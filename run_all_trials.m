function run_all_trials(varargin)
%RUN_ALL_TRIALS Convert MVNX files and compute RULA scores without Excel metadata.
%
%   Place XSens .mvnx recordings in 01_rawData/, ensure skripts.zip is present,
%   then run this function from MATLAB. It will:
%     1. Extract skripts/ if needed and add helper paths.
%     2. Convert every .mvnx file to .mat under data/.
%     3. Build minimal Condition and Subject tables with placeholder metadata.
%     4. Call MF_02SelectAndRULA to calculate RULA scores for all trials.
%     5. Write Results.xlsx (Sheet "Results_detail") with the aggregated scores.
%
%   The function overwrites Project_table.mat, Project_data_v01.mat, and updates
%   Surgeon_db.xlsx in the repository root. A timestamped backup of the Excel
%   file is created automatically before writing.
%
%   Optional name/value arguments:
%       'launchVisualizer' (logical, default true) – open the interactive GUI
%           (RULA_Visualizer) after processing completes.
%       'backupSurgeonDB' (logical, default false) – create a timestamped copy
%           of Surgeon_db.xlsx before it is modified.
%       'processVideos'   (logical, default true) – blur reference videos via
%           videoblur after scoring when figure windows are available.

launchVisualizer = true;
backupSurgeon = false;
processVideos = true;
if ~isempty(varargin)
    if mod(numel(varargin), 2) ~= 0
        error('run_all_trials:InvalidArgs', ...
            'Optional arguments must be supplied as name/value pairs.');
    end
    for argIdx = 1:2:numel(varargin)
        name = lower(string(varargin{argIdx}));
        value = varargin{argIdx+1};
        switch name
            case "launchvisualizer"
                launchVisualizer = logical(value);
            case "backupsurgeondb"
                backupSurgeon = logical(value);
            case "processvideos"
                processVideos = logical(value);
            otherwise
                error('run_all_trials:UnknownOption', ...
                    'Unrecognised option "%s".', varargin{argIdx});
        end
    end
end

repoRoot = fileparts(mfilename('fullpath'));

% 1) Make sure helper scripts are available on the MATLAB path.
scriptsDir = fullfile(repoRoot, 'skripts');
if ~isfolder(scriptsDir)
    zipPath = fullfile(repoRoot, 'skripts.zip');
    if ~isfile(zipPath)
        error('run_all_trials:MissingScripts', ...
            'Neither skripts/ nor skripts.zip found in %s', repoRoot);
    end
    fprintf('Extracting skripts.zip to %s\n', repoRoot);
    unzip(zipPath, repoRoot);
end
addPathIfMissing(scriptsDir);
spmDir = fullfile(scriptsDir, 'spm1dmatlab-master');
if isfolder(spmDir)
    addPathIfMissing(spmDir, true);
end
ensureStandingLegScore(scriptsDir);

% Extract RULA lookup tables if necessary.
rulaDir = fullfile(repoRoot, 'RULA_tables');
if ~isfolder(rulaDir)
    zipPath = fullfile(repoRoot, 'RULA_tables.zip');
    if isfile(zipPath)
        fprintf('Extracting RULA_tables.zip to %s\n', repoRoot);
        unzip(zipPath, repoRoot);
    else
        mkdir(rulaDir);
        warning(['RULA_tables directory created but lookup spreadsheets are missing. ' ...
            'Please add Wrist and Arm Posture Score.xlsx, Trunk Posture Score.xlsx, and Table C.xlsx.']);
    end
end

% 2) Convert MVNX recordings to MAT files inside data/.
rawDir = fullfile(repoRoot, '01_rawData');
if ~isfolder(rawDir)
    error('run_all_trials:MissingRawDir', 'Directory not found: %s', rawDir);
end

matDir = fullfile(repoRoot, 'data');
if ~isfolder(matDir)
    mkdir(matDir);
end

rawFiles = dir(fullfile(rawDir, '*.mvnx'));
if isempty(rawFiles)
    error('run_all_trials:NoRawFiles', ...
        'No .mvnx files found under %s', rawDir);
end

fprintf('Converting %d MVNX file(s) to MAT...\n', numel(rawFiles));
for idx = 1:numel(rawFiles)
    [~, baseName, ~] = fileparts(rawFiles(idx).name);
    destMat = fullfile(matDir, [baseName '.mat']);
    if isfile(destMat)
        fprintf('  Skipping existing %s\n', destMat);
        continue;
    end
    Subject = MF_readMVNX(rawFiles(idx).folder, rawFiles(idx).name);
    save(destMat, 'Subject');
    fprintf('  Saved %s\n', destMat);
end

matFiles = dir(fullfile(matDir, '*.mat'));
if isempty(matFiles)
    error('run_all_trials:NoMatFiles', ...
        'No .mat files located under %s after conversion.', matDir);
end

% 3) Build placeholder metadata tables so MF_02SelectAndRULA can run.
nTrials = numel(matFiles);
subjectIDs = cell(nTrials, 1);
filenames = cell(nTrials, 1);
for idx = 1:nTrials
    [~, baseName, ext] = fileparts(matFiles(idx).name);
    subjectIDs{idx} = baseName;
    filenames{idx} = [baseName ext];
end

ConditionTable = table( ...
    subjectIDs, ...
    repmat({'NA'}, nTrials, 1), ...
    repmat({'NA'}, nTrials, 1), ...
    repmat({'NA'}, nTrials, 1), ...
    repmat({'NA'}, nTrials, 1), ...
    repmat({'NA'}, nTrials, 1), ...
    filenames, ...
    repmat({[matDir filesep]}, nTrials, 1), ...
    repmat({'not done'}, nTrials, 1), ...
    'VariableNames', {'SubjectID','Condition1','Condition2','Condition3', ...
    'Condition4','Condition5','Filename','PathName','RULA'});

Condition_db = cell2table(cell(1,5), 'VariableNames', ...
    {'Condition1','Condition2','Condition3','Condition4','Condition5'});

uniqueSubjects = unique(subjectIDs, 'stable');
Subject_db = table(uniqueSubjects(:), repmat({'unknown'}, numel(uniqueSubjects), 1), ...
    'VariableNames', {'SubjectID','Sex'});

% 4) Run the core RULA computation.
cleanupCaches(repoRoot);
if backupSurgeon
    backupSurgeonDB(repoRoot);
end

if exist('MF_02SelectAndRULA_v01', 'file')
    [ConditionTable_loaded, Data, Settings] = MF_02SelectAndRULA_v01( ...
        repoRoot, Condition_db, ConditionTable, Subject_db);
elseif exist('MF_02SelectAndRULA', 'file')
    [ConditionTable_loaded, Data, Settings] = MF_02SelectAndRULA( ...
        repoRoot, Condition_db, ConditionTable, Subject_db);
else
    error('run_all_trials:MissingFunction', ...
        'MF_02SelectAndRULA or MF_02SelectAndRULA_v01 not found on the MATLAB path.');
end

% 5) Summarise and persist results.
[Summary_table, ~] = MF_combine_RULA(Data, ConditionTable_loaded);
resultsPath = fullfile(repoRoot, 'Results.xlsx');
writetable(Summary_table, resultsPath, 'Sheet', 'Results_detail');
fprintf('Wrote summary to %s\n', resultsPath);

if false && exist('MF_combine_RULA_hist', 'file')
    try %#ok<TRYNC>
        MF_combine_RULA_hist(Data, ConditionTable_loaded);
    catch
    end
end

SettingsPath = fullfile(repoRoot, 'Project_settings.mat');
save(SettingsPath, 'Settings');
fprintf('Saved run settings snapshot to %s\n', SettingsPath);

videoSummary = processReferenceVideos(repoRoot, processVideos);
if videoSummary.Ran
    fprintf('Reference video blur: %d processed, %d skipped existing, %d failed.\n', ...
        videoSummary.Processed, videoSummary.SkippedExisting, videoSummary.Failed);
end

fprintf('RULA processing complete for %d trial(s).\n', nTrials);

if launchVisualizer && exist(fullfile(repoRoot, 'RULA_Visualizer.m'), 'file')
    try
        RULA_Visualizer(repoRoot);
    catch ME
        warning('run_all_trials:VisualizerFailed', ...
            'Unable to launch RULA_Visualizer automatically: %s', ME.message);
    end
end
end

function addPathIfMissing(dirPath, includeSubDirs)
% Add a folder (optionally with subfolders) to the MATLAB path if absent.
if nargin < 2
    includeSubDirs = false;
end
if ~isfolder(dirPath)
    return;
end
dirPath = char(dirPath);
target = normalizePath(dirPath);
existing = strsplit(path, pathsep);
existing = cellfun(@normalizePath, existing, 'UniformOutput', false);
if any(strcmpi(existing, target))
    return;
end
if includeSubDirs
    addpath(genpath(dirPath));
else
    addpath(dirPath);
end
end

function out = normalizePath(p)
out = char(p);
out = regexprep(out, '[\\/]+$', '');
end

function cleanupCaches(repoRoot)
% Delete cached tables so the run is non-interactive.
caches = {'Project_data_v01.mat', 'Project_table.mat'};
for ii = 1:numel(caches)
    cachePath = fullfile(repoRoot, caches{ii});
    if isfile(cachePath)
        delete(cachePath);
    end
end
end

function backupSurgeonDB(repoRoot)
% Keep a timestamped copy of Surgeon_db.xlsx before MF_02SelectAndRULA updates it.
source = fullfile(repoRoot, 'Surgeon_db.xlsx');
if ~isfile(source)
    return;
end
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
dest = fullfile(repoRoot, ['Surgeon_db_backup_' timestamp '.xlsx']);
if copyfile(source, dest)
    fprintf('Backed up Surgeon_db.xlsx to %s\n', dest);
end
end

function summary = processReferenceVideos(repoRoot, processVideos)
if nargin < 2
    processVideos = true;
end
summary = struct('Ran', false, 'Processed', 0, 'SkippedExisting', 0, 'Failed', 0);
if ~processVideos
    return;
end
videoDir = fullfile(repoRoot, 'ReferenceVideos');
if ~isfolder(videoDir)
    fprintf('ReferenceVideos directory not found at %s. Skipping video blur.\n', videoDir);
    return;
end
if exist('videoblur', 'file') ~= 2
    fprintf('videoblur.m not found on the MATLAB path. Skipping reference video processing.\n');
    return;
end
entries = [dir(fullfile(videoDir, '*.mp4')); dir(fullfile(videoDir, '*.MP4'))];
entries = entries(~[entries.isdir]);
if isempty(entries)
    fprintf('No reference videos located under %s.\n', videoDir);
    return;
end
names = lower({entries.name});
isBlurred = cellfun(@(name) endsWith(name, '_blurred.mp4') || endsWith(name, '-blurred.mp4'), names);
if all(isBlurred)
    fprintf('All reference videos already have blurred copies. Skipping videoblur.\n');
    return;
end
if ~hasFigureSupport()
    warning('run_all_trials:VideoBlurSkippedNoGraphics', ...
        'Skipping reference video blurring because figure windows are not available in this MATLAB session.');
    return;
end
pendingCount = sum(~isBlurred);
fprintf('Launching videoblur for %d reference video(s) that still need blurring.\n', pendingCount);
try
    blurSummary = videoblur(videoDir);
    summary.Ran = true;
    if isfield(blurSummary, 'Processed')
        summary.Processed = blurSummary.Processed;
    end
    if isfield(blurSummary, 'SkippedExisting')
        summary.SkippedExisting = blurSummary.SkippedExisting;
    end
    if isfield(blurSummary, 'Failed')
        summary.Failed = blurSummary.Failed;
    end
catch ME
    warning('run_all_trials:VideoBlurFailed', ...
        'videoblur encountered an error: %s', ME.message);
end
end

function tf = hasFigureSupport()
tf = false;
try
    tf = usejava('desktop') && feature('ShowFigureWindows');
catch
    tf = false;
end
end

function ensureStandingLegScore(scriptsDir)
% Ensure RULA Step 11 assumes unsupported legs (fixed score +2).
rulaFile = fullfile(scriptsDir, 'RULA_calc_scores.m');
if ~isfile(rulaFile)
    return;
end
fileText = fileread(rulaFile);
originalText = fileText;
oldComment = '% general leg and feet are supported';
newComment = '% For standing surgeons legs and feet are unsupported -> fixed score +2';
if contains(fileText, oldComment)
    fileText = strrep(fileText, oldComment, newComment);
end
oldAssign = 'rula.s11_leg_pos.total = ones(size(rula.s1_upper_arm_pos.left.total));';
newAssign = 'rula.s11_leg_pos.total = 2*ones(size(rula.s1_upper_arm_pos.left.total));';
if contains(fileText, oldAssign)
    fileText = strrep(fileText, oldAssign, newAssign);
end
if ~isequal(fileText, originalText)
    fid = fopen(rulaFile, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, fileText);
    fprintf('Updated Step 11 leg score to +2 in %s\n', rulaFile);
end
end
