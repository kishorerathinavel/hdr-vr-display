clear all;
close all;

LCDrows = 800;
LCDcols = 480;

values = round(0:255/32:255);

for i = 1:size(values,2)
    filename = sprintf('LCDimages/lcdImage_%03d.png', values(i));
    img = values(i)*ones(480, 800, 3);
    imwrite(uint8(img), filename);
end

squareWidth = 200;
img = zeros(480, 800, 3);
img(240 - floor(squareWidth/2):240 + squareWidth/2, 400 - floor(squareWidth/2):400 + squareWidth/2, :) = 255;
filename = sprintf('LCDimages/whiteSquare_%03d.png', squareWidth);
imwrite(uint8(img), filename);



