close all;
clear all;

LCDrows = 800;
LCDcols = 480;
LCDaspect = LCDcols/LCDrows;

LEDrows = 29;
LEDcols = ceil(LEDrows * LCDaspect);

values = [255, 200, 150, 100, 50, 0];

%% Single LED images
for i = 1:size(values, 2)
    grayI_L = zeros(LEDrows, LEDcols);
    grayI_L(floor(LEDrows/2), floor(LEDcols/2)) = values(i);
    
    I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
    I_L(:, :, 1) = grayI_L;
    I_L(:, :, 2) = grayI_L;
    I_L(:, :, 3) = grayI_L;
    
    I_L32x32 = zeros(32, 32, 3);
    I_L32x32(2:LEDrows + 1, 2:LEDcols + 1, :) = flipdim(flipdim(I_L, 2),1);
    
    filename = sprintf('LEDimages/singleLED_%03d.png', values(i));
    imwrite(uint8(I_L32x32), filename);
end

%% All LED images
for i = 1:size(values, 2)
    grayI_L = values(i)*ones(LEDrows, LEDcols);
    
    I_L = zeros(size(grayI_L, 1), size(grayI_L, 2), 3);
    I_L(:, :, 1) = grayI_L;
    I_L(:, :, 2) = grayI_L;
    I_L(:, :, 3) = grayI_L;
    
    I_L32x32 = zeros(32, 32, 3);
    I_L32x32(2:LEDrows + 1, 3:LEDcols + 2, :) = flipdim(flipdim(I_L, 2),1);
    
    filename = sprintf('LEDimages/allLED_%03d.png', values(i));
    imwrite(uint8(I_L32x32), filename);
end




