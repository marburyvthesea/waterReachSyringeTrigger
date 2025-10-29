%% arduino parameters
port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);
%%
trialLength = 20;                           % individual trial length (seconds)
expLengthMins = 55;                          % total length of expn (minutes)

%% start video acquisition then trigger syringe pump

% file location for later 'Z:\Basic_Sciences\Phys\ContractorLab\Projects\JJM\BehaviorData\water_reach_task\'
% [CHANGE VAR.]    
videoFolder = 'F:\WaterReachData\09162025';         %folder for all mouse trial videos
timestamp = datestr(now, 'mm_dd_yy_HH_MM_SS'); 

mouseID = 'm2_t1';   %mouse ID

mouseID = strcat(mouseID, '_', timestamp);         % Update mouseID with timestamp

newDirectory = strcat(videoFolder, mouseID); 
mkdir(newDirectory);                                %creates new directory with mouseID as folder name
fileName = strcat(newDirectory, "\", mouseID, "_T", '.avi');

%establish video settings
vid = videoinput('winvideo', 1, 'Y800_640x480'); % Change to 'gentl'/'winvideo' if preferred
src = getselectedsource(vid);
src.FrameRate = '113.9303'; % Set the desired frame rate

% log frames directly to disk in the background
vw = VideoWriter(fileName, 'Motion JPEG AVI');
vw.Quality = 75;
vw.FrameRate = 113; 

vid.LoggingMode = 'disk';
vid.DiskLogger = vw;

vid.ReturnedColorSpace = 'grayscale' ;

vid.FramesPerTrigger = Inf; 

% --- run ---
open(vw);                % open the writer before start
preview(vid);            % non-blocking live view
triggerconfig(vid,'immediate');
start(vid);              % begins acquiring & writing to disk in background
disp('Video recording started.');

%%%
% Variable to store timestamps for later analysis
trialStartTimestamps = {};      % Start of trial timestamp
beamBreakTimestamps = {};       % Successful trial
 
delta = expLengthMins * 60 / 86400;         % becomes time difference needed to end trial
startTime = now;                            % initiation of start time
currTrial = 1;    
triggerPump=true;
triggerBuzzer=true;

while now < (startTime + delta)  
             
    if triggerPump
        % send 1 to arduino to trigger pump and buzzer
        write(arduinoSerial, '1', 'char');
    elseif triggerBuzzer & ~triggerPump
        % send 2 to arduino to trigger buzzer
        write(arduinoSerial, '2', 'char');
    end
   
    pause(10)
   
    % send status character 's' to prompt status of IR beam
    %pause(5)
    %write(arduinoSerial, 's', 'char');
    
    % initial timing for start of trials
    trialStartTimestamps{end + 1} = datetime('now'); % Record the current timestamp
    tic                                              %start timer for trials
    
    % variables for while loop and initial state
    % from arduinoSerial ('Broken' = water drop still there, 'Unbroken' =
    % water drop missing
    startNextTrial = false;
    
    
    % continous checking of IR beam leading to issues instead just wait a
    % given length of time then get status of IR beam to determine if new
    % drop needs to be delivered 
    if(now < (startTime + delta))
        % perhaps instead here use either a capacitative sensor to detect
        % touch to water spout or a proximity sensor to detect mouse arm at
        % given point 
        %display time elapsing here
        disp('Starting trial pause:');
        startPauseTime = tic; % Start the timer
        
        %update video
        pause(0.01);
        drawnow limitrate nocallbacks;

        while toc(startPauseTime) < trialLength
            pause(0.01);
            drawnow limitrate nocallbacks;
            if mod(round(toc(startPauseTime)), 5) == 0 % Check every 5 seconds
            fprintf('Elapsed: %.2f s | Remaining: %.2f s\n', toc(startPauseTime), max(trialLength - toc(startPauseTime), 0));
            pause(1); % Prevent multiple prints within the same second
            end
        end
    end
    
    sCheck = "Unbroken";
    disp('reading beam')
    write(arduinoSerial, 's', 'char');
    pause(1)
    
    if arduinoSerial.NumBytesAvailable > 0      % verifying open communication from arduino
        disp('is broken?')
        rawData = strtrim(readline(arduinoSerial));
        disp(['Raw data: ', rawData]);
        % Clean the received string to remove leading/trailing digits or spaces
        irBeam = regexprep(strtrim(rawData), '[^a-zA-Z]', '');
        disp(['Cleaned data: ', irBeam]);
        % check if success -- i.e. beam is unbroken / water drop missing
        if (strcmp(sCheck, irBeam) == 1)        % if true, water drop missing
            beamBreakTimestamps{end + 1} = datetime('now');         % Record the current timestamp
            disp(strcat("trial ", num2str(currTrial), ": SUCCESS ", num2str(toc)));     % disp for personal tracking (not necessary)
            %startNextTrial = true;
            currTrial = currTrial + 1;
            triggerPump=true;
            triggerBuzzer=true;
            flush(arduinoSerial);
        elseif ~(strcmp(sCheck, irBeam) == 1)
            trialStartTimestamps{end + 1} = datetime('now'); 
            disp(strcat("trial ", num2str(currTrial), ": FAILED"));
            % trigger air puff / other "punishment" signal, maybe
            % white light initially 
            % trigger white superwhite led here 
            currTrial = currTrial + 1;
            triggerPump=false;
            triggerBuzzer=true;
            flush(arduinoSerial);
        else
            disp('did not read beam, exiting')
            startNextTrial = true;
        end
    else
        disp('did not read beam')
        flush(arduinoSerial);
    end    
    % resets arduino comm. cleans backlogged status checks
    flush(arduinoSerial);
end
disp('experiment over')         % personal disp, not essent.

% --- teardown ---
disp('experiment over')
stop(vid);               % stops acquisition; file is already on disk
closepreview(vid);
try
    close(vw);           % close writer explicitly (good hygiene)
catch
end
delete(vid);
clear vid
disp(['Video saved as ', fileName]);

% Write timestclose(videoWriter);amps to a text file
trialStarttimestampFile = strcat(newDirectory, "\", mouseID, "_trialStartTimestamps.txt");
beamBreaktimestampFile = strcat(newDirectory, "\", mouseID, "_beamBreakTimestamps.txt");


% Write each timestamp to the file
trialStartID = fopen(trialStarttimestampFile, 'w'); % Open the file for writing
fprintf(trialStartID, "Trial Start Timestamps:\n");
for i = 1:length(trialStartTimestamps)
    fprintf(trialStartID, "%s\n", datestr(trialStartTimestamps{i}, 'yyyy-mm-dd HH:MM:SS.FFF'));
end
fclose(trialStartID);

beamBreakID = fopen(beamBreaktimestampFile, 'w'); % Open the file for writing
fprintf(beamBreakID, "Beam Break Timestamps:\n");
for i = 1:length(beamBreakTimestamps)
    fprintf(beamBreakID, "%s\n", datestr(beamBreakTimestamps{i}, 'yyyy-mm-dd HH:MM:SS.FFF'));
end
fclose(beamBreakID); % Close the file

%%
clear arduinoSerial; % Close the connection to the Arduino
disp('Serial port connection closed.');