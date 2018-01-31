function [prefill_out,acc_out,destdir, tagmod]=Blind_Recd_XR(dcmdir_in,dcm_inven)
% Blind and clean up XRs

warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

% define static folders/files
dpvr_file = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\DPVR\most_inven.mat'; % prior visit scores
acc_file = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\DPVR\accnum.mat'; % last used accession number
mostroot = 'E:\MOST-KXR\IDENTIFIED\'; % MOST-DICOM RELEASED files
destroot = 'E:\MOST-Renewal-II\XR\BLINDING\For_QC\TEMP_BLINDED\';

% define and load parameters
prefill_out = {};
acc_out = {};
tagmod = {};

load(dpvr_file,'most_inven','KXRdata');
load(acc_file,'accnum');
disp(horzcat('Starting new barcodes at: ',zerofillstr(accnum+1,4)));



%parse folder path
[~,dn,~]=fileparts(dcmdir_in);
destdir = horzcat(destroot,dn,'\');
mkdir(destdir);

%% organize according to ID & XR view
unq_ids = unique(dcm_inven(:,3));

for ix=1:size(unq_ids,1) % for each ID...
    
    tmpid = unq_ids{ix,1}; %parse the true MOST ID
    trueid = regexp(tmpid,'M[BI][0-9]{5}','match');
    if(~isempty(trueid))
        trueid = trueid{1};
    else
        trueid = regexp(strrep(upper(tmpid),'O','0'),'M[BI][0-9]{5}','match');
        if(~isempty(trueid))
            trueid = trueid{1};
        else
            trueid = tmpid;
        end
    end
    
    kx = indcfind(most_inven(:,1),trueid,'regexpi'); %name
    if(~isempty(kx))
        tmpname = most_inven{kx(1),2};
        old_cohort = 1;
    else
        tmpname = '';
        old_cohort = 0;
    end
    jx = indcfind(dcm_inven(:,3),tmpid,'regexpi'); %series
    tmpstudy = dcm_inven(jx,:);
    unq_series = unique(cell2mat(tmpstudy(:,10)));
    
    %misc view series
    misc_se = find(cell2mat(tmpstudy(:,10))>7);
    
    %GROUP ALL PA VIEWS TOGETHER
    if(size(find(unq_series<4),1)<1)
        loop_series = unq_series;
        loop_series = [loop_series; setdiff([1;4;5],loop_series)];
    elseif(size(find(unq_series<4),1)>1)
        loop_series = [1; unq_series(find(unq_series>3))];
        loop_series = [loop_series; setdiff([4;5],loop_series)];
    else
        loop_series = unq_series;
        loop_series = [loop_series; setdiff([4;5],loop_series)];
    end
    

    %create new accession number root
    accnum = accnum+1;
    tmpacc1 = zerofillstr(accnum,4);
    tmpacc1 = horzcat('6',tmpacc1);
    
    for jx_se = 1:size(loop_series,1) % for each series in study...
        
        %get all images that are same XR view series
        this_se = loop_series(jx_se,1);
        if(this_se==1) %get other PA views too
            pa1_se = find(cell2mat(tmpstudy(:,10))==1);
            pa2_se = find(cell2mat(tmpstudy(:,10))==2);
            pa3_se = find(cell2mat(tmpstudy(:,10))==3);
            all_se = [pa1_se; pa2_se; pa3_se];
        else
            all_se = find(cell2mat(tmpstudy(:,10))==this_se);
        end
        
        %add misc series since we don't what they are
        tmpseries = tmpstudy([all_se; misc_se],:);
        
        if(~isempty(tmpseries))
            %get info from first file
            tmprow = tmpseries(1,:);
            tmpf = tmprow{1,2};
            tmpse = tmprow{1,10};

            tmpinfo = dicominfo(tmpf);
            tmpdate = tmpinfo.StudyDate;

            if(isempty(tmpname))
                tmpnamefields = fieldnames(tmpinfo.PatientName);
                for fx=1:size(tmpnamefields,1)
                    tmpname = horzcat(tmpname,tmpinfo.PatientName.(tmpnamefields{fx}));
                end
            end

            if(isfield(tmpinfo,'SeriesDescription'))
                tmp_desc = tmpinfo.SeriesDescription;
            else
                tmp_desc = '';
            end
        else
            tmprow = tmpstudy(1,:);
            tmpf = tmprow{1,2};
            tmpinfo = dicominfo(tmpf);
            tmpdate = tmpinfo.StudyDate;
            
            tmpse = this_se;
        end
        
        switch tmpse
            case 1
                new_desc = 'PA10';
                prev_str = 'Bilateral PA Fixed Flexion';
            case 2
                new_desc = 'PA15';
                prev_str = 'Bilateral PA Fixed Flexion';
            case 3
                new_desc = 'PA05';
                prev_str = 'Bilateral PA Fixed Flexion';
            case 4
                new_desc = 'LLAT';
                prev_str = 'Left Lateral Knee';
            case 5
                new_desc = 'RLAT';
                prev_str = 'Right Lateral Knee';
%             case 6
%                 new_desc = 'Full Limb';
%                 prev_str = 'Full Limb';
            otherwise
                new_desc = tmp_desc;
                prev_str = '$';
        end
        
        %create series accession number 6AAAAB
        tmpacc2 = horzcat(tmpacc1,num2str(tmpse));
        newd = horzcat(destdir,trueid,'_',tmpname,'\',tmpacc2);
        if(~exist(newd))
            mkdir(newd);
        end
        
        %create new StudyInstanceUID
        newstudyuid = dicomuid;
        
        %collect previous visit XRs if old cohort
        flist = tmpseries(:,2);
        flist = [flist, repcell([size(flist,1),1],new_desc), repcell([size(flist,1),1],'1')];
        
        if(old_cohort==1)
            idx = indcfind(KXRdata(:,2),trueid,'regexpi');
            
            pvlist = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('84M.*',prev_str),'regexpi')),1);
            pvdesc = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('84M.*',prev_str),'regexpi')),6);
            if(~isempty(pvlist))
                flist = [flist; [pvlist, pvdesc, repcell(size(pvlist),'0')]];
            end

            pvlist = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('60M.*',prev_str),'regexpi')),1);
            pvdesc = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('60M.*',prev_str),'regexpi')),6);
            if(~isempty(pvlist))
                flist = [flist; [pvlist, pvdesc, repcell(size(pvlist),'0')]];
            end
            
            pvlist = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('30M.*',prev_str),'regexpi')),1);
            pvdesc = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('30M.*',prev_str),'regexpi')),6);
            if(~isempty(pvlist))
                flist = [flist; [pvlist, pvdesc, repcell(size(pvlist),'0')]];
            end

            pvlist = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('15M.*',prev_str),'regexpi')),1);
            pvdesc = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('15M.*',prev_str),'regexpi')),6);
            if(~isempty(pvlist))
                flist = [flist; [pvlist, pvdesc, repcell(size(pvlist),'0')]];
            end

            pvlist = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('BL.*',prev_str),'regexpi')),1);
            pvdesc = KXRdata(intersect(idx,indcfind(KXRdata(:,6),horzcat('BL.*',prev_str),'regexpi')),6);
            if(~isempty(pvlist))
                flist = [flist; [pvlist, pvdesc, repcell(size(pvlist),'0')]];
            end
        end
        
        %rename descriptions for BL-84m
        flist(indcfind(flist(:,2),'- 5 degrees caudal$','regexpi'),2) = {'PA05'};
        flist(indcfind(flist(:,2),'- 10 degrees caudal$','regexpi'),2) = {'PA10'};
        flist(indcfind(flist(:,2),'- 15 degrees caudal$','regexpi'),2) = {'PA15'};
        flist(indcfind(flist(:,2),'Left Lateral Knee$','regexpi'),2) = {'LLAT'};
        flist(indcfind(flist(:,2),'Right Lateral Knee$','regexpi'),2) = {'RLAT'};
        
        % collect prefiller data
        prefill_out{end+1,1} = trueid;
        prefill_out{end,2} = tmpname;
        prefill_out{end,3} = tmpdate;
        prefill_out{end,4} = tmpse;
        prefill_out{end,5} = size(tmpseries,1);
        prefill_out{end,6} = size(flist,1);
        prefill_out{end,7} = tmpacc2;
        prefill_out{end,8} = new_desc;
        
        disp(prefill_out(end,:));
        
        % copy/process all XRs for this ID & view %
        for fx=1:size(flist,1)
            
            %copy file w/ new file name 6AAAABCC
            tmpf = flist{fx,1};
            tmpdesc = flist{fx,2};
            tmpinfo = dicominfo(tmpf);
            
            newf = horzcat(newd,'\',tmpacc2,zerofillstr(fx,2));
            tmpacc3 = horzcat(tmpacc2,zerofillstr(fx,2));
            new_desc2 = horzcat(tmpdesc,' ',tmpacc3);
            
            if(~exist(newf))
                copyfile(tmpf,newf,'f');
                tmpinfo = dicominfo(newf);
            else
                disp('Filename already exists!');
                disp(newf);
                return;
            end
            
            [status,result] = dcmdjpeg(newf,newf); if(status~=0); disp('decompression error!'); disp(result); disp(tmpf); disp(newf); return; end;
%             [status,result] = dcmerasetag(newf,'(0012,0030)');
%             [status,result] = dcmerasetag(newf,'(0008,0008)');
            [status,result] = dcmbatchmod(newf,{'(0012,0030)','','e';'(0008,0008)','','e'});
            
            try
            dicomanon(newf,newf,'keep',{'PatientID','PatientName','AccessionNumber','SeriesNumber','StudyDescription','SeriesDescription','StudyID','StudyInstanceUID','SeriesInstanceUID','SOPInstanceUID'});
            catch anonerr
                disp(anonerr);
                err_img = dicomread(newf);
                err_info = dicominfo(newf);
                dicomwrite(err_img,newf);
            end
            
%             [status,result] = dcmhardmod(newf,'(0010,0010)',horzcat(tmpname,'^^^^'),'i');   if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0010,0020)',tmpid,'i');     if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0008,0050)',tmpacc2,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0020,0011)',zerofillstr(fx,2),'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0008,1030)',tmpacc2,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0008,103E)',new_desc2,'i');  if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0020,000D)',newstudyuid,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             [status,result] = dcmhardmod(newf,'(0020,0010)',tmpacc3,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%             
%             
%             
%                 
%             [status,result] = dcmhardmod(newf,'(0008,0018)',tmpinfo.SOPInstanceUID,'i'); if(status~=0); disp('SOPInstanceUID error!'); disp(newf); return; end;
            
            tagcell = {...
            '(0010,0010)',horzcat(tmpname,'^^^^'),'i';...
            '(0010,0020)',trueid,'i';...
            '(0008,0050)',tmpacc2,'i';...
            '(0020,0011)',zerofillstr(fx,2),'i';...
            '(0008,1030)',tmpacc2,'i';...
            '(0008,103E)',new_desc2,'i';...
            '(0020,000D)',newstudyuid,'i';...
            '(0020,0010)',tmpacc3,'i';...
            '(0008,0018)',tmpinfo.SOPInstanceUID,'i';...
            '','','imt';...
            };
            tagmod = [tagmod; tagcell];

            [status,result] = dcmbatchmod(newf,tagcell);
            
            try
                [status,result] = FixXR(newf,tmpinfo); 
            catch
                try
                    pause(15);
                    [status,result] = FixXR(newf,tmpinfo);
                catch
                    status = -1;
                end
            end
            if(status(1)~=0)
                disp('photometric error!'); 
                disp(newf); 
            end
            
            [status,result] = dcmcjpeg(newf,newf); 
                if(status~=0); disp('compression error!'); disp(result); disp(tmpf); disp(newf); end;
            
            %append new XRs to acc_out
            if(strcmpi(flist{fx,3},'1'))
                acc_out = [acc_out; {trueid, tmpacc3, tmpacc2, tmpse, tmpdesc, tmpdate, tmpinfo.SOPInstanceUID}];
            end
            
        end
    end
    delbak(destdir);
end
        
delbak(destdir);
save(acc_file,'accnum');
save(horzcat('MOST_QC_BLIND_',datestr(now,'yyyymmdd'),'.mat'));


