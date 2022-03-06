function hdrvdpcompare(test, hdr, ppd)

warning('off', 'MATLAB:interp1:UsePCHIP');
res = hdrvdp(test, hdr, 'rgb-bt.709', ppd, {'rgb_display', 'led-lcd'});
cout = sprintf('Q %f', res.Q)

figure;
subplot(1, 4, 1);
imshow(hdrvdp_visualize('diff', res.P_map, test, hdr));
title('hdr vdp 2.2 diff');
subplot(1, 4, 2);
imshow(hdrvdp_visualize('pmap', res.P_map, {'context_image', hdr}));
title('hdr vdp 2.2 pmap');
subplot(1, 4, 3);
imshow(tonemapGamma(hdr));
title('reference');
subplot(1, 4, 4);
imshow(tonemapGamma(test));
title('test');

cout = sprintf('mean: %f %f', mean(test(:)), mean(hdr(:)))
cout = sprintf('min: %f %f', min(test(:)), min(hdr(:)))
cout = sprintf('max: %f %f', max(test(:)), max(hdr(:)))
w = warning ('on','all');

