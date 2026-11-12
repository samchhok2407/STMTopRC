classdef Results
%RESULTS - Everything that happens to a design after Engine has solved it.
%
%   M   = Results.metrics(S)            which members get DRAWN, and the counts
%   fig = Results.plot(S)               draw the layout
%         Results.save(S,fig,outDir)    PNG + FIG + MAT + summary.txt
%   S   = Results.load(name)            read one saved run back
%         Results.rescale(cases,...)    redraw a study on ONE line-width scale
%
% Nothing here changes a design.
% SPDX-License-Identifier: GPL-3.0-or-later

methods(Static)

function Z=loadPath(Fe,L)
% Physical load path sum_e |F_e| L_e; positive forces denote tension.
% No display threshold or collinear merging enters this evaluation.
if ~isvector(Fe) || ~isvector(L) || numel(Fe)~=numel(L) ...
        || any(~isfinite(Fe(:))) || any(~isfinite(L(:))) || any(L(:)<=0)
    error('Results:invalidLoadPath','Forces and positive lengths must be finite vectors of equal size.');
end
Z = sum(abs(Fe(:)).*L(:));
end

%% ========================================================================
function M=metrics(S,showFrac,doMerge)
% Select the members that get DRAWN and measure their load-path connectivity.
% Returns the member list E, their areas A, kinds mat and forces F, plus the counts
if nargin<2 || isempty(showFrac), showFrac = S.plotShowFrac; end
if nargin<3 || isempty(doMerge),  doMerge  = S.plotMergeCollinear; end
if isempty(showFrac), showFrac = 0.02; end

area = max(S.X,[],2); amax = max(area);
if amax<=0, amax = 1; end

% showFrac == 0 means 'draw everything that exists', not 'draw zero-area bars'
if showFrac==0, vis = area>0; else, vis = area>=showFrac*amax; end

E = S.BARS(vis,:); nN = size(S.NODE,1);

% Merging must spare supports AND loaded nodes: a line landing on a loaded
% node is a real joint, not a pass-through
protectedNode = false(nN,1);
protectedNode(S.suppNodes) = true;
protectedNode(S.loadNodes) = true;
isSupport = false(nN,1); isSupport(S.suppNodes) = true;

[~,matOf] = max(S.X,[],2);
% With ONE material column every bar is 'material 1', so colour by force sign
if size(S.X,2)==1
    matOf = 1 + (S.Fe(:)<0);        % 1 = tie (tension), 2 = strut
end
A = area(vis); mat = matOf(vis); F = S.Fe(:); F = F(vis);

deg = accumarray([E(:,1); E(:,2)],1,[nN 1]);   % degrees BEFORE merging
if doMerge, [E,A,mat,F] = Results.mergeCollinear(S.NODE,E,A,mat,protectedNode,F); end

M.E = E;  M.A = A;  M.mat = mat;  M.F = F;   % F: member force, + tension
M.amax = amax;
M.nShown  = nnz(vis);
M.nMerged = size(E,1);

% --- degree-one nodes in the DRAWING -------------------------------------
isLoad = false(nN,1); isLoad(S.loadNodes) = true;
d1  = find(deg==1 & ~isSupport);
bad = false(numel(d1),1);
for j=1:numel(d1)
    n = d1(j);
    if ~isLoad(n), bad(j) = true; continue, end   % nothing external holds it
    e = find(E(:,1)==n | E(:,2)==n,1);
    if isempty(e), continue, end                  % no drawn member: cannot judge
    o = E(e,1); if o==n, o = E(e,2); end
    dv = S.NODE(o,:) - S.NODE(n,:);
    f  = [S.Fext(2*n-1), S.Fext(2*n)];
    if norm(f)<=0, bad(j) = true; continue, end   % listed as loaded, carries none
    % Parallel means zero cross product: the load acts along the member
    bad(j) = abs(dv(1)*f(2)-dv(2)*f(1)) > 1e-9*norm(dv)*norm(f);
end
M.nDangle = nnz(bad);

% Reachability is asked of the MERGED list, because that is the drawing
[M.nIsolated,M.nLoadIsolated] = Results.supportReach(E,nN,S.suppNodes,S.loadNodes);
end

%% ========================================================================
function fig=plot(S,ax)
% Draw the optimized STM from the member list of Results.metrics.
% Results.plot(S,ax) draws into an existing axes
if nargin>=2 && ~isempty(ax) && isgraphics(ax)
    fig = ancestor(ax,'figure');
    set(fig,'Name',['STM -- ' S.label]);
    cla(ax,'reset'); set(ax,'Color','none','XColor','none','YColor','none');
else
    % Slender members get a wider window, so 11 pt labels still have room
    wFig = min(1400, max(640, round(300*S.width/S.height)));
    fig = figure('Color','w','Name',['STM -- ' S.label],'Position',[60 90 wFig 480]);
    ax  = axes(fig);
end
hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
fnt = {'FontName','Times New Roman','FontSize',S.plotFontSize,'Color','k'};   % all figure text
pad = max(S.width,S.height);    % framing scales with the model

% Backdrop: optional ground structure (one NaN-separated line), domain
% boundary and tie band
thin = 0.3; dark = [0.35 0.35 0.35];
if S.plotGround
    nb = size(S.BARS,1);
    gx = [S.NODE(S.BARS(:,1),1), S.NODE(S.BARS(:,2),1), nan(nb,1)].';
    gy = [S.NODE(S.BARS(:,1),2), S.NODE(S.BARS(:,2),2), nan(nb,1)].';
    plot(ax,gx(:),gy(:),'-','Color',[0.90 0.90 0.90],'LineWidth',thin);
end
if S.plotBoundary
    loops = {[0 0; S.width 0; S.width S.height; 0 S.height]};
    if ~isempty(S.domain), loops = [{S.domain.outer}, S.domain.holes(:).']; end
    for c = loops
        xy = c{1}([1:end 1],:);
        plot(ax,xy(:,1),xy(:,2),'-','Color',dark,'LineWidth',thin);
    end
end
if S.tieFrac<1-1e-9              % upper limit of the tie region
    plot(ax,[0 S.width],S.tieFrac*S.height*[1 1],':','Color',dark,'LineWidth',thin);
end

% Members: blue tie / red strut by default, width carries area
M = Results.metrics(S);
[gmax,wMax,gam] = Results.plotScale(S,M.amax);
col = [0 0 1; 0.85 0 0];
if ~isempty(S.barColor), col = repmat(S.barColor(:).',2,1); end
for e=1:size(M.E,1)
    plot(ax,S.NODE(M.E(e,:),1),S.NODE(M.E(e,:),2),'-','Color',col(M.mat(e),:), ...
         'LineWidth',0.5+wMax*min(M.A(e)/gmax,1).^gam);
end
% Every node, the same way in every case: an unfilled dark-grey circle
plot(ax,S.NODE(:,1),S.NODE(:,2),'o','MarkerEdgeColor',dark, ...
     'MarkerFaceColor','none','MarkerSize',4,'LineWidth',thin);

% Optional member labels at the centre of each member: force (+ tension) or
% area. On a horizontal member the text sits just above the line instead
if ~strcmp(S.plotLabel,'none')
    if strcmp(S.plotLabel,'force'), val = M.F; else, val = M.A; end
    for e=1:size(M.E,1)
        xy = mean(S.NODE(M.E(e,:),:),1); vA = 'middle';
        if abs(diff(S.NODE(M.E(e,:),2))) < 1e-9*pad
            xy(2) = xy(2) + 0.003*pad; vA = 'bottom';
        end
        text(ax,xy(1),xy(2),sprintf('%.4g',val(e)),fnt{:}, ...
             'HorizontalAlignment','center','VerticalAlignment',vA);
    end
end

% Optional external forces: applied loads, supports and reactions
lim = [-0.05*pad, S.width+0.05*pad, -0.05*pad, S.height+0.05*pad];
unit = ''; if ~isempty(S.units), unit = [' ' strtrim(strtok(S.units,','))]; end
if S.plotLoads
    hAl = {'right','center','left'};  vAl = {'top','middle','bottom'};
    Fmax = max(abs(S.Fext)); if Fmax<=0, Fmax = 1; end
    for k=find(abs(S.Fext) > 1e-3*Fmax).'          % one arrow per nonzero component
        v = [0 0]; v(2-mod(k,2)) = sign(S.Fext(k));
        len  = 0.0336*pad*max(abs(S.Fext(k))/Fmax,0.35);   % arrow length
        tail = S.NODE(ceil(k/2),:) - len*v;
        quiver(ax,tail(1),tail(2),len*v(1),len*v(2),0,'Color','k', ...
               'LineWidth',1.4,'MaxHeadSize',1.2);
        text(ax,tail(1),tail(2),[' ' sprintf('%.4g',abs(S.Fext(k))) unit ' '],fnt{:}, ...
             'HorizontalAlignment',hAl{2-v(1)},'VerticalAlignment',vAl{2-v(2)});
        lim = [min(lim(1),tail(1)-0.04*pad), max(lim(2),tail(1)+0.04*pad), ...
               min(lim(3),tail(2)-0.04*pad), max(lim(4),tail(2)+0.04*pad)];
    end
    % Symbol size: 3.5% of the model, but no wider than the gap between supports
    sn = unique(S.suppNodes(:)); s = 0.035*pad;
    if numel(sn)>1
        dd = sqrt((S.NODE(sn,1)-S.NODE(sn,1).').^2 + (S.NODE(sn,2)-S.NODE(sn,2).').^2);
        s = min(s, 0.55*min(dd(dd>0)));
    end
    xyText = Results.supports(ax,S,s,Results.reactions(S),unit,fnt);
    if ~isempty(xyText)
        lim = [min(lim(1),min(xyText(:,1))-0.06*pad), max(lim(2),max(xyText(:,1))+0.06*pad), ...
               min(lim(3),min(xyText(:,2))-0.06*pad), max(lim(4),max(xyText(:,2))+0.06*pad)];
    end
end
xlim(ax,lim(1:2)); ylim(ax,lim(3:4));
end

%% ========================================================================
function outDir=save(S,fig,outDir)
% Save the figure (PNG + editable .fig), the result struct and a text summary.
% OUTDIR is a bare name under results/, or a path; the resolved path is returned
outDir = Results.resultPath(outDir);
if ~exist(outDir,'dir'), mkdir(outDir); end

if ~isempty(fig) && isgraphics(fig)
    exportgraphics(fig,fullfile(outDir,'layout.png'),'Resolution',1000);
    savefig(fig,fullfile(outDir,'layout.fig'));
end

S.fig = [];             % drop the handle: saving it serializes the whole figure
S.resultDir = '';       % no local path in the file; Results.load sets it on read
save(fullfile(outDir,'result.mat'),'S');

if S.equilOK, eqstr = 'OK'; else, eqstr = 'CHECK!'; end
fid = fopen(fullfile(outDir,'summary.txt'),'w');
if fid<0, error('Results:writeFailed','Cannot open summary.txt in %s.',outDir); end
fileGuard = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',S.label);
fprintf(fid,'----------------------------------------\n');
if ~isempty(S.source), fprintf(fid,'source          : %s\n',S.source); end
if ~isempty(S.units),  fprintf(fid,'units           : %s\n',S.units);  end
fprintf(fid,'mesh            : %d x %d\n',S.nx,S.ny);
if ~isempty(S.domain)
    fprintf(fid,'domain          : %d-corner outline, %d opening(s), %d nodes\n', ...
            size(S.domain.outer,1),numel(S.domain.holes),size(S.NODE,1));
end
if S.minLenCells>0, fprintf(fid,'min member len  : %.6g cells\n',S.minLenCells); end
fprintf(fid,'Vmax            : %s\n',num2str(S.Vmax(:).','%.6g  '));
if ~isnan(S.Z), fprintf(fid,'load path Z/(PH): %.4f\n',S.Z); end
fprintf(fid,'objective J=-Pi : %.6f\n',S.J);
fprintf(fid,'active members  : %d\n',S.nActive);
fprintf(fid,'displayed members: %d\n',S.nMerged);
if S.nLoadIsolated==0 && S.nDangle==0 && S.nIsolated==0
    fprintf(fid,'drawn load path : OK\n');
else
    fprintf(fid,['drawn load path : BROKEN (%d loaded node(s) off path, ' ...
                 '%d dangling, %d isolated)\n'],S.nLoadIsolated,S.nDangle,S.nIsolated);
end
if size(S.X,2)==1
    fprintf(fid,'material volume : %.12g\n',S.matVol(1));
    fprintf(fid,'material Vfrac  : 1 (single bilinear material)\n');
else
    for mm=1:size(S.X,2)
        fprintf(fid,'material %d volume: %.12g\n',mm,S.matVol(mm));
        fprintf(fid,'material %d Vfrac : %.12g\n',mm,S.matVfrac(mm));
    end
end
fprintf(fid,'filter alphaF   : %.3g\n',S.alphaF);
fprintf(fid,'iterations      : %d\n',S.nIter);
fprintf(fid,'converged       : %s\n',string(S.converged));
if isfield(S,'elapsedSeconds'), fprintf(fid,'run time (s)    : %.1f\n',S.elapsedSeconds); end
fprintf(fid,'equil. residual : %.2e\n',S.resid);
fprintf(fid,'equilibrium     : %s\n',eqstr);
clear fileGuard

fprintf('  saved results to: %s\n',outDir);
end

%% ========================================================================
function S=load(caseDir)
% Read one saved run back. CASEDIR is a path, or a bare name under results/
f = fullfile(char(caseDir),'result.mat');
if ~exist(f,'file')   % not a path: look for it under this package's results/
    f = fullfile(Results.pkgRoot(),'results',char(caseDir),'result.mat');
end
if ~exist(f,'file')
    error('Results:noResult', ...
          'No saved result for "%s".\n  Run the case that produces it first.',char(caseDir))
end
D = builtin('load',f,'S'); S = D.S;

% The folder it was read from, so Results.rescale writes back to it
S.resultDir = fileparts(f);
end

%% ========================================================================
function amax=rescale(cases,varargin)
% Redraw finished runs on one line-width scale, set by the largest displayed
% bar of the set, and overwrite their saved figures. Only line widths change.
% CASES are result directories or result structs
opt = struct('maxArea',[],'maxWidth',5,'gamma',1,'quiet',false);
if mod(numel(varargin),2)~=0
    error('Results:optionPairs','Options must be supplied as name/value pairs.');
end
for a=1:2:numel(varargin)-1      % apply 'name',value pairs; reject unknown names
    if ~isfield(opt,varargin{a})
        error('Results:unknownOption','Unknown option "%s".',varargin{a})
    end
    opt.(varargin{a}) = varargin{a+1};
end

if ischar(cases) || isstring(cases), cases = cellstr(cases); end
if isstruct(cases), cases = {cases}; end
cases = cases(~cellfun('isempty',cases));
if isempty(cases), amax = []; return, end

R = Results.loadCases(cases); n = numel(R);
for k=1:n
    if ~isfield(R{k},'resultDir') || isempty(R{k}.resultDir)
        error('Results:notSaved',['Case %d ("%s") was run with no resultDir, so it\n' ...
              '  has no saved figure to rewrite.  Give the case directory by name, or\n' ...
              '  set resultDir on the run.'],k,R{k}.label)
    end
end

% The scale is the largest bar actually DRAWN, through each design's own
% display threshold -- never one the threshold hid
amax = opt.maxArea;
if isempty(amax)
    amax = 0;
    for k=1:n
        Mk = Results.metrics(R{k});
        if ~isempty(Mk.A), amax = max(amax,max(Mk.A)); end
    end
end
if amax<=0
    error('Results:noArea', ...
          'Nothing to scale by: no displayed member in these %d case(s) has area.',n)
end

for k=1:n
    S = R{k};
    S.plotMaxArea = amax; S.plotMaxWidth = opt.maxWidth; S.plotWidthGamma = opt.gamma;
    fig = Results.plot(S);
    Results.save(S,fig,S.resultDir);
    close(fig);
end

if ~opt.quiet
    if opt.gamma==1, mapStr = 'width proportional to area';
    else,            mapStr = sprintf('width on area^%.3g',opt.gamma);
    end
    fprintf(['  ONE line-width scale over %d case(s): full width = %.6g area units,\n' ...
             '  %s.  Thickness now compares across these figures;\n' ...
             '  WHICH members are drawn is unchanged.\n'],n,amax,mapStr);
end
end

end % public methods


methods(Static, Access=private)

function r=pkgRoot()
% The package root, from this file's own location: src/Results.m -> package
r = fileparts(fileparts(mfilename('fullpath')));
end

function d=resultPath(d)
% An absolute path is taken as given; anything else is a name (or subpath)
% under this package's results/ folder
d = char(d);
if ~isempty(regexp(d,'^([A-Za-z]:[\\/]|[\\/])','once')), return, end
d = fullfile(Results.pkgRoot(),'results',d);
end

function R=loadCases(cases)
% Case directories in, results out. Already-loaded results pass straight through
if isstruct(cases{1}), R = cases(:); return, end
n = numel(cases); R = cell(n,1); miss = {};
for k=1:n
    try
        R{k} = Results.load(cases{k});
    catch
        miss{end+1} = char(cases{k}); %#ok<AGROW>
    end
end
if ~isempty(miss)
    error('Results:missing',['%d of %d case(s) have not been run yet:\n    %s\n' ...
          '  Each case is solved once by its own script; this one only redraws.'], ...
          numel(miss),n,strjoin(miss,sprintf('\n    ')))
end
end

function [E,A,M,F]=mergeCollinear(NODE,E,A,M,protectedNode,F)
% Collapse pass-through nodes into single members: a node touched by exactly two
% collinear members of the SAME kind is not a joint, so the two are drawn as one.
% The member force F rides along (an unloaded pass-through node carries one force)
tol = 1e-6; changed = true;
while changed
    changed = false;
    for n=1:size(NODE,1)
        if protectedNode(n), continue, end
        rows = find(E(:,1)==n | E(:,2)==n);
        if numel(rows)~=2, continue, end        % a joint, not a pass-through
        e1 = rows(1); e2 = rows(2);
        if M(e1)~=M(e2), continue, end          % tie meeting strut = real joint

        a = E(e1,1); if a==n, a = E(e1,2); end
        b = E(e2,1); if b==n, b = E(e2,2); end
        if a==b, continue, end

        d1 = NODE(n,:)-NODE(a,:); d2 = NODE(b,:)-NODE(n,:);
        L1 = norm(d1); L2 = norm(d2);
        if L1<eps || L2<eps, continue, end
        % Parallel (zero cross product) AND same sense => a,n,b collinear
        if abs(d1(1)*d2(2)-d1(2)*d2(1)) > tol*L1*L2, continue, end
        if (d1*d2.')<=0, continue, end

        [Anew,iBig] = max([A(e1),A(e2)]);
        Fpair = [F(e1),F(e2)]; Fnew = Fpair(iBig);
        dup  = find((E(:,1)==a & E(:,2)==b) | (E(:,1)==b & E(:,2)==a),1);
        keep = true(size(E,1),1); keep([e1 e2]) = false;
        if isempty(dup)
            E = [E(keep,:); a, b]; A = [A(keep); Anew]; M = [M(keep); M(e1)];
            F = [F(keep); Fnew];
        else
            A(dup) = max(A(dup),Anew);          % absorb into the existing bar
            F(dup) = F(dup) + Fnew;             % parallel bars share the force
            E = E(keep,:); A = A(keep); M = M(keep); F = F(keep);
        end
        changed = true; break                   % indices shifted; restart
    end
end
end

function [nIso,nLoadIso]=supportReach(E,nN,suppNodes,loadNodes)
% Flood out from the supports along the displayed members, and report what is
% never reached: isolated drawn nodes, and loaded nodes off the load path
used = false(nN,1);
seen = false(nN,1); seen(suppNodes) = true;
if ~isempty(E)
    used([E(:,1); E(:,2)]) = true;
    adj = sparse([E(:,1); E(:,2)],[E(:,2); E(:,1)],true,nN,nN);
    stack = suppNodes(:);
    while ~isempty(stack)
        n = stack(end); stack(end) = [];
        nb = find(adj(:,n) & ~seen);
        seen(nb) = true;
        stack = [stack; nb]; %#ok<AGROW>
    end
end
isLoad = false(nN,1); isLoad(loadNodes) = true;
nIso     = nnz(used & ~seen);
nLoadIso = nnz(isLoad & ~seen);
end

function R=reactions(S)
% Support reactions from nodal equilibrium: R = -(Fext + bar forces on the
% node) at the restrained DOFs. A tension bar pulls its end node toward the other
nN = size(S.NODE,1);
d = S.NODE(S.BARS(:,2),:) - S.NODE(S.BARS(:,1),:);
f = S.Fe(:).*(d./sqrt(sum(d.^2,2)));
Fbar = zeros(2*nN,1);
Fbar(1:2:end) = accumarray(S.BARS(:,1),f(:,1),[nN 1]) - accumarray(S.BARS(:,2),f(:,1),[nN 1]);
Fbar(2:2:end) = accumarray(S.BARS(:,1),f(:,2),[nN 1]) - accumarray(S.BARS(:,2),f(:,2),[nN 1]);
R = zeros(2*nN,1);
R(S.fixedDof) = -(S.Fext(S.fixedDof) + Fbar(S.fixedDof));
end

function xyText=supports(ax,S,s,R,unit,fnt)
% Pin or roller symbol (height s) at every support node, with its nonzero
% reactions R. Returns the text anchors so the caller can frame them
xyText = zeros(0,2);
Rmax = max(abs(R)); if Rmax<=0, Rmax = 1; end
for n = unique(S.suppNodes(:)).'
    fx = any(S.fixedDof==2*n-1); fy = any(S.fixedDof==2*n);
    if ~fx && ~fy, continue, end
    xy = S.NODE(n,:);
    if fy   % bears vertically: ground below a bottom-half node, above a top-half one
        t = [0 -1]; if xy(2) > S.height/2, t = [0 1]; end
    else    % bears horizontally: ground beside the nearer side edge
        t = [-1 0]; if xy(1) > S.width/2, t = [1 0]; end
    end
    w = [-t(2) t(1)];
    base = xy + s*t;                                  % centre of the triangle base
    tri  = [xy; base+0.6*s*w; base-0.6*s*w];
    patch(ax,tri(:,1),tri(:,2),[0.75 0.75 0.75],'EdgeColor','k','LineWidth',1.0);
    g = base;                                         % ground line position
    if ~(fx && fy)                                    % roller: two wheels first
        r = 0.22*s; th = linspace(0,2*pi,24).';
        for c = [-0.32 0.32]
            cc = base + c*s*w + r*t;
            patch(ax,cc(1)+r*cos(th),cc(2)+r*sin(th),'w','EdgeColor','k','LineWidth',0.8);
        end
        g = base + 2*r*t;
    end
    gl = [g+0.85*s*w; g-0.85*s*w];
    plot(ax,gl(:,1),gl(:,2),'k-','LineWidth',1.2);
    for c = linspace(-0.75,0.75,5)                    % short hatch strokes
        h = [g+c*s*w; g+c*s*w+0.3*s*(t-w)];
        plot(ax,h(:,1),h(:,2),'k-','LineWidth',0.6);
    end
    % Reaction values beyond the hatching, one line per nonzero component
    rxy = R([2*n-1, 2*n]); names = {'Rx','Ry'}; lines = {};
    for c = find(abs(rxy) > 1e-3*Rmax).'
        lines{end+1} = sprintf('%s = %.4g%s',names{c},rxy(c),unit); %#ok<AGROW>
    end
    if isempty(lines), continue, end
    p = g + 0.45*s*t;
    hAl = {'right','center','left'};  vAl = {'top','middle','bottom'};
    text(ax,p(1),p(2),lines,fnt{:},'HorizontalAlignment',hAl{2+t(1)}, ...
         'VerticalAlignment',vAl{2+t(2)});
    xyText(end+1,:) = p; %#ok<AGROW>
end
end

function [amax,wMax,gam]=plotScale(S,ownMax)
% Area drawn at full line width, the width added at it, and the exponent
% (plotMaxArea shares one scale across runs; see Results.rescale)
amax = ownMax;
if ~isempty(S.plotMaxArea), amax = S.plotMaxArea; end
if isempty(amax) || amax<=0, amax = 1; end
wMax = 5;
if ~isempty(S.plotMaxWidth), wMax = S.plotMaxWidth; end
gam = 1;
if ~isempty(S.plotWidthGamma) && S.plotWidthGamma>0, gam = S.plotWidthGamma; end
end

end % private methods
end
