function Send_Screening_to_PA()
%% function to send XRs for screening

%% initialize

% parameters
side = 3;
knee = 'B';
dvd_date = datestr(now,'yyyymmdd');

% table columns for upload
f_up = {...
    'READINGID';...
    'READINGACRO';...
    'DVD';...
    'SIDE';...
    'KNEE';...
    'V1BLINDDATE';...
    'V1TFBARCDBU';...
    'V1NUMXR';...
    };

% mdbf
mdbf_qc = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb';

% get scoresheet template
template_dir = 'S:\FelixTemp\XR\ScreeningPA_Templates';
[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

% set up directories
output_dir = 'E:\most-dicom\XR_QC\Sent\Screening';
final_destination = '';

batch_dir = horzcat(output_dir,'\Batches\Batch_',dvd_date);
mdbf = horzcat(output_dir,'\Scoresheets\MOST_XR_ScreeningPA_',dvd_date,'.mdb');
final_dir = horzcat(final_destination,'\DICOM\',dvd_date);
final_mdbf = horzcat(final_destination,'\Scoresheets\MOST_XR_ScreeningPA_',dvd_date,'.mdb');

if(~exist(batch_dir,'dir')) % continue if this batch hasn't been made

  % query for blinded images that have not been sent
  [x_send,f_send] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMScreening WHERE send_flag=0');
  pause(1);

  % stop if no images to send
  if(size(x_send,2)<2)
    return;
  end

  % filter out IDs that have been previously sent
  [x_sent,f_sent] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMScreening WHERE send_flag BETWEEN 1 and 2'); % flag 1 for PA, flag 2 for DF
  pause(1);
  unique_sent_IDs = unique(x_send(:,indcfind(f_sent,'^PatientID$','regexpi')));

  x_send = x_send(~ismember(x_send(:,indcfind(f_send,'^PatientID$','regexpi')),unique_sent_IDs);

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

  % limit how many new XRs to send
  lim_num = 20;
  if(size(x_send,1)>lim_num)
    x_send = x_send(1:lim_num,:);
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
  x_up = [x_up; x_send; x_adj; x_resend; x_IF_aligned];

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

    % insert into scoresheet
    conn = DeployMSAccessConn(mdbf);

    % get IDs for sending as blank scoresheets
    prefill_up = [x_send; x_resend];

    % Insert new blank records into scoresheet
    InsertScoresheet_NewScreening(mdbf,prefill_up,f_send);

    %% NEED CODE TO ADD ADJ AND IF SCORESHEET ENTRIES %%

    % get IDs for sending as adj
    prefill_up = x_adj;
    u_id = unique(prefill_up(:,f_PatientID));



    % copy to Box.com Sync folder
    copyfile(batch_dir,final_dir);
    copyfile(mdbf,final_mdbf);

    % Update send_flags in database

    if(size(x_send,1)>0)
      % update tblDICOMScreening send_flags
      flag_cell = cell(size(x_send,1));
      flag_cell(:) = {1};

      where_cell = x_send(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblDICOMScreening',{'send_flag'},flag_cell,where_cell,1);
    end

    if(size(x_adj,1)>0)
      % update tblSendAdj send_flags

      flag_cell = cell(size(x_adj,1));
      flag_cell(:) = {1};

      where_cell = x_adj(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblSendAdj',{'send_flag'},flag_cell,where_cell,1);
    end

    if(size(x_resend,1)>0)
      % update tblResend send_flags

      flag_cell = cell(size(x_resend,1));
      flag_cell(:) = {1};

      where_cell = x_resend(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblResend',{'send_flag'},flag_cell,where_cell,1);
    end

    if(size(x_IF_aligned,1)>0)
      % update tblSendIF send_flags

      flag_cell = cell(size(x_IF_aligned,1));
      flag_cell(:) = {1};

      where_cell = x_IF_aligned(:,f_SOPInstanceUID);

      UpdateMDB_WhereIs(mdbf_qc,'tblSendIF',{'send_flag'},flag_cell,where_cell,1);
    end

  end %if any images to send exist
end %if batch dir does not exist yet
