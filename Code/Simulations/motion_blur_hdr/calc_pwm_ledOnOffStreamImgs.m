function ledOnOffStreamImgs = calc_pwm_ledOnOffStreamImgs(backlight, backlightBitDepth, pngBitDepth)

ledOnOffStreamImgs = zeros(size(backlight, 1), size(backlight, 2), 3, 2^backlightBitDepth ...
                           - 1);
for rowIter = 1:size(backlight, 1)
    for colIter = 1:size(backlight, 2)
        for color = 1:3
            num = backlight(rowIter, colIter, color);
            num = floor(num/2^(pngBitDepth - backlightBitDepth));

            ledOnOffStream = [];
            for time = 1:2^backlightBitDepth - 1
                ledOnOffStream = [ledOnOffStream, (num >= time)];
            end
            ledOnOffStreamImgs(rowIter, colIter, color, :) = ledOnOffStream;
        end
    end
end

