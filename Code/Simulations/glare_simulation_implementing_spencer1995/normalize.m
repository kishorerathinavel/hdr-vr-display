function retImg = normalize(img)
retImg = (img - min(img(:)))/range(img(:));
end
