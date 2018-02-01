function [exit_code]=MOST_XR_Anonymize(file_in,tagcell)
% exit codes:
% 1 JPEG decompression
% 2 anonymize
% 4 insert blinding metadata
% 8 fix photometric interpretation
% 16 JPEG compression

% initialize
exit_code = 0;

% decompress JPEG
[status,result] = dcmdjpeg(file_in,file_in);
if(status~=0)
  exit_code = exit_code + 1;
end

% anonymize blinding file
try
  dicomanon(file_in,file_in,'keep',{'PatientID','PatientName','AccessionNumber','SeriesNumber','StudyDescription','SeriesDescription','StudyID','StudyInstanceUID','SeriesInstanceUID','SOPInstanceUID'});
catch anonerr
  try
    err_img = dicomread(tmpf);
    dicomwrite(err_img,file_in);
  catch
    exit_code = exit_code + 2;
end

try
  [status,result] = dcmbatchmod(file_in,tagcell);
catch
  try %try again if failed
    pause(1);
    [status,result] = dcmbatchmod(file_in,tagcell);
  catch
    exit_code = exit_code + 4;
  end
end

try
    [status,result] = FixXR(file_in,tmpinfo);
catch
    try %try again if failed
        pause(1);
        [status,result] = FixXR(file_in,tmpinfo);
    catch
        status = -1;
    end
end
if(status(1)~=0)
    exit_code = exit_code + 8;
end

% re-compress JPEG
[status,result] = dcmcjpeg(file_in,file_in);
if(status~=0)
  exit_code = exit_code + 16;
end
