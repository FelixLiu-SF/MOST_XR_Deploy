function [final_dicom_category]=Get_New_XRs_All()
%% Universal MOST X-ray categorizer
% this should scan for all new XR files, and categorize them by view and by exam type

%% initialize
disp('');
disp('Initializing Neural Network scan...');
final_dicom_category = {};

%% set up directories

%database
mdbf = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

%input dir
incoming_dir_uab = 'E:\most\MOST-Renewal-II\Clinics\UAB\Xray';
incoming_dir_ui = 'E:\most\MOST-Renewal-II\Clinics\Uiowa\Xray';

%output dir
output_dir = 'S:\FelixTemp\XR';

%% set up save file
dtstr = datestr(now,'yyyymmddHHMMSS');
savef = horzcat(output_dir,'\XR_files_',dtstr,'.mat');


%% query database for data
disp('');
disp(horzcat('Reading from database: ',mdbf));
[x_exclude,f_exclude] = DeployMDBquery(mdbf,'SELECT * FROM tblFilesExcluded');
[x_category,f_category] = DeployMDBquery(mdbf,'SELECT * FROM tblFilesCategory');

%% scan directories
disp('');
disp(horzcat('Reading DICOMs from: ',incoming_dir_uab));
uab_filelist = filetroll(incoming_dir_uab,'*','.dcm',0,0);
disp(horzcat('Reading DICOMs from: ',incoming_dir_ui));
ui_filelist = filetroll(incoming_dir_ui,'*','.dcm',0,0);

dicom_xr_list = [uab_filelist; ui_filelist];

%% filter out files by filename/filetype
disp('');
disp('Filtering out previously scanned files.');
filter_xr_list = dicom_xr_list;

% exclude 'test' or 'phantom' files
filter_xr_list(indcfind(filter_xr_list(:,1),'(test|phantom)','regexpi'),:) = [];

% exclude files from exclusion list
files_to_exclude = x_exclude(:,indcfind(f_exclude,'filename','regexpi'));
filter_xr_list = filter_xr_list(~ismember(filter_xr_list(:,1),files_to_exclude(:,1)),:);

% exclude files previously categorized
files_already_categorized = x_category(:,indcfind(f_category,'filename','regexpi'));
filter_xr_list = filter_xr_list(~ismember(filter_xr_list(:,1),files_already_categorized(:,1)),:);

% filter for only DICOM file formats
filter_xr_list = filter_xr_list(cellfun(@isdicom,filter_xr_list(:,1)),:);


%% get dicom metadata
disp('');
disp('Reading DICOM metadata');
dicom_unblinded = {};
for ix=1:size(filter_xr_list,1)

  try
    tmpf =    filter_xr_list{ix,1};
    tmpinfo = dicominfo(tmpf);

    tmpSOP =  tmpinfo.SOPInstanceUID;
    tmpID =   tmpinfo.PatientID;
    tmpDate = tmpinfo.StudyDate;

    tmp_namefields = fieldnames(tmpinfo.PatientName);
    tmp_patientname = '';
    for nx=1:size(tmp_namefields,1)
        tmp_patientname = horzcat(tmp_patientname,getfield(tmpinfo.PatientName,tmp_namefields{nx}));
    end

    dicom_unblinded = [dicom_unblinded; {tmpf, tmpSOP, tmpID, tmpDate, tmp_patientname}];

  catch metadata_err
    disp('Error reading DICOM metadata');
    disp(metadata_err.message);
  end
end

%% filter out files by metadata

% filter out O's vs 0's
dicom_unblinded(:,3) = cellfun(@upper,dicom_unblinded(:,3),'UniformOutput',0);
dicom_unblinded(:,3) = cellfun(@strrep,dicom_unblinded(:,3),repcell(size(dicom_unblinded(:,3)),'O'),repcell(size(dicom_unblinded(:,3)),'0'),'UniformOutput',0);

% filter for MOST IDs
mostid_x = indcfind(dicom_unblinded(:,3),'(MB|MI)[0-9]{5}','regexpi');

final_dicom_unblinded = dicom_unblinded(mostid_x,:);
final_dicom_unblinded = sortrows(final_dicom_unblinded,[4,-3]); %sort by studydate

%% analyze for content
disp('');
disp('Analyzing X-ray image types using Neural Networks');
if(size(final_dicom_unblinded,1)>0)

  % make matrix for saving category results
  final_dicom_category = final_dicom_unblinded;

  for ix=1:size(final_dicom_category,1)

    tmpf =  final_dicom_category{ix,1};
    tmpid = final_dicom_category{ix,3};

    view_output = '';

    try
      % preprocess image for NN
      [tmpratio,edge_nn,adj_img,adjc_img]=Preprocess_XR_for_NN(tmpf);

      % run NN and categorize by NN results
      [view_output]=Get_NeuralNet_XR_Category(tmpid,tmpratio,edge_nn,adj_img,adjc_img);
      final_dicom_category{ix,6} = view_output;

    catch nn_err

      disp(nn_err.message);
      final_dicom_category{ix,6} = 'Unknown';

    end %try-catch

  end

  %% save the results

  % save mat file
  try
      save(savef,'final_dicom_category','final_dicom_unblinded')
  catch save_err
      disp(save_err.message);
  end

  % upload to database
  UploadToMDB(mdbf,'tblFilesCategory',{'filename','SOPInstanceUID','PatientID','StudyDate','PatientName','View'},final_dicom_category);

end %size>0
