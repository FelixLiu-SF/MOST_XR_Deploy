function InsertScoresheet_NewScreening(mdbf,prefill_up,f_in)
% this function inserts new blank records for screening scoresheet

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
  tmpid = u_id{px,1};

  % collect images with matching ID
  tmpstudy = x_up(indcfind(x_up(:,f_PatientID),tmpid,'regexpi'),:);

  % collect metadata
  tmpname = tmpstudy{1,f_PatientName};
  tmpstudydate = tmpstudy{1,f_StudyDate};
  tmpstudybc = tmpstudy{1,f_StudyBarcode};

  tmpnum = size(tmpstudy,1);

  % arrange data to insert
  tmp_up = {...
      tmpid;...
      tmpname;...
      dvd_date;...
      side;...
      knee;...
      tmpstudydate;...
      tmpstudybc;...
      tmpnum;...
      };

  %upload the data
  fastinsert(conn,'tblScores',f_up,tmp_up'); pause(1);
  fastinsert(conn,'tblOrigScores',f_up,tmp_up'); pause(1);

end

close(conn);
pause(1);
