function Upload_Scoresheet_to_tblPA(master_mdbf,mdbf,destf)
%% function to upload XRs results from screening

%% initialize
disp(' ');
disp(horzcat('Uploading scoresheet into database: ',mdbf));


%% read data from database

[x1,f1] = DeployMDBquery(master_mdbf,'SELECT * FROM tblScreening_PA');
master_id =    indcfind(f1,'^READINGID$','regexpi');

[x2,f2] = DeployMDBquery(master_mdbf,'SELECT * FROM tblSendAdj');
col_adjid =    indcfind(f2,'^PatientID$','regexpi');
col_adjsend =  indcfind(f2,'^Send_flag$','regexpi');

%% collect and upload data to mdb scoresheet
[xS,fS] = DeployMDBquery(mdbf,'SELECT * FROM tblScores');

col_edate = indcfind(fS,'^E_DATE$','regexpi');
col_dvd =   indcfind(fS,'^DVD$','regexpi');
col_id =    indcfind(fS,'^READINGID$','regexpi');
col_reader = indcfind(fS,'^READER$','regexpi');

col_tfrt = indcfind(fS,'^V1TFKLG_R$','regexpi');
col_pfrt = indcfind(fS,'^V1PFKLG_R$','regexpi');
col_tflt = indcfind(fS,'^V1TFKLG_L$','regexpi');
col_pflt = indcfind(fS,'^V1PFKLG_L$','regexpi');

col_DF = indcfind(fS,'^V1REVIEWDF$','regexpi');

chk_read_all = indcfind(xS(:,indcfind(fS,'^E_DATE$','regexpi')),'','empty');

%% upload results to database

[conn] = DeployMSAccessConn(master_mdbf);

for jx=1:size(xS,1)

  tmpid = xS(jx,col_id);
  disp(' ');
  disp(tmpid);

    % check if signed by reader
    chk_read = xS{jx,col_edate};
    if(~isempty(chk_read))

        chkr1 = xS{jx,col_tfrt};
        chkr2 = xS{jx,col_pfrt};
        chkl1 = xS{jx,col_tflt};
        chkl2 = xS{jx,col_pflt};

        if(max(chkr1==[2,3,-6,-7,-9])>0 || max(chkr2==[2,3,-6,-7,-9])>0)
            xS{jx,col_DF} = -1;
        end
        if(max(chkl1==[2,3,-6,-7,-9])>0 || max(chkl2==[2,3,-6,-7,-9])>0)
            xS{jx,col_DF} = -1;
        end
        if(chkr1==4 || chkr2==4 || chkl1==4 || chkl2==4)
            xS{jx,col_DF} = 0;
        end


        % check if already uploaded
        kx = intersect(tmpid,x1(:,master_id));

        if(isempty(kx))

            fastinsert(conn,'tblScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);
            fastinsert(conn,'tblOrigScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);

        else
            disp('The ID above is already uploaded.');

            % check if this is an adjudication result
            ax = intersect(tmpid,x2(:,col_adjid));
            if(~isempty(ax))

              % ID is in the Adj table, check if it was actually sent for adj
              chk_adj_send = x2{ax(1),col_adjsend};
              if(chk_adj_send>eps)
                % yes it was sent for adj, this is probably the adj results

                disp('These are adjudication results, uploading as final scores.')
                
                % change reader name to adjudication
                xS{jx,col_reader} = 'adjudication';

                % insert the results into tblScreening_DF for online report
                fastinsert(conn,'tblScreening_DF',fS(2:end)',xS(jx,2:end)); pause(0.2);

              end
            end

        end

    else % not signed, skip record for now

        disp('The record above is not signed.');

    end

end

close(conn);

if(isempty(chk_read_all))
    movefile(mdbf,destf);
end
