function [jointx,jointy]=findKneeJoint_120m(filename,Photometric,PixDim,crop_in)
%

% initialize outputs
jointx = [];
jointy = [];

% initialize parameters
disk2 = strel('disk',2);
disk4 = strel('disk',4);

% read DCM and crop for knee
rawimg=dicomread(filename);
imgsize=size(rawimg);
if(strcmp(Photometric,'MONOCHROME1'))
    rawimg=abs(mat2gray(rawimg)-max(max(mat2gray(rawimg))));
else
    rawimg=mat2gray(rawimg);
end

cropforleg=rawimg(crop_in(1):crop_in(2),crop_in(3):crop_in(4));
cropforleg=cropforleg/max([1,max(max(cropforleg))]);
cropsize=size(cropforleg);
clear rawimg;

% construct binary knee mask
flag_mask = 0; bwthresh = 0.5;
while(flag_mask==0)
    ixthresh = round(bwthresh*100);
    bwcutoff=stretchlim(cropforleg, [bwthresh, 1]);
    ix=1;

    bwcropfor=im2bw(cropforleg,bwcutoff(1));
    leglabels=bwlabel(bwcropfor,4);
    legstats=regionprops(leglabels,'Area');
    legareas=[legstats.Area];
    [~,areaind]=sort(legareas,2,'descend');

    if(size(areaind,2)>0)
        % continue processing bright contiguous regions
        
        getleg=zeros(size(bwcropfor)); %1st label w/ largest area
        getleg(leglabels==areaind(ix))=1;
        getleg=imclose(getleg,disk4);

        checklegmask=sum(getleg,2); %iteratively add leg until femur/tibia cross the top/bottom
        ix=ix+1;
        if(ix>size(areaind,2))
            flag_mask=1;
        end

        % check if mask encompasses almost whole image height
        while(size(find(checklegmask(:,1)==0),1)>(cropsize(1)*0.025) && flag_mask==0);
            getleg(leglabels==areaind(ix))=1; %add more labels to mask
            getleg=imclose(getleg,disk4);
            checklegmask=sum(getleg,2);
            ix=ix+1; 
            if(ix>size(areaind,2) || ix>ixthresh) %break loop if first few labels are not enough
                flag_mask=1;
            end
        end

        % check if mask encompasses almost whole image height
        if(size(find(checklegmask(:,1)==0),1)<=(cropsize(1)*0.005))
            flag_mask=1;
        else
            flag_mask=0;
            bwthresh = bwthresh - 0.05; %lower BW threshold
        end
        
    else % lower threshold if no regions found
        flag_mask=0;
        bwthresh = bwthresh - 0.05; %lower BW threshold
    end
    
    if(bwthresh<=0) % escape if unable to find adequate leg structures
        disp('Insufficient anatomy or image contrast.');
        return;
    end
    
end

% get image gradients
[gradx,grady]=gradient(imfilter(cropforleg,fspecial('gaussian',5,5)));


% get positive y-gradient mask
posgrady=grady/max(max(grady));
posind=stretchlim(posgrady,[0.95 1]); %only strong edges
posgrady=im2bw(posgrady,posind(1));
posgrady=posgrady.*imdilate(getleg,disk2);
posgrady=imclose(posgrady,disk2);

poslabels=bwlabel(posgrady,8); %label the edge shapes
posstats=regionprops(poslabels,'Area','Orientation','MajorAxisLength','MinorAxisLength');
posareas=[posstats.Area];
[~,posind]=sort(posareas,2,'descend');

posgrady=zeros(size(posgrady)); %collect only the large edge shapes w/ horiz. orientation
ix=1;
while(posstats(posind(ix)).Area>((5/PixDim(2))^2))
    if(abs(posstats(posind(ix)).Orientation)<45 && (posstats(posind(ix)).MajorAxisLength)>2*(posstats(posind(ix)).MinorAxisLength))
        posgrady(poslabels==posind(ix))=1;
    else % this shape doesn't fit, erode and examine eroded shapes
        minigrady = zeros(size(poslabels));
        minigrady(poslabels==posind(ix))=1;
        minigrady = imerode(minigrady,disk2);
        minilabels=bwlabel(minigrady,8); %label the edge shapes again
        ministats=regionprops(minilabels,'Area','Orientation','MajorAxisLength','MinorAxisLength');
        miniareas=[ministats.Area];
        [~,miniind]=sort(miniareas,2,'descend');
        for jx=1:size(ministats,1)
            if(ministats(miniind(jx)).Area>((5/PixDim(2))^2) && abs(ministats(miniind(jx)).Orientation)<45 && (ministats(miniind(jx)).MajorAxisLength)>2*(ministats(miniind(jx)).MinorAxisLength))
                posgrady(minilabels==miniind(jx))=1;
            end
        end
    end
    ix=ix+1;
end
posgrady=imclose(posgrady,disk2);

% horizontally fill the edge shapes
padsize=round(50/PixDim(1));
posgrady=padarray(posgrady,[0 2*padsize]);
posgrady=imclose(posgrady,ones(1,round(25/PixDim(2))));
posgrady=posgrady(:,((2*padsize)+1):((end)-(2*padsize)));

% ignore the extremely long, or extremely short horizontal shapes
poslabels=bwlabel(posgrady,8); %label the edge shapes again
posstats=regionprops(poslabels,'BoundingBox');
posgrady=zeros(size(posgrady));
for ix=1:size(posstats,1)
    if( posstats(ix).BoundingBox(3)<(0.95*cropsize(2)) && posstats(ix).BoundingBox(3)>(30/PixDim(1)) )
        posgrady(poslabels==ix)=1;
    end
end


% get negative y-gradient mask
neggrady=grady/min(min(grady));
negind=stretchlim(neggrady,[0.95 1]); %only strong edges
neggrady=im2bw(neggrady,negind(1));
neggrady=neggrady.*imdilate(getleg,disk2);
neggrady=imclose(neggrady,disk2);

neglabels=bwlabel(neggrady,8); %label the edge shapes
negstats=regionprops(neglabels,'Area','Orientation','MajorAxisLength','MinorAxisLength');
negareas=[negstats.Area];
[~,negind]=sort(negareas,2,'descend');

neggrady=zeros(size(neggrady)); %collect large edge shapes w/ horiz. orientation
ix=1;
while(negstats(negind(ix)).Area>((5/PixDim(2))^2))
    if(abs(negstats(negind(ix)).Orientation)<45 && (negstats(negind(ix)).MajorAxisLength)>2*(negstats(negind(ix)).MinorAxisLength))
        neggrady(neglabels==negind(ix))=1;
    else % this shape doesn't fit, erode and examine eroded shapes
        minigrady = zeros(size(neglabels));
        minigrady(neglabels==negind(ix))=1;
        minigrady = imerode(minigrady,disk2);
        minilabels=bwlabel(minigrady,8); %label the edge shapes again
        ministats=regionprops(minilabels,'Area','Orientation','MajorAxisLength','MinorAxisLength');
        miniareas=[ministats.Area];
        [~,miniind]=sort(miniareas,2,'descend');
        for jx=1:size(ministats,1)
            if(ministats(miniind(jx)).Area>((5/PixDim(2))^2) && abs(ministats(miniind(jx)).Orientation)<45 && (ministats(miniind(jx)).MajorAxisLength)>2*(ministats(miniind(jx)).MinorAxisLength))
                neggrady(minilabels==miniind(jx))=1;
            end
        end
    end
    ix=ix+1;
end
neggrady=imclose(neggrady,disk2);

% horizontally fill the edge shapes
padsize=round(50/PixDim(1));
neggrady=padarray(neggrady,[0 2*padsize]);
neggrady=imclose(neggrady,ones(1,round(25/PixDim(2))));
neggrady=neggrady(:,((2*padsize)+1):((end)-(2*padsize)));

% ignore the extremely long, or extremely short horizontal shapes
neglabels=bwlabel(neggrady,8); %label the edge shapes again
negstats=regionprops(neglabels,'BoundingBox');
neggrady=zeros(size(neggrady));
for ix=1:size(negstats,1)
    if( negstats(ix).BoundingBox(3)<(0.95*cropsize(2)) && negstats(ix).BoundingBox(3)>(30/PixDim(1)) )
        neggrady(neglabels==ix)=1;
    end
end


% combine positive & negative gradient edge shapes
combgrady=posgrady+neggrady;
combgrady(combgrady>1)=1;
combgrady=imclose(combgrady,ones(round(5/PixDim(2)),1));

% ignore combined shapes without contribution from both pos+neg
jointlabels=bwlabel(combgrady,4);
for ix=1:max(max(jointlabels))
    
    tempmat=zeros(size(jointlabels));
    tempmat(jointlabels==ix)=1;

    tempsum=sum(sum( tempmat.*posgrady ));
    if(tempsum==0)
        jointlabels(jointlabels==ix)=0;
    end
    
    tempsum=sum(sum( tempmat.*neggrady ));
    if(tempsum==0)
        jointlabels(jointlabels==ix)=0;
    end
end

% find the largest remaining shape
jointstats=regionprops(jointlabels,'Area');
jointareas=[jointstats.Area];
[~,jointind]=max(jointareas);
if(~isempty(jointind))
    if(size(jointstats,1)>1)
        combgrady(jointlabels~=jointind)=0;
    end
else
    disp('Unable to find knee joint.');
    return;
end

% return center-of-mass for final knee ROI
centprop=regionprops(combgrady,'Centroid');
jointcentroid=centprop.Centroid;

jointx=jointcentroid(1) + crop_in(3) - 1;
jointy=jointcentroid(2) + crop_in(1) - 1;



