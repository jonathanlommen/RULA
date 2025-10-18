function thresholds = RULA_visualization_thresholds()
%RULA_VISUALIZATION_THRESHOLDS Return reference boundaries for key joints.
%   thresholds = RULA_visualization_thresholds() builds a struct mapping the
%   MVNX joint labels used within the RULA workflow to vectors of breakpoints
%   for each degree of freedom. These values mirror the limits applied inside
%   RULA_calc_scores and are used purely for plotting reference lines in the
%   visualisation GUI.
%
%   The struct is organised as:
%       thresholds.<jointLabel>.<dimension> = [breakpoints]
%
%   Dimensions follow Settings.Dimensionsjoint:
%       abduction  -> column 1 of jointAngle
%       rotation   -> column 2 of jointAngle
%       flexion    -> column 3 of jointAngle

thresholds = struct();

% Helper for reducing repetition when populating symmetric joints.
shoulderFlex = [-20 20 45 90];
shoulderAbd  = [45];
wristFlex    = [-15 -5 5 15];
wristDev     = [-10 10];
wristRot     = [-45 45];
elbowFlex    = [60 100];
neckFlex     = [0 10 20];
neckTwist    = [-10 10];
trunkFlex    = [0 20 60];
trunkTwist   = [-10 10];

thresholds.jRightShoulder.abduction = shoulderAbd;
thresholds.jRightShoulder.rotation  = [];
thresholds.jRightShoulder.flexion   = shoulderFlex;

thresholds.jLeftShoulder.abduction = shoulderAbd;
thresholds.jLeftShoulder.rotation  = [];
thresholds.jLeftShoulder.flexion   = shoulderFlex;

thresholds.jRightElbow.abduction = [];
thresholds.jRightElbow.rotation  = [];
thresholds.jRightElbow.flexion   = elbowFlex;

thresholds.jLeftElbow.abduction = [];
thresholds.jLeftElbow.rotation  = [];
thresholds.jLeftElbow.flexion   = elbowFlex;

thresholds.jRightWrist.abduction = wristDev;
thresholds.jRightWrist.rotation  = wristRot;
thresholds.jRightWrist.flexion   = wristFlex;

thresholds.jLeftWrist.abduction = wristDev;
thresholds.jLeftWrist.rotation  = wristRot;
thresholds.jLeftWrist.flexion   = wristFlex;

% Neck and trunk reference values use the summed joint angles from the
% original RULA implementation, so these breakpoints are approximate guides.
thresholds.jT1C7.abduction = [];
thresholds.jT1C7.rotation  = neckTwist;
thresholds.jT1C7.flexion   = neckFlex;

thresholds.jL5S1.abduction = [];
thresholds.jL5S1.rotation  = trunkTwist;
thresholds.jL5S1.flexion   = trunkFlex;

end
