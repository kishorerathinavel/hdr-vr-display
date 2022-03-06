close all;
clear all;
clc;

%% Initializing some variables
% Variables names for the rest of the code are along the lines of Fig. 9 in hdr2004 paper

hdr = im2double(hdrread('..\..\..\Data\hdrData\memorial.hdr'));
LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

LEDrows = 29;
LEDcols = ceil(LEDrows * LCDaspect);

K = round(LCDrows/LEDrows);

maxEyeMovement = 5;
eyeMovementVec = generateRandomEyeMovementVector(maxEyeMovement);
% eyeMovementVec is the movement of pixels on the retina due to a linear
% gaze change of the eye. The movement is assumed in this code as number of
% retinal pixels per PWM bit frame

%%
d = LCDcols/tan(deg2rad(25));


%% Creating the glare simulated image of the HDR image

glareFS = generateGlareFunction(4, 0.01, 10, d, false);
figure;
imshow(glareFS);

figure;
imshow(glareFS/mean(glareFS(:)));

figure;
cool(3);
h = surf(log(glareFS));
% h = surf(glare);
set(h, 'LineStyle', 'none');

%%
figure;
imshow(tonemapGamma(hdr));

perceivedHDR = imfilter(hdr, glareFS);

range(hdr(:))
range(perceivedHDR(:))

perceivedHDR = sum(hdr(:))*(perceivedHDR/sum(perceivedHDR(:)));
figure;
imshow(tonemapGamma(perceivedHDR));


