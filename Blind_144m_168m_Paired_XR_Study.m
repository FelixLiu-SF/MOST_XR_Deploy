function [tmpstudy_144m_reblinded, tmpstudy_168m_reblinded]=Blind_144m_168m_Paired_XR_Study(dcmdir_out,tmpid,tmpstudy,f_unprocessed,x_best,f_best,x_category,f_category)

%% 168 MONTH PA VIEWS NOT BEING PROPERLY LABELLED

%% initialize
tmpstudy_144m_reblinded = {};
tmpstudy_168m_reblinded = {};
dpvr_file = 'KXRdata.mat';
load(dpvr_file);

f_filename = indcfind(f_unprocessed,'^filename$','regexpi');
f_SOPInstanceUID = indcfind(f_unprocessed,'^SOPInstanceUID$','regexpi');
f_PatientID = indcfind(f_unprocessed,'^PatientID$','regexpi');
f_PatientName = indcfind(f_unprocessed,'^PatientName$','regexpi');
f_StudyDate = indcfind(f_unprocessed,'^StudyDate$','regexpi');
f_StudyBarcode = indcfind(f_unprocessed,'^StudyBarcode$','regexpi');
f_SeriesBarcode = indcfind(f_unprocessed,'^SeriesBarcode$','regexpi');
f_FileBarcode = indcfind(f_unprocessed,'^FileBarcode$','regexpi');
f_View = indcfind(f_unprocessed,'^View$','regexpi');
f_StudyBarcode = indcfind(f_unprocessed,'^StudyBarcode$','regexpi');

% get patient name
tmpid =         tmpstudy{1,f_PatientID};
tmpname =       tmpstudy{1,f_PatientName};
tmpdate =       tmpstudy{1,f_StudyDate};
tmpbarcode =    tmpstudy{1,f_StudyBarcode};

% get 144m XRs
tmp_best =      x_best(indcfind(x_best(:,indcfind(f_best,'^mostid$','regexpi')),tmpid,'regexpi'),:);
tmp_category =  x_category(indcfind(x_category(:,indcfind(f_category,'^PatientID$','regexpi')),tmpid,'regexpi'),:);

% organize series types
loop_series = {};
if(~isempty(indcfind(tmpstudy(:,f_View),'^PA','regexpi')))
    loop_series = [loop_series; 'PA'];
end
if(~isempty(indcfind(tmpstudy(:,f_View),'^LLAT','regexpi')))
    loop_series = [loop_series; 'LLAT'];
end
if(~isempty(indcfind(tmpstudy(:,f_View),'^RLAT','regexpi')))
    loop_series = [loop_series; 'RLAT'];
end

if(size(loop_series,1)>0)

  % get existing barcode
  tmpacc1 = tmpbarcode;

  for jx_se = 1:size(loop_series,1) %loop through each XR view type in exam

      
    % collect all files for this XR view type
    this_se = loop_series{jx_se,1};
    all_se = indcfind(tmpstudy(:,f_View),horzcat('^',this_se),'regexpi');
    
    % collect files for reblinding under this XR type
    tmpseries = tmpstudy(all_se,:);
      
    % get existing study UIDs
    tmpf = tmpseries{1,f_filename};
    tmpinfo = dicominfo(tmpf);
    newstudyuid = tmpinfo.StudyInstanceUID;

    % get existing series barcode
    tmpacc2 = tmpseries{1,f_SeriesBarcode};
    
    % generate output directory for this series
    newdir =  horzcat(dcmdir_out,'\',tmpid,'_',tmpname,'\',tmpacc2);
    if(~exist(newdir,'dir'))
      mkdir(newdir);
    end
    
    % categorize if unknown PA beam angles
    if(strcmpi(this_se,'PA'))
      [tmpseries_PA] = Relabel_XR_PA_Views_Deploy(tmpseries(:,1:6));
      for ax=1:size(tmpseries_PA,1)
          
          tmp_PA_SOP = tmpseries_PA{ax,f_SOPInstanceUID};
          tmp_PA_view = tmpseries_PA{ax,f_View};
          
          bx = indcfind(tmpseries(:,f_SOPInstanceUID),tmp_PA_SOP,'regexpi');
          tmpseries{bx(1),f_View} = tmp_PA_view;
          
      end
      
    end %beam angle
    
    
    %% blind XR images
    for fx=1:size(tmpseries,1)

      % get metadata for file
      tmpf = tmpseries{fx,f_filename};
      tmpacc3 = tmpseries{fx,f_FileBarcode};
      tmpdesc = tmpseries{fx,f_View};
      tmpSOP = tmpseries{fx,f_SOPInstanceUID};
      
      % copy file to blinding destination
      newf = horzcat(newdir,'\',tmpacc3);

      if(~exist(newf,'file'))
          copyfile(tmpf,newf,'f');
      else
          disp('Filename already exists!');
          disp(newf);
      end
      
      % reblind series description
      
      new_desc = horzcat(tmpdesc,' ',tmpacc3);
      
      tagcell = {...
      '(0008,103E)',new_desc,'i';...
      '(0008,0018)',tmpSOP,'i';...
      '','','imt';...
      };
  
      [exit_code]=MOST_XR_Anonymize(newf,tagcell);

      % save new metadata
      tmpseries{fx,f_filename} = newf; 
      tmpstudy_168m_reblinded = [tmpstudy_168m_reblinded; tmpseries];

    end %fx    

    % look up series number for this XR type
    switch this_se
      case 'PA'
        tmpse=1;
        prev_str = 'PAxx';
      case 'PA05'
        tmpse=3;
        prev_str = 'PAxx';
      case 'PA10'
        tmpse=1;
        prev_str = 'PAxx';
      case 'PA15'
        tmpse=2;
        prev_str = 'PAxx';
      case 'LLAT'
        tmpse=4;
        prev_str = 'LLAT';
      case 'RLAT'
        tmpse=5;
        prev_str = 'RLAT';
      case 'Full Limb'
      
    end


    %% Add XR images from 144m MOST visit
    fx = fx+1;
    px = indcfind(tmp_best(:,indcfind(f_best,'^view$','regexpi')),prev_str,'regexpi');
    prev_SOP = tmp_best{px(1),indcfind(f_best,'SOPINSTANCEUID','regexpi')};
    prev_acc3 = tmp_best{px(1),indcfind(f_best,'barcode','regexpi')};
    prev_desc = tmp_best{px(1),indcfind(f_best,'imagetype','regexpi')};
    prev_date = tmp_best{px(1),indcfind(f_best,'xrdate','regexpi')};
    
    prev_desc2 = horzcat(prev_desc,' ',prev_acc3);
    
    rx = indcfind(tmp_category(:,indcfind(f_category,'^SOPInstanceUID$','regexpi')),strrep(prev_SOP,'.','\.'),'regexpi');
    tmpf = tmp_category{rx(1),indcfind(f_category,'^filename$','regexpi')};
    
    % copy file to blinding destination
    newf = horzcat(newdir,'\',prev_acc3);

    if(~exist(newf,'file'))
      copyfile(tmpf,newf,'f');
    else
      disp('Filename already exists!');
      disp(newf);
    end
    
    % blind XR with blinding info
      tagcell = {...
      '(0010,0010)',horzcat(tmpname,'^^^^'),'i';...
      '(0010,0020)',tmpid,'i';...
      '(0008,0050)',tmpacc2,'i';...
      '(0020,0011)',zerofillstr(fx,2),'i';...
      '(0008,1030)',tmpacc2,'i';...
      '(0008,103E)',prev_desc2,'i';...
      '(0020,000D)',newstudyuid,'i';...
      '(0020,0010)',prev_acc3,'i';...
      '(0008,0018)',prev_SOP,'i';...
      '','','imt';...
      };

    % Anonymize MOST X-ray files
    [exit_code]=MOST_XR_Anonymize(newf,tagcell);
    
    
    % save metadata
    tmp144series = {};
    tmp144series = {...
        newf;...
        prev_SOP;...
        tmpid;...
        tmpname;...
        prev_date;...
        prev_desc;...
        tmpacc1;...
        tmpacc2;...
        prev_acc3;...
        exit_code;...
        5;
    };




    dellist = filetroll(newdir,'*','.bak',0,1);
    for dx=1:size(dellist,1)
        delete(dellist{dx,1});
    end

    tmpstudy_144m_reblinded = [tmpstudy_144m_reblinded; tmp144series'];

  end %loop_series

end
