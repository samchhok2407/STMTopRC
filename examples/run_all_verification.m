function T = run_all_verification(outRoot)
%RUN_ALL_VERIFICATION - Regenerate every result reported in the manuscript.
%   run_all_verification runs the regression tests, the three panel cases, the
%   five deep-beam cases and the three members with openings, checks each one,
%   draws the convergence history (manuscript Fig. 6) and writes the common
%   summary results/verification.csv.  No source file is edited.
%
%   run_all_verification(outRoot) writes the case folders, the convergence
%   figure, verification.csv and execution.log under the absolute directory
%   outRoot instead, leaving
%   the shipped results/ untouched.
%
%   T is the summary table.  The function errors, after writing the table, if
%   any case fails a check.
% SPDX-License-Identifier: GPL-3.0-or-later
here = fileparts(mfilename('fullpath'));          % examples/
root = fileparts(here);                            % repository root
addpath(fullfile(root,'src'),here,fullfile(root,'tests'));

if nargin<1, outRoot = ''; end
outRoot = char(outRoot);
if isempty(outRoot)
    outDir = fullfile(root,'results');
elseif isempty(regexp(outRoot,'^([A-Za-z]:[\\/]|[\\/])','once'))
    error('run_all_verification:relativePath','outRoot must be an absolute path.');
else
    outDir = outRoot;
end
if ~exist(outDir,'dir'), mkdir(outDir); end

% RELEASE-REGRESSION BASELINES: the objectives this release recorded for the
% eleven cases, in run order (panel, deep beam, openings). They check that a
% rerun reproduces the release; they are NOT the published values of the
% source papers, which the manuscript compares separately.
JreleaseBaseline = [1.13642246142837; 1.13644099191565; 1.1794979197108
        0.00108740500420607; 0.00291500050117302; 0.001118734724952
        0.00132102954335499; 0.00112490843818602
        458517.371786859; 4540.63842641246; 458.009413287531];
tolJ = 1e-6;            % relative; allows for platform round-off, not a new design

logFile = fullfile(outDir,'execution.log');
if exist(logFile,'file'), delete(logFile); end
diary(logFile);
figVisible = get(groot,'defaultFigureVisible');
set(groot,'defaultFigureVisible','off');    % the layouts are saved, not shown
restore = onCleanup(@() cleanup(figVisible));
fprintf('MATLAB %s on %s\n',version,computer);

%% ===== REGRESSION TESTS =================================================
selftest_release;       % includes selftest_ZhaoAppendixB

%% ===== THE ELEVEN MANUSCRIPT CASES ======================================
%  One independent runner per case, in examples/; none needs editing.
panel  = {run_panel_1mat_1vol(outRoot), run_panel_2mat_1vol(outRoot), ...
          run_panel_2mat_2vol(outRoot)};
beam   = {run_deepbeam_tie_full_depth(outRoot), run_deepbeam_tie_23H(outRoot), ...
          run_deepbeam_tie_half_H(outRoot), run_deepbeam_tie_0_90(outRoot), ...
          run_deepbeam_tie_0_45_90(outRoot)};
hole   = {run_deepbeam_one_hole(outRoot), run_rc_beam_four_holes(outRoot), ...
          run_deepbeam_two_holes(outRoot)};
cases  = [panel, beam, hole];

%  Each runner drew its layout against its own largest bar.  Redraw the
%  deep-beam figures on ONE line-width scale, as printed.
Results.rescale(beam, 'maxWidth', 8, 'gamma', 0.5);

%  Convergence history of the shared-budget panel (manuscript Fig. 6)
close(convergence_history(panel{2}, outDir));

%% ===== CHECKS AND THE COMMON SUMMARY ====================================
n = numel(cases);
rows = cell(n,16);
today = char(datetime('today','Format','yyyy-MM-dd'));
for k=1:n
    S = cases{k};
    groups = S.parameters.volGroups(:);
    used = accumarray(groups,S.matVol(1:numel(groups)),[numel(S.Vmax),1]);
    volumeOK = all(used <= S.Vmax + 1e-8*max(S.Vmax,eps));
    connectivity = S.nDangle==0 && S.nIsolated==0 && S.nLoadIsolated==0;
    relDiff = abs(S.J-JreleaseBaseline(k))/abs(JreleaseBaseline(k));
    passed = S.converged && S.equilOK && volumeOK && connectivity && relDiff<=tolJ;
    rows(k,:) = {S.label,S.J,S.Z,S.nActive,S.nMerged,S.nIter,S.elapsedSeconds, ...
                 S.resid,S.converged,S.equilOK,connectivity,volumeOK, ...
                 JreleaseBaseline(k),relDiff,passed,today};
    if isgraphics(S.fig), close(S.fig); end
end
T = cell2table(rows,'VariableNames',{'Case','J','Z','Active','Displayed', ...
    'Iterations','Seconds','Residual','Converged','Equilibrium','Connectivity', ...
    'VolumeOK','ReleaseBaselineJ','BaselineRelDiffJ','Passed','VerifiedDate'});
writetable(T,fullfile(outDir,'verification.csv'));
disp(T);
fprintf('  summary written to: %s\n',fullfile(outDir,'verification.csv'));

failed = T.Case(~T.Passed);
if ~isempty(failed)
    error('run_all_verification:failed','%d of %d case(s) failed a check:\n    %s', ...
          numel(failed),n,strjoin(failed,sprintf('\n    ')));
end
fprintf('REGRESSION TESTS AND ALL %d MANUSCRIPT CASES PASSED\n',n);
end

function cleanup(figVisible)
set(groot,'defaultFigureVisible',figVisible);
diary off
end
