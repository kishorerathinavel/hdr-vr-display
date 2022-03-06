% Simulate the backlight, all parameters are hacked.....

function BL = SimBL2(LEDs, K, Height, Width, Kernel)

center = floor((K-1)/2)+1;

% maybe we can use double convolution to model the blur???
BL = zeros(Width,Height,3);
for(r = 1:Width/K)
    for(c = 1:Height/K)
        BL( (r-1)*K+center, (c-1)*K+center, : ) = 1;
        BL( (r-1)*K+center, (c-1)*K+center, : ) = LEDs(r,c,:);
    end
end


%BL = imfilter(BL, Kernel, 'replicate');
BL = imfilter(BL, Kernel);
