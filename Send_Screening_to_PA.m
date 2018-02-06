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

batch_dir = horzcat(output_dir,'\Batches\Batch_',dvd_date);
mdbf = horzcat(output_dir,'\Scoresheets\MOST_XR_ScreeningPA_',dvd_date,'.mdb');

if(~exist(batch_dir,'dir'))

  % create batching files
  mkdir(batch_dir);
  copyfile(mdbf_template,mdbf);

  % query for blinded images
  [x_screening,f_screening] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblDICOMScreening');
  pause(1);

  % query for images previously sent
  [x_sent,f_sent] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblSentScreening');
  pause(1);

  % query for new incidental findings//resend
  [x_resend,f_resend] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblResend');
  pause(1);
  [x_resent,f_resent] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblResent');
  pause(1);

  %% query for review by DF %%

  % filter for XR exams that haven't been sent yet, by ID
  x_up = {};
  x_up = x_screening(~ismember(x_screening(:,indcfind(f_screening,'^PatientID$','regexpi')),x_sent(:,indcfind(f_sent,'^PatientID$','regexpi'))),:);

  % add in files for resending, by filename
  to_add = {};
  to_add = x_resend(~ismember(x_resend(:,indcfind(f_resend,'^filename$','regexpi')),x_resent(:,indcfind(f_resent,'^filename$','regexpi'))),:);

  x_up = [x_up; to_add];

  % add in IDs for review, by ID


  % copy files

  % create new mdb scoresheet

  % copy to Box.com Sync folder


end
