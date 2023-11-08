function plotBehavBG(pairNo, baseDir)
%% Function to plot behavioral results from BG for a given pair
%
% USAGE: plotBehavBG(pairNo, baseDir=pwd)
%
% Data is expected to be in .mat files named "pairPAIRNO_BG_behav.mat",
% that is, the output from getBehavData.m function.
% 
% Inputs:
% pairNo  -  Numeric value, pair number.
% baseDir -  Char array, path to parent directory containing behavioral data. 
%            The directory is searched recursively for the right behavioral
%            data files. Defaults to current working directory (pwd).
%
%


%% Input checks

if ~ismember(nargin, 1:2)
    error('Wring number of input args! Input arg "pairNo" is required while "baseDir" is optional.');
end
if ~ismember(pairNo, 1:999)
    error('Input arg "pairNo" should be integer in range 1:999!');
end
if nargin == 1
    baseDir = pwd;
else
    if ~exist(baseDir, 'dir')
        error('Input arg "baseDir" is not a valid path to a directory!');
    end
end
% make sure "baseDir" ending is consistent (without separator, as with pwd)
if baseDir(end) == '/'
    baseDir = baseDir(1:end-1);
end


%% Load data

fileName = fullfile(baseDir, ['pair', num2str(pairNo), '_BG_behav.mat']);
data = load(fileName);


%% Load config stats for scaling

statsFileNameEasy = '/home/adamb/fc_real_random_adam/easyConfigsStats.mat';
statsFileNameHarder = '/home/adamb/fc_real_random_adam/harderConfigsStats.mat';
easyStats = load(statsFileNameEasy);
harderStats = load(statsFileNameHarder);

% get scaling constants
scalers = [easyStats.jointFairW(1:2, :); harderStats.jointFairW(1:5, :)];


%% Plot in a loop, one plot for each BG game

fps = 20;
colorMface = [0.3010 0.7450 0.9330];
colorMedge = [0 0.4470 0.7410];
colorGface = [0.9290 0.6940 0.1250];
colorGedge = [0.8500 0.3250 0.0980];
gcfColor = [1 1 1];
gcfMainPos = [0.2, 0.25, 0.8, 0.75];

bgEnd = size(data.behavData, 2);

for bgIdx = 1:bgEnd
% for bgIdx = 1
    
    saveFileFig = fullfile(baseDir, ['pair', num2str(pairNo), '_BG', num2str(bgIdx), '_behav_plot.png']);
    
    behavM = data.behavData{1, bgIdx};
    behavG = data.behavData{2, bgIdx};
    
    % there could be very small differences across timings
    pairTotalTime = floor(min(behavM.totalTime, behavG.totalTime));
%    pairFlipNo = min(size(behavM.flipTimes, 1), size(behavG.flipTimes, 1));

    % common timeline with 50 fps, starting after the first second elapsed    
    commonTimes = 1 : 1/fps : pairTotalTime;
    frameNo = numel(commonTimes);
    
    % get indices from both data sets that are closest to the common
    % timeline
    behavMi= zeros(frameNo, 1);
    behavGi= zeros(frameNo, 1);
    for f = 1:frameNo
        [~, behavMi(f)] = min(abs(behavM.flipTimes-commonTimes(f)));
        [~, behavGi(f)] = min(abs(behavG.flipTimes-commonTimes(f)));
    end
        
%    % check flip differences
%    hist(behavM.flipTimes(behavMi)-behavG.flipTimes(behavGi), 50)
    
    % rescale values and use new indices
%     totalVM = behavM.totalValue(behavMi);
%     startValueM = totalVM(1);
%     totalVM = (totalVM./startValueM)*100;
%     totalVG= behavG.totalValue(behavGi);
%     startValueG = totalVG(1);
%     totalVG = (totalVG./startValueG)*100;
    % use "scaler", a value from the analysis of each game corresponding a
    % type of maximum achievable value
    totalVM = behavM.totalValue(behavMi);
    startValueM = totalVM(1);
    totalVM = (totalVM./scalers(bgIdx, 1))*100;
    totalVG= behavG.totalValue(behavGi);
    startValueG = totalVG(1);
    totalVG = (totalVG./scalers(bgIdx, 2))*100;


    % offer on counter
    counterValueM = behavM.counterValue(behavMi);
    counterValueG = behavG.counterValue(behavGi);
    counterVM = (counterValueM./scalers(bgIdx, 1))*100;
    counterVG = (counterValueG./scalers(bgIdx, 2))*100;
    
    % requirements set
    reqM = behavM.endingReq(behavMi);
    reqG = behavG.endingReq(behavGi);
    reqMstart = find(reqM, 1);
    reqGstart = find(reqG, 1);
    
    % scale 
    scaleMax = max(max(totalVM), max(totalVG));
    yscale = [-scaleMax*1.15, scaleMax*1.15];
    
    
    %% Plot with area
    
    myFig = figure;
    % set figure size and background color
    set(gcf, 'Units', 'Normalized', 'OuterPosition', gcfMainPos);
    set(gcf, 'Color', gcfColor);
    
    ax1 = area(commonTimes, totalVM, 'FaceColor', colorMface, 'EdgeColor', colorMedge, ...
        'LineStyle', '-', 'LineWidth', 2, 'FaceAlpha', 0.5);
    hold on;
    ax2 = area(commonTimes, -totalVG, 'FaceColor', colorGface, 'EdgeColor', colorGedge, ...
        'LineStyle', '-', 'LineWidth', 2, 'FaceAlpha', 0.5);    

    % add counters as line plots
    plot(commonTimes, counterVM, 'b', 'LineWidth', 1.5);  
    plot(commonTimes, -counterVG, 'r', 'LineWidth', 1.5);
    
    % add requirements set stage as shaded area
    area(commonTimes, reqM*max(yscale), 'FaceColor', colorMface./1.5, 'EdgeColor', [1 1 1], 'LineStyle', 'None', 'FaceAlpha', 0.4);
    area(commonTimes, -reqG*max(yscale), 'FaceColor', colorGface./1.5, 'EdgeColor', [1 1 1], 'LineStyle', 'None', 'FaceAlpha', 0.4);
    
    % axis limits
    ylim(yscale);
    xlim([1, pairTotalTime+5]);
    
    % annotations
    annotation('textbox', [0.83, 0.65, 0.05, 0.04], 'String', [num2str(totalVM(end)), '%'], 'EdgeColor', colorMedge);
    annotation('textbox', [0.83, 0.345, 0.05, 0.04], 'String', [num2str(totalVG(end)), '%'], 'EdgeColor', colorGedge);
    annotation('textbox', [0.17, 0.65, 0.05, 0.04], 'String', [num2str(totalVM(1)), '%'], 'EdgeColor', colorMedge);
    annotation('textbox', [0.17, 0.345, 0.05, 0.04], 'String', [num2str(totalVG(1)), '%'], 'EdgeColor', colorGedge);
    
    
    % title and labels
    title(['Pair ', num2str(pairNo), ', game ', num2str(bgIdx)]);
    xlabel('Time (s)');
    ylabel('% of maximum value');

    % font sizes, appearance
    set(gca, 'Fontsize', 12);
    
    saveas(myFig, saveFileFig);

    
end % for bgIdx









