function run_all_trials()
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
%   Dentist_db.xlsx in the repository root. A timestamped backup of the Excel
%   file is created automatically before writing.

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
addpath(scriptsDir);
spmDir = fullfile(scriptsDir, 'spm1dmatlab-master');
if isfolder(spmDir)
    addpath(genpath(spmDir));
end

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
backupDentistDB(repoRoot);

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

if exist('MF_combine_RULA_hist', 'file')
    try %#ok<TRYNC>
        MF_combine_RULA_hist(Data, ConditionTable_loaded);
    catch
    end
end

SettingsPath = fullfile(repoRoot, 'Project_settings.mat');
save(SettingsPath, 'Settings');
fprintf('Saved run settings snapshot to %s\n', SettingsPath);

fprintf('RULA processing complete for %d trial(s).\n', nTrials);
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

function backupDentistDB(repoRoot)
% Keep a timestamped copy of Dentist_db.xlsx before MF_02SelectAndRULA updates it.
source = fullfile(repoRoot, 'Dentist_db.xlsx');
if ~isfile(source)
    return;
end
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
dest = fullfile(repoRoot, ['Dentist_db_backup_' timestamp '.xlsx']);
if copyfile(source, dest)
    fprintf('Backed up Dentist_db.xlsx to %s\n', dest);
end
end
