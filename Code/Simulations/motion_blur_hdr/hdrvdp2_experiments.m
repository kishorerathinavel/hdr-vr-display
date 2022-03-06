close all;
clear all;
clc;

%% inputting reference and test hdrs
hdr = im2double(hdrread('..\..\..\Data\hdrData\memorial.hdr'));
LCDrows = 800;
LCDcols = 480;
ref = padCrop(hdr, 800, 480); 

test1 = im2double(hdrread('simulationOutputs/oled_raster_perceivedImg.hdr'));
test2 = im2double(hdrread('simulationOutputs/pwm_rowInner_averagePerceived.hdr'));

%% using hdr vdp 2
ppd = hdrvdp_pix_per_deg(6, [480 800], 0.5);
res1 = hdrvdp(test1, hdr, 'rgb-bt.709', ppd, {'rgb_display', 'led-lcd'});
res2 = hdrvdp(test2, ref, 'rgb-bt.709', ppd, {'rgb_display', 'led-lcd'});

