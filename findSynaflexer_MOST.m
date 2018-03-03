function [imgsize, rectcorner, rectsize, beadline, avgfinR, avgfinL, Rline, Lline, finbeadR, finbeadL] = findSynaflexer_MOST(filename,PixDim,Photometric,pixrad)
% [imgsize, rectcorner, rectsize, beadline, avgfinR, avgfinL, Rline, Lline, finbeadR, finbeadL] = findSynaflexer_120m(filename,PixDim,Photometric,pixrad)

% initialize parameters
    resetROI=1;
    rloffset=0;
    breakloop=0;
    
    mmbandwidth = 6.35;
    mmwidth = 4;
    
% initialize outputs
    imgsize = [];
    rectcorner = [];
    rectsize = [];
    beadline = [];
    avgfinR = [];
    avgfinL = [];
    Rline = [];
    Lline = []; 
    finbeadR = [];
    finbeadL = [];
    
% search image for beads with Hough circle detection, looping through
% different search regions
while(resetROI==1)
    breakloop=breakloop+1;
    resetROI=0;

    % get search region; middle 20% of image with rloffset
    [grayimg,rectcorner,rectsize,filteredimg,imgsize]=GetSynFrameImg(filename,Photometric,rloffset);

    % find Hough circles
    [circen,~,~]=GetHoughCircle(filteredimg,pixrad);

    if(size(circen,1)>0 & size(circen,1)<400)
        %% check goodness of beads
        [circen]=StripThreshold(circen,grayimg,pixrad);
        [circen]=GetPeakBeads(circen,rectsize,PixDim,mmbandwidth,mmwidth);
 
        try
            [circen]=StripResidual(circen,rectsize,PixDim);
            [beadline,Rline,Lline,Rstat,Lstat,Rfitout,Lfitout,Rbeads,Lbeads]=GetBeadLines(circen);
            Rdist = RowDist(Rbeads);
            Ldist = RowDist(Lbeads);

            % get rid of duplicates
            [Rbeads]=StripSpacing(Rbeads,Rdist,PixDim);
            [Lbeads]=StripSpacing(Lbeads,Ldist,PixDim);

            circen = sortrows([Rbeads;Lbeads],2);
        catch
            Rbeads = [];
            Lbeads = [];
            circen = [];
        end

        %% check if beads are close to edge of search region, move region if so
        synaflexmid=round( ( (beadline(1)+beadline(2))+(size(grayimg,1)*beadline(1) + beadline(2)) )/2 );
        if( synaflexmid>(0.8*size(grayimg,2)) || synaflexmid<(0.2*size(grayimg,2)) )
            %rloffset=rloffset+round(synaflexmid-(size(grayimg,2)/2));
            rloffset = round(rloffset + ((-1)^(breakloop))*(imgsize(2)*(0.06*breakloop)));
            resetROI=1;
        end
        
        bead_test0 = (isempty(Rbeads) || isempty(Lbeads));
        if(bead_test0<1)
            bead_test1 = abs(size(Rbeads,1)-size(Lbeads,1));
            bead_test2r = mean(Rbeads(:,1));
            bead_test2l = mean(Lbeads(:,1));
            bead_test2 = abs(bead_test2r - bead_test2l);
            bead_test3r = mean(Rbeads(:,2));
            bead_test3l = mean(Lbeads(:,2));
            bead_test3 = abs(bead_test3r - bead_test3l);
        else
            bead_test1 = 0;
            bead_test2 = 0;
            bead_test3 = 0;
        end
        
        if(resetROI==0 && (bead_test0==1 | bead_test1>3 | (bead_test2>(25/PixDim(1))) | (bead_test3<(2/PixDim(1))) ) )
            rloffset = round(rloffset + ((-1)^(breakloop))*(imgsize(2)*(0.06*breakloop)));
            resetROI=1;
        end

    else % too many circles to be real, redefine search region, alternating -/+ rloffsets
        rloffset = round(rloffset + ((-1)^(breakloop))*(imgsize(2)*(0.06*breakloop)));
        resetROI=1;
    end

    if(breakloop>10)
        resetROI=0;
    end
    
%     %debug
%     hf = figure; imshow(filteredimg,[]); hold on;
%     scatter(circen(:,1),circen(:,2),'ro');
%     uiwait(hf);

end

if(breakloop<=10 && size(circen,1)>0)

    Rdist = RowDist(Rbeads);
    Ldist = RowDist(Lbeads);
    
    % collect beads into groups of continous beads on a line
    [beadR2,beadL2,beadR2alt,beadL2alt,avgrawR,avgrawL]=GroupBeads(Rbeads,Lbeads,Rdist,Ldist,PixDim);
    
    % check overlap of bead groupings
    bead_overlap = zeros(2,2);
        bead_overlap(1,1) = min([max(beadR2(:,2)), max(beadL2(:,2))]) - max([min(beadR2(:,2)), min(beadL2(:,2))]);
    if(~isempty(beadL2alt))
        bead_overlap(2,1) = min([max(beadR2(:,2)), max(beadL2alt(:,2))]) - max([min(beadR2(:,2)), min(beadL2alt(:,2))]);
    end
    if(~isempty(beadR2alt))
        bead_overlap(1,2) = min([max(beadR2alt(:,2)), max(beadL2(:,2))]) - max([min(beadR2alt(:,2)), min(beadL2(:,2))]);
    end
    if(~isempty(beadL2alt) && ~isempty(beadR2alt))
        bead_overlap(2,2) = min([max(beadR2alt(:,2)), max(beadL2alt(:,2))]) - max([min(beadR2alt(:,2)), min(beadL2alt(:,2))]);
    end
    
    % find largest overlap between Rt & Lt groupings
    if(max(max(bead_overlap>0)))
        [col_max,row_ix]=max(bead_overlap);
        [~,col_ix]=max(col_max);
        col_group = col_ix;
        row_group = row_ix(col_ix);
    else
        col_group = 1;
        row_group = 1;
    end
    
    % use largest overlap
    if(col_group==2)
        beadR2 = beadR2alt;
    end
    if(row_group==2)
        beadL2 = beadL2alt;
    end
    
    % pair the right and left beads
    if(size(beadR2,1)<=size(beadL2,1))
        matchfirst=0;
        matchfound=0;
        while( matchfirst<(size(beadR2,1)) && matchfound==0)
            matchfirst=matchfirst+1;
            matchbead=abs(beadL2(:,2)-beadR2(matchfirst,2));
            [matchdist,matchind]=min(matchbead);

            if(matchdist<avgrawR/2)
                matchfound=1;
            end
        end    
        if(matchfound==0)
            disp('No reliable bead pairs found')

            beadR3=[];
            beadL3=[];
        else
            beadR3=beadR2(matchfirst:end,:);
            beadL3=beadL2(matchind:end,:);
        end
    elseif(size(beadR2,1)>size(beadL2,1))
        matchfirst=0;
        matchfound=0;
        while( matchfirst<(size(beadL2,1)) && matchfound==0)
            matchfirst=matchfirst+1;
            matchbead=abs(beadR2(:,2)-beadL2(matchfirst,2));
            [matchdist,matchind]=min(matchbead);

            if(matchdist<avgrawL/2)
                matchfound=1;
            end
        end    
        if(matchfound==0)
            disp('No reliable bead pairs found')

            beadR3=[];
            beadL3=[];
        else
            beadL3=beadL2(matchfirst:end,:);
            beadR3=beadR2(matchind:end,:);
        end
    end
    
  
    if(size(beadR3,1)==size(beadL3,1))
        finbeadR=beadR3;
        finbeadL=beadL3;
        
    elseif(size(beadR3,1)<size(beadL3,1))
        finbeadR=beadR3;
        finbeadL=beadL3(1:size(beadR3,1),:);
        
    elseif(size(beadR3,1)>size(beadL3,1))
        finbeadR=beadR3(1:size(beadL3,1),:);
        finbeadL=beadL3;
    end
    
    % check if 2+ bead pairs are left
    if(size(finbeadR,1)>1 && size(finbeadL,1)>1)
    
    % recalc distances for final bead arrays
        Rdist = RowDist(finbeadR);
        Ldist = RowDist(finbeadL);

        avgfinR=mean(Rdist)*PixDim(2);
        avgfinL=mean(Ldist)*PixDim(2);

        npairs=size(finbeadR,1);

        d1=25.4*1.5;
        y2=25.4*(npairs-1);

        B0R=[(1-rectcorner(1))*Rline(1)+Rline(2)+rectcorner(2),1];
        B0L=[(1-rectcorner(1))*Lline(1)+Lline(2)+rectcorner(2),1];

        B1=finbeadL(1,:)+[rectcorner(2), rectcorner(1)];
        B2=finbeadR(1,:)+[rectcorner(2), rectcorner(1)];
        B3=finbeadL(end,:)+[rectcorner(2), rectcorner(1)];
        B4=finbeadR(end,:)+[rectcorner(2), rectcorner(1)];

        h1=PixDim(2)*sum((B0L-B1).^2).^0.5;
        h2=PixDim(2)*sum((B0R-B2).^2).^0.5;
        h3=PixDim(2)*sum((B0L-B3).^2).^0.5;
        h4=PixDim(2)*sum((B0R-B4).^2).^0.5;

        s0=h1;
        s1=h2-h1;
        s2=h3-h2;
        s3=h4-h3;

        d2=(d1*(s1+s2))/(s3-s1);
        y0=(s1*(s1+s2))/(s3-s1) - s0;
        y1=(s1*y0 + s1*y2 -s3*y0)/(s3-s1);
        d0=((d1+d2)*(s0-y1))/(y0+y1);

    else % less than 2 bead pairs, no further beam angle calculations possible
        finbeadL=[];
        finbeadR=[];
    end

else % no reliable Hough circle detection
    finbeadL=[];
    finbeadR=[];
end






















%% SUBFUNCTIONS for cleaner code %%

% crop synaflexer image for frame beads
function [grayimg,rectcorner,rectsize,filteredimg,imgsize]=GetSynFrameImg(filename,Photometric,rloffset)
% function [grayimg,rectcorner,topbright,rectsize,filteredimg,findcutoff]=GetSynFrameImg(filename,Photometric,rloffset)

    % read dicom image, correct photometric interpretation
    if(strcmp(Photometric,'MONOCHROME1'))
        rawimg=dicomread(filename);
        rawimg=abs(mat2gray(rawimg)-max(max(mat2gray(rawimg))));
    else
        rawimg=dicomread(filename);
    end
    imgsize = size(rawimg);

    % crop image to middle 20%, exclude 5% superior % 5% inferior.
    % Right-Left offset translation is optional.
    Rlim = (round( size(rawimg,2)/2 - size(rawimg,2)*0.10 )+rloffset);
    Llim = (round( size(rawimg,2)/2 + size(rawimg,2)*0.10 )+rloffset);
    if(Rlim<1);                 Rlim=1;                 end;
    if(Llim>size(rawimg,2));    Llim=size(rawimg,2);    end;
    cropimg=rawimg(round(size(rawimg,1)/20):size(rawimg,1)-round(size(rawimg,1)/20),Rlim:Llim);
    rectcorner=[round(size(rawimg,1)/20), Rlim];

    % 8bit grayscale more suitable for screenshots
    grayimg=mat2gray(cropimg)*255;
    rectsize=size(grayimg);

    % filter to correct Right-Left inhomogeneity
        
        % sample superior 5% of cropped image
        sample=grayimg(1:round(size(grayimg,1)/20),:);
        % blur and collapse columns
        blursample=imfilter(sample,fspecial('gaussian',10,10));
        samplesum=sum(blursample);
        % create filter = (inverse of col sum) + 1
        sumfilter=(abs(1-(samplesum/max(samplesum)))+1);
        % apply filter to all rows of cropped image
        filteredimg=grayimg.*repmat(sumfilter,size(grayimg,1),1);
        
% Hough circle search
function [circen,cirrad,memvar]=GetHoughCircle(filteredimg,pixrad)
% function [circen,cirrad,memvar]=GetHoughCircle(filteredimg,pixrad)

    % initialize variables
    circen = [];
    cirrad = 0;
    memvar=0;
    smpx=floor(0.33*pixrad); %lower limit of circle radius
    bgpx=ceil(1.25*pixrad); %upper limit of circle radius
    findcutoff=5;
    
    % first hough search
    try
        [~, circen, cirrad] = CircularHough_Grd(filteredimg, [smpx, bgpx], floor(findcutoff(1)), 5, 1);
    catch tcerr1
    % something went wrong, so try lower resolution search (50% reduction)
        disp(tcerr1.message);
        memvar=1;
        
        filteredimglow=imresize(filteredimg,0.5);
        try
            [~, circen, cirrad] = CircularHough_Grd(filteredimglow, [round(smpx/2), round(bgpx/2)], floor(findcutoff(1)), 5, 1);
        catch tcerr2
        % something still wrong, possibly no beads found
            disp(tcerr2.message);
            disp('Low resolution image still too large.');
            return;
        end
    end
    
    % check if there are too many results
    if(size(circen,1)>24)
    % then blur image again
        if(memvar==0)
            filteredimg2=imfilter(filteredimg,fspecial('gaussian',round(0.25*pixrad),round(0.25*pixrad)));
        end
        if(memvar==1)
            filteredimg2=imfilter(filteredimglow,fspecial('gaussian',round(0.25*pixrad),round(0.25*pixrad)));
        end

        [~, circen2, cirrad2] = CircularHough_Grd(filteredimg2, [smpx, bgpx], floor(findcutoff(1)), 5, 1);
        
        % check if increase blurring had better results
        if(size(circen,1)>size(circen2,1))
            circen = circen2;
            cirrad = cirrad2;
        end
    end

    % correct for low resolution image
    if(memvar==1 && size(circen,1)>0)
        circen(:,1)=2.*circen(:,1);
        circen(:,2)=2.*circen(:,2);
        cirrad=2.*cirrad;
    end

% keep only circles in 2 largest columnar peaks
function [circenout]=GetPeakBeads(circen,rectsize,PixDim,mmbandwidth,mmwidth)
    
    circenout = circen;
    
    % check density of circles along x-axis
    estpeaks=zeros(25,100);

    
    xi=linspace(1,rectsize(2),100);
    maxest=round(linspace(1,(mmbandwidth/PixDim(1)),25));
    
    % collect density plots at varying bandwidth
    for i=maxest
        [f] = ksdensity(circen(:,1),xi,'width',i); 
        estpeaks(i,:)=f;
    end
    
    % find most dense peaks across all bandwidths
    pkestimate=max(estpeaks);
    pkestimate=pkestimate/max(pkestimate);
    
    % loop to find suitable peaks
    pkheight = 0.95;
    mmwidth0 = mmwidth;
    pkflag=1;
    while(pkflag~=0)
        %simple peak locater
        pklocs = find(pkestimate>pkheight);
        if(size(pklocs,2)>1) %more than 1 peak, use robust peak locater
            [~,pklocs] = findpeaks(pkestimate,'minpeakheight',pkheight,'sortstr','descend');
        end
        pkflag=pkflag+1;
        
        % limit the number of random comparisons
        pkcheck = factorial(size(pklocs,2)+1);
        if(pkcheck>250) %restrict the factorial check
            pkcheck=250;
        end
        
        if(size(pklocs,2)>2) %reduce to random 2 peaks
            randpks = randperm(size(pklocs,2));
            pklocs=pklocs(1,randpks(1:2));
        end
        
        %check if width spacing between peaks is good
        pkdiff = diff(sort(pklocs));
        if(max(pkdiff)<4/PixDim(1) & min(pkdiff)>1/PixDim(1))
            
            % filter circles to areas under peaks with width = mmwidth
            pkwid=mmwidth0/PixDim(1);
            cirix=[];
            for i=1:size(pklocs,2)
                cirixtoadd = find(circen(:,1)>(xi(pklocs(i))-pkwid) & circen(:,1)<(xi(pklocs(i))+pkwid));
                cirix=[cirix; cirixtoadd];
            end
            cirix = unique(cirix);
            circentmp = circen(cirix,:);
            try
                [~,Rline,Lline,~,~,~,~,Rbeads,Lbeads]=GetBeadLines(circentmp);

                % check Rt and Lt line slopes, x-dim St Dev, and mean y-dim
                if( (abs(Rline(1) - Lline(1))*50 <1) ...
                        && (std(Rbeads(:,1))<(3/PixDim(2))) && (std(Lbeads(:,1))<(3/PixDim(2))) ...
                        && abs(mean(Rbeads(:,2)) - mean(Lbeads(:,2)))<(rectsize(1)/5) ...
                        && size(Rbeads,1)>1 && size(Lbeads,1)>1)
                    % if these 2 peaks are good match, stop while-loop
                    pkflag=0;
                end
            catch beaderr
                
            end
        end
        
        if(pkflag~=0 & size(pklocs,2)<2)
            % if only 1 peak found
            pkflag=1;
            mmwidth0 = mmwidth;
            pkheight = pkheight - 0.05;
        elseif(pkflag~=0 & size(pklocs,2)==2 & mmwidth0>=0.5)
            % if exactly 2 peaks found, decrease pk width
            pkflag=1;
            mmwidth0 = mmwidth0 - 0.25;
        elseif(pkflag~=0 & pkflag>pkcheck & mmwidth0>=0.5)
            % if while loop run is too large, decrease pk width
            pkflag=1;
            mmwidth0 = mmwidth0 - 0.25;
        elseif(pkflag~=0 & pkflag>pkcheck & mmwidth0<0.5)
            % if while loop run is too large, decrease pk height
            pkflag=1;
            mmwidth0 = mmwidth;
            pkheight = pkheight - 0.05;
        end
        if(pkheight<0)
            pkflag=0;
            errmsg = 'nobeads';
            return;
        end
    end % pklocs is a good match at this point

    % filter circles to areas under peaks with width = mmwidth
    pkwid=mmwidth/PixDim(1);
    cirix=[];
    for i=1:size(pklocs,2)
        cirixtoadd = find(circen(:,1)>(xi(pklocs(i))-pkwid) & circen(:,1)<(xi(pklocs(i))+pkwid));
        cirix=[cirix; cirixtoadd];
    end
    cirix = unique(cirix);
    circenout = circen(cirix,:);

% check linearity of circles
function [beadline,Rline,Lline,Rstat,Lstat,Rfitout,Lfitout,Rbeads,Lbeads]=GetBeadLines(circenin)
    beadline=polyfit(circenin(:,2),circenin(:,1),1);
    Rcount=1;
    Lcount=1;
    for i=1:size(circenin,1)
        if(circenin(i,1)<(circenin(i,2)*beadline(1)+beadline(2)))
            Rbeads(Rcount,:)=circenin(i,:);
            Rcount=Rcount+1;
        else
            Lbeads(Lcount,:)=circenin(i,:);
            Lcount=Lcount+1;
        end
    end
    Rbeads=sortrows(Rbeads,2);
    Lbeads=sortrows(Lbeads,2);

    [Rline0,Rstat,Rfitout]=fit(Rbeads(:,2),Rbeads(:,1),'poly1');
    [Lline0,Lstat,Lfitout]=fit(Lbeads(:,2),Lbeads(:,1),'poly1');
    
    Rline = [Rline0.p1, Rline0.p2];
    Lline = [Lline0.p1, Lline0.p2];

% strip circles by line fit residuals
function [circenout]=StripResidual(circenin,rectsize,PixDim)

    % initial line fitting
    [beadline,Rline,Lline,Rstat,Lstat,Rfitout,Lfitout,Rbeads,Lbeads]=GetBeadLines(circenin);

    % delete circles with residuals > 1mm
    [maxresid,ixresid]=max(abs(Rfitout.residuals));
    while(maxresid>(1/PixDim(1)) & size(Rbeads,1)>2)
        Rbeads(ixresid,:)=[];
        [Rline0,Rstat,Rfitout]=fit(Rbeads(:,2),Rbeads(:,1),'poly1');
        Rline = [Rline0.p1, Rline0.p2];
        [maxresid,ixresid]=max(abs(Rfitout.residuals));
    end
    [maxresid,ixresid]=max(abs(Lfitout.residuals));
    while(maxresid>(1/PixDim(1)) & size(Lbeads,1)>2)
        Lbeads(ixresid,:)=[];
        [Lline0,Lstat,Lfitout]=fit(Lbeads(:,2),Lbeads(:,1),'poly1');
        Lline = [Lline0.p1, Lline0.p2];
        [maxresid,ixresid]=max(abs(Lfitout.residuals));
    end

    % check slope is still reasonable, otherwise reject the results
    if(abs(Rline(1))<(PixDim(1)/2) | abs(Lline(1))<(PixDim(1)/2))
        circenout = sortrows([Rbeads;Lbeads],2);
    else
        circenout = circenin;
    end
        
% strip circles by threshold
function [circenout]=StripThreshold(circenin,grayimg,pixrad)

    % dark threshold img
    darkpxlim=stretchlim(grayimg/max(max(grayimg)),[0.1 1]);
    darkbeadimg=im2bw(grayimg/max(max(grayimg)),darkpxlim(1));

    %bright threshold img
    areapxlim=stretchlim(grayimg/max(max(grayimg)),[0.99 1]);
    areabeadimg=im2bw(grayimg/max(max(grayimg)),areapxlim(1));
    areabeadlabels=bwlabel(areabeadimg);
    areabeadstats=regionprops(areabeadlabels,'Area');
    areabeadA=[areabeadstats.Area];
    areabeadlarge=find(areabeadA>((2*pixrad)^2));

    areabeadimg=0*areabeadimg;
    for i=1:size(areabeadlarge,2)
        areabeadimg(areabeadlabels==areabeadlarge(i))=1;
    end

    % strip thresheld circles
    for i=1:size(circenin,1)
        if(darkbeadimg(round(circenin(i,2)),round(circenin(i,1)))==0)
            circenin(i,:)=NaN;
        end
    end
    circenin=circenin(find(~isnan(circenin(:,1))),:);

    for i=1:size(circenin,1)
        if(areabeadimg(round(circenin(i,2)),round(circenin(i,1)))==1)
            circenin(i,:)=NaN;
        end
    end
    circenin=circenin(find(~isnan(circenin(:,1))),:);

    circenout=circenin;
    
% Strip circle by restricting width of density peaks
function [circenout]=ConstrictPeakWidth(circen,rectsize,PixDim,mmbandwidth,mmwidth)

    [beadline,Rline,Lline,Rstat,Lstat,Rfitout,Lfitout,Rbeads,Lbeads]=GetBeadLines(circenin);
    pkmm = mmwidth;
    
    while( ((Rstat.rmse>1/PixDim(1)) || (Lstat.rmse>1/PixDim(1))) && pkmm>=1)
        [circen]=GetPeakBeads(circen,rectsize,PixDim,mmbandwidth,pkmm);
        [beadline,Rline,Lline,Rstat,Lstat,Rfitout,Lfitout,Rbeads,Lbeads]=GetBeadLines(circenin);
        
        pkmm = pkmm-0.5;
    end
    circenout = circen;
    
% Calculate distance between pts
function [Dcon]=RowDist(X)
    D = pdist(X,'euclidean');
    D = squareform(D);
    idx = sub2ind(size(D),[1:size(X,1)-1],[2:size(X,1)]);
    Dcon = D(idx)';
    
% Strip beads by average spacing
function [beadsout]=StripSpacing(beadsin,distin,PixDim)

    smallix = find(distin<(10/PixDim(2)));
    while(size(smallix,1)>0)
        meandist = mean(distin(distin>(10/PixDim(2)) & distin<(50/PixDim(2))));
        checkix = smallix(1);
        if(checkix==1)
            d1 = distin(checkix) + distin(checkix+1);
            d2 = distin(checkix+1);
            [~,closeix]=min(abs([d1,d2]-meandist));
            if(closeix==1 & d1 > (10/PixDim(2)))
                delix = checkix+1;
            elseif(closeix==1 & d1 <= (10/PixDim(2)))
                delix = checkix;
            else
                delix = checkix;
            end
        elseif(checkix==size(distin,1))
            d1 = distin(checkix-1);
            d2 = distin(checkix) + distin(checkix-1);
            [~,closeix]=min(abs([d1,d2]-meandist));
            if(closeix==1)
                delix = checkix+1;
            else
                delix = checkix;
            end
        else
            d1 = distin(checkix-1);
            d2 = distin(checkix+1);
            d3 = d1+d2;
            [~,closeix]=min(abs([d1,d2,d3]-meandist));
            if(closeix==1)
                delix = checkix+1;
            else
                delix = checkix;
            end
        end

        beadsin(delix,:)=[];
        distin = RowDist(beadsin);
        smallix = find(distin<(10/PixDim(2)));
    end
    beadsout=beadsin;
    
    % group beads into contigious sections
    function [beadR2,beadL2,beadR2alt,beadL2alt,avgrawR,avgrawL]=GroupBeads(Rbeads,Lbeads,Rdist,Ldist,PixDim)
        
        % find avg bead distances & discrepancies
        avgrawR=mean(Rdist(Rdist>(10/PixDim(2)) & Rdist<(50/PixDim(2))));
        avgrawL=mean(Ldist(Ldist>(10/PixDim(2)) & Ldist<(50/PixDim(2))));

        Rdistdiv=abs((Rdist-avgrawR)/avgrawR);
        Ldistdiv=abs((Ldist-avgrawL)/avgrawL);

        errbeadsR=find(Rdistdiv>0.5);
        errbeadsL=find(Ldistdiv>0.5);

        % find contiguous Right beads
        if(isempty(errbeadsR)) % all contiguous
            topbeadR=1;
            botbeadR=size(Rbeads,1);
        elseif(size(errbeadsR,1)==1) % 1 break in middle
            if(errbeadsR(1)<=size(Rbeads,1)/2)
                topbeadR=errbeadsR(1)+1;
                botbeadR=size(Rbeads,1);
                alttopR=1;
                altbotR=errbeadsR(1);
            end
            if(errbeadsR(1)>size(Rbeads,1)/2)
                topbeadR=1;
                botbeadR=errbeadsR(1);
                alttopR=errbeadsR(1)+1;
                altbotR=size(Rbeads,1);
            end
        elseif(size(errbeadsR,1)>1) % multiple breaks
            altok=0;
            indok=0;
            inddist=0;
            for bd=1:(size(errbeadsR,1)-1)
                bdind=errbeadsR(bd+1)-errbeadsR(bd);
                if(bdind>inddist && bdind>1)
                    altok=indok;
                    indok=bd;
                    inddist=bdind;
                end
            end
            if( (size(Rbeads,1)-errbeadsR(end))>inddist && (size(Rbeads,1)-errbeadsR(end))> 1)
                altok=indok;
                indok=size(errbeadsR,1);
                errbeadsR(indok+1)=size(Rbeads,1);
            end
            if( (errbeadsR(1))>inddist && (errbeadsR(1))> 1)
                altok=indok;
                indok=0;
            end
            if(indok~=0)
                topbeadR=errbeadsR(indok)+1;
                botbeadR=errbeadsR(indok+1);
            end
            if(indok==0)
                topbeadR=1;
                botbeadR=errbeadsR(1);
            end
            if(altok~=0)
                alttopR=errbeadsR(altok)+1;
                altbotR=errbeadsR(altok+1);
            end
            if(altok==0)
                alttopR=1;
                altbotR=errbeadsR(1);
            end
        end
        
        % save contigious beads
        beadR2=Rbeads(topbeadR:botbeadR,:);
        if(~isempty(errbeadsR))
            beadR2alt=Rbeads(alttopR:altbotR,:);
        else
            beadR2alt=[];
        end

        % find contiguous Left beads 
        if(isempty(errbeadsL)) % all contiguous
            topbeadL=1;
            botbeadL=size(Lbeads,1);
        elseif(size(errbeadsL,1)==1) % 1 break in middle
            if(errbeadsL(1)<=size(Lbeads,1)/2)
                topbeadL=errbeadsL(1)+1;
                botbeadL=size(Lbeads,1);
                alttopL=1;
                altbotL=errbeadsL(1);
            end
            if(errbeadsL(1)>size(Lbeads,1)/2)
                topbeadL=1;
                botbeadL=errbeadsL(1);
                alttopL=errbeadsL(1)+1;
                altbotL=size(Lbeads,1);
            end
        elseif(size(errbeadsL,1)>1) % multiple breaks
            altok=0;
            indok=0;
            inddist=0;
            for bd=1:(size(errbeadsL,1)-1)
                bdind=errbeadsL(bd+1)-errbeadsL(bd);
                if(bdind>inddist && bdind>1)
                    altok=indok;
                    indok=bd;
                    inddist=bdind;
                end
            end
            if( (size(Lbeads,1)-errbeadsL(end))>inddist && (size(Lbeads,1)-errbeadsL(end))> 1)
                altok=indok;
                indok=size(errbeadsL,1);
                errbeadsL(indok+1)=size(Lbeads,1);
            end
            if( (errbeadsL(1))>inddist && (errbeadsL(1))> 1)
                altok=indok;
                indok=0;
            end
            if(indok~=0)
                topbeadL=errbeadsL(indok)+1;
                botbeadL=errbeadsL(indok+1);
            end
            if(indok==0)
                topbeadL=1;
                botbeadL=errbeadsL(1);
            end
            if(altok~=0)
                alttopL=errbeadsL(altok)+1;
                altbotL=errbeadsL(altok+1);
            end
            if(altok==0)
                alttopL=1;
                altbotL=errbeadsL(1);
            end
        end
        
        % save contigious beads
        beadL2=Lbeads(topbeadL:botbeadL,:);
        if(~isempty(errbeadsL))
            beadL2alt=Lbeads(alttopL:altbotL,:);
        else
            beadL2alt=[];
        end