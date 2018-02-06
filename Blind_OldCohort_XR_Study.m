function [tmpstudy_out]=Blind_OldCohort_XR_Study(dcmdir_out,tmpid,tmpstudy,accnum_qc)

%% initialize
tmpstudy_out = {};
dpvr_file = 'KXRdata.mat';
load(dpvr_file);

% get patient name
tmpname = tmpstudy{1,4};

% organize series types
loop_series = unique(tmpstudy(:,6));
% remove unstitched full limb images
loop_series(indcfind(loop_series(:,1),'^Unstitched','regexpi'),:) = [];
% collect unknown image types
unknown_series =  indcfind(tmpstudy(:,6),'Unknown','regexpi');
empty_series =    indcfind(tmpstudy(:,6),'','empty');

if(size(loop_series,1)>0)

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
    if(strcmpi(this_se,'PA'))
      tmpseries = [tmpseries; tmpseries(unknown_series,:); tmpseries(empty_series,:)];
    end %add unknowns

    % look up series number for this XR type
    switch this_se
      case 'PA'
        tmpse=1;
        prev_str = 'Bilateral PA Fixed Flexion';
      case 'PA05'
        tmpse=3;
        prev_str = 'Bilateral PA Fixed Flexion';
      case 'PA10'
        tmpse=1;
        prev_str = 'Bilateral PA Fixed Flexion';
      case 'PA15'
        tmpse=2;
        prev_str = 'Bilateral PA Fixed Flexion';
      case 'LLAT'
        tmpse=4;
        prev_str = 'Left Lateral Knee';
      case 'RLAT'
        tmpse=5;
        prev_str = 'Right Lateral Knee';
      case 'Full Limb'
        tmpse=6;
        prev_str = '^Full Limb$'
      case 'Unstitched Pelvis'
        tmpse=62;
        prev_str = '^$'
      case 'Unstitched Knee'
        tmpse=63;
        prev_str = '^$'
      case 'Unstitched Ankle'
        tmpse=64;
        prev_str = '^$'
      otherwise
        tmpse=7;
        prev_str = '^$'
    end

    % generate series qc barcode
    tmpacc2 = horzcat(tmpacc1,num2str(tmpse));

    % generate output directory for this series
    newdir =  horzcat(dcmdir_out,'\',tmpid,'_',tmpname,'\',tmpacc2);
    if(~exist(newdir,'dir'))
      mkdir(newdir);
    end

    %% Add XR images from previous MOST visits
    px = indcfind(KXRdata(:,2),tmpid,'regexpi');
    prev_visit = {'84M','60M','30M','15M','BL'};
    for pvx = 1:size(prev_visit,2)
      add_x = intersect(px,indcfind(KXRdata(:,6),horzcat(prev_visits{1,pvx},'.*',prev_str),'regexpi'));
      if(~isempty(add_x))
        pv_add = cell(size(add_x,1),6);
        pv_add(:,1) = KXRdata(add_x,1);
        pv_add(:,6) = KXRdata(add_x,6);
        tmpseries = [tmpseries; pv_add];
      end
    end

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

      if(~exist(newf,'file'))
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

    dellist = filetroll(newdir,'*','.bak',0,1);
    for dx=1:size(dellist,1)
        delete(dellist{dx,1});
    end

    tmpstudy_out = [tmpstudy_out; tmpseries];

  end %loop_series

end
