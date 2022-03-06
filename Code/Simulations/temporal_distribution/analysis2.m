close all;
clear all;
clc;

%% Initializing some variables
% Variables names for the rest of the code are along the lines of Fig. 9 in hdr2004 paper

hdr = im2double(hdrread('..\..\..\Data\hdrData\memorial.hdr'));
LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

%% Creating the glare simulated image of the HDR image
b = LCDcols/tan(deg2rad(50));
glareFS = generateGlareFunction(4, 0.01, 10, b, false);
center = floor(size(glareFS)/2);

% figure;
% imshow(glareFS);
%
% figure;
% imshow(glareFS/mean(glareFS(:)));
%
% figure;
% cool(3);
% h = surf(log(glareFS));
% % h = surf(glare);
% set(h, 'LineStyle', 'none');

%% Defining inputs
arr_t_persistence = 1:16; % milliseconds
eyeSpeed = 500; % angles per second
anglesInMillisecond = eyeSpeed/1000;
pixelsInMillisecond = ceil(b*tan(deg2rad(anglesInMillisecond)));

%% Generating outputs

figure;
imshow(tonemapGamma(hdr));

perceivedHDRstationaryEye = imfilter(hdr, glareFS);
perceivedHDRstationaryEye = sum(hdr(:))*(perceivedHDRstationaryEye/sum(perceivedHDRstationaryEye(:)));
figure;
imshow(tonemapGamma(perceivedHDRstationaryEye));
spacing = 0.001;
perceivedImage = zeros(size(perceivedHDRstationaryEye));
for t = 0:5
    figure('units','normalized','outerposition',[0 0 1 1])
    t_persistence = arr_t_persistence(t + 1);
    eye_movement_vec = ones(1, 2*pixelsInMillisecond*t_persistence + 1);
    eye_movement_vec(1, pixelsInMillisecond*t_persistence:end) = 0;
    eye_movement_vec = eye_movement_vec/sum(eye_movement_vec(:));
    
    glare_moving_eye = imfilter(glareFS, eye_movement_vec);
    a = subplot(1, 4, 1);
    imshow(glare_moving_eye/mean(glare_moving_eye(:)));
    title('Glare * motion blur');

    presentedImage = hdr;
    presentedImage(presentedImage > 255) = 255;
    currPerceivedImage = imfilter(presentedImage, glare_moving_eye);
    perceivedImage = perceivedImage + currPerceivedImage;
    b = subplot(1, 4, 2);
    p_pos = get(a, 'pos');
    c_pos = p_pos;
    c_pos(1) = p_pos(1) + p_pos(3) + spacing;
    set(b, 'pos', c_pos);
    p_pos = get(b, 'pos');
    imshow(tonemapGamma(currPerceivedImage));
    title({'Perceived Display image','in current frame'});

    c = subplot(1, 4, 3);
    c_pos = p_pos;
    c_pos(1) = p_pos(1) + p_pos(3) + spacing;
    set(c, 'pos', c_pos);
    p_pos = get(c, 'pos');
    imshow(tonemapGamma(perceivedImage));
    title({'Perceived Display image','so far'});
        
    hdr = hdr - perceivedImage;
    hdr(hdr < 0) = 0;
    d = subplot(1, 4, 4);
    c_pos = p_pos;
    c_pos(1) = p_pos(1) + p_pos(3) + spacing;
    set(d, 'pos', c_pos);
    imshow(tonemapGamma(hdr));
    title('Residual');

end
