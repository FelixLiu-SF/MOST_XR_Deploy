function [view_output]=Get_NeuralNet_XR_Category(tmpid,tmpratio,edge_nn,adj_img,adjc_img)

%% function for categorizing XR image using neural network inputs

%% work-in-progress

%% initialize output_list
view_output = '';

% check ID for clinical site
if(strcmpi(tmpid(1:2),'MB'))

  %% UAB
  if(tmpratio>2.5)

    % aspect ratio matches full-limb image
    stitch_results = most_xr_uab_stitchnet_20180202(edge_nn(:)); %edge image into stitching NN

    [~,stitch_max]=max(stitch_results); %check NN results is 4 for FL
    if(abs(stitch_max-4)<eps)
        view_output = 'Full Limb';
    else
        view_output = 'Unknown';
    end

  else

    % aspect ratio doesn't match full-limb image

    fl_results = most_xr_uab_flnet_20180202(edge_nn(:)); %edge image into full limb NN

    [~,fl_max]=max(fl_results); %check if NN results for unstitched FL image
    if(abs(fl_max-1)<eps)

        %image is probably an unstitched full limb image

        stitch_results = most_xr_uab_stitchnet_20180202(edge_nn(:)); %check what kind of unstitched image
        [~,stitch_max]=max(stitch_results);

        % categorize unstitched full limb XR image
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

    else % image is probably not unstitched full limb image

        %full image neural net
        nn_results = most_xr_uab_deepnet_20180202(adj_img(:));
        [nno_maxval,nno_max]=max(nn_results);

        %cropped image neural net
        nnc_results = most_xr_uab_cropnet_20180202(adjc_img(:));
        [nnc_maxval,nnc_max]=max(nnc_results);

        % compare cropped score vs original score, use the best score
        if(max(nno_maxval)>max(nnc_maxval))
            nn_max = nno_max;
        else
            nn_max = nnc_max;
        end

        % categorize core XR image
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

    end

  end %image ratio

elseif(strcmpi(tmpid(1:2),'MI'))

  %% UI

  %full image neural net
  nn_results = most_xr_ui_deepnet_20180202(adj_img(:));
  [nno_maxval,nno_max]=max(nn_results);

  %cropped image neural net
  nnc_results = most_xr_ui_cropnet_20180202(adjc_img(:));
  [nnc_maxval,nnc_max]=max(nnc_results);

  % compare cropped score vs original score, use the best score
  if(max(nno_maxval)>max(nnc_maxval))
      nn_max = nno_max;
  else
      nn_max = nnc_max;
  end

  % categorize XR image, very robust NN for UI
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

end %clinical site
