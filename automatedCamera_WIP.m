%% Setup Parameters
baseOutputDir = 'F:\WaterReachData\11222024\'; % Base directory for saving videos
baseFileName = 'mouse4_trial';               % Base name for the video files
numTrials = 5;                               % Number of trials to run
recording_time = 10;                         % Recording duration for each trial (seconds)
frame_rate = 110.0001;                            % Camera frame rate

% Ensure output directory exists
if ~exist(baseOutputDir, 'dir')
    mkdir(baseOutputDir);
end

%% Create Video Input Object
vid = videoinput('winvideo', 1, 'Y800_640x480'); % Adjust device ID and format as needed
src = getselectedsource(vid);
src.FrameRate = sprintf('%.4f', frame_rate); % Set the frame rate

% Configure video input
vid.FramesPerTrigger = Inf;        % Capture until stopped
vid.LoggingMode = 'memory';        % Log frames to memory
vid.TriggerRepeat = Inf;           % Continuously trigger

%% Define Frame Writing Callback
% This callback function will have access to the `videoWriter` variable
function frameAcquiredCallback(obj, ~, videoWriter)
    % Get the latest frames and write them to the video
    frames = getdata(obj, obj.FramesAvailable); % Get all available frames

    % Process and write each frame
    for i = 1:size(frames, 4)
        % Ensure the frame size matches the VideoWriter requirements
        frame = frames(:, :, :, i); % Grayscale capture
        writeVideo(videoWriter, frame); % Write the frame
    end
    
    flushdata(obj); % Clear the memory buffer
end

for trialNum = 1:numTrials
    % Generate output file name for the current trial
    outputFile = fullfile(baseOutputDir, [baseFileName, num2str(trialNum), '.avi']);
    
    % Create VideoWriter object for this trial
    videoWriter = VideoWriter(outputFile, 'Motion JPEG AVI');
    videoWriter.Quality = 75;         % Set video quality
    videoWriter.FrameRate = frame_rate; % Match camera frame rate
    open(videoWriter);
    
    % Assign the callback with the videoWriter for this trial
    vid.FramesAcquiredFcnCount = 1; % Trigger callback after every frame
    vid.FramesAcquiredFcn = @(obj, event) frameAcquiredCallback(obj, event, videoWriter);
    
    % Start Acquisition for this trial
    disp(['Starting trial ', num2str(trialNum), '...']);
    preview(vid); % Show live preview
    start(vid);   % Start recording
    
    % Pause for the specified recording time
    pause(recording_time);
    
    % Stop Acquisition for this trial
    disp(['Stopping trial ', num2str(trialNum), '...']);
    stop(vid);
    closepreview(vid);
    
    % Close the VideoWriter object for this trial
    close(videoWriter);
    disp(['Trial ', num2str(trialNum), ' saved as ', outputFile]);
end

%% Cleanup
disp('Finalizing...');
delete(vid);        % Delete the video object
clear vid;          % Clear workspace variable
disp('All trials completed and saved.');
