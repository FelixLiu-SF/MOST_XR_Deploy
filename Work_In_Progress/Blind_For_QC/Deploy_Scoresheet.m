function [mdbf]=Deploy_Scoresheet(prefill_out, acc_out, dcmdir_in)

%% preset parameters
side = 3;
knee = 'B';

template_dir =  'E:\MOST-Renewal-II\XR\BLINDING\Scoresheet_Templates\QC';
out_dir =       'E:\MOST-Renewal-II\XR\BLINDING\For_QC\Scoresheets\';
prevscoresf =   'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\DPVR\v01235xray_20140128.csv';
prevBAf =       'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\DPVR\MOST_V6BEAM_2016FEB21_update_beam.xls';

%% parse input data
if(strcmpi(dcmdir_in(end),'\'))
    dcmdir_in = dcmdir_in(1:end-1);
end
[~,dn,~]=fileparts(dcmdir_in);
dvd_date = dn;

[~,~,list_template]=foldertroll(template_dir,'.mdb');
mdbf_template = list_template{end,1};

mdbf = horzcat(out_dir,'MOST_XR_QC_',dvd_date,'.mdb');
copyfile(mdbf_template,mdbf);

% [x,f]=MDBquery(mdbf,'SELECT * from tblScores');
% [xbarc,fbarc]=MDBquery(mdbf,'SELECT * from tblAccession');

prevscores = readdlm(prevscoresf,',');
prevh = prevscores(1,:)';

[~,~,prevBA] = xlsread(prevBAf);

acc_out(:,1) = regimatch(acc_out(:,1),'M[BI][0-9]{5}');


%% arrange table columns for upload
f_up = {...
    'READINGID';...
    'READINGACRO';...
    'DVD';...
    'SIDE';...
    'KNEE';...
    'V1BLINDDATE';...
    'V1TFBARCDBU';...
    'V1RLBARCDBU';...
    'V1LLBARCDBU';...
    'V1FLBARCDBU';...
    'V1NUMPA';...
    'V1NUMRL';...
    'V1NUMLL';...
    'V1NUMFL';...
    'XRPAREC';...
    'XRPARECN';...
    'XRPARE05';...
    'XRPARE10';...
    'XRPARE15';...
    'XRLAREC';...
    'XRLARECN';...
    'XRLARECN_R';...
    'XRLARECN_L';...
    'XRFLREC';...
    'XRFLRECN';...
    'XRPABEST';...
    'XRLLBEST';...
    'XRRLBEST';...
    'V0XRVISIT';...
    'V0XRBA';...
    'V0TFKLG_R';...
    'V0TFJSM_R';...
    'V0TFJSL_R';...
    'V0TFCHM_R';...
    'V0TFCHL_R';...
    'V0TFKLG_L';...
    'V0TFJSM_L';...
    'V0TFJSL_L';...
    'V0TFCHM_L';...
    'V0TFCHL_L';...
    };

f_barc_up = {...
    'READINGID';...
    'BARCODE';...
    'ACCESSION';...
    'SERIESNUM';...
    'SERIESDESC';...
    'STUDYDATE';...
    'SOPINSTANCEUID'
    };

%% arrange table data

jx_PA05 = indcfind(prefill_out(:,8),'^PA05$','regexpi');
jx_PA10 = indcfind(prefill_out(:,8),'^PA10$','regexpi');
jx_PA15 = indcfind(prefill_out(:,8),'^PA15$','regexpi');
jx_RLAT = indcfind(prefill_out(:,8),'^RLAT$','regexpi');
jx_LLAT = indcfind(prefill_out(:,8),'^LLAT$','regexpi');
jx_FLMB = indcfind(prefill_out(:,8),'^Full Limb$','regexpi');

jx_PAx = [jx_PA05; jx_PA10; jx_PA15];

%collect and upload data to mdb scoresheet
conn = RobustMSAccessConn(mdbf);

u_id = unique(prefill_out(:,1));
tbl_up = [u_id, cell(size(u_id,1),40)];
for ix=1:size(u_id,1)
    
    try
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

        tmpjx = indcfind(prefill_out(:,1),horzcat('^',trueid,'$'),'regexpi');
        tmpacro = prefill_out{tmpjx(1),2};
        tmpdate = prefill_out{tmpjx(1),3};

        % get series data
        tmpserx = intersect(tmpjx,jx_PAx);
        if(~isempty(tmpserx))
            tmpPA = 1;
            barcPA = prefill_out{tmpserx(1),7};
            numPA = prefill_out{tmpserx(1),6};
            recnPA = sum([prefill_out{tmpserx,5}]);
        else
            tmpPA = 0;
            barcPA = '';
            numPA = 0;
            recnPA = 0;
        end
        tmpserx = intersect(tmpjx,jx_RLAT);
        if(~isempty(tmpserx))
            tmpRL = 1;
            barcRL = prefill_out{tmpserx(1),7};
            numRL = prefill_out{tmpserx(1),6};
            recnRL = sum([prefill_out{tmpserx,5}]);
        else
            tmpRL = 0;
            barcRL = '';
            numRL = 0;
            recnRL = 0;
        end
        tmpserx = intersect(tmpjx,jx_LLAT);
        if(~isempty(tmpserx))
            tmpLL = 1;
            barcLL = prefill_out{tmpserx(1),7};
            numLL = prefill_out{tmpserx(1),6};
            recnLL = sum([prefill_out{tmpserx,5}]);
        else
            tmpLL = 0;
            barcLL = '';
            numLL = 0;
            recnLL = 0;
        end
        tmpserx = intersect(tmpjx,jx_FLMB);
        if(~isempty(tmpserx))
            tmpFL = 1;
            barcFL = prefill_out{tmpserx(1),7};
            numFL = prefill_out{tmpserx(1),6};
            recnFL = sum([prefill_out{tmpserx,5}]);
        else
            tmpFL = 0;
            barcFL = '';
            numFL = 0;
            recnFL = 0;
        end

        if(recnPA>0)
            recPA = 1;
            if(recnPA==1)
                tmpserx = intersect(tmpjx,jx_PAx);
                bestPA = horzcat(prefill_out{tmpserx(1),7},'01');
            else
                bestPA = '';
            end
            tmpserx = intersect(tmpjx,jx_PA05);
            if(~isempty(tmpserx)); chk05 = -1; else; chk05 = 0; end
            tmpserx = intersect(tmpjx,jx_PA10);
            if(~isempty(tmpserx)); chk10 = -1; else; chk10 = 0; end
            tmpserx = intersect(tmpjx,jx_PA15);
            if(~isempty(tmpserx)); chk15 = -1; else; chk15 = 0; end
        else
            recPA = 0;
            chk05 = 0;
            chk10 = 0;
            chk15 = 0;
            bestPA = '';
        end

        if(recnRL>0 || recnLL>0)
            recLA = 1;
            recnLA = recnRL + recnLL;
        else
            recLA = 0;
            recnLA = 0;
        end
        if(recnRL==1)
            tmpserx = intersect(tmpjx,jx_RLAT);
            bestRL = horzcat(prefill_out{tmpserx(1),7},'01');
        else
            bestRL = '';
        end
        if(recnLL==1)
            tmpserx = intersect(tmpjx,jx_LLAT);
            bestLL = horzcat(prefill_out{tmpserx(1),7},'01');
        else
            bestLL = '';
        end

        if(recnFL>0)
            recFL = 1;
            if(recnFL==1)
                tmpserx = intersect(tmpjx,jx_FLMB);
                bestFL = horzcat(prefill_out{tmpserx(1),7},'01');
            else
                bestFL = '';
            end

        else
            recFL = 0;
            bestFL = '';
        end

        %get previous visit scores

        kx = indcfind(prevscores(:,1),trueid,'regexpi');
        if(~isempty(kx))
            tmprow = prevscores(kx(1),:);

            if(~isempty(tmprow{1,8}))
                tmpvisit = 'V5';
                tmpvstr = '84M';
            elseif(~isempty(tmprow{1,7}))
                tmpvisit = 'V3';
                tmpvstr = '60M';
            elseif(~isempty(tmprow{1,6}))
                tmpvisit = 'V2';
                tmpvstr = '30M';
            elseif(~isempty(tmprow{1,5}))
                tmpvisit = 'V1';
                tmpvstr = '15M';
            elseif(~isempty(tmprow{1,4}))
                tmpvisit = 'V0';
                tmpvstr = 'BL';
            else
                tmpvisit = '';
                tmpvstr = '';
            end
        else
            tmpvisit = '';
            tmpvstr = '';
        end

        if(~isempty(tmpvisit))
            pXLKL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XLKL'),'regexpi')};
            pXLCHOL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XLCHOL'),'regexpi')};
            pXLCHOM = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XLCHOM'),'regexpi')};
            pXLJSL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XLJSL'),'regexpi')};
            pXLJSM = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XLJSM'),'regexpi')};
            pXRKL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XRKL'),'regexpi')};
            pXRCHOL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XRCHOL'),'regexpi')};
            pXRCHOM = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XRCHOM'),'regexpi')};
            pXRJSL = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XRJSL'),'regexpi')};
            pXRJSM = tmprow{1,indcfind(prevh,horzcat(tmpvisit,'XRJSM'),'regexpi')};
        else
            pXLKL = '';
            pXLCHOL = '';
            pXLCHOM = '';
            pXLJSL = '';
            pXLJSM = '';
            pXRKL = '';
            pXRCHOL = '';
            pXRCHOM = '';
            pXRJSL = '';
            pXRJSM = '';
        end

        %expected beam angle
        bx = indcfind(prevBA(:,1),trueid,'regexpi');
        if(~isempty(bx))
            tmpBA = str2num(prevBA{bx(1),2});
        else
            tmpBA = [];
        end

        % arrange data
        tmp_up = {...
            trueid;...
            tmpacro;...
            dvd_date;...
            side;...
            knee;...
            tmpdate;...
            barcPA;...
            barcRL;...
            barcLL;...
            barcFL;...
            numPA;...
            numRL;...
            numLL;...
            numFL;...
            recPA;...
            recnPA;...
            chk05;...
            chk10;...
            chk15;...
            recLA;...
            recnLA;...
            recnRL;...
            recnLL;...
            recFL;...
            recnFL;...
            bestPA;...
            bestLL;...
            bestRL;...
            tmpvstr;...
            tmpBA;...
            pXRKL;...
            pXRJSM;...
            pXRJSL;...
            pXRCHOM;...
            pXRCHOL;...
            pXLKL;...
            pXLJSM;...
            pXLJSL;...
            pXLCHOM;...
            pXLCHOL;
            };

        %get accession data
        tmp_barc = acc_out(indcfind(acc_out(:,1),trueid,'regexpi'),:);
        tmp_barc = cellfun(@num2str,tmp_barc,'UniformOutput',0);

        %upload the data
        datainsert(conn,'tblScores',f_up,tmp_up'); pause(2);
        datainsert(conn,'tblOrigScores',f_up,tmp_up'); pause(2);
        datainsert(conn,'tblAccession',f_barc_up,tmp_barc); pause(2);
        
    catch inserterr
        disp(inserterr.message);
        
    end
    
end

close(conn);


