%% function for blinding and processing DICOM XRs

%% turn off warnings
warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

%% set up directories

%database
mdbf = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb'

%output dir
dcmdir_out = 'E:\most-dicom\XR_QC\144m';

%% grab data from database

% accession numbers
[x_acc_qc,f_acc_qc] = MDBQuery(mdbf,'SELECT * FROM tblAccNumQC');
[x_acc_sc,f_acc_sc] = MDBQuery(mdbf,'SELECT * FROM tblAccNumScreening');
accnum_qc = x_acc_qc{1,1};
accnum_sc = x_acc_sc{1,1};

% all files and categories
[x_category,f_category] = MDBquery(mdbf,'SELECT * FROM tblFilesCategory');

% all processed files
[x_qc,f_qc] = MDBquery(mdbf,'SELECT * FROM tblDICOMQC');
[x_fl,f_fl] = MDBquery(mdbf,'SELECT * FROM tblDICOMFullLimb');
[x_screening,f_screening] = MDBquery(mdbf,'SELECT * FROM tblDICOMScreening');

%% filter out processed files by SOP
SOP_processed = [x_qc(:,2); x_fl(:,2); x_screening(:,2)];

x_unprocessed = x_category(~ismember(x_category(:,2),SOP_processed),:);

%% process and blind all new XRs
if(size(x_unprocessed,1)>0)

  unq_ids = unique(x_unprocessed(:,3));

  for ix=1:size(unq_ids,1) % loop through each ID

    tmpid = unq_ids{ix,1};

    % get a single XR exam by ID and date
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,3),tmpid,'regexpi'),:);
    tmpstudydate = tmpstudy{1,4};
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,4),tmpstudydate,'regexpi'),:);

    % get patient name
    tmpname = tmpstudy{1,5};

    %% check cohort by ID
    chk_oldcohort = indcfind(tmpid,'(MB0[0-2][0-9]{3}|MI5[0-2][0-9]{3})','regexpi');
    chk_newcohort = indcfind(tmpid,'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})','regexpi');

    %% switch blinding by cohort
    if(~isempty(chk_oldcohort) && isempty(chk_newcohort))
      %% old cohort participant, do not screen


    elseif(isempty(chk_oldcohort) && ~isempty(chk_newcohort))
      %% new cohort participant, also blind for screening
      

    end %blinding by cohort

  end %ix

end %size>0
