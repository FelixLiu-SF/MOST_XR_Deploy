function Upload_BlankScreening_from_PA()
%% function to upload XRs from screening

%% initialize
disp(' ');
disp('Uploading blank PA screening scores...');


% master mdbf
master_mdbf = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

% directories
srcdir = 'E:\most-dicom\XR_QC\Sent\ScreeningSecondary\Scoresheets';
newdir = 'E:\most-dicom\XR_QC\Received\ScreeningSecondary';
updir = 'E:\most-dicom\XR_QC\Uploaded\ScreeningSecondary';

%% search for new scoresheets

[~,~,src_list] = foldertroll(srcdir,'.mdb');
[~,~,up_list] = foldertroll(updir,'.mdb');

if(size(src_list,1)>0)
    %% copy new scoresheets for uploading
    disp(' ');
    disp('Copying new scoresheets');
    copy_list = src_list(~ismember(src_list(:,3),up_list(:,3)),:);
    for ix=1:size(copy_list,1)
        tmppf = copy_list{ix,1};
        tmpf = copy_list{ix,3};

        tmp_destf = horzcat(newdir,'\',tmpf);

        copyfile(tmppf,tmp_destf);
    end

    %% upload the new scoresheet files
    disp(' ');
    disp('Uploading results to database');
    [~,~,new_list] = foldertroll(newdir,'.mdb');

    for ix=1:size(new_list,1)

        tmp_mdbf =  new_list{ix,1};
        tmp_destf = horzcat(updir,'\',new_list{ix,3});

        Upload_BlankScoresheet_to_tblPA(master_mdbf,tmp_mdbf,tmp_destf);
        pause(5);

    end
    
end