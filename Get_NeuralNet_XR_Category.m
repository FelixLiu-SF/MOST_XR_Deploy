function [view_output]=Get_NeuralNet_XR_Category(tmpid,tmpratio,edge_nn,adj_img,adjc_img)

%% function for categorizing XR image using neural network inputs

%% work-in-progress

% initialize output_list
view_output = '';

% check ID for clinical site
if(strcmpi(tmpid(1:2),'MB'))

  % UAB
  if(tmpratio>2.5)

    % aspect ratio matches full-limb image
    stitch_results = uab_stitchnet(edge_nn(:)); %edge image into stitching NN

    [~,stitch_max]=max(stitch_results); %check NN results is 4 for FL
    if(abs(stitch_max-4)<eps)
        view_output = 'Full Limb';
    else
        view_output = 'Unknown';
    end

  else
  end %image ratio

elseif(strcmpi(tmpid(1:2),'MI'))

  % UI

end %clinical site

%% this is a temporary starting point
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
