function [tmpstudy_out]=Blind_OldCohort_XR_Study(dcmdir_out,tmpid,tmpstudy,accnum_qc)

%% initialize
tmpstudy_out = {};

% organize series types
loop_series = unique(tmpstudy(:,6));
unknown_series =  indcfind(tmpstudy(:,6),'Unknown','regexpi');
empty_series =    indcfind(tmpstudy(:,6),'','empty');

% generate new barcode
tmpacc1 = zerofillstr(accnum_qc,4);
tmpacc1 = horzcat('6',tmpacc1);

for jx_se = 1:size(loop_series,1) %loop through each XR view type in exam

  % generate new UIDs
  newstudyuid = dicomuid;

  % collect all files for this XR view type
  this_se = loop_series{jx_se,1};
  all_se = indcfind(tmpstudy(:,6),horzcat('^',this_se,'$'),'regexpi');

  % collect files for blinding under this XR type
  tmpseries = tmpstudy(all_se,:);

  % categorize PA beam angles
  if(strcmpi(this_se,'PA'))
    [tmpseries] = Relabel_XR_PA_Views_Deploy(tmpseries);
  end %beam angle

  % add unknown/empty series to the PA series
  if(strmpci(this_se,'PA'))
    tmpseries = [tmpseries; tmpseries(unknown_series,:); tmpseries(empty_series,:)];
  end %add unknowns

  % look up series number for this XR type
  switch this_se
    case 'PA'
      tmpse=1;
    case 'PA05'
      tmpse=3;
    case 'PA10'
      tmpse=1;
    case 'PA15'
      tmpse=2;
    case 'LLAT'
      tmpse=4;
    case 'RLAT'
      tmpse=5;
    case 'Full Limb'
      tmpse=6;
    case 'Unstitched Pelvis'
      tmpse=7;
    case 'Unstitched Knee'
      tmpse=7;
    case 'Unstitched Ankle'
      tmpse=7;
    otherwise
      tmpse=7;
  end

  % generate series qc barcode
  tmpacc2 = horzcat(tmpacc1,num2str(tmpse));

  % generate output directory for this series
  newdir =  horzcat(dcmdir_out,tmpid,'_',tmpname,'\',tmpacc2);
  if(~exist(newdir))
    mkdir(newdir);
  end

  %% MISSING CODE FOR GRABBING PRIOR VISIT XRAY IMAGES %%

  %% blind XR images
  for fx=1:size(tmpseries,1)

    % get metadata for file
    tmpf =    tmpseries{fx,1};
    tmpdesc = tmpseries{fx,6};
    tmpinfo = dicominfo(tmpf);

    tmpacc3 = horzcat(tmpacc2,zerofillstr(fx,2));
    new_desc = horzcat(tmpdesc,' ',tmpacc3);

    % copy file to blinding destination
    newf = horzcat(newdir,'\',tmpacc3);

    if(~exist(newf))
        copyfile(tmpf,newf,'f');
    else
        disp('Filename already exists!');
        disp(newf);
    end

    % save metadata
    tmpseries{fx,7} =  tmpacc1;
    tmpseries{fx,8} =  tmpacc2;
    tmpseries{fx,9} =  tmpacc3;
    tmpseries{fx,10} = newstudyuid;
    tmpseries{fx,11} = newf;

    % generate blinding info
    % blind XR with blinding info
    tagcell = {...
    '(0010,0010)',horzcat(tmpname,'^^^^'),'i';...
    '(0010,0020)',tmpid,'i';...
    '(0008,0050)',tmpacc2,'i';...
    '(0020,0011)',zerofillstr(fx,2),'i';...
    '(0008,1030)',tmpacc2,'i';...
    '(0008,103E)',new_desc,'i';...
    '(0020,000D)',newstudyuid,'i';...
    '(0020,0010)',tmpacc3,'i';...
    '(0008,0018)',tmpinfo.SOPInstanceUID,'i';...
    '','','imt';...
    };

    % Anonymize MOST X-ray files
    [exit_code]=MOST_XR_Anonymize(newf,tagcell);
    tmpseries{fx,12} = exit_code;

  end %fx

  tmpstudy_out = [tmpstudy_out; tmpseries];

end %loop_series
