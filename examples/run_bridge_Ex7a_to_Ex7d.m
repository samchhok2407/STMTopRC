function runs = run_bridge_Ex7a_to_Ex7d(allCases,outRoot)
%RUN_BRIDGE_EX7A_TO_EX7D - Long-span bridge modulus sweep, Zhang et al. (2017).
%   Pass false as the first argument to run only the first case.
% SPDX-License-Identifier: GPL-3.0-or-later
if nargin<1, allCases = true; end
if nargin<2, outRoot = ''; end
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src'));
runs = {};      % every block that runs appends one entry here

%% ===== COMMON SETUP =====================================================
%  Identical for every block below; only Emod(2) changes.
Et = 7e7;               % kN/m^2, tension modulus, the same in every block
common = struct();
common.width = 20; common.height = 5; common.P = 40;
common.x0 = 9.456817e-7;
common.Vmax = 0.05; common.volGroups = 1; % volume inferred from Table 3
common.etaMin = 0.5; common.etaMax = 0.5; % damping pinned: no adaptation
common.etaInc = 1.0; common.etaDec = 1.0;
common.units = 'kN, m';
common.source = ['Zhang, Ramos Jr. & Paulino (2017), Struct Multidisc Optim ' ...
                 '55:2045-2072, Example 2, Table 3'];
common.nx        = 18;   common.ny = 7;
xAll = (0:common.nx).'*(common.width/common.nx);
xs = xAll([0:4, 14:18] + 1); % five pinned nodes at each end
common.supports = [xs, zeros(numel(xs),1), ones(numel(xs),2)];
xl = xAll((5:13) + 1); % nine loaded nodes across the deck
common.loads = [xl, zeros(numel(xl),1), zeros(numel(xl),1), -common.P*ones(numel(xl),1)];
common.maxIter   = 6000;
common.alphaF    = 1e-4;                
common.Nfilter   = 1;
%  Everything else is the Engine default and is not restated here: gsLevel = Inf


%% ===== Ex7a  Material 1,  Ec/Et = 1 ======================== Fig. 13(a) ==
p = bridgeCase(common, Et, 1.0, 'Ex7a');
p.plotShowFrac = 0.01;
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

if allCases
%% ===== Ex7b  Material 2,  Ec/Et = 0.09 ===================== Fig. 13(b) ==
p = bridgeCase(common, Et, 0.09, 'Ex7b');
p.plotShowFrac = 0.005;
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);

%% ===== Ex7c  Material 3,  Ec/Et = 0.04 ===================== Fig. 13(c) ==
p = bridgeCase(common, Et, 0.04, 'Ex7c');
p.plotShowFrac = 0.005;
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);


%% ===== Ex7d  Material 4,  Ec/Et = 0.0225 =================== Fig. 13(d) ==
p = bridgeCase(common, Et, 0.0225, 'Ex7d');
p.plotShowFrac = 0.001;
if ~isempty(outRoot), p.resultDir = fullfile(outRoot,p.resultDir); end
runTimer = tic; runs{end+1} = Engine(p); runs{end}.elapsedSeconds = toc(runTimer);


end

%% ===== ONE LINE-WIDTH SCALE OVER THE BLOCKS THAT RAN ====================
if numel(runs) > 1
    Results.rescale(runs, 'maxWidth', 8, 'gamma', 0.5);
end

%% ===== READING THE RESULTS ==============================================
%  Cross-case tables -- the arch-to-suspension transition, tension against
%  compression member counts, aTop, residuals -- are NOT part of this runner.

end

function p = bridgeCase(common, Et, EcOverEt, tag)
% One modulus ratio.  Only Emod(2) and the output names change, so the four
% blocks cannot drift apart.
p        = common;
p.Emod   = [Et, EcOverEt*Et];
p.label  = sprintf('%s  --  long-span bridge, Ec/Et = %g', tag, EcOverEt);
p.resultDir = sprintf('Ex7_longspan_bridge/EcEt_%g', EcOverEt);
end
