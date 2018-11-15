%% function for blinding and processing paired 144m & 168m DICOM XRs

%% turn off warnings
warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

%% initialize

f_up_qc = {'filename','SOPInstanceUID','PatientID','PatientName','StudyDate','View','StudyBarcode','SeriesBarcode','FileBarcode','Exit_code','Send_flag'};

%% set up directories

%database
mdbf = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

%output dir
dcmdir_out = 'E:\most-dicom\XR_QC\168m';
dcmdir_out_qc = horzcat(dcmdir_out,'\QC');

%% initialize
savef = horzcat(dcmdir_out,'\MOST_XR_BLIND_',datestr(now,'yyyymmddHHMMSS'),'.mat');

% % accession numbers
[x_acc,f_acc] = DeployMDBquery(mdbf,'SELECT * FROM tblAccessionQC');
pause(1);
x_acc = x_acc(indcfind(x_acc(:,indcfind(f_acc,'^SERIESDESC$','regexpi')),'^(PA|PA05|PA10|PA15|LLAT|RLAT)$','regexpi'),:);

% query for raw files
[x_category,f_category] = DeployMDBquery(mdbf,'SELECT * FROM tblFilesCategory');
pause(1);

% query for blinded images that have not been sent
[x_send,f_send] = DeployMDBquery(mdbf,'SELECT * FROM tblDICOMQC WHERE (Send_flag=0)'); %flag 0 for new 144m/168m, flag 2 for 0-84m (for solo 168m), flag 5 for 144m (for paired 168m)
pause(1);
if(size(x_send,2)<11)
    x_send = cell(1,length(f_send));
    x_send{1,indcfind(f_send,'^PatientID$','regexpi')} = '';
end
x_send = x_send(indcfind(x_send(:,indcfind(f_send,'^View$','regexpi')),'^(PA|PA05|PA10|PA15|LLAT|RLAT)$','regexpi'),:);

if(~isempty(x_send))

    % query for blinded images that already blinded for paired 144m & 168m
    [x_sent,f_sent] = DeployMDBquery(mdbf,'SELECT * FROM tblDICOMQC WHERE (Send_flag=5)'); %flag 0 for new 144m/168m, flag 2 for 0-84m (for solo 168m), flag 5 for 144m (for paired 168m)
    pause(1);
    if(size(x_sent,2)<11)
        x_sent = cell(1,length(f_sent));
        x_sent{1,indcfind(f_sent,'^PatientID$','regexpi')} = '';
    end

    % query for best 144m images
    [x_best,f_best] = DeployMDBquery(mdbf,'SELECT * FROM tblBestImages144m');
    pause(1);

    % filter by tracking form data
    [xa03,fa03] = DeployMDBquery(mdbf,'SELECT * FROM tblmatched_kxr_tf');
    xa03(:,indcfind(fa03,'^a03recordid$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03recordid$','regexpi')),'UniformOutput',0);
    xa03(:,indcfind(fa03,'^a03visit$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03visit$','regexpi')),'UniformOutput',0);
    xa03(:,indcfind(fa03,'^a03exmnm$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03exmnm$','regexpi')),'UniformOutput',0);

    xa03final = xa03(indcfind(xa03(:,indcfind(fa03,'^a03visit$','regexpi')),'5','regexpi'),:);
    xa03final = xa03final(indcfind(xa03final(:,indcfind(fa03,'^a03exmnm$','regexpi')),'[1-9]','regexpi'),:);

    unique_TF_IDs = unique(xa03final(:,indcfind(fa03,'^a03id$','regexpi')));
    x_send = x_send(ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_TF_IDs),:);


    % filter for 144m & 168m pairs
    unique_tosend_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
    unique_tosend_IDs = unique(intersect(unique_tosend_IDs,x_acc(:,indcfind(f_acc,'^READINGID$','regexpi'))));

    % filter out previously blinded 144m & 168m pairs
    unique_tosend_IDs = unique(setdiff(unique_tosend_IDs,unique(x_sent(:,indcfind(f_sent,'^PatientID$','regexpi'))) ));

    x_send =    x_send(ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_tosend_IDs),:);
    x_acc =     x_acc(ismember(x_acc(:,indcfind(f_acc,'^READINGID$','regexpi')),unique_tosend_IDs),:);
    x_best =    x_best(ismember(x_best(:,indcfind(f_best,'^mostid$','regexpi')),unique_tosend_IDs),:);

    unique_tosend_SOPs = unique(x_best(:,indcfind(f_best,'^SOPINSTANCEUID$','regexpi')));
    x_category = x_category(ismember(x_category(:,indcfind(f_category,'^SOPInstanceUID$','regexpi')),unique_tosend_SOPs),:);

end

%% process and blind all new 144m & 168m paired XRs for QC
disp(' ');
disp('Blind new 144m/168m paired X-ray images');

x_unprocessed = x_send;
f_unprocessed = f_send;

f_filename = indcfind(f_unprocessed,'^filename$','regexpi');
f_SOPInstanceUID = indcfind(f_unprocessed,'^SOPInstanceUID$','regexpi');
f_PatientID = indcfind(f_unprocessed,'^PatientID$','regexpi');
f_PatientName = indcfind(f_unprocessed,'^PatientName$','regexpi');
f_StudyDate = indcfind(f_unprocessed,'^StudyDate$','regexpi');
f_StudyBarcode = indcfind(f_unprocessed,'^StudyBarcode$','regexpi');
f_View = indcfind(f_unprocessed,'^View$','regexpi');
f_StudyBarcode = indcfind(f_unprocessed,'^StudyBarcode$','regexpi');

if(size(x_unprocessed,1)>0)

    unq_ids = unique(x_unprocessed(:,f_PatientID));

    disp(' ');
    disp(horzcat('# of IDs to blind: ',num2str(size(unq_ids,1))));

    for ix=1:size(unq_ids,1) % loop through each ID

        tmpid = unq_ids{ix,1};

        disp(ix);
        disp(tmpid);

        % get a single XR exam by ID and date
        tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,f_PatientID),tmpid,'regexpi'),:);
        tmpstudydate = tmpstudy{1,f_StudyDate};
        tmpbarcode = tmpstudy{1,f_StudyBarcode};
        tmpstudy = tmpstudy(indcfind(tmpstudy(:,f_StudyDate),tmpstudydate,'regexpi'),:);
        tmpstudy = sortrows(tmpstudy,[f_View, f_StudyDate, f_SOPInstanceUID, f_filename]);

        % get patient name
        tmpname = tmpstudy{1,f_PatientName};

        % reblind the study for paired 144m/168m QC
        [tmpstudy_144m_reblinded, tmpstudy_168m_reblinded]=Blind_144m_168m_Paired_XR_Study(dcmdir_out_qc,tmpid,tmpstudy,f_unprocessed,x_best,f_best,x_category,f_category);
        % Update 168m processed files to MDB
        if(size(tmpstudy_168m_reblinded,1)>0)
            UpdateMDB_WhereIs(mdbf,'tblDICOMQC',{'filename'},tmpstudy_168m_reblinded(:,indcfind(f_send,'^filename$','regexpi')),{'SOPInstanceUID'},tmpstudy_168m_reblinded(:,indcfind(f_send,'^SOPInstanceUID$','regexpi')),1);
        end
        % Upload 144m processed files to MDB
        if(size(tmpstudy_144m_reblinded,1)>0)
            UploadToMDB(mdbf,'tblDICOMQC',f_up_qc,tmpstudy_144m_reblinded);
        end

    end %ix
    
else
    
    disp('No new films to blind.');
    
end %if


%% save .mat file
save(savef);

