%% function for blinding and processing DICOM XRs

%% turn off warnings
warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

%% initialize
savef = horzcat('MOST_XR_BLIND_',datestr(now,'yyyymmddHHMMSS'),'.mat');

%% set up directories

%database
mdbf = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb'

%output dir
dcmdir_out = 'E:\most-dicom\XR_QC\144m';
dcmdir_out_qc = horzcat(dcmdir_out,'\QC');
dcmdir_out_sc = horzcat(dcmdir_out,'\Screening');

%% grab data from database

% accession numbers
[x_acc,f_acc] = MDBQuery(mdbf,'SELECT * FROM tblAccNum');
accnum_qc = x_acc{1,indcfind(f_acc,'^QC$','regexpi')};
accnum_sc = x_acc{1,indcfind(f_acc,'^Screening$','regexpi')};

% all files and categories
[x_category,f_category] = MDBquery(mdbf,'SELECT * FROM tblFilesCategory');

% all processed files
[x_qc,f_qc] = MDBquery(mdbf,'SELECT * FROM tblDICOMQC');
[x_fl,f_fl] = MDBquery(mdbf,'SELECT * FROM tblDICOMFullLimb');
[x_screening,f_screening] = MDBquery(mdbf,'SELECT * FROM tblDICOMScreening');

%% filter out processed files by SOP
SOP_processed = [x_qc(:,indcfind(f_qc,'^SOPInstanceUID$','regexpi')); x_fl(:,indcfind(f_fl,'^SOPInstanceUID$','regexpi')); x_screening(:,indcfind(f_screening,'^SOPInstanceUID$','regexpi'))];
x_unprocessed = x_category(~ismember(x_category(:,indcfind(f_category,'^SOPInstanceUID$','regexpi')),SOP_processed),:);

%% process and blind all new XRs
if(size(x_unprocessed,1)>0)

  unq_ids = unique(x_unprocessed(:,3));

  for ix=1:size(unq_ids,1) % loop through each ID

    tmpid = unq_ids{ix,1};

    % get a single XR exam by ID and date
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,3),tmpid,'regexpi'),:);
    tmpstudydate = tmpstudy{1,4};
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,4),tmpstudydate,'regexpi'),:);
    tmpstudy = sortrows(tmpstudy,[6,4,2,1]);

    % get patient name
    tmpname = tmpstudy{1,5};

    %% check cohort by ID
    chk_oldcohort = indcfind(tmpid,'(MB0[0-2][0-9]{3}|MI5[0-2][0-9]{3})','regexpi');
    chk_newcohort = indcfind(tmpid,'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})','regexpi');



    %% switch blinding by cohort
    if(~isempty(chk_oldcohort) && isempty(chk_newcohort))
      %% OLD cohort participant, do not screen

      % iterate the accession number counter for QC
      accnum_qc = accnum_qc+1;

      % blind the study for QC
      [tmpstudy_oldcohort_blinded]=Blind_OldCohort_XR_Study(dcmdir_out_qc,tmpid,tmpstudy,accnum_qc);
      % UploadToMDB here

    elseif(isempty(chk_oldcohort) && ~isempty(chk_newcohort))
      %% NEW cohort participant, also blind for screening

      % iterate the accession number counter for QC
      accnum_qc = accnum_qc+1;

      % blind the study
      [tmpstudy_oldcohort_blinded]=Blind_OldCohort_XR_Study(dcmdir_out_qc,tmpid,tmpstudy,accnum_qc);
      % UploadToMDB here

      % iterate the accession number counter for screening
      accnum_sc = accnum_sc+1;

      % blind the study for screening
      [tmpstudy_newcohort_blinded]=Blind_NewCohort_XR_Study(dcmdir_out_sc,tmpid,tmpstudy,accnum_qc);
      % UploadToMDB here

    end %blinding by cohort

  end %ix

  %% save accession number counters
  UploadToMDB(mdbf,'tblAccNum',{'QC','Screening'},{accnum_qc, accnum_sc}});

  %% save .mat file
  save(savef);

end %size>0
