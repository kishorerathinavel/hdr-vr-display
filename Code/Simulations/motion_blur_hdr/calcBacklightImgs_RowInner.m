function backlightImgs = calcBacklightImgs_RowInner(ledOnOffStreamImgs, ledOnOffStreamLength, ...
                                                  rowOffset, LEDrows, LEDcols)

backlightImgs = zeros(size(ledOnOffStreamImgs, 1), size(ledOnOffStreamImgs, 2), size(ledOnOffStreamImgs, ...
                                                  3), ledOnOffStreamLength * rowOffset);
for ledOnOffStreamIndex = 1:ledOnOffStreamLength
    for rowIndex = 1:rowOffset
        accessedRowImage = zeros(LEDrows, LEDcols, 3);
        for row = rowIndex:rowOffset:LEDrows
            accessedRowImage(row, :, :) = 1;
        end
        backlightImg = accessedRowImage.*ledOnOffStreamImgs(:,:,:,ledOnOffStreamIndex);
        backlightImgs(:,:,:, (ledOnOffStreamIndex - 1) * rowOffset + rowIndex) = backlightImg;
    end
end

