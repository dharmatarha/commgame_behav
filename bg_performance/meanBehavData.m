function meanBehavData(pairList, baseDir, outputDir)
%% Function to gather pair-level behavioral data together
%
% USAGE: meanBehavData(pairList, baseDir, outputDir)
%
% Searches for pair-level behavioral data files (pairXX_BG_behav.mat
% files) in "baseDir", loads them, and collects performance-related 
% information for the sample defined in "pairList". 
%
% Inputs:
% pairNo    -  Numeric vector containing pair numbers that define the sample.
% baseDir   -  Char array, path to parent directory containing pair-level 
%              behavioral data. Defaults to current working directory (pwd).
% outputDir -  Char array, path to output directory. Defaults to pwd.
%
%


%% Input checks

if ~ismember(nargin, 1:3)
    error('Wrong number of input args! Input arg "pairList" is required while "baseDir" and "outputDir" are optional.');
end
if ~isvector(pairList)
    error('Input arg "pairList" should be a vector!');
end
if nargin == 1
    baseDir = pwd;
    outputDir = pwd;
elseif nargin == 2
    outputDir = pwd;
    if ~exist(baseDir, 'dir')
        error('Input arg "baseDir" is not a valid path to a directory!');
    end
elseif nargin == 3
    if ~exist(baseDir, 'dir')
        error('Input arg "baseDir" is not a valid path to a directory!');
    end
    if ~exist(outputDir, 'dir')
        error('Input arg "outputDir" is not a valid path to a directory!');
    end    
end
% make sure "baseDir" and "outputDir" ending is consistent (without separator, as with pwd)
if baseDir(end) == '/'
    baseDir = baseDir(1:end-1);
end
if outputDir(end) == '/'
    outputDir = outputDir(1:end-1);
end


%% Define files to load

sampleSize = numel(pairList);
pairFiles = cell(sampleSize, 1);

for pairIdx = 1:sampleSize
    pairNo = pairList(pairIdx);
    pairFiles{pairIdx} = fullfile(baseDir, ['pair', num2str(pairNo), '_BG_behav.mat']);
    if ~exist(pairFiles{pairIdx}, 'file')
        error(['Cannot find behav file for pair ', num2str(pairNo), ' at ', pairFiles{pairIdx}]);
    end
end


%% Load config stats for scaling

statsFileNameEasy = '/home/adamb/fc_real_random_adam/easyConfigsStats.mat';
statsFileNameHarder = '/home/adamb/fc_real_random_adam/harderConfigsStats.mat';
easyStats = load(statsFileNameEasy);
harderStats = load(statsFileNameHarder);

% get scaling constants
scalersInit = [easyStats.initW(1:2, :); harderStats.initW(1:6, :)];
scalersMax = [easyStats.jointMaxW(1:2, :); harderStats.jointMaxW(1:6, :)];
scalersFair = [easyStats.jointFairW(1:2, :); harderStats.jointFairW(1:6, :)];
% scalersEqual = [easyStats.equalityMaxW(1:2, :); harderStats.equalityMaxW(1:6, :)];


%% Load files, aggregate data

maxBG = 10;
labs = 2;
maxGame = nan(sampleSize, 1);
totalTime = nan(sampleSize, maxBG);
mustHavesTime = nan(sampleSize, maxBG, labs);
endingW = nan(sampleSize, maxBG, labs);
wScaledMax = nan(sampleSize, maxBG, labs);
wScaledFair = nan(sampleSize, maxBG, labs);
% wScaledEqual = nan(sampleSize, maxBG, labs);
wScaledInit = nan(sampleSize, maxBG, labs);

% params for mean plotting
fps = 50;

totalValueInterp = nan(sampleSize, maxBG, labs, 10001);
counterValueInterp = nan(sampleSize, maxBG, labs, 10001);
reqInterp = nan(sampleSize, maxBG, labs, 10001);
reqInterpStart = nan(sampleSize, maxBG, labs, 10001);


% pairs
for pairIdx = 1:sampleSize
    
    tmp = load(pairFiles{pairIdx});
    
    maxGame(pairIdx) = size(tmp.behavData, 2);
    
    % BG games
    for bgIdx = 1: maxGame(pairIdx)
    
        behavM = tmp.behavData{1, bgIdx};
        behavG = tmp.behavData{2, bgIdx};

        % there could be very small differences across timings
        totalTime(pairIdx, bgIdx) = (min(behavM.totalTime, behavG.totalTime));

        % mustHaves
        reqM = behavM.endingReq;
        reqG = behavG.endingReq;
        reqMStart = find(reqM, 1);
        reqGStart = find(reqG, 1);
        if ~isempty(reqMStart)
            mustHavesTime(pairIdx, bgIdx, 1) = behavM.flipTimes(reqMStart);
        end
        if ~isempty(reqGStart)    
            mustHavesTime(pairIdx, bgIdx, 2) = behavG.flipTimes(reqGStart);  
        end
        
        % wealth at the end of each game
        endingW(pairIdx, bgIdx, 1) = behavM.totalValue(end);
        endingW(pairIdx, bgIdx, 2) = behavG.totalValue(end);
        
        % scaled wealth
        wScaledInit(pairIdx, bgIdx, 1:2) = squeeze(endingW(pairIdx, bgIdx, 1:2)) ./ scalersInit(bgIdx, 1:2)';
        wScaledMax(pairIdx, bgIdx, 1:2) = squeeze(endingW(pairIdx, bgIdx, 1:2)) ./ scalersMax(bgIdx, 1:2)';
        wScaledFair(pairIdx, bgIdx, 1:2) = squeeze(endingW(pairIdx, bgIdx, 1:2)) ./ scalersFair(bgIdx, 1:2)';
%         wScaledEqual(pairIdx, bgIdx, 1:2) = squeeze(endingW(pairIdx, bgIdx, 1:2)) ./ scalersEqual(bgIdx, 1:2)';
        

        % for plotting
        
        % common timeline with 50 fps, starting after the first second elapsed   
        pairTotalTime = floor(min(behavM.totalTime, behavG.totalTime));
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

        totalVM = behavM.totalValue(behavMi);
        totalVG= behavG.totalValue(behavGi);

        % offer on counter
        counterVM = behavM.counterValue(behavMi);
        counterVG = behavG.counterValue(behavGi);

        % requirements set
        reqM = behavM.endingReq(behavMi);
        reqG = behavG.endingReq(behavGi);
        reqMstart = find(reqM, 1);
        reqGstart = find(reqG, 1);

        % standardized times
        standTimes = commonTimes/pairTotalTime;
        interpTimes = 0:0.0001:1;
        
        % interpolated wealth, offer and requirements (mustHaves) values
        totalValueInterp(pairIdx, bgIdx, 1, :) = interp1(standTimes, totalVM, interpTimes, 'linear');
        totalValueInterp(pairIdx, bgIdx, 2, :) = interp1(standTimes, totalVG, interpTimes, 'linear');
        counterValueInterp(pairIdx, bgIdx, 1, :) = interp1(standTimes, counterVM, interpTimes, 'linear');
        counterValueInterp(pairIdx, bgIdx, 2, :) = interp1(standTimes, counterVG, interpTimes, 'linear');
        reqInterp(pairIdx, bgIdx, 1, :) = interp1(standTimes, double(reqM), interpTimes, 'linear');
        reqInterp(pairIdx, bgIdx, 2, :) = interp1(standTimes, double(reqG), interpTimes, 'linear');
        reqInterpStart(pairIdx, bgIdx, 1, :) = find(reqInterp, 1);
        reqInterpStart(pairIdx, bgIdx, 2, :) = find(reqInterp, 1);


    end
    
end


%% Get average for plotting

meanTotalV = nan(maxBG, 2, 10001);
meanCounterV = nan(maxBG, 2, 10001);
meanReq = nan(maxBG, 2, 10001);

for bgIdx = 1:maxBG
    
    pairMask = maxGame >= bgIdx;
    
    totalV = squeeze(totalValueInterp(pairMask, bgIdx, :, :));
    meanTotalV(bgIdx, :, :) = squeeze(mean(totalV, 1));

    counterV = squeeze(counterValueInterp(pairMask, bgIdx, :, :));
    meanCounterV(bgIdx, :, :) = squeeze(mean(totalV, 1));

    req = squeeze(reqInterp(pairMask, bgIdx, :, :));
    meanReq(bgIdx, :, :) = squeeze(mean(req, 1));


end


%% save, end

saveFile = fullfile(outputDir, ['pair', num2str(pairList(1)), '_', num2str(pairList(end)), '_BG_behav_sample.mat']);

save(saveFile);






