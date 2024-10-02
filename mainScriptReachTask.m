%% arduino parameters

port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);

recordingLengthSeconds = 10; % video recording / trial length
pumpDelay = 2; % delay between starting video acquisition and triggering the pump

%% start video acquisition then trigger syringe pump

vid = videoinput('macvideo', 1); % Create video input object for the first camera
vid.FramesPerTrigger = Inf; % Set to continuous recording
vid.LoggingMode = 'disk'; % Store video on disk (optional, adjust if needed)
diskLogger = VideoWriter('recorded_video.avi', 'Uncompressed AVI'); % Specify the output file
vid.DiskLogger = diskLogger;

%% Start video acquisition

start(vid); % Start the video recording
disp('Video recording started.');

pause(pumpDelay); % Wait for camera to start before triggering syringe pump
disp('Delay complete, triggering pump...');

% send 1 to arduino to trigger pump 
write(arduinoSerial, '1', 'char');

%% Continue recording for trial length 
pause(recordingLengthSeconds - pumpDelay); % Continue recording until the specified time has passed

%% Stop video acquisition
stop(vid); % Stop video recording
disp('Video recording stopped.');

delete(vid); % Delete video input object
clear vid; % Clear the variable