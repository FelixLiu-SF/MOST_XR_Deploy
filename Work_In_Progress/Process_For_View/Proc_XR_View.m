try

%% initialize
addpath('E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code');
datedir_in = datestr(now,'yyyymmdd');
BAchoice = [5,10,15];

%% define static folders/files
incoming_dir_uab = 'E:\MOST-Renewal-II\XR\UAB';
incoming_dir_ui = 'E:\MOST-Renewal-II\XR\UI';
process_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_process_view.csv';
exclude_logfile = 'E:\MOST-Renewal-II\XR\BLINDING\MOST_XR_blinding_excluded.csv';
masterf = 'E:\MOST-Renewal-II\XR\Database_Copy\MOST_XR_144M_Master.accdb';

flnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_FL_XR_patternnet_20170207.mat';
stitchnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_Stitching_XR_patternnet_20170207.mat';
deepnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_XR_deepnet_20170208.mat';
cropnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_XR_cropnet_20170208.mat';

ui_deepnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_UI_FL_XR_deepnet_20170601.mat';
ui_cropnet_f = 'E:\MOST-Renewal-II\XR\BLINDING\MATLAB\Common_code\MOST_UI_CropFL_XR_deepnet_20170601.mat';

load(flnet_f); 
flnet = pnet;
clear pnet;

load(stitchnet_f); 
stitchnet = pnet;
clear pnet;

load(ui_deepnet_f);
ui_deepnet = deepnet;
clear deepnet

load(ui_cropnet_f);
ui_cropnet = deepnet;
clear deepnet

load(deepnet_f); 
% deepnet = deepnet;

load(cropnet_f);
% cropnet = cropnet;

% get db list
[xa,fa]=MDBquery(masterf,'SELECT * FROM tblAccessionQC');

% get list of all files in XR folder
uab_filelist = filetroll(incoming_dir_uab,'*','.*',0,0);
ui_filelist = filetroll(incoming_dir_ui,'*','.*',0,0);
dicom_xr_list = [uab_filelist; ui_filelist];


%% read spreadsheet log of blinded XR files
[~,~,csv_processed] = xlsread(process_logfile);
csv_processed(:,4) = cellfun(@num2str,csv_processed(:,4),'UniformOutput',0); %change format of studydates
csv_processed(2:end,3) = regimatch(csv_processed(2:end,3),'(M|X)(B|I).{5}');

% filter out XRs that were previously blinded
dicom_xr_list = dicom_xr_list(~ismember(dicom_xr_list(:,1),csv_processed(:,1)),:);


% read spreadsheet log from exclusion spreadsheet
[~,~,csv_excluded] = xlsread(exclude_logfile);
csv_excluded(:,4) = cellfun(@num2str,csv_excluded(:,4),'UniformOutput',0); %change format of studydates

% filter out XRs that were previously blinded
dicom_xr_list = dicom_xr_list(~ismember(dicom_xr_list(:,1),csv_excluded(:,1)),:);

% exclude 'test' or 'phantom' files
dicom_xr_list(indcfind(dicom_xr_list(:,1),'(test|phantom)','regexpi'),:) = [];

% filter for only DICOM file formats
dicom_xr_list = dicom_xr_list(cellfun(@isdicom,dicom_xr_list(:,1)),:);



%% get metadata on unblinded XRs
dicom_list = {};
for ix=1:size(dicom_xr_list,1)
    
    tmpf = dicom_xr_list{ix,1};
    tmpinfo = dicominfo(tmpf);
    
    tmpSOP = tmpinfo.SOPInstanceUID;
    tmpID = tmpinfo.PatientID;
    tmpDate = tmpinfo.StudyDate;
    
    dicom_list = [dicom_list; {tmpf, tmpSOP, tmpID, tmpDate}];
    
end

% filter out O's vs 0's
dicom_list(:,3) = cellfun(@upper,dicom_list(:,3),'UniformOutput',0);
dicom_list(:,3) = cellfun(@strrep,dicom_list(:,3),repcell(size(dicom_list(:,3)),'O'),repcell(size(dicom_list(:,3)),'0'),'UniformOutput',0);

% filter for MOST IDs
mostid_x = indcfind(dicom_list(:,3),'(MB|MI)[0-9]{5}','regexpi');

dicom_list = dicom_list(mostid_x,:);
dicom_list = sortrows(dicom_list,4); %sort by studydate

% filter out SOPInstanceUIDs already accounted for
dicom_list = dicom_list(~ismember(dicom_list(:,2),xa(:,indcfind(fa','^SOPINSTANCEUID$','regexpi'))),:);

if(size(dicom_list,1)>0)

    for ix=1:size(dicom_list,1)

        view_output = '';

        tmpf = dicom_list{ix,1};
        tmpimg = dicomread(tmpf);
        tmpid = dicom_list{ix,3};

        % image aspect ratio
        tmpratio = size(tmpimg,1)/size(tmpimg,2);
        
        %% MB
        if(strcmpi(tmpid(1:2),'MB'))
        
            if(tmpratio>2.5)

                % aspect ratio matches full-limb image
                edge_nn = stitch2nn(tmpimg);
                stitch_results = stitchnet(edge_nn(:));
                [~,stitch_max]=max(stitch_results);
                if(abs(stitch_max-4)<eps)
                    view_output = 'Full Limb';
                else
                    view_output = 'Unknown';
                end
                dicom_list{ix,6} = stitch_results;

            else
                % aspect ratio doesn't match full-limb image
                edge_nn = stitch2nn(tmpimg);
                fl_results = flnet(edge_nn(:));
                [~,fl_max]=max(fl_results);
                if(abs(fl_max-1)<eps)
                    stitch_results = stitchnet(edge_nn(:));
                    [~,stitch_max]=max(stitch_results);
                    switch stitch_max
                        case 1
                            view_output = 'Unstitched Pelvis';
                        case 2
                            view_output = 'Unstitched Knee';
                        case 3
                            view_output = 'Unstitched Ankle';
                        case 4
                            view_output = 'Unknown';
                        otherwise
                            view_output = 'Unknown';
                    end
                    dicom_list{ix,6} = stitch_results;
                else

                    %full image neural net 
                    nn_img = imresize(tmpimg,[50,50]); 
                    nnn_img = 1 - double(nn_img)/max(max(double(nn_img))); 
                    adj_img = imadjust(nnn_img,stretchlim(nnn_img,[0.33,1.0]));
                    nn_results = deepnet(adj_img(:));
                    [nno_maxval,nno_max]=max(nn_results);

                    %cropped image neural net
                    croplim = round([size(tmpimg)/6,size(tmpimg)-(size(tmpimg)/6)]);
                    cropimg = tmpimg(croplim(1,1):croplim(1,3),croplim(1,2):croplim(1,4));
                    nnc_img = imresize(cropimg,[50,50]); 
                    nnnc_img = 1 - double(nnc_img)/max(max(double(nnc_img))); 
                    adjc_img = imadjust(nnnc_img,stretchlim(nnnc_img,[0.33,1.0]));
                    nnc_results = cropnet(adjc_img(:));
                    [nnc_maxval,nnc_max]=max(nnc_results);

                    % compare cropped score vs original score
                    if(max(nno_maxval)>max(nnc_maxval))
                        nn_max = nno_max;
                    else
                        nn_max = nnc_max;
                    end

                    switch nn_max
                        case 1
                            view_output = 'PA';
                        case 2
                            view_output = 'LLAT';
                        case 3
                            view_output = 'RLAT';
                        otherwise
                            view_output = 'Unknown';
                    end

                    dicom_list{ix,7} = nn_results;
                    dicom_list{ix,8} = nnc_results;

                end
            end
            
        else
        %% MI
            %full image neural net 
            nn_img = imresize(tmpimg,[50,50]); 
            nnn_img = 1 - double(nn_img)/max(max(double(nn_img))); 
            adj_img = imadjust(nnn_img,stretchlim(nnn_img,[0.33,1.0]));
            nn_results = ui_deepnet(adj_img(:));
            [nno_maxval,nno_max]=max(nn_results);

            %cropped image neural net
            croplim = round([size(tmpimg)/6,size(tmpimg)-(size(tmpimg)/6)]);
            cropimg = tmpimg(croplim(1,1):croplim(1,3),croplim(1,2):croplim(1,4));
            nnc_img = imresize(cropimg,[50,50]); 
            nnnc_img = 1 - double(nnc_img)/max(max(double(nnc_img))); 
            adjc_img = imadjust(nnnc_img,stretchlim(nnnc_img,[0.33,1.0]));
            nnc_results = ui_cropnet(adjc_img(:));
            [nnc_maxval,nnc_max]=max(nnc_results);
            
            % compare cropped score vs original score
            if(max(nno_maxval)>max(nnc_maxval))
                nn_max = nno_max;
            else
                nn_max = nnc_max;
            end
            
            switch nn_max
                case 1
                    view_output = 'PA';
                case 2
                    view_output = 'LLAT';
                case 3
                    view_output = 'RLAT';
                case 4
                    view_output = 'Full Limb';
                case 5
                    view_output = 'Unstitched Pelvis';
                case 6
                    view_output = 'Unstitched Knee';
                case 7
                    view_output = 'Unstitched Ankle';
                otherwise
                    view_output = 'Unknown';
            end

            dicom_list{ix,7} = nn_results;
            dicom_list{ix,8} = nnc_results;
        
        end

        dicom_list{ix,5} = view_output;

        clear tmpf tmpimg tmpratio
    end
    
    jx = indcfind(dicom_list(:,5),'PA','regexpi');
    if(~isempty(jx))
        for kx=1:size(jx,1)
            
            new_desc = '';
            ix=jx(kx);
            filename = dicom_list{ix,1};
            
            try
                [~,aR,aL,aC,npairs,~,~,~,~,~,~,~,~,~,~,~,~,~,~,~]=CalcBeamAngle2016(filename);
            catch beamangle_err
                aC = [];
                aL = [];
                aR = [];
            end
            if(isempty(aC) && (~isempty(aR) || ~isempty(aL)))
                aC = unique([aR;aL]);
            elseif(isempty(aC))
                aC = 10;
            end
            [~,bx] = min(abs(BAchoice - abs(aC)));
            trueBA = BAchoice(1,bx);
            
            new_desc = horzcat('PA',zerofillstr(trueBA,2));
            dicom_list{ix,5} = new_desc;
        end
    end
    

    output_list = dicom_list(:,1:5);

    dlmtxtwrite([{'filename','SOPInstanceUID','PatientID','StudyDate','SeriesDesc'}; output_list], horzcat('MOST_XR_Views_',datedir_in,'.txt'), ',', 'cell', '', 1);
    dlmtxtappend(output_list,process_logfile,',','cell','');

    save(horzcat('MOST_XR_Views_',datedir_in,'.mat'),'dicom_list','output_list');
    
else
    
    save(horzcat('MOST_XR_Views_',datedir_in,'.mat'),'dicom_list');

end


catch view_err
    disp('Error encountered.');
    disp(view_err.message)
    exit;

end
disp('Process finished.');
exit;
