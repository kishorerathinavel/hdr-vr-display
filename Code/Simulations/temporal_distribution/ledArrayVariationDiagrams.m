close all;
clear all;
clc;

lineWidth = 3;
fontSize = 12;

%% BCM and fixed voltage
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));

figure;
for i = 1:k
    voltage = zeros(size(time));
    currVoltage = round(rand())*5;
    for j = 1:(2^(i-1))
        t = 2^(i-1) - 1 + j;
        startingIndex = find(time == t);
        endingIndex = find(time == t + 1);
        voltage(startingIndex:endingIndex) = currVoltage;
    end
    plot(time, voltage, 'LineWidth', lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('BCM and Fixed voltage');
set(gca,'FontSize',fontSize)

%% BCM and LCD
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));
maxVoltage = 3.0;
figure;
for i = 1:k
    voltage = zeros(size(time));
    currVoltage = round(rand())*maxVoltage;
    for j = 1:(2^(i-1))
        t = 2^(i-1) - 1 + j;
        startingIndex = find(time == t);
        endingIndex = find(time == t + 1);
        voltage(startingIndex:endingIndex) = currVoltage;
    end
    plot(time, voltage, 'LineWidth',lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('BCM and LCD');
set(gca,'FontSize',fontSize)

%% BCM and Controllable voltage for quantized frame-time

k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));

figure;
for i = 1:k
    voltage = zeros(size(time));
    currVoltage = rand()*5;
    for j = 1:(2^(i-1))
        t = 2^(i-1) - 1 + j;
        startingIndex = find(time == t);
        endingIndex = find(time == t + 1);
        voltage(startingIndex:endingIndex) = currVoltage;
    end
    plot(time, voltage, 'LineWidth',lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('BCM and Controllable voltage');
set(gca,'FontSize',fontSize)

%% PDM and fixed voltage
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));

figure;
for i = 1:2^k - 1
    voltage = zeros(size(time));
    t = i;
    startingIndex = find(time == t);
    endingIndex = find(time == t + 1);
    voltage(startingIndex:endingIndex) = round(rand())*5;
    plot(time, voltage, 'LineWidth',lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('PDM and Fixed voltage');
set(gca,'FontSize',fontSize)

%% PDM and LCD
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));
maxVoltage = 3.0;
figure;
for i = 1:2^k - 1
    voltage = zeros(size(time));
    currVoltage = round(rand())*maxVoltage;
    t = i;
    startingIndex = find(time == t);
    endingIndex = find(time == t + 1);
    voltage(startingIndex:endingIndex) =  currVoltage;
    plot(time, voltage, 'LineWidth',lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('PDM and LCD');
set(gca,'FontSize',fontSize)

%% BCM and controllable voltage
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));

figure;
for i = 1:2^k - 1
    voltage = zeros(size(time));
    t = i;
    startingIndex = find(time == t);
    endingIndex = find(time == t + 1);
    voltage(startingIndex:endingIndex) =  rand()*5;
    plot(time, voltage, 'LineWidth',lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('PDM and Controllable voltage');
set(gca,'FontSize',fontSize)

%% PDM and fixed voltage for value 9
k = 4;
time = 0:0.01:2^k + 1;
value = 2;
voltage = zeros(size(time));

figure;
for i = 1:2^k - 1
    voltage = zeros(size(time));
    t = i;
    startingIndex = find(time == t);
    endingIndex = find(time == t + 1);
    if(t < value)
        voltage(startingIndex:endingIndex) = 5;
    end
    plot(time, voltage, 'LineWidth',lineWidth, 'color', 'blue');
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('PDM and Fixed voltage');
set(gca,'FontSize',fontSize)

%% BCM and fixed voltage for value 9
k = 4;
time = 0:0.01:2^k + 1;
voltage = zeros(size(time));

figure;
for i = 1:k
    voltage = zeros(size(time));
    if (i == 1 || i == 4)
        currVoltage = 5;
    else
        currVoltage = 0;
    end
    for j = 1:(2^(i-1))
        t = 2^(i-1) - 1 + j;
        startingIndex = find(time == t);
        endingIndex = find(time == t + 1);
        voltage(startingIndex:endingIndex) = currVoltage;
    end
    plot(time, voltage, 'LineWidth', lineWidth);
    hold on;
end
xlim([0 17]);
ylim([0 6]);
xlabel('time');
ylabel('voltage');
title('BCM and Fixed voltage');
set(gca,'FontSize',fontSize)
