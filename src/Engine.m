function S=Engine(p)
%STMTopRC - Strut-and-Tie Topology optimization for Reinforced Concrete.
%   S = Engine(p) builds the model from p and optimizes it.
%   Required fields: width, height, nx, ny, P, Emod, x0. All others default
%   to the DEFAULTS block below (docs/parameter_guide.md).
%   Emod: one bilinear row [Et Ec], or two rows [Et 0; 0 Ec] (ties, struts).
% SPDX-License-Identifier: GPL-3.0-or-later

runTimer = tic;
if ~isstruct(p) || ~isscalar(p)
    error('Engine:notStruct',['Engine takes a parameter STRUCT, not a %s.\n' ...
          '  Define p in an examples/run_*.m script, then call Engine(p).'],class(p))
end

%% === DEFAULTS ===========================================================
d = struct();

% supports and loads ([] = built-in simply-supported deep-beam case)
d.supports = [];            % [x y fixX fixY ; ...]
d.loads    = [];            % [x y Fx Fy ; ...]

% material and volume
d.inactiveFactor = 1e-6;    % floor on the inactive branch of each material
d.volGroups  = [];          % volGroups(mat) = constraint index; [] = 1:m
d.Vmax       = [];          % per-constraint budget; [] = auto (x0*sum(L))
d.xmaxFactor = 1e4;         % xmax = xmaxFactor*x0
d.moveFactor = 1e4;         % move limit = moveFactor*x0

% ground structure
d.domain      = [];         % [] = full width x height rectangle; or a struct:
                            %   outer  [x y] outline corners (non-self-intersecting)
                            %   holes  {[x y], ...} openings strictly inside outer
                            %   xLines, yLines  grid lines ([] = uniform nx, ny)
                            % Nodes are grid points inside the shape; a bar is kept
                            % only if its whole length stays inside the shape
d.gsLevel     = Inf;        % keep bars within N cells (Chebyshev); Inf = all pairs
d.minLenCells = 0;          % minimum member length, in grid cells
d.groundOnly  = false;      % build the model and return WITHOUT optimizing
d.evalAreas   = [];         % numBars x m areas: evaluate this design, no optimization
d.useSymmetry = true;       % false = never average left-right twins

% optimizer (the convergence test stops the loop; maxIter is a safeguard)
d.alpha       = 1.0;        % ZPR damping exponent; eta0 = 1/(1+alpha)
d.tolOpt      = 1e-9;       % stop when max|dX| falls below this (absolute)
d.tolRel      = 0;          % also stop when max|dX| < tolRel*max(area); 0 = off
d.maxIter     = 10000;      % safeguard cap on optimization iterations
d.maxNR       = 40;         % maximum Newton-Raphson iterations per state solve
d.tolNR       = 1e-8;       % Newton-Raphson tolerance on |R|/max(|Fext|,P)
d.GammaFactor = 1e-10;      % Tikhonov term = GammaFactor*kRef; kRef = largest diagonal
                            % of a reference stiffness (initial areas, larger modulus)
d.etaMin      = 0.20;       % lower bound on the adaptive damping
d.etaMax      = 1.00;       % upper bound on the adaptive damping
d.etaInc      = 1.20;       % damping growth factor for steady bars
d.etaDec      = 0.70;       % damping decay factor for oscillating bars

% discrete filter
d.alphaF  = 1e-4;           % prune bars below this fraction of the max area
d.Nfilter = 350;            % filter from this iteration on (k >= Nfilter)

% tie placement
d.tieFrac   = 1.0;          % ties confined to y <= tieFrac*height
d.tieAngles = [];           % allowed tie angles in degrees; [] = any

% output
d.doPlot    = true;         % draw the optimized layout
d.resultDir = '';           % save dir; bare name = results/<name>; '' = no save
d.label     = 'STM run';    % title used in figures and printouts
d.plotShowFrac       = 0.02;   % hide members below this fraction of max area
d.plotMergeCollinear = true;   % collapse pass-through nodes when plotting
d.plotMaxArea    = [];      % bar area drawn at full line width; [] = own largest
d.plotMaxWidth   = 5;       % line width added at plotMaxArea
d.plotWidthGamma = 1;       % exponent on the area fraction; 1 = width ~ area
d.barColor       = [];      % RGB triplet for every bar; [] = blue tie / red strut
d.plotGround     = false;   % draw the candidate ground structure behind the layout
d.plotBoundary   = true;    % draw the domain outline and its openings
d.plotLoads      = false;   % external forces: applied loads, supports and reactions
d.plotLabel      = 'none';  % member labels: 'none', 'force' (+ tension) or 'area'
d.plotFontSize   = 11;      % font size (pt) of all figure text
d.showZ          = true;    % compute and report the load-path number Z/(P*H)

% documentation (carried into summary.txt, never used in the math)
d.units  = '';              % unit system, e.g. 'kN, m' or 'kip, in'
d.source = '';              % paper and figure this case reproduces

required = {'width','height','nx','ny','P','Emod','x0'};
missing = setdiff(required,fieldnames(p));
if ~isempty(missing)
    error('Engine:missingParameter','Missing required parameter(s): %s.',strjoin(missing,', '));
end
unknown = setdiff(fieldnames(p),[fieldnames(d); required(:)]);
if ~isempty(unknown)
    error('Engine:unknownParameter','Unknown parameter(s): %s.',strjoin(unknown,', '));
end
for f = fieldnames(d).'
    if ~isfield(p,f{1}), p.(f{1}) = d.(f{1}); end
end
if isempty(p.volGroups), p.volGroups = 1:size(p.Emod,1); end  % one constraint per material
if ~isempty(p.domain), p.domain = completeDomain(p.domain); end
p.plotLabel = lower(char(p.plotLabel));
validateParameters(p);

%% === MODEL AND OPTIMIZATION =============================================
G  = groundStructure(p);        % grid nodes, candidate bars, assembly indices
BC = boundaryConditions(p,G);   % fixed/free DOFs and the nodal force vector
if p.groundOnly
    S = baseResult(p,G,BC); S.groundOnly = true;
    return
end
if ~isempty(p.evalAreas), S = evaluateDesign(p,G,BC); return, end
S = optimizeDesign(p,G,BC,runTimer);
end

function S=evaluateDesign(p,G,BC)
% State, objective and analytical sensitivity dJ/dx = -L*Psi of given areas
M = materials(p,G);
if ~isequal(size(p.evalAreas),[G.numBars M.m])
    error('Engine:invalidAreas','evalAreas must be numBars x m (%d x %d).',G.numBars,M.m);
end
X = p.evalAreas;
[u,Psi,Fe,Fint,info] = analysis(p,G,BC,M,X,zeros(G.numDof,1));
S = baseResult(p,G,BC);
S.X = X; S.u = u; S.Fe = Fe;
S.J = objectiveJ(BC.Fext,u,X,G.L,Psi);
S.dJdx = -G.L.*Psi;
S.resid = norm(Fint(BC.freeDof)-BC.Fext(BC.freeDof))/BC.Fscale;
S.stateInfo = info;
S.kRef = M.kRef;            S.Gamma = M.Gamma;
end

function validateParameters(p)
% Reject malformed models before allocating the all-pairs ground structure.
for name = {'width','height','P'}
    validateattributes(p.(name{1}),{'numeric'},{'real','finite','scalar','positive'},'Engine',name{1});
end
for name = {'nx','ny','maxIter','maxNR'}
    validateattributes(p.(name{1}),{'numeric'},{'real','finite','scalar','integer','positive'},'Engine',name{1});
end
validateattributes(p.Emod,{'numeric'},{'real','finite','2d','nonnegative'},'Engine','Emod');
m = size(p.Emod,1);
if ~ismember(m,[1 2]) || size(p.Emod,2)~=2 || any(max(p.Emod,[],2)<=0)
    error('Engine:invalidMaterials','Emod must have one or two [Et Ec] rows with a positive modulus in each row.');
end
validateattributes(p.x0,{'numeric'},{'real','finite','vector','positive'},'Engine','x0');
if numel(p.x0)~=1 && numel(p.x0)~=m
    error('Engine:invalidAreas','x0 must be scalar or contain one area per material.');
end
validateattributes(p.volGroups,{'numeric'},{'real','finite','vector','integer','positive','numel',m},'Engine','volGroups');
groups = unique(p.volGroups(:)).';
if ~isequal(groups,1:max(groups))
    error('Engine:invalidGroups','volGroups must use consecutive group indices starting at 1.');
end
if ~isempty(p.Vmax)
    validateattributes(p.Vmax,{'numeric'},{'real','finite','vector','positive'},'Engine','Vmax');
    if numel(p.Vmax)~=1 && numel(p.Vmax)~=max(groups)
        error('Engine:invalidBudget','Vmax must be scalar or contain one budget per volume group.');
    end
end
if ~any(strcmp(p.plotLabel,{'none','force','area'}))
    error('Engine:invalidLabel','plotLabel must be ''none'', ''force'' or ''area''.');
end
for name = {'supports','loads'}
    a = p.(name{1});
    if isempty(a), continue, end
    validateattributes(a,{'numeric'},{'real','finite','2d','ncols',4},'Engine',name{1});
    if any(a(:,1)<0 | a(:,1)>p.width | a(:,2)<0 | a(:,2)>p.height)
        error('Engine:outsideDomain','%s coordinates must lie inside the rectangular domain.',name{1});
    end
    if ~isempty(p.domain) && any(~inDomain(p.domain,a(:,1:2)))
        error('Engine:outsideDomain','%s coordinates must lie inside the domain shape, outside its openings.',name{1});
    end
end
if ~isempty(p.domain)
    xy = p.domain.outer; tol = 1e-9*max(p.width,p.height);
    if any(abs(min(xy,[],1))>tol) || any(abs(max(xy,[],1)-[p.width p.height])>tol)
        error('Engine:invalidDomain','domain.outer must span exactly [0, width] x [0, height].');
    end
    for k=1:numel(p.domain.holes)
        h = p.domain.holes{k};
        [in,on] = inpolygon(h(:,1),h(:,2),xy(:,1),xy(:,2));
        if any(~in | on), error('Engine:invalidDomain','Each opening must lie strictly inside domain.outer.'); end
    end
end
validateattributes(p.tieFrac,{'numeric'},{'real','finite','scalar','>=',0,'<=',1},'Engine','tieFrac');
validateattributes(p.inactiveFactor,{'numeric'},{'real','finite','scalar','>',0,'<=',1},'Engine','inactiveFactor');
if ~isempty(p.tieAngles)
    validateattributes(p.tieAngles,{'numeric'},{'real','finite','vector','>=',0,'<=',180},'Engine','tieAngles');
end
% Tie restrictions act on row 1, which in the one-row model also carries struts
if m==1 && (p.tieFrac<1 || ~isempty(p.tieAngles))
    error('Engine:tieRestrictionRequiresTwoMaterials', ...
          ['tieFrac and tieAngles require the two-material tie/strut model ' ...
           'Emod = [Et 0; 0 Ec]; with one [Et Ec] row they would also remove struts.']);
end

% Optimizer, filter and plotting settings
for name = {'tolOpt','tolRel','GammaFactor','minLenCells','alpha'}
    validateattributes(p.(name{1}),{'numeric'},{'real','finite','scalar','nonnegative'},'Engine',name{1});
end
for name = {'tolNR','etaMin','etaMax','etaInc','etaDec','moveFactor','xmaxFactor', ...
            'plotMaxWidth','plotWidthGamma','plotFontSize'}
    validateattributes(p.(name{1}),{'numeric'},{'real','finite','scalar','positive'},'Engine',name{1});
end
if p.etaMin>p.etaMax
    error('Engine:invalidDamping','etaMin must not exceed etaMax.');
end
validateattributes(p.alphaF,{'numeric'},{'real','finite','scalar','>=',0,'<',1},'Engine','alphaF');
validateattributes(p.Nfilter,{'numeric'},{'real','finite','scalar','integer','nonnegative'},'Engine','Nfilter');
validateattributes(p.gsLevel,{'numeric'},{'real','scalar','positive','nonnan'},'Engine','gsLevel');
if isfinite(p.gsLevel) && p.gsLevel~=round(p.gsLevel)
    error('Engine:invalidLevel','gsLevel must be a positive integer or Inf.');
end
validateattributes(p.plotShowFrac,{'numeric'},{'real','finite','scalar','>=',0,'<=',1},'Engine','plotShowFrac');
if ~isempty(p.plotMaxArea)
    validateattributes(p.plotMaxArea,{'numeric'},{'real','finite','scalar','positive'},'Engine','plotMaxArea');
end
if ~isempty(p.barColor)
    validateattributes(p.barColor,{'numeric'},{'real','finite','numel',3,'>=',0,'<=',1},'Engine','barColor');
end
for name = {'doPlot','groundOnly','useSymmetry','showZ','plotMergeCollinear', ...
            'plotGround','plotBoundary','plotLoads'}
    v = p.(name{1});
    if ~(isscalar(v) && (islogical(v) || (isnumeric(v) && (v==0 || v==1))))
        error('Engine:invalidFlag','%s must be a scalar true/false.',name{1});
    end
end
end

%% ========================================================================
%  THE MODEL -- geometry only, built once before the first iteration
%% ========================================================================

function G=groundStructure(p)
% --- Grid nodes: grid-line intersections, x changing fastest ------------
dx = p.width/p.nx; dy = p.height/p.ny;
xs = (0:p.nx)*dx; ys = (0:p.ny)*dy;
if ~isempty(p.domain)
    if ~isempty(p.domain.xLines), xs = p.domain.xLines; end
    if ~isempty(p.domain.yLines), ys = p.domain.yLines; end
end
[gx,gy] = ndgrid(0:numel(xs)-1,0:numel(ys)-1);   % grid-line index of each node
NODE = [xs(gx(:)+1).', ys(gy(:)+1).'];
gx = gx(:); gy = gy(:);
if ~isempty(p.domain)   % keep the nodes inside the outline, outside openings
    inside = inDomain(p.domain,NODE);
    NODE = NODE(inside,:); gx = gx(inside); gy = gy(inside);
end
Nn = size(NODE,1);

% --- Candidate bars: every node pair i<j, then the filters --------------
[J,I] = find(tril(true(Nn),-1)); BARS = [I J];
D  = NODE(BARS(:,2),:) - NODE(BARS(:,1),:);
L  = sqrt(D(:,1).^2+D(:,2).^2);
cx = D(:,1)./L; cy = D(:,2)./L;

minLen = p.minLenCells*min(dx,dy);
keep = ~throughNode(NODE,BARS,minLen);           % no bar through a third node
if isfinite(p.gsLevel)                           % connectivity level (Chebyshev)
    cheb = max(abs(gx(BARS(:,1))-gx(BARS(:,2))),abs(gy(BARS(:,1))-gy(BARS(:,2))));
    keep = keep & (cheb<=p.gsLevel);
end
if minLen>0, keep = keep & (L>=minLen-1e-9); end
if ~isempty(p.domain), keep(keep) = segmentsInside(p.domain,NODE,BARS(keep,:)); end

BARS = BARS(keep,:); L = L(keep); cx = cx(keep); cy = cy(keep);

% --- Sparse assembly: each bar adds (k/L)*(Bdir'*Bdir), a 4x4 block -----
DOF  = [2*BARS(:,1)-1, 2*BARS(:,1), 2*BARS(:,2)-1, 2*BARS(:,2)];
Bdir = [-cx, -cy, cx, cy];
iLoc = repmat(1:4,1,4); jLoc = repelem(1:4,4);

% --- Left-right mirror about x = width/2 -------------------------------
nodeMirror = nearestNode(NODE,[p.width-NODE(:,1), NODE(:,2)]);

G = struct('NODE',NODE,'BARS',BARS,'L',L,'cx',cx,'cy',cy, ...
           'numNodes',Nn,'numDof',2*Nn,'numBars',size(BARS,1), ...
           'barMirror',mirrorBars(BARS,nodeMirror),'nodeMirror',nodeMirror, ...
           'DOF',DOF,'Bdir',Bdir,'Krow',reshape(DOF(:,iLoc),[],1), ...
           'Kcol',reshape(DOF(:,jLoc),[],1),'Kpat',Bdir(:,iLoc).*Bdir(:,jLoc));
end

function dom=completeDomain(dom)
% Fill optional domain fields and check the outline; openings become a cell.
if ~isstruct(dom) || ~isscalar(dom) || ~isfield(dom,'outer')
    error('Engine:invalidDomain','domain must be a struct with an outer [x y] outline.');
end
unknown = setdiff(fieldnames(dom),{'outer','holes','xLines','yLines'});
if ~isempty(unknown), error('Engine:invalidDomain','Unknown domain field(s): %s.',strjoin(unknown,', ')); end
for f = {'holes','xLines','yLines'}
    if ~isfield(dom,f{1}), dom.(f{1}) = []; end
end
if isempty(dom.holes), dom.holes = {}; elseif ~iscell(dom.holes), dom.holes = {dom.holes}; end
dom.xLines = unique(dom.xLines(:)).'; dom.yLines = unique(dom.yLines(:)).';   % sorted, distinct
for loop = [{dom.outer}, dom.holes(:).']
    xy = loop{1};
    validateattributes(xy,{'numeric'},{'real','finite','2d','ncols',2},'Engine','domain loop');
    n = size(xy,1);
    if n<3, error('Engine:invalidDomain','Each domain loop needs at least three corners.'); end
    for i=1:n                % non-adjacent edges must not cross or touch
        for j=i+2:n
            if i==1 && j==n, continue, end
            if segmentsCross(xy(i,:),xy(mod(i,n)+1,:),xy(j,:),xy(mod(j,n)+1,:))
                error('Engine:invalidDomain','A domain loop crosses itself.');
            end
        end
    end
end
end

function tf=segmentsCross(a,b,c,d)
% TRUE when segments ab and cd intersect or touch
o = @(p,q,r) sign((q(1)-p(1))*(r(2)-p(2))-(q(2)-p(2))*(r(1)-p(1)));
onSeg = @(a,b,p) p(1)>=min(a(1),b(1)) && p(1)<=max(a(1),b(1)) && ...
                 p(2)>=min(a(2),b(2)) && p(2)<=max(a(2),b(2));
tf = o(a,b,c)~=o(a,b,d) && o(c,d,a)~=o(c,d,b);
tf = tf || (o(a,b,c)==0 && onSeg(a,b,c)) || (o(a,b,d)==0 && onSeg(a,b,d)) ...
        || (o(c,d,a)==0 && onSeg(c,d,a)) || (o(c,d,b)==0 && onSeg(c,d,b));
end

function inside=inDomain(dom,xy)
% Inside or on the outline, and not strictly inside an opening (opening edges allowed)
[in,on] = inpolygon(xy(:,1),xy(:,2),dom.outer(:,1),dom.outer(:,2));
inside = in | on;
for k=1:numel(dom.holes)
    h = dom.holes{k}; [in,on] = inpolygon(xy(:,1),xy(:,2),h(:,1),h(:,2));
    inside = inside & ~(in & ~on);
end
end

function ok=segmentsInside(dom,NODE,BARS)
% A bar is admissible when every piece between its crossings with the domain
% edges lies inside the shape: split each bar at the crossings and test the
% midpoint of every piece (both ends are nodes, already inside)
A = NODE(BARS(:,1),:); R = NODE(BARS(:,2),:)-A; Nb = size(BARS,1);
span = max(max(dom.outer,[],1)-min(dom.outer,[],1)); tol = 1e-9*span;
T = [zeros(Nb,1) ones(Nb,1)];
for loop = [{dom.outer}, dom.holes(:).']
    xy = loop{1}; n = size(xy,1);
    for e=1:n
        C = xy(e,:); Dv = xy(mod(e,n)+1,:)-C;
        den = R(:,1)*Dv(2)-R(:,2)*Dv(1);
        AC = C-A;
        t = (AC(:,1)*Dv(2)-AC(:,2)*Dv(1))./den;          % along the bar
        s = (AC(:,1).*R(:,2)-AC(:,2).*R(:,1))./den;      % along the edge
        hit = abs(den)>tol*max(vecnorm(R,2,2),1) & t>0 & t<1 & s>=-1e-12 & s<=1+1e-12;
        tt = nan(Nb,1); tt(hit) = t(hit); T = [T tt]; %#ok<AGROW>
    end
end
T = sort(T,2);                       % NaN (no crossing) sorts to the end
mid = (T(:,1:end-1)+T(:,2:end))/2;   % midpoints of consecutive pieces
ok = true(Nb,1);
for c=1:size(mid,2)
    rows = ~isnan(mid(:,c)); if ~any(rows), continue, end
    ok(rows) = ok(rows) & inDomain(dom,A(rows,:) + mid(rows,c).*R(rows,:));
end
end

function BC=boundaryConditions(p,G)
% Support nodes, fixed/free DOFs, load nodes and the nodal force vector.
% p.supports rows are [x y fixX fixY]; p.loads rows are [x y Fx Fy]
NODE = G.NODE; numDof = G.numDof;

if ~isempty(p.supports)          % nonzero restraint flags mean fixed
    suppNodes = nearestNode(NODE,p.supports(:,1:2));
    warnSnap(p,NODE,suppNodes,p.supports(:,1:2),'support');
    fixedDof = unique([2*suppNodes(p.supports(:,3)~=0)-1; 2*suppNodes(p.supports(:,4)~=0)]);
else                             % built-in: pin bottom-left, roller bottom-right
    pin    = find(NODE(:,1)<1e-9              & NODE(:,2)<1e-9,1);
    roller = find(abs(NODE(:,1)-p.width)<1e-9 & NODE(:,2)<1e-9,1);
    suppNodes = [pin; roller];
    fixedDof  = [2*pin-1; 2*pin; 2*roller];
end

if ~isempty(p.loads)             % contributions at the same DOF accumulate
    loadNodes = nearestNode(NODE,p.loads(:,1:2));
    warnSnap(p,NODE,loadNodes,p.loads(:,1:2),'load');
    Fext = accumarray([2*loadNodes-1; 2*loadNodes],[p.loads(:,3); p.loads(:,4)],[numDof 1]);
else                             % built-in: P down at top mid-span
    loadNodes = nearestNode(NODE,[p.width/2, p.height]);
    warnSnap(p,NODE,loadNodes,[p.width/2, p.height],'load');
    Fext = zeros(numDof,1); Fext(2*loadNodes) = -p.P;
end

freeDof = setdiff((1:numDof)',fixedDof);
% Reference force for every relative residual: the applied load, but never
% below the reference load P, so the measure is the same in any force unit
Fscale = max(norm(Fext(freeDof)),abs(p.P));
BC = struct('suppNodes',suppNodes,'fixedDof',fixedDof,'freeDof',freeDof, ...
            'Fext',Fext,'loadNodes',loadNodes,'Fscale',Fscale);
end

function warnSnap(p,NODE,idx,xy,what)
% Supports and loads act at the nearest node; say so when that moves them
moved = sqrt(sum((NODE(idx,:)-xy).^2,2));
[dmax,k] = max(moved);
if dmax > 1e-6*max(p.width,p.height)
    warning('Engine:snapped',['%d %s point(s) moved to the nearest node; the largest ' ...
            'move is %.4g, from (%.4g, %.4g) to (%.4g, %.4g).'], ...
            nnz(moved > 1e-6*max(p.width,p.height)),what,dmax,xy(k,1),xy(k,2),NODE(idx(k),1),NODE(idx(k),2));
end
end

function idx=nearestNode(NODE,xy)
% Nearest grid node to each row of xy = [x y]: supports, loads and the mirror map
idx = zeros(size(xy,1),1);
for k=1:size(xy,1)
    [~,idx(k)] = min((NODE(:,1)-xy(k,1)).^2+(NODE(:,2)-xy(k,2)).^2);
end
end

function barMirror=mirrorBars(BARS,nodeMirror)
% Left-right mirror image of each bar; a bar with no mirror maps to itself
Nn  = numel(nodeMirror);
key = @(a,b) (min(a,b)-1)*Nn + max(a,b);
[found,loc] = ismember(key(nodeMirror(BARS(:,1)),nodeMirror(BARS(:,2))), ...
                       key(BARS(:,1),BARS(:,2)));
barMirror = (1:size(BARS,1))';
barMirror(found) = loc(found);
end

function remove=throughNode(NODE,BARS,minLen)
% TRUE for bars passing through another node (redundant). With minLen>0 a bar is
% spared unless BOTH pieces it would split into are long enough to replace it
p1 = NODE(BARS(:,1),:);
D  = NODE(BARS(:,2),:)-p1; len2 = sum(D.^2,2); L = sqrt(len2);
remove = false(size(BARS,1),1);
for n=1:size(NODE,1)
    v = NODE(n,:) - p1;
    crossZ = D(:,1).*v(:,2) - D(:,2).*v(:,1);      % zero => collinear
    along  = (v(:,1).*D(:,1) + v(:,2).*D(:,2))./len2;
    isEnd  = (BARS(:,1)==n) | (BARS(:,2)==n);
    on = (abs(crossZ)<=1e-9*len2) & (along>1e-9) & (along<1-1e-9) & ~isEnd;
    if minLen>0
        on = on & (along.*L>=minLen-1e-9) & ((1-along).*L>=minLen-1e-9);
    end
    remove = remove | on;
end
end

function M=materials(p,G)
% Bilinear materials, tie eligibility, area bounds and volume budgets
m = size(p.Emod,1);
Emax = max(p.Emod,[],2);
Et = max(p.Emod(:,1),p.inactiveFactor*Emax).';   % 1 x m, floored so a dead
Ec = max(p.Emod(:,2),p.inactiveFactor*Emax).';   % branch is soft, not singular

% Ties (material 1) stay in the band y <= tieFrac*H and may be angle-limited
barTopY = max(G.NODE(G.BARS(:,1),2),G.NODE(G.BARS(:,2),2));
allowed = true(G.numBars,m);
allowed(:,1) = barTopY <= p.tieFrac*p.height + 1e-9;
if ~isempty(p.tieAngles)
    allowed(:,1) = allowed(:,1) & angleOK(G.cx,G.cy,p.tieAngles);
end

x0 = p.x0(:);
if numel(x0)<m, x0 = repmat(x0(1),m,1); end

% One budget per volume group (Eq. 2 when Vmax = []): x0 times the total
% length of all candidate bars, independent of tieFrac and tieAngles
volGroups = p.volGroups(:).'; ncon = max(volGroups);
Vmax = zeros(ncon,1);
for j=1:ncon
    if isempty(p.Vmax), Vmax(j) = sum(x0(volGroups==j))*sum(G.L);
    else,               Vmax(j) = p.Vmax(min(j,numel(p.Vmax)));
    end
end

% Tikhonov term: Gamma = GammaFactor*kRef, kRef = largest diagonal of the
% stiffness from the initial areas and the larger modulus of each material
X0 = double(allowed).*x0.';
kBarRef = X0*max(Et,Ec).';
KdiagRef = accumarray(G.DOF(:),reshape((kBarRef./G.L).*G.Bdir.^2,[],1),[G.numDof 1]);
kRef = max(KdiagRef);

M = struct('m',m,'Et',Et,'Ec',Ec,'kRef',kRef,'Gamma',p.GammaFactor*kRef, ...
           'allowed',allowed,'X',X0, ...
           'xmax',p.xmaxFactor.*x0,'move',p.moveFactor.*x0, ...
           'volGroups',volGroups,'ncon',ncon,'Vmax',Vmax);
end

function ok=angleOK(cx,cy,angles)
% TRUE for bars matching an allowed tie angle (degrees, mod 180).
% Angle a also admits 180-a, so a limit is symmetric about the vertical
theta = mod(atan2d(cy,cx),180);
ok = false(numel(cx),1);
for a = unique(mod([angles(:); 180-angles(:)],180)).'
    d  = abs(theta-a);
    ok = ok | (min(d,180-d) < 1e-6);   % min(...) closes the 0/180 wrap
end
end

function tf=isMirrored(nodeMirror,fixedDof,Fext,numDof)
% Is the PROBLEM left-right symmetric about x = width/2? The geometry, the
% restraints and the load must all mirror
isFixed = false(numDof,1); isFixed(fixedDof) = true;
ix = (1:numel(nodeMirror))'; mx = nodeMirror(:);
if ~isequal(isFixed(2*ix),isFixed(2*mx)), tf = false; return, end   % vertical restraint

tol = 1e-9*max(1,max(abs(Fext)));
% Horizontal restraints must mirror, unless a single one only removes rigid
% translation under zero net horizontal load (the default pin/roller model)
fixedX = isFixed(2*ix-1);
horizontalOK = isequal(fixedX,isFixed(2*mx-1)) ...
    || (nnz(fixedX)==1 && abs(sum(Fext(2*ix-1)))<=tol);
tf = horizontalOK ...
  && all(abs(Fext(2*ix)  -Fext(2*mx))  <=tol) ...     % Fy mirrors
  && all(abs(Fext(2*ix-1)+Fext(2*mx-1))<=tol);        % Fx flips sign
end

%% ========================================================================
%  THE OPTIMIZATION
%% ========================================================================

function S=optimizeDesign(p,G,BC,runTimer)
% ZPR optimization loop, then the final equilibrium evaluation
M = materials(p,G);
L = G.L; Fext = BC.Fext; X = M.X;

% Averaging each bar with its left-right twin suppresses drift, but only where
% the PROBLEM is symmetric; a shaped domain is never averaged
barMirror = G.barMirror;
symmetricLR = p.useSymmetry && isempty(p.domain) && ...
              isMirrored(G.nodeMirror,BC.fixedDof,Fext,G.numDof);
if ~symmetricLR
    barMirror = (1:G.numBars)';
    fprintf('  left-right symmetry: NO -- symmetry averaging disabled\n');
end

eta = (1/(1+p.alpha))*ones(G.numBars,M.m);   % ZPR damping, starts at 0.5
Xprev1 = X; Xprev2 = X; u = zeros(G.numDof,1);
hist = struct('J',[],'Z',[],'dX',[],'Vfrac',[],'nNR',[]);   % one row per iteration
PH = p.P*p.height;

fprintf('\n  %s\n',p.label);
fprintf('  %d nodes | %d bars | tie allowed %d/%d | Vmax=[%s]\n', ...
        G.numNodes,G.numBars,nnz(M.allowed(:,1)),G.numBars,num2str(M.Vmax(:).','%.4g '));
if p.showZ
    fprintf('  %4s  %14s  %12s  %10s\n','iter','J = -Pi','max|dX|','Z/(P H)');
    zCol = @(Z) sprintf('  %10.4f',Z/PH);
else
    fprintf('  %4s  %14s  %12s\n','iter','J = -Pi','max|dX|');
    zCol = @(~) '';
end

Zval = NaN;   % stays NaN when showZ is off
converged = false;
for k=1:p.maxIter   % normally exits through the convergence test (h)
    % (a) Nonlinear state: displacements, strain-energy density, bar forces.
    %     analysis stops the run if this state does not converge
    [u,Psi,Fe,~,info] = analysis(p,G,BC,M,X,u);
    hist.nNR(k,1) = info.iterations;

    % (b) Objective J and, optionally, the load-path number Z
    Jval = objectiveJ(Fext,u,X,L,Psi);
    if p.showZ, Zval = Results.loadPath(Fe,L); end

    % (c) Symmetrize the sensitivities, where the problem is symmetric
    Psi = 0.5*(Psi + Psi(barMirror,:));

    % (d) Adaptive damping (Groenwold-Etman): grow eta for bars moving steadily,
    %     shrink it for bars that oscillate
    if k>=3
        trend = (X-Xprev1).*(Xprev1-Xprev2);
        eta(trend>0) = min(p.etaMax,p.etaInc*eta(trend>0));
        eta(trend<0) = max(p.etaMin,p.etaDec*eta(trend<0));
    end

    % (e) ZPR update, one shared multiplier per volume constraint
    Xnew = X;
    for j=1:M.ncon
        mats = (M.volGroups==j);
        Xnew(:,mats) = zprUpdate(X(:,mats),L,Psi(:,mats),eta(:,mats), ...
                                 M.Vmax(j),M.xmax(mats),M.move(mats));
    end
    Xnew = 0.5*(Xnew + Xnew(barMirror,:));

    % (f) Discrete filter from iteration Nfilter on: prune near-zero bars.
    %     Pruning is irreversible: the multiplicative update keeps zero at zero
    if k>=p.Nfilter
        for mm=1:M.m
            big = max(Xnew(:,mm));
            if big>0, Xnew(Xnew(:,mm)<p.alphaF*big,mm) = 0; end
        end
    end

    % (g) Logging and bookkeeping
    dX = max(abs(Xnew(:)-X(:)));
    hist.J(k,1) = Jval; hist.Z(k,1) = Zval/PH; hist.dX(k,1) = dX;
    vol = L.'*X; hist.Vfrac(k,:) = vol/sum(vol);   % material shares of the evaluated design
    Xprev2 = Xprev1; Xprev1 = X; X = Xnew;
    if k==1 || mod(k,50)==0
        fprintf('  %4d  %14.6f  %12.3e%s\n',k,Jval,dX,zCol(Zval));
    end

    % (h) Stop when the design stops moving
    if dX < max(p.tolOpt,p.tolRel*max(X(:)))
        fprintf('  %4d  %14.6f  %12.3e%s   (converged)\n',k,Jval,dX,zCol(Zval));
        converged = true;
        break
    end
end
if converged
    stopReason = 'converged';
else
    stopReason = 'maxIter';
    fprintf(2,'  WARNING: maxIter = %d reached before convergence (max|dX| = %.3e).\n',p.maxIter,dX);
end

% Final evaluation and equilibrium check: internal forces must balance the load
[u,Psi,Fe,Fint,info] = analysis(p,G,BC,M,X,u);
Jval = objectiveJ(Fext,u,X,L,Psi);
Z = NaN; if p.showZ, Z = Results.loadPath(Fe,L)/PH; end
resid = norm(Fint(BC.freeDof)-Fext(BC.freeDof))/BC.Fscale;   % Eq. (9), no Tikhonov term

S = packResult(p,G,BC,M,X,u,Fe,Jval,Z,resid,hist,symmetricLR,converged);
S.stopReason = stopReason;  % 'converged' or 'maxIter'
S.stateInfo = info;         % Newton record of the final state solve
S.elapsedSeconds = toc(runTimer);   % whole Engine call, model building included
if ~isempty(p.resultDir), S.resultDir = Results.save(S,S.fig,p.resultDir); end
end

function [u,Psi,Fe,Fint,info]=analysis(p,G,BC,M,area,u)
% Newton-Raphson state solve at the given areas, then Psi, Fe and Fint.
% Must reach |R| < tolNR*Fscale, otherwise the run stops (no unconverged
% state reaches the update). Line search: Armijo backtracking on Pi (Eq. 3),
% which is smooth across lambda = 1; near the solution, where the change in
% Pi is below round-off, a step that lowers |R| is accepted instead.
freeDof = BC.freeDof; Fext = BC.Fext; tol = p.tolNR*BC.Fscale;
info = struct('converged',false,'iterations',0,'relResidual',NaN);
Pi = potential(G,M,area,u,Fext);
for it=1:p.maxNR+1                           % maxNR updates, each followed by a check
    [F,Kt] = assemble(G,M,area,u);
    R = F(freeDof) - Fext(freeDof); Rn = norm(R);
    info.relResidual = Rn/BC.Fscale;
    if Rn < tol, info.converged = true; break, end
    if it>p.maxNR, break, end
    info.iterations = it;

    Kt = Kt + M.Gamma*speye(G.numDof);      % Tikhonov on the diagonal
    du = -Kt(freeDof,freeDof)\R;
    slope = R.'*du;                          % dPi/dstep at step 0; < 0 (descent)

    step = 1; accepted = false;              % backtracking (Armijo) line search
    for ls=1:40
        uTry = u; uTry(freeDof) = u(freeDof) + step*du;
        PiTry = potential(G,M,area,uTry,Fext);
        if PiTry <= Pi + 1e-4*step*slope + 1e-13*abs(Pi)
            accepted = true;
        else
            Ftry = assemble(G,M,area,uTry);
            accepted = norm(Ftry(freeDof)-Fext(freeDof)) < Rn;
        end
        if accepted, break, end
        step = step/2;
    end
    if ~accepted
        error('Engine:lineSearchFailed', ['Newton line search could reduce neither the ' ...
              'energy nor the residual (relative residual %.3e after %d iteration(s)).'],Rn/BC.Fscale,it-1);
    end
    u = uTry; Pi = PiTry;
end
if ~info.converged
    error('Engine:stateNotConverged', ['State analysis did not converge within ' ...
          'maxNR = %d (relative residual %.3e, tolNR = %.1e).'],p.maxNR,info.relResidual,p.tolNR);
end
[Fe,~,Psi] = barState(M,area,barStretch(G,u));
Psi = max(Psi,1e-30);       % floored: the ZPR update divides by it
Fint = nodalForces(G,Fe);
end

function [Fint,Kt]=assemble(G,M,area,u)
% Internal nodal forces and, when asked for, the sparse tangent stiffness
[Fe,kBar] = barState(M,area,barStretch(G,u));
Fint = nodalForces(G,Fe);
if nargout>1
    Kt = sparse(G.Krow,G.Kcol,reshape((kBar./G.L).*G.Kpat,[],1),G.numDof,G.numDof);
end
end

function [Fe,kBar,Psi]=barState(M,area,lam)
% Bar forces, axial stiffness (area*E) and, when asked for, the strain-energy
% density of each material, for the bar stretches lam
nb = numel(lam);
Fe = zeros(nb,1); kBar = zeros(nb,1); Psi = zeros(nb,M.m);
for mm=1:M.m
    E = M.Et(mm)*(lam>=1) + M.Ec(mm)*(lam<1);   % one-sided bilinear modulus
    Fe   = Fe   + area(:,mm).*E.*(lam-1);
    kBar = kBar + area(:,mm).*E;
    if nargout>2, Psi(:,mm) = 0.5*E.*(lam-1).^2; end
end
end

function Fint=nodalForces(G,Fe)
% Assemble bar forces into nodal internal forces
Fc = Fe.*G.Bdir;
Fint = accumarray(G.DOF(:),Fc(:),[G.numDof 1]);
end

function lam=barStretch(G,u)
% Axial stretch of every bar: 1 + elongation/L
lam = 1 + sum(G.Bdir.*u(G.DOF),2)./G.L;
end

function Pi=potential(G,M,area,u,Fext)
% Total potential energy Pi = strain energy - F'u (Eq. (3)); Pi = -J
[~,~,Psi] = barState(M,area,barStretch(G,u));
Pi = sum(sum(area.*(G.L.*Psi))) - Fext.'*u;
end

function J=objectiveJ(Fext,u,X,L,Psi)
% J = -Pi = F'u - integral of the strain energy
J = Fext.'*u - sum(sum(X.*(L.*Psi)));
end

function Xnew=zprUpdate(X,L,Psi,eta,Vmax,xmax,move)
% ZPR update for the materials sharing ONE volume constraint: grow useful bars,
% shrink the rest, and bisect on the multiplier phi until the budget is met
g = size(X,2);
xLow  = max(0,X-reshape(move,1,g));
xHigh = min(reshape(xmax,1,g),X+reshape(move,1,g));
Lg    = repmat(L,1,g);
tryArea  = @(phi) min(xHigh,max(xLow,X.*(Psi./phi).^eta));
groupVol = @(phi) sum(sum(Lg.*tryArea(phi)));

if groupVol(realmin)<=Vmax   % largest allowed areas already fit the budget
    Xnew = tryArea(realmin); return
end
phiLo = 1e-30; phiHi = 1e30;
for it=1:200
    phi = sqrt(phiLo*phiHi);
    if groupVol(phi)>Vmax, phiLo = phi; else, phiHi = phi; end
end
Xnew = tryArea(sqrt(phiLo*phiHi));
end

%% ========================================================================
%  THE RESULT STRUCT
%% ========================================================================

function S=baseResult(p,G,BC)
% The model description, identical whether or not anything was solved
S = struct();
S.parameters = p;           % complete effective inputs, including filled defaults
S.NODE = G.NODE;            S.BARS = G.BARS;          S.L = G.L;
S.width = p.width;          S.height = p.height;
S.nx = p.nx;                S.ny = p.ny;
S.gsLevel = p.gsLevel;
S.suppNodes = BC.suppNodes; S.loadNodes = BC.loadNodes;
S.supports = p.supports;    S.loads = p.loads;
S.Fext = BC.Fext;           S.fixedDof = BC.fixedDof;   S.Emod = p.Emod;
S.units = p.units;          S.source = p.source;        S.label = p.label;
S.domain = p.domain;        % [] for the full rectangle
end

function S=packResult(p,G,BC,M,X,u,Fe,Jval,Z,resid,hist,symmetricLR,converged)
% Package the finished design, check the drawing, plot and save
L = G.L; m = M.m;
matVol   = zeros(max(m,2),1); matVol(1:m) = sum(L.*X,1).';
matVfrac = zeros(max(m,2),1);
if sum(matVol)>0, matVfrac(1:m) = matVol(1:m)/sum(matVol); end

S = baseResult(p,G,BC);
S.X = X;                    S.u = u;   % final nodal displacements
S.Fe = Fe;                  % signed: + tension, - compression
S.J = Jval;                 S.Z = Z;
S.matVol = matVol;          S.matVfrac = matVfrac;
S.nActive = nnz(any(X>0,2));
S.resid = resid;            S.equilOK = isfinite(Jval) && resid<1e-3;
S.Fscale = BC.Fscale;       % reference force of every relative residual
S.kRef = M.kRef;            S.Gamma = M.Gamma;   % Tikhonov reference stiffness and term
S.Vmax = M.Vmax;            S.P = p.P;
aAct = X(X>0);              % aTop: min/max surviving area, the structural resolution
S.aTop = NaN; if ~isempty(aAct), S.aTop = min(aAct)/max(aAct); end
S.tieFrac = p.tieFrac;      S.tieAngles = p.tieAngles;  S.minLenCells = p.minLenCells;
S.nBars = G.numBars;        % candidates offered
S.barMirror = G.barMirror;  % left-right twin of each bar (geometry only)
S.symmetricLR = symmetricLR;   % whether the mirror average was APPLIED
S.elig = M.allowed;         S.hist = hist;
S.nIter = numel(hist.J);
S.converged = converged;    % false when maxIter stopped the run
S.alphaF = p.alphaF;        S.Nfilter = p.Nfilter;
for f = {'plotShowFrac','plotMergeCollinear','plotMaxArea', ...
         'plotMaxWidth','plotWidthGamma','barColor','plotGround','plotBoundary', ...
         'plotLoads','plotLabel','plotFontSize'}
    S.(f{1}) = p.(f{1});
end
S.resultDir = '';           % set by Results.save, so Results.rescale can write back

if ~S.equilOK
    fprintf(2,'  WARNING: final equilibrium check failed (relative residual %.3e).\n',resid);
end

% Check the drawing: the displayed members must form a valid truss
Mx = Results.metrics(S);
S.nShown = Mx.nShown;   S.nMerged = Mx.nMerged;   S.nDangle = Mx.nDangle;
S.nIsolated = Mx.nIsolated;  S.nLoadIsolated = Mx.nLoadIsolated;
if Mx.nLoadIsolated>0 || Mx.nDangle>0 || Mx.nIsolated>0
    fprintf(2,['  !! the DRAWING (bars >= %.3g of max area) is not a valid truss: ' ...
               '%d loaded node(s) off the load path, %d dangling, %d isolated.\n'], ...
            S.plotShowFrac,Mx.nLoadIsolated,Mx.nDangle,Mx.nIsolated);
    if S.equilOK
        fprintf(2,['     The full design IS in equilibrium, so the plot is slicing an ' ...
                   'un-discretized design mid-member.\n     Raise minLenCells to ' ...
                   'discretize it, or lower plotShowFrac to see the hidden members.\n']);
    end
end

S.fig = [];
if p.doPlot, S.fig = Results.plot(S); end
% Saved by optimizeDesign, after the run time is recorded
end
