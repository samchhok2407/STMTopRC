function R=selftest_stateSolver()
% State-solver regression: with Et = Ec the bilinear law is linear elastic, so
% the Newton solution must equal the direct solution of K u = f. Checks the
% stiffness assembly, boundary conditions, Newton solve and force recovery.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
E = 200;
p = struct('width',2,'height',1,'nx',2,'ny',1,'P',1,'Emod',[E E],'x0',1, ...
           'doPlot',false,'groundOnly',true);
G = Engine(p);                                  % 6 nodes, all admissible bars
nb = size(G.BARS,1); nd = 2*size(G.NODE,1);
X = 1 + (1:nb).'/nb;                            % distinct positive areas
p.groundOnly = false; p.evalAreas = X;
S = Engine(p);

% Direct linear solution
d = G.NODE(G.BARS(:,2),:) - G.NODE(G.BARS(:,1),:); L = sqrt(sum(d.^2,2));
B = [-d./L, d./L];                              % [-c -s c s] per bar
dof = [2*G.BARS(:,1)-1, 2*G.BARS(:,1), 2*G.BARS(:,2)-1, 2*G.BARS(:,2)];
K = zeros(nd);
for e=1:nb
    K(dof(e,:),dof(e,:)) = K(dof(e,:),dof(e,:)) + E*X(e)/L(e)*(B(e,:).'*B(e,:));
end
free = setdiff(1:nd,G.fixedDof);
u = zeros(nd,1); u(free) = K(free,free)\G.Fext(free);
F = E*X./L.*sum(B.*u(dof),2);
J = 0.5*G.Fext.'*u;                             % -Pi at equilibrium

R.du = norm(S.u-u)/norm(u);
R.dF = norm(S.Fe-F)/norm(F);
R.dJ = abs(S.J-J)/abs(J);
assert(R.du<1e-8 && R.dF<1e-8 && R.dJ<1e-8,'State solver differs from K u = f.');
fprintf(['State solver PASSED: %d bars; relative difference u %.1e, ' ...
         'forces %.1e, J %.1e\n'],nb,R.du,R.dF,R.dJ);
end
