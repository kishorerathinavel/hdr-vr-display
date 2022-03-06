BL1 = imread('BL1.png');

img = zeros(32, 32, 3);

imwrite(img, 'test1.png');

img(20:30, 20:30, :) = 255;
imwrite(img, 'test2.png');
