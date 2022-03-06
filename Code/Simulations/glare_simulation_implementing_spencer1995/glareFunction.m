clear all;
close all;
clc;

%%
L = 0.005; % luminance

if L < 0.01
    alpha = 0.282;
    beta = 0.478;
    gamma = 0.207;
    zeta = 0.033;
elseif L < 3
    alpha = 0.368;
    beta = 0.478;
    gamma = 0.138;
    zeta = 0.016;
else
    alpha = 0.384;
    beta = 0.478;
    gamma = 0.138;
    zeta = 0;
end

lambda = 568;
F_0 = [];
F_1 = [];
F_2 = [];
F_3 = [];
M = 10;
resolution = 0.01;

for thetaX = -M:resolution:M
    theta = abs(thetaX);
    
    
    f_0 = 2.61 * 1e6 * exp(-(theta/0.02)^2);
    f_1 = 20.91/(theta + 0.02)^3;
    f_2 = 72.37/(theta + 0.02)^2;
%     f_3 = 436.9 * (568/lambda) * exp(-(theta - 3*lambda/568)^2);
    f_3 = 436.9 * (568/lambda) * exp(-((theta - 3)/0.2)^2);
    
    
    F_0 = [F_0 f_0];
    F_1 = [F_1 f_1];
    F_2 = [F_2 f_2];
    F_3 = [F_3 f_3];
end

theta = -M:resolution:M;

figure;
plot(theta, log10(F_0), 'g');
hold on;
plot(theta, log10(F_1), 'b');
hold on;
plot(theta, log10(F_2), 'r');
hold on;
plot(theta, log10(F_3), 'magenta');
ylim([-1 8]);
xlim([-10 10]);

%% 
% F_0 = F_0/sum(F_0);
% F_1 = F_1/sum(F_1);
% F_2 = F_2/sum(F_2);
% F_3 = F_3/sum(F_3);

%%
F_0 = alpha*F_0;
F_1 = beta*F_1;
F_2 = gamma*F_2;
F_3 = zeta*F_3;

%%
sumF = F_0 + F_1 + F_2 + F_3;
sumF = sumF/sum(sumF(:));

figure;
plot(theta, log(sumF));
%%
n = 300;
N = 2*n + 1;
maxD = N/sqrt(2);
filter = zeros(N, N);
indices = zeros(N,N,2);
patchSize = (2*M/resolution + 1)/(2*n + 1);
for i = 1:N-1
    for j = 1:N-1
        d1 = sqrt((i - N/2)^2 + (j - N/2)^2);
        %         d2 = sqrt((i + 1 - N/2)^2 + (j + 1 - N/2)^2);
        
        indexS = d1/maxD * M;
        %         indexE = ceil(d2/maxD * M);
        
        %         if(indexS > indexE)
        %             temp = indexE;
        %             indexE = indexS;
        %             indexS = temp;
        %         end
        %         diff = [diff abs(indexS - indexE)];
        %         if(indexS > M || indexE > M)
        if(floor((M + indexS)/ resolution + patchSize/2) > 2*M/resolution + 1)
            filter(i,j) = 0;
        else
            filter(i,j) = sum(sumF(floor((M + indexS)/ resolution - patchSize/2):floor((M + indexS)/ resolution + patchSize/2)));
            indices(i,j,1) = floor((M + indexS)/ resolution - patchSize/2);
            indices(i,j,2) = floor((M + indexS)/ resolution + patchSize/2);
        end
    end
end

figure;
imshow(filter/mean(filter(:)));

figure;
plot(log(filter(n,:)));

%% Constructing glare lines:
angleResolution = 1;
lines = rand(360*angleResolution, 1);

glareImg = zeros(size(filter));

for i = 1:N-1
    for j = 1:N-1
        angle = atan(abs(j - N/2)/abs(i - N/2));
        angleDeg = angle/pi*180;
        
        if(i - N/2 < 0 && j - N/2 >= 0)
            angleDeg = 90 + angleDeg;
        elseif(i - N/2 < 0 && j - N/2 < 0)
            angleDeg = 180 + angleDeg;
        elseif(i - N/2 >=0 && j - N/2 < 0)
            angleDeg = 270 + angleDeg;
        end
        
        if(angleDeg < 1)
            angleDeg = 1;
        end
        
        if(angleDeg > 360)
            angleDeg = 360;
        end
        d = sqrt((i - N/2)^2 + (j - N/2)^2);
        correctionFactor = (2*pi*d + 2*pi)/(360*angleResolution);
        linesIndex = floor(angleDeg*angleResolution);
        if(linesIndex < 1)
            linesIndex = 1;
        end
        glareImg(i,j) = correctionFactor * lines(linesIndex);
    end
end

figure;
imshow(normalize(glareImg));
imwrite(uint8(2*255*normalize(glareImg)), 'flareLines.png');

%%
PSF = glareImg.*filter;

figure;
imshow(0.1 * PSF/mean(PSF(:)));
