%% arduino parameters

port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);
%%
trialLength = 30;                           % individual trial length
expLengthMins =5;                          % total length of exp

%% start video acquisition then trigger syringe pump

% file location for later 'Z:\Basic_Sciences\Phys\ContractorLab\Projects\JJM\BehaviorData\water_reach_task\'
% [CHANGE VAR.] 
videoFolder = 'F:\WaterReachData\11272024';         %folder for all mouse trial videos
mouseID = 'm1_r4';                                 %mouse ID

newDirectory = strcat(videoFolder, mouseID); 
mkdir(newDirectory);                                %creates new directory with mouseID as folder name
fileName = strcat(newDirectory, "\", mouseID, "_T", '.avi');

%establish video settings
vid = videoinput('winvideo', 1, 'Y800_640x480'); % Change to 'gentl' if preferred
src = getselectedsource(vid);
src.FrameRate = '113.9303'; % Set the desired frame rate
vid.FramesPerTrigger = Inf; % Set to continuous recording
vid.LoggingMode = "memory"; % Log frames to memory

videoWriter = VideoWriter(fileName, 'Motion JPEG AVI');
videoWriter.Quality = 75; % Set compression quality to 75
videoWriter.FrameRate = 110; %match the camera frame rate

% Open, preview and start video acquisition
open(videoWriter);
preview(vid);
start(vid); % Start the video recording
disp('Video recording started.');

%%%
% Variable to store timestamps for later analysis
trialStartTimestamps = {};      % Start of trial timestamp
beamBreakTimestamps = {};       % Successful trial
 
delta = expLengthMins * 60 / 86400;         % becomes time difference needed to end trial
startTime = now;                            % initiation of start time
currTrial = 1;    

while now < (startTime + delta)  
    % send 1 to arduino to trigger pump 
    write(arduinoSerial, '1', 'char');
    pause(5)
   
    % send status character 's' to prompt status of IR beam
    pause(5)
    write(arduinoSerial, 's', 'char');
    
    % initial timing for start of trials
    trialStartTimestamps{end + 1} = datetime('now'); % Record the current timestamp
    tic                                              %start timer for trials
    
    % variables for while loop and initial state
    % from arduinoSerial ('Broken' = water drop still there, 'Unbroken' =
    % water drop missing
    startNextTrial = false;
    sCheck = "Unbroken";
    
    % continous checking of IR beam leading to issues instead just wait a
    % given length of time then get status of IR beam to determine if new
    % drop needs to be delivered 
    if(now < (startTime + delta))
        pause(trialLength)
    end

    while ~startNextTrial
        if arduinoSerial.NumBytesAvailable > 0      % verifying open communication from arduino
            write(arduinoSerial, 's', 'char');      % get status from IR beam
            pause(1)
            irBeam = strtrim(readline(arduinoSerial));
            % check if success -- i.e. beam is unbroken / water drop missing
            if (strcmp(sCheck, irBeam) == 1)        % if true, water drop missing
                beamBreakTimestamps{end + 1} = datetime('now');         % Record the current timestamp
                disp(strcat("trial ", num2str(currTrial), ": SUCCESS ", num2str(toc)));     % disp for personal tracking (not necessary)
                startNextTrial = true;
                currTrial = currTrial + 1;
            % check if trial block over 
            elseif(now > (startTime + delta))   % check if entire exp is over, the loop could keep it running if not incl.
                startNextTrial = true;
            % else assume failure -- i.e. beam remains broken
            else
                if(toc > trialLength)           % resets trial clock, new trial beginning
                    tic
                    trialStartTimestamps{end + 1} = datetime('now'); 
                    disp(strcat("trial ", num2str(currTrial), ": FAILED"));
                    % trigger air puff / other "punishment" signal, maybe
                    % white light initially 
                    % trigger white superwhite led here 
                    currTrial = currTrial + 1;
                end
            end
        end
    end    
    % resets arduino comm. cleans backlogged status checks
    flush(arduinoSerial);
end
disp('experiment over')         % personal disp, not essent.

% Stop video acquisition
    stop(vid);                  % Stop video recording
    closepreview(vid);
    disp('Video recording stopped.');

    frames = getdata(vid);

    for i = 1:size(frames, 4)
        writeVideo(videoWriter, frames(:, :, :, i)); % Write each frame
    end

    close(videoWriter);
    delete(vid); % Delete video input object
    disp(['Video saved as ', fileName]);
    clear vid; % Clear the variable

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