function runs = run_deepbeam_Ex1_to_Ex5(allCases,outRoot)
%RUN_DEEPBEAM_EX1_TO_EX5 - Deep-beam tie restrictions, Zhao et al. (2023) Fig. 1.
%   Pass true as the first argument to run every case.
% SPDX-License-Identifier: GPL-3.0-or-later
if nargin<1, allCases = false; end
if nargin<2, outRoot = ''; end
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));
runs = {};      % every block that runs appends one entry here

%% ===== COMMON SETUP =====================================================
common = struct();
common.width = 60; common.height = 15; common.P = 1;
common.nx    = 16; common.ny     = 4;      % Ex2 overrides with a coarser mesh
common.Emod = [29007.5, 0; 0, 4351.1]; common.x0 = [0.01, 0.01];
common.units = 'kip, in';
common.source = 'Zhao et al. (2023), Fig. 1(d,f,h,j,l)';
common.maxIter = 2000;  common.tolRel = 1e-6;
%  tolRel is what actually stops these runs.  tolOpt -- left at its default of
%  1e-9 -- is an ABSOLUTE test on max|dX|, and the bar areas here reach ~10, so
%  it demands 1e-10 relative precision, below the update's own noise floor.
%  With tolRel = 0 that test never fires: Ex1 runs to maxIter with max|dX|
%  jittering around 1.6e-8 (53% of steps GROW) while J has been flat to 6e-12
%  since iteration ~416 in the historical diagnostic run. Current numerical
%  results are recorded in results/verification.csv.
%
%  Everything else is the Engine default and is deliberately NOT restated here:
%  gsLevel = Inf (all-pairs), alphaF = 1e-4, Nfilter = 350, tolOpt = 1e-9,
%  alpha = 1.0, doPlot = true, plotShowFrac = 0.02 (hide members below 2% of
%  the largest area), Vmax = [] (automatic; at 16x4 this gives 493.34).
%  See the DEFAULTS block at the top of src/Engine.m.

%% ===== Ex1 ================================================= Fig. 1(d) ==
%  Ties unrestricted.  THE BASELINE the other four blocks are measured against.
p = common;
p.tieFrac   = 1.0; p.tieAngles = [];
p.label     = 'Ex1  --  deep beam, ties full depth, any angle';
p.resultDir = 'Ex1_deepbeam_full_depth';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

if allCases
%% ===== Ex2 ================================================= Fig. 1(f) ==
%  Ties below 2H/3.  Coarser mesh -> smaller budget, so J is not comparable.
p = common;
p.tieFrac   = 2/3; p.tieAngles = [];
p.nx        = 12;  p.ny = 3;           % coarser than common -> smaller budget
p.label     = 'Ex2  --  deep beam, ties below 2H/3';
p.resultDir = 'Ex2_deepbeam_tie_23H';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

%% ===== Ex3 ================================================= Fig. 1(h) ==
%  Ties below H/2 -- the tightest depth restriction.
p = common;
p.tieFrac   = 0.5; p.tieAngles = [];
p.label     = 'Ex3  --  deep beam, ties below H/2';
p.resultDir = 'Ex3_deepbeam_tie_half_H';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

%% ===== Ex4 ================================================= Fig. 1(j) ==
% Ties horizontal or vertical only -- the orthogonal mat tied on site.
p = common;
p.tieFrac   = 1.0; p.tieAngles = [0 90];
p.label     = 'Ex4  --  deep beam, ties at 0/90 deg';
p.resultDir = 'Ex4_deepbeam_tie_0_90';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

%% ===== Ex5 ================================================= Fig. 1(l) ==
%  Ex4 plus a diagonal lane -- what re-admitting the 45 deg bar buys.
p = common;
p.tieFrac   = 1.0; p.tieAngles = [0 45 90];
p.label     = 'Ex5  --  deep beam, ties at 0/45/90 deg';
p.resultDir = 'Ex5_deepbeam_tie_0_45_90';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

end

%% ===== ONE LINE-WIDTH SCALE OVER THE BLOCKS THAT RAN ====================
if numel(runs) > 1
    Results.rescale(runs, 'gamma', 0.5);
end

end
