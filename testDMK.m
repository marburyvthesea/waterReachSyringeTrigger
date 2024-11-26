

%vid = videoinput('gentl', 1); % Create video input object for the first camera
vid = videoinput('winvideo', 1, 'Y800_640x480');
src = getselectedsource(vid);
src.FrameRate = '110.0001'
%%
preview(vid);
pause(240); % Preview 
closepreview(vid);

%%
delete(vid);
clear vid;