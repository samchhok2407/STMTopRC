function runs = run_validation_Zhang2018(outRoot)
%RUN_VALIDATION_ZHANG2018 - Zhang, Paulino & Ramos Jr. (2018), Example 1.
%   The three cases of Example 1 in one pass: Fig. 7(c), Fig. 8(c), Fig. 8(d).
%   Pass an absolute output root to keep results in a separate directory.
% SPDX-License-Identifier: GPL-3.0-or-later

if nargin<1, outRoot = ''; end

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));
runs = {};


%% ===== COMMON SETUP =====================================================
%  Identical for every block below.  Only the MATERIAL layout, the volume
%  constraints and the filter settings change from case to case.
E     = 1e7;                               % kPa, the paper's E
Vmax  = 0.15;                              % m^3, total prescribed volume

common = struct();
common.width = 30; common.height = 10; common.P = 100;
common.supports = [0, common.height/2, 1, 1; common.width, common.height/2, 1, 1];
common.loads = [ 7, common.height/2, 0,  common.P
                15, common.height/2, 0, -common.P
                23, common.height/2, 0,  common.P];
common.tolRel = 3e-4;
common.showZ  = false;                     % the paper reports J, not Z
common.units  = 'kN, m';
common.source = 'Zhang, Paulino & Ramos Jr. (2018), Example 1';
common.nx = 30;  common.ny = 10;
common.gsLevel = 10;                       % section 5.1 prescribes level 10
%  Everything else is the Engine default and is not restated here: alpha = 1.0,
%  tolOpt = 1e-9, doPlot = true, plotShowFrac = 0.02.  maxIter, Nfilter and
%  alphaF differ between the panels, so each block states its own -- alphaF in
%  particular, because it decides how many members survive to be drawn.


%% ===== Fig 7(c)  ONE bilinear material, ONE volume constraint ===========
%  Et = 7E in tension, Ec = 2E in compression, in a SINGLE material column.
%  Drawn in the paper's single-material brown rather than blue tie / red strut.
p = common;
p.Emod      = [7*E, 2*E];      % one row = one bilinear material
p.x0        = 0.01;
p.volGroups = 1;
p.Vmax      = Vmax;
p.maxIter   = 1000;
p.alphaF    = 1e-3;  p.Nfilter = 100;
p.barColor  = [0.545 0.353 0.169];      % the paper's single-material colour
p.label     = 'Zhang2018 Fig. 7(c)  --  1 material, 1 volume constraint';
p.resultDir = 'Zhang2018_Fig7c';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);


%% ===== Fig 8(c)  TWO one-sided materials sharing ONE constraint =========
%  The same problem split into a tension-only and a compression-only material
%  on a shared budget.  It should reproduce Fig. 7(c): that is the paper's own
%  consistency check on the multi-material formulation, and the table below
%  measures it.
p = common;
p.Emod      = [7*E, 0; 0, 2*E];         % two rows = two one-sided materials
p.x0        = [0.01 0.01];
p.volGroups = [1 1];                    % both in constraint 1: one shared budget
p.Vmax      = Vmax;
p.maxIter   = 600;
p.alphaF    = 1e-3;  p.Nfilter = 1;
p.label     = 'Zhang2018 Fig. 8(c)  --  2 materials, 1 volume constraint';
p.resultDir = 'Zhang2018_Fig8c';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);


%% ===== Fig 8(d)  TWO one-sided materials, a constraint EACH =============
%  Half the budget to each material.  This is a DIFFERENT problem from 8(c),
%  not a consistency check -- expect a different J.
p = common;
p.Emod      = [7*E, 0; 0, 2*E];
p.x0        = [0.01 0.01];
p.volGroups = [1 2];                    % one budget per material
p.Vmax      = [0.5 0.5]*Vmax;
p.maxIter   = 1000;
p.alphaF    = 1e-6;  p.Nfilter = 1;     % 1000x finer filter than the other two
p.label     = 'Zhang2018 Fig. 8(d)  --  2 materials, 2 volume constraints';
p.resultDir = 'Zhang2018_Fig8d';
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);


end
