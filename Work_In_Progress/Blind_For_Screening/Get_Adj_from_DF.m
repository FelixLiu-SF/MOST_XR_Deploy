function [x_adj,f_adj]=Get_Adj_from_DF(datedir_in,days_back)

x_adj = {};
f_adj = {};

datenum_in = datenum(datedir_in,'yyyymmdd');
datenum_back = floor(datenum_in - days_back);

mdbf = 'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

[x_pa,f_pa]   = MDBquery(mdbf,'SELECT * FROM tblScreening_PA');
[x_df,f_df]   = MDBquery(mdbf,'SELECT * FROM tblScreening_DF');
[x_odf,f_odf] = MDBquery(mdbf,'SELECT * FROM tblOrigScreening_DF');

col_pa_READINGID  = indcfind(f_pa,'^READINGID$','regexpi');
col_df_READINGID  = indcfind(f_df,'^READINGID$','regexpi');
col_odf_READINGID = indcfind(f_odf,'^READINGID$','regexpi');

col_odf_DVD = indcfind(f_odf,'^DVD$','regexpi');
col_odf_READER = indcfind(f_odf,'^READER$','regexpi');
col_odf_EDATE = indcfind(f_odf,'^E_DATE$','regexpi');
col_odf_ETIME = indcfind(f_odf,'^E_TIME$','regexpi');
col_odf_COMMENTS = indcfind(f_odf,'^COMMENTS$','regexpi');
col_odf_COMMENTS_REVIEW = indcfind(f_odf,'^COMMENTS_REVIEW$','regexpi');
col_odf_COMMENTS_SFCC = indcfind(f_odf,'^COMMENTS_SFCC$','regexpi');

ids_odf_not_df = setdiff(x_odf(:,col_odf_READINGID),x_df(:,col_df_READINGID));
ids_odf = intersect(ids_odf_not_df,x_pa(:,col_pa_READINGID));



if(size(ids_odf,1)>0)

    f_adj = f_odf;
    x_adj = x_odf(ismember(x_odf(:,col_odf_READINGID),ids_odf),:);
    
    dvd_datenum = x_adj(:,col_odf_DVD);
    dvd_datenum = cellfun(@datenum,dvd_datenum,repcell(size(dvd_datenum),'yyyymmdd'),'UniformOutput',0);
    dvd_datenum = cell2mat(dvd_datenum);
    
    x_adj(:,col_odf_COMMENTS_SFCC) = [];
    f_adj(col_odf_COMMENTS_SFCC,:) = [];
    
    x_adj = x_adj(dvd_datenum>datenum_back,:);
    
    for ix=1:size(x_adj,1)
        
        if(isempty(x_adj{ix,col_odf_COMMENTS}))
            x_adj{ix,col_odf_COMMENTS} = '';
        end
        if(isempty(x_adj{ix,col_odf_COMMENTS_REVIEW}))
            x_adj{ix,col_odf_COMMENTS_REVIEW} = '';
        end
        
        x_adj{ix,col_odf_COMMENTS_REVIEW} = horzcat(x_adj{ix,col_odf_COMMENTS_REVIEW},' ',x_adj{ix,col_odf_COMMENTS});

        x_adj{ix,col_odf_READER} = '';
        x_adj{ix,col_odf_EDATE}  = '';
        x_adj{ix,col_odf_ETIME}  = '';
        x_adj{ix,col_odf_COMMENTS}  = 'Dr Felson has requested adjudication for this exam. Please review and confirm KLG scores';
        
    end
end