%% arduino parameters

port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);

%% start video acquisition then trigger syringe pump

recordingLengthSeconds = 5; % video recording / trial length
pumpDelay = 2; % delay between starting video acquisition and triggering the pump

%file location for later 'Z:\Basic_Sciences\Phys\ContractorLab\Projects\JJM\BehaviorData\water_reach_task\'
videoFolder = 'F:\WaterReachData\112024'; %folder for all mouse trial videos
mouseID = 'test-1';   %mouse ID
newDirectory = strcat(videoFolder, mouseID); 
mkdir(newDirectory);    %creates new directory with mouseID as folder name

trials = 10; %change for num of trials run
counter = 0;
%%
for rec = 1:trials    
    counter = counter + 1;
    
    fileName = strcat(newDirectory, "\", mouseID, "_T", string(counter), '.avi');

    vid = videoinput('winvideo', 1, 'Y800_640x480'); % Change to 'gentl' if preferred
    src = getselectedsource(vid);
    src.FrameRate = '110.0001'; % Set the desired frame rate
    vid.FramesPerTrigger = Inf; % Set to continuous recording
    vid.LoggingMode = "memory"; % Log frames to memory

    videoWriter = VideoWriter(outputFile, 'Motion JPEG AVI');
    videoWriter.Quality = 75; % Set compression quality to 75

% Start video acquisition
    start(vid); % Start the video recording
    disp('Video recording started.');

    % send 1 to arduino to trigger pump 
    write(arduinoSerial, '1', 'char');
    pause(5)
    disp('start pump:')
    
    % Wait for the signal '1' from Arduino
    % received = false;
    % pause(3)
    % disp('waiting for signal for Arduino')
    % while ~received
    %     if arduinoSerial.NumBytesAvailable > 0
    %         response = read(arduinoSerial, 1, 'char');
    %         if response == '1'
    %             disp('Water delivery stopped.');
    %             received = true;
    %         end
    %     end
    %     pause(0.1); % Small delay 
    % end
    
% Continue recording for trial length
    %pause(recordingLengthSeconds);  % this additional time seems essential for recording up to mouse grab

    %send status character 's' to prompt status of water drop
    write(arduinoSerial, 's', 'char');
    pause(5)
    
    disp('waiting for trial to end')
    startNextTrial = false;
    sCheck = "Unbroken";
    while ~startNextTrial
        if arduinoSerial.NumBytesAvailable > 0
            write(arduinoSerial, 's', 'char');
            pause(1)
            irBeam = strtrim(readline(arduinoSerial));
            %disp(irBeam);
            if (strcmp(sCheck, irBeam) == 1) %meaning there's no longer a water drop
                disp('trial ended: mouse took water');
                startNextTrial = true;
            end
        end
    end
    flush(arduinoSerial);

% Stop video acquisition
    stop(vid); % Stop video recording
    disp('Video recording stopped.');

    delete(vid); % Delete video input object
    clear vid; % Clear the variable
end

%%
clear arduinoSerial; % Close the connection to the Arduino
disp('Serial port connection closed.');