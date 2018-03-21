function Upload_BlankScoresheet_to_tblPA(master_mdbf,mdbf,destf)
%% function to upload blank XRs results from screening

%% initialize
disp(' ');
disp(horzcat('Uploading scoresheet into database: ',mdbf));


%% read data from database

[x1,f1] = DeployMDBquery(master_mdbf,'SELECT * FROM tblScreening_PA');
master_id =    indcfind(f1,'^READINGID$','regexpi');

%% collect and upload data to mdb scoresheet
[xS,fS] = DeployMDBquery(mdbf,'SELECT * FROM tblScores');

col_edate = indcfind(fS,'^E_DATE$','regexpi');
col_dvd =   indcfind(fS,'^DVD$','regexpi');
col_id =    indcfind(fS,'^READINGID$','regexpi');

col_tfrt = indcfind(fS,'^V1TFKLG_R$','regexpi');
col_pfrt = indcfind(fS,'^V1PFKLG_R$','regexpi');
col_tflt = indcfind(fS,'^V1TFKLG_L$','regexpi');
col_pflt = indcfind(fS,'^V1PFKLG_L$','regexpi');

col_DF = indcfind(fS,'^V1REVIEWDF$','regexpi');

chk_read_all = indcfind(xS(:,indcfind(fS,'^E_DATE$','regexpi')),'','empty');

%% upload results to database

[conn] = DeployMSAccessConn(master_mdbf);

for jx=1:size(xS,1)
    
    xS{jx,col_DF} = -1;
    
    % check if already uploaded
    kx = intersect(xS(jx,col_id),x1(:,master_id));

    if(isempty(kx))

        fastinsert(conn,'tblScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);
        fastinsert(conn,'tblOrigScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);

    else
        disp('The ID above is already uploaded.');
    end

end

close(conn);

movefile(mdbf,destf);
        
