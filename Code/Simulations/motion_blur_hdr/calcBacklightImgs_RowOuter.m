function backlightImgs = calcBacklightImgs_RowOuter(ledOnOffStreamImgs, ledOnOffStreamLength, ...
                                                  rowOffset, LEDrows, LEDcols)

backlightImgs = zeros(size(ledOnOffStreamImgs, 1), size(ledOnOffStreamImgs, 2), size(ledOnOffStreamImgs, ...
                                                  3), ledOnOffStreamLength * rowOffset);
for rowIndex = 1:rowOffset
    for ledOnOffStreamIndex = 1:ledOnOffStreamLength
        accessedRowImage = zeros(LEDrows, LEDcols, 3);
        for row = rowIndex:rowOffset:LEDrows
            accessedRowImage(row, :, :) = 1;
        end
        backlightImg = accessedRowImage.*ledOnOffStreamImgs(:,:,:,ledOnOffStreamIndex);
        backlightImgs(:,:,:, (rowIndex - 1) * ledOnOffStreamLength + ledOnOffStreamIndex) = backlightImg;
    end
end

