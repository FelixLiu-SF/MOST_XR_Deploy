function [mdbf]=Deploy_ScreeningDF_Scoresheet(prefill_out, acc_out, dcmdir_in)

%% preset parameters
side = 3;
knee = 'B';

template_dir =  'E:\MOST-Renewal-II\XR\BLINDING\Scoresheet_Templates\ScreeningDF_Templates';
out_dir =       'E:\MOST-Renewal-II\XR\BLINDING\For_Screening\Scoresheets\';

%% parse input data
if(strcmpi(dcmdir_in(end),'\'))
    dcmdir_in = dcmdir_in(1:end-1);
end
[~,dn,~]=fileparts(dcmdir_in);
dvd_date = dn;

[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

mdbf = horzcat(out_dir,'MOST_XR_ScreeningDF_',dvd_date,'.mdb');
copyfile(mdbf_template,mdbf);

% [x,f]=MDBquery(mdbf,'SELECT * from tblScores');
% [xbarc,fbarc]=MDBquery(mdbf,'SELECT * from tblAccession');

%% arrange table columns for upload
f_up = {...
    'READINGID';...
    'READINGACRO';...
    'DVD';...
    'SIDE';...
    'KNEE';...
    'V1BLINDDATE';...
    'V1TFBARCDBU';...
    'V1NUMXR';...
    };

%% arrange table data

%collect and upload data to mdb scoresheet
conn = RobustMSAccessConn(mdbf);

u_id = unique(prefill_out(:,1));
tbl_up = [u_id, cell(size(u_id,1),14)];
for ix=1:size(u_id,1)
    
    tmpid = u_id{ix,1};
    
    trueid = regexp(tmpid,'M[BI][0-9]{5}','match');
    if(~isempty(trueid))
        trueid = trueid{1};
    else
        trueid = regexp(strrep(upper(tmpid),'O','0'),'M[BI][0-9]{5}','match');
        if(~isempty(trueid))
            trueid = trueid{1};
        else
            trueid = tmpid;
        end
    end
    
    tmpjx = indcfind(prefill_out(:,1),horzcat('^',tmpid,'$'),'regexpi');
    tmpacro = prefill_out{tmpjx(1),2};
    tmpdate = prefill_out{tmpjx(1),3};
    
    tmpnum = prefill_out{tmpjx(1),5};
    
    % get accession data
    tmpseracc = prefill_out(tmpjx,7);
    tmpseracc = regimatch(tmpseracc,'^F[0-9]{4}');
    tmpacc = unique(tmpseracc);
    tmpacc = tmpacc{1};
    
    
    % arrange data
    tmp_up = {...
        trueid;...
        tmpacro;...
        dvd_date;...
        side;...
        knee;...
        tmpdate;...
        tmpacc;...
        tmpnum;...
        };
    
    %upload the data
    fastinsert(conn,'tblScores',f_up,tmp_up'); pause(1);
    fastinsert(conn,'tblOrigScores',f_up,tmp_up'); pause(1);
    
end

close(conn);


