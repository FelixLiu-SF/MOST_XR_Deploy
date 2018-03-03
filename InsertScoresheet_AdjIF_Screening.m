function InsertScoresheet_AdjIF_Screening(mdbf_qc,mdbf,prefill_up,f_in,dvd_date)
% this function inserts new blank records for screening scoresheet

% initialize
[x_pa,f_pa]   = DeployMDBquery(mdbf_qc,'SELECT * FROM tblScreening_PA');
[x_odf,f_odf] = DeployMDBquery(mdbf_qc,'SELECT * FROM tblOrigScreening_DF');

side = 3;
knee = 'B';

% table columns for upload
f_up_new = {...
    'READINGID';...
    'READINGACRO';...
    'DVD';...
    'SIDE';...
    'KNEE';...
    'V1BLINDDATE';...
    'V1TFBARCDBU';...
    'V1NUMXR';...
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

u_id = unique(prefill_up(:,f_PatientID));

conn = DeployMSAccessConn(mdbf);

% loop through each ID
for px=1:size(u_id,1)
    
  f_up = {};
  tmpid = u_id{px,1};
  
  % check for existing scores
  jx_odf = indcfind(x_odf(:,indcfind(f_odf,'^READINGID$','regexpi')),tmpid,'regexpi');
  jx_pa =  indcfind(x_pa(:,indcfind(f_pa,'^READINGID$','regexpi')),tmpid,'regexpi');
  
  if(~isempty(jx_odf))
      %% found existing DF scores, insert these
      
      [tmp_up, f_up] = CleanExistingScreeningScores(x_odf(jx_odf(end,1),:), f_odf);
      
  elseif(~isempty(jx_pa))
      %% can only find existing PA scores, insert these
      
      [tmp_up, f_up] = CleanExistingScreeningScores(x_pa(jx_pa(end,1),:), f_pa);
      
  else
      %% can't find existing scores, insert blank record
      
      % collect images with matching ID
      tmpstudy = prefill_up(indcfind(prefill_up(:,f_PatientID),tmpid,'regexpi'),:);

      % collect metadata
      tmpname = tmpstudy{1,f_PatientName};
      tmpstudydate = tmpstudy{1,f_StudyDate};
      tmpstudybc = tmpstudy{1,f_StudyBarcode};

      tmpnum = size(tmpstudy,1);

      % arrange data to insert
      % arrange data to insert
      tmp_up = {...
          tmpid,...
          tmpname,...
          dvd_date,...
          side,...
          knee,...
          tmpstudydate,...
          tmpstudybc,...
          tmpnum,...
          };
      
      f_up = f_up_new;
      
  end

  %upload the data
  fastinsert(conn,'tblScores',f_up,tmp_up); pause(1);
  fastinsert(conn,'tblOrigScores',f_up,tmp_up); pause(1);

end

close(conn);
pause(1);
