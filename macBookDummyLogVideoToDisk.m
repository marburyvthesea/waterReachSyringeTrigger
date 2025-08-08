

trialLength = 30;                           % individual trial length
expLengthMins =1;                          % total length of exp

%%

%% start video acquisition then trigger syringe pump

% file location for later 'Z:\Basic_Sciences\Phys\ContractorLab\Projects\JJM\BehaviorData\water_reach_task\'
% [CHANGE VAR.] 
videoFolder = '/Users/johnmarshall/Documents/Analysis/WaterReachData/';         %folder for all mouse trial videos
mouseID = 'test_2';                                 %mouse ID

newDirectory = strcat(videoFolder, mouseID); 
mkdir(newDirectory);                                %creates new directory with mouseID as folder name
fileName = strcat(newDirectory, "\", mouseID, "_T", '.avi');

%establish video settings
vid = videoinput('macvideo', 1, 'YCbCr422_320x240'); % Change to 'gentl' if preferred
src = getselectedsource(vid);
%src.FrameRate = '20'; % Set the desired frame rate

% log frames directly to disk in the background
vw = VideoWriter(fileName, 'Motion JPEG AVI');
vw.Quality   = 75;
vw.FrameRate = 20;

vid.LoggingMode = 'disk';       % <<< key change (or 'disk&memory' if you also want a RAM buffer)
vid.DiskLogger  = vw;

% optional: make sure preview is grayscale not auto-converted
vid.ReturnedColorSpace = 'grayscale';

% continuous acquisition
vid.FramesPerTrigger = Inf;

% --- run ---
open(vw);                % open the writer before start
preview(vid);            % non-blocking live view
triggerconfig(vid,'immediate');
start(vid);              % begins acquiring & writing to disk in background
disp('Video recording started.');

delta = expLengthMins * 60 / 86400;         % becomes time difference needed to end trial
startTime = now;                            % initiation of start time
currTrial = 1;  

while now < (startTime + delta) 
    disp('running experiment');
    pause(0.01);
    drawnow limitrate nocallbacks;
end 

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







