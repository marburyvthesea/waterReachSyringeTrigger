%% arduino parameters
port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
%%
trialLength = 5;                           % individual trial length (seconds)
expLengthMins = 55;
%% start video acquisition then trigger syringe pump
%% start video acquisition then trigger syringe pump (with random reward schedule + per-trial logging)

% --------------------
% Session Params
% --------------------
videoFolder = 'F:\WaterReachData\11112025';
timestamp = datestr(now, 'mm_dd_yy_HH_MM_SS');
mouseID = ['m3_2_t1_rr60' timestamp];

% Trial timing (edit as needed)
if ~exist('expLengthMins','var'),  expLengthMins = 1;  end   % total experiment length (minutes)
if ~exist('trialLength','var'),    trialLength   = 30; end   % each trial length (seconds)

% Random-reward parameter X% (deliver only after a previous success, with probability X)
rewardPercentDelivered = 60;                      % e.g., 60 means deliver on 60% of post-success trials
rewardProb = max(0, min(1, rewardPercentDelivered/100));
rng('shuffle');                                   % randomize once per session

% --------------------
% Paths
% --------------------
newDirectory = fullfile(videoFolder, mouseID);
if ~exist(newDirectory,'dir'); mkdir(newDirectory); end
file_cam1 = fullfile(newDirectory, [mouseID '_cam1.avi']);
file_cam2 = fullfile(newDirectory, [mouseID '_cam2.avi']);

% --------------------
% Camera setup (two devices: 3 and 4)
% --------------------
fmt       = 'Y800_640x480';
fps_str   = '113.9303';         % requested camera FPS (string for winvideo)
fps_writer= 113;                % VideoWriter nominal rate

vid1 = videoinput('winvideo', 3, fmt);
vid2 = videoinput('winvideo', 4, fmt);

src1 = getselectedsource(vid1);
src2 = getselectedsource(vid2);
src1.FrameRate = fps_str;
src2.FrameRate = fps_str;

% If your driver exposes flips; keep or remove as needed
try, set(src2, 'VerticalFlip', 'on'); catch, end

% Log directly to disk in the background
vw1 = VideoWriter(file_cam1, 'Motion JPEG AVI'); vw1.Quality = 75; vw1.FrameRate = fps_writer;
vw2 = VideoWriter(file_cam2, 'Motion JPEG AVI'); vw2.Quality = 75; vw2.FrameRate = fps_writer;

set(vid1, 'LoggingMode','disk', 'DiskLogger',vw1, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger',Inf);
set(vid2, 'LoggingMode','disk', 'DiskLogger',vw2, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger',Inf);

triggerconfig(vid1,'immediate');
triggerconfig(vid2,'immediate');

open(vw1); open(vw2);
preview(vid1); preview(vid2);
start([vid1 vid2]);
disp('Video recording started on both cameras.');

% --------------------
% Experiment state & logging
% --------------------
trialStartTimestamps = {};           % timestamps when each trial starts (once per trial)
beamBreakTimestamps  = {};           % timestamps when beam indicates success (Unbroken)

delta     = expLengthMins * 60 / 86400;
startTime = now;
currTrial = 1;

% Random-reward state
lastTrialOutcome = 'none';           % 'success' | 'fail' | 'none' (for trial 1)
totalRewardDeliveries = 0;           % number of pump+buzzer decisions
totalRewardOmissions  = 0;           % number of buzzer-only decisions

% Per-trial reward schedule logging (aligned by trial index)
decisionDeliver       = [];          % 1=deliver, 0=omit
decisionPrevOutcome   = strings(0);  % "success" | "fail" | "none"
decisionReason        = strings(0);  % human-readable reason
decisionRandU         = [];          % rand draw when prev==success; NaN otherwise
decisionActualOutcome = strings(0);  % "success" | "fail"
decisionTrialStartTs  = datetime.empty(0,1);  % trial start timestamp for each trial

% --------------------
% Trial loop
% --------------------
while now < (startTime + delta)

    % Decide reward for THIS trial based on previous outcome
    if currTrial == 1
        deliverThisTrial = true;                  % always deliver on the first trial
        reason           = "first trial";
        prevOutcomeForLog= "none";
        u                = NaN;
    elseif strcmpi(lastTrialOutcome,'success')
        u                = rand;
        deliverThisTrial = (u <= rewardProb);     % X% delivery after success
        if deliverThisTrial
            reason = "post-success: deliver";
        else
            reason = "post-success: omission";
        end
        prevOutcomeForLog= "success";
    elseif strcmpi(lastTrialOutcome,'fail')
        deliverThisTrial = false;                 % 0% delivery after failure
        reason           = "post-failure: omission";
        prevOutcomeForLog= "fail";
        u = NaN;
    else
        deliverThisTrial = true;                  % safety default
        reason           = "default";
        prevOutcomeForLog= string(lastTrialOutcome);
        u = NaN;
    end

    % Execute Arduino action based on decision
    if deliverThisTrial
        totalRewardDeliveries = totalRewardDeliveries + 1;
        write(arduinoSerial, '1', 'char');        % '1' = pump + buzzer
    else
        totalRewardOmissions  = totalRewardOmissions  + 1;
        write(arduinoSerial, '2', 'char');        % '2' = buzzer only
    end
    fprintf('[Trial %d] Decision: %s\n', currTrial, reason);

    % Optional inter-action pause
    pause(10);

    % Start-of-trial timestamp (once per trial) and log it
    tsNow = datetime('now');
    trialStartTimestamps{end+1} = tsNow;
    decisionTrialStartTs(currTrial,1) = tsNow;

    tic;  % start per-trial timer

    % Trial wait with UI servicing for preview windows
    if now < (startTime + delta)
        disp('Starting trial pause:');
        startPauseTime = tic;
        pause(0.01); drawnow limitrate nocallbacks;
        while toc(startPauseTime) < trialLength
            pause(0.01); drawnow limitrate nocallbacks;
            if mod(round(toc(startPauseTime)), 5) == 0
                fprintf('Elapsed: %.2f s | Remaining: %.2f s\n', ...
                        toc(startPauseTime), max(trialLength - toc(startPauseTime), 0));
                pause(1);
            end
        end
    end

    % Beam read / success logic
    sCheck = "Unbroken";               % success condition (drop removed)
    disp('reading beam');
    write(arduinoSerial, 's', 'char'); pause(1);

    if arduinoSerial.NumBytesAvailable > 0
        disp('is broken?');
        rawData = strtrim(readline(arduinoSerial));
        disp(['Raw data: ', rawData]);

        irBeam = regexprep(strtrim(rawData), '[^a-zA-Z]', '');  % keep letters only
        disp(['Cleaned data: ', irBeam]);

        if strcmp(sCheck, irBeam)
            beamBreakTimestamps{end+1} = datetime('now');
            disp(strcat("trial ", num2str(currTrial), ": SUCCESS ", num2str(toc)));
            lastTrialOutcome = 'success';
            decisionActualOutcome(currTrial,1) = "success";
        else
            disp(strcat("trial ", num2str(currTrial), ": FAILED"));
            lastTrialOutcome = 'fail';
            decisionActualOutcome(currTrial,1) = "fail";
        end

        flush(arduinoSerial);
        % Store decision info aligned to this trial index
        decisionDeliver(     currTrial,1) = double(deliverThisTrial);
        decisionPrevOutcome( currTrial,1) = prevOutcomeForLog;
        decisionReason(      currTrial,1) = reason;
        decisionRandU(       currTrial,1) = u;

        currTrial = currTrial + 1;

    else
        disp('did not read beam');
        flush(arduinoSerial);

        % Treat as failure; still log decision for this trial
        lastTrialOutcome = 'fail';
        decisionActualOutcome(currTrial,1) = "fail";
        decisionDeliver(     currTrial,1) = double(deliverThisTrial);
        decisionPrevOutcome( currTrial,1) = prevOutcomeForLog;
        decisionReason(      currTrial,1) = reason;
        decisionRandU(       currTrial,1) = u;

        currTrial = currTrial + 1;
    end

    flush(arduinoSerial);
    pause(0.01); drawnow limitrate nocallbacks;
end

disp('experiment over');

% --------------------
% Teardown (both cameras)
% --------------------
try stop([vid1 vid2]); end
try closepreview(vid1); end
try closepreview(vid2); end
try close(vw1); end
try close(vw2); end
delete(vid1); delete(vid2);
clear vid1 vid2 src1 src2
disp(['Video saved as: ' file_cam1]);
disp(['Video saved as: ' file_cam2]);

% --------------------
% Save timestamp text files
% --------------------
trialStartFile = fullfile(newDirectory, [mouseID '_trialStartTimestamps.txt']);
beamBreakFile  = fullfile(newDirectory, [mouseID '_beamBreakTimestamps.txt']);

fid = fopen(trialStartFile, 'w'); fprintf(fid, "Trial Start Timestamps:\n");
for i=1:numel(trialStartTimestamps)
    fprintf(fid, "%s\n", datestr(trialStartTimestamps{i}, 'yyyy-mm-dd HH:MM:SS.FFF'));
end
fclose(fid);

fid = fopen(beamBreakFile, 'w'); fprintf(fid, "Beam Break Timestamps:\n");
for i=1:numel(beamBreakTimestamps)
    fprintf(fid, "%s\n", datestr(beamBreakTimestamps{i}, 'yyyy-mm-dd HH:MM:SS.FFF'));
end
fclose(fid);

% --------------------
% Save total success summary CSV
% --------------------
totalTrialStarts = numel(trialStartTimestamps);
totalBeamBreaks  = numel(beamBreakTimestamps);
successPct       = 100 * (totalBeamBreaks / max(totalTrialStarts,1));

summaryTbl = table( ...
    totalTrialStarts, totalBeamBreaks, successPct, ...
    rewardPercentDelivered, totalRewardDeliveries, totalRewardOmissions, ...
    'VariableNames', {'trial_starts','beam_breaks','success_pct', ...
                      'reward_percent_delivered','reward_deliveries','reward_omissions'});

totalSuccessFile = fullfile(newDirectory, [mouseID '_totalSuccess.csv']);
writetable(summaryTbl, totalSuccessFile);

fprintf('Totals saved: %d trial starts, %d beam breaks (%.2f%%)\n', ...
    totalTrialStarts, totalBeamBreaks, successPct);
fprintf('Reward schedule: X=%.1f%%, delivered=%d, omissions=%d\n', ...
    rewardPercentDelivered, totalRewardDeliveries, totalRewardOmissions);

% --------------------
% Save per-trial reward schedule CSV
% --------------------
trialIdx = (1:numel(decisionDeliver)).';

rewardScheduleTbl = table( ...
    trialIdx, ...
    decisionTrialStartTs, ...
    decisionPrevOutcome, ...
    decisionDeliver, ...
    decisionRandU, ...
    decisionReason, ...
    decisionActualOutcome, ...
    'VariableNames', {'trial','trial_start_ts','prev_outcome','deliver','rand_u','reason','actual_outcome'});

rewardScheduleFile = fullfile(newDirectory, [mouseID '_rewardSchedule.csv']);
writetable(rewardScheduleTbl, rewardScheduleFile);

disp(['Wrote reward schedule: ' rewardScheduleFile]);

%% I'd like to just run video previews here after the "trial loop" has ended
%% === Preview-only session (no logging to disk) ===
try
    % Create fresh video objects for preview only
    fmt = 'Y800_640x480';        % same format
    vidP1 = videoinput('winvideo', 3, fmt);
    vidP2 = videoinput('winvideo', 4, fmt);

    set(vidP1, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger', Inf, 'LoggingMode','memory');
    set(vidP2, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger', Inf, 'LoggingMode','memory');

    % Request same frame rate (driver permitting)
    srcP1 = getselectedsource(vidP1);  srcP1.FrameRate = fps_str;
    srcP2 = getselectedsource(vidP2);  srcP2.FrameRate = fps_str;

    % If your driver supports hardware flip on device 4 you can try this:
    % (commented, since support varies; keep the software flip below either way)
    % try, set(srcP2, 'HorizontalFlip', 'on'); end

    triggerconfig(vidP1,'immediate');
    triggerconfig(vidP2,'immediate');

    % One figure, two axes
    fh = figure('Name','Preview-only (no logging). Close to stop.', 'NumberTitle','off');
    t = tiledlayout(fh,1,2,'Padding','compact','TileSpacing','compact');

    ax1 = nexttile(t,1); title(ax1,'Cam3'); axis(ax1,'image','off');
    ax2 = nexttile(t,2); title(ax2,'Cam4 (flipped)'); axis(ax2,'image','off');

    % Pre-create image handles at expected size (adjust if your format changes)
    hIm1 = imshow(zeros(480,640,'uint8'),'Parent',ax1);
    hIm2 = imshow(zeros(480,640,'uint8'),'Parent',ax2);

    % Bind previews to our image handles
    preview(vidP1, hIm1);

    % For device 4, flip the preview horizontally (display only)
    setappdata(hIm2, 'UpdatePreviewWindowFcn', ...
        @(obj, event, h) set(h,'CData', flip(event.Data, 2)));
    preview(vidP2, hIm2);

    % Start both (preview will update continuously, no disk writes)
    start([vidP1 vidP2]);

    % Keep UI alive until user closes the window
    disp('Preview-only running. Close the preview window to stop.');
    while isvalid(fh)
        pause(0.05);
        drawnow limitrate nocallbacks;
    end

catch ME
    warning('Preview-only session encountered an issue: %s', ME.message);
end

%% Cleanup (safe to call even if already closed)
try stop([vidP1 vidP2]); end
try closepreview(vidP1); end
try closepreview(vidP2); end
try delete(vidP1); delete(vidP2); end
clear vidP1 vidP2 srcP1 srcP2 fh hIm1 hIm2
%%
clear arduinoSerial; % Close the connection to the Arduino
disp('Serial port connection closed.');