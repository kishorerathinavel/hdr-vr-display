function fImg = blockSampleImg(img, K)
[imgRows, imgCols, channels] = size(img);
fImg = imresize(img, [imgRows/K imgCols/K]);

% use subsampled primary instead of resize (bicubic, which is better)
for(r = 1:imgRows/K)
    for(c = 1:imgCols/K)
        for k = 1:channels
            block = img((r-1)*K+1:r*K, (c-1)*K+1:c*K, k);
            fImg(r,c,k) = mean(block(:));
        end
        
    end
end
end
