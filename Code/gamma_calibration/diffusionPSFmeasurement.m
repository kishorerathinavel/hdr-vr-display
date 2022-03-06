close all;
clear all;
clc;

%% Finding spatial mu and sigma of diffusion kernel
singleLED150 = im2double(rgb2gray(imread('calibrationData/diffusionKernel/singleLED150.tif')));
% figure;
% surf(singleLED150);
% Kernel = fspecial('gaussian', 10, 2);
% singleLED150 = imfilter(singleLED150, Kernel);
% figure;
% surf(singleLED150);

squareSize = 300;
squareLocation = [500 925];

sR = round(squareLocation(1) - squareSize/2);
eR = round(squareLocation(1) + squareSize/2);
sC = round(squareLocation(2) - squareSize/2);
eC = round(squareLocation(2) + squareSize/2);

addImg = zeros(size(singleLED150));
addImg(sR:eR, sC:eC) = 100;
addImg = uint8(addImg);
% imshow(singleLED150 + addImg);

cropImg = singleLED150(sR:eR,sC:eC);
% imshow(cropImg);

%%
xdata = 1:size(cropImg,1);
ydata = 1:size(cropImg,2);

[mux muy sigmax sigmay] = findSpatialMuSigma(cropImg, 0);

% Hard-coding correction factors for each of the sigmas. I don't understand
% why this has to be done but works.
factorx = 1.7;
factory = 1.7;
newsigmax = sigmax*factorx;
newsigmay = sigmay*factory;

% peakX = (mean(sum(cropImg, 1)));
% peakY = (mean(sum(cropImg, 2)));
Energy = 1.0*sum(cropImg(:));

constructedGaussianData = zeros(size(cropImg));
for xdata = 1:size(cropImg,1)
    for ydata = 1:size(cropImg,2)
        exponentx = -((xdata - mux)^2)/(2*(newsigmax^2));
        exponenty = - ((ydata - muy)^2)/(2*(newsigmay^2));
        multiplierx = 1/(2*(newsigmax^2)*pi)^0.5;
        multipliery = 1/(2*(newsigmay^2)*pi)^0.5;
        currVal = Energy*multiplierx*exp(1)^(exponentx) * multipliery*exp(1)^(exponenty);
        constructedGaussianData(xdata, ydata) = currVal;
    end
end

% constructedGaussianData = constructedGaussianData*1.5*(max(cropImg(:))/max(constructedGaussianData(:)));
% constructedGaussianData = constructedGaussianData + mean(cropImg(:))*ones(size(constructedGaussianData));

[mux2 muy2 sigmax2 sigmay2] = findSpatialMuSigma(constructedGaussianData, 0);

figure;
imshow(cropImg);

figure;
imshow(constructedGaussianData);

figure;
xdata = 1:size(cropImg,1);
ydata = 1:size(cropImg,2);
hot(3);
h = surf(constructedGaussianData);
cool(3);
hold on;
g = surf(cropImg);
set(h, 'LineStyle', 'none');
set(g, 'LineStyle', 'none');

figure;
h = surf(abs(cropImg - constructedGaussianData));
set(h, 'LineStyle', 'none');

figure;
plot(sum(cropImg, 1))
hold on;
plot(sum(constructedGaussianData, 1))
title('Plot comparison for along x-axis');

figure; 
plot(sum(cropImg, 2))
hold on;
plot(sum(constructedGaussianData, 2))
title('Plot comparison for along y-axis');