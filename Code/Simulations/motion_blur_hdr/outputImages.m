function outputImages(filePrefix, ledOnOffStreamImgs, backlightImgs, diffusedBacklightImgs, perceivedImgs)

allLEDOnOffStreamImgs = [];
for ledOnOffStreamIndex = 1:size(ledOnOffStreamImgs, 4)
    allLEDOnOffStreamImgs = [allLEDOnOffStreamImgs ledOnOffStreamImgs(:,:,:,ledOnOffStreamIndex)];
end
fileName = sprintf('%s_allLEDOnOffStreamImage.png', filePrefix);
imwrite(allLEDOnOffStreamImgs, fileName);

allBacklightImgs = [];
for time = 1:size(backlightImgs, 4)
    allBacklightImgs = [allBacklightImgs backlightImgs(:,:,:,time)];
end
fileName = sprintf('%s_allBacklightImgs.png', filePrefix);
imwrite(allBacklightImgs, fileName);

% for time = 1:size(diffusedBacklightImgs, 4)
%     fileName = sprintf('%s_diffusedBacklight_%03d.png', filePrefix, time);
%     imwrite(500 * diffusedBacklightImgs(:,:,:,time), fileName);
% end

% for time = 1:size(perceivedImgs, 4)
%     fileName = sprintf('%s_perceived_%03d.png', filePrefix, time);
%     imwrite(1000 * perceivedImgs(:,:,:,time), fileName);
% end

