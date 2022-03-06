function offsetImg = fractionalPixelOffset(img, offset)
offset1 = floor(offset);
offset2 = ceil(offset);
img1 = (1 - abs(offset - offset1)) * img;
img2 = (1 - abs(offset - offset2)) * img;

img1(end - offset1:end, :, :) = 0;
img1(:, end - offset1:end, :) = 0;
img1 = circshift(img1, offset1, 1);
img1 = circshift(img1, offset1, 2);

img2(end - offset2:end, :, :) = 0;
img2(:, end - offset2:end, :) = 0;
img2 = circshift(img2, offset2, 1);
img2 = circshift(img2, offset2, 2);

offsetImg = img1 + img2;

