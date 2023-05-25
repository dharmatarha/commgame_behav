function audioRepair(inputDir, pairNo, timeDiffThr, missingSampleThr, samplingTol, fs)
%% Function to repair buffer underflow errors and bad sampling rates
%
% USAGE: audioRepair(inputDir,
%                    pairNo,
%                    timeDiffThr=0.020,
%                    missingSampleThr=225,
%                    samplingTol=0.5,
%                    fs=44100)
%
% Two types of audio recording problems are mitigated by the function:
%
% (1) When a buffer underflow occured, we see the details of the missing
% portion from the audio status parameters saved out during the task. Such
% missing segments are recovered (injected) as segments filled with silence.
% This behavior is controlled by input args "timeDiffThr" and 
% "missingSampleThr".
%
% (2) Sampling rates are not fully consistent across different sound cards
% used and might show deviations from nominal sampling rate. Such problems
% are detected and the recorded audio resampled if necessary. The maximum
% tolerated deviation from nominal sampling rate is controlled by
% input arg "samplingTol". 
%
% Audio recordings are also aligned to a common start time
% "sharedStartTime" loaded from recording-specific .mat files.
%
% Mandatory inputs:
% inputDir   - Char array, path to folder holding pair-level data. The
%              folder is searched recursively for the right files.
% pairNo     - Numeric value, pair number, one of 1:99.
% 
% Optional inputs:
% timeDiffThr      - Time difference threshold between subsequent audio 
%                    packets in seconds. If the recording times of
%                    subsequent packets  differ more than this threshold,
%                    there could have beena buffer underflow event, and 
%                    the packets are flagged for a further check based on 
%                    "missingSampleThr". Defaults to 0.02 (20 msec),
%                    roughly double the "normal" audio packet size.
% missingSampleThr - Threshold for the number of "missing" audio frames
%                    after a temporal deviation (time difference, see 
%                    "timeDiffThr") is detected. If the threshold is reached,
%                    a silent (zero-filled) segment is inserted for the 
%                    missing segment. Defaults to 225, corrresponding to
%                    missing data of 5 msec at 44.1 kHz.
% samplingTol      - Tolerance for deviation from nominal sampling rate
%                    (see "fs") in Hz, defaults to 0.5.
% fs               - Sampling rate in Hz. Defaults to 44100.
%
% The outputs are the edited, synched audio files at:
% inputDir/pair[pairNo]_Mordor_freeConv_audio_repaired.wav
% inputDir/pair[pairNo]_Gondor_freeConv_audio_repaired.wav
%
%
% Notes:
%
% 2023.05.


%% Input checks

if ~ismember(nargin, 2:6)
    error('Input args inputDir and pairNo are required while timeDiffThr, missingSampleThr, samplingTol and fs are optional!');
end
if nargin < 6 || isempty(fs)
    fs = 44100;
end
if nargin < 5 || isempty(samplingTol)
    samplingTol = 0.5;
end
if nargin < 4 || isempty(missingSampleThr)
    missingSampleThr = 225;
end
if nargin < 3 || isempty(timeDiffThr)
    timeDiffThr = 0.02;
end

disp([char(10), 'Called audioRepair with input args:',...
    char(10), 'Input dir: ', inputDir, ...
    char(10), 'Pair number: ', num2str(pairNo), ...
    char(10), 'Time difference threshold: ', num2str(timeDiffThr*1000), ' ms', ...
    char(10), 'Missing sample threshold: ', num2str(missingSampleThr), ' frames', ...
    char(10), 'Sampling rate deviation tolerance: ', num2str(samplingTol), ' Hz', ...
    char(10), 'Nominal sampling rate: ', num2str(fs), ' Hz']);


%% Find pair-specific -mat and .wav files

mordorfiles = struct; gondorfiles = struct; 

% audio wav and mat files for Mordor lab
tmpwav = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_audio.wav']);
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_audio.mat']);
mordorfiles.audiowav = fullfile(tmpwav(1).folder, tmpwav(1).name);
mordorfiles.audiomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

% audio wav and mat files for Gondor lab
tmpwav = dir([inputDir, '**/pair', num2str(pairNo), '_Gondor_freeConv_audio.wav']);
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Gondor_freeConv_audio.mat']);
gondorfiles.audiowav = fullfile(tmpwav(1).folder, tmpwav(1).name);
gondorfiles.audiomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

% video timestamps
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_videoTimes.mat']);
mordorfiles.videomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

disp('Found relevant files:');
disp(mordorfiles);
disp(gondorfiles);


%% Extract all relevant timestamps

% VIDEO
% Get shared start time
tmp = load(mordorfiles.videomat);
sharedStartTime = tmp.sharedStartTime;

% AUDIO
% timestamps of first recorded audio frames
tmp = load(mordorfiles.audiomat);
audioStart.mordor = tmp.perf.firstFrameTiming;
tstats.mordor = tmp.perf.tstats;
tmp = load(gondorfiles.audiomat);
audioStart.gondor = tmp.perf.firstFrameTiming;
tstats.gondor = tmp.perf.tstats;

disp('Extracted relevant timestamps and audio recording metadata');


%% Find underflows in audio channels, based on audio frame timing

% Correct for missing audio packets (occasional underflows) that 
% correspond to jumps in stream timings without audio data 
% First, detect "jumps", that is, audio frames where there is a 
% "large" change in streaming time from frame to frame, while the number of 
% elapsed samples does not match it.

audioRepair = struct;
audioRepair.mordor = [];
audioRepair.gondor = [];
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    audioTimes = tstats.(lab)(2, :)';
    elapsedSamples = tstats.(lab)(1, :)';
    suspectFrames = find(diff(audioTimes) > timeDiffThr);
    counter = 1;
    % check each suspect audioframe for skipped material
    if ~isempty(suspectFrames)
        
        for i = 1:length(suspectFrames)
            timingDiff = audioTimes(suspectFrames(i)+1) - audioTimes(suspectFrames(i));
            sampleDiff = elapsedSamples(suspectFrames(i)+1) - elapsedSamples(suspectFrames(i));
            expectedSamples = timingDiff*fs;
            if expectedSamples - sampleDiff > missingSampleThr
               audioRepair.(lab)(counter, 1:2) = [suspectFrames(i), expectedSamples-sampleDiff];
               counter = counter + 1;
            end
        end  % for i
        
    end  % if ~isempty 
    
end  % for lab

disp('Checked for missing samples (underflows)');
disp(['For Mordor, there were ', num2str(size(audioRepair.mordor, 1)), ' suspected events']);
disp(['For Gondor, there were ', num2str(size(audioRepair.gondor, 1)), ' suspected events']);


%% Load audio

audioData = struct;
[audioData.mordor, tmp] = audioread(mordorfiles.audiowav); 
if tmp ~= fs
    error(['Unexpected sampling freq (', num2str(tmp), ') in audio file at ', mordorfiles.audiowav ]);
end
[audioData.gondor, tmp] = audioread(gondorfiles.audiowav); 
if tmp ~= fs
    error(['Unexpected sampling freq (', num2str(tmp), ') in audio file at ', gondorfiles.audiowav ]);
end
% sanity check - audio recordings must have started before video stream
if audioStart.mordor >= sharedStartTime || audioStart.gondor >= sharedStartTime
    error("Insane audio versus task and video start times!");
end

disp('Loaded audio files');


%% Repair loaded audio for missing frames (underflows)

for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    
    if ~isempty(audioRepair.(lab))
        elapsedSamples = tstats.(lab)(1, :)';
        
        % for inserting audio samples, do it in reverse order, otherwise 
        % the indices get screwed
        for i = size(audioRepair.(lab), 1):-1:1
            % sample to insert silence at
            startSample = elapsedSamples(audioRepair.(lab)(i, 1) + 1);
            % define silence (zeros)
            silentFrame = zeros(round(audioRepair.(lab)(i, 2)), 2);
            % special rule for inserting silent frames when those would be at the very end, 
            % potentially out of bounds of recorded audio
            if startSample > size(audioData.(lab), 1) + 1
                audioData.(lab) = [audioData.(lab); silentFrame];
            % otherwise we insert silent frames to their expected location
            else
                audioData.(lab) = [audioData.(lab)(1:startSample, 1:2); silentFrame; audioData.(lab)(startSample+1:end, 1:2)];
            end
        end  % for i
        
    end  % if ~isempty
    
end  % for lab

disp('Inserted silent frames for detected underflow events');


%% Estimate real (empirical) sampling frequency 

% MORDOR
% estimate sampling frequency based on the size of the (repaired) audio
% data and the total time elapsed while recording
streamTimesM = tstats.mordor(2, :)';
totalSamplesM =size(audioData.mordor, 1);
totalTimeM = streamTimesM(end)-streamTimesM(1);
fsEmpMordor = totalSamplesM/totalTimeM;
disp(['Estimated sampling frequency for Mordor audio: ',... 
    num2str(fsEmpMordor), ' Hz']);

% GONDOR
streamTimesG = tstats.gondor(2, :)';
totalSamplesG =size(audioData.gondor, 1);
totalTimeG = streamTimesG(end)-streamTimesG(1);
fsEmpGondor = totalSamplesG/totalTimeG;
disp(['Estimated sampling frequency for Gondor audio: ',... 
    num2str(fsEmpGondor), ' Hz']);


%% Resample audio channels, if needed

% MORDOR
if abs(fsEmpMordor - fs) > samplingTol
    tx = 0:1/fsEmpMordor:totalTimeM;
    data = audioData.mordor;
    % due to numeric errors there could be a slight mismatch between audio
    % frames and corresponding timestamps - check for discrepancy
    if numel(tx) ~= size(data, 1)
        % report if the difference is too large
        if abs(numel(tx) ~= size(data, 1)) > 2
            disp(['WARNING! At the resampling step for Mordor, audio data size is ',... 
                num2str(size(data, 1)), ' while estimated time points is a vector of length ',... 
                num2str(numel(tx)), '!']);
        end
        tx = tx(1:size(data, 1));
    end
    newFs = fs;
    resampledDataMordor = resample(data, tx, newFs);
    disp(['Resampled Mordor audio to nominal (', num2str(fs),... 
        ' Hz) sampling frequency']);
    audioData.mordor = resampledDataMordor;
end

% GONDOR
if abs(fsEmpGondor - fs) > samplingTol
    tx = 0:1/fsEmpGondor:totalTimeG;
    data = audioData.gondor;
    % due to numeric errors there could be a slight mismatch between audio
    % frames and corresponding timestamps - check for discrepancy    
    if numel(tx) ~= size(data, 1)
        % report if the difference is too large
        if abs(numel(tx) ~= size(data, 1)) > 2
            disp(['WARNING! At the resampling step for Gondor, audio data size is ',... 
                num2str(size(data, 1)), ' while estimated time points is a vector of length ',... 
                num2str(numel(tx)), '!']);
        end        
        tx = tx(1:size(data, 1));
    end
    newFs = fs;
    resampledDataGondor = resample(data, tx, newFs);
    disp(['Resampled Gondor audio to nominal (', num2str(fs),... 
    ' Hz) sampling frequency']);
    audioData.gondor = resampledDataGondor;
end


%% Edit audio to common start:
% Both channels are trimmed so that they start from sharedStartTime and end
% when the shorter of the two audio recordings ended.
% Since sampling frequency issues are already fixed at this point, we
% assume that sampling frequency = fs, and use that for trimming

% trim from start and end
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    startDiff = sharedStartTime - audioStart.(lab);
    audioData.(lab) = audioData.(lab)(round(startDiff*fs)+1 : end, :);
end
disp('Trimmed both audio channels to video start');

% turn to mono and normalize intensity
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    audioData.(lab) = mean(audioData.(lab), 2);
    audioData.(lab) = (audioData.(lab) / max(audioData.(lab))) * 0.99;
end
disp('Audio channels are set to mono and normalized');

% check length, there might be a difference still
if length(audioData.mordor) ~= length(audioData.gondor)
    lm = length(audioData.mordor);
    lg = length(audioData.gondor);
    if lm < lg
        audioData.gondor = audioData.gondor(1:lm);
    elseif lm > lg
        audioData.mordor = audioData.mordor(1:lg);
    end
    disp('Audio channel length values adjusted (trimmed to the shorter)');
end


%% save audio files

% output paths
outputAudioMordor = fullfile(inputDir, ['pair', num2str(pairNo), '_Mordor_freeConv_repaired_mono.wav']);
outputAudioGondor = fullfile(inputDir, ['pair', num2str(pairNo), '_Gondor_freeConv_repaired_mono.wav']);

audiowrite(outputAudioMordor, audioData.mordor, fs);
disp('Mordor audio saved out to:');
disp(outputAudioMordor);
audiowrite(outputAudioGondor, audioData.gondor, fs);
disp('Gondor audio saved out to:');
disp(outputAudioGondor);

return

