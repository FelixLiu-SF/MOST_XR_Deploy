function [dcmdir_out,final_ID_unblinded]=Get_New_XRs(datedir_in)
% [dcmdir_out,final_ID_unblinded]=Get_New_XRs(datedir_in);

% define static folders/files
incoming_dir_uab = 'E:\MOST-Renewal-II\XR\UAB';
incoming_dir_ui = 'E:\MOST-Renewal-II\XR\UI';
blinding_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinded_incoming.csv';
fulllimb_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinded_fulllimb.csv';
temp_dir_unblinded = 'E:\MOST-Renewal-II\XR\BLINDING\For_QC\TEMP_UNBLINDED';
temp_dir_blinded = 'E:\MOST-Renewal-II\XR\BLINDING\For_QC\TEMP_BLINDED';
mdbf = 'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

exclude_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinding_excluded.csv';

% get today's date
% dirdate = datestr(now,'yyyymmdd');
dirdate = datedir_in;
dcmdir_out = horzcat(temp_dir_unblinded,'\',dirdate);

% get list of all files in XR folder
uab_filelist = filetroll(incoming_dir_uab,'*','.*',0,0);
ui_filelist = filetroll(incoming_dir_ui,'*','.*',0,0);

% filter for only DICOM file formats
uab_xr_list = uab_filelist(cellfun(@isdicom,uab_filelist(:,1)),:);
ui_xr_list = ui_filelist(cellfun(@isdicom,ui_filelist(:,1)),:);

dicom_xr_list = [uab_xr_list; ui_xr_list];

% exclude 'test' or 'phantom' files
dicom_xr_list(indcfind(dicom_xr_list(:,1),'(test|phantom)','regexpi'),:) = [];

% read spreadsheet log of blinded XR files
[~,~,csv_blinded] = xlsread(blinding_logfile);
csv_blinded(:,4) = cellfun(@num2str,csv_blinded(:,4),'UniformOutput',0); %change format of studydates
csv_blinded(2:end,3) = regimatch(csv_blinded(2:end,3),'(M|X)(B|I).{5}');

% filter out XRs that were previously blinded
files_unblinded = dicom_xr_list(~ismember(dicom_xr_list(:,1),csv_blinded(:,1)),:);

% exclude files from exclusion spreadsheet
[~,~,csv_excluded] = xlsread(exclude_logfile);
csv_excluded(:,4) = cellfun(@num2str,csv_excluded(:,4),'UniformOutput',0); %change format of studydates
files_unblinded = files_unblinded(~ismember(files_unblinded(:,1),csv_excluded(:,1)),:);

% read spreadsheet log of blinded FL files
[~,~,csv_fl] = xlsread(fulllimb_logfile);
csv_fl(:,4) = cellfun(@num2str,csv_fl(:,4),'UniformOutput',0); %change format of studydates
csv_fl(2:end,3) = regimatch(csv_fl(2:end,3),'M(B|I).{5}');

% filter out FL XRs that were previously blinded
files_unblinded = files_unblinded(~ismember(files_unblinded(:,1),csv_fl(:,1)),:);


% get metadata on unblinded XRs
dicom_unblinded = {};
for ix=1:size(files_unblinded,1)
    
    tmpf = files_unblinded{ix,1};
    tmpinfo = dicominfo(tmpf);
    
    tmpSOP = tmpinfo.SOPInstanceUID;
    tmpID = tmpinfo.PatientID;
    tmpDate = tmpinfo.StudyDate;
    
    dicom_unblinded = [dicom_unblinded; {tmpf, tmpSOP, tmpID, tmpDate}];
    
end

% filter out O's vs 0's
dicom_unblinded(:,3) = cellfun(@upper,dicom_unblinded(:,3),'UniformOutput',0);
dicom_unblinded(:,3) = cellfun(@strrep,dicom_unblinded(:,3),repcell(size(dicom_unblinded(:,3)),'O'),repcell(size(dicom_unblinded(:,3)),'0'),'UniformOutput',0);

% filter for MOST IDs
mostid_x = indcfind(dicom_unblinded(:,3),'(MB|MI)[0-9]{5}','regexpi');
id_mismatch_x = setdiff([1:size(dicom_unblinded,1)],mostid_x);

final_dicom_unblinded = dicom_unblinded(mostid_x,:);
final_dicom_unblinded = sortrows(final_dicom_unblinded,4); %sort by studydate
final_dicom_unblinded(2:end,3) = regimatch(final_dicom_unblinded(2:end,3),'M(B|I).{5}');

if(size(id_mismatch_x,2)>0)
    disp('MOST ID mismatch: ');
    disp([csv_blinded(1,:); dicom_unblinded(id_mismatch_x,:)]);
end

% filter for MOST IDs for EXISTING Cohort only
existingid_x = indcfind(final_dicom_unblinded(:,3),'(MB|MI)(0|5)[0-2][0-9]{3}','regexpi');
final_dicom_unblinded = final_dicom_unblinded(existingid_x,:);
final_dicom_unblinded = sortrows(final_dicom_unblinded,4); %sort by studydate


% filter out IDs that were previously QC'd 
% these are requested repeats probably, handle in another process
final_dicom_unblinded = final_dicom_unblinded(~ismember(final_dicom_unblinded(:,3),csv_blinded(:,3)),:);


% filter out IDs that do not match tracking forms (accoridng to JL)
[x_tf,f_tf] = MDBquery(mdbf,'SELECT * FROM tblmatched_kxr_tf');
final_dicom_unblinded = final_dicom_unblinded(ismember(final_dicom_unblinded(:,3),x_tf(:,indcfind(f_tf,'^a03id$','regexpi'))),:);


% limit number of IDs if too many
n_limit = 30;
total_ID_size = size(unique(final_dicom_unblinded(:,3)),1);
if(total_ID_size>=n_limit)
    jx = 1;
    tmp_ID_size = size(unique(final_dicom_unblinded(1:jx,3)),1);
    while(tmp_ID_size<=n_limit && jx<size(final_dicom_unblinded,1))
        jx=jx+1;
        tmp_ID_size = size(unique(final_dicom_unblinded(1:jx,3)),1);
    end
    final_dicom_unblinded = final_dicom_unblinded(1:(jx-1),:);
end

% safety check all XRs for matching IDs
final_ID_list = unique(final_dicom_unblinded(:,3));
final_ID_unblinded = {};
for ix=1:size(final_ID_list,1)
    jx = indcfind(final_dicom_unblinded(:,3),final_ID_list{ix,1},'regexpi');
    final_ID_unblinded = [final_ID_unblinded; final_dicom_unblinded(jx,:)];
end

% copy final XRs to temporary folder for blinding
for ix=1:size(final_ID_unblinded,1)
    
    tmpf = final_ID_unblinded{ix,1};
    [tmpd1,tmpf1,tmpe1] = fileparts(tmpf);
    [tmpd2,tmpf2,tmpe2] = fileparts(tmpd1);
    
    tmp_src_dir = tmpd1;
    tmp_dest_dir = horzcat(temp_dir_unblinded,'\',dirdate,'\',final_ID_unblinded{ix,3},'\',tmpf2);
    [copyout_s,copyout_msg,copyout_mid] = copyfile(tmp_src_dir, tmp_dest_dir,'f');
    
end

% append to blinding log
dlmtxtappend(final_ID_unblinded,blinding_logfile,',','cell','');





