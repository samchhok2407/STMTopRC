function S = run_panel_2mat_1vol(outRoot)
%RUN_PANEL_2MAT_1VOL - Panel, two one-sided materials sharing one volume constraint.
%   Source: Zhang, Paulino & Ramos Jr. (2018), Example 1, Fig. 8(c).
%   S = run_panel_2mat_1vol(outRoot) runs it; outRoot (absolute, optional) redirects the results.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

%% ===== MODEL ============================================================
E     = 1e7;                               % kPa, the paper's E
Vmax  = 0.15;                              % m^3, total prescribed volume

p = struct();
p.width = 30; p.height = 10; p.P = 100;
p.supports = [0, p.height/2, 1, 1; p.width, p.height/2, 1, 1];
p.loads = [ 7, p.height/2, 0,  p.P
           15, p.height/2, 0, -p.P
           23, p.height/2, 0,  p.P];
p.nx = 30;  p.ny = 10;
p.gsLevel = 10;                            % section 5.1 prescribes level 10
p.units  = 'kN, m';
p.source = 'Zhang, Paulino & Ramos Jr. (2018), Example 1';

%% ===== MATERIALS AND VOLUME =============================================
p.Emod      = [7*E, 0; 0, 2*E];         % two rows = two one-sided materials
p.x0        = [0.01 0.01];
p.volGroups = [1 1];                    % both in constraint 1: one shared budget
p.Vmax      = Vmax;

%% ===== OPTIMIZER AND OUTPUT =============================================
p.tolRel = 3e-4;
p.alphaF  = 1e-4;  p.Nfilter = 1;          % same filter in all three panel cases
p.showZ   = false;                         % the paper reports J, not Z
p.plotGround    = false;      % candidate ground structure
p.plotBoundary  = false;      % domain outline and openings
p.plotLoads     = false;      % external forces: applied loads, supports, reactions
p.plotLabel     = 'none';    % internal forces: 'none', 'force' or 'area'
p.label     = 'Zhang2018 Fig. 8(c)  --  2 materials, 1 volume constraint';
p.resultDir = 'Zhang2018_Fig8c';
%  Everything else is the Engine default and is not restated here.

%% ===== RUN ==============================================================
if nargin>=1 && ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
S = Engine(p);
end
