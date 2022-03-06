
%% 
% Downscale a grayscale image I given an array of LEDs and Kernel Size
function S = per_block_weighted_dot_summed(I, LED_size, K, Kernel)
m = LED_size(1);
n = LED_size(2);
[h,w] = size(Kernel);

%maybe padarray(I, with kernel size?)
I = padarray(I, [h w]); %pad zeros on both dimension.

for(r = 1:m)
    for(c = 1:n)
        center = round([(r-1)*K+K/2+h, (c-1)*K+K/2+w]);
        % carve out the region we are interested.
        Weighted = I(center(1) - h/2 + 1:center(1) + h/2, center(2) - w/2 + 1:center(2) + w/2).*Kernel;
        
        S(r,c) = sum(sum(  Weighted ));
    end
end
    