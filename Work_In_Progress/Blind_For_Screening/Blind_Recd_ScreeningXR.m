function [prefill_out,acc_out,destdir, tagmod]=Blind_Recd_ScreeningXR(dcmdir_in,dcm_inven)
% Blind and clean up XRs

warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

% define static folders/files
acc_file = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\DPVR\screening_accnum.mat'; % last used accession number
destroot = 'E:\MOST-Renewal-II\XR\BLINDING\For_Screening\TEMP_BLINDED\';

% define and load parameters
prefill_out = {};
acc_out = {};

load(acc_file,'accnum');
disp(horzcat('Starting new barcodes at: ',zerofillstr(accnum+1,4)));

tagmod = {};

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
    
    truename = regexp(tmpid,'_[A-Z]{4}','match'); %parse the true MOST ACROSTIC
    if(~isempty(truename))
        truename = truename{1};
        truename = truename(2:end);
    else
        truename = regexp(tmpid,'[A-Z]{4}','match');
        if(~isempty(truename))
            truename = truename{1};
        else
            truename = 'XXXX';
        end
    end
    
    jx = indcfind(dcm_inven(:,3),tmpid,'regexpi'); %get study
    tmpstudy = dcm_inven(jx,:);
    tmpstudy = sortrows(tmpstudy,10);
    
    %create new accession number root
    accnum = accnum+1;
    tmpacc1 = zerofillstr(accnum,4);
    tmpacc1 = horzcat('F',tmpacc1);
    
    %create new StudyInstanceUID
    newstudyuid = dicomuid;
    
    newd = horzcat(destdir,trueid,'_',truename,'\',tmpacc1);
    if(~exist(newd))
        mkdir(newd);
    end
    
    flist = {};
    
    % loop through each XR view
    for jx_se = 1:size(tmpstudy,1)
        
        tmprow = tmpstudy(jx_se,:);
        tmpf = tmprow{1,2};
        this_se = tmprow{1,10};
        tmpse = this_se;
        
        tmpinfo = dicominfo(tmpf);
        tmpdate = tmpinfo.StudyDate;
        
        if(isfield(tmpinfo,'SeriesDescription'))
            tmp_desc = tmpinfo.SeriesDescription;
        else
            tmp_desc = '';
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
            case 44
                new_desc = 'LLAT';
                prev_str = 'Left Lateral Knee';
            case 5
                new_desc = 'RLAT';
                prev_str = 'Right Lateral Knee';
%             case 6
%                 new_desc = 'Full Limb';
%                 prev_str = 'Full Limb';
            case 6
                new_desc = '';
                prev_str = '$';
            otherwise
                new_desc = tmp_desc;
                prev_str = '$';
        end
        
        %create series accession number FAAAAB
        tmpacc2 = horzcat(tmpacc1,num2str(tmpse));
        
        flist{jx_se,1} = tmpf;
        flist{jx_se,2} = new_desc;
        flist{jx_se,3} = '1';
        flist{jx_se,4} = this_se;
        flist{jx_se,5} = tmpacc1;
        flist{jx_se,6} = tmpacc2;
        
        % collect prefiller data
        prefill_out{end+1,1} = trueid;
        prefill_out{end,2} = truename;
        prefill_out{end,3} = tmpdate;
        prefill_out{end,4} = tmpse;
        prefill_out{end,5} = size(tmpstudy,1);
        prefill_out{end,6} = size(tmpstudy,1);
        prefill_out{end,7} = tmpacc2;
        prefill_out{end,8} = new_desc;
        
        disp(prefill_out(end,:));
    end
        
    % copy/process all XRs for this ID
    for fx=1:size(flist,1)

        %copy file w/ new file name FNNNN
        tmpf = flist{fx,1};
        tmpinfo = dicominfo(tmpf);
        
        tmpdesc = flist{fx,2};
        tmpse = flist{fx,4};
        tmpacc1 = flist{fx,5};
        tmpacc2 = flist{fx,6};
        tmpacc3 = horzcat(tmpacc2,zerofillstr(fx,2));
        
        new_se = horzcat(num2str(tmpse),zerofillstr(fx,2));

        newf = horzcat(newd,'\',zerofillstr(fx,3));
        new_desc2 = horzcat(tmpdesc,' ',tmpacc3);

        if(~exist(newf))
            copyfile(tmpf,newf,'f');
        else
            disp('Filename already exists!');
            disp(newf);
            return;
        end
            
        [status,result] = dcmdjpeg(newf,newf); if(status~=0); disp('decompression error!'); disp(result); disp(tmpf); disp(newf); return; end;
        [status,result] = dcmerasetag(newf,'(0012,0030)');
        [status,result] = dcmerasetag(newf,'(0008,0008)');

        try
            dicomanon(newf,newf,'keep',{'PatientID','PatientName','AccessionNumber','SeriesNumber','StudyDescription','SeriesDescription','StudyID','StudyInstanceUID','SeriesInstanceUID','SOPInstanceUID'});
        catch anonerr
            disp(anonerr);
            err_img = dicomread(newf);
            err_info = dicominfo(newf);
            dicomwrite(err_img,newf);
        end

%         [status,result] = dcmhardmod(newf,'(0010,0010)',horzcat(truename,'^^^^'),'i');   if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0010,0020)',trueid,'i');     if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0008,0050)',tmpacc2,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0020,0011)',new_se,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0008,1030)',tmpacc2,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0008,103E)',new_desc2,'i');  if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0020,000D)',newstudyuid,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;
%         [status,result] = dcmhardmod(newf,'(0020,0010)',tmpacc3,'i');    if(status~=0); disp('dcmodify error!'); disp(newf); return; end;

        tagcell = {...
            '(0010,0010)',horzcat(truename,'^^^^'),'i';...
            '(0010,0020)',trueid,'i';...
            '(0008,0050)',tmpacc1,'i';...
            '(0020,0011)',new_se,'i';...
            '(0008,1030)',tmpacc2,'i';...
            '(0008,103E)',new_desc2,'i';...
            '(0020,000D)',newstudyuid,'i';...
            '(0020,0010)',tmpacc3,'i';...
            '(0008,0018)',tmpinfo.SOPInstanceUID,'i';...
            '','','imt';...
            };
        tagmod = [tagmod; tagcell];
        
        [status,result] = dcmbatchmod(newf,tagcell);
        retry = 1;
        while(status~=0 && retry<10)
            pause(10);
            [status,result] = dcmbatchmod(newf,tagcell);
            retry = retry+1;
        end
 
%         [status,result] = dcmhardmod(newf,'(0008,0018)',tmpinfo.SOPInstanceUID,'i'); if(status~=0); disp('SOPInstanceUID error!'); disp(newf); return; end;
               
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
        [status,result] = dcmcjpeg(newf,newf); if(status(1)~=0); disp('compression error!'); disp(result); disp(tmpf); disp(newf); end;

        %append new XRs to acc_out
        if(strcmpi(flist{fx,3},'1'))
            acc_out = [acc_out; {trueid, tmpacc3, tmpacc2, tmpse, tmpdesc, tmpdate, tmpinfo.SOPInstanceUID}];
        end
            
    end
end
        
delbak(destdir);
save(acc_file,'accnum');
save(horzcat('MOST_SCREEN_BLIND_',datestr(now,'yyyymmdd'),'.mat'));


