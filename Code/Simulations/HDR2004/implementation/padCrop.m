function fImg = padCrop(img, rows, cols)
    [imgRows, imgCols, channels] = size(img);
    
    fImg = zeros(rows, cols, channels);
    
    if(imgRows > rows) 
        img(1:(imgRows - rows)/2 + 1, :, :) = [];
        img(rows + 1:size(img, 1), :, :) = [];
    end
    
    if(imgCols > cols)
        img(:, 1:(imgCols - cols)/2 + 1, :, :) = [];
        img(:, cols + 1:size(img, 2), :) = [];
    end
    
    if(imgRows < rows)
        startRow = (rows - imgRows)/2 + 1;
        fImg(startRow:startRow + imgRows - 1, :, :) = img;
    end

    if(imgCols < cols)
        startCol = (cols - imgCols)/2 + 1;
        fImg(:, startCol: startCol + imgCols - 1, :) = img;
    end
end
