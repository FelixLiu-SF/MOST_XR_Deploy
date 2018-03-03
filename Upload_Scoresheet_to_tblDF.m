function Upload_Scoresheet_to_tblDF(master_mdbf,mdbf,destf)
%% function to upload XRs results from screening

%% initialize
disp(' ');
disp(horzcat('Uploading scoresheet into database: ',mdbf));


%% read data from database

% collect XR blinding data
[xB,fB] = DeployMDBquery(master_mdbf,'SELECT * FROM tblDICOMScreening');
fB_col_id =     indcfind(fB,'^PatientID$','regexpi');
fB_send_flag =  indcfind(fB,'^Send_flag$','regexpi');

% collect existing screening DF data
[x1,f1] = DeployMDBquery(master_mdbf,'SELECT * FROM tblScreening_DF');
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

col_DF =        indcfind(fS,'^V1REVIEWDF$','regexpi');

col_reviewPA =  indcfind(fS,'^V1REVIEWPA$','regexpi');

chk_read_all = indcfind(xS(:,indcfind(fS,'^E_DATE$','regexpi')),'','empty');

%% upload results to database

[conn] = DeployMSAccessConn(master_mdbf);

for jx=1:size(xS,1)

    % check if signed by reader
    chk_read = xS{jx,col_edate};
    if(~isempty(chk_read))

        chkr1 = xS{jx,col_tfrt};
        chkr2 = xS{jx,col_pfrt};
        chkl1 = xS{jx,col_tflt};
        chkl2 = xS{jx,col_pflt};
        
        tmp_revPA = 1;
        tmp_revPA = xS{jx,col_reviewPA};

        disp(xS(jx,col_id));
        
        % check if already uploaded
        kx = intersect(xS(jx,col_id),x1(:,master_id));

        if(isempty(kx))

            if(tmp_revPA==0)
                fastinsert(conn,'tblScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);
                fastinsert(conn,'tblOrigScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);
            else
                disp('Send the ID above to PA for adjudication');
                fastinsert(conn,'tblOrigScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);
                
                % update adj in database
                tmpid = xS{jx,col_id};
                ax = indcfind(xB(:,fB_col_id),tmpid,'regexpi');
                adj_up = xB(ax,:);
                
                for bx=1:size(adj_up,1)
                    adj_up{bx,fB_send_flag} = 0;
                end
                
                UploadToMDB(master_mdbf,'tblSendAdj',fB,adj_up);
                
            end

        else
            disp('The ID above is already uploaded.');
            disp(' ');
        end

    else % not signed, skip record for now

        disp(xS(jx,col_id));
        disp('The record above is not signed.');
        disp(' ');
        
    end        

end

close(conn);

if(isempty(chk_read_all))
    movefile(mdbf,destf);
end
        
