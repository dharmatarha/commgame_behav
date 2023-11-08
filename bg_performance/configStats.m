% load configs
label = 'easy';
%label = 'harder';

confFile = ['/home/adamb/commgame_experiment/exp/', label, 'Configs.mat'];
tmp = load(confFile);
if strcmp('easy', label)
    configs = tmp.easyConfigs;
elseif strcmp('harder', label)
    configs = tmp.harderConfigs;
end
confNo = size(configs, 2);
tokenNo = size(configs(1).tokens, 1);


%% Get initial wealth for all configs

initW = nan(confNo, 2);
for c = 1:confNo
    tmp = configs(c).tokens'*configs(c).prices;
    initW(c, :) = [tmp(1, 1), tmp(2, 2)];
end


%% Get token distributions and wealth after mustHaves are exchanged

tokensAfter = nan(confNo, size(configs(1).tokens, 1), 2);
afterW = nan(confNo, 2);
for c = 1:confNo
    mustBargain = configs(c).mustHaves-configs(c).tokens;  % tokens players need to obtain from the other player
    mustBargain(isnan(mustBargain)) = 0;
    tokensAfter(c, :, :) = configs(c).tokens+mustBargain-[mustBargain(:,2), mustBargain(:,1)];  % distribution of tokens after exchanging must-have tokens
    tmp = squeeze(tokensAfter(c, :, :))'*configs(c).prices;
    afterW(c, :) = [tmp(1, 1), tmp(2, 2)];
end

afterWdiff = afterW - initW;


%% Get exchange opportunities after mustHaves are exchanged

tokensRest = tokensAfter;
pwg = nan(confNo, 2);
pwl = nan(confNo, 2);

for c = 1:confNo
    
    % get the tokens one might exchange (not "mustHave" tokens)
    mustBargain = configs(c).mustHaves;
    mustBargain(isnan(mustBargain)) = 0;
    availTokens = squeeze(tokensRest(c, :, :)) - mustBargain;  % available tokens for bargains
    
    % get the price differences across players
    configPrices = configs(c).prices;
    priceDiffs = configPrices(:, 1) - configPrices(:, 2);
    
    % Derive PWG (= potential wealth flow) and PWL (= potential wealth
    % loss)
    mask1 = priceDiffs > 0;  % mask for larger prices for player 1 
    mask2 = priceDiffs < 0;  % mask for larger prices for player 2

    pwg(c, 1) = dot(availTokens(mask1, 2), configPrices(mask1, 1));  % potential wealth gain for player 1 if all tokens with larger player 1 prices were given to her
    pwl(c, 2) = dot(availTokens(mask1, 2), configPrices(mask1, 2));  % potential wealth loss for player 2 if all tokens with larger player 1 prices were given to player 1
    pwg(c, 2) = dot(availTokens(mask2, 1), configPrices(mask2, 2));  % potential wealth gain for player 2 if all tokens with larger player 2 prices were given to her
    pwl(c, 1) = dot(availTokens(mask2, 1), configPrices(mask2, 1));  % potential wealth loss for player 1 if all tokens with larger player 2 prices were given to player 2
    
    % store bargainable tokens in a var for each config
    tokensRest(c, :, :) = availTokens;
    
end


%% Get markers of bargaining success and behavior

% Net gain for both players if all tradeable / bargainable tokens were
% exchanged in a value maximization step
gainLossDiff = nan(confNo, 2);
gainLossDiff(:, 1) = pwg(:, 1) - pwl(:, 1);
gainLossDiff(:, 2) = pwg(:, 2) - pwl(:, 2);
 
% maximally efficient allocation for total (joint, pair-level wealth) after mustHaves exchange        
jointMaxWealth = afterW + gainLossDiff; 

% difference of maximally efficient allocation  and initial wealth
jointMaxWealthInitDiff = jointMaxWealth - initW;    
% difference of maximally efficient allocation  and mushtHaves exchange wealth
jointMaxWealthAfterDiff = jointMaxWealth - afterW; 

% if maximally efficient allocation is simply distributed, creating equal
% wealth at the end
jointMaxWealthEqual = [mean(jointMaxWealth, 2), mean(jointMaxWealth, 2)];

% if maximally efficient allocation is distributed equally, relative
% to initial wealth
jointMaxWealthEqualInit = [mean(jointMaxWealthInitDiff, 2), mean(jointMaxWealthInitDiff, 2)] + initW;

% if maximally efficient allocation is distributed equally, relative
% to after mustHaves exchange wealth
jointMaxWealthEqualAfter = [mean(jointMaxWealthAfterDiff, 2), mean(jointMaxWealthAfterDiff, 2)] + initW;
 

    

savef = ['/home/adamb/fc_real_random_adam/', label, 'ConfigsStats.mat'];
save(savef);
    
    
    
        
