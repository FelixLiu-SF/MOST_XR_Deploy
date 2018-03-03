function [knee_top, knee_bot, knee_right, knee_left] = KneeXRSections(imgsize,rectcorner,rectsize,finbeadR,finbeadL)


% calculate middle 2/3 of XR height
h6 = imgsize(1)/6;
h6_top = round(h6);
h6_bot =round(5*h6);

truebeadR = [finbeadR(:,1)+rectcorner(2),finbeadR(:,2)+rectcorner(1)];
truebeadL = [finbeadL(:,1)+rectcorner(2),finbeadL(:,2)+rectcorner(1)];

SynRK = min(truebeadR(:,1));
SynLK = max(truebeadL(:,1));
SynTop = min([truebeadR(:,2);truebeadL(:,2)]);
SynBot = max([truebeadR(:,2);truebeadL(:,2)]);

SynWidth = round(abs(SynLK - SynRK));

knee_top = round(min([h6_top; SynTop]));
knee_bot = round(max([h6_bot; SynBot]));

knee_right = round([SynWidth, (SynRK-SynWidth)]);
knee_left = round([(SynLK+SynWidth),(imgsize(2)-SynWidth)]);