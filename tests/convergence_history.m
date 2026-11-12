function fig = convergence_history(S,outDir)
%CONVERGENCE_HISTORY - Convergence history of the shared-budget panel.
%   fig = convergence_history reads the saved result of run_panel_2mat_1vol
%   and writes results/convergence_history.{png,fig}.
%   fig = convergence_history(S,outDir) draws the result struct S and writes
%   the figure to outDir (used by run_all_verification).
%
%   (a) objective J and maximum area change dX, with the stopping tolerance of
%   the final design; (b) tension (blue) and compression (red) volume
%   fractions. Iteration 1 evaluates the uniform starting areas, which exceed
%   the prescribed budget, so the histories start at k = 2.
% SPDX-License-Identifier: GPL-3.0-or-later
root = fileparts(fileparts(mfilename('fullpath')));   % tests/ -> repository root
addpath(fullfile(root,'src'));
if nargin<1 || isempty(S)
    D = load(fullfile(root,'results','Zhang2018_Fig8c','result.mat'),'S'); S = D.S;
end
if nargin<2 || isempty(outDir), outDir = fullfile(root,'results'); end
if ~isfield(S.hist,'Vfrac') || isempty(S.hist.Vfrac)
    error('convergence_history:noFractions', ...
          'No fraction history in this result; rerun run_panel_2mat_1vol first.');
end
J = S.hist.J(:); dX = S.hist.dX(:); F = S.hist.Vfrac;
n = numel(J); k = (2:n).';
tol = max(S.parameters.tolOpt, S.parameters.tolRel*max(S.X(:)));

blue = [0 0 1]; red = [1 0 0]; grey = [0.45 0.45 0.45];
fnt = {'FontName','Times New Roman','FontSize',10};
sml = {'FontName','Times New Roman','FontSize',9};
fig = figure('Color','w','Units','inches','Position',[1 1 6 2.8]);
tl  = tiledlayout(fig,1,2,'TileSpacing','loose','Padding','compact');
xl = [0 600]; xt = 0:200:600;

% (a) objective (left) and maximum area change (right, log) with the tolerance
ax = nexttile(tl,1); hold(ax,'on'); box(ax,'on');
set(ax,fnt{:},'LineWidth',0.6,'TickDir','in','XColor','k');
yyaxis(ax,'left');
mk = unique([1:10, 20:25:numel(k), numel(k)]);
hJ = plot(ax,k,J(k),'-o','Color',blue,'LineWidth',1.0,'MarkerSize',3, ...
          'MarkerFaceColor','w','MarkerIndices',mk);
ax.YColor = 'k'; ylim(ax,[1 5]); yticks(ax,1:5);
ylabel(ax,'Objective {\itJ} (kN\cdotm)',fnt{:},'Color','k');
yyaxis(ax,'right');
hX = plot(ax,k,dX(k),'-','Color','k','LineWidth',0.5);
yline(ax,tol,':','Color',grey,'LineWidth',1.0);
plot(ax,n,dX(end),'o','Color','k','MarkerSize',4,'LineWidth',0.6);
text(ax,n+4,1.35*dX(end),sprintf('{\\itk} = %d',n),sml{:},'HorizontalAlignment','left','VerticalAlignment','bottom');   % converged iteration
e = floor(log10(tol));
text(ax,xl(2)-10,tol/1.12,sprintf('tolerance = %.2f\\times10^{%d} m^2',tol/10^e,e),sml{:}, ...
     'Color',grey,'HorizontalAlignment','right','VerticalAlignment','top');
lo = tol/4; hi = 10*max(dX(k));
set(ax,'YScale','log','YTick',10.^(ceil(log10(lo)):2:floor(log10(hi))));
ylim(ax,[lo hi]); ax.YColor = 'k';
ylabel(ax,'Max. area change {\itdX} (m^2)',fnt{:},'Color','k');
xlim(ax,xl); xticks(ax,xt);
xlabel(ax,{'Iteration {\itk}','(a)'},fnt{:},'Color','k');
legend(ax,[hJ hX],{'Objective {\itJ}','Max. area change {\itdX}'},'Location','northeast','Box','off',sml{:});

% (b) material volume fractions, to the two decimals reported in Table 1
ax = nexttile(tl,2); hold(ax,'on'); box(ax,'on');
plot(ax,k,F(k,1),'-','Color',blue,'LineWidth',1.0);
plot(ax,k,F(k,2),'-','Color',red,'LineWidth',1.0);
set(ax,fnt{:},'LineWidth',0.6,'TickDir','in','XColor','k','YColor','k');
xlim(ax,xl); xticks(ax,xt); ylim(ax,[0.3 0.7]); yticks(ax,0.3:0.1:0.7);
text(ax,n,F(end,1)+0.012,sprintf('Tension: %.2f',F(end,1)),fnt{:},'Color',blue, ...
     'HorizontalAlignment','right','VerticalAlignment','bottom');
text(ax,n,F(end,2)-0.012,sprintf('Compression: %.2f',F(end,2)),fnt{:},'Color',red, ...
     'HorizontalAlignment','right','VerticalAlignment','top');
xlabel(ax,{'Iteration {\itk}','(b)'},fnt{:},'Color','k');
ylabel(ax,'Volume fraction',fnt{:},'Color','k');

out = fullfile(outDir,'convergence_history');
exportgraphics(fig,[out '.png'],'Resolution',1200);
savefig(fig,[out '.fig']);
fprintf('%s: %d iterations, J = %.3f, final dX %.3g below tolerance %.3g, fractions %.2f/%.2f\n', ...
        S.label,n,J(end),dX(end),tol,F(end,1),F(end,2));
end
