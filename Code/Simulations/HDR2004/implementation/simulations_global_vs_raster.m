% Modulation schemes for LED backlight array:

% Here, in each LED frame update, some rows are updated simultaneously. Each row being updated is
% offset from the next or previous row being updated by a fixed number given by rowOffset. To access
% all rows, the rows are lit in a scanline fashion. The number of times each row is accessesed
% before the entire LED frame is accesses is also given by rowOffset.What happens in each row access
% is what defines the modulation scheme. All schemes can be thought of as a combination of (1) how
% the loops are ordered and (2) the ledOnOffStream that is calculated and sent to the LED driver
% board. If the loops are ordered this way: ledRefresh loop, ledOnOffStreamIndex loop, rowIndex
% loop, then for each ledOnOffStreamIndex, all rows are accessed. The advantage is that all rows can
% display the LSB soon which means that the dim portions of an image have low latency and the
% disdvantage is a longer duration for each LED to display its on-off stream. If the loops ar
% ordered this way: ledRefresh loop, rowIndex loop, ledOnOffStreamIndex loop, then, for each row,
% the entire ledOnOffStream is displayed. The advantage is a shorter duration for each LED to
% display its on-off stream and the disadvantage is that rows that are accessed with higher delay
% than when the frame was generated are going to have more motion blur. This is the case with DK2
% however, since we use a 1/s scan display, the total time to update the entire frame is reduced by
% a factor of s. The ledOnOffStream is of two types currently: (1) BCM: Here, the ledOnOffStream is LSB
% for duration t, then (LSB + 1) for duration 2t and so on...  (2) PWM: Here, the ledOnOffStream of
% BCM is rearranged to bring all the ones earlier followed by zeros till end of ledOnOffStream

clear all;
close all;
clc;

%% Import images which are the result of the optimization algorithm
backlight = imread('hdr2004.png');
backlight = flip(backlight, 1);
backlight = flip(backlight, 2);
% imshow(backlight);

modulation = im2double(imrotate(imread('modulation.png'), 90));
% imshow(modulation);

%% Simulation parameters

% LCD
LCDrows = size(modulation, 1);
LCDcols = size(modulation, 2);
LCDaspect = LCDcols/LCDrows;
LCDfps = 60;
maxLCDFrameTime = 1000/LCDfps; % in milliseconds

% LED
LEDrows = size(backlight, 1);
LEDcols = size(backlight, 2);
% LEDcols = ceil(LEDrows * LCDaspect);
backlightBitDepth = 4;
ledOnOffStreamLength = 2^backlightBitDepth - 1;
scanRate = 1/4;
rowOffset = 1/scanRate;
numLEDbitFrames = ledOnOffStreamLength * rowOffset;

LEDnits = 200;

% Others
K = round(LCDrows/LEDrows);
vFOV = 80;
hFOV = vFOV*LCDaspect;
pngBitDepth = 8;
eyeRotVelocity = 100; % Defined in degrees per second

maxPersistence = 1;

% When loop order is ledRefresh loop, rowIndex loop, ledOnOffStreamIndex loop:
rowOuter_maxTimePerRowAccess = maxLCDFrameTime/rowOffset;
if(rowOuter_maxTimePerRowAccess > maxPersistence)
    rowOuter_maxTimePerRowAccess = maxPersistence;
end
rowOuter_maxBitStreamTime = rowOuter_maxTimePerRowAccess/ledOnOffStreamLength;
rowOuter_bitFrameTime = rowOuter_maxBitStreamTime;
rowOuter_LED_end2end_On_Time = ledOnOffStreamLength * rowOuter_maxBitStreamTime;

% When loop order is ledRefresh loop, ledOnOffStreamIndex loop, rowIndex loop:
% rowInner_maxBitStreamTime = maxLCDFrameTime/ledOnOffStreamLength;
% if(rowInner_maxBitStreamTime > maxPersistence)
%     rowInner_maxBitStreamTime = maxPersistence;
% end
% rowInner_maxTimePerRowAccess = rowInner_maxBitStreamTime/rowOffset;
% rowInner_bitFrameTime = rowInner_maxTimePerRowAccess;
% rowInner_LED_end2end_On_Time = ledOnOffStreamLength * rowOffset * rowOuter_bitFrameTime;

rowInner_bitFrameTime = rowOuter_bitFrameTime;
rowInner_LED_end2end_On_Time = ledOnOffStreamLength * rowOffset * rowInner_bitFrameTime;

%% Kernel
% Just works - need to calibrate
diffusionPSFDiameter = 200;

% The (1/6) works and I found this by playing round with the values. Might
% change upon calibration
diffusionPSFStandwardDeviaion = 20.2;

% This parameter artificially adds brightness to the diffusedI_L which is
% the result of convolving grayI_L with Kernel. Sometimes, without this
% artificial brightness increase, the diffusedI_L will never reach bright
% enough values (because the maximum grayI_L is 255 which gets spread out a
% lot by the Kernel); without bright enough diffusedI_L values, the
% residual image can be quite large if the hdr image has very bright
% pixels. This parameter is basically to avoid such high residuals - this
% parameter is not physically realizable. Also read comments for
% 'artificialBrightnessScaleFactor'
diffusionPSFMultiplicationFactor = 2; 

Kernel = fspecial('gaussian', diffusionPSFDiameter, diffusionPSFStandwardDeviaion) * diffusionPSFMultiplicationFactor;

%% Section for DK2

hdr = im2double(hdrread('..\..\..\Data\hdrData\memorial.hdr'));
tonemappedHDR = tonemapGamma(hdr);
% imshow(tonemappedHDR);

oledMaxPersistence = 3;
oledPerceivedImg = zeros(size(tonemappedHDR));
oledTimePerRow = oledMaxPersistence/size(hdr, 2);

% If pixel motion blur is less than one, don't bother building a kernel. Do take care of pixel
% offsets though
oledPixelMotionBlur = floor((LCDcols/hFOV)*eyeRotVelocity*oledTimePerRow/1000); 

for colIter = 1:size(hdr, 2)
    temp = tonemappedHDR(:,colIter,:);
    time = colIter * oledTimePerRow;
    pixelOffset =  (LCDcols/hFOV)*eyeRotVelocity*time/1000; 
    pixelOffset1 = floor(pixelOffset);
    pixelOffset2 = ceil(pixelOffset);
    temp1 = (1 - abs(pixelOffset - pixelOffset1)) * temp;
    temp2 = (1 - abs(pixelOffset - pixelOffset2)) * temp;
    temp1(end - pixelOffset1 : end, 1,:) = 0;
    temp2(end - pixelOffset2 : end, 1,:) = 0;
    temp1 = circshift(temp1, pixelOffset1, 2);
    temp2 = circshift(temp2, pixelOffset2, 2);
    if(colIter + pixelOffset1 <= LCDcols && colIter + pixelOffset2 <= LCDcols)
        oledPerceivedImg(:,colIter + pixelOffset1,:) = oledPerceivedImg(:,colIter + ...
                                                          pixelOffset1,:) + LEDnits * oledTimePerRow*temp1;
        oledPerceivedImg(:,colIter + pixelOffset2,:) = oledPerceivedImg(:,colIter + ...
                                                          pixelOffset2,:) + LEDnits * oledTimePerRow*temp2;
    end
end
filePrefix = sprintf('simulationOutputs/oled_raster');
fileName = sprintf('%s_perceivedImg.hdr', filePrefix);
hdrwrite(oledPerceivedImg, fileName);
fileName = sprintf('%s_perceivedImg_diff.hdr', filePrefix);
hdrwrite(abs(hdr - oledPerceivedImg), fileName);


%% BCM; Loop order: ledRefresh loop, ledOnOffStreamIndex loop, rowIndex loop

ledOnOffStreamImgs = calc_bcm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);

backlightImgs = calcBacklightImgs_RowInner(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                           LEDrows, LEDcols);

diffusedBacklightImgs = zeros(LCDrows, LCDrows, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    diffusedBacklightImgs(:,:,:,bitFrameIter) = SimBL2(backlightImgs(:,:,:,bitFrameIter), K, LCDrows, LCDrows, ...
                                               Kernel);
end
diffusedBacklightImgs(:,1:end - LCDcols, :,:) = [];

perceivedImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    perceivedImgs(:,:,:,bitFrameIter) = modulation.*diffusedBacklightImgs(:,:,:,bitFrameIter);
end

referencePerceivedImg = LEDnits * rowInner_bitFrameTime * sum(perceivedImgs, 4);

filePrefix = sprintf('simulationOutputs/bcm_rowInner');
outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs);

averagePerceivedImg = zeros(size(perceivedImgs, 1), size(perceivedImgs, 2), 3);
for bitFrameIter = 1:size(perceivedImgs, 4)
    time = bitFrameIter * rowInner_bitFrameTime;
    pixelOffset = (LCDcols/hFOV)*eyeRotVelocity*time/1000;
    currPerceivedImg = perceivedImgs(:,:,:,bitFrameIter);
    currPerceivedImg = fractionalPixelOffset(currPerceivedImg, pixelOffset);
    averagePerceivedImg = averagePerceivedImg + LEDnits * rowInner_bitFrameTime*currPerceivedImg;
end
fileName = sprintf('%s_averagePerceived.hdr', filePrefix);
hdrwrite(averagePerceivedImg, fileName);
fileName = sprintf('%s_averagePerceived_diff.hdr', filePrefix);
hdrwrite(abs(averagePerceivedImg - referencePerceivedImg), fileName);



%% PWM; Loop order: ledRefresh loop, ledOnOffStreamIndex loop, rowIndex loop
ledOnOffStreamImgs = calc_pwm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);

backlightImgs = calcBacklightImgs_RowInner(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                           LEDrows, LEDcols);

diffusedBacklightImgs = zeros(LCDrows, LCDrows, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    diffusedBacklightImgs(:,:,:,bitFrameIter) = SimBL2(backlightImgs(:,:,:,bitFrameIter), K, LCDrows, LCDrows, ...
                                               Kernel);
end
diffusedBacklightImgs(:,1:end - LCDcols, :,:) = [];

perceivedImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    perceivedImgs(:,:,:,bitFrameIter) = modulation.*diffusedBacklightImgs(:,:,:,bitFrameIter);
end
referencePerceivedImg = LEDnits * rowInner_bitFrameTime * sum(perceivedImgs, 4);


filePrefix = sprintf('simulationOutputs/pwm_rowInner');
outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs);

averagePerceivedImg = zeros(size(perceivedImgs, 1), size(perceivedImgs, 2), 3);
for bitFrameIter = 1:size(perceivedImgs, 4)
    time = bitFrameIter * rowInner_bitFrameTime;
    pixelOffset = (LCDcols/hFOV)*eyeRotVelocity*time/1000;
    currPerceivedImg = perceivedImgs(:,:,:,bitFrameIter);
    currPerceivedImg = fractionalPixelOffset(currPerceivedImg, pixelOffset);
    averagePerceivedImg = averagePerceivedImg + LEDnits * rowInner_bitFrameTime*currPerceivedImg;
end
fileName = sprintf('%s_averagePerceived.hdr', filePrefix);
hdrwrite(averagePerceivedImg, fileName);
fileName = sprintf('%s_averagePerceived_diff.hdr', filePrefix);
hdrwrite(abs(averagePerceivedImg - referencePerceivedImg), fileName);



%% BCM; Loop order: ledRefresh loop, rowIndex loop, ledOnOffStreamIndex loop

ledOnOffStreamImgs = calc_bcm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);
backlightImgs = calcBacklightImgs_RowOuter(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                           LEDrows, LEDcols);

diffusedBacklightImgs = zeros(LCDrows, LCDrows, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    diffusedBacklightImgs(:,:,:,bitFrameIter) = SimBL2(backlightImgs(:,:,:,bitFrameIter), K, LCDrows, LCDrows, ...
                                               Kernel);
end
diffusedBacklightImgs(:,1:end - LCDcols, :,:) = [];



perceivedImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    perceivedImgs(:,:,:,bitFrameIter) = modulation.*diffusedBacklightImgs(:,:,:,bitFrameIter);
end
referencePerceivedImg = LEDnits * rowOuter_bitFrameTime * sum(perceivedImgs, 4);

filePrefix = sprintf('simulationOutputs/bcm_rowOuter');
outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs);

averagePerceivedImg = zeros(size(perceivedImgs, 1), size(perceivedImgs, 2), 3);
for bitFrameIter = 1:size(perceivedImgs, 4)
    time = bitFrameIter * rowOuter_bitFrameTime;
    pixelOffset = (LCDcols/hFOV)*eyeRotVelocity*time/1000;
    currPerceivedImg = perceivedImgs(:,:,:,bitFrameIter);
    currPerceivedImg = fractionalPixelOffset(currPerceivedImg, pixelOffset);
    averagePerceivedImg = averagePerceivedImg + LEDnits * rowOuter_bitFrameTime*currPerceivedImg;
end
fileName = sprintf('%s_averagePerceived.hdr', filePrefix);
hdrwrite(averagePerceivedImg, fileName);
fileName = sprintf('%s_averagePerceived_diff.hdr', filePrefix);
hdrwrite(abs(averagePerceivedImg - referencePerceivedImg), fileName);



%% PWM; Loop order: ledRefresh loop, rowIndex loop, ledOnOffStreamIndex loop
ledOnOffStreamImgs = calc_pwm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);

backlightImgs = calcBacklightImgs_RowOuter(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                           LEDrows, LEDcols);

diffusedBacklightImgs = zeros(LCDrows, LCDrows, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    diffusedBacklightImgs(:,:,:,bitFrameIter) = SimBL2(backlightImgs(:,:,:,bitFrameIter), K, LCDrows, LCDrows, ...
                                               Kernel);
end
diffusedBacklightImgs(:,1:end - LCDcols, :,:) = [];

perceivedImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
for bitFrameIter = 1:numLEDbitFrames
    perceivedImgs(:,:,:,bitFrameIter) = modulation.*diffusedBacklightImgs(:,:,:,bitFrameIter);
end
referencePerceivedImg = LEDnits * rowOuter_bitFrameTime * sum(perceivedImgs, 4);


filePrefix = sprintf('simulationOutputs/pwm_rowOuter');
outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs);

averagePerceivedImg = zeros(size(perceivedImgs, 1), size(perceivedImgs, 2), 3);
for bitFrameIter = 1:size(perceivedImgs, 4)
    time = bitFrameIter * rowOuter_bitFrameTime;
    pixelOffset = (LCDcols/hFOV)*eyeRotVelocity*time/1000;
    currPerceivedImg = perceivedImgs(:,:,:,bitFrameIter);
    currPerceivedImg = fractionalPixelOffset(currPerceivedImg, pixelOffset);
    averagePerceivedImg = averagePerceivedImg + LEDnits * rowOuter_bitFrameTime*currPerceivedImg;
end
fileName = sprintf('%s_averagePerceived.hdr', filePrefix);
hdrwrite(averagePerceivedImg, fileName);
fileName = sprintf('%s_averagePerceived_diff.hdr', filePrefix);
hdrwrite(abs(averagePerceivedImg - referencePerceivedImg), fileName);




% OLEDs

% Voltage control

