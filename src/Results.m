classdef Results
%RESULTS - Everything that happens to a design after Engine has solved it.
%
%   M   = Results.metrics(S)            which members get DRAWN, and the counts
%   fig = Results.plot(S)               draw the layout
%         Results.save(S,fig,outDir)    PNG + FIG + MAT + summary.txt
%   S   = Results.load(name)            read one saved run back
%         Results.rescale(cases,...)    redraw a study on ONE line-width scale
%
% NONE OF THIS CAN CHANGE A DESIGN.  It measures, draws and records what Engine already decided.
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
% Returns the member list E, their areas A and kinds mat, plus the counts
if nargin<2 || isempty(showFrac), showFrac = S.plotShowFrac; end
if nargin<3 || isempty(doMerge),  doMerge  = S.plotMergeCollinear; end
if isempty(showFrac), showFrac = 0.02; end

area = max(S.X,[],2); amax = max(area);
if amax<=0, amax = 1; end

% showFrac == 0 means 'draw everything that exists', not 'draw zero-area bars'
if showFrac==0, vis = area>0; else, vis = area>=showFrac*amax; end

E = S.BARS(vis,:); nN = size(S.NODE,1);

% Merging must spare supports AND loaded nodes: a girder line landing on a
% loaded top node is a real joint, not a pass-through
protectedNode = false(nN,1);
protectedNode(S.suppNodes) = true;
protectedNode(S.loadNodes) = true;
isSupport = false(nN,1); isSupport(S.suppNodes) = true;

[~,matOf] = max(S.X,[],2);
% With ONE material column every bar is 'material 1', so colour by force sign
if size(S.X,2)==1
    matOf = 1 + (S.Fe(:)<0);        % 1 = tie (tension), 2 = strut
end
A = area(vis); mat = matOf(vis);

% Optional: peel one-ended branches off the DRAWING, repeatedly
if S.plotPruneDangling && ~isempty(E)
    keep = true(size(E,1),1); changed = true;
    while changed
        deg1 = accumarray([E(keep,1); E(keep,2)],1,[nN 1])==1 & ~protectedNode;
        peel = keep & (deg1(E(:,1)) | deg1(E(:,2)));
        changed = any(peel); keep(peel) = false;
    end
    raw = find(vis); vis(raw(~keep)) = false;
    E = E(keep,:); A = A(keep); mat = mat(keep);
end

deg = accumarray([E(:,1); E(:,2)],1,[nN 1]);   % degrees BEFORE merging
if doMerge, [E,A,mat] = Results.mergeCollinear(S.NODE,E,A,mat,protectedNode); end

M.E = E;  M.A = A;  M.mat = mat;
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
    if isempty(e), continue, end                  % cannot judge; do not cry wolf
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
% Draw the final optimized STM. The member list comes from Results.metrics, so
% the figure and the reported counts always describe the same drawing.
% Results.plot(S,ax) draws into an existing axes instead of opening a window
if nargin>=2 && ~isempty(ax) && isgraphics(ax)
    fig = ancestor(ax,'figure');
    set(fig,'Name',['STM -- ' S.label]);
    cla(ax,'reset'); set(ax,'Color','none','XColor','none','YColor','none');
else
    fig = figure('Color','w','Name',['STM -- ' S.label],'Position',[60 90 640 480]);
    ax  = axes(fig);
end
hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');

% Backdrop first, so nothing covers the structure. The domain boundary is
% deliberately NOT drawn: the node grid marks every candidate node, so its
% extent IS the domain, and a rectangle reads as a picture frame
plot(ax,S.NODE(:,1),S.NODE(:,2),'.','Color',[0.70 0.70 0.70],'MarkerSize',5);
if S.tieFrac<1-1e-9                          % upper limit of the tie region
    yb = S.tieFrac*S.height;
    plot(ax,[0 S.width],[yb yb],'k:','LineWidth',1.0);
end

M = Results.metrics(S,S.plotShowFrac,S.plotMergeCollinear);
[gmax,wMax,gam] = Results.plotScale(S,M.amax);

% Blue tie / red strut by default; barColor overrides both with one colour
col = [0 0 1; 0.85 0 0];
if ~isempty(S.barColor), col = repmat(S.barColor(:).',2,1); end

used = false(size(S.NODE,1),1);
for e=1:size(M.E,1)
    n1 = M.E(e,1); n2 = M.E(e,2);
    plot(ax,S.NODE([n1 n2],1),S.NODE([n1 n2],2),'-','Color',col(M.mat(e),:), ...
         'LineWidth',0.5+wMax*min(M.A(e)/gmax,1).^gam);   % width carries area
    used(n1) = true; used(n2) = true;
end
plot(ax,S.NODE(used,1),S.NODE(used,2),'o','MarkerEdgeColor','k', ...
     'MarkerFaceColor','w','MarkerSize',5,'LineWidth',1.0);

% Padding scales with the model, so a unit-scale domain is framed like a big one
pad = max(S.width,S.height);
xlim(ax,[-0.05*pad, S.width+0.05*pad]);
ylim(ax,[-0.05*pad, S.height+0.05*pad]);
end


%% ========================================================================
function outDir=save(S,fig,outDir)
% Save the figure (PNG + editable .fig), the result struct and a text summary.
% OUTDIR is a bare name under results/, or a path; the resolved path is returned
outDir = Results.resultPath(outDir);
if ~exist(outDir,'dir'), mkdir(outDir); end

if ~isempty(fig) && isgraphics(fig)
    exportgraphics(fig,fullfile(outDir,'layout.png'),'Resolution',150);
    savefig(fig,fullfile(outDir,'layout.fig'));
end

S.fig = [];             % Drop the handle: saving it serializes the whole figure
S.resultDir = outDir;   % Where it went, so a later rescale pass can write back
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
if isfield(S,'minLenCells') && S.minLenCells>0
    fprintf(fid,'min member len  : %.6g cells\n',S.minLenCells);
end
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
% Convert older saved files to the manuscript's member-force notation.
if isfield(S,'Naxial')
    if ~isfield(S,'Fe'), S.Fe = S.Naxial; end
    S = rmfield(S,'Naxial');
end

% Defaults for fields that older saved runs never wrote
if ~isfield(S,'minLenCells'),    S.minLenCells = 0;   end
if ~isfield(S,'gsLevel'),        S.gsLevel = NaN;     end
if ~isfield(S,'symmetricLR'),    S.symmetricLR = NaN; end
if ~isfield(S,'nBars'),          S.nBars = size(S.BARS,1); end
if ~isfield(S,'plotMaxArea'),    S.plotMaxArea = [];    end  % [] = each figure
if ~isfield(S,'plotMaxWidth'),   S.plotMaxWidth = [];   end  % normalized by its
if ~isfield(S,'plotWidthGamma'), S.plotWidthGamma = []; end  % own largest bar

% Where it was actually read from beats the path recorded when it ran, so a
% results tree that has been moved or copied still writes back to itself
S.resultDir = fileparts(f);
end


%% ========================================================================
function amax=rescale(cases,varargin)
% Redraw finished runs on ONE line-width scale, in place.
%
% Every run saves its own layout.png normalized by its own largest bar, because
% at that moment nothing knows what the rest of the study will produce. This
% pass takes the largest DISPLAYED bar over the whole set, redraws each layout
% against it, and overwrites that run's layout.png, layout.fig and result.mat.
% Only the line WIDTH changes: J, Z, member counts, the residual and each
% block's own plotShowFrac are properties of the design and stay untouched.
% CASES are result directories, or the result structs themselves
opt = struct('maxArea',[],'maxWidth',5,'gamma',1, ...
             'position',[60 90 640 480],'quiet',false);
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

% Every result carries the directory it belongs to: Results.load sets it to the
% directory it read from, and a run saved by the engine carries the one it wrote
for k=1:n
    if ~isfield(R{k},'resultDir') || isempty(R{k}.resultDir)
        error('Results:notSaved',['Case %d ("%s") was run with no resultDir, so it\n' ...
              '  has no saved figure to rewrite.  Give the case directory by name, or\n' ...
              '  set resultDir on the run.'],k,R{k}.label)
    end
end

% The scale is the largest bar actually DRAWN, taken through each design's own
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
    fig = figure('Color','w','Name',['STM -- ' S.label],'Position',opt.position);
    Results.plot(S,axes('Parent',fig));
    Results.save(S,fig,S.resultDir);
    close(fig);
end

if ~opt.quiet
    if opt.gamma==1, mapStr = 'width proportional to area';
    else,            mapStr = sprintf('width on area^%.3g',opt.gamma);
    end
    fprintf(['  ONE line-width scale over %d case(s): full width = %.6g area units,\n' ...
             '  %s.  Thickness now compares across these\n' ...
             '  figures; each block keeps its own display threshold, so WHICH members\n' ...
             '  are drawn is unchanged.\n'],n,amax,mapStr);
end
end

end % public methods


methods(Static, Access=private)

function r=pkgRoot()
% The package root, from this file's own location: src/Results.m -> STMTopRC/
r = fileparts(fileparts(mfilename('fullpath')));
end


function d=resultPath(d)
% An absolute path is taken as given; anything else is a name (or subpath)
% under this package's results/ folder, so no script hard-codes a location
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


function [E,A,M]=mergeCollinear(NODE,E,A,M,protectedNode)
% Collapse pass-through nodes into single members: a node touched by exactly two
% collinear members of the SAME kind is not a joint, so the two are drawn as one
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

        Anew = max(A(e1),A(e2));
        dup  = find((E(:,1)==a & E(:,2)==b) | (E(:,1)==b & E(:,2)==a),1);
        keep = true(size(E,1),1); keep([e1 e2]) = false;
        if isempty(dup)
            E = [E(keep,:); a, b]; A = [A(keep); Anew]; M = [M(keep); M(e1)];
        else
            A(dup) = max(A(dup),Anew);          % absorb into the existing bar
            E = E(keep,:); A = A(keep); M = M(keep);
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


function [amax,wMax,gam]=plotScale(S,ownMax)
% The area drawn at full line width, the width added at it, and the exponent.
% Left alone a figure normalizes by its OWN largest bar, so two designs whose
% areas differ by 5x look alike. plotMaxArea shares one area across a set of
% runs (see Results.rescale); plotMaxWidth widens the range; plotWidthGamma < 1
% lifts the light end. Any gamma is MONOTONE, so equal width still means equal
% area within the set
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
