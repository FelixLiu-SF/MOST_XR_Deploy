function Send_Review_to_DF()
%% function to send screening XRs for review with BU

%% initialize
disp(' ');
disp('Initializing...');

% parameters
dvd_date = datestr(now,'yyyymmdd');

% mdbf
mdbf_qc = '\\fu-hsing\most\Imaging\144-month\MOST_XR_144M_Master.accdb';

% get scoresheet template for DF review
template_dir = 'S:\FelixTemp\XR\Scoresheet_Templates\AdjDF_Templates';
[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

% set up directories
output_dir = 'E:\most-dicom\XR_QC\Sent\Screening';
final_destination = '\\MOST-FTPS\mostftps\SITE03\XR\DOWNLOAD\SCREENING';

batch_dir = horzcat(output_dir,'\Batches\Batch_',dvd_date);
mdbf = horzcat(output_dir,'\Scoresheets\MOST_XR_ScreeningDF_',dvd_date,'.mdb');
final_dir = horzcat(final_destination,'\DICOM\',dvd_date);
final_mdbf = horzcat(final_destination,'\MOST_XR_ScreeningDF_',dvd_date,'.mdb');

if(~exist(mdbf,'file')) % continue if this scoresheet hasn't been made
    
    disp(' ');
    disp('Reading data from database');
    
    %% read master data
    [x1,f1] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblScreening_PA');
    [x2,f2] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblScreening_DF');
    [x3,f3] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblOrigScreening_DF');
    [x4,f4] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblReviewDF_Sent');
    
    % filter read DF
    x_out = x1(~ismember(x1(:,indcfind(f1,'^READINGID$','regexpi')),x2(:,indcfind(f2,'^READINGID$','regexpi'))),:);
    
    % filter out pending Adjudication
    x_out = x_out(~ismember(x_out(:,indcfind(f1,'^READINGID$','regexpi')),x3(:,indcfind(f3,'^READINGID$','regexpi'))),:);
    
    % filter out pending DF Review
    x_out = x_out(~ismember(x_out(:,indcfind(f1,'^READINGID$','regexpi')),x4(:,indcfind(f4,'^READINGID$','regexpi'))),:);
    
    
    x_out = sortrows(x_out,1);
    
    
    %% filter for last 90 days only
    f1_edate = indcfind(f1,'^E_DATE$','regexpi');
    start_num = now - 90;
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
    
    % create mdbf if any records remaining
    if(size(x1_up,1)>0)
        
        disp(' ');
        disp('Records to send for review: ');
        disp(x1_up);
        
        pause(2);
        copyfile(mdbf_template,mdbf);
        pause(2);
        
%         connurl = ['jdbc:odbc:Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=' mdbf_df];
%         conn = database('','','','sun.jdbc.odbc.JdbcOdbcDriver', connurl);
        conn = DeployMSAccessConn(mdbf);
        
        for ix=1:size(x1_up,1)
            fastinsert(conn,'tblScores',f1_up(1:end),x1_up(ix,1:end)); pause(0.25);
            fastinsert(conn,'tblOrigScores',f1_up(1:end),x1_up(ix,1:end)); pause(0.25);
        end
        close(conn);
        
        % send to MOST-FTPS
        copyfile(mdbf,final_mdbf);
        
        % upload to database
        UploadToMDB(mdbf_qc,'tblReviewDF_Sent',f1_up,x1_up);

        
    end

end