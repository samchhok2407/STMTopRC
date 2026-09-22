function R=selftest_ZhaoAppendixB()
% Evaluation regression, not optimizer validation. Zhao et al. (2023),
% Appendix B and Fig. B1, ACI Structural Journal 120(6), pp. 20-21.
% Coordinates read from the H/4 grid; P=H=1. Published values are rounded.
% SPDX-License-Identifier: GPL-3.0-or-later
addpath(fullfile(fileparts(mfilename('fullpath')),'..','src'));
NODE=[0 0;.25 .5;.75 0;2 1;3.25 0;3.75 .5;4 0];
BARS=[1 2;6 7;2 4;4 6;3 4;4 5;1 3;5 7;2 3;5 6;3 5];
D=NODE(BARS(:,2),:)-NODE(BARS(:,1),:); L=sqrt(sum(D.^2,2));
Q=zeros(14,11);
for e=1:11
 d=D(e,:).'/L(e); i=BARS(e,1); j=BARS(e,2);
 Q(2*i-1:2*i,e)=d; Q(2*j-1:2*j,e)=-d;
end
f=zeros(14,1); f(8)=-1; fixed=[1 2 14]; free=setdiff(1:14,fixed);
Fe=Q(free,:)\(-f(free));
Fepub=[-.56;-.56;-.61;-.61;-.53;-.53;.25;.25;.47;.47;1];
Lpub=[.56;.56;1.82;1.82;1.60;1.60;.75;.75;.71;.71;2.50];
assert(rank(Q(free,:))==11,'Determinate equilibrium system must be nonsingular.');
assert(norm(Q(free,:)*Fe+f(free))<1e-12,'Nodal equilibrium failed.');
assert(all(abs(Fe-Fepub)<=.005),'Force mismatch exceeds published rounding.');
assert(all(abs(L-Lpub)<=.005),'Length mismatch exceeds published rounding.');
Z=Results.loadPath(Fe,L); Zrounded=Results.loadPath(Fepub,Lpub);
assert(abs(Z-97/12)<1e-12,'Exact-coordinate load path mismatch.');
assert(abs(Zrounded-8.086)<1e-12,'Published rounded-data sum mismatch.');
assert(Results.loadPath(Fe.',L.')==Z,'Row-vector convention mismatch.');
assert(Results.loadPath(-Fe,L)==Z,'Load-path sign invariance failed.');
R=struct('NODE',NODE,'BARS',BARS,'Fe',Fe,'L',L,'Fepublished',Fepub,...
 'Lpublished',Lpub,'Z',Z,'Zrounded',Zrounded,'residual',norm(Q(free,:)*Fe+f(free)));
fprintf('Appendix B PASSED: Z/(PH)=%.12g; rounded-input sum=%.12g; source label=8.08\n',Z,Zrounded);
end
