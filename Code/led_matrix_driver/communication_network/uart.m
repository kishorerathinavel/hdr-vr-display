clear all;
close all;
clc;
delete(instrfindall)

%%
bl_img = imread('../Simulations/HDR2004/implementation/hdr2004.png');
% imshow(bl_img);


%% Test serial write
s = serial('COM4');
prt = instrfind;
prt.BaudRate = 115200;
fopen(s);

for repeat = 1:50

    for r = 1:15
        for c = 1:32
            fwrite(s, bl_img(c,r,1));
            fwrite(s, bl_img(c,r + 16,1));
            % str = sprintf('%d', bl_img(r, c, 1));
            % fprintf(s, '%s', str);
        end
    end

end


fclose(s);
