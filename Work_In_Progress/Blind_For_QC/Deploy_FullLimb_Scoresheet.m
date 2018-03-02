function [mdbf]=Deploy_FullLimb_Scoresheet(prefill_out, xsfinal,fs,dcmdir_in)

%% preset parameters
side = 3;
knee = 'B';

template_dir =  'E:\MOST-Renewal-II\XR\BLINDING\Scoresheet_Templates\QC_FullLimb';
out_dir =       'E:\MOST-Renewal-II\XR\BLINDING\For_FullLimb\Scoresheets\';

masterf = 'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

%% get tracking form data
[xt,ft]=MDBquery(masterf,'SELECT * FROM tblmatched_flxr_tf_mAs');

%% parse input data
if(strcmpi(dcmdir_in(end),'\'))
    dcmdir_in = dcmdir_in(1:end-1);
end
[~,dn,~]=fileparts(dcmdir_in);
dvd_date = dn;

fs_rec = indcfind(fs,'XR.*REC$','regexpi');

[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

mdbf = horzcat(out_dir,'MOST_XR_FullLimb_',dvd_date,'.mdb');
copyfile(mdbf_template,mdbf);


%% clear comments
for ix=1:size(xsfinal,1)
    xsfinal{ix,indcfind(fs,'^COMMENTS$','regexpi')} = '';
    xsfinal{ix,indcfind(fs,'^COMMENTS_REVIEW$','regexpi')} = '';
    xsfinal{ix,indcfind(fs,'^COMMENTS_SFCC$','regexpi')} = '';
end

%% collect and upload data to mdb scoresheet
conn = RobustMSAccessConn(mdbf);

u_id = unique(prefill_out(:,1));

for ix=1:size(u_id,1)
    
    tmpid = u_id{ix,1};
    
    jx = indcfind(prefill_out(:,1),tmpid,'regexpi');
    
    kx = indcfind(xsfinal(:,indcfind(fs,'^READINGID$','regexpi')),tmpid,'regexpi');
    tmprow = xsfinal(kx(end),:);
    
    %delete NaNs & empties
    for nx=1:size(tmprow,2)
        if(isnan(tmprow{1,nx}))
            tmprow{1,nx} = '';
        elseif(isempty(tmprow{1,nx}))
            tmprow{1,nx} = '';
        end
    end
    for mx=1:length(fs_rec)
        nx=fs_rec(mx);
        if(strcmpi(class(tmprow{1,nx}),'char'))
            tmprow{1,nx} = (str2num(tmprow{1,nx}));
        end
    end
    
    newdate = prefill_out{jx(1),3};
    barcFL  = prefill_out{jx(1),7};
    numFL   = prefill_out{jx(1),6};
    recnFL   = prefill_out{jx(1),5};
    if(recnFL>0)
        recFL = 1;
    else
        recFL = 0;
    end
    
    tmprow{1,indcfind(fs,'^V1BLINDDATE$','regexpi')} = newdate;
    tmprow{1,indcfind(fs,'^V1FLBARCDBU$','regexpi')} = barcFL;
    tmprow{1,indcfind(fs,'^V1NUMFL$','regexpi')}     = numFL;
    tmprow{1,indcfind(fs,'^XRFLRECN$','regexpi')}    = recnFL;
    tmprow{1,indcfind(fs,'^XRFLREC$','regexpi')}     = recFL;
    
    
    % check tracking form for m13fltsid, mAs and comments
    tmp_flsid = '';
    tmp_mAs = '';
    tmp_comm = '';
    mx = indcfind(xt(:,indcfind(ft,'^m13id$','regexpi')),tmpid,'regexpi');
    tmp_flsid = xt{mx(1),indcfind(ft,'^m13fltsid$','regexpi')};
    tmp_mAs = xt{mx(1),indcfind(ft,'^m13flmas$','regexpi')};
    tmp_comm = xt{mx(1),indcfind(ft,'^m13flcom$','regexpi')};
    
    new_comm = horzcat('Tech ',tmp_flsid,'. ',num2str(tmp_mAs),' mAs. Clinic Comments: ',tmp_comm);
    tmprow{1,indcfind(fs,'^COMMENTS$','regexpi')} = new_comm;
    
    %filter for cols with data
    dx = indcfind(tmprow','~','empty');
    dx = intersect([2:98],dx);
    
    
    %upload the data
    datainsert(conn,'tblScores',fs(dx),tmprow(1,dx)); pause(2);
    datainsert(conn,'tblOrigScores',fs(dx),tmprow(1,dx)); pause(2);
end

close(conn);

