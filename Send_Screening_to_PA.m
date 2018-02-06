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

if(~exist(batch_dir,'dir')) % continue if this batch hasn't been made

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

  %% filter out exit_code errors %%
  del_ix = [];
  for fx=1:size(x_up,1)
    tmp_exitcode = x_up{fx,indcfind(f_screening,'exit_code','regexpi')};
    if(tmp_exitcode>0)
      del_ix = [del_ix; fx];
    end
  end
  if(size(del_ix,1)>0)
    x_up(del_ix,:) = [];
  end
  

  if(size(x_up,1)>0) % continue if there are any IDs to send

    % create batching directory
    mkdir(batch_dir);

    % create scoresheet file
    copyfile(mdbf_template,mdbf);

    % copy files to batching dir
    f_filename = indcfind(f_screening,'^filename$','regexpi');
    f_SOPInstanceUID = indcfind(f_screening,'^SOPInstanceUID$','regexpi');
    f_PatientID = indcfind(f_screening,'^PatientID$','regexpi');
    f_PatientName = indcfind(f_screening,'^PatientName$','regexpi');
    f_StudyDate = indcfind(f_screening,'^StudyDate$','regexpi');
    f_View = indcfind(f_screening,'^View$','regexpi');
    f_StudyBarcode = indcfind(f_screening,'^StudyBarcode$','regexpi');
    f_SeriesBarcode = indcfind(f_screening,'^SeriesBarcode$','regexpi');
    f_FileBarcode = indcfind(f_screening,'^FileBarcode$','regexpi');

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

    % copy to Box.com Sync folder

  end
end
