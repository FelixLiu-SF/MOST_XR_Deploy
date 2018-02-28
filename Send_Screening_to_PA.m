function Send_Screening_to_PA()
%% function to send XRs for screening

%% initialize
disp(' ');
disp('Initializing...');

% parameters
dvd_date = datestr(now,'yyyymmdd');

% mdbf
mdbf_qc = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

% get scoresheet template
template_dir = 'S:\FelixTemp\XR\Scoresheet_Templates\ScreeningPA_Templates';
[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

% set up directories
output_dir = 'E:\most-dicom\XR_QC\Sent\Screening';
final_destination = 'E:\Program Files\Box Sync\OAI_XR_ReaderA\MOST';

batch_dir = horzcat(output_dir,'\Batches\Batch_',dvd_date);
mdbf = horzcat(output_dir,'\Scoresheets\MOST_XR_ScreeningPA_',dvd_date,'.mdb');
final_dir = horzcat(final_destination,'\DICOM\',dvd_date);
final_mdbf = horzcat(final_destination,'\Scoresheets\MOST_XR_ScreeningPA_',dvd_date,'.mdb');

if(~exist(batch_dir,'dir')) % continue if this batch hasn't been made
    
  disp(' ');
  disp(horzcat('Processing batch: ',dvd_date));

  disp(' ');
  disp(horzcat('Reading data from database: ',mdbf_qc));
  
  % query for blinded images that have not been sent
  [x_send,f_send] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMScreening WHERE Send_flag=0');
  pause(1);

  % stop if no images to send
  if(size(x_send,2)<2)
    return;
  end

  % filter out IDs that have been previously sent
  [x_sent,f_sent] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMScreening WHERE send_flag BETWEEN 1 and 2'); % flag 1 for PA, flag 2 for DF
  pause(1);
  unique_sent_IDs = unique(x_sent(:,indcfind(f_sent,'^PatientID$','regexpi')));

  x_send = x_send(~ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_sent_IDs),:);

  % stop if no images to send
  if(size(x_send,1)<1)
    return;
  end

  % filter out exit_code errors %
  del_ix = [];
  for fx=1:size(x_send,1)
    tmp_exitcode = x_send{fx,indcfind(f_send,'exit_code','regexpi')};
    if(tmp_exitcode>0)
      del_ix = [del_ix; fx];
    end
  end
  if(size(del_ix,1)>0)
    x_up(del_ix,:) = [];
  end

  % stop if no images to send
  if(size(x_send,1)<1)
    return;
  end
  
  unique_send_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
  
  disp(' ');
  disp(horzcat('# of total IDs with X-rays to send: ',num2str(size(unique_send_IDs,1))));

  % limit how many new XRs to send
  lim_num = 20;
  if(size(unique_send_IDs,1)>lim_num)
      x_send = x_send(ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_send_IDs(1:lim_num)),:);
      
      unique_send_IDs = unique(x_send(:,indcfind(f_send,'^PatientID$','regexpi')));
      
      disp(' ');
      disp(horzcat('Limiting # of total IDs with X-rays to send: ',num2str(size(unique_send_IDs,1))));
  end
  
  

  % query for adjudication review
  [x_adj,f_adj] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblSendAdj WHERE send_flag=0');
  pause(1);
  [x_adj] = AlignMSColumns(x_adj,f_adj,f_send);

  % query for resend
  [x_resend,f_resend] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblResend WHERE send_flag=0');
  pause(1);
  [x_resend] = AlignMSColumns(x_resend,f_resend,f_send);

  % query for incidental findings review
  [x_IF,f_IF] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblSendIF WHERE send_flag=0');
  pause(1);
  [x_IF_aligned] = AlignMSColumns(x_IF,f_IF,f_send);

  % collect all files to send
  x_up = {};
  x_up = [x_up; x_send];
  
  x_up_new = {};
  x_up_new = [x_up_new; x_send];
  
  x_up_old = {};
  
  f_old = {};
  
  if(size(x_resend,2)>1)
      x_up = [x_up; x_resend];
      x_up_new = [x_up_new; x_resend];
  end
  if(size(x_adj,2)>1)
      x_up = [x_up; x_adj];
      x_up_old = [x_up_old; x_adj];
      f_old = f_adj;
  end
  if(size(x_IF_aligned,2)>1)
      x_up = [x_up; x_IF_aligned];
      x_up_old = [x_up_old; x_IF_aligned];
      f_old = f_IF;
  end

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
    prefill_up = x_up_new;

    % Insert new blank records into scoresheet
    InsertScoresheet_NewScreening(mdbf,prefill_up,f_send,dvd_date);

    % get IDs for sending as adj
    prefill_up = x_up_old;
    if(size(prefill_up,1)>0)
        %  continue if any IDs for Adj/IF
        disp(' ');
        disp('Insert scoresheet records for adjudications and incidental findings review.');
        
        InsertScoresheet_AdjIF_Screening(mdbf_qc,mdbf,prefill_up,f_old,dvd_date);
        
    end

    %% Send files to Reader
    
    % copy to Box.com Sync folder
    disp(' ');
    disp('Send files to Reader');
    copyfile(batch_dir,final_dir);
    copyfile(mdbf,final_mdbf);

    % Update send_flags in database
    disp(' ');
    disp('Update tblDICOMScreening flags in database');
    if(size(x_send,1)>0)
      % update tblDICOMScreening send_flags
      flag_cell = cell(size(x_send,1),1);
      flag_cell(:) = {1};

      where_cell = x_send(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblDICOMScreening',{'send_flag'},flag_cell,{'SOPInstanceUID'},where_cell,1);
    end

    if(size(x_adj,1)>0 && size(x_adj,2)>1)
      % update tblSendAdj send_flags
      disp(' ');
      disp('Update tblSendAdj flags in database');

      flag_cell = cell(size(x_adj,1),1);
      flag_cell(:) = {1};

      where_cell = x_adj(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblSendAdj',{'send_flag'},flag_cell,{'SOPInstanceUID'},where_cell,1);
    end

    if(size(x_resend,1)>0 && size(x_resend,2)>1)
      % update tblResend send_flags
      disp(' ');
      disp('Update tblResend flags in database');

      flag_cell = cell(size(x_resend,1),1);
      flag_cell(:) = {1};

      where_cell = x_resend(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblResend',{'send_flag'},flag_cell,{'SOPInstanceUID'},where_cell,1);
    end

    if(size(x_IF_aligned,1)>0 && size(x_IF_aligned,2)>1)
      % update tblSendIF send_flags
      disp(' ');
      disp('Update tblSendIF flags in database');

      flag_cell = cell(size(x_IF_aligned,1),1);
      flag_cell(:) = {1};

      where_cell = x_IF_aligned(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblSendIF',{'send_flag'},flag_cell,{'SOPInstanceUID'},where_cell,1);
    end

  end %if any images to send exist
  
else
    disp(' ');
    disp('Batch has already been processed.');
end %if batch dir does not exist yet
