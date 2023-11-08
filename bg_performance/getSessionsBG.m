function getSessionsBG(pairs, baseDir)


%% Input checks
if ~ismember(nargin, [1, 2])
    error('Input arg "pairs" is required while arg "baseDir" is optional!');
end
if nargin == 1
    baseDir = pwd;
else
    if ~exist(baseDir, 'dir')
        error('Input arg "baseDir" is not a valid path to a directory!');
    end
end


%% Loop through pair-specific behavioral output files, collect BG info

pairList = zeros(numel(pairs), 1);
bgValid = zeros(numel(pairs), 10);
maxGame = pairList;

pairIdx = 0;
for pairNo = pairs
    
    pairIdx = pairIdx + 1;
    
    pairFile = fullfile(baseDir, ['pair', num2str(pairNo), '_BG_behav.mat']);
    if ~exist(pairFile, 'file')
        error(['Cannot find BG behavioral file at ', pairFile]);
    end
    
    tmp = load(pairFile);
    maxBG = size(tmp.behavData, 2);
    
    pairList(pairIdx) = pairNo;
    maxGame(pairIdx) = maxBG;
    bgValid(pairIdx, 1:maxBG) = ones(1, maxBG);

end
    
    
save('BGgames.mat', 'bgValid', 'pairList', 'maxGame');

return
            


