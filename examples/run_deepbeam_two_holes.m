function S = run_deepbeam_two_holes(outRoot)
%RUN_DEEPBEAM_TWO_HOLES - RC deep beam with two 400 x 400 mm holes (W1), 2 x 100 kN.
%   Source: Starcev-Curcin et al. (2020), Appl. Sci. 10, 6217, Fig. 6 (W1).
%   S = run_deepbeam_two_holes(outRoot) runs it; outRoot (absolute, optional) redirects the results.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

%% ===== MODEL ============================================================
p = struct();
p.width = 1800; p.height = 1200; p.P = 100;   % P = 100 kN per load point
p.nx    = 9;    p.ny     = 6;                 % 10 x 7 nodes at 200 mm
p.Emod  = [200, 0; 0, 31];                    % kN/mm^2: B500 steel ties, C25/30 struts
p.x0    = [0.01, 0.01]*645.16;                % 6.4516 mm^2 initial areas
p.units = 'kN, mm';
p.source = 'Starcev-Curcin et al. (2020), Appl. Sci. 10, 6217, Fig. 6 (W1)';

%% ===== DOMAIN ===========================================================
% Openings: cells 1-3 and 6-8 across, 1-3 up (interior node of each removed)
p.domain = struct('outer',  [0 0; 1800 0; 1800 1200; 0 1200], ... 
                  'holes',  {{[ 200 200;  600 200;  600 600;  200 600], ...
                              [1200 200; 1600 200; 1600 600; 1200 600]}}, ...
                  'xLines', 0:200:1800, ...
                  'yLines', 0:200:1200);
p.supports = [0 0 1 1; 1800 0 0 1];           % pin left, roller right
p.loads    = [ 600 1200 0 -100;               % 2 x 100 kN at the thirds of the span
              1200 1200 0 -100];
p.tieFrac  = 1.0; p.tieAngles = [];           % ties anywhere, any angle

%% ===== OPTIMIZER AND OUTPUT =============================================
p.volGroups = [1 2];        % separate tie / strut volume budgets
p.inactiveFactor = 1e-3;    % not the 1e-6 default: 1e-3 reproduces the published
                            % W1 layout (see docs/examples.md)
p.gsLevel   = Inf;          % every node connected to every node it can see
p.tolRel    = 1e-6;         % stop when max|dX| < tolRel * max area
p.alphaF    = 1e-4;  p.Nfilter = 350;   % discrete filter
p.plotGround    = true;      % candidate ground structure
p.plotBoundary  = true;      % domain outline and openings
p.plotLoads     = true;      % external forces: applied loads, supports, reactions
p.plotLabel     = 'force';   % internal forces: 'none', 'force' or 'area'
p.plotFontSize  = 16;        % figure text size (pt); default 11
p.label     = 'RC deep beam with two holes (W1)';
p.resultDir = 'deepbeam_two_holes';
%  Everything else is the Engine default (docs/parameter_guide.md).

%% ===== RUN ==============================================================
if nargin>=1 && ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
S = Engine(p);
end
