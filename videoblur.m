function summary = videoblur(videoDir, varargin)
%VIDEOBLUR Apply an interactive elliptical blur to reference videos.
%   VIDEOBLUR() processes all MP4 files in the current directory and writes
%   blurred copies named *_blurred.mp4. The user is asked to place a vertical
%   ellipse around the surgeon's head on the first frame of each video; the
%   region is tracked and blurred for the remaining frames.
%
%   VIDEOBLUR(videoDir) processes videos located in the specified folder.
%
%   VIDEOBLUR(..., 'Overwrite', TF) forces regeneration of blurred videos when
%   TF is true. Default is false and existing *_blurred.mp4 files are skipped.
%
%   The function returns a struct with counts of processed, skipped, and failed
%   videos.

if nargin < 1 || isempty(videoDir)
    videoDir = pwd;
end
validateattributes(videoDir, {'char','string'}, {'nonempty'}, mfilename, 'videoDir', 1);
videoDir = char(videoDir);

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, 'Overwrite', false, @(x)islogical(x) || (isnumeric(x) && isscalar(x)));
addParameter(parser, 'ExpandFactor', 1.5, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'RotateAngle', -90, @(x)isnumeric(x) && isscalar(x));
addParameter(parser, 'MinPointsToTrack', 8, @(x)isnumeric(x) && isscalar(x) && x >= 0);
addParameter(parser, 'GaussSigma', 10, @(x)isnumeric(x) && isscalar(x) && x > 0);
addParameter(parser, 'Preview', false, @(x)islogical(x) || (isnumeric(x) && isscalar(x)));
addParameter(parser, 'PreviewStep', 30, @(x)isnumeric(x) && isscalar(x) && x >= 1);
addParameter(parser, 'UseGPU', [], @(x)islogical(x) || (isnumeric(x) && isscalar(x)));
parse(parser, varargin{:});
opts = parser.Results;

if isempty(opts.UseGPU)
    opts.UseGPU = gpuDeviceCount > 0;
else
    opts.UseGPU = logical(opts.UseGPU);
end
opts.Overwrite = logical(opts.Overwrite);
opts.Preview = logical(opts.Preview);
opts.PreviewStep = round(opts.PreviewStep);

if ~isfolder(videoDir)
    error('videoblur:MissingFolder', 'Directory not found: %s', videoDir);
end
if ~featureSupportsFigures()
    error('videoblur:GraphicsUnavailable', ...
        'Interactive video blurring requires a MATLAB session with figure support.');
end

entries = [dir(fullfile(videoDir, '*.mp4')); dir(fullfile(videoDir, '*.MP4'))];
entries = entries(~[entries.isdir]);
if isempty(entries)
    error('videoblur:NoVideos', 'No .mp4 files located in %s.', videoDir);
end

summary = struct('Processed', 0, 'SkippedExisting', 0, 'Failed', 0, ...
    'Outputs', {cell(0, 1)}, 'Messages', {cell(0, 1)});

fprintf('Applying elliptical blur in %s (%d video(s)).\n', videoDir, numel(entries));
for idx = 1:numel(entries)
    entry = entries(idx);
    inputPath = fullfile(entry.folder, entry.name);
    [~, nameOnly, ~] = fileparts(entry.name);
    lowerName = lower(nameOnly);
    if endsWith(lowerName, '_blurred') || endsWith(lowerName, '-blurred')
        fprintf('Skipping %s (already blurred).\n', entry.name);
        summary.SkippedExisting = summary.SkippedExisting + 1;
        summary.Outputs{end+1, 1} = inputPath; %#ok<AGROW>
        continue;
    end
    outputPath = fullpathWithBlurSuffix(entry.folder, nameOnly);

    if ~opts.Overwrite && isfile(outputPath)
        fprintf('Skipping %s (blurred version found).\n', entry.name);
        summary.SkippedExisting = summary.SkippedExisting + 1;
        summary.Outputs{end+1, 1} = outputPath; %#ok<AGROW>
        continue;
    end

    fprintf('Processing %d/%d: %s\n', idx, numel(entries), entry.name);
    try
        processSingleVideo(inputPath, outputPath, opts);
        summary.Processed = summary.Processed + 1;
        summary.Outputs{end+1, 1} = outputPath; %#ok<AGROW>
    catch ME
        summary.Failed = summary.Failed + 1;
        summary.Messages{end+1, 1} = sprintf('%s: %s', entry.name, ME.message); %#ok<AGROW>
        warning('videoblur:ProcessingFailed', ...
            'Failed to blur %s: %s', entry.name, ME.message);
    end
end

if summary.Processed > 0
    fprintf('Finished blurring %d video(s).\n', summary.Processed);
else
    fprintf('No videos were blurred (all skipped or failed).\n');
end
end

function processSingleVideo(inputPath, outputPath, opts)
reader = VideoReader(inputPath);
writer = VideoWriter(outputPath, 'MPEG-4');
writer.FrameRate = reader.FrameRate;
open(writer);
cleanupWriter = onCleanup(@()close(writer)); %#ok<NASGU>

firstFrame = readFrame(reader);
firstFrame = imrotate(firstFrame, opts.RotateAngle);

[ellipseCenter, ellipseSemiAxes, ellipseRotation] = selectInitialEllipse(firstFrame, inputPath);

grayFirst = rgb2gray(firstFrame);
bbox = [ellipseCenter(1)-ellipseSemiAxes(1), ellipseCenter(2)-ellipseSemiAxes(2), 2*ellipseSemiAxes];
pointsDetected = detectMinEigenFeatures(grayFirst, 'ROI', round(bbox), 'MinQuality', 0.01);
pointTracker = vision.PointTracker('MaxBidirectionalError', 3);
cleanupTracker = onCleanup(@()safeReleasePointTracker(pointTracker)); %#ok<NASGU>

if pointsDetected.Count > 0
    points = pointsDetected.Location;
    initialize(pointTracker, points, grayFirst);
    isTracking = true;
else
    points = zeros(0, 2);
    isTracking = false;
end

lastEllipse = struct('Center', ellipseCenter, ...
    'SemiAxes', ellipseSemiAxes, ...
    'RotationAngle', ellipseRotation);

reader.CurrentTime = 0;
totalFrames = round(reader.FrameRate * reader.Duration);
frameIdx = 0;
tic;

while hasFrame(reader)
    frameRGB = readFrame(reader);
    frameRGB = imrotate(frameRGB, opts.RotateAngle);
    frameIdx = frameIdx + 1;
    grayFrame = rgb2gray(frameRGB);

    if isTracking
        [pointsNew, validity] = step(pointTracker, grayFrame);
        validPointsNew = pointsNew(validity, :);
        validPointsOld = points(validity, :);
    else
        validPointsNew = zeros(0, 2);
        validPointsOld = zeros(0, 2);
    end

    if isTracking && size(validPointsNew, 1) >= opts.MinPointsToTrack
        delta = mean(validPointsNew, 1) - mean(validPointsOld, 1);
        lastEllipse.Center = lastEllipse.Center + delta;
        points = validPointsNew;
        setPoints(pointTracker, points);
    else
        [isTracking, points, lastEllipse] = attemptManualReinit(frameRGB, opts, pointTracker, lastEllipse);
    end

    frameRGB = applyEllipseBlur(frameRGB, lastEllipse, opts);

    if opts.Preview && mod(frameIdx, opts.PreviewStep) == 0
        figureTitle = sprintf('Preview frame %d/%d', frameIdx, totalFrames);
        showPreviewFrame(frameRGB, figureTitle);
    end

    writeVideo(writer, frameRGB);
    printEta(frameIdx, totalFrames);
end

fprintf('\nSaved blurred video to %s\n', outputPath);
end

function [center, semiAxes, rotation] = selectInitialEllipse(firstFrame, inputPath)
[height, width, ~] = size(firstFrame);
defaultWidth = round(width * 0.12);
defaultHeight = round(height * 0.28);
defaultCenter = [width * 0.5, height * 0.5];

[~, fileName, ~] = fileparts(inputPath);
fig = figure('Name', ['Select head ellipse: ', fileName], ...
    'NumberTitle', 'off');
cleanupFig = onCleanup(@()closeFigureSafely(fig));
imshow(firstFrame);
title('Position the vertical ellipse around the head, then double-click or press Enter');

ellipseROI = drawellipse('Center', defaultCenter, ...
    'SemiAxes', [defaultWidth / 2, defaultHeight / 2], ...
    'RotationAngle', 90, ...
    'Color', 'r', ...
    'Label', 'Head ROI');

wait(ellipseROI);
center = ellipseROI.Center;
semiAxes = ellipseROI.SemiAxes;
rotation = ellipseROI.RotationAngle;
clear cleanupFig;
end

function [isTracking, points, ellipseState] = attemptManualReinit(frameRGB, opts, pointTracker, ellipseState)
fprintf('\nTracking lost. Manual re-initialisation required.\n');
fig = figure('Name', 'Tracking lost', 'NumberTitle', 'off');
cleanupFig = onCleanup(@()closeFigureSafely(fig));
imshow(frameRGB);
title('Draw new vertical ellipse (double-click or Enter to confirm, Esc to keep last)');

try
    newEllipse = drawellipse('Label', 'New Head ROI', 'Color', 'y', 'RotationAngle', 90); %#ok<NASGU>
    wait(newEllipse);
    newCenter = newEllipse.Center;
    newSemiAxes = newEllipse.SemiAxes;
    newRotation = newEllipse.RotationAngle;
catch
    newCenter = [];
    newSemiAxes = [];
    newRotation = ellipseState.RotationAngle;
end
clear cleanupFig;

if isempty(newCenter)
    fprintf('Ellipse unchanged; continuing with previous ROI.\n');
    points = zeros(0, 2);
    isTracking = false;
    return;
end

bbox = [newCenter(1) - newSemiAxes(1), newCenter(2) - newSemiAxes(2), 2 * newSemiAxes];
grayFrame = rgb2gray(frameRGB);
pointsDetected = detectMinEigenFeatures(grayFrame, 'ROI', round(bbox), 'MinQuality', 0.01);

if pointsDetected.Count >= opts.MinPointsToTrack
    points = pointsDetected.Location;
    release(pointTracker);
    initialize(pointTracker, points, grayFrame);
    isTracking = true;
    ellipseState.Center = newCenter;
    ellipseState.SemiAxes = newSemiAxes;
    ellipseState.RotationAngle = newRotation;
    fprintf('Re-initialised tracker with %d points.\n', size(points, 1));
else
    fprintf('Insufficient feature points detected. Continuing without tracking.\n');
    points = zeros(0, 2);
    isTracking = false;
end
end

function frameOut = applyEllipseBlur(frameRGB, ellipseState, opts)
[height, width, ~] = size(frameRGB);
mask = false(height, width);

cx = round(ellipseState.Center(1));
cy = round(ellipseState.Center(2));
rx = max(1, round(ellipseState.SemiAxes(1) * opts.ExpandFactor));
ry = max(1, round(ellipseState.SemiAxes(2) * opts.ExpandFactor));
theta = deg2rad(ellipseState.RotationAngle);

[X, Y] = meshgrid(1:width, 1:height);
Xrot = (X - cx) * cos(theta) + (Y - cy) * sin(theta);
Yrot = -(X - cx) * sin(theta) + (Y - cy) * cos(theta);
ellipseMask = (Xrot .^ 2 / rx ^ 2 + Yrot .^ 2 / ry ^ 2) <= 1;
mask(ellipseMask) = true;

if opts.UseGPU
    frameGPU = gpuArray(frameRGB);
    blurred = gather(imgaussfilt(frameGPU, opts.GaussSigma));
else
    blurred = imgaussfilt(frameRGB, opts.GaussSigma);
end

frameOut = frameRGB;
frameOut(repmat(mask, [1 1 3])) = blurred(repmat(mask, [1 1 3]));
end


function outputPath = fullpathWithBlurSuffix(folder, nameOnly)
baseName = stripSuffixCase(nameOnly, '_blurred');
baseName = stripSuffixCase(baseName, '-blurred');
outputPath = fullfile(folder, [baseName '_blurred.mp4']);
end

function trimmed = stripSuffixCase(name, suffix)
if nargin < 2 || isempty(suffix)
    trimmed = name;
    return;
end
nameChar = char(name);
lenName = length(nameChar);
lenSuffix = length(suffix);
if lenName >= lenSuffix && strcmpi(nameChar(lenName-lenSuffix+1:lenName), suffix)
    trimmed = nameChar(1:lenName-lenSuffix);
else
    trimmed = nameChar;
end
end

function showPreviewFrame(frameRGB, titleText)
persistent previewFig previewAx
if isempty(previewFig) || ~isvalid(previewFig)
    previewFig = figure('Name', 'videoblur preview', 'NumberTitle', 'off');
    previewAx = axes('Parent', previewFig);
elseif isempty(previewAx) || ~isvalid(previewAx)
    previewAx = axes('Parent', previewFig);
end
imshow(frameRGB, 'Parent', previewAx);
title(previewAx, titleText);
drawnow;
end

function printEta(frameIdx, totalFrames)
if frameIdx <= 1 || totalFrames <= 0
    return;
end
elapsed = toc;
progress = frameIdx / totalFrames;
eta = elapsed / max(progress, eps) * (1 - progress);
fprintf('Frame %d/%d (%.1f%%) – ETA: %d min %d sec\r', ...
    frameIdx, totalFrames, progress * 100, floor(eta / 60), round(mod(eta, 60)));
end

function ok = featureSupportsFigures()
ok = false;
try
    ok = usejava('desktop') && feature('ShowFigureWindows');
catch
    ok = false;
end
end

function closeFigureSafely(fig)
if isempty(fig) || ~ishandle(fig)
    return;
end
try %#ok<TRYNC>
    close(fig);
end
end

function safeReleasePointTracker(pointTracker)
if isempty(pointTracker)
    return;
end
try %#ok<TRYNC>
    release(pointTracker);
end
end
