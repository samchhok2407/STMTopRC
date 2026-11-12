function S = run_deepbeam_one_hole(outRoot)
%RUN_DEEPBEAM_ONE_HOLE - RC deep beam with one 4 x 1 m hole, 2 x 1000 kN, ties at 0/45/90 deg.
%   Source: Starcev-Curcin et al. (2016), Tehnicki vjesnik 23(1), Fig. 8.
%   S = run_deepbeam_one_hole(outRoot) runs it; outRoot (absolute, optional) redirects the results.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

%% ===== MODEL ============================================================
p = struct();
p.width = 8000; p.height = 4000; p.P = 1000;  % P = 1000 kN per load point
p.nx    = 8;    p.ny     = 4;                 % 9 x 5 = 45 nodes at 1 m
p.Emod  = [200, 0; 0, 31];                    % kN/mm^2: Es = 200 GPa, Ec = 31 GPa
p.x0    = [0.01, 0.01]*645.16;                % 6.4516 mm^2 initial areas
p.units = 'kN, mm';
p.source = 'Starcev-Curcin et al. (2016), Tehnicki vjesnik 23(1), Table 1 / Fig. 8';

%% ===== DOMAIN ===========================================================
p.domain = struct('outer',  [0 0; 8000 0; 8000 4000; 0 4000], ...
                  'holes',  {{[2000 2000; 6000 2000; 6000 3000; 2000 3000]}}, ...
                  'xLines', 0:1000:8000, ...
                  'yLines', 0:1000:4000);
p.supports = [0 0 1 1; 8000 0 0 1];           % pin left, roller right
p.loads    = [3000 4000 0 -1000;              % 2 x 1000 kN
              5000 4000 0 -1000];
p.tieFrac  = 1.0; p.tieAngles = [0 45 90];    % paper's beta = 1 directions

%% ===== OPTIMIZER AND OUTPUT =============================================
p.volGroups = [1 2];        % separate tie / strut volume budgets
p.inactiveFactor = 1e-6;    % soft branch of each material (Engine default)
p.gsLevel   = Inf;          % every node connected to every node it can see
p.tolRel    = 1e-6;         % stop when max|dX| < tolRel * max area
p.alphaF    = 1e-4;  p.Nfilter = 350;   % discrete filter
p.plotGround    = true;      % candidate ground structure
p.plotBoundary  = true;      % domain outline and openings
p.plotLoads     = true;      % external forces: applied loads, supports, reactions
p.plotLabel     = 'force';   % internal forces: 'none', 'force' or 'area'
p.plotFontSize  = 16;        % figure text size (pt); default 11
p.label     = 'RC deep beam with one hole';
p.resultDir = 'deepbeam_one_hole';
%  Everything else is the Engine default (docs/parameter_guide.md).

%% ===== RUN ==============================================================
if nargin>=1 && ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
S = Engine(p);
end
