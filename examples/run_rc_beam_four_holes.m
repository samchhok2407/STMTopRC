function S = run_rc_beam_four_holes(outRoot)
%RUN_RC_BEAM_FOUR_HOLES - RC beam with four 0.4 m holes, 3 x 100 kN, ties at 0/45/90 deg.
%   Source: Starcev-Curcin et al. (2016), Tehnicki vjesnik 23(1), Fig. 10.
%   S = run_rc_beam_four_holes(outRoot) runs it; outRoot (absolute, optional) redirects the results.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));

%% ===== MODEL ============================================================
p = struct();
p.width = 7200; p.height = 1200; p.P = 100;   % P = 100 kN per load point
p.nx    = 18;   p.ny     = 3;                 % 19 x 4 nodes at 400 mm
p.Emod  = [200, 0; 0, 30];                    % kN/mm^2: Es = 200 GPa, Ec = 30 GPa
p.x0    = [0.01, 0.01]*645.16;                % 6.4516 mm^2 initial areas
p.units = 'kN, mm';
p.source = 'Starcev-Curcin et al. (2016), Tehnicki vjesnik 23(1), Table 3 / Fig. 10';

%% ===== DOMAIN ===========================================================
hole = @(x) [x 400; x+400 400; x+400 800; x 800];
p.domain = struct('outer',  [0 0; 7200 0; 7200 1200; 0 1200], ...
                  'holes',  {{hole(800), hole(2400), hole(4400), hole(6000)}}, ...
                  'xLines', 0:400:7200, ...
                  'yLines', 0:400:1200);
p.supports = [0 0 1 1; 7200 0 0 1];           % pin left, roller right
p.loads    = [1200 1200 0 -100;               % 3 x 100 kN
              3600 1200 0 -100;
              6000 1200 0 -100];
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
p.label     = 'RC beam with four holes';
p.resultDir = 'rc_beam_four_holes';
%  Everything else is the Engine default (docs/parameter_guide.md).

%% ===== RUN ==============================================================
if nargin>=1 && ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
S = Engine(p);
end
