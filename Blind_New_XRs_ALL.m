%% function for blinding and processing DICOM XRs

%% turn off warnings
warning('off','images:dicominfo:fileVRDoesNotMatchDictionary');
warning('off','Images:initSize:adjustingMag');
warning('off','images:dicominfo:unhandledCharacterSet');

%% initialize
savef = horzcat('MOST_XR_BLIND_',datestr(now,'yyyymmddHHMMSS'),'.mat');

%% set up directories

%database
mdbf = 'S:\FelixTemp\XR\MOST_XR_144M_Master.accdb'

%output dir
dcmdir_out = 'E:\most-dicom\XR_QC\144m';

%% grab data from database

% accession numbers
[x_acc,f_acc] = MDBQuery(mdbf,'SELECT * FROM tblAccNum');
accnum_qc = x_acc{1,indcfind(f_acc,'^QC$','regexpi')};
accnum_sc = x_acc{1,indcfind(f_acc,'^Screening$','regexpi')};

% all files and categories
[x_category,f_category] = MDBquery(mdbf,'SELECT * FROM tblFilesCategory');

% all processed files
[x_qc,f_qc] = MDBquery(mdbf,'SELECT * FROM tblDICOMQC');
[x_fl,f_fl] = MDBquery(mdbf,'SELECT * FROM tblDICOMFullLimb');
[x_screening,f_screening] = MDBquery(mdbf,'SELECT * FROM tblDICOMScreening');

%% filter out processed files by SOP
SOP_processed = [x_qc(:,indcfind(f_qc,'^SOPInstanceUID$','regexpi')); x_fl(:,indcfind(f_fl,'^SOPInstanceUID$','regexpi')); x_screening(:,indcfind(f_screening,'^SOPInstanceUID$','regexpi'))];
x_unprocessed = x_category(~ismember(x_category(:,indcfind(f_category,'^SOPInstanceUID$','regexpi')),SOP_processed),:);

%% process and blind all new XRs
if(size(x_unprocessed,1)>0)

  unq_ids = unique(x_unprocessed(:,3));

  for ix=1:size(unq_ids,1) % loop through each ID

    tmpid = unq_ids{ix,1};

    % get a single XR exam by ID and date
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,3),tmpid,'regexpi'),:);
    tmpstudydate = tmpstudy{1,4};
    tmpstudy = x_unprocessed(indcfind(x_unprocessed(:,4),tmpstudydate,'regexpi'),:);
    tmpstudy = sortrows(tmpstudy,[6,4,2,1]);

    % get patient name
    tmpname = tmpstudy{1,5};

    %% check cohort by ID
    chk_oldcohort = indcfind(tmpid,'(MB0[0-2][0-9]{3}|MI5[0-2][0-9]{3})','regexpi');
    chk_newcohort = indcfind(tmpid,'(MB0[3-9][0-9]{3}|MI5[3-9][0-9]{3})','regexpi');

    % organize series types
    loop_series = unique(tmpstudy(:,6));
    unknown_series =  indcfind(tmpstudy(:,6),'Unknown','regexpi');
    empty_series =    indcfind(tmpstudy(:,6),'','empty');

    %% switch blinding by cohort
    if(~isempty(chk_oldcohort) && isempty(chk_newcohort))
      %% OLD cohort participant, do not screen

      % generate barcodes & UIDs
      newstudyuid = dicomuid;
      accnum_qc = accnum_qc+1;
      tmpacc1 = zerofillstr(accnum_qc,4);
      tmpacc1 = horzcat('6',tmpacc1);

      for jx_se = 1:size(loop_series,1) %loop through each XR view type in exam

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

          % decompress JPEG
          [status,result] = dcmdjpeg(newf,newf);
          if(status~=0)
            disp('decompression error!');
            disp(result);
            disp(newf);
          end

          % anonymize blinding file
          try
          dicomanon(newf,newf,'keep',{'PatientID','PatientName','AccessionNumber','SeriesNumber','StudyDescription','SeriesDescription','StudyID','StudyInstanceUID','SeriesInstanceUID','SOPInstanceUID'});
          catch anonerr
              disp(anonerr);
              err_img = dicomread(tmpf);
              dicomwrite(err_img,newf);
          end

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

          [status,result] = dcmbatchmod(newf,tagcell);
          try
              [status,result] = FixXR(newf,tmpinfo);
          catch
              try
                  pause(15);
                  [status,result] = FixXR(newf,tmpinfo);
              catch
                  status = -1;
              end
          end
          if(status(1)~=0)
              disp('photometric error!');
              disp(newf);
          end

          % re-compress JPEG
          [status,result] = dcmcjpeg(newf,newf);
          if(status~=0)
            disp('compression error!');
            disp(result);
            disp(newf);
          end

        end %fx

      end %loop_series


    elseif(isempty(chk_oldcohort) && ~isempty(chk_newcohort))
      %% NEW cohort participant, also blind for screening


    end %blinding by cohort

  end %ix

  %% save accession number counters

  %% save .mat file
  save(savef);

end %size>0
