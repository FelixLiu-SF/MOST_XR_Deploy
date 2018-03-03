function Upload_QC_from_BU()
%% function to upload XRs results from QC

%% initialize
disp(' ');
disp('Initializing...');


% master mdbf
master_mdbf = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

% directories
srcdir = '\\most-ftps\MOSTFTPS\SITE03\XR\UPLOAD';
newdir = 'E:\most-dicom\XR_QC\Received\QC';
updir = 'E:\most-dicom\XR_QC\Uploaded\QC';

%% search for new scoresheets

[~,~,src_list] = foldertroll(srcdir,'.mdb');
[~,~,up_list] = foldertroll(updir,'.mdb');

src_list = src_list(indcfind(src_list(:,3),'MOST_XR_QC_[0-9]{8}','regexpi'),:);

if(size(src_list,1)>0)
    disp(' ');
    disp('List of scoresheets from reader: ');
    disp(src_list(:,1));
else
    disp(' ');
    disp('No scoresheets from reader found.');
end

%% copy new scoresheets for uploading
disp(' ');
disp('Copying new scoresheets');
copy_list = src_list(~ismember(src_list(:,3),up_list(:,3)),:);
for ix=1:size(copy_list,1)
    tmppf = copy_list{ix,1};
    tmpf = copy_list{ix,3};
    
    tmp_destf = horzcat(newdir,'\',tmpf);
    
    copyfile(tmppf,tmp_destf);
end

%% upload the new scoresheet files
disp(' ');
disp('Uploading results to database');
[~,~,new_list] = foldertroll(newdir,'.mdb');

for ix=1:size(new_list,1)
    
    tmp_mdbf =  new_list{ix,1};
    tmp_destf = horzcat(updir,'\',new_list{ix,3});
    
    Upload_Scoresheet_to_tblBU(master_mdbf,tmp_mdbf,tmp_destf);
    pause(5);
    
end