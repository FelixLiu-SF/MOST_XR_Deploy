function Send_Screening_to_PA()
%% function to send XRs for screening

%% initialize



% mdbf
mdbf = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb';

% set up directories
output_dir = 'E:\most-dicom\XR_QC\144m';

% query for blinded images
[x_screening,f_screening] = DeployMDBquery(mdbf,'SELECT * FROM tblDICOMScreening');
pause(1);

% query for images previously sent
[x_sent,f_sent] = DeployMDBquery(mdbf,'SELECT * FROM tblSentScreening');
pause(1);

% query for new incidental findings//resend
% query for images previously sent
[x_resend,f_resend] = DeployMDBquery(mdbf,'SELECT * FROM tblResend');
pause(1);

% query for review by DF

% copy files

% create new mdb scoresheet

% copy to Box.com Sync folder
