function fImg = tonemapGamma(img)
gammaFactor = 1.8;
toneMapFactor = 1;

fImg = (img./(img + toneMapFactor)).^(1/gammaFactor);
end
