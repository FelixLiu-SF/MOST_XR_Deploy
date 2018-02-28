

%% get parameters

dir_PA_src =    'C:\Users\fliu2\Box Sync\OAI_XR_ReaderA\MOST\Scoresheets';
dir_PA_dest =   'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Resend_For_DavidFelson\Copy_of_PA_Scoresheets';
dir_DF =        'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Resend_For_DavidFelson\Send_to_DavidFelson';
template_dir =  'E:\MOST-Renewal-II\XR\BLINDING\Scoresheet_Templates\AdjDF_Templates';

master_mdbf =   'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

tmp_date = now;
% if(weekday(tmp_date)==2 || weekday(tmp_date)==4)
%     dvd_date = datestr(tmp_date,'yyyymmdd');
% else
%     dvd_date = datestr(tmp_date,'yyyymmdd');
%     while(weekday(tmp_date)~=2 && weekday(tmp_date)~=4)
%         tmp_date = tmp_date - 1;
%         dvd_date = datestr(tmp_date,'yyyymmdd');
%     end
% end
dvd_date = datestr(tmp_date,'yyyymmdd');

%% define output

mdbf_df = horzcat(dir_DF,'\','MOST_XR_ScreeningDF_',dvd_date,'.mdb');

if(~exist(mdbf_df))

    %% input dir
    [s,m] = robofun(dir_PA_src,dir_PA_dest,'',0);
    disp(m);

    [~,~,list_input]=foldertroll(dir_PA_dest,'.mdb');
    [~,~,list_sent]=foldertroll(dir_DF,'.mdb');

    %% read master data
    [x1,f1] = MDBquery(master_mdbf,'SELECT * FROM tblScreening_PA');
    [x2,f2] = MDBquery(master_mdbf,'SELECT * FROM tblScreening_DF');

    %% insert read PA data into dummy Master mdbf

    for ix=1:size(list_input,1)

        tmpf = list_input{ix,1};

        %collect data from mdb scoresheet
        [xS,fS] = MDBquery(tmpf,'SELECT * FROM tblScores');

        col_edate = indcfind(fS,'^E_DATE$','regexpi');
        col_dvd =   indcfind(fS,'^DVD$','regexpi');

        col_tfrt = indcfind(fS,'^V1TFKLG_R$','regexpi');
        col_pfrt = indcfind(fS,'^V1PFKLG_R$','regexpi');
        col_tflt = indcfind(fS,'^V1TFKLG_L$','regexpi');
        col_pflt = indcfind(fS,'^V1PFKLG_L$','regexpi');

        col_DF = indcfind(fS,'^V1REVIEWDF$','regexpi');

        %check if scoresheet uploaded already
        u_dvd = unique(xS(:,col_dvd));
        kx = intersect(u_dvd(end,:),x1(:,indcfind(f1,'^DVD$','regexpi')));

        if(isempty(kx))

%             connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' master_mdbf];
%             conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);
            conn = RobustMSAccessConn(master_mdbf);
            
            for jx=1:size(xS,1)

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
                    
                    fastinsert(conn,'tblScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);
                    fastinsert(conn,'tblOrigScreening_PA',fS(2:end)',xS(jx,2:end)); pause(0.2);

                end        
            end

            close(conn);

        end
        
        clear xS

    end

    %% create new Screening DF scoresheet from temp dummy Master mdbf

    % get updated data
    [x1,f1] = MDBquery(master_mdbf,'SELECT * FROM tblScreening_PA');
    [x2,f2] = MDBquery(master_mdbf,'SELECT * FROM tblScreening_DF');
    
    f1_edate = indcfind(f1,'^E_DATE$','regexpi');
    f2_edate = indcfind(f2,'^E_DATE$','regexpi');
    
    del1 = [];
    del2 = [];
    
    for ix=1:size(x1,1)
        if(isempty(x1{ix,f1_edate}))
            del1 = [del1;ix];
        end
    end
    x1(del1,:) = [];
    
    for ix=1:size(x2,1)
        if(isempty(x2{ix,f2_edate}))
            del2 = [del2;ix];
        end
    end
    x2(del2,:) = [];
    
    % filter read DF
    x_out = x1(~ismember(x1(:,indcfind(f1,'^READINGID$','regexpi')),x2(:,indcfind(f2,'^READINGID$','regexpi'))),:);
    x_out = sortrows(x_out,1);
    
    % filter unread DF
    for ix=1:size(list_sent,1)

        tmpf = list_sent{ix,1};

        %collect data from mdb scoresheet
        [xD,fD] = MDBquery(tmpf,'SELECT * FROM tblScores');
        x_out = x_out(~ismember(x_out(:,indcfind(f1,'^READINGID$','regexpi')),xD(:,indcfind(fD,'^READINGID$','regexpi'))),:);
        
    end
    
    % check only last 30 days
    start_num = now - 30;
    read_datenum = cellfun(@datenum,x_out(:,indcfind(f1,'^E_DATE$','regexpi')),repcell([size(x_out,1),1],'yyyymmdd'),'UniformOutput',0);
    x_out = x_out(find(cell2mat(read_datenum)>=start_num),:);
    
    %% get parameters
    f_select = {...
        'READINGID';...
        'READINGACRO';...
        'DVD';...
        'SIDE';...
        'KNEE';...
        'V1BLINDDATE';...
        'V1TFBARCDBU';...
        'V1NUMXR';...
        'V1TFKLG_R';...
        'V1TFJSC_R';...
        'V1TFCHD_R';...
        'V1TFCHM_R';...
        'V1TFCHL_R';...
        'V1TFKLG_L';...
        'V1TFJSC_L';...
        'V1TFCHD_L';...
        'V1TFCHM_L';...
        'V1TFCHL_L';...
        'V1PFBARCDBU';...
        'V1PFKLG_R';...
        'V1PFXJS_R';...
        'V1PFKLG_L';...
        'V1PFXJS_L';...
        'V1INCIDF_R';...
        'V1INCIDF_L';...
        'COMMENTS';...
        'COMMENTS_REVIEW';...
        'V1REVIEWDF';...
        'V1REVIEWPA'};

    f1_up = f1(ismember(f1,f_select));
    x1_up = x_out(:,ismember(f1,f_select));

    x1_up = sortrows(x1_up,indcfind(f1_up,'^DVD$','regexpi'));
    
    col_pa_COMMENTS = indcfind(f1_up,'^COMMENTS$','regexpi');
    col_pa_COMMENTS_REVIEW = indcfind(f1_up,'^COMMENTS_REVIEW$','regexpi');
        
    keep_up = [];
    del_up = [];
    
    for ix=1:size(x1_up,1)
        % filter KLG
        chkr1 = x1_up{ix,indcfind(f1_up,'^V1TFKLG_R$','regexpi')};
        chkr2 = x1_up{ix,indcfind(f1_up,'^V1PFKLG_R$','regexpi')};
        chkl1 = x1_up{ix,indcfind(f1_up,'^V1TFKLG_L$','regexpi')};
        chkl2 = x1_up{ix,indcfind(f1_up,'^V1PFKLG_L$','regexpi')};
        chki1 = x1_up{ix,indcfind(f1_up,'^V1INCIDF_R$','regexpi')};
        chki2 = x1_up{ix,indcfind(f1_up,'^V1INCIDF_L$','regexpi')};
        chkdf = x1_up{ix,indcfind(f1_up,'^V1REVIEWDF$','regexpi')};
        chkpa = x1_up{ix,indcfind(f1_up,'^V1REVIEWPA$','regexpi')};
        
%         x_adj{ix,col_odf_COMMENTS_REVIEW} = horzcat(x_adj{ix,col_odf_COMMENTS_REVIEW},' ',x_adj{ix,col_odf_COMMENTS});
        tmp_comments = '';
        try
            tmp_comments = horzcat(tmp_comments,' ',x1_up{ix,col_pa_COMMENTS});
        catch
        end
        try
            tmp_comments = horzcat(tmp_comments,' ',x1_up{ix,col_pa_COMMENTS_REVIEW});
        catch
        end
        
        x1_up{ix,col_pa_COMMENTS} = tmp_comments;
        x1_up{ix,col_pa_COMMENTS_REVIEW} = '';

        if( ( (max(chkr1==[2,3])>0 || max(chkr2==[2,3])>0 || max(chkl1==[2,3])>0 || max(chkl2==[2,3])>0) && (chki1==-1 || chki2==-1 || chkdf==-1) ) || ...
                ( (abs(chkr1 + 6)<0.1 && abs(chkr2 + 6)<0.1 && abs(chkl1 + 6)<0.1 && abs(chkl2 + 6)<0.1) && (chkdf==-1) ) || ... 
                ((chki1==-1 || chki2==-1) && chkdf==-1 && chkpa==-1) )
            keep_up = [keep_up; ix];
        else
            del_up = [del_up; ix];
        end
        
    end
    
    x1_up = x1_up(keep_up,:);
    
    for ix=1:size(x1_up,1)
        x1_up{ix,indcfind(f1_up,'^V1REVIEWPA$','regexpi')} = 0;
    end
    
    %% get newest template
    [~,~,list_template]=foldertroll(template_dir,'.mdb');
    mdbf_template = list_template{end,1};
    
    % create mdbf if any records remaining
    if(size(x1_up,1)>0)
        
        pause(2);
        copyfile(mdbf_template,mdbf_df);
        pause(2);
        
%         connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' mdbf_df];
%         conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);
        conn = RobustMSAccessConn(mdbf_df);
        
        for ix=1:size(x1_up,1)
            fastinsert(conn,'tblScores',f1_up(1:end),x1_up(ix,1:end)); pause(0.25);
            fastinsert(conn,'tblOrigScores',f1_up(1:end),x1_up(ix,1:end)); pause(0.25);
        end
        close(conn);
        
    end

end

exit;

