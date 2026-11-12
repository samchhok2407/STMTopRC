function R=selftest_sensitivity()
% Sensitivity regression: the analytical derivative dJ/dx = -L*Psi used by the
% ZPR update must match a central finite difference of J. Two one-sided
% materials (deep-beam moduli); members are taken well away from the
% tension/compression switch at lambda = 1.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
p = struct('width',60,'height',15,'nx',8,'ny',2,'P',1, ...
           'Emod',[29007.5 0; 0 4351.1],'x0',[.01 .01],'doPlot',false,'groundOnly',true);
G = Engine(p); nb = size(G.BARS,1);
X = 0.01*[1+0.5*sin(1:nb).', 1+0.5*cos(1:nb).'];   % positive, non-uniform areas
p.groundOnly = false; p.evalAreas = X;
S = Engine(p);

% Strain of every bar; pick the three largest tensile (material 1 active)
% and three largest compressive (material 2 active) members
d = G.NODE(G.BARS(:,2),:) - G.NODE(G.BARS(:,1),:); L = sqrt(sum(d.^2,2));
dof = [2*G.BARS(:,1)-1, 2*G.BARS(:,1), 2*G.BARS(:,2)-1, 2*G.BARS(:,2)];
strain = sum([-d./L, d./L].*S.u(dof),2)./L;
[~,iT] = sort(strain,'descend'); [~,iC] = sort(strain,'ascend');
pick = [iT(1:3), ones(3,1); iC(1:3), 2*ones(3,1)];

R.rel = zeros(size(pick,1),1);
for k=1:size(pick,1)
    e = pick(k,1); m = pick(k,2); h = 1e-4*X(e,m);
    q = p; q.evalAreas(e,m) = X(e,m)+h; Jp = Engine(q).J;
    q.evalAreas(e,m) = X(e,m)-h;        Jm = Engine(q).J;
    fd = (Jp-Jm)/(2*h);
    R.rel(k) = abs(fd-S.dJdx(e,m))/abs(S.dJdx(e,m));
end
R.minStrainRatio = min(abs(strain(pick(:,1))))/max(abs(strain));
assert(all(R.rel<1e-6),'Analytical sensitivity differs from finite differences.');
fprintf(['Sensitivity PASSED: %d members (3 tie, 3 strut); max relative ' ...
         'difference %.1e (h = 1e-4 x)\n'],numel(R.rel),max(R.rel));
end
