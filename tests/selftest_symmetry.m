function selftest_symmetry()
% Symmetry regression: averaging is applied only when supports, loads and
% domain mirror about x = width/2, and never when the user switches it off.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
p = struct('width',60,'height',15,'nx',8,'ny',2,'P',1, ...
           'Emod',[29007.5 0;0 4351.1],'x0',[.01 .01],'doPlot',false);
check(p,true,'default pin/roller deep beam');
q = p; q.tieFrac = 0.5; q.tieAngles = [0 45 90];
check(q,true,'tie band and tie angles (mirror-invariant)');
q = p; q.useSymmetry = false;
check(q,false,'symmetric problem, useSymmetry = false');
q = p; q.loads = [22.5 15 0 -1];
check(q,false,'load off mid-span');
q = p; q.supports = [0 0 1 1;60 0 0 1;15 0 1 0];
check(q,false,'unmirrored horizontal restraint');
q = p; q.domain = struct('outer',[0 0;60 0;60 15;0 15]);
check(q,false,'shaped domain (never averaged)');
fprintf('Symmetry detection PASSED: 2 symmetric and 4 non-averaged cases.\n');
end

function check(p,expected,name) %#ok<INUSD> p is used inside evalc
evalc('S = Engine(p);');
assert(S.symmetricLR==expected,'Symmetry detection failed: %s.',name);
end
