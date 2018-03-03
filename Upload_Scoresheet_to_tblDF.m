function Upload_Scoresheet_to_tblDF(master_mdbf,mdbf,destf)
%% function to upload XRs results from screening

%% initialize
disp(' ');
disp(horzcat('Uploading scoresheet into database: ',mdbf));

signal_dir = 'C:\Program Files\Box Sync\Signaling';

%% read data from database

% collect XR blinding data
[xB,fB] = DeployMDBquery(master_mdbf,'SELECT * FROM tblDICOMScreening');
fB_col_id =     indcfind(fB,'^PatientID$','regexpi');
fB_send_flag =  indcfind(fB,'^Send_flag$','regexpi');

% collect existing screening DF data
[x1,f1] = DeployMDBquery(master_mdbf,'SELECT * FROM tblScreening_DF');
master_id =    indcfind(f1,'^READINGID$','regexpi');

[x2,f2] = DeployMDBquery(master_mdbf,'SELECT * FROM tblOrigScreening_DF');
master_origid =    indcfind(f2,'^READINGID$','regexpi');

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

col_COMMENTS =          indcfind(fS,'^COMMENTS$','regexpi');
col_COMMENTS_REVIEW =   indcfind(fS,'^COMMENTS_REVIEW$','regexpi');


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

        tmpid = xS(jx,col_id);

        disp(tmpid);

        % check if already uploaded
        kx = intersect(tmpid,x1(:,master_id));
        ox = intersect(tmpid,x2(:,master_origid));

        if(isempty(kx))

            if(tmp_revPA==0)
                fastinsert(conn,'tblScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);
                fastinsert(conn,'tblOrigScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);
            else
                disp('Send the ID above to PA for adjudication');
                disp(' ');

                %% check if this ID is already in queue for adjudication
                if(isempty(ox))

                  %% check this adjudication record for comments from BU
                  if(isempty(xS{jx,col_COMMENTS}))
                      xS{jx,col_COMMENTS} = '';
                  end

                  if(isempty(xS{jx,col_COMMENTS_REVIEW}))
                      xS{jx,col_COMMENTS_REVIEW} = '';
                  end
                  tmp_comments = horzcat(xS{jx,col_COMMENTS},' ',xS{jx,col_COMMENTS_REVIEW});
                  tmp_comments = strtrim(tmp_comments);

                  if(~isempty(tmp_comments)) %comments exist, okay to send to PA

                    % only update results in tblOrigScreening_DF, reserve tblScreening_DF for adj results
                    fastinsert(conn,'tblOrigScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);

                    % update adj in database
                    ax = indcfind(xB(:,fB_col_id),tmpid,'regexpi');
                    adj_up = xB(ax,:);

                    for bx=1:size(adj_up,1)
                        adj_up{bx,fB_send_flag} = 0;
                    end

                    UploadToMDB(master_mdbf,'tblSendAdj',fB,adj_up);

                  else %comments are missing, hold back and warn

                    % get scoresheet name and ID for warning
                    [~,mdbfn,~] = fileparts(mdbf);
                    warn_msg = horzcat(signal_dir,'\',mdbfn,'_',warn_msg,'.txt');
                    dlmtxtwrite({mdbf;mdbfn;tmpid},warn_msg,',','cell','',1); %read this file on a computer with email capabilities
                  end

                end

            end

        else
            disp('The ID above is already uploaded.');
            disp(' ');
        end

    else % not signed, skip record for now

        disp(tmpid);
        disp('The record above is not signed.');
        disp(' ');

    end

end

close(conn);

if(isempty(chk_read_all))
    movefile(mdbf,destf);
end
