function [mux, muy, sigmax, sigmay] = findSpatialMuSigma(data, threshold)

data(data < threshold) = 0;
dataAlongX = sum(data, 1);
dataAlongY = sum(data, 2);

xdata = 1:size(data, 1);
ydata = 1:size(data, 2);

weightedDataX = xdata.*dataAlongX;
sumWeightedDataX = sum(weightedDataX);
sumWeightsX = sum(dataAlongX);
mux = sumWeightedDataX/sumWeightsX;

weightedDataY = ydata'.*dataAlongY;
sumWeightedDataY = sum(weightedDataY);
sumWeightsY = sum(dataAlongY);
muy = sumWeightedDataY/sumWeightsY;

avgDataAlongX = mean(dataAlongX);
avgDataAlongY = mean(dataAlongY);

avgDataX = avgDataAlongX*ones(size(dataAlongX));
avgDataY = avgDataAlongY*ones(size(dataAlongY));

diffDataX = dataAlongX - avgDataX;
diffDataY = dataAlongY - avgDataY;

sigmax = (sum(diffDataX.*diffDataX)/size(diffDataX,2))^0.5;
sigmay = (sum(diffDataY.*diffDataY)/size(diffDataY,1))^0.5;

end
