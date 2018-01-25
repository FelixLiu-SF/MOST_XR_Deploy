function [dcmdir_out,final_dicom_unblinded,xafinal,fa,xsfinal,fs]=Get_New_FullLimbs(datedir_in)
% [dcmdir_out,final_ID_unblinded]=Get_New_FullLimbs()

% define static folders/files
incoming_dir_uab = 'E:\MOST-Renewal-II\XR\UAB';
incoming_dir_ui = 'E:\MOST-Renewal-II\XR\UI';
blinding_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinded_incoming.csv';
fulllimb_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinded_fulllimb.csv';
temp_dir_unblinded = 'E:\MOST-Renewal-II\XR\BLINDING\For_FullLimb\TEMP_UNBLINDED';
temp_dir_blinded = 'E:\MOST-Renewal-II\XR\BLINDING\For_FullLimb\TEMP_BLINDED';
masterf = 'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

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

% filter for Screening ID scheme
screenid_x = indcfind(final_dicom_unblinded(:,3),'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})','regexpi');
final_dicom_unblinded = final_dicom_unblinded(screenid_x,:);

% filter for matched FL tracking forms
[xt,ft]=MDBquery(masterf,'SELECT * FROM tblmatched_flxr_tf_mAs');
final_dicom_unblinded = final_dicom_unblinded(ismember(final_dicom_unblinded(:,3),xt(:,indcfind(ft,'^m13id$','regexpi'))),:);


% get existing barcode info
[xs,fs]=MDBquery(masterf,'SELECT * FROM tblQC_BU');
[xa,fa]=MDBquery(masterf,'SELECT * FROM tblAccessionQC');
% filter for IDs that were previously QC'd 
% these are probably requested repeats or full limbs
final_dicom_unblinded = final_dicom_unblinded(ismember(final_dicom_unblinded(:,3),xs(:,indcfind(fs,'^READINGID$','regexpi'))),:);
xafinal = xa(ismember(xa(:,indcfind(fa,'^READINGID$','regexpi')),final_dicom_unblinded(:,3)),:);
xsfinal = xs(ismember(xs(:,indcfind(fs,'^READINGID$','regexpi')),final_dicom_unblinded(:,3)),:);
% filter accessions for only pa and lateral views
xafinal = xa(indcfind(xa(:,indcfind(fa,'^SERIESDESC$','regexpi')),'^(PA|LLAT|RLAT)','regexpi'),:);


% % filter out XRs from same study date as before
% del_ix = [];
% for ix=1:size(final_dicom_unblinded,1)
%     tmpid   = final_dicom_unblinded{ix,3};
%     tmpdate = final_dicom_unblinded{ix,4};
%     
%     jx = indcfind(xafinal(:,indcfind(fa,'^READINGID$','regexpi')),tmpid,'regexpi');
%     chkdate = intersect(tmpdate,xafinal(jx,indcfind(fa,'^STUDYDATE$','regexpi')));
%     
%     if(~isempty(chkdate))
%         del_ix = [del_ix; ix];
%     end
% end
% if(~isempty(del_ix))
%     final_dicom_unblinded(del_ix,:) = [];
% end
% % % this no longer applies - rely on neural network to filter out repeats

% copy final XRs to temporary folder for blinding
for ix=1:size(final_dicom_unblinded,1)
    
    tmpf = final_dicom_unblinded{ix,1};
    [tmpd1,tmpf1,tmpe1] = fileparts(tmpf);
    [tmpd2,tmpf2,tmpe2] = fileparts(tmpd1);
    
    tmp_src_dir = tmpd1;
    tmp_dest_dir = horzcat(temp_dir_unblinded,'\',dirdate,'\',final_dicom_unblinded{ix,3},'\',tmpf2);
    [copyout_s,copyout_msg,copyout_mid] = copyfile(tmp_src_dir, tmp_dest_dir,'f');
    
end

% append to blinding log
dlmtxtappend(final_dicom_unblinded,fulllimb_logfile,',','cell','');





