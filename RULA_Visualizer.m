function RULA_Visualizer(repoRoot)
%RULA_VISUALIZER Interactive RULA data exploration GUI.
%   RULA_VISUALIZER() launches the GUI in the current working directory.  The
%   app expects that run_all_trials has completed successfully and that
%   Project_data_v01.mat plus 04_Processed/<trial>_processed.mat files exist.
%
%   RULA_VISUALIZER(repoRoot) loads project artefacts from the specified
%   repository root.

if nargin < 1 || isempty(repoRoot)
    repoRoot = pwd;
end

dataFile = fullfile(repoRoot, 'Project_data_v01.mat');
if ~isfile(dataFile)
    error('RULA_Visualizer:MissingData', ...
        'Could not locate Project_data_v01.mat in %s. Run run_all_trials first.', repoRoot);
end

loaded = load(dataFile, 'ConditionTable_loaded', 'Data', 'Settings');
ConditionTable = loaded.ConditionTable_loaded;
Settings = loaded.Settings;
Data = loaded.Data;

subjectIDs = string(ConditionTable.SubjectID);
trialNames = string(ConditionTable.Filename);
uniqueSubjects = unique(subjectIDs, 'stable');

if isempty(uniqueSubjects)
    error('RULA_Visualizer:NoTrials', 'No processed trials found in Project_data_v01.mat.');
end

jointNames = string(Settings.JointNames);
dimensionNames = string(Settings.Dimensionsjoint);
jointItems = cellstr(jointNames);
subjectItems = cellstr(uniqueSubjects);

thresholds = RULA_visualization_thresholds();

app = struct();
app.RepoRoot = repoRoot;
app.ConditionTable = ConditionTable;
app.Settings = Settings;
app.Data = Data;
app.JointNames = jointNames;
app.DimensionNames = dimensionNames;
app.MotionLabels = buildMotionLabels();
app.SubjectIDs = subjectIDs;
app.TrialNames = trialNames;
app.UniqueSubjects = uniqueSubjects;
app.Thresholds = thresholds;

app.Fig = uifigure('Name', 'RULA Visualizer', ...
    'Position', [100 100 1200 720]);
app.MainGrid = uigridlayout(app.Fig, [1 2], ...
    'ColumnWidth', {240, '1x'}, ...
    'RowHeight', {'1x'});

% Control panel
app.ControlPanel = uipanel(app.MainGrid, 'Title', 'Controls');
app.ControlPanel.Layout.Row = 1;
app.ControlPanel.Layout.Column = 1;
app.ControlGrid = uigridlayout(app.ControlPanel, [9 1], ...
    'RowHeight', {30,30,30,30,30,30,30,'1x',30}, ...
    'Padding', [10 10 10 10]);

uilabel(app.ControlGrid, 'Text', 'Subject:', ...
    'HorizontalAlignment', 'left');
app.SubjectDropdown = uidropdown(app.ControlGrid, ...
    'Items', subjectItems, ...
    'Value', subjectItems{1}, ...
    'ValueChangedFcn', @(src, evt)onSubjectChanged());

uilabel(app.ControlGrid, 'Text', 'Trial / File:', ...
    'HorizontalAlignment', 'left');
app.TrialDropdown = uidropdown(app.ControlGrid, ...
    'Items', {}, ...
    'ValueChangedFcn', @(src, evt)onTrialChanged());

uilabel(app.ControlGrid, 'Text', 'View:', ...
    'HorizontalAlignment', 'left');
app.ViewDropdown = uidropdown(app.ControlGrid, ...
    'Items', {'Time Series','Summary Statistics'}, ...
    'Value', 'Time Series', ...
    'ValueChangedFcn', @(src, evt)onViewChanged());

uilabel(app.ControlGrid, 'Text', 'Joint (time series):', ...
    'HorizontalAlignment', 'left');
app.JointList = uilistbox(app.ControlGrid, ...
    'Items', jointItems, ...
    'Value', jointItems{1}, ...
    'Multiselect', 'off');

app.PlotButton = uibutton(app.ControlGrid, 'Text', 'Generate Plot', ...
    'ButtonPushedFcn', @(src, evt)onPlotRequested());

app.ExportButton = uibutton(app.ControlGrid, 'Text', 'Save Figure...', ...
    'ButtonPushedFcn', @(src, evt)onExportFigure());

app.MessageLabel = uilabel(app.ControlGrid, ...
    'Text', '', ...
    'HorizontalAlignment', 'left', ...
    'WordWrap', 'on');

% Plot area
app.PlotPanel = uipanel(app.MainGrid, 'Title', 'Visualization');
app.PlotPanel.Layout.Row = 1;
app.PlotPanel.Layout.Column = 2;

% Housekeeping
onSubjectChanged();
onViewChanged();

    function onSubjectChanged()
        subject = string(app.SubjectDropdown.Value);
        matches = strcmp(app.SubjectIDs, subject);
        trials = unique(app.TrialNames(matches), 'stable');
        if isempty(trials)
            app.TrialDropdown.Items = {};
            app.TrialDropdown.Value = '';
            showMessage(sprintf('No trials located for subject %s.', subject), true);
        else
            trialItems = cellstr(trials);
            app.TrialDropdown.Items = trialItems;
            app.TrialDropdown.Value = trialItems{1};
            showMessage('', false);
        end
    end

    function onTrialChanged()
        % placeholder for future use (e.g., auto preview)
    end

    function onViewChanged()
        viewType = app.ViewDropdown.Value;
        if strcmp(viewType, 'Time Series')
            app.JointList.Enable = 'on';
            if isempty(app.JointList.Value)
                app.JointList.Value = app.JointList.Items{1};
            end
        else
            app.JointList.Enable = 'off';
        end
    end

    function onPlotRequested()
        if isempty(app.TrialDropdown.Value)
            showMessage('Select a trial before generating plots.', true);
            return;
        end
        viewType = app.ViewDropdown.Value;
        switch viewType
            case 'Time Series'
                jointLabel = string(app.JointList.Value);
                if jointLabel == ""
                    showMessage('Choose a joint for the time-series view.', true);
                    return;
                end
                try
                    plotTimeSeries(jointLabel);
                    showMessage('', false);
                catch ME
                    showMessage(ME.message, true);
                end
            case 'Summary Statistics'
                try
                    plotSummary();
                    showMessage('', false);
                catch ME
                    showMessage(ME.message, true);
                end
        end
    end

    function plotTimeSeries(jointLabel)
        idxJoint = find(app.JointNames == jointLabel, 1);
        if isempty(idxJoint)
            error('RULA_Visualizer:UnknownJoint', ...
                'Joint %s is not present in Settings.JointNames.', jointLabel);
        end
        trialName = string(app.TrialDropdown.Value);
        processedPath = fullfile(app.RepoRoot, '04_Processed', ...
            sprintf('%s_processed.mat', erase(trialName, ".mat")));
        if ~isfile(processedPath)
            error('RULA_Visualizer:MissingProcessed', ...
                'Processed file not found: %s', processedPath);
        end
        loadedTrial = load(processedPath, 'Data_tmp', 'Subject_tmp');
        if ~isfield(loadedTrial, 'Data_tmp')
            error('RULA_Visualizer:MissingDataTmp', ...
                'Data_tmp missing in %s. Re-run the pipeline.', processedPath);
        end
        Data_tmp = loadedTrial.Data_tmp;
        if isfield(Data_tmp, 'time') && ~isempty(Data_tmp.time)
            timeSeconds = (double(Data_tmp.time) - double(Data_tmp.time(1))) * 1e-3;
        elseif isfield(loadedTrial, 'Subject_tmp') && isfield(loadedTrial.Subject_tmp, 'Parameter')
            fs = loadedTrial.Subject_tmp.Parameter.frameRate;
            nSamples = size(Data_tmp.jointAngle, 1);
            timeSeconds = (0:nSamples-1).' / fs;
        else
            nSamples = size(Data_tmp.jointAngle, 1);
            timeSeconds = (0:nSamples-1).';
        end

        nDims = numel(app.DimensionNames);
        cols = (idxJoint - 1) * nDims + (1:nDims);
        jointAngles = Data_tmp.jointAngle(:, cols);

        delete(app.PlotPanel.Children);
        rowHeights = cell(1, nDims + 1);
        rowHeights{1} = 40;
        for rhIdx = 2:numel(rowHeights)
            rowHeights{rhIdx} = '1x';
        end
        colWidths = {42, '1x'};
        plotGrid = uigridlayout(app.PlotPanel, [nDims + 1 2], ...
            'RowHeight', rowHeights, ...
            'ColumnWidth', colWidths, ...
            'Padding', [10 10 10 10]);
        titleLabel = uilabel(plotGrid, ...
            'Text', char(jointLabel), ...
            'FontWeight', 'bold', ...
            'FontSize', 16, ...
            'HorizontalAlignment', 'center');
        titleLabel.Layout.Row = 1;
        titleLabel.Layout.Column = 2;

        labelAxes = uiaxes(plotGrid);
        labelAxes.Layout.Row = [2 nDims + 1];
        labelAxes.Layout.Column = 1;
        labelAxes.XLim = [0 1];
        labelAxes.YLim = [0 1];
        labelAxes.XTick = [];
        labelAxes.YTick = [];
        labelAxes.Color = 'none';
        labelAxes.XColor = 'none';
        labelAxes.YColor = 'none';
        labelAxes.Box = 'off';
        if isprop(labelAxes, 'Toolbar') && ~isempty(labelAxes.Toolbar)
            labelAxes.Toolbar.Visible = 'off';
        end
        if exist('disableDefaultInteractivity', 'file')
            disableDefaultInteractivity(labelAxes);
        end
        text(labelAxes, 0.5, 0.5, 'Degrees (°)', ...
            'Rotation', 90, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 12, ...
            'FontWeight', 'normal');

        for dimIdx = 1:nDims
            ax = uiaxes(plotGrid);
            ax.Layout.Row = dimIdx + 1;
            ax.Layout.Column = 2;
            grid(ax, 'on');
            hold(ax, 'on');

            dimName = app.DimensionNames(dimIdx);
            motionLabel = resolveMotionLabel(jointLabel, dimName);
            jointKey = char(jointLabel);
            dimKey = char(dimName);
            boundaryValues = [];
            if isfield(app.Thresholds, jointKey)
                jointThresholds = app.Thresholds.(jointKey);
                if isfield(jointThresholds, dimKey)
                    boundaryValues = jointThresholds.(dimKey);
                end
            end

            ySeries = jointAngles(:, dimIdx);
            [yMin, yMax] = computeYAxisLimits(ySeries, boundaryValues);
            ylim(ax, [yMin yMax]);

            xSpan = [timeSeconds(1) timeSeconds(end)];
            if xSpan(1) == xSpan(2)
                xSpan(2) = xSpan(2) + 1;
            end
            [shadeHandles, shadeLabels] = shadeRulaBands(ax, xSpan, [yMin yMax], boundaryValues);

            dataLine = plot(ax, timeSeconds, ySeries, 'LineWidth', 1.1, ...
                'Color', [0 0.4470 0.7410]);
            if exist('uistack', 'file')
                try
                    uistack(dataLine, 'top');
                catch
                end
            end

            if ~isempty(boundaryValues)
                for vIdx = 1:numel(boundaryValues)
                    v = boundaryValues(vIdx);
                    lineHandle = yline(ax, v, '--r', 'LineWidth', 1);
                    lineHandle.HandleVisibility = 'off';
                end
            end

            hold(ax, 'off');

            if dimIdx == numel(app.DimensionNames)
                xlabel(ax, 'Time (s)');
            end
            title(ax, motionLabel, 'Interpreter', 'none', ...
                'FontWeight', 'normal', 'FontSize', 12);

            if ~isempty(shadeHandles)
                leg = legend(ax, shadeHandles, shadeLabels, ...
                    'Location', 'bestoutside', 'AutoUpdate', 'off');
                if ~isempty(leg) && isvalid(leg)
                    leg.Title.String = 'RULA Subscore';
                end
            else
                legend(ax, 'off');
            end
        end
    end

    function plotSummary()
        trialName = string(app.TrialDropdown.Value);
        processedPath = fullfile(app.RepoRoot, '04_Processed', ...
            sprintf('%s_processed.mat', erase(trialName, ".mat")));
        if ~isfile(processedPath)
            error('RULA_Visualizer:MissingProcessed', ...
                'Processed file not found: %s', processedPath);
        end
        loadedTrial = load(processedPath, 'rula');
        if ~isfield(loadedTrial, 'rula')
            error('RULA_Visualizer:MissingRula', ...
                'RULA struct missing in %s. Re-run the pipeline.', processedPath);
        end
        rula = loadedTrial.rula;
        if ~isfield(rula, 's15_neck_trunk_leg_score')
            error('RULA_Visualizer:MissingStep15', ...
                'Step 15 results not found for trial %s.', trialName);
        end

        scores = rula.s15_neck_trunk_leg_score.total(:);
        scores = scores(~isnan(scores));
        if isempty(scores)
            error('RULA_Visualizer:NoScores', ...
                'No valid Step 15 scores available for %s.', trialName);
        end

        medScore = median(scores);
        lowerScore = prctile(scores, 25);
        upperScore = prctile(scores, 75);

        delete(app.PlotPanel.Children);
        plotGrid = uigridlayout(app.PlotPanel, [2 1], ...
            'RowHeight', {'1x', '1x'}, ...
            'Padding', [10 10 10 10]);

        axBar = uiaxes(plotGrid);
        bar(axBar, 1, medScore, 'FaceColor', [0.2 0.45 0.7]);
        hold(axBar, 'on');
        errorbar(axBar, 1, medScore, medScore - lowerScore, upperScore - medScore, ...
            'k', 'LineWidth', 1.2);
        hold(axBar, 'off');
        axBar.XTick = 1;
        axBar.XTickLabel = {'Overall RULA'};
        ylim(axBar, [0 max(7, upperScore + 1)]);
        ylabel(axBar, 'Score');
        title(axBar, sprintf('Median RULA Score (IQR: %.1f – %.1f)', lowerScore, upperScore));

        axHist = uiaxes(plotGrid);
        if isfield(rula.s15_neck_trunk_leg_score, 'total_rel')
            relData = rula.s15_neck_trunk_leg_score.total_rel;
            relData = relData(~any(isnan(relData),2), :);
            if ~isempty(relData)
                bar(axHist, relData(:,1), relData(:,2), 'FaceColor', [0.6 0.6 0.6]);
                xlabel(axHist, 'Score');
                ylabel(axHist, 'Relative duration');
                title(axHist, 'Score distribution (Step 15)');
                axHist.XTick = relData(:,1);
                return;
            end
        end
        histogram(axHist, scores, 'BinEdges', 0.5:1:8.5, 'FaceColor', [0.6 0.6 0.6]);
        xlabel(axHist, 'Score');
        ylabel(axHist, 'Occurrences');
        title(axHist, 'Score distribution (Step 15)');
        axHist.XTick = 1:8;
    end

    function labels = buildMotionLabels()
        labels = struct();

        labels = addJoint(labels, 'jL5S1', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Bending', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jL4L3', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jL1T12', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jT9T8', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jT1C7', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jC1Head', ...
            'abduction', 'Lateral Bending', ...
            'rotation', 'Axial Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightT4Shoulder', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightShoulder', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightElbow', ...
            'abduction', 'Ulnar Deviation/Radial Deviation', ...
            'rotation', 'Pronation/Supination', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightWrist', ...
            'abduction', 'Ulnar Deviation/Radial Deviation', ...
            'rotation', 'Pronation/Supination', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftT4Shoulder', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftShoulder', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftElbow', ...
            'abduction', 'Ulnar Deviation/Radial Deviation', ...
            'rotation', 'Pronation/Supination', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftWrist', ...
            'abduction', 'Ulnar Deviation/Radial Deviation', ...
            'rotation', 'Pronation/Supination', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightHip', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightKnee', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jRightAnkle', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Dorsiflexion/Plantarflexion');

        labels = addJoint(labels, 'jRightBallFoot', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftHip', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftKnee', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        labels = addJoint(labels, 'jLeftAnkle', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Dorsiflexion/Plantarflexion');

        labels = addJoint(labels, 'jLeftBallFoot', ...
            'abduction', 'Abduction/Adduction', ...
            'rotation', 'Internal/External Rotation', ...
            'flexion', 'Flexion/Extension');

        function outLabels = addJoint(inLabels, jointKey, varargin)
            outLabels = inLabels;
            if ~isfield(outLabels, jointKey)
                outLabels.(jointKey) = struct();
            end
            for idx = 1:2:numel(varargin)
                dimKey = varargin{idx};
                motion = varargin{idx+1};
                outLabels.(jointKey).(dimKey) = motion;
            end
        end
    end

    function label = resolveMotionLabel(jointLabel, dimName)
        jointKey = char(jointLabel);
        dimKey = char(dimName);
        if isfield(app.MotionLabels, jointKey)
            jointStruct = app.MotionLabels.(jointKey);
            if isfield(jointStruct, dimKey)
                stored = jointStruct.(dimKey);
                if ~isempty(stored)
                    label = stored;
                    return;
                end
            end
        end
        label = formatDimensionName(dimKey);
    end

    function [yMin, yMax] = computeYAxisLimits(series, boundaries)
        values = series(~isnan(series));
        values = values(:);
        if ~isempty(boundaries)
            boundaryVals = boundaries(~isnan(boundaries));
            values = [values; boundaryVals(:)];
        end
        if isempty(values)
            values = 0;
        end
        yMin = min(values);
        yMax = max(values);
        if yMin == yMax
            spread = max(1, abs(yMin) * 0.1 + 1);
            yMin = yMin - spread;
            yMax = yMax + spread;
        else
            margin = 0.05 * (yMax - yMin);
            if margin <= 0
                margin = 1;
            end
            yMin = yMin - margin;
            yMax = yMax + margin;
        end
    end

    function [handles, labels] = shadeRulaBands(ax, xSpan, yLimits, boundaries)
        handles = gobjects(0, 1);
        labels = {};
        if nargin < 4 || isempty(boundaries)
            boundaries = [];
        else
            boundaries = sort(unique(boundaries(~isnan(boundaries))));
        end
        binEdges = [-inf; boundaries(:); inf];
        numBands = numel(binEdges) - 1;
        if numBands < 1
            numBands = 1;
            binEdges = [-inf; inf];
        end
        greys = linspace(0.9, 0.4, numBands);
        for idx = 1:numBands
            lowerBound = binEdges(idx);
            upperBound = binEdges(idx + 1);
            yLower = yLimits(1);
            if isfinite(lowerBound)
                yLower = lowerBound;
            end
            yUpper = yLimits(2);
            if isfinite(upperBound)
                yUpper = upperBound;
            end
            if yUpper <= yLower
                continue;
            end
            grey = greys(idx);
            patchHandle = patch(ax, ...
                [xSpan(1) xSpan(2) xSpan(2) xSpan(1)], ...
                [yLower yLower yUpper yUpper], ...
                grey * ones(1, 3), ...
                'EdgeColor', 'none', ...
                'FaceAlpha', 0.18, ...
                'HandleVisibility', 'on');
            handles(end+1, 1) = patchHandle; %#ok<AGROW>
            labels{end+1, 1} = sprintf('%d', idx);
        end
    end

    function name = formatDimensionName(dimKey)
        switch lower(string(dimKey))
            case "abduction"
                name = 'Abduction/Adduction';
            case "rotation"
                name = 'Internal/External Rotation';
            case "flexion"
                name = 'Flexion/Extension';
            otherwise
                name = char(dimKey);
        end
    end

    function onExportFigure()
        if isempty(app.PlotPanel.Children)
            showMessage('Generate a plot before exporting.', true);
            return;
        end
        [file, path] = uiputfile({'*.png','PNG Image (*.png)'; ...
            '*.svg','SVG File (*.svg)'}, 'Save current figure as');
        if isequal(file, 0)
            return;
        end
        fullPath = fullfile(path, file);
        exportgraphics(app.PlotPanel, fullPath);
        showMessage(sprintf('Figure saved to %s', fullPath), false);
    end

    function showMessage(msg, isError)
        if nargin < 2
            isError = false;
        end
        app.MessageLabel.Text = msg;
        if isError
            app.MessageLabel.FontColor = [0.72 0.18 0.14];
        else
            app.MessageLabel.FontColor = [0.1 0.1 0.1];
        end
    end

end
