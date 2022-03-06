img = imread('nvidia2.png');


fID = fopen('unit8Array.txt', 'w');
for i = 1:32
    for j = 1:32
        for colorChannel = 1:3
            fprintf(fID, '%3d, ', img(i, j, colorChannel));
        end
    end
    fprintf(fID, '\n');
end

fclose(fID);
