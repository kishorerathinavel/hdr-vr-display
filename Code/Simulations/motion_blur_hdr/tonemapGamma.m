function fImg = tonemapGamma(img)
gammaFactor = 2.2;
toneMapFactor = 0.1;

fImg = (img./(img + toneMapFactor)).^(1/gammaFactor);
end
