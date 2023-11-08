function getBehavData(pairNo, baseDir, outputDir)
%% Function to collect pair-level behavioral data in CommGame
%
% USAGE: getBehavData(pairNo, baseDir=pwd, outputDir=pwd)
%
% Searches for behavioral data files (pairPAIRNO_LABNAME_BGNUMBER_times.mat
% files) in "baseDir", loads them, and extracts performance-related 
% information: timing of each bargain, changes in "wealth", overall time 
% and wealth. Data is aggregated across BG games. 
%
% Inputs:
% pairNo    -  Numeric value, pair number.
% baseDir   -  Char array, path to parent directory containing behavioral data. 
%              The directory is searched recursively for the right behavioral
%              data files. Defaults to current working directory (pwd).
% outputDir -  Char array, path to output directory. Defaults to pwd.
%
%
% Outputs:
% Output is saved into a .mat file pairPAIRNO_BG_behav.mat, in "outputDir". 
% It contains the following variables:
%     filePaths  - Cell array, sized LABS X GAMES, with each cell 
%                  containing the file path to the behavioral data file 
%                  corresponding to the specific lab and game no. Labs are
%                  always {'Mordor', 'Gondor'}, in this order.
%     behavData  - Cell array, sized LABS X GAMES, with each cell
%                  containing a "behav" struct. The fields of the struct
%                  hold the behavioral data corresponding to the specific
%                  lab and game. Its fields are:
%                    startTime: Numeric value, starting time of BG,
%                               according to sharedStartTime.
%                    endTime: Numeric value, ending time of BG,
%                             according to the last flip timestamp.
%                    totalTime: Numeric value, difference of startTime and
%                               endTime.
%                    flipTimes: Numeric vector of flip timestamps.
%                    endingReq: Vector of 0-1 values, marking when the
%                               minimum requirements for ending the BG 
%                               were satisfied, one value for each flip.
%                    counterValue: Numeric vector of total value placed on
%                                  the counter at each flip.
%                    selvesValue: Numeric vector of total value placed on
%                                 the shelves at each flip.
%                    totalValue: Numeric vector of overall value on the
%                                shelves and the counter.
%
%


%% Input checks

if ~ismember(nargin, 1:3)
    error('Wrong number of input args! Input arg "pairNo" is required while "baseDir" and "outputDir" are optional.');
end
if ~ismember(pairNo, 1:999)
    error('Input arg "pairNo" should be integer in range 1:999!');
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


%% Find files

% maximum number of BG games we check for
maxGames = 20;  
% lab names in cell array
labNames = {'Mordor', 'Gondor'};
% cell array holding file paths for each lab and BG game
filePaths = cell(numel(labNames), maxGames);

% look for behavioral data files for each lab and game
for labIdx = 1 : numel(labNames)
    labName = labNames{labIdx};
    
    for bgIdx = 1 : maxGames
        
        fileName = ['pair', num2str(pairNo), '_', labName, '_BG', num2str(bgIdx), '_times.mat'];
        tmp = dir([baseDir, '/**/', fileName]); 
        if ~isempty(tmp)
            filePaths{labIdx, bgIdx} = fullfile(tmp.folder, tmp.name);
        else
            break;
        end
        
    end % for bgIdx
    
end % for labIdx

% strip potentially empty part of filePaths
filePaths(:, bgIdx:end) = [];
% last BG game number
bgEnd = bgIdx - 1;


%% Extract data

% cell array storing behavioral data
behavData = cell(size(filePaths));

% loop through labs and games
for labIdx = 1 : numel(labNames)
    for bgIdx = 1 : bgEnd
        
        behav = struct;
        
        % load data
        data = load(filePaths{labIdx, bgIdx});
        
        % start time is defined as the sharedStartTime
        startTime = data.sharedStartTime;
        
        % get number of flips and their absolute and relative timing
        flipTimes = data.flipTimeStamps(:, 1);
        lastFlip = find(isnan(flipTimes), 1) - 1;

        % total time based on flips
        endTime = flipTimes(lastFlip);
        totalTime = endTime - startTime;
        
        % timings of valid flips
        flipTimes = flipTimes(1:lastFlip);
        flipTimes = flipTimes - startTime;
        
        % get time series for clicking on ending button
        endingClick = data.flipData.endingFlagS';
        
        % time series for value on shelves, counter, and total wealth
        tokenPrices = data.gameParams.tokenPrices;
        counterStates = data.flipData.counterState(:, 1:lastFlip);
        shelvesStates = data.flipData.shelvesState(:, 1:lastFlip);
        counterValue = counterStates' * tokenPrices;  
        shelvesValue = shelvesStates' * tokenPrices;
        totalValue = shelvesValue + counterValue;
        
        % time series for having all mustHaves collected
        mustHaves = data.gameParams.mustHaves;  % array sized tokenNo * 1
        mustHavesBool = ~isnan(mustHaves); 
        endingReq = all(shelvesStates(mustHavesBool, :) >= mustHaves(mustHavesBool)); 
        
        % time series for number of bargains and their relative timing
        bargains = [0; diff(totalValue) ~= 0];
        bargainN = sum(bargains);
        bargainTimes = flipTimes(logical(bargains));
        bargainValues = totalValue(logical(bargains)) - totalValue(logical([bargains(2:end); 0]));
        
        % changes in number of mustHaves at each bargain
        bargainMustHaveChanges = shelvesStates(mustHavesBool, logical(bargains)) -  shelvesStates(mustHavesBool, logical([bargains(2:end); 0]));
        
        % store everything in the behav struct
        behav.startTime = startTime;
        behav.flipTimes = flipTimes;
        behav.endTime = endTime;
        behav.totalTime = totalTime;
        behav.endingClick = endingClick;
        behav.endingReq = endingReq';
        behav.counterValue = counterValue;
        behav.shelvesValue = shelvesValue;
        behav.counterStates = counterStates;
        behav.shelvesStates = shelvesStates;
        behav.totalValue = totalValue;
        behav.bargains = bargains;
        behav.bargainN = bargainN;
        behav.bargainTimes = bargainTimes;
        behav.bargainValues = bargainValues;
        behav.bargainMustHaveChanges = bargainMustHaveChanges;
        
        behavData{labIdx, bgIdx} = behav;
        
    end % for bgIdx
    
end % for labIdx
        
        
%% Saving results

saveFile = fullfile(outputDir, ['pair', num2str(pairNo), '_BG_behav.mat']);
save(saveFile,'filePaths', 'behavData', 'pairNo');


return

