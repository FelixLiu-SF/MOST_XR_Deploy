function Upload_Scoresheet_to_tblBU(master_mdbf,mdbf,destf)
%% function to upload XRs results from screening

%% initialize
disp(' ');
disp(horzcat('Uploading scoresheet into database: ',mdbf));


%% read data from database

[x1,f1] = DeployMDBquery(master_mdbf,'SELECT * FROM tblScreening_PA');

master_id =     indcfind(f1,'^READINGID$','regexpi');
master_dvd =    indcfind(f1,'^DVD$','regexpi');
master_edate =  indcfind(f1,'^E_DATE$','regexpi');

x1(:,master_edate) = cellfun(@num2str,x1(:,master_edate),'UniformOutput',0);

%% collect and upload data to mdb scoresheet
[xS,fS] = DeployMDBquery(mdbf,'SELECT * FROM tblScores');

fS_DVD =    indcfind(fS,'^DVD$','regexpi');
fS_ID =     indcfind(fS,'^READINGID$','regexpi');
fS_EDATE =  indcfind(fS,'^E_DATE$','regexpi');

%% check for repeat requests

jx_col = indcfind(fS,'^(READINGID|DVD|XRPAQC|XRLAQC|COMMENTS|COMMENTS_REVIEW)$','regexpi');
jx_PA = indcfind(fS,'^XRPAQC$','regexpi');
jx_LA = indcfind(fS,'^XRLAQC$','regexpi');

chk_PA = cell2mat(xS(:,jx_PA));
chk_LA = cell2mat(xS(:,jx_LA));

if( ~isempty(find(chk_PA==2)) || ~isempty(find(chk_LA==2)) )
    disp(' ');
    disp('--- XR Repeat Requests ---');
    ix_chk = unique([find(chk_PA==2); find(chk_LA==2)]);
    disp(xS(ix_chk,jx_col));
else
    disp(' ');
    disp('No XR Repeat Requests from BU in this scoresheet');
end

%% upload results to database

unread_count = [];

[conn] = DeployMSAccessConn(master_mdbf);

for jx=1:size(xS,1)
        
        e_date = '';
        e_date = num2str(xS{jx,fS_EDATE});
        
        % check if already uploaded
        kx1 = intersect(xS(jx,fS_ID),x1(:,master_id));
        kx2 = intersect(xS(jx,fS_DVD),x1(:,master_dvd));
        kx3 = intersect(xS(jx,fS_EDATE),x1(:,master_edate));
        
        kx123 = intersect(kx1,intersect(kx2,kx3));
        
        if(~isempty(e_date) && (isempty(kx1) || isempty(kx123)) )
            disp(xS(jx,fS_ID));
            fastinsert(conn,'tblQC_BU',fS(2:end)',xS(jx,2:end)); pause(0.2);
            fastinsert(conn,'tblOrigQC_BU',fS(2:end)',xS(jx,2:end)); pause(0.2);
        else
            unread_count = [unread_count; jx];
        end
    end

close(conn);

if(size(unread_count,1)>0)
    disp(' ');
    disp(horzcat('Records unread: ',num2str(size(unread_count,1))));
    disp(' ');
    disp(xS(unread_count,1:10));
else
    disp(' ');
    disp('Uploaded all records.');
end

if(isempty(unread_count))
    movefile(mdbf,destf);
end
        
