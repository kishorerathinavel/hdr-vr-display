close all;
clear all;
clc;

%% Initializing some variables
% Variables names for the rest of the code are along the lines of Fig. 9 in hdr2004 paper

hdr = im2double(hdrread('..\..\..\Data\hdrData\memorial.hdr'));
hdr(:,:,1) = 1.0*hdr(:,:,1);
hdr(:,:,2) = 1.0*hdr(:,:,2);
hdr(:,:,3) = 0.9*hdr(:,:,3);

LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

LEDrows = 29;
LEDcols = ceil(LEDrows * LCDaspect);

K = round(LCDrows/LEDrows);

%% Calculating root image 
I = padCrop(hdr, 800, 480); 

fileName = sprintf('resized_reference_hdr_%d_%d.hdr', LCDrows, LCDcols);
hdrwrite(I, fileName);

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


% %% Printing backlight infomation to text file
% I_L32x32 = zeros(32, 32, 3);
% I_L32x32(2:31, 2:LEDcols + 1, :) = uint8(255*flipdim(I_L./max(I_L(:)), 2));
% fID = fopen('unit8Array.txt', 'w');
% for i = 1:32
%     for j = 1:32
%         for colorChannel = 1:3
%             fprintf(fID, '%3d, ', I_L32x32(i, j, colorChannel));
%         end
%     end
%     fprintf(fID, '\n');
% end
% fclose(fID);

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
diffusionPSFMultiplicationFactor = 2; 

Kernel = fspecial('gaussian', diffusionPSFDiameter, diffusionPSFStandwardDeviaion) * diffusionPSFMultiplicationFactor;
% maxKernelVal = max(Kernel(:));
% Kernel = Kernel./(maxKernelVal);

diffusedI_L = SimBL2(I_L, K, LCDcols, LCDrows, Kernel); %step 4
% figure;
% imshow(diffusedI_L);
origDiffusedI_L = diffusedI_L;

% imshow(tonemapGamma(Kernel));

%% "Forward process"
% This is the proposed forward process according the hdr 2004 paper and the
% 2FieldScheme paper. However, in my experiments, I've found that
% initializing modulationImg = rootI and grayI_L to all ones is the best
% initialization combination
modulationImg = I./(diffusedI_L + 1e-8); % step 5
modulationImg(modulationImg < 0) = 0;
modulationImg(modulationImg > 255) = 255;
% figure;
% imshow(modulationImg);

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
maxGrayI_LQuantizationValue = 32; 

% This parameter is a multiplicative factor which basically artificially
% increase brightness of the LEDs after deconvolving desired diffusedI_L
% with Kernel. It is kind of like adding a DC gain to the entire image. If
% we didn't do this, grayI_L would be initialized to all ones and the
% changes made to it will change it only slightly (near the value of one) -
% while mathematically this is fine, in hardware implementation, the
% backlight is very dim. So, we add a scaling factor for the initial
% brightness as well as the subsequent changes
% artificialBrightnessScaleFactor = 125;
artificialBrightnessScaleFactor = maxGrayI_LQuantizationValue/diffusionPSFMultiplicationFactor;
grayI_L = artificialBrightnessScaleFactor*ones(size(origGrayI_L));
grayI_L(grayI_L < 0) = 0;
I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
I_L(:, :, 1) = grayI_L;
I_L(:, :, 2) = grayI_L;
I_L(:, :, 3) = grayI_L;

diffusedI_L = SimBL2(I_L, K, LCDcols, LCDrows, Kernel); %step 4

generatedImage = modulationImg.*diffusedI_L; % When we use this, the modulationImg and grayI_L are very similar to their originals.
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
    
    fileName = sprintf('Outputs/iter_%03d.png', iter - 1);
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
fileName = sprintf('Outputs/iter_%03d.png', iter);
imwrite([modulationImg (255/maxGrayI_LQuantizationValue)*diffusedI_L tonemapGamma(generatedImage) tonemapGamma(abs(residual))], fileName);
%%


gamma = 3.1;
rangeModulationImg = range(modulationImg(:));
minModulationImg = min(modulationImg(:));
gammaCorrectedModulationImg = (((modulationImg - minModulationImg)/rangeModulationImg).^(1/gamma))*255;
transposedModulationImg = flipdim(permute(gammaCorrectedModulationImg, [2 1 3]), 2);
imwrite(uint8(transposedModulationImg), 'modulation.png');

I_L32x32 = zeros(32, 32, 3);
I_L32x32(2:30, 2:19, :) = 255*flipdim(flipdim(diffusionPSFMultiplicationFactor*I_L./max(I_L(:)), 2),1);
imwrite(uint8(I_L32x32), 'hdr2004.png');








