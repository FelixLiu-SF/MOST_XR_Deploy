%% function for blinding and processing DICOM XRs

%% turn off warnings
warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

%% initialize

f_up_qc = {'filename','SOPInstanceUID','PatientID','PatientName','StudyDate','View','StudyBarcode','SeriesBarcode','FileBarcode','Exit_code','Send_flag'};
f_up_sc = {'filename','SOPInstanceUID','PatientID','PatientName','StudyDate','View','StudyBarcode','SeriesBarcode','FileBarcode','Exit_code','Send_flag'};

%% set up directories

%database
mdbf = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

%output dir
dcmdir_out = 'E:\most-dicom\XR_QC\144m';
dcmdir_out_qc = horzcat(dcmdir_out,'\QC');
dcmdir_out_sc = horzcat(dcmdir_out,'\Screening');

%% initialize
savef = horzcat(dcmdir_out,'\MOST_XR_BLIND_',datestr(now,'yyyymmddHHMMSS'),'.mat');

%% grab data from database
disp(' ');
disp(horzcat('Reading from database: ',mdbf));

% accession numbers
[x_acc,f_acc] = DeployMDBquery(mdbf,'SELECT * FROM tblAccNum');
pause(1);
accnum_qc = x_acc{1,indcfind(f_acc,'^QC$','regexpi')};
accnum_sc = x_acc{1,indcfind(f_acc,'^Screening$','regexpi')};

% all processed files, need to call this early in deployment for some reason, i have no idea why
% table is getting too large, query by expected years 
[x_qc,f_qc] = DeployMDBquery(mdbf,'SELECT * FROM tblDICOMQC WHERE StudyDate LIKE ''2018%'' OR StudyDate LIKE ''2019%'' OR StudyDate LIKE ''2020%''');
pause(1);
[x_screening,f_screening] = DeployMDBquery(mdbf,'SELECT * FROM tblDICOMScreening WHERE StudyDate LIKE ''2017%'' OR StudyDate LIKE ''2018%'' OR StudyDate LIKE ''2019%''');
pause(1);

% all files and categories
[x_category,f_category] = DeployMDBquery(mdbf,'SELECT * FROM tblFilesCategory WHERE StudyDate LIKE ''2018%'' OR StudyDate LIKE ''2019%'' OR StudyDate LIKE ''2020%''');
pause(1);

% align columns
f_order = [...
  indcfind(f_category,'^filename$','regexpi'),...
  indcfind(f_category,'^SOPInstanceUID$','regexpi'),...
  indcfind(f_category,'^PatientID$','regexpi'),...
  indcfind(f_category,'^PatientName$','regexpi'),...
  indcfind(f_category,'^StudyDate$','regexpi'),...
  indcfind(f_category,'^View$','regexpi'),...
  ];

  x_category = x_category(:,f_order);

%% filter out processed files by SOP
disp(' ');
disp('Filter our previously blinded files');
SOP_processed_qc =          x_qc(:,indcfind(f_qc,'^SOPInstanceUID$','regexpi'));
SOP_processed_screening =   x_screening(:,indcfind(f_screening,'^SOPInstanceUID$','regexpi'));

x_unprocessed =             x_category(~ismember(x_category(:,2),SOP_processed_qc),:);
x_unprocessed_screening =   x_category(~ismember(x_category(:,2),SOP_processed_screening),:);

%% filter out unstitched full limb views from qc
x_unprocessed(indcfind(x_unprocessed(:,6),'^Unstitched','regexpi'),:) = [];

%% filter out all full limbs views from screening
x_unprocessed_screening(indcfind(x_unprocessed_screening(:,6),'^Unstitched','regexpi'),:) = [];
x_unprocessed_screening(indcfind(x_unprocessed_screening(:,6),'^Full Limb','regexpi'),:) = [];

disp(' ');
disp(horzcat('# of new files to blind: ',num2str(size(x_unprocessed,1))));

%% process and blind all new XRs for QC
disp(' ');
disp('Blind new X-ray images');
if(size(x_unprocessed,1)>0)

  unq_ids = unique(x_unprocessed(:,3));
  
  disp(' ');
  disp(horzcat('# of IDs to blind: ',num2str(size(unq_ids,1))));

  for ix=1:size(unq_ids,1) % loop through each ID

    tmpid = unq_ids{ix,1};
    
    disp(ix);
    disp(tmpid);

    % get a single XR exam by ID and date
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,3),tmpid,'regexpi'),:);
    tmpstudydate = tmpstudy{1,5};
    tmpstudy = tmpstudy(indcfind(tmpstudy(:,5),tmpstudydate,'regexpi'),:);
    tmpstudy = sortrows(tmpstudy,[6,5,2,1]);

    % get patient name
    tmpname = tmpstudy{1,4};

    %% check cohort by ID
    chk_oldcohort = regexpi(tmpid,'(MB0[0-2][0-9]{3}|MI5[0-2][0-9]{3})');
    chk_newcohort = regexpi(tmpid,'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})');


    %% switch blinding by cohort
    if(~isempty(chk_oldcohort) && isempty(chk_newcohort))
        
      %% OLD cohort participant, do not screen

      % iterate the accession number counter for QC
      accnum_qc = accnum_qc+1;

      % save accession number counters
      UpdateMDB(mdbf,'tblAccNum',{'QC','Screening'},{accnum_qc, accnum_sc},{'WHERE RECORDID=1'});

      % blind the study for QC
      [tmpstudy_oldcohort_blinded]=Blind_OldCohort_XR_Study(dcmdir_out_qc,tmpid,tmpstudy,accnum_qc);
      % Upload processed files to MDB
      if(size(tmpstudy_oldcohort_blinded,1)>0)
        UploadToMDB(mdbf,'tblDICOMQC',f_up_qc,tmpstudy_oldcohort_blinded(:,[11,2:9,12:13]));
      end

    elseif(isempty(chk_oldcohort) && ~isempty(chk_newcohort))
        
      %% NEW cohort participant

      % iterate the accession number counter for QC
      accnum_qc = accnum_qc+1;

      % save accession number counters
      UpdateMDB(mdbf,'tblAccNum',{'QC','Screening'},{accnum_qc, accnum_sc},{'WHERE RECORDID=1'});

      % blind the study
      [tmpstudy_newcohort_blinded]=Blind_NewCohort_XR_Study(dcmdir_out_qc,tmpid,tmpstudy,accnum_qc);
      % Upload processed files to MDB
      if(size(tmpstudy_newcohort_blinded,1)>0)
        UploadToMDB(mdbf,'tblDICOMQC',f_up_qc,tmpstudy_newcohort_blinded(:,[11,2:9,12:13]));
      end


    end %blinding by cohort

  end %ix
end
  
  %% process and blind all new XRs for Screening
disp(' ');
disp('Blind new Screening X-ray images');
if(size(x_unprocessed_screening,1)>0)

  unq_ids = unique(x_unprocessed_screening(:,3));
  
  disp(' ');
  disp(horzcat('# of IDs to blind: ',num2str(size(unq_ids,1))));

  for ix=1:size(unq_ids,1) % loop through each ID

    tmpid = unq_ids{ix,1};
    
    disp(ix);
    disp(tmpid);

    % get a single XR exam by ID and date
    tmpstudy = x_unprocessed_screening(indcfind(x_unprocessed_screening(:,3),tmpid,'regexpi'),:);
    tmpstudydate = tmpstudy{1,5};
    tmpstudy = tmpstudy(indcfind(tmpstudy(:,5),tmpstudydate,'regexpi'),:);
    tmpstudy = sortrows(tmpstudy,[6,5,2,1]);

    % get patient name
    tmpname = tmpstudy{1,4};

    %% check cohort by ID
    chk_oldcohort = regexpi(tmpid,'(MB0[0-2][0-9]{3}|MI5[0-2][0-9]{3})');
    chk_newcohort = regexpi(tmpid,'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})');


    %% switch blinding by cohort
    if(~isempty(chk_oldcohort) && isempty(chk_newcohort))
        
      %% OLD cohort participant, do not screen

    elseif(isempty(chk_oldcohort) && ~isempty(chk_newcohort))
        
      %% NEW cohort participant,  blind for screening

      % iterate the accession number counter for screening
      accnum_sc = accnum_sc+1;

      % save accession number counters
      UpdateMDB(mdbf,'tblAccNum',{'QC','Screening'},{accnum_qc, accnum_sc},{'WHERE RECORDID=1'});

      % blind the study for screening
      [tmpstudy_screening_blinded]=Blind_Screening_XR_Study(dcmdir_out_sc,tmpid,tmpstudy,accnum_sc);
      % Upload processed files to MDB
      if(size(tmpstudy_screening_blinded,1)>0)
        UploadToMDB(mdbf,'tblDICOMScreening',f_up_sc,tmpstudy_screening_blinded(:,[11,2:9,12:13]));
      end

    end %blinding by cohort

  end %ix

end %size>0

%% save .mat file
save(savef);
