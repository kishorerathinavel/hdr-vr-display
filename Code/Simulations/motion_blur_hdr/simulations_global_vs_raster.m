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

ppd = hdrvdp_pix_per_deg(15, [480 800], 0.1);
%% HDR 2004
%% Initializing some variables
% Variables names for the rest of the code are along the lines of Fig. 9 in hdr2004 paper

hdr = im2double(hdrread('..\..\..\Data\hdrData\resized_memorial_800_480.hdr'));
LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

LEDrows = 29;
LEDcols = ceil(LEDrows * LCDaspect);

K = round(LCDrows/LEDrows);

%% Calculating root image 
I = hdr;
rootI = I.^0.5; 

% figure;
% imshow(rootI);

%% Initialize backlight
grayRootI = mean(rootI, 3);
grayI_L = blockSampleImg(grayRootI, K);
grayI_L(grayI_L < 0) = 0;
grayI_L(grayI_L > 255) = 255;
origGrayI_L = grayI_L;

I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
I_L(:, :, 1) = grayI_L;
I_L(:, :, 2) = grayI_L;
I_L(:, :, 3) = grayI_L;

%% Generating diffusion kernel. Unknown parameters: (need to calibrate for these values) 

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
diffusionPSFMultiplicationFactor = 1; 

Kernel = fspecial('gaussian', diffusionPSFDiameter, diffusionPSFStandwardDeviaion) * diffusionPSFMultiplicationFactor;

diffusedI_L = SimBL2(I_L, K, LCDcols, LCDrows, Kernel); %step 4
origDiffusedI_L = diffusedI_L;

%% "Forward process"
% This is the proposed forward process according the hdr 2004 paper and the
% 2FieldScheme paper. However, in my experiments, I've found that
% initializing modulationImg = rootI and grayI_L to all ones is the best
% initialization combination
modulationImgTemp = I./(diffusedI_L + 1e-8); % step 5
modulationImg = modulationImgTemp;
modulationImg(modulationImg > 255) = 255;

% cout = 'moduationImgTemp'
% hdrvdpcompare(modulationImgTemp.*diffusedI_L, hdr, ppd);
% cout = 'moduationImgTemp'
% hdrvdpcompare(modulationImg.*diffusedI_L, hdr, ppd);
% keyboard;

origModulationImg = modulationImg;

%% "Iterative process"
Energy = [];
modulationImg = rootI;

% modulationImg = ones(size(origModulationImg));
% meanM = mean(rootI, 3);
% modulationImg(:,:,1) = meanM;
% modulationImg(:,:,2) = meanM;
% modulationImg(:,:,3) = meanM;
% grayI_L = ceil(origGrayI_L);

% Should be 16 for the adafruit boards, but 16 makes the images look terrible
maxGrayI_LQuantizationValue = 255; 

% This parameter is a multiplicative factor which basically artificially
% increase brightness of the LEDs after deconvolving desired diffusedI_L
% with Kernel. It is kind of like adding a DC gain to the entire image. If
% we didn't do this, grayI_L would be initialized to all ones and the
% changes made to it will change it only slightly (near the value of one) -
% while mathematically this is fine, in hardware implementation, the
% backlight is very dim. So, we add a scaling factor for the initial
% brightness as well as the subsequent changes
% artificialBrightnessScaleFactor = 125;
artificialBrightnessScaleFactor = 1; %maxGrayI_LQuantizationValue/diffusionPSFMultiplicationFactor;
grayI_L = artificialBrightnessScaleFactor*ones(size(origGrayI_L));
grayI_L(grayI_L < 0) = 0;
I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
I_L(:, :, 1) = grayI_L;
I_L(:, :, 2) = grayI_L;
I_L(:, :, 3) = grayI_L;

diffusedI_L = SimBL2(I_L, K, LCDcols, LCDrows, Kernel); %step 4

generatedImage = modulationImg.*diffusedI_L; % When we use this, the modulationImg and grayI_L
                                             % are very similar to their originals.

residual = I - generatedImage;
sqResidual = residual.*residual;
% Energy = [Energy, sum(sqResidual(:))];

    
for iter = 1:20
    % This is the expected perceived image - compare with prototype
   generatedImage = modulationImg.*diffusedI_L; % When we use this, the modulationImg and grayI_L are very similar to their originals. 
%    generatedImage = round(modulationImg).*round(diffusedI_L);
    
    residual = I - generatedImage;
    sqResidual = residual.*residual;
    currEnergy = sum(sqResidual(:))
    Energy = [Energy, currEnergy];
    
    fileName = sprintf('simulationOutputs/iter_%03d.png', iter - 1);
    imwrite([modulationImg (255/maxGrayI_LQuantizationValue)*diffusedI_L tonemapGamma(generatedImage) tonemapGamma(abs(residual))], fileName);
    
    
    lambda = 0.01;
    Mtr = per_block_weighted_dot_summed(residual.*modulationImg, [LCDrows/K + 1; LCDcols/K + 1], K, Kernel);    %residual = blue
    MtM = per_block_weighted_dot_summed(modulationImg.*modulationImg, [LCDrows/K + 1; LCDcols/K + 1], K, Kernel)+1e-3;   %hessian
    

    grayI_L = (grayI_L + artificialBrightnessScaleFactor*Mtr./(MtM + 1e-8));
    grayI_L(grayI_L < 0) = 0;
    grayI_L = (255/maxGrayI_LQuantizationValue)*round(maxGrayI_LQuantizationValue*(grayI_L/max(grayI_L(:))));
    

    I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
    I_L(:, :, 1) = grayI_L;
    I_L(:, :, 2) = grayI_L;
    I_L(:, :, 3) = grayI_L;
    
    diffusedI_L = SimBL2(I_L, K, LCDcols, LCDrows, Kernel); %step 4
%     diffusedI_L(diffusedI_L > 255) = 255;
    
    modulationImg = (modulationImg + (residual.*diffusedI_L)./(diffusedI_L.*diffusedI_L + 1e-8));
    modulationImg(modulationImg < 0) = 0;
    modulationImg(modulationImg > 255) = 255;
    
    if(sum(sqResidual(:)) < 1)
        break;
    end
    
    % bad local minima
    if(iter > 1 && (Energy(iter - 1) - Energy(iter))/Energy(iter-1) < 0.0001)
        break;
    end
end
iter

generatedImage = modulationImg.*diffusedI_L; % When we use this, the modulationImg and grayI_L are very similar to their originals.
residual = I - generatedImage;
sqResidual = residual.*residual;
Energy = [Energy, sum(sqResidual(:))];
fileName = sprintf('simulationOutputs/iter_%03d.png', iter);
imwrite([modulationImg (255/maxGrayI_LQuantizationValue)*diffusedI_L tonemapGamma(generatedImage) tonemapGamma(abs(residual))], fileName);

%% Output result of optimization algorithm

gamma = 3.1;
rangeModulationImg = range(modulationImg(:));
minModulationImg = min(modulationImg(:));
gammaCorrectedModulationImg = (((modulationImg - minModulationImg)/rangeModulationImg).^(1/gamma))*255;
transposedModulationImg = flipdim(permute(gammaCorrectedModulationImg, [2 1 3]), 2);
imwrite(uint8(transposedModulationImg), 'modulation.png');

I_L32x32 = zeros(32, 32, 3);
I_L32x32(2:30, 2:19, :) = 255*flipdim(flipdim(diffusionPSFMultiplicationFactor*I_L./max(I_L(:)), 2),1);
imwrite(uint8(I_L32x32), 'hdr2004.png');


cout = 'hdr2004'
hdrvdpcompare(modulationImg.*diffusedI_L, hdr, ppd);

%% Import images which are the result of the optimization algorithm

% backlight = imread('hdr2004.png');
% backlight = flip(backlight, 1);
% backlight = flip(backlight, 2);
% modulation = 255 * im2double(imrotate(imread('modulation.png'), 90));
% diffusedI_L = SimBL2(backlight, K, LCDcols, LCDrows, Kernel); 
% cout = 'input from files'
% hdrvdpcompare(modulation.*diffusedI_L, hdr, ppd);

backlight = I_L;
modulation = modulationImg;
diffusedI_L = SimBL2(backlight, K, LCDcols, LCDrows, Kernel); 
cout = 'input from algo'
hdrvdpcompare(modulation.*diffusedI_L, hdr, ppd);

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


% Others
vFOV = 80;
hFOV = vFOV*LCDaspect;
pngBitDepth = 8;
eyeRotVelocity = 200; % Defined in degrees per second

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

LEDnits = 16/rowInner_bitFrameTime;

%% Generalized BCM/PDM rowInner/rowOuter simulation
% modulationScheme = 1 => bcm 
% modulationScheme = 2 => pdm 
for modulationScheme = 1:2

    % loopOrder = 1 => rowInner (Loop order: ledRefresh loop, ledOnOffStreamIndex loop, rowIndex loop)
    % loopOrder = 2 => rowOuter (Loop order: ledRefresh loop, rowIndex loop, ledOnOffStreamIndex loop)
    for loopOrder = 1:2
        if(loopOrder == 1)
            bitFrameTime = rowInner_bitFrameTime;
        else
            bitFrameTime = rowOuter_bitFrameTime;
        end
    
        if (modulationScheme == 1)
            ledOnOffStreamImgs = calc_bcm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);
        else
            ledOnOffStreamImgs = calc_pwm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth);
        end
        
        if (loopOrder == 1)
            backlightImgs = LEDnits * calcBacklightImgs_RowInner(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                                       LEDrows, LEDcols);
        else
            backlightImgs = LEDnits * calcBacklightImgs_RowOuter(ledOnOffStreamImgs, ledOnOffStreamLength, rowOffset, ...
                                                       LEDrows, LEDcols);
        end
        
        diffusedBacklightImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
        parfor bitFrameIter = 1:numLEDbitFrames
            diffusedBacklightImgs(:,:,:,bitFrameIter) = SimBL2(backlightImgs(:,:,:,bitFrameIter), K, LCDcols, LCDrows, ...
                                                              Kernel);
        end
        % diffusedBacklightImgs(:,1:end - LCDcols, :,:) = [];

        
        perceivedImgs = zeros(LCDrows, LCDcols, 3, numLEDbitFrames);
        parfor bitFrameIter = 1:numLEDbitFrames
            perceivedImgs(:,:,:,bitFrameIter) = modulation.*diffusedBacklightImgs(:,:,:,bitFrameIter);
        end

        if(modulationScheme == 1)
            filePrefix = sprintf('simulationOutputs/bcm');
        else
            filePrefix = sprintf('simulationOutputs/pwm');
        end
        
        if(loopOrder == 1)
            filePrefix = sprintf('%s_rowInner', filePrefix);
        else
            filePrefix = sprintf('%s_rowOuter', filePrefix);
        end

        referencePerceivedImg = bitFrameTime * sum(perceivedImgs, 4);
        cout = sprintf('%s_reference', filePrefix)
        hdrvdpcompare(referencePerceivedImg, hdr, ppd);

        
        outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs);

        averagePerceivedImg = zeros(size(perceivedImgs, 1), size(perceivedImgs, 2), 3);
        parfor bitFrameIter = 1:size(perceivedImgs, 4)
            time = bitFrameIter * bitFrameTime;
            pixelOffset = (LCDcols/hFOV)*eyeRotVelocity*time/1000;
            currPerceivedImg = perceivedImgs(:,:,:,bitFrameIter);
            currPerceivedImg = fractionalPixelOffset(currPerceivedImg, pixelOffset);
            averagePerceivedImg = averagePerceivedImg + bitFrameTime*currPerceivedImg;
        end
        
        filePrefix
        hdrvdpcompare(averagePerceivedImg, hdr, ppd);
        suptitle(strrep(filePrefix(19:end), '_', ' '));

        fileName = sprintf('%s_averagePerceived.hdr', filePrefix);
        hdrwrite(averagePerceivedImg, fileName);
        fileName = sprintf('%s_averagePerceived_diff.hdr', filePrefix);
        hdrwrite(abs(averagePerceivedImg - referencePerceivedImg), fileName);
        fileName = sprintf('%s_perceivedImg_tonemapped.png', filePrefix);
        imwrite(tonemapGamma(averagePerceivedImg), fileName);
        fileName = sprintf('%s_perceivedImg_diff_tonemapped.png', filePrefix);
        imwrite(tonemapGamma(abs(hdr - averagePerceivedImg)), fileName);
    end
end
filePrefix = sprintf('simulationOutputs/');
fileName = sprintf('%sreference_tonemapped.png', filePrefix);
imwrite(tonemapGamma(hdr), fileName);

%% Section for DK2

hdr = hdrread('..\..\..\Data\hdrData\resized_memorial_800_480.hdr');
tonemappedHDR = tonemapGamma(hdr);
% imshow(tonemappedHDR);

oledMaxPersistence = 3;
oledPerceivedImg = zeros(size(tonemappedHDR));
oledTimePerRow = oledMaxPersistence/size(hdr, 2);
oled_LEDnits = 1/oledTimePerRow;

% If pixel motion blur is less than one, don't bother building a kernel. Do take care of pixel
% offsets though

for colIter = 1:size(hdr, 2)
    temp = tonemappedHDR;
    if(colIter > 1)
        temp(:,1:colIter - 1, :) = 0;
    end
    if(colIter < size(hdr, 2))
        temp(:,colIter + 1:end,:) = 0;
    end
    
    time = colIter * oledTimePerRow;
    pixelOffset =  (LCDcols/hFOV)*eyeRotVelocity*time/1000; 

    currPerceivedImg = fractionalPixelOffset(temp, pixelOffset);
    oledPerceivedImg = oledPerceivedImg + oledTimePerRow * oled_LEDnits * currPerceivedImg;
    
    % pixelOffset1 = floor(pixelOffset);
    % pixelOffset2 = ceil(pixelOffset);
    % temp1 = (1 - abs(pixelOffset - pixelOffset1)) * temp;
    % temp2 = (1 - abs(pixelOffset - pixelOffset2)) * temp;
    % temp1(end - pixelOffset1 : end, 1,:) = 0;
    % temp2(end - pixelOffset2 : end, 1,:) = 0;
    % temp1 = circshift(temp1, pixelOffset1, 2);
    % temp2 = circshift(temp2, pixelOffset2, 2);
    
    
    % if(colIter + pixelOffset1 <= LCDcols && colIter + pixelOffset2 <= LCDcols)
    %     oledPerceivedImg(:,colIter + pixelOffset1,:) = oledPerceivedImg(:,colIter + ...
    %                                                       pixelOffset1,:) + oled_LEDnits * oledTimePerRow*temp1;
    %     oledPerceivedImg(:,colIter + pixelOffset2,:) = oledPerceivedImg(:,colIter + ...
    %                                                       pixelOffset2,:) + oled_LEDnits * oledTimePerRow*temp2;
    % end
end

ppd = hdrvdp_pix_per_deg(15, [480 800], 0.1);
cout = 'oled'
hdrvdpcompare(oledPerceivedImg, hdr, ppd);
imshow(oledPerceivedImg);
title('test');
suptitle(strrep(filePrefix(19:end), '_', ' '));

filePrefix = sprintf('simulationOutputs/oled_raster');
fileName = sprintf('%s_perceivedImg.hdr', filePrefix);
hdrwrite(oledPerceivedImg, fileName);
fileName = sprintf('%s_perceivedImg_diff.hdr', filePrefix);
hdrwrite(abs(hdr - oledPerceivedImg), fileName);
fileName = sprintf('%s_perceivedImg_tonemapped.png', filePrefix);
imwrite(tonemapGamma(oledPerceivedImg), fileName);
fileName = sprintf('%s_perceivedImg_diff_tonemapped.png', filePrefix);
imwrite(tonemapGamma(abs(hdr - oledPerceivedImg)), fileName);


%% Using hdr vdp 2

% clear all;
% close all;
% clc;

% warning('off', 'MATLAB:interp1:UsePCHIP');
% hdr = hdrread('..\..\..\Data\hdrData\resized_memorial_800_480.hdr');
% figure;
% imshow(tonemapGamma(hdr));
% % noise = rand(size(hdr)) * 1;
% % test = hdr + noise;
% test = hdr;
% test(test > 40) = 40;
% figure;
% imshow(tonemapGamma(test));
% ppd = hdrvdp_pix_per_deg(15, [480 800], 0.1);
% res = hdrvdp(test, hdr, 'rgb-bt.709', ppd, {'rgb_display', 'led-lcd'});
% cout = sprintf('Q %f', res.Q)
% figure;
% imshow(hdrvdp_visualize('diff', res.P_map, test, hdr));
% figure;
% imshow(hdrvdp_visualize('pmap', res.P_map, {'context_image', hdr}));
% cout = sprintf('mean: %f %f', mean(test(:)), mean(hdr(:)))
% cout = sprintf('min: %f %f', min(test(:)), min(hdr(:)))
% cout = sprintf('max: %f %f', max(test(:)), max(hdr(:)))
% w = warning ('on','all');

