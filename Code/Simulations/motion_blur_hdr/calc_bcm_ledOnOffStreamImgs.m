function ledOnOffStreamImgs = calc_bcm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth)

ledOnOffStreamImgs = zeros(size(backlight, 1), size(backlight, 2), 3, 2^backlightBitDepth ...
                           - 1);
for rowIter = 1:size(backlight, 1)
    for colIter = 1:size(backlight, 2)
        for color = 1:3
            num = backlight(rowIter, colIter, color);
            bitPattern = de2bi(bitshift(num, backlightBitDepth - pngBitDepth), backlightBitDepth);
            
            ledOnOffStream = [];
            for iter = 1:backlightBitDepth
                for length = 1:2^(iter - 1)
                    ledOnOffStream = [ledOnOffStream, bitPattern(iter)];
                end
            end
            ledOnOffStreamImgs(rowIter, colIter, color, :) = ledOnOffStream;
        end
    end
end

