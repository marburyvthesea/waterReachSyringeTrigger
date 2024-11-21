% Specify the output AVI file name
outputFileName = 'F:\WaterReachData\recording2_output.avi';

% Create a VideoWriter object with MJPEG compression
v = VideoWriter(outputFileName, 'Motion JPEG AVI');
v.Quality = 75; % Set compression quality to 75

% Open the VideoWriter object
open(v);

% Assuming 'recording2' is a 4D array [height, width, colorChannels, numFrames]
% Write each frame to the video file
for frameIndex = 1:size(recording2, 4)
    % Extract the current frame
    frame = recording2(:, :, :, frameIndex);
    
    % Write the frame to the video file
    writeVideo(v, frame);
end

% Close the VideoWriter object
close(v);

disp(['Video saved to ' outputFileName]);