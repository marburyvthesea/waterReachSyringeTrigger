%%
outputFile = ['F:\WaterReachData\11232024\mouse4_trial20.avi'];
recording_time = 60
%% Create video input object for the camera
vid = videoinput('winvideo', 1, 'Y800_640x480'); % Change to 'gentl' if preferred
src = getselectedsource(vid);
src.FrameRate = '110.0001'; % Set the desired frame rate
%%
% Configure video logging to MATLAB workspace
vid.FramesPerTrigger = Inf; % Capture indefinitely until stopped
vid.LoggingMode = 'memory'; % Log frames to memory

% Create a VideoWriter object for MJPEG compression
videoWriter = VideoWriter(outputFile, 'Motion JPEG AVI');
videoWriter.Quality = 75; % Set compression quality to 75

videoWriter.FrameRate = 110; % Match the camera frame rate
open(videoWriter);

% Set up preview and start acquisition
preview(vid);
start(vid); % Start video acquisition

% Run preview and save for 30 seconds
pause(recording_time);

% Stop preview and acquisition
stop(vid);
closepreview(vid);

% Save captured frames to video file
frames = getdata(vid); % Retrieve frames from memory
for i = 1:size(frames, 4)
    writeVideo(videoWriter, frames(:, :, :, i)); % Write each frame
end

% Close the video file
close(videoWriter);
disp(['Video saved as ', outputFile]);
%%
% Clean ups
delete(vid);
clear vid;


//