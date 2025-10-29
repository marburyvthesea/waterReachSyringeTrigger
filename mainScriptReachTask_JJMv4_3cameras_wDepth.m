%% arduino parameters
port = 'COM3'; 
baudRate = 9600; 
arduinoSerial = serialport(port, baudRate);

try
    if isempty(pyenv().Version) || ~contains(pyenv().Version,"python")
        pyenv("Version","C:\Users\scanimage\.conda\envs\realsense\python.exe");
    end
catch
    pyenv("Version","C:\Users\scanimage\.conda\envs\realsense\python.exe");
end
%%
trialLength = 20;                           % individual trial length (seconds)
expLengthMins = 2;
%% start video acquisition then trigger syringe pump

% Params
videoFolder = 'F:\WaterReachData\09192025';
timestamp = datestr(now, 'mm_dd_yy_HH_MM_SS');
mouseID = ['test' timestamp];

% Paths
newDirectory = fullfile(videoFolder, mouseID);
if ~exist(newDirectory,'dir'); mkdir(newDirectory); end
file_cam1 = fullfile(newDirectory, [mouseID '_cam1.avi']);
file_cam2 = fullfile(newDirectory, [mouseID '_cam2.avi']);

% Camera setup (two devices: 1 and 2)
fmt = 'Y800_640x480';        % your format
fps_str = '113.9303';        % requested camera FPS (string for winvideo)
fps_writer = 113;            % VideoWriter nominal rate

vid1 = videoinput('winvideo', 3, fmt);
vid2 = videoinput('winvideo', 4, fmt);

src1 = getselectedsource(vid1);
src2 = getselectedsource(vid2);
src1.FrameRate = fps_str;
src2.FrameRate = fps_str;

% Write directly to disk in the background
vw1 = VideoWriter(file_cam1, 'Motion JPEG AVI'); vw1.Quality = 75; vw1.FrameRate = fps_writer;
vw2 = VideoWriter(file_cam2, 'Motion JPEG AVI'); vw2.Quality = 75; vw2.FrameRate = fps_writer;

set(vid1, 'LoggingMode', 'disk', 'DiskLogger', vw1, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger', Inf);
set(vid2, 'LoggingMode', 'disk', 'DiskLogger', vw2, 'ReturnedColorSpace','grayscale', 'FramesPerTrigger', Inf);

% (Optional) try to minimize start skew by starting both together
triggerconfig(vid1,'immediate');
triggerconfig(vid2,'immediate');

% Open writers & start
open(vw1); open(vw2);

% Open two preview windows (non-blocking)
preview(vid1);
preview(vid2);

% Start both cams as simultaneously as MATLAB allows
start([vid1 vid2]);
disp('Video recording started on both cameras.');

% 1) Import pyrealsense2 and start the pipeline
rs = py.importlib.import_module('pyrealsense2');
cfg = rs.config();
% Use 640x480 @ 30 fps to keep USB bandwidth reasonable
cfg.enable_stream(rs.stream.color, 640, 480, rs.format.bgr8, int32(30));
cfg.enable_stream(rs.stream.depth, 640, 480, rs.format.z16,  int32(30));
pipe = rs.pipeline();
profile = pipe.start(cfg);

% Depth scale (meters per unit)
dev   = profile.get_device();
dsens = dev.first_depth_sensor();
depth_scale = double(dsens.get_depth_scale());  %#ok<NASGU>  % save if you want meters: depth_m = depth * depth_scale

% 2) Output files for D435
file_d435_rgb   = fullfile(newDirectory, [mouseID '_d435_rgb.avi']);
file_d435_depth = fullfile(newDirectory, [mouseID '_d435_depth.tif']);     % 16-bit stack
file_d435_ts_c  = fullfile(newDirectory, [mouseID '_d435_color_timestamps.csv']);
file_d435_ts_d  = fullfile(newDirectory, [mouseID '_d435_depth_timestamps.csv']);

% VideoWriter for RGB (Motion JPEG)
vw_d435 = VideoWriter(file_d435_rgb, 'Motion JPEG AVI');
vw_d435.Quality   = 75;
vw_d435.FrameRate = 30;
open(vw_d435);

% Timestamp storage (preallocate lightly; will grow)
d435_color_ts = zeros(0,1);  % MATLAB datenum (or use posixtime seconds if you prefer)
d435_depth_ts = zeros(0,1);

% 3) Live preview figure for D435
fh = figure('Name','D435 RGB + Depth','NumberTitle','off');
tiledlayout(fh,1,2,'Padding','compact','TileSpacing','compact');
axC = nexttile; ihC = imshow(zeros(480,640,3,'uint8'),'Parent',axC); title(axC,'D435 Color');
axD = nexttile; ihD = imagesc(axD, zeros(480,640,'uint16')); axis(axD,'image'); colormap(axD,'parula'); colorbar(axD); title(axD,'D435 Depth (raw units)');

% 4) Timer to pull frames at ~30 fps without blocking your main loop
d435_running = true;
t_d435 = timer( ...
    'ExecutionMode','fixedRate', ...
    'Period',1/30, ...
    'BusyMode','drop', ...
    'TimerFcn',@grab_d435_frame, ...
    'ErrorFcn',@(varargin) disp('D435 timer error (continuing)...') );

start(t_d435);

% ---- Nested function: grabs one frameset and writes to disk/preview ----
function grab_d435_frame(~,~)
    if ~d435_running, return; end
    try
        frames  = pipe.wait_for_frames(500);              % 0.5 s timeout
        dframe  = frames.get_depth_frame();
        cframe  = frames.get_color_frame();
        if logical(dframe) && logical(cframe)
            % Depth (uint16)
            w = int32(dframe.get_width());  h = int32(dframe.get_height());
            buf = uint8(dframe.get_data());               % Python memoryview bytes
            depth = typecast(buf, 'uint16');              % vector
            depth = reshape(depth, [w h])';               % HxW
            % Append to TIFF stack (16-bit)
            if exist(file_d435_depth,'file')
                imwrite(depth, file_d435_depth, 'tif', 'WriteMode','append', 'Compression','none');
            else
                imwrite(depth, file_d435_depth, 'tif', 'Compression','none');
            end
            d435_depth_ts(end+1,1) = now;                 %#ok<AGROW>

            % Color (BGR8 -> RGB)
            w = int32(cframe.get_width());  h = int32(cframe.get_height());
            cbuf  = uint8(cframe.get_data());
            color = reshape(cbuf, [3, w*h]);              % 3 x N (B,G,R)
            color = permute(reshape(color, [3, w, h]), [3 2 1]); % HxWx3 (BGR)
            color = color(:,:, [3 2 1]);                  % -> RGB

            % Write to AVI (uint8 RGB)
            writeVideo(vw_d435, color);
            d435_color_ts(end+1,1) = now;                 %#ok<AGROW>

            % Update previews
            set(ihC,'CData',color);
            set(ihD,'CData',depth);
            drawnow limitrate nocallbacks;
        end
    catch
        % swallow transient timeouts; keep running
    end
end

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
    % Keep UI responsive
    pause(0.01);
    drawnow limitrate nocallbacks;
end
disp('experiment over')         % personal disp, not essent.

% --- Teardown (both cameras) ---
try stop([vid1 vid2]); end
try closepreview(vid1); end
try closepreview(vid2); end
try close(vw1); end
try close(vw2); end
delete(vid1); delete(vid2);
clear vid1 vid2 src1 src2
disp(['Video saved as: ' file_cam1]);
disp(['Video saved as: ' file_cam2]);

% Save timestamps (same as your original)
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

try
     d435_running = false;
     if isvalid(t_d435); stop(t_d435); delete(t_d435); end
     pipe.stop();
     close(vw_d435);
     % Save timestamps (CSV; one ISO8601 per line)
     writelines(string(datetime(d435_color_ts,'ConvertFrom','datenum','Format','yyyy-MM-dd HH:mm:ss.SSS')), file_d435_ts_c);
     writelines(string(datetime(d435_depth_ts,'ConvertFrom','datenum','Format','yyyy-MM-dd HH:mm:ss.SSS')), file_d435_ts_d);
     if isvalid(fh); close(fh); end
catch ME
     warning('D435 teardown: %s', ME.message);
end

%%
clear arduinoSerial; % Close the connection to the Arduino
disp('Serial port connection closed.');