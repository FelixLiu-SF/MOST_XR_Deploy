function []=DICOMByteFlip(file_in,file_out,mirror_rl,mirror_tb)

  % get file info
  finfo = dir(file_in);
  dinfo = dicominfo(file_in);

  img = dicomread(file_in);
  imgsz = size(img);

  nbytes = 2;
  nheaderbytes = finfo.bytes - (nbytes*imgsz(1)*imgsz(2));

  % read in raw byte data
  fid = fopen(file_in,'r');
  fseek(fid,nheaderbytes,'bof');

  RawImg = fread(fid,Inf,'uint16');

  fclose(fid);

  % reshape image
  RawImgReshape(RawImg,imgsz(2),imgsz(1));

  MatchImg = RawImgReshape';

  % flip the image
  if(mirror_tb)
    MatchImg = MatchImg(end:-1:1,:);
  end

  if(mirror_rl)
    MatchImg = MatchImg(:,end:-1:1);
  end

  % reshape to byte format
  UnMatchImg = MatchImg';
  OutputImg = reshape(UnMatchImg,[],1);

  % copy file for output
  copyfile(file_in,file_out);

  % rewrite image data
  fod = fopen(file_out,'r+');
  fseek(fod,nheaderbytes,'bof');

  fwrite(fod,OutputImg,'uint16');

  fclose(fod);
