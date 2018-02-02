function [uab_flnet,uab_stitchnet,uab_deepnet,uab_cropnet,ui_deepnet,ui_cropnet]=Load_NeuralNetworks_MOST_XR()

%% this function loads the saved neural networks for MOST XR_files_

%% define static folders/files
flnet_f =     'S:\FelixTemp\XR\MOST_FL_XR_patternnet_20170207.mat';
stitchnet_f = 'S:\FelixTemp\XR\MOST_Stitching_XR_patternnet_20170207.mat';
deepnet_f =   'S:\FelixTemp\XR\MOST_XR_deepnet_20170208.mat';
cropnet_f =   'S:\FelixTemp\XR\MOST_XR_cropnet_20170208.mat';

ui_deepnet_f = 'S:\FelixTemp\XR\MOST_UI_FL_XR_deepnet_20170601.mat';
ui_cropnet_f = 'S:\FelixTemp\XR\MOST_UI_CropFL_XR_deepnet_20170601.mat';

%% load the neural network files

% UAB neural networks
load(flnet_f);
uab_flnet = pnet;
clear pnet;

load(stitchnet_f);
uab_stitchnet = pnet;
clear pnet;

load(deepnet_f);
uab_deepnet = deepnet;
clear deepnet

load(cropnet_f);
uab_cropnet = cropnet;
clear cropnet

% UI neural networks
load(ui_deepnet_f);
ui_deepnet = deepnet;
clear deepnet

load(ui_cropnet_f);
ui_cropnet = deepnet;
clear deepnet
