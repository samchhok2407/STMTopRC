function S = run_deepbeam_tie_half_H(outRoot)
%RUN_DEEPBEAM_TIE_HALF_H - Deep beam, ties below H/2.
%   Source: Zhao et al. (2023), Fig. 1(h).
%   S = run_deepbeam_tie_half_H(outRoot) runs it; outRoot (absolute, optional) redirects the results.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

%% ===== MODEL ============================================================
p = struct();
p.width = 60; p.height = 15; p.P = 1;
p.nx    = 16; p.ny     = 4;
p.Emod  = [29007.5, 0; 0, 4351.1]; p.x0 = [0.01, 0.01];
p.units = 'kip, in';
p.source = 'Zhao et al. (2023), Fig. 1(h)';

%% ===== TIE RESTRICTION ==================================================
p.tieFrac   = 0.5; p.tieAngles = [];      % ties below H/2, any angle

%% ===== OPTIMIZER AND OUTPUT =============================================
p.tolRel = 1e-6;
p.plotGround    = false;      % candidate ground structure
p.plotBoundary  = true;      % domain outline and openings
p.plotLoads     = false;      % external forces: applied loads, supports, reactions
p.plotLabel     = 'none';    % internal forces: 'none', 'force' or 'area'
p.plotMaxWidth  = 8;         % line width added at the largest area (default 5)
p.label     = 'Ex3  --  deep beam, ties below H/2';
p.resultDir = 'Ex3_deepbeam_tie_half_H';
%  Everything else is the Engine default and is not restated here.

%% ===== RUN ==============================================================
if nargin>=1 && ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
S = Engine(p);
end
