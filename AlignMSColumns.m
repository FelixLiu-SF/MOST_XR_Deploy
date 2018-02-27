function [x_out] = AlignMSColumns(x_in,f_in,f_align)

if(size(f_in,1)>1 && size(x_in,2)>1)
  jx = [];
  for ix=1:size(f_align,1)

    tmp_f = indcfind(f_in,horzcat('^',f_align{ix,1},'$'),'regexpi');
    jx = [jx, tmp_f];

  end

  x_out = x_in(:,jx);
else
  x_out = x_in;
end
