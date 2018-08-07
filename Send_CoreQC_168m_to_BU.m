function Send_CoreQC_168m_to_BU()
%% function to send XRs for QC

%% initialize
disp(' ');
disp('Initializing...');

% parameters
dvd_date = datestr(now,'yyyymmdd');

% mdbf
mdbf_qc = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

% get scoresheet template
template_dir = 'S:\FelixTemp\XR\Scoresheet_Templates\QC';
[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

% set up directories
output_dir = 'E:\most-dicom\XR_QC\Sent\QC';
final_destination = '\\most-ftps\MOSTFTPS\SITE03\XR\DOWNLOAD\QC';

batch_dir = horzcat(output_dir,'\Batches\Batch_',dvd_date);
mdbf = horzcat(output_dir,'\Scoresheets\MOST_XR_QC_',dvd_date,'.mdb');
final_dir = horzcat(final_destination,'\DICOM\',dvd_date);
final_mdbf = horzcat(final_destination,'\MOST_XR_QC_',dvd_date,'.mdb');

if(~exist(batch_dir,'dir')) % continue if this batch hasn't been made

  disp(' ');
  disp(horzcat('Processing batch: ',dvd_date));

  disp(' ');
  disp(horzcat('Reading data from database: ',mdbf_qc));
  
  % query for blinded images that have not been sent
  [x_send,f_send] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMQC WHERE (Send_flag=0)'); %flag 0 for 144m, flag 2 for 168m
  pause(1);
  
  % filter for core X-ray sequences only
  x_send = x_send(indcfind(x_send(:,indcfind(f_send,'^View$','regexpi')),'^(PA|LLAT|RLAT|BL Visit|15M Visit|30M Visit|60M Visit|84M Visit)','regexpi'),:);

  % stop if no images to send
  if(size(x_send,2)<2)
    disp('No images to send.');
    return;
  end
  
  % filter by tracking form data
  [xa03,fa03] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblmatched_kxr_tf');
  xa03(:,indcfind(fa03,'^a03recordid$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03recordid$','regexpi')),'UniformOutput',0);
  xa03(:,indcfind(fa03,'^a03visit$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03visit$','regexpi')),'UniformOutput',0);
  xa03(:,indcfind(fa03,'^a03exmnm$','regexpi'))   = cellfun(@num2str,xa03(:,indcfind(fa03,'^a03exmnm$','regexpi')),'UniformOutput',0);

  xa03final = xa03(indcfind(xa03(:,indcfind(fa03,'^a03visit$','regexpi')),'5','regexpi'),:);
  xa03final = xa03final(indcfind(xa03final(:,indcfind(fa03,'^a03exmnm$','regexpi')),'[1-9]','regexpi'),:);
  
  unique_TF_IDs = unique(xa03final(:,indcfind(fa03,'^a03id$','regexpi')));

  x_send = x_send(ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_TF_IDs),:);
  
  unique_tosend_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
  
  % filter for 144m XRs that have been previously sent

  [x_sent,f_sent] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMQC WHERE (Send_flag=5)'); % flag 5 for 144m reblinded for 168m pairing
  pause(1);

  x_sent = x_sent(ismember(x_sent(:,indcfind(f_sent,'^PatientID$','regexpi')),unique_tosend_IDs),:);
  
  % stop if no images to send
  if(size(x_send,1)<1)
    disp('No images to send.');
    return;
  end  
  
  % combine 144m and 168m XRs
  x_send = [x_send; x_sent];


  % filter out exit_code errors %
  del_ix = [];
  for fx=1:size(x_send,1)
    tmp_exitcode = x_send{fx,indcfind(f_send,'exit_code','regexpi')};
    if(tmp_exitcode>0)
      del_ix = [del_ix; fx];
    end
  end
  if(size(del_ix,1)>0)
    x_send(del_ix,:) = [];
  end

  % stop if no images to send
  if(size(x_send,1)<1)
    return;
  end
  
  unique_send_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
  
  disp(' ');
  disp(horzcat('# of total IDs with X-rays to send: ',num2str(size(unique_send_IDs,1))));

  % limit how many new XRs to send
  lim_num = 35;
  if(size(unique_send_IDs,1)>lim_num)
      x_send = x_send(ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_send_IDs(1:lim_num)),:);
      
      unique_send_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
      
      disp(' ');
      disp(horzcat('Limiting # of total IDs with X-rays to send: ',num2str(size(unique_send_IDs,1))));
  end


  % collect all files to send
  x_up = {};
  x_up = x_send;

  if(size(x_up,1)>0) % continue if there are any IDs to send
      
    % create batching directory
    mkdir(batch_dir);

    % create scoresheet file
    copyfile(mdbf_template,mdbf);

    % column indices
    f_filename = indcfind(f_send,'^filename$','regexpi');
    f_SOPInstanceUID = indcfind(f_send,'^SOPInstanceUID$','regexpi');
    f_PatientID = indcfind(f_send,'^PatientID$','regexpi');
    f_PatientName = indcfind(f_send,'^PatientName$','regexpi');
    f_StudyDate = indcfind(f_send,'^StudyDate$','regexpi');
    f_View = indcfind(f_send,'^View$','regexpi');
    f_StudyBarcode = indcfind(f_send,'^StudyBarcode$','regexpi');
    f_SeriesBarcode = indcfind(f_send,'^SeriesBarcode$','regexpi');
    f_FileBarcode = indcfind(f_send,'^FileBarcode$','regexpi');

    % copy files to batching dir
    disp(' ');
    disp('Copying DICOM files.');
    
    for fx=1:size(x_up,1)

      tmpf = x_up{fx,f_filename};
      tmpid = x_up{fx,f_PatientID};
      tmpname = x_up{fx,f_PatientName};
      tmpstudybc = x_up{fx,f_StudyBarcode};
      tmpfilebc = x_up{fx,f_FileBarcode};

      newdir = horzcat(batch_dir,'\',tmpid,'_',tmpname,'\',tmpstudybc);
      newf = horzcat(newdir,'\',tmpfilebc);

      if(~exist(newdir,'dir'))
        mkdir(newdir);
      end

      copyfile(tmpf,newf);

    end

    disp(' ');
    disp('Insert scoresheet records for new X-rays.');
    
    % get IDs for sending as blank records
    prefill_up = x_up;

    % Insert new blank records into scoresheet
    InsertScoresheet_NewQC(mdbf,prefill_up,f_send,dvd_date);

    %% Send files to Reader
    
    % copy to MOST-FTPS
    disp(' ');
    disp('Send files to Reader');
    copyfile(batch_dir,final_dir);
    copyfile(mdbf,final_mdbf);

    % Update send_flags in database
    disp(' ');
    disp('Update tblDICOMQC flags in database');
    if(size(x_send,1)>0)
      % update tblDICOMQC send_flags
      flag_cell = cell(size(x_send,1),1);
      
      existing_flags = cell2mat(x_send(:,indcfind(f_send,'Send_flag','regexpi'))); %get existing flags
      flag_cell(:) = {1}; %prefill with ones
      flag_cell(existing_flags==2) = {4}; %change prior visit flags (2) to sent flag (4)

      where_cell = x_send(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblDICOMQC',{'send_flag'},flag_cell,{'SOPInstanceUID'},where_cell,1);
    end
    
  end
  
else
    disp(' ');
    disp('Batch has already been processed.');
end %if batch dir does not exist yet
