function InsertScoresheet_NewQC(mdbf,prefill_up,f_in,dvd_date)
% this function inserts new blank records for screening scoresheet

% initialize
side = 3;
knee = 'B';

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

% column indices
f_filename = indcfind(f_in,'^filename$','regexpi');
f_SOPInstanceUID = indcfind(f_in,'^SOPInstanceUID$','regexpi');
f_PatientID = indcfind(f_in,'^PatientID$','regexpi');
f_PatientName = indcfind(f_in,'^PatientName$','regexpi');
f_StudyDate = indcfind(f_in,'^StudyDate$','regexpi');
f_View = indcfind(f_in,'^View$','regexpi');
f_StudyBarcode = indcfind(f_in,'^StudyBarcode$','regexpi');
f_SeriesBarcode = indcfind(f_in,'^SeriesBarcode$','regexpi');
f_FileBarcode = indcfind(f_in,'^FileBarcode$','regexpi');


%% arrange table data

jx_PA05 = indcfind(prefill_up(:,f_View),'^PA05$','regexpi');
jx_PA10 = indcfind(prefill_up(:,f_View),'^PA10$','regexpi');
jx_PA15 = indcfind(prefill_up(:,f_View),'^PA15$','regexpi');
jx_RLAT = indcfind(prefill_up(:,f_View),'^RLAT$','regexpi');
jx_LLAT = indcfind(prefill_up(:,f_View),'^LLAT$','regexpi');
jx_FLMB = indcfind(prefill_up(:,f_View),'^Full Limb$','regexpi');
jx_PAx = [jx_PA05; jx_PA10; jx_PA15];

u_id = unique(prefill_up(:,f_PatientID));

conn = DeployMSAccessConn(mdbf);

% loop through each ID, collect and upload data to mdb scoresheet
for ix=1:size(u_id,1)
    
    % this ID
    tmpid = u_id{ix,1};

    % collect images with matching ID
    tmpjx = indcfind(prefill_up(:,f_PatientID),tmpid,'regexpi');
    tmpstudy = prefill_up(tmpjx,:);
    
    disp(tmpstudy);
  
    % sanitize inputs
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
        
    % collect metadata
    tmpacro = tmpstudy{1,f_PatientName};
    tmpdate = tmpstudy{1,f_StudyDate};
    tmpstudybc = tmpstudy{1,f_StudyBarcode};

    tmpnum = size(tmpstudy,1);
    
    
        % get series data
        tmpserx = intersect(tmpjx,jx_PAx);
        if(~isempty(tmpserx))
            tmpPA = 1;
            barcPA = prefill_up{tmpserx(1),f_SeriesBarcode}; 
            numPA = size(tmpserx,1); %originally included prev visits
            recnPA = size(tmpserx,1); %num of recd images in this view
        else
            tmpPA = 0;
            barcPA = '';
            numPA = 0;
            recnPA = 0;
        end
        tmpserx = intersect(tmpjx,jx_RLAT);
        if(~isempty(tmpserx))
            tmpRL = 1;
            barcRL = prefill_up{tmpserx(1),f_SeriesBarcode}; 
            numRL = size(tmpserx,1);
            recnRL = size(tmpserx,1);
        else
            tmpRL = 0;
            barcRL = '';
            numRL = 0;
            recnRL = 0;
        end
        tmpserx = intersect(tmpjx,jx_LLAT);
        if(~isempty(tmpserx))
            tmpLL = 1;
            barcLL = prefill_up{tmpserx(1),f_SeriesBarcode}; 
            numLL = size(tmpserx,1);
            recnLL = size(tmpserx,1);
        else
            tmpLL = 0;
            barcLL = '';
            numLL = 0;
            recnLL = 0;
        end
        tmpserx = intersect(tmpjx,jx_FLMB);
        if(~isempty(tmpserx))
            tmpFL = 1;
            barcFL = tmpstudy{tmpserx(1),f_SeriesBarcode}; 
            numFL = size(tmpserx,1);
            recnFL = size(tmpserx,1);
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
                bestPA = horzcat(barcPA,'01');
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
            bestRL = horzcat(barcRL,'01');
        else
            bestRL = '';
        end
        if(recnLL==1)
            tmpserx = intersect(tmpjx,jx_LLAT);
            bestLL = horzcat(barcLL,'01');
        else
            bestLL = '';
        end

        if(recnFL>0)
            recFL = 1;
            if(recnFL==1)
                tmpserx = intersect(tmpjx,jx_FLMB);
                bestFL = horzcat(barcFL,'01');
            else
                bestFL = '';
            end

        else
            recFL = 0;
            bestFL = '';
        end
        %
        
        % previous XR scores not being collected here anymore
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
        tmpBA = [];
        tmpvstr = '';
        
        % arrange data to insert
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
        
        % construct table for accession numbers
        
        tmp_barc = cell(size(tmpstudy,1),7);
        tmp_barc(:,1) = tmpstudy(:,f_PatientID);
        tmp_barc(:,2) = tmpstudy(:,f_FileBarcode);
        tmp_barc(:,3) = tmpstudy(:,f_SeriesBarcode);
        tmp_barc(:,5) = tmpstudy(:,f_View);
        tmp_barc(:,6) = tmpstudy(:,f_StudyDate);
        tmp_barc(:,7) = tmpstudy(:,f_SOPInstanceUID);
        for jx=1:size(tmp_barc,1)
            tmpview = tmp_barc{jx,5};
            switch tmpview
                case 'PA05'
                    tmp_barc{jx,4} = '1';
                case 'PA10'
                    tmp_barc{jx,4} = '1';
                case 'PA15'
                    tmp_barc{jx,4} = '1';
                case 'LLAT'
                    tmp_barc{jx,4} = '4';
                case 'RLAT'
                    tmp_barc{jx,4} = '5';
                otherwise
                    tmp_barc{jx,4} = '6';
            end
        end
        
        disp(tmp_barc);

    %upload the data
    fastinsert(conn,'tblScores',f_up,tmp_up'); pause(1);
    fastinsert(conn,'tblOrigScores',f_up,tmp_up'); pause(1);
    datainsert(conn,'tblAccession',f_barc_up,tmp_barc); pause(2);

end

close(conn);
pause(1);
