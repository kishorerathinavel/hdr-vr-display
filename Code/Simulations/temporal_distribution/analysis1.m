close all;
clear all;
clc;

%% Defining inputs
arr_dist_bw_px = 1:20;
arr_vel_eyes = 1:10; % pixels per millisecond
arr_t_persistence = 1:16; % milliseconds
arr_contrast = 1:10:400;

LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

%% Creating space for output matrices
perceived_stationery_eyes = zeros(length(arr_dist_bw_px), length(arr_vel_eyes), length(arr_t_persistence), length(arr_contrast));
perceived_sp_eyes = zeros(length(arr_dist_bw_px), length(arr_vel_eyes), length(arr_t_persistence), length(arr_contrast));

%% Getting glare function
d = LCDcols/tan(deg2rad(40)); % assume that current hdr image was shot by a camera of FOV 80 degrees
glareFS = generateGlareFunction(4, 0.01, 20, d, false);
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

center = floor(size(glareFS)/2);
hf_glare_size = size(glareFS) - center;

%% Generate outputs

for k = 1:length(arr_t_persistence)
    figure;
    for j = 1:length(arr_vel_eyes)
        t_persistence = arr_t_persistence(k);
        vel_eyes = arr_vel_eyes(j);
        eye_movement_vec = ones(1, 2*vel_eyes*t_persistence + 1);
        eye_movement_vec(1, vel_eyes*t_persistence:end) = 0;
        eye_movement_vec = eye_movement_vec/sum(eye_movement_vec(:));
        
        glare_moving_eye = imfilter(glareFS, eye_movement_vec);

%         diff = abs(glare_moving_eye - glareFS);
%         imshow(diff/mean(diff(:)));
        imshow(glare_moving_eye/mean(glare_moving_eye(:)));
        
        for i = 1:length(arr_dist_bw_px)
            for l = 1:length(arr_contrast)
                
                dist_bw_px = arr_dist_bw_px(i);
                
                contrast = arr_contrast(l);
                
                alpha = glareFS(center(1), center(2));
                beta = glareFS(center(1) + dist_bw_px, center(2) + dist_bw_px);

                
                alpha2 = glare_moving_eye(center(1), center(2));
                beta2 = glare_moving_eye(center(1) + dist_bw_px, center(2) + dist_bw_px);
                
                perceived_stationery_eyes(dist_bw_px, vel_eyes, t_persistence, contrast) = contrast*(alpha - beta);
                perceived_sp_eyes(dist_bw_px, vel_eyes, t_persistence, contrast) = contrast*(alpha2 - beta2);
                
            end
        end
    end
end

diff = perceived_sp_eyes - perceived_stationery_eyes;
[value index] = min(diff(:))
[a b c d] = ind2sub(size(perceived_sp_eyes), index)


%% Experimenting with matrix vector convolution
% img = imread('nvidia_green_4-wallpaper-800x480.jpg');
% filt = ones(20,1);
% filt = filt/sum(filt(:));
% imshow(imfilter(img, filt));