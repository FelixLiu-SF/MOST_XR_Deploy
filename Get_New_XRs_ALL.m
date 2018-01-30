
%% Universal MOST X-ray categorizer
% this should scan for all new XR files, and categorize them by view and by exam type

%% set up directories

%database
mdbf = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb'

%input dir
incoming_dir_xr = 'E:\most-dicom\MOST-DICOM-IN\images\XR';

dpvrf = 'most_inven.mat' %this matlab save file needs to be included in the deployment

% output dir
dcmdir_out = 'E:\most-dicom\XR_QC\144m';

%% scan directories
dicom_xr_list = filetroll(incoming_dir_xr,'*','.dcm',0,0);

%% filter out files by filename/filetype
filter_xr_list = dicom_xr_list;

% exclude 'test' or 'phantom' files
filter_xr_list(indcfind(filter_xr_list(:,1),'(test|phantom)','regexpi'),:) = [];

% exclude files from exclusion list
files_to_exclude = []; %placeholder for data input
filter_xr_list = filter_xr_list(~ismember(filter_xr_list(:,1),files_to_exclude(:,1)),:);

% exclude files previously categorized
files_already_categorized = []; %placeholder for data input
filter_xr_list = filter_xr_list(~ismember(filter_xr_list(:,1),files_already_categorized(:,1)),:);

% filter for only DICOM file formats
filter_xr_list = filter_xr_list(cellfun(@isdicom,filter_xr_list(:,1)),:);


%% get dicom metadata
dicom_unblinded = {};
for ix=1:size(filter_xr_list,1)

  try
    tmpf = filter_xr_list{ix,1};
    tmpinfo = dicominfo(tmpf);

    tmpSOP = tmpinfo.SOPInstanceUID;
    tmpID = tmpinfo.PatientID;
    tmpDate = tmpinfo.StudyDate;

    dicom_unblinded = [dicom_unblinded; {tmpf, tmpSOP, tmpID, tmpDate}];
  catch metadata_err
    disp('Error reading DICOM metadata');
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

id_mismatch_x = setdiff([1:size(dicom_unblinded,1)],mostid_x);
if(size(id_mismatch_x,2)>0)
    disp('MOST ID mismatch: ');
    disp([csv_blinded(1,:); dicom_unblinded(id_mismatch_x,:)]);
end


%% analyze for content


%% save the results
