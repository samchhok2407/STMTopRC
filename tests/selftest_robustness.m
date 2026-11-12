function R=selftest_robustness()
% Robustness regression: controlled failures and invariances.
%   1. a Newton solve that cannot converge stops the run (Engine:stateNotConverged)
%   2. the maxIter safeguard returns S.converged = false, stopReason 'maxIter'
%   3. the same physical problem in kN-m and N-mm gives the same design
%   4. tie restrictions are refused for the one-material bilinear model
%   5. a symmetric problem gives the same design with and without averaging
%   6. malformed optimizer settings are rejected
%   7. a load that is moved to the nearest node raises Engine:snapped
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
p = struct('width',60,'height',15,'nx',8,'ny',2,'P',1, ...
           'Emod',[29007.5 0;0 4351.1],'x0',[.01 .01],'doPlot',false);

% 1. Newton nonconvergence is an error, never a silent result
q = p; q.maxNR = 1;
mustFail(@() quiet(q),'Engine:stateNotConverged');

% 2. Optimization iteration safeguard
q = p; q.maxIter = 1;
S = quiet(q);
assert(~S.converged && strcmp(S.stopReason,'maxIter') && S.nIter==1, ...
       'maxIter safeguard did not flag the run as unconverged.');
S = quiet(p);
assert(S.converged && strcmp(S.stopReason,'converged') && S.stateInfo.converged);

% 3. Unit-system invariance: kN, m  versus  N, mm (stopping test relative only)
a = struct('width',2,'height',1,'nx',4,'ny',2,'P',10,'Emod',[200e6 0;0 30e6], ...
           'x0',[1e-4 1e-4],'tolOpt',0,'tolRel',1e-6,'doPlot',false);
b = a; b.width = 2000; b.height = 1000; b.P = 10e3;            % N, mm
b.Emod = a.Emod*1e-3; b.x0 = a.x0*1e6;                          % N/mm^2, mm^2
Sa = quiet(a); Sb = quiet(b);
R.du = norm(Sb.u/1e3 - Sa.u)/norm(Sa.u);
R.dF = norm(Sb.Fe/1e3 - Sa.Fe)/norm(Sa.Fe);
R.dJ = abs(Sb.J/1e6 - Sa.J)/abs(Sa.J);
R.dZ = abs(Sb.Z - Sa.Z)/abs(Sa.Z);
R.dX = norm(Sb.X(:)/1e6 - Sa.X(:))/norm(Sa.X(:));
R.dResid = abs(Sb.resid - Sa.resid);
assert(Sa.converged && Sb.converged && Sa.nIter==Sb.nIter, ...
       'Unit change altered convergence (%d vs %d iterations).',Sa.nIter,Sb.nIter);
% Forces, J, Z and areas agree to round-off. Displacements are resolved only
% to the Newton tolerance on the residual, and the soft inactive branches turn
% that into a larger displacement difference, hence the looser bound on u
assert(max([R.dF R.dJ R.dZ R.dX])<1e-8 && R.du<1e-6 && R.dResid<1e-10, ...
       'Unit change altered the result.');

% 4. One bilinear material: tie restrictions would delete struts too
q = p; q.Emod = [29007.5 4351.1]; q.x0 = .01; q.tieFrac = 0.5;
mustFail(@() quiet(q),'Engine:tieRestrictionRequiresTwoMaterials');
q.tieFrac = 1; q.tieAngles = [0 90];
mustFail(@() quiet(q),'Engine:tieRestrictionRequiresTwoMaterials');

% 5. Symmetry averaging must not change the design of a symmetric problem
S1 = quiet(p);
q = p; q.useSymmetry = false; S0 = quiet(q);
assert(S1.symmetricLR && ~S0.symmetricLR);
R.dJsym = abs(S1.J-S0.J)/abs(S1.J);
R.dXmirror = max(abs(S0.X(:)-reshape(S0.X(S0.barMirror,:),[],1)))/max(S0.X(:));
R.dXsym = max(abs(S1.X(:)-S0.X(:)))/max(S1.X(:));
assert(R.dJsym<1e-6 && R.dXmirror<1e-4 && R.dXsym<1e-4, ...
       'Averaged and unaveraged symmetric designs differ.');

% 6. Input validation of optimizer settings
q = p; q.etaMin = 0.9; q.etaMax = 0.5;
mustFail(@() quiet(q),'Engine:invalidDamping');
q = p; q.doPlot = [true false];
mustFail(@() quiet(q),'Engine:invalidFlag');
q = p; q.gsLevel = 2.5;
mustFail(@() quiet(q),'Engine:invalidLevel');
for bad = {{'alphaF',1},{'Nfilter',-1},{'tolOpt',-1},{'GammaFactor',-1}, ...
           {'moveFactor',0},{'tieAngles',[0 200]},{'plotShowFrac',2}}
    q = p; q.(bad{1}{1}) = bad{1}{2};
    mustFail(@() quiet(q),'');
end

% 7. Snapping a load to the nearest node is reported
q = p; q.loads = [31 15 0 -1];          % nodes every 7.5 in: 30 is nearest
lastwarn('');
quiet(q);                               % evalc keeps the warning text off screen
[~,id] = lastwarn;
assert(strcmp(id,'Engine:snapped'),'A snapped load was not reported.');

fprintf(['Robustness PASSED: Newton failure stops the run, maxIter flagged, ' ...
         'units kN-m vs N-mm max rel. diff (F, J, Z, X) %.1e, one-material tie limits refused, ' ...
         'symmetry J diff %.1e, input checks.\n'], ...
        max([R.dF R.dJ R.dZ R.dX]),R.dJsym);
end

function S=quiet(p) %#ok<INUSD> p is used inside evalc
% Run Engine without its iteration printout
[~,S] = evalc('Engine(p)');
end

function mustFail(f,id)
% f must error; with a nonempty id, with exactly that identifier
try
    f();
catch ME
    assert(isempty(id) || strcmp(ME.identifier,id),'Unexpected error: %s (%s)',ME.identifier,ME.message);
    return
end
error('selftest:missingError','Expected an error%s.',id);
end
