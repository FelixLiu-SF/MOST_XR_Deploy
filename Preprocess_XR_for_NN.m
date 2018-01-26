function [tmpratio,edge_nn,adj_img,adjc_img]=Preprocess_XR_for_NN(tmpf,tmpid)

%% Function for pre-processing x-ray images for neural net classification

%% read in DICOM image
tmpimg = dicomread(tmpf);

% image aspect ratio
tmpratio = size(tmpimg,1)/size(tmpimg,2);

%% preprocess images for neural net

%edge filter image
edge_nn = stitch2nn(tmpimg);

%full image neural net
nn_img = imresize(tmpimg,[50,50]);
nnn_img = 1 - double(nn_img)/max(max(double(nn_img)));
adj_img = imadjust(nnn_img,stretchlim(nnn_img,[0.33,1.0]));

%cropped image neural net
croplim = round([size(tmpimg)/6,size(tmpimg)-(size(tmpimg)/6)]);
cropimg = tmpimg(croplim(1,1):croplim(1,3),croplim(1,2):croplim(1,4));
nnc_img = imresize(cropimg,[50,50]);
nnnc_img = 1 - double(nnc_img)/max(max(double(nnc_img)));
adjc_img = imadjust(nnnc_img,stretchlim(nnnc_img,[0.33,1.0]));
