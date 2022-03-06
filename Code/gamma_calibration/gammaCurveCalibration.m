close all;
clear all;
clc;

%% Read in all raw images
pathname = 'calibrationData/LCDgamma/withoutWhiteBalanceCorrection/bayer/';
lcdValue = round(0:(255/32):255);

for i = 1:33
    filename = sprintf('%s%d.tif', pathname, lcdValue(i));
    rawImg{i} = imread(filename);
end

%% Try demosaicing raw image using built-in function
for i = 1:33
    clrImg{i} = demosaic(rawImg{i}, 'rggb');
%     clrImg{i} = repmat(rawImg{i}, [1 1 3]);
end

% This is taken from the excel file. Note that the shutter speed values in
% the excel file are in the reverse order wrt lcdValue. 
% i.e. SSreversed(1) = lcdValue(33) = SS(33)
SSreversed = [100.046 100.046 100.046 100.046 199.926 199.926 199.926 299.971 299.971 299.971 299.971 399.852 399.852 399.852 500.063 500.063 500.063 500.063 500.063 500.063 599.943 699.823 699.823 799.703 799.703 996.818 996.818 996.818 996.818 996.818 996.818 996.818 996.818];
SS = fliplr(SSreversed);

%% ROI for doing gamma correction
rect = [500 900];
loc = round(size(rawImg{1})/2);
testImg = zeros(size(rawImg{30}));
sR = loc(1) - round(rect(1)/2);
eR = loc(1) + round(rect(1)/2);
sC = loc(2) - round(rect(2)/2);
eC = loc(2) + round(rect(2)/2);
testImg(sR:eR, sC:eC) = 0.1;
% imshow(im2double(rawImg{30}) + testImg);

%% Calculating SS-corrected rawImg
minSS = min(SS(:));
for i = 1:33
    SSCorrectedRawImg{i} = clrImg{i}/(SS(i)/minSS);
%     imshow(SSCorrectedRawImg{i});
%     str = sprintf('iter = %d', i);
%     title(str);
%     waitforbuttonpress;
end

%% Calculating average RGB in roi
avgRGB = [];
gammaRGBall = [];

for i = 1:33
    roi = SSCorrectedRawImg{i}(sR:eR, sC:eC, :);
    rCh = roi(:,:,1);
    gCh = roi(:,:,2);
    bCh = roi(:,:,3);
    meanR = mean(rCh(:));
    meanG = mean(gCh(:));
    meanB = mean(bCh(:));
    avgRGB = [avgRGB; meanR meanG meanB];
%     gammaRGBall = [gammaRGBall; [log(meanR) log(meanG) log(meanB)]/log(lcdValue(i))];
end
%% Normalizing avgRGB and lcdValues
minRGB = min(avgRGB);
maxRGB = range(avgRGB);
normalizedAvgRGB = zeros(size(avgRGB));
normalizedAvgRGB(:,1) = (avgRGB(:,1) - minRGB(1))/maxRGB(1);
normalizedAvgRGB(:,2) = (avgRGB(:,2) - minRGB(2))/maxRGB(2);
normalizedAvgRGB(:,3) = (avgRGB(:,3) - minRGB(3))/maxRGB(3);

normalizedLCDValues = (lcdValue - min(lcdValue))/range(lcdValue);
normalizedLCDValues = repmat(normalizedLCDValues', [1 3]);

%% calculating gamma values
gammaRGBall = log(normalizedAvgRGB)./log(normalizedLCDValues);

gammaRGB = mean(gammaRGBall(6:32,:), 1);
gammaEstimatedOutputs = [normalizedLCDValues(:,1).^gammaRGB(1) normalizedLCDValues(:,2).^gammaRGB(2) normalizedLCDValues(:,3).^gammaRGB(3)];
correctedValues = [normalizedLCDValues(:,1).^(1/gammaRGB(1)) normalizedLCDValues(:,2).^(1/gammaRGB(2)) normalizedLCDValues(:,3).^(1/gammaRGB(3))].^gammaRGBall;
% gammaEstimatedOutputs = lcdValuesRep.^gammaRGBall + 1;

figure;
plot(normalizedAvgRGB(:,1), 'r');
hold on;
plot(gammaEstimatedOutputs(:,1), 'black');
hold on;
plot(correctedValues(:,1), 'magenta');
title('red channel');

figure;
plot(normalizedAvgRGB(:,2), 'g');
hold on;
plot(gammaEstimatedOutputs(:,2), 'black');
hold on;
plot(correctedValues(:,2), 'magenta');
title('green channel');

figure;
plot(normalizedAvgRGB(:,3), 'b');
hold on;
plot(gammaEstimatedOutputs(:,3), 'black');
hold on;
plot(correctedValues(:,3), 'magenta');
title('blue channel');

%% gamma calculation based on derivatives
% offsetMeanRGB = zeros(size(avgRGB) + [1 0]);
% offsetMeanRGB(2:end, :) = avgRGB;
% 
% derivativeMeanRGB = avgRGB(2:end , :) - offsetMeanRGB(2:end - 1, :);
% 
% offsetLCDvalues = zeros(size(lcdValue) + [0 1]);
% offsetLCDvalues(:, 2:end) = lcdValue;
% 
% derivativeLCDValues = lcdValue(:, 2:end) - offsetLCDvalues(:, 2:end-1);
% 
% logDerivativeMeanRGB = log(derivativeMeanRGB);
% logDerivativeLCDValues = log(derivativeLCDValues);
% 
% logDerivativeLCDValues = repmat(logDerivativeLCDValues', [1, 3]);
% gamma2 = real(logDerivativeLCDValues./logDerivativeMeanRGB);

