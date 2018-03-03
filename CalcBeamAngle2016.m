function [info_out,aR,aL,aC,npairs,avgfinR,avgfinL,LRratio,FemR,FemL,TibR,TibL,jointR,jointL,truebeadR,truebeadL,lim_8_12,FemTib_10,pixrad,exitcode]=CalcBeamAngle2016(filename)
% [info_out,aR,aL,aC,npairs,avgfinR,avgfinL,LRratio,FemR,FemL,TibR,TibL,jointR,jointL,truebeadR,truebeadL,lim_8_12,FemTib_10,exitcode]=CalcBeamAngle120m(filename)

% initialize output variables
info_out = struct();
aR = [];
aL = [];
aC = [];
npairs = [];
avgfinR = [];
avgfinL = [];
LRratio = [];
FemR = [];
FemL = [];
TibR = [];
TibL = [];
jointR = [];
jointL = [];
truebeadR = [];
truebeadL = [];
lim_8_12 = [];
FemTib_10 = [];
pixrad = [];
exitcode = 0;

% check if file is DICOM format
if(isdicom(filename))
    info = dicominfo(filename);
else
    disp('Input file is not DICOM format');
    exitcode = 0;
    return;
end

% collect DICOM metadata
if(isfield(info,'PatientID')); PatID=info.PatientID;            else; PatID='.'; end;
if(isfield(info,'PatientName')); Acro=info.PatientName;         else; Acro='.'; end;
if(isfield(info,'StudyDate')); StudyDate=info.StudyDate;        else; StudyDate='.'; end;
if(isfield(info,'SOPInstanceUID')); UID=info.SOPInstanceUID;        else; UID='.'; end;
if(isfield(info,'PixelSpacing')); PixDim=info.PixelSpacing;     else; PixDim='.'; end;
if(isfield(info,'ImagerPixelSpacing')); ImagerPixDim=info.ImagerPixelSpacing;   else; ImagerPixDim='.'; end;
if(isfield(info,'AccessionNumber')); Accession=info.AccessionNumber;            else; Accession='.'; end;
if(isfield(info,'ClinicalTrialTimePointID')); Visit=info.ClinicalTrialTimePointID;          else; Visit='.'; end;
if(isfield(info,'PhotometricInterpretation')); Photometric=info.PhotometricInterpretation;  else; Photometric='.'; end;
if(isfield(info,'Rows')); ImgRows=info.Rows;                else; ImgRows='.'; end;
if(isfield(info,'Columns')); ImgCols=info.Columns;          else; ImgCols='.'; end;

% check pixel dimension data
if(strcmp(ImagerPixDim(1),'.') & ~strcmp(PixDim(1),'.'))
    ImagerPixDim = PixDim;
end
if(strcmp(PixDim(1),'.') & ~strcmp(ImagerPixDim(1),'.'))
    PixDim = ImagerPixDim;
end

if(isstruct(Acro))
    c_Acro = struct2cell(Acro);
    Acro = strtrim(horzcat(c_Acro{:}));
end

% save output metadata
info_out = struct('PatientID',PatID,...
    'Acrostic',Acro,...
    'StudyDate',StudyDate,...
    'UID',UID,...
    'PixDim',ImagerPixDim,...
    'Accession',Accession,...
    'Visit',Visit,...
    'Photometric',Photometric,...
    'ImgRows',ImgRows,'ImgCols',ImgCols);

% calculate SynaFlexer bead size
if(~strcmp(ImagerPixDim(1),'.'))
    pixrad=ceil((25.4/16)/ImagerPixDim(1));
else
    error('Pixel Spacing not found');
    exitcode = 0;
    return;
end

% Get Synaflexer Bead positions
[imgsize, rectcorner, rectsize, beadline, avgfinR, avgfinL, Rline, Lline, finbeadR, finbeadL] = findSynaflexer_MOST(filename,PixDim,Photometric,pixrad);
if(size(finbeadR,1)>0 && size(finbeadL,1)>0)
    truebeadR = [finbeadR(:,1)+rectcorner(2),finbeadR(:,2)+rectcorner(1)];
    truebeadL = [finbeadL(:,1)+rectcorner(2),finbeadL(:,2)+rectcorner(1)];
else
    disp('No Synaflexer beads found on image.');
    exitcode = 0;
    return;
end

% Get crop coordinates for knees
[knee_top, knee_bot, knee_right, knee_left] = KneeXRSections(imgsize,rectcorner,rectsize,finbeadR,finbeadL);
crop_in_R =[knee_top,knee_bot,knee_right(1),knee_right(2)];
crop_in_L =[knee_top,knee_bot,knee_left(1),knee_left(2)];

% Get approximate knee joint centers
[jointRx,jointRy]=findKneeJoint_MOST(filename,Photometric,PixDim,crop_in_R);
[jointLx,jointLy]=findKneeJoint_MOST(filename,Photometric,PixDim,crop_in_L);

% Calculate film geometry
npairs=size(finbeadR,1);
d1=25.4*1.5;
y2=25.4*(npairs-1);

B0R=[(1-rectcorner(1))*Rline(1)+Rline(2)+rectcorner(2),1];
B0L=[(1-rectcorner(1))*Lline(1)+Lline(2)+rectcorner(2),1];

B1=truebeadL(1,:);
B2=truebeadR(1,:);
B3=truebeadL(end,:);
B4=truebeadR(end,:);

h1=ImagerPixDim(2)*sum((B0L-B1).^2).^0.5;
h2=ImagerPixDim(2)*sum((B0R-B2).^2).^0.5;
h3=ImagerPixDim(2)*sum((B0L-B3).^2).^0.5;
h4=ImagerPixDim(2)*sum((B0R-B4).^2).^0.5;

s0=h1;
s1=h2-h1;
s2=h3-h2;
s3=h4-h3;

d2=(d1*(s1+s2))/(s3-s1);
y0=(s1*(s1+s2))/(s3-s1) - s0;
y1=(s1*y0 + s1*y2 -s3*y0)/(s3-s1);
d0=((d1+d2)*(s0-y1))/(y0+y1);

% Calculate knee geometry
hL=ImagerPixDim(2)*jointLy;
hR=ImagerPixDim(2)*jointRy;

aL = (180/pi)*atan((y0+hL)/(d0+d1+d2));
aR = (180/pi)*atan((y0+hR)/(d0+d1+d2));
aC = (180/pi)*atan((y0+((hL+hR)/2))/(d0+d1+d2));

LRratio = avgfinL/avgfinR;

% calculate 8 and 12 degree limits
lim8 = ((tan(8*(pi/180))*(d0+d1+d2)) - y0)/ImagerPixDim(2);
lim12 = ((tan(12*(pi/180))*(d0+d1+d2)) - y0)/ImagerPixDim(2);

% calculate -8, -12 degree limits for LR flipped images
lim8flip = ((tan(-8*(pi/180))*(d0+d1+d2)) - y0)/ImagerPixDim(2);
lim12flip = ((tan(-12*(pi/180))*(d0+d1+d2)) - y0)/ImagerPixDim(2);

% calculate estimates of femur/tibia coverage
FemL = (1/100)*round(hL*10);
FemR = (1/100)*round(hR*10);
TibL = (1/100)*round(((imgsize(1)*ImagerPixDim(2)) - hL)*10);
TibR = (1/100)*round(((imgsize(1)*ImagerPixDim(2)) - hR)*10);

Fem10 = min([jointLy,jointRy]) - (100/ImagerPixDim(2));
Tib10 = max([jointLy,jointRy]) + (100/ImagerPixDim(2));

% clean up variables
jointR = [jointRx,jointRy];
jointL = [jointLx,jointLy];
lim_8_12 = [lim8, lim12, lim8flip, lim12flip];
FemTib_10 = [Fem10, Tib10];
exitcode=1;
