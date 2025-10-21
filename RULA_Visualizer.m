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
subjectKeys = cellstr(uniqueSubjects);
subjectLabels = cellfun(@formatSubjectLabel, subjectKeys, 'UniformOutput', false);

app = struct();
app.RepoRoot = repoRoot;
app.ConditionTable = ConditionTable;
app.Settings = Settings;
app.Data = Data;
app.JointNames = jointNames;
app.DimensionNames = dimensionNames;
app.SubjectIDs = subjectIDs;
app.TrialNames = trialNames;
app.UniqueSubjects = uniqueSubjects;
thresholds = RULA_visualization_thresholds();
app.Thresholds = thresholds;
app.StepDefinitions = buildStepDefinitions(Settings);

app.Fig = uifigure('Name', 'RULA Visualizer', ...
    'Position', [100 100 1200 720]);
app.MainGrid = uigridlayout(app.Fig, [1 2], ...
    'ColumnWidth', {240, '1x'}, ...
    'RowHeight', {'1x'});

% Control panel
app.ControlPanel = uipanel(app.MainGrid, 'Title', 'Controls');
app.ControlPanel.Layout.Row = 1;
app.ControlPanel.Layout.Column = 1;
app.ControlGrid = uigridlayout(app.ControlPanel, [11 1], ...
    'RowHeight', {30,30,30,30,30,30,30,30,'1x',30,30}, ...
    'Padding', [10 10 10 10]);

subjectLabel = uilabel(app.ControlGrid, 'Text', 'Subject Selection:', ...
    'HorizontalAlignment', 'left');
subjectLabel.Layout.Row = 1;
app.SubjectDropdown = uidropdown(app.ControlGrid, ...
    'Items', subjectLabels, ...
    'ItemsData', subjectKeys, ...
    'Value', subjectKeys{1}, ...
    'ValueChangedFcn', @(src, evt)onSubjectChanged());
app.SubjectDropdown.Layout.Row = 2;

trialLabel = uilabel(app.ControlGrid, 'Text', 'Trial Selection:', ...
    'HorizontalAlignment', 'left');
trialLabel.Layout.Row = 3;
app.TrialDropdown = uidropdown(app.ControlGrid, ...
    'Items', {}, ...
    'ItemsData', {}, ...
    'ValueChangedFcn', @(src, evt)onTrialChanged());
app.TrialDropdown.Layout.Row = 4;

viewLabel = uilabel(app.ControlGrid, 'Text', 'View Data:', ...
    'HorizontalAlignment', 'left');
viewLabel.Layout.Row = 5;
app.ViewDropdown = uidropdown(app.ControlGrid, ...
    'Items', {'Time Series','Summary Statistics'}, ...
    'Value', 'Time Series', ...
    'ValueChangedFcn', @(src, evt)onViewChanged());
app.ViewDropdown.Layout.Row = 6;

stepLabel = uilabel(app.ControlGrid, 'Text', 'RULA Step:', ...
    'HorizontalAlignment', 'left');
stepLabel.Layout.Row = 7;
stepDefs = app.StepDefinitions;
stepItems = {stepDefs.Label};
stepKeys = {stepDefs.Key};
if isempty(stepKeys)
    stepItems = {''};
    stepKeys = {''};
end
app.StepDropdown = uidropdown(app.ControlGrid, ...
    'Items', stepItems, ...
    'ItemsData', stepKeys, ...
    'ValueChangedFcn', @(src, evt)onStepChanged());
app.StepDropdown.Layout.Row = 8;
if ~isempty(stepKeys) && ~strcmp(stepKeys{1}, '')
    app.StepDropdown.Value = stepKeys{1};
else
    app.StepDropdown.Enable = 'off';
end

app.MessageLabel = uilabel(app.ControlGrid, ...
    'Text', '', ...
    'HorizontalAlignment', 'left', ...
    'WordWrap', 'on');
app.MessageLabel.Layout.Row = 9;

app.PlotButton = uibutton(app.ControlGrid, 'Text', 'Generate Plot', ...
    'ButtonPushedFcn', @(src, evt)onPlotRequested());
app.PlotButton.Layout.Row = 10;

app.ExportButton = uibutton(app.ControlGrid, 'Text', 'Save Figure...', ...
    'ButtonPushedFcn', @(src, evt)onExportFigure());
app.ExportButton.Layout.Row = 11;

% Plot area
app.PlotPanel = uipanel(app.MainGrid, 'Title', 'Visualization');
app.PlotPanel.Layout.Row = 1;
app.PlotPanel.Layout.Column = 2;

% Housekeeping
onSubjectChanged();
onViewChanged();

    function onSubjectChanged()
        subjectKey = string(app.SubjectDropdown.Value);
        matches = (app.SubjectIDs == subjectKey);
        trials = unique(app.TrialNames(matches), 'stable');
        if isempty(trials)
            app.TrialDropdown.Items = {};
            app.TrialDropdown.ItemsData = {};
            app.TrialDropdown.Value = '';
            app.TrialDropdown.Enable = 'off';
            showMessage(sprintf('No trials located for %s.', formatSubjectLabel(subjectKey)), true);
            return;
        end

        trialKeys = cellstr(trials);
        trialLabels = cellfun(@formatTrialLabel, trialKeys, 'UniformOutput', false);
        app.TrialDropdown.Items = trialLabels;
        app.TrialDropdown.ItemsData = trialKeys;
        app.TrialDropdown.Value = trialKeys{1};
        app.TrialDropdown.Enable = 'on';
        showMessage('', false);
        onTrialChanged();
    end

    function onTrialChanged()
        % placeholder for future use (e.g., auto preview)
    end

    function onViewChanged()
        viewType = app.ViewDropdown.Value;
        if strcmp(viewType, 'Time Series')
            if isvalidControl(app.StepDropdown)
                app.StepDropdown.Enable = 'on';
            end
        else
            if isvalidControl(app.StepDropdown)
                app.StepDropdown.Enable = 'off';
            end
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
                stepKey = "";
                if isvalidControl(app.StepDropdown) && strcmp(app.StepDropdown.Enable, 'on')
                    stepKey = string(app.StepDropdown.Value);
                end
                if stepKey == ""
                    showMessage('Choose a RULA step for the time-series view.', true);
                    return;
                end
                try
                    plotTimeSeries(stepKey);
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

    function plotTimeSeries(stepKey)
        def = getStepDefinition(stepKey);
        if isempty(def) || ~isfield(def, 'Key')
            error('RULA_Visualizer:UnknownStep', ...
                'RULA step "%s" is not available for plotting.', stepKey);
        end
        if isempty(app.TrialDropdown.Value)
            error('RULA_Visualizer:NoTrial', ...
                'Select a trial before generating plots.');
        end

        trialName = string(app.TrialDropdown.Value);
        processedPath = fullfile(app.RepoRoot, '04_Processed', ...
            sprintf('%s_processed.mat', erase(trialName, ".mat")));
        if ~isfile(processedPath)
            error('RULA_Visualizer:MissingProcessed', ...
                'Processed file not found: %s', processedPath);
        end

        loadedTrial = load(processedPath, 'Data_tmp', 'Subject_tmp', 'rula');
        if ~isfield(loadedTrial, 'Data_tmp')
            error('RULA_Visualizer:MissingDataTmp', ...
                'Data_tmp missing in %s. Re-run the pipeline.', processedPath);
        end
        if ~isfield(loadedTrial, 'rula')
            error('RULA_Visualizer:MissingRula', ...
                'RULA struct missing in %s. Re-run the pipeline.', processedPath);
        end

        Data_tmp = loadedTrial.Data_tmp;
        if isfield(loadedTrial, 'Subject_tmp')
            Subject_tmp = loadedTrial.Subject_tmp;
        else
            Subject_tmp = struct();
        end
        rula = loadedTrial.rula;

        timeSeconds = deriveTimeVector(Data_tmp, Subject_tmp);
        ctx = struct('Data', Data_tmp, ...
            'Subject', Subject_tmp, ...
            'Rula', rula, ...
            'Settings', app.Settings);

        components = computeStepComponents(def, ctx);
        if isempty(components)
            error('RULA_Visualizer:NoComponents', ...
                'No time-series data are available for %s.', def.Label);
        end

        maxPlotPoints = 6000;

        delete(app.PlotPanel.Children);
        plotGrid = uigridlayout(app.PlotPanel, [numel(components) + 1, 1], ...
            'Padding', [10 10 10 10]);
        rowHeights = [{40}, repmat({'1x'}, 1, numel(components))];
        plotGrid.RowHeight = rowHeights;

        titleLabel = uilabel(plotGrid, ...
            'Text', def.Label, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 16);
        titleLabel.Layout.Row = 1;
        titleLabel.Layout.Column = 1;

        for compIdx = 1:numel(components)
            comp = components(compIdx);
            ax = uiaxes(plotGrid);
            ax.Layout.Row = compIdx + 1;
            ax.Layout.Column = 1;
            grid(ax, 'on');
            hold(ax, 'on');

            yLimits = computeYLimits(comp.values, comp.threshold);
            if isempty(yLimits) || numel(yLimits) ~= 2 || any(~isfinite(yLimits))
                baseSpan = comp.values(~isnan(comp.values));
                if isempty(baseSpan)
                    yLimits = [-1 1];
                else
                    yLimits = [min(baseSpan), max(baseSpan)];
                    if yLimits(1) == yLimits(2)
                        yLimits = yLimits + [-1 1];
                    end
                end
            end
            if yLimits(2) <= yLimits(1)
                center = mean(yLimits);
                spread = max(1, abs(diff(yLimits))/2 + 1);
                yLimits = [center - spread, center + spread];
            end
            ylim(ax, yLimits);

            xSpan = [timeSeconds(1) timeSeconds(end)];
            if xSpan(1) == xSpan(2)
                xSpan(2) = xSpan(2) + 1;
            end
            [bandHandles, bandLabels] = applyThresholdBands(ax, xSpan, yLimits, comp.threshold, comp.values);

            [plotTimes, plotValues] = downsampleSeries(timeSeconds, comp.values, maxPlotPoints);
            dataLine = plot(ax, plotTimes, plotValues, ...
                'LineWidth', 1.1, 'Color', [0 0.4470 0.7410]);
            if exist('uistack', 'file')
                try %#ok<TRYNC>
                    uistack(dataLine, 'top');
                end
            end

            if ~isempty(bandHandles)
                leg = legend(ax, bandHandles, bandLabels, ...
                    'Location', 'eastoutside', ...
                    'AutoUpdate', 'off');
                if ~isempty(leg) && isvalid(leg)
                    try %#ok<TRYNC>
                        title(leg, 'RULA Subscore');
                    end
                    leg.Interpreter = 'none';
                end
            else
                legend(ax, 'off');
            end

            hold(ax, 'off');
            ylabel(ax, comp.yLabel, 'Interpreter', 'none');
            if compIdx == numel(components)
                xlabel(ax, 'Time (s)');
            else
                xlabel(ax, '');
            end
            title(ax, comp.label, 'Interpreter', 'none', ...
                'FontWeight', 'normal', 'FontSize', 12);
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
        summaryGrid = uigridlayout(app.PlotPanel, [2 1], ...
            'RowHeight', {'2x', '1x'}, ...
            'ColumnWidth', {'1x'}, ...
            'Padding', [10 10 10 10], ...
            'RowSpacing', 12);

        finalTogetherFull = reshape(rula.final_score.together, [], 1);
        finalTogetherFull = finalTogetherFull(~isnan(finalTogetherFull));
        if isempty(finalTogetherFull)
            error('RULA_Visualizer:NoFinalScores', ...
                'No final RULA scores are available for %s.', trialName);
        end

        axHist = uiaxes(summaryGrid);
        axHist.Layout.Row = 1;
        axHist.Layout.Column = 1;
        binEdges = 0.5:1:7.5;
        cappedScores = min(finalTogetherFull, 7);
        counts = histcounts(cappedScores, binEdges);
        totalSamples = sum(counts);
        relCounts = counts / max(totalSamples, 1) * 100;
        colorAcceptable = [0.20 0.60 0.20];
        colorInvestigate = [1.00 0.84 0.00];
        colorChangeSoon = [0.91 0.45 0.13];
        colorImmediate = [0.80 0.20 0.20];
        colors = [
            colorAcceptable;
            colorAcceptable;
            colorInvestigate;
            colorInvestigate;
            colorChangeSoon;
            colorChangeSoon;
            colorImmediate];
        bar(axHist, 1:7, relCounts, 'FaceColor', 'flat', ...
            'CData', colors, 'EdgeColor', 'none');
        maxPerc = max(relCounts);
        upperPerc = max(maxPerc * 1.15, 1);
        hold(axHist, 'on');
        text(axHist, 1:7, relCounts + upperPerc*0.08, ...
            arrayfun(@(v)sprintf('%.1f%%', v), relCounts, 'UniformOutput', false), ...
            'HorizontalAlignment', 'center', 'FontSize', 10);
        axHist.XTick = 1:7;
        axHist.XLim = [0.5 7.5];
        xlabel(axHist, 'RULA Score');
        ylabel(axHist, 'Relative occurrence (%)');
        title(axHist, 'Overall RULA Score Distribution');
        ylim(axHist, [0 upperPerc]);

        legendEntries = {
            '1-2 Acceptable', colorAcceptable;
            '3-4 Investigate further', colorInvestigate;
            '5-6 Investigate/change soon', colorChangeSoon;
            '7 Immediate action', colorImmediate}
            ;
        legendHandles = gobjects(size(legendEntries,1),1);
        for idx = 1:size(legendEntries,1)
            legendHandles(idx) = plot(axHist, NaN, NaN, 's', ...
                'MarkerFaceColor', legendEntries{idx,2}, ...
                'MarkerEdgeColor', 'none', 'LineStyle', 'none', 'MarkerSize', 9);
        end
        leg = legend(axHist, legendHandles, legendEntries(:,1), ...
            'Location', 'northwest', 'Interpreter', 'none', 'Box', 'on');
        if ~isempty(leg) && isvalid(leg)
            leg.Title.String = 'Ergonomic Risk';
            leg.ItemTokenSize = [18 9];
        end
        hold(axHist, 'off');

        axBar = uiaxes(summaryGrid);
        axBar.Layout.Row = 2;
        axBar.Layout.Column = 1;
        subjectLabel = "Unknown";
        if exist('Subject_tmp', 'var') && isfield(Subject_tmp, 'SubjectID') && ~isempty(Subject_tmp.SubjectID)
            subjectLabel = string(Subject_tmp.SubjectID);
        else
            matchIdx = find(app.TrialNames == trialName, 1);
            if ~isempty(matchIdx)
                subjectLabel = string(app.ConditionTable.SubjectID(matchIdx));
            end
        end
        trialLabelRaw = strrep(trialName, '_processed.mat', '');
        meta = parseTrialMetadata(trialLabelRaw);

        subjectValue = 'Unknown';
        trialValue = 'Unknown';
        dateValue = 'Unknown';

        if meta.IsValid
            subjectDigits = regexp(meta.Subject, '\d+', 'match', 'once');
            if ~isempty(subjectDigits)
                numVal = str2double(subjectDigits);
                if ~isnan(numVal)
                    subjectDigits = sprintf('%02d', numVal);
                end
                subjectValue = subjectDigits;
            else
                subjectValue = meta.Subject;
            end

            trialDigits = meta.TrialNumber;
            numVal = str2double(trialDigits);
            if ~isnan(numVal)
                trialDigits = sprintf('%02d', numVal);
            end
            trialValue = trialDigits;
            dateValue = meta.Date;
        else
            subjectDigits = regexp(char(subjectLabel), '\d+', 'match', 'once');
            if ~isempty(subjectDigits)
                numVal = str2double(subjectDigits);
                if ~isnan(numVal)
                    subjectDigits = sprintf('%02d', numVal);
                end
                subjectValue = subjectDigits;
            else
                subjectValue = char(subjectLabel);
            end

            trialDigits = regexp(trialLabelRaw, '(\d+)', 'tokens');
            if ~isempty(trialDigits)
                trialStr = trialDigits{end}{1};
                numVal = str2double(trialStr);
                if ~isnan(numVal)
                    trialStr = sprintf('%02d', numVal);
                end
                trialValue = trialStr;
            else
                trialValue = trialLabelRaw;
            end
        end

        xLabelSummary = sprintf('Subject: %s | Trial: %s | Date: %s', subjectValue, trialValue, dateValue);
        medTogether = median(cappedScores);
        q1 = prctile(cappedScores, 25);
        q3 = prctile(cappedScores, 75);
        errLow = medTogether - q1;
        errHigh = q3 - medTogether;
        bar(axBar, 1, medTogether, 'FaceColor', [0.20 0.45 0.85], 'EdgeColor', 'none');
        hold(axBar, 'on');
        errorbar(axBar, 1, medTogether, errLow, errHigh, ...
            'Color', [0.1 0.3 0.1], 'LineWidth', 1.4, 'CapSize', 12);
        hold(axBar, 'off');
        axBar.XTick = 1;
        axBar.XTickLabel = {xLabelSummary};
        ylim(axBar, [0 max(7, medTogether + errHigh + 1)]);
        ylabel(axBar, 'Median score');
        title(axBar, sprintf('Overall Median RULA Score (IQR %.1f – %.1f)', q1, q3));

    end

    function onStepChanged(~, ~)
        % Placeholder for future interactive behaviour.
    end

    function def = getStepDefinition(stepKey)
        def = struct();
        if isempty(stepKey)
            return;
        end
        keys = {app.StepDefinitions.Key};
        idx = find(strcmp(keys, stepKey), 1);
        if ~isempty(idx)
            def = app.StepDefinitions(idx);
        end
    end

    function components = computeStepComponents(def, ctx)
        components = struct('label', {}, 'values', {}, 'yLabel', {}, 'threshold', {});

        numDims = numel(app.DimensionNames);
        sideKey = char(def.Side);

        jointIdxMap.right = struct('t4shoulder', 7, 'shoulder', 8, 'elbow', 9, 'wrist', 10);
        jointIdxMap.left  = struct('t4shoulder', 11, 'shoulder', 12, 'elbow', 13, 'wrist', 14);
        jointIdxMap.neck  = struct('neck', 5, 'head', 6);
        jointIdxMap.trunk = [1 2 3 4];
        segmentIdx.T8 = 5;

        switch def.Step
            case 1
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).shoulder, 3, ...
                    fetchLimits({'s1_upper_arm_pos_hist', sideKey, 'part', 'flex_ext'}), 'Flex/Extension'));
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).shoulder, 1, ...
                    fetchLimits({'s1_upper_arm_pos_hist', sideKey, 'part', 'abd'}), 'Abduction/Adduction'));
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).t4shoulder, 1, ...
                    fetchLimits({'s1_upper_arm_pos_hist', sideKey, 'part', 'ele'}), 'Shoulder Elevation'));
            case 2
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).elbow, 3, ...
                    fetchLimits({'s2_lower_arm_pos_hist', sideKey, 'part', 'flex_ext'}), 'Flex/Extension'));
                components = appendComponent(components, makeForearmOffsetComponent(jointIdxMap.(sideKey).wrist, ...
                    fetchLimits({'s2_lower_arm_pos_hist', sideKey, 'part', 'pos2center'}), sideKey, segmentIdx.T8));
            case 3
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).wrist, 3, ...
                    fetchLimits({'s3_wrist_pos_hist', sideKey, 'part', 'flex_ext'}), 'Flex/Extension'));
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).wrist, 1, ...
                    fetchLimits({'s3_wrist_pos_hist', sideKey, 'part', 'dev'}), 'Deviation'));
            case 4
                components = appendComponent(components, makeAngleComponent(jointIdxMap.(sideKey).wrist, 2, ...
                    fetchLimits({'s4_wrist_pos_hist', sideKey, 'part', 'twist'}), 'Pronation/Supination'));
            case 5
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Wrist & Arm Posture Score', capitalizeSide(sideKey)), ...
                    fetchVector({'s5_arm_post_score', sideKey, 'total'}), 'Score'));
            case 6
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Step 6 Static Condition', capitalizeSide(sideKey)), ...
                    fetchVector({'s6_arm_muscle_use', sideKey, 'part', 'static'}), 'Flag (0/1)'));
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Step 6 Repetitive Condition', capitalizeSide(sideKey)), ...
                    fetchVector({'s6_arm_muscle_use', sideKey, 'part', 'repetitiv'}), 'Flag (0/1)'));
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Step 6 Score', capitalizeSide(sideKey)), ...
                    fetchVector({'s6_arm_muscle_use', sideKey, 'part', 'total_shoulder'}), 'Score'));
            case 7
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Step 7 Load Adjustment', capitalizeSide(sideKey)), ...
                    fetchVector({'s7_arm_muscle_load', sideKey, 'total'}), 'Score'));
            case 8
                components = appendComponent(components, makeScoreComponent( ...
                    sprintf('%s Step 8 Wrist/Arm Score', capitalizeSide(sideKey)), ...
                    fetchVector({'s8_wrist_arm_score', sideKey, 'total'}), 'Score'));
            case 9
                neckIndices = [jointIdxMap.neck.neck, jointIdxMap.neck.head];
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Neck Flex/Extension', neckIndices, 3, fetchLimits({'s9_neck_pos_hist', 'part', 'flex_ext'})));
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Neck Twist', neckIndices, 2, fetchLimits({'s9_neck_pos_hist', 'part', 'twist'})));
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Neck Lateral Bending', neckIndices, 1, fetchLimits({'s9_neck_pos_hist', 'part', 'lat'})));
            case 10
                trunkIndices = jointIdxMap.trunk;
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Trunk Flex/Extension', trunkIndices, 3, fetchLimits({'s10_trunk_pos_hist', 'part', 'flex_ext'})));
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Trunk Twist', trunkIndices, 2, fetchLimits({'s10_trunk_pos_hist', 'part', 'twist'})));
                components = appendComponent(components, makeCombinedAngleComponent( ...
                    'Trunk Lateral Bending', trunkIndices, 1, fetchLimits({'s10_trunk_pos_hist', 'part', 'lat'})));
            case 11
                components = appendComponent(components, makeScoreComponent( ...
                    'Step 11 Leg Score', fetchVector({'s11_leg_pos', 'total'}), 'Score'));
            case 12
                components = appendComponent(components, makeScoreComponent( ...
                    'Step 12 Trunk/Neck/Leg Posture Score', fetchVector({'s12_trunk_neck_leg_post_score', 'total'}), 'Score'));
            case 13
                components = appendComponent(components, makeScoreComponent( ...
                    'Neck Muscle Use Flag', fetchVector({'s13_trunk_neck_muscle_use', 'neck'}), 'Flag (0/1)'));
                components = appendComponent(components, makeScoreComponent( ...
                    'Trunk Muscle Use Flag', fetchVector({'s13_trunk_neck_muscle_use', 'trunk'}), 'Flag (0/1)'));
                components = appendComponent(components, makeScoreComponent( ...
                    'Step 13 Score', fetchVector({'s13_trunk_neck_muscle_use', 'total'}), 'Flag (0/1)'));
            case 14
                components = appendComponent(components, makeScoreComponent( ...
                    'Step 14 Load Adjustment', fetchVector({'s14_trunk_neck_muscle_use', 'total'}), 'Score'));
            case 15
                components = appendComponent(components, makeScoreComponent( ...
                    'Step 15 Neck/Trunk/Leg Score', fetchVector({'s15_neck_trunk_leg_score', 'total'}), 'Score'));
        end

        function comp = makeAngleComponent(jointIdx, dimIdx, limits, suffix)
            comp = [];
            if isempty(jointIdx) || jointIdx < 1 || jointIdx > numel(ctx.Settings.JointNames)
                return;
            end
            values = ensureColumn(double(ctx.Data.jointAngle(:, (jointIdx - 1) * numDims + dimIdx)));
            label = sprintf('%s %s', formatJointName(ctx.Settings.JointNames{jointIdx}), suffix);
            comp = baseComponent(label, values, 'Degrees (°)', createLimitThreshold(limits));
        end

        function comp = makeCombinedAngleComponent(label, jointIdxList, dimIdx, limits)
            comp = [];
            if isempty(jointIdxList)
                return;
            end
            values = zeros(size(ctx.Data.jointAngle, 1), 1);
            for ii = 1:numel(jointIdxList)
                idx = jointIdxList(ii);
                if idx < 1 || idx > numel(ctx.Settings.JointNames)
                    continue;
                end
                values = values + ensureColumn(double(ctx.Data.jointAngle(:, (idx - 1) * numDims + dimIdx)));
            end
            comp = baseComponent(label, values, 'Degrees (°)', createLimitThreshold(limits));
        end

        function comp = makeForearmOffsetComponent(wristIdx, limits, sideKeyLocal, t8Idx)
            comp = [];
            values = computeForearmOffset(ctx, wristIdx, t8Idx);
            if isempty(values)
                return;
            end
            label = sprintf('%s Forearm Offset', capitalizeSide(sideKeyLocal));
            comp = baseComponent(label, values, 'Metres', createLimitThreshold(limits));
        end

        function comp = makeScoreComponent(label, values, unit)
            if nargin < 3 || isempty(unit)
                unit = 'Score';
            end
            values = ensureColumn(double(values));
            if isempty(values)
                comp = [];
            else
                comp = baseComponent(label, values, unit, createScoreThreshold(values));
            end
        end

        function comp = baseComponent(label, values, yLabel, threshold)
            comp.label = label;
            comp.values = values;
            comp.yLabel = yLabel;
            comp.threshold = threshold;
        end

        function list = appendComponent(list, comp)
            if isempty(comp)
                return;
            end
            list(end+1) = comp; %#ok<AGROW>
        end

        function limits = fetchLimits(pathCells)
            try
                limits = getfield(ctx.Rula, pathCells{:}, 'limits'); %#ok<GFLD>
            catch
                limits = [];
            end
        end

        function values = fetchVector(pathCells)
            try
                values = getfield(ctx.Rula, pathCells{:}); %#ok<GFLD>
            catch
                values = [];
            end
        end
    end

    function yLimits = computeYLimits(values, threshold)
        v = values(~isnan(values));
        if isempty(v)
            v = 0;
        end
        yMin = min(v);
        yMax = max(v);

        if nargin > 1 && isstruct(threshold)
            switch threshold.mode
                case 'limits'
                    limits = threshold.limits;
                    if ~isempty(limits)
                        finiteBounds = [limits(isfinite(limits(:,1)),1); limits(isfinite(limits(:,2)),2)];
                        if ~isempty(finiteBounds)
                            yMin = min([yMin; finiteBounds]);
                            yMax = max([yMax; finiteBounds]);
                        end
                    end
                case 'scores'
                    scores = threshold.scores;
                    if ~isempty(scores)
                        yMin = min([yMin; scores(:)]);
                        yMax = max([yMax; scores(:)]);
                    end
            end
        end

        if yMin == yMax
            if nargin > 1 && isstruct(threshold) && strcmp(threshold.mode, 'scores')
                yMin = yMin - 0.5;
                yMax = yMax + 0.5;
            else
                spread = max(1, abs(yMin) * 0.1 + 1);
                yMin = yMin - spread;
                yMax = yMax + spread;
            end
        else
            if nargin > 1 && isstruct(threshold) && strcmp(threshold.mode, 'scores')
                yMin = yMin - 0.5;
                yMax = yMax + 0.5;
            else
                margin = 0.05 * (yMax - yMin);
                if margin <= 0
                    margin = 1;
                end
                yMin = yMin - margin;
                yMax = yMax + margin;
            end
        end

        yLimits = [yMin, yMax];
    end

    function [patchHandles, patchLabels] = applyThresholdBands(ax, xSpan, yLimits, threshold, values)
        patchHandles = gobjects(0, 1);
        patchLabels = {};

        if nargin < 4 || isempty(threshold) || ~isstruct(threshold) || strcmp(threshold.mode, 'none')
            return;
        end
        if nargin < 5
            values = [];
        end

        valueData = double(values(:));
        finiteData = valueData(isfinite(valueData));
        dataExists = ~isempty(finiteData);
        dataMin = -inf;
        dataMax = inf;
        if dataExists
            dataMin = min(finiteData);
            dataMax = max(finiteData);
        end
        bandTol = 0;
        if dataExists
            span = dataMax - dataMin;
            bandTol = max(1e-6, 0.015 * max(1, abs(span)));
        end

        switch threshold.mode
            case 'limits'
                limits = threshold.limits;
                if isempty(limits)
                    return;
                end
                scores = limits(:, 3);
                finiteScores = scores(isfinite(scores));
                if isempty(finiteScores)
                    finiteScores = 0;
                end
                minScore = min(finiteScores);
                maxScore = max(finiteScores);
                for idx = 1:size(limits, 1)
                    lower = limits(idx, 1);
                    upper = limits(idx, 2);
                    score = limits(idx, 3);
                    yLower = isfinite(lower) * lower + (~isfinite(lower)) * yLimits(1);
                    yUpper = isfinite(upper) * upper + (~isfinite(upper)) * yLimits(2);
                    if yUpper <= yLower
                        continue;
                    end
                    lowerBound = lower;
                    upperBound = upper;
                    bandColor = scoreToColor(score, minScore, maxScore);
                    edgeColor = darkenColor(bandColor, 0.65);
                    if isfinite(lower)
                        yline(ax, lower, '--', 'Color', edgeColor, 'LineWidth', 1, 'HandleVisibility', 'off');
                    end
                    if isfinite(upper)
                        yline(ax, upper, '--', 'Color', edgeColor, 'LineWidth', 1, 'HandleVisibility', 'off');
                    end

                    dataInBand = finiteData;
                    if dataExists
                        if isfinite(lowerBound)
                            dataInBand = dataInBand(dataInBand >= lowerBound - bandTol);
                        end
                        if isfinite(upperBound)
                            dataInBand = dataInBand(dataInBand <= upperBound + bandTol);
                        end
                    end
                    if isempty(dataInBand)
                        continue;
                    end
                    bandMin = min(dataInBand);
                    bandMax = max(dataInBand);
                    if isfinite(lowerBound) && ~isfinite(upperBound)
                        yLowerVis = max(yLower, lowerBound);
                    else
                        yLowerVis = max(yLower, bandMin - bandTol);
                    end
                    if isfinite(upperBound) && ~isfinite(lowerBound)
                        yUpperVis = min(yUpper, upperBound);
                    else
                        yUpperVis = min(yUpper, bandMax + bandTol);
                    end
                    if yUpperVis <= yLowerVis
                        continue;
                    end
                    patchHandles(end+1, 1) = patch(ax, ...
                        [xSpan(1) xSpan(2) xSpan(2) xSpan(1)], ...
                        [yLowerVis yLowerVis yUpperVis yUpperVis], ...
                        bandColor, ...
                        'EdgeColor', 'none', ...
                        'FaceAlpha', 0.32, ...
                        'HandleVisibility', 'on'); %#ok<AGROW>
                    patchLabels{end+1, 1} = sprintf('Subscore %g (%s to %s)', score, ...
                        formatBound(lower), formatBound(upper)); %#ok<AGROW>
                end
            case 'scores'
                scores = threshold.scores;
                if isempty(scores)
                    return;
                end
                scores = sort(scores(:).');
                minScore = scores(1);
                maxScore = scores(end);
                boundaries = [scores - 0.5, scores(end) + 0.5];
                for idx = 1:numel(scores)
                    lower = boundaries(idx);
                    upper = boundaries(idx + 1);
                    yLower = max(lower, yLimits(1));
                    yUpper = min(upper, yLimits(2));
                    if yUpper <= yLower
                        continue;
                    end
                    lowerBound = lower;
                    upperBound = upper;
                    bandColor = scoreToColor(scores(idx), minScore, maxScore);
                    dataInBand = finiteData;
                    if dataExists
                        if isfinite(lowerBound)
                            dataInBand = dataInBand(dataInBand >= lowerBound - bandTol);
                        end
                        if isfinite(upperBound)
                            dataInBand = dataInBand(dataInBand <= upperBound + bandTol);
                        end
                    end
                    if ~isempty(dataInBand)
                        bandMin = min(dataInBand);
                        bandMax = max(dataInBand);
                        yLowerVis = max(yLower, bandMin - bandTol);
                        yUpperVis = min(yUpper, bandMax + bandTol);
                        if yUpperVis <= yLowerVis
                            continue;
                        end
                        patchHandles(end+1, 1) = patch(ax, ...
                            [xSpan(1) xSpan(2) xSpan(2) xSpan(1)], ...
                            [yLowerVis yLowerVis yUpperVis yUpperVis], ...
                            bandColor, ...
                            'EdgeColor', 'none', ...
                            'FaceAlpha', 0.32, ...
                            'HandleVisibility', 'on'); %#ok<AGROW>
                        patchLabels{end+1, 1} = sprintf('Subscore %s', formatNumeric(scores(idx))); %#ok<AGROW>
                    end
                end
                for idx = 2:numel(boundaries) - 1
                    scoreLeft = scores(idx - 1);
                    scoreRight = scores(idx);
                    midScore = (scoreLeft + scoreRight) / 2;
                    lineColor = darkenColor(scoreToColor(midScore, minScore, maxScore), 0.65);
                    yline(ax, boundaries(idx), '--', 'Color', lineColor, 'LineWidth', 1, 'HandleVisibility', 'off');
                end
        end

        function color = scoreToColor(score, minScore, maxScore)
            if ~isfinite(score)
                score = maxScore;
            end
            if maxScore <= minScore
                t = 0.5;
            else
                t = (score - minScore) / (maxScore - minScore);
            end
            t = max(0, min(1, t));
            baseStops = [
                0.12 0.55 0.25;  % green
                0.95 0.85 0.20;  % amber
                0.78 0.18 0.15   % red
            ];
            color = interpolateStops(baseStops, t);
        end

        function color = darkenColor(color, factor)
            color = max(0, min(1, color * factor));
        end

        function color = interpolateStops(stops, t)
            if isempty(stops)
                color = [0.5 0.5 0.5];
                return;
            end
            nStops = size(stops, 1);
            if nStops == 1
                color = stops(1, :);
                return;
            end
            tScaled = t * (nStops - 1) + 1;
            idxLow = floor(tScaled);
            idxHigh = ceil(tScaled);
            idxLow = max(1, min(nStops, idxLow));
            idxHigh = max(1, min(nStops, idxHigh));
            frac = tScaled - idxLow;
            if idxLow == idxHigh
                color = stops(idxLow, :);
            else
                color = (1 - frac) * stops(idxLow, :) + frac * stops(idxHigh, :);
            end
        end
    end

    function threshold = createLimitThreshold(limits)
        if isempty(limits)
            threshold = struct('mode', 'none');
        else
            threshold = struct('mode', 'limits', 'limits', double(limits));
        end
    end

    function threshold = createScoreThreshold(values)
        scores = unique(values(~isnan(values)));
        if isempty(scores)
            threshold = struct('mode', 'none');
            return;
        end
        scores = double(scores(:).');
        maxDiscreteBands = 8;
        finiteScores = scores(isfinite(scores));
        if numel(scores) <= maxDiscreteBands && numel(finiteScores) <= maxDiscreteBands
            threshold = struct('mode', 'scores', 'scores', scores);
            return;
        end

        if isempty(finiteScores)
            threshold = struct('mode', 'scores', 'scores', scores(1));
            return;
        end

        numBands = min(maxDiscreteBands, max(3, ceil(numel(finiteScores) / 25)));
        edges = linspace(min(finiteScores), max(finiteScores), numBands + 1);
        mids = (edges(1:end-1) + edges(2:end)) / 2;
        limits = [edges(1:end-1).' edges(2:end).'];
        limits(:,3) = mids.';
        limits(1,1) = -inf;
        limits(end,2) = inf;
        threshold = struct('mode', 'limits', 'limits', limits);
    end

    function value = computeForearmOffset(ctx, wristIdx, t8Idx)
        value = [];
        if ~isfield(ctx.Data, 'position') || isempty(ctx.Data.position)
            return;
        end
        pos = ctx.Data.position;
        cols = size(pos, 2);
        if wristIdx < 1 || 3 * wristIdx > cols || t8Idx < 1 || 3 * t8Idx > cols
            return;
        end
        wristXY = pos(:, (wristIdx - 1) * 3 + (1:2));
        t8XY = pos(:, (t8Idx - 1) * 3 + (1:2));
        delta = wristXY - t8XY;

        if isfield(ctx.Data, 'orientation') && ~isempty(ctx.Data.orientation)
            quats = ctx.Data.orientation(:, (t8Idx - 1) * 4 + (1:4));
            yawDeg = computeSegmentYawDegrees(quats);
        else
            yawDeg = zeros(size(delta, 1), 1);
        end

        theta = -yawDeg;
        value = ensureColumn(delta(:,1) .* sind(theta) + delta(:,2) .* cosd(theta));
    end

    function yawDeg = computeSegmentYawDegrees(quats)
        if isempty(quats)
            yawDeg = 0;
            return;
        end
        qw = quats(:,1); qx = quats(:,2); qy = quats(:,3); qz = quats(:,4);
        yawDeg = rad2deg(atan2(2 * (qw .* qz + qx .* qy), 1 - 2 * (qy.^2 + qz.^2)));
    end

    function arr = ensureColumn(arr)
        arr = double(arr(:));
    end

    function [tOut, vOut] = downsampleSeries(tIn, vIn, maxPoints)
        if nargin < 3 || isempty(maxPoints) || maxPoints <= 0
            maxPoints = numel(tIn);
        end
        if isempty(tIn) || isempty(vIn)
            tOut = tIn;
            vOut = vIn;
            return;
        end
        n = min(numel(tIn), numel(vIn));
        tBase = tIn(1:n);
        vBase = ensureColumn(vIn(1:n));
        if n <= maxPoints
            tOut = tBase;
            vOut = vBase;
            return;
        end
        idx = unique(round(linspace(1, n, maxPoints)));
        idx(idx < 1) = 1;
        idx(idx > n) = n;
        tOut = tBase(idx);
        vOut = vBase(idx);
    end

    function name = formatJointName(raw)
        if isempty(raw)
            name = '';
            return;
        end
        if raw(1) == 'j'
            raw = raw(2:end);
        end
        name = regexprep(raw, '([a-z])([A-Z])', '$1 $2');
        name = strrep(name, '_', ' ');
    end

    function text = capitalizeSide(side)
        if isempty(side)
            text = '';
            return;
        end
        if isstring(side)
            side = char(side);
        end
        firstChar = upper(side(1));
        if numel(side) > 1
            rest = lower(side(2:end));
        else
            rest = '';
        end
        text = [firstChar rest];
    end

    function label = formatSubjectLabel(subjectKey)
        keyChar = char(subjectKey);
        keyChar = strtrim(keyChar);

        numStr = '';
        token = regexp(keyChar, 'Subject\s*#?\s*(\d+)', 'tokens', 'once');
        if ~isempty(token)
            numStr = token{1};
        end
        if isempty(numStr)
            token = regexp(keyChar, 'P(\d+)', 'tokens', 'once');
            if ~isempty(token)
                numStr = token{1};
            end
        end
        if isempty(numStr)
            numStr = regexp(keyChar, '\d+', 'match', 'once');
        end

        if ~isempty(numStr)
            numVal = str2double(numStr);
            if ~isnan(numVal)
                label = sprintf('Subject #%02d', numVal);
            else
                label = sprintf('Subject #%s', numStr);
            end
        else
            label = sprintf('Subject %s', keyChar);
        end
    end

    function label = formatTrialLabel(trialKey)
        meta = parseTrialMetadata(trialKey);
        if meta.IsValid
            trialNum = meta.TrialNumber;
            numVal = str2double(trialNum);
            if ~isnan(numVal)
                trialNum = sprintf('%02d', numVal);
            end
            label = sprintf('Trial #%s', trialNum);
        else
            label = char(trialKey);
        end
    end

    function meta = parseTrialMetadata(name)
        meta = struct('Subject', '', 'Date', '', 'TrialNumber', '', 'IsValid', false);
        base = char(name);
        base = regexprep(base, '\.[^.]+$', '');
        base = regexprep(base, '_processed$', '');
        tokens = regexp(base, '^(P\d+)[_-](\d{2}-\d{2}-\d{4})[-_](\d+)$', 'tokens', 'once');
        if isempty(tokens)
            return;
        end
        meta.Subject = tokens{1};
        meta.Date = tokens{2};
        meta.TrialNumber = tokens{3};
        meta.IsValid = true;
    end

    function text = formatBound(value)
        if isfinite(value)
            text = formatNumeric(value);
        elseif value < 0
            text = '-Inf';
        else
            text = 'Inf';
        end
    end

    function text = formatNumeric(val)
        if abs(val) >= 100 || abs(val) < 0.01
            text = sprintf('%.2g', val);
        else
            text = sprintf('%.2f', val);
        end
    end

    function timeSeconds = deriveTimeVector(Data_tmp, Subject_tmp)
        if isfield(Data_tmp, 'time') && ~isempty(Data_tmp.time)
            base = double(Data_tmp.time);
            timeSeconds = (base - base(1)) * 1e-3;
        elseif isfield(Subject_tmp, 'Parameter') && isfield(Subject_tmp.Parameter, 'frameRate')
            fs = Subject_tmp.Parameter.frameRate;
            nSamples = size(Data_tmp.jointAngle, 1);
            timeSeconds = (0:nSamples-1).' / fs;
        else
            nSamples = size(Data_tmp.jointAngle, 1);
            timeSeconds = (0:nSamples-1).' / 60;
        end
    end

    function defs = buildStepDefinitions(~)
        defs = struct('Key', {}, 'Label', {}, 'Step', {}, 'Side', {});
        defs = addDef(defs, 'step1_right', 'Step 1 – Upper Arm (Right)', 1, 'right');
        defs = addDef(defs, 'step1_left',  'Step 1 – Upper Arm (Left)', 1, 'left');
        defs = addDef(defs, 'step2_right', 'Step 2 – Lower Arm (Right)', 2, 'right');
        defs = addDef(defs, 'step2_left',  'Step 2 – Lower Arm (Left)', 2, 'left');
        defs = addDef(defs, 'step3_right', 'Step 3 – Wrist (Right)', 3, 'right');
        defs = addDef(defs, 'step3_left',  'Step 3 – Wrist (Left)', 3, 'left');
        defs = addDef(defs, 'step4_right', 'Step 4 – Wrist Twist (Right)', 4, 'right');
        defs = addDef(defs, 'step4_left',  'Step 4 – Wrist Twist (Left)', 4, 'left');
        defs = addDef(defs, 'step5_right', 'Step 5 – Wrist/Arm Posture Score (Right)', 5, 'right');
        defs = addDef(defs, 'step5_left',  'Step 5 – Wrist/Arm Posture Score (Left)', 5, 'left');
        defs = addDef(defs, 'step6_right', 'Step 6 – Muscle Use (Right)', 6, 'right');
        defs = addDef(defs, 'step6_left',  'Step 6 – Muscle Use (Left)', 6, 'left');
        defs = addDef(defs, 'step7_right', 'Step 7 – Load/Force (Right)', 7, 'right');
        defs = addDef(defs, 'step7_left',  'Step 7 – Load/Force (Left)', 7, 'left');
        defs = addDef(defs, 'step8_right', 'Step 8 – Wrist/Arm Score (Right)', 8, 'right');
        defs = addDef(defs, 'step8_left',  'Step 8 – Wrist/Arm Score (Left)', 8, 'left');
        defs = addDef(defs, 'step9',       'Step 9 – Neck', 9, '');
        defs = addDef(defs, 'step10',      'Step 10 – Trunk', 10, '');
        defs = addDef(defs, 'step11',      'Step 11 – Legs', 11, '');
        defs = addDef(defs, 'step12',      'Step 12 – Trunk/Neck/Leg Posture Score', 12, '');
        defs = addDef(defs, 'step13',      'Step 13 – Muscle Use (Neck/Trunk)', 13, '');
        defs = addDef(defs, 'step14',      'Step 14 – Load/Force (Neck/Trunk)', 14, '');
        defs = addDef(defs, 'step15',      'Step 15 – Neck/Trunk/Leg Score', 15, '');
    end

    function defs = addDef(defs, key, label, stepNumber, side)
        entry.Key = key;
        entry.Label = label;
        entry.Step = stepNumber;
        if nargin < 5
            entry.Side = '';
        else
            entry.Side = side;
        end
        defs(end+1) = entry; %#ok<AGROW>
    end

    function tf = isvalidControl(ctrl)
        tf = ~isempty(ctrl) && isgraphics(ctrl) && isvalid(ctrl);
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
