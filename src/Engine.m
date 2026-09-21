function S=Engine(p)
%STMTopRC - Strut-and-Tie Topology optimization for Reinforced Concrete.
%   S = Engine(p) builds the model from p and optimizes it.
%   p must carry the 7 MODEL fields -- width, height, nx, ny, P, Emod, x0 --
%   and maxIter.  Every other parameter falls back to the DEFAULTS block
%   below, which is the complete list of what Engine accepts.
% SPDX-License-Identifier: GPL-3.0-or-later

if ~isstruct(p) || ~isscalar(p)
    error('Engine:notStruct',['Engine takes a parameter STRUCT, not a %s.\n' ...
          '  Define p in an examples/run_*.m script, then call Engine(p).'],class(p))
end

%% === DEFAULTS ===========================================================
%  Default values for optional settings not supplied by the caller.
%  Each run_*.m supplies the model parameters and sets maxIter.
d = struct();

% supports and loads ([] = built-in simply-supported deep-beam case)
d.supports = [];            % [x y fixX fixY ; ...]
d.loads    = [];            % [x y Fx Fy ; ...]
d.loadAt   = 'top';         % default single load: 'top' or 'bottom'

% material and volume
d.inactiveFactor = 1e-6;    % floor on the inactive branch of each material
d.volGroups  = [];          % volGroups(mat) = constraint index; [] = 1:m
d.Vmax       = [];          % per-constraint budget; [] = auto (x0*sum(L))
d.xmaxFactor = 1e4;         % xmax = xmaxFactor*x0
d.moveFactor = 1e4;         % move limit = moveFactor*x0

% ground structure
d.gsLevel     = Inf;        % keep bars within N cells (Chebyshev); Inf = all pairs
d.minLenCells = 0;          % minimum member length, in grid cells
d.groundOnly  = false;      % build the model and return WITHOUT optimizing

% optimizer settings. Each run_*.m sets maxIter for its case, so the
% iteration limit is explicit and suited to that case.
d.alpha       = 1.0;        % ZPR damping exponent; eta0 = 1/(1+alpha)
d.tolOpt      = 1e-9;       % stop when max|dX| falls below this (absolute)
d.tolRel      = 0;          % also stop when max|dX| < tolRel*max(area); 0 = off
d.maxNR       = 40;         % maximum Newton-Raphson iterations per state solve
d.tolNR       = 1e-8;       % Newton-Raphson residual tolerance
d.GammaFactor = 1e-10;      % Tikhonov term = GammaFactor*max(Emod)
d.etaMin      = 0.20;       % lower bound on the adaptive damping
d.etaMax      = 1.00;       % upper bound on the adaptive damping
d.etaInc      = 1.20;       % damping growth factor for steady bars
d.etaDec      = 0.70;       % damping decay factor for oscillating bars

% discrete filter
d.alphaF  = 1e-4;           % prune bars below this fraction of the max area
d.Nfilter = 350;            % start filtering after this iteration

% tie placement
d.tieFrac   = 1.0;          % ties confined to y <= tieFrac*height
d.tieAngles = [];           % allowed tie angles in degrees; [] = any

% output
d.doPlot    = true;         % draw the optimized layout
d.resultDir = '';           % save dir; bare name = results/<name>; '' = no save
d.label     = 'STM run';    % title used in figures and printouts
d.plotShowFrac       = 0.02;   % hide members below this fraction of max area
d.plotMergeCollinear = true;   % collapse pass-through nodes when plotting
d.plotPruneDangling  = false;  % iteratively hide one-ended branches when plotting
d.plotMaxArea   = [];       % bar area drawn at full line width; [] = own largest
d.plotMaxWidth  = 5;        % line width added at plotMaxArea
d.plotWidthGamma = 1;       % exponent on the area fraction; 1 = width ~ area
d.barColor      = [];       % RGB triplet for every bar; [] = blue tie / red strut
d.showZ         = true;     % compute and report the load-path number Z/(P*H)

% documentation (carried into summary.txt, never used in the math)
d.units  = '';              % unit system, e.g. 'kN, m' or 'kip, in'
d.source = '';              % paper and figure this case reproduces
required = {'width','height','nx','ny','P','Emod','x0','maxIter'};
missing = setdiff(required,fieldnames(p));
if ~isempty(missing)
    error('Engine:missingParameter','Missing required parameter(s): %s.',strjoin(missing,', '));
end
unknown = setdiff(fieldnames(p),[fieldnames(d); required(:)]);
if ~isempty(unknown)
    error('Engine:unknownParameter','Unknown parameter(s): %s.',strjoin(unknown,', '));
end
f = fieldnames(d);
for k=1:numel(f)
    if ~isfield(p,f{k}), p.(f{k}) = d.(f{k}); end
end
if isempty(p.volGroups), p.volGroups = 1:size(p.Emod,1); end  % One constraint per material
validateParameters(p);

%% === MODEL SETUP ========================================================
G  = groundStructure(p);    % Grid nodes, candidate bars, assembly indices
BC = boundaryConditions(p,G);   % Fixed/free DOFs and the nodal force vector

%% === OPTIMIZATION =======================================================
if p.groundOnly, S = groundResult(p,G,BC); return, end
S = optimizeDesign(p,G,BC);
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
for name = {'supports','loads'}
    a = p.(name{1});
    if ~isempty(a)
        validateattributes(a,{'numeric'},{'real','finite','2d','ncols',4},'Engine',name{1});
        if any(a(:,1)<0 | a(:,1)>p.width | a(:,2)<0 | a(:,2)>p.height)
            error('Engine:outsideDomain','%s coordinates must lie inside the rectangular domain.',name{1});
        end
    end
end
validateattributes(p.tieFrac,{'numeric'},{'real','finite','scalar','>=',0,'<=',1},'Engine','tieFrac');
validateattributes(p.inactiveFactor,{'numeric'},{'real','finite','scalar','>',0,'<=',1},'Engine','inactiveFactor');
end

%% ========================================================================
%  THE MODEL -- geometry only.  Nothing below depends on a bar area, so it
%  runs once, before the first iteration.
%% ========================================================================

function G=groundStructure(p)
% --- Grid nodes: (nx+1) x (ny+1), x changing fastest --------------------
dx = p.width/p.nx; dy = p.height/p.ny;
[gx,gy] = ndgrid(0:p.nx,0:p.ny);
NODE = [gx(:)*dx, gy(:)*dy];
Nn = size(NODE,1);

% --- Candidate bars: every node pair i<j, then the filters --------------
[J,I] = find(tril(true(Nn),-1)); BARS = [I J];
D  = NODE(BARS(:,2),:) - NODE(BARS(:,1),:);
L  = sqrt(D(:,1).^2+D(:,2).^2);
cx = D(:,1)./L; cy = D(:,2)./L;

minLen = 0;
if p.minLenCells>0, minLen = p.minLenCells*min(dx,dy); end

% Drop bars passing straight through a third node (redundant)
keep = ~throughNode(NODE,BARS,minLen);

% Connectivity 'level': keep only bars spanning <= gsLevel cells (Chebyshev)
if isfinite(p.gsLevel)
    ix = round(NODE(:,1)/dx); iy = round(NODE(:,2)/dy);
    cheb = max(abs(ix(BARS(:,1))-ix(BARS(:,2))),abs(iy(BARS(:,1))-iy(BARS(:,2))));
    keep = keep & (cheb<=p.gsLevel);
end

if minLen>0, keep = keep & (L>=minLen-1e-9); end   % Length control

BARS = BARS(keep,:); L = L(keep); cx = cx(keep); cy = cy(keep);
Nb = size(BARS,1);

% --- Sparse assembly indices -------------------------------------------
DOF  = [2*BARS(:,1)-1, 2*BARS(:,1), 2*BARS(:,2)-1, 2*BARS(:,2)];
Bdir = [-cx, -cy, cx, cy];      % axial-direction row per bar
% Each bar adds (k/L)*(Bdir'*Bdir), a 4x4 block, to the tangent stiffness
iLoc = [1 2 3 4 1 2 3 4 1 2 3 4 1 2 3 4];
jLoc = [1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4];

% --- Left-right mirror about x = width/2 -------------------------------
nodeMirror = nearestNode(NODE,[p.width-NODE(:,1), NODE(:,2)]);
barMirror  = mirrorBars(BARS,nodeMirror);

G = struct('NODE',NODE,'BARS',BARS,'L',L,'cx',cx,'cy',cy, ...
           'numNodes',Nn,'numDof',2*Nn,'numBars',Nb, ...
           'barMirror',barMirror,'nodeMirror',nodeMirror, ...
           'DOF',DOF,'Bdir',Bdir,'Krow',reshape(DOF(:,iLoc),[],1), ...
           'Kcol',reshape(DOF(:,jLoc),[],1),'Kpat',Bdir(:,iLoc).*Bdir(:,jLoc));
end

function BC=boundaryConditions(p,G)
% Support nodes, fixed/free DOFs, load nodes and the nodal force vector.
% p.supports rows are [x y fixX fixY]; p.loads rows are [x y Fx Fy]
NODE = G.NODE; numDof = G.numDof;

% --- Supports: nonzero restraint flags mean fixed -----------------------
if ~isempty(p.supports)
    suppNodes = nearestNode(NODE,p.supports(:,1:2));   % snap to the grid
    fixX = p.supports(:,3)~=0; fixY = p.supports(:,4)~=0;
    fixedDof = unique([2*suppNodes(fixX)-1; 2*suppNodes(fixY)]);
    pinNode = suppNodes(1); rollerNode = suppNodes(end);
else % Built-in simply-supported case: pin bottom-left, roller bottom-right
    pinNode    = find(NODE(:,1)<1e-9              & NODE(:,2)<1e-9,1);
    rollerNode = find(abs(NODE(:,1)-p.width)<1e-9 & NODE(:,2)<1e-9,1);
    fixedDof   = [2*pinNode-1; 2*pinNode; 2*rollerNode];
    suppNodes  = [pinNode; rollerNode];
end

% --- Loads: contributions at the same DOF accumulate --------------------
if ~isempty(p.loads)
    loadNodes = nearestNode(NODE,p.loads(:,1:2));      % snap to the grid
    Fext = accumarray([2*loadNodes-1; 2*loadNodes],[p.loads(:,3); p.loads(:,4)],[numDof 1]);
else % Built-in single load, P down at mid-span
    loadY = p.height; if strcmpi(p.loadAt,'bottom'), loadY = 0; end
    loadNodes = nearestNode(NODE,[p.width/2, loadY]);
    Fext = zeros(numDof,1); Fext(2*loadNodes) = -p.P;
end

BC = struct('suppNodes',suppNodes,'pinNode',pinNode,'rollerNode',rollerNode, ...
            'fixedDof',fixedDof,'freeDof',setdiff((1:numDof)',fixedDof), ...
            'Fext',Fext,'loadNodes',loadNodes);
end

function idx=nearestNode(NODE,xy)
% Nearest grid node to each row of xy = [x y].  Supports, loads and the mirror
% map all snap this way, so the rule lives here once. 
idx = zeros(size(xy,1),1);
for k=1:size(xy,1)
    [~,idx(k)] = min((NODE(:,1)-xy(k,1)).^2+(NODE(:,2)-xy(k,2)).^2);
end
end

function barMirror=mirrorBars(BARS,nodeMirror)
% Match each bar to its left-right mirror image, given the node map.
% A bar with no mirror maps to itself, so averaging leaves it alone
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
p1 = NODE(BARS(:,1),:); p2 = NODE(BARS(:,2),:);
D  = p2-p1; len2 = sum(D.^2,2); L = sqrt(len2);
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

%% ========================================================================
%  THE RESULT STRUCT
%% ========================================================================

function S=baseResult(p,G,BC)
% The MODEL description, identical whether or not anything was solved.
% groundResult and packResult both start here, so the two cannot drift apart
S = struct();
S.parameters = p;          % Complete effective inputs, including filled defaults
S.NODE = G.NODE;            S.BARS = G.BARS;          S.L = G.L;
S.width = p.width;          S.height = p.height;
S.nx = p.nx;                S.ny = p.ny;
S.gsLevel = p.gsLevel;
S.suppNodes = BC.suppNodes; S.loadNodes = BC.loadNodes;
S.supports = p.supports;    S.loads = p.loads;
S.pinNode = BC.pinNode;     S.rollerNode = BC.rollerNode;
S.Fext = BC.Fext;           S.Emod = p.Emod;
S.units = p.units;          S.source = p.source;      S.label = p.label;
end

function S=groundResult(p,G,BC)
% Package the model with p.groundOnly: geometry, supports and loads, nothing solved
S = baseResult(p,G,BC);
S.fixedDof = BC.fixedDof;
S.groundOnly = true;
end

function S=optimizeDesign(p,G,BC)
% ZPR optimization loop, then the final equilibrium evaluation
M = materials(p,G);
L = G.L; Fext = BC.Fext; X = M.X;

% Averaging each bar with its left-right twin suppresses drift, but only where
% the PROBLEM is symmetric. Elsewhere the map is made a no-op
barMirror = G.barMirror;
symmetricLR = isMirrored(G.nodeMirror,BC.fixedDof,Fext,G.numDof);
if ~symmetricLR
    barMirror = (1:G.numBars)';
    fprintf('  left-right symmetry: NO -- symmetry averaging disabled\n');
end

%% --- Optimization loop --------------------------------------------------
eta = (1/(1+p.alpha))*ones(G.numBars,M.m);   % ZPR damping, starts at 0.5
Xprev1 = X; Xprev2 = X; u = zeros(G.numDof,1);
histLog.J = nan(p.maxIter,1); histLog.Z = nan(p.maxIter,1); histLog.dX = nan(p.maxIter,1);

zCol = @(Z) sprintf('  %10.4f',Z/(p.P*p.height));  % the Z/(P H) column
if ~p.showZ, zCol = @(~) ''; end

fprintf('\n  %s\n',p.label);
fprintf('  %d nodes | %d bars | tie allowed %d/%d | Vmax=[%s]\n', ...
        G.numNodes,G.numBars,nnz(M.allowed(:,1)),G.numBars,num2str(M.Vmax(:).','%.4g '));
if p.showZ, fprintf('  %4s  %14s  %12s  %10s\n','iter','J = -Pi','max|dX|','Z/(P H)');
else,       fprintf('  %4s  %14s  %12s\n','iter','J = -Pi','max|dX|'); end

Zval = NaN; converged = false;   % Zval stays NaN when showZ is off
for k=1:p.maxIter
    % (a) Solve the nonlinear state, and with it the strain energy and forces
    [u,~,Psi,Fe] = analysis(p,G,BC,M,X,u);

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

    % (f) Discrete filter: after Nfilter steps, prune near-zero bars
    if k>=p.Nfilter
        for mm=1:M.m
            big = max(Xnew(:,mm));
            if big>0, Xnew(Xnew(:,mm)<p.alphaF*big,mm) = 0; end
        end
    end

    % (g) Logging and bookkeeping
    dX = max(abs(Xnew(:)-X(:)));
    histLog.J(k) = Jval; histLog.Z(k) = Zval/(p.P*p.height); histLog.dX(k) = dX;
    Xprev2 = Xprev1; Xprev1 = X; X = Xnew;
    if k==1 || mod(k,50)==0
        fprintf('  %4d  %14.6f  %12.3e%s\n',k,Jval,dX,zCol(Zval));
    end

    % (h) Stop when the design stops moving
    if k>5 && dX < max(p.tolOpt,p.tolRel*max(X(:)))
        converged = true;
        fprintf('  %4d  %14.6f  %12.3e%s   (converged)\n',k,Jval,dX,zCol(Zval));
        break
    end
end
if ~converged
    fprintf(2,'  WARNING: reached maxIter=%d without satisfying the tolerance.\n',p.maxIter);
end

%% --- Final evaluation ---------------------------------------------------
[u,~,PsiF,Fe,Fint] = analysis(p,G,BC,M,X,u);
Jval = objectiveJ(Fext,u,X,L,PsiF);
michellZ = NaN; if p.showZ, michellZ = Results.loadPath(Fe,L); end

% Equilibrium check: internal forces should balance the applied load
resid = norm(Fint(BC.freeDof)-Fext(BC.freeDof))/max(norm(Fext(BC.freeDof)),1);

O = struct('X',X,'Fe',Fe,'Jval',Jval,'michellZ',michellZ,'resid',resid, ...
           'equilOK',isfinite(Jval)&&resid<1e-3,'hist',histLog, ...
           'symmetricLR',symmetricLR,'converged',converged);
S = packResult(p,G,BC,M,O);
end


function [u,lam,Psi,Fe,Fint]=analysis(p,G,BC,M,area,u0)
% Solve the nonlinear state for the given bar areas, starting from u0.
%   [u,lam]                 -- displacements and bar stretches only
%   [u,lam,Psi,Fe]      -- + strain-energy density and axial forces
%   [u,lam,Psi,Fe,Fint] -- + nodal internal forces (the equilibrium check)
% Each trailing group costs an extra pass over the bars, so it is computed only
% when asked for: the optimization loop takes four outputs, the final call five
Psi = []; Fe = []; Fint = [];
freeDof = BC.freeDof; Fext = BC.Fext;

% Newton-Raphson: find the displacements where bar forces balance the load
u = u0;
for it=1:p.maxNR
    [F,Kt] = assemble(G,M,area,u,true);
    R = F(freeDof) - Fext(freeDof); Rn = norm(R);
    if Rn < p.tolNR*max(norm(Fext(freeDof)),1) || Rn < 1e-12, break, end

    Kt = Kt + M.Gamma*speye(G.numDof);      % Tikhonov on the diagonal
    du = -Kt(freeDof,freeDof)\R;

    step = 1;                                % Backtracking line search
    for ls=1:25
        uTry = u; uTry(freeDof) = u(freeDof) + step*du;
        Ftry = assemble(G,M,area,uTry,false);
        if norm(Ftry(freeDof)-Fext(freeDof)) < Rn, break, end
        step = step/2;
    end
    u(freeDof) = u(freeDof) + step*du;
end
lam = barStretch(G,u);

if nargout>2
    Psi    = zeros(G.numBars,M.m);
    Fe = zeros(G.numBars,1);
    for mm=1:M.m
        E = barModulus(lam,M.Et(mm),M.Ec(mm));
        Psi(:,mm) = 0.5*E.*(lam-1).^2;
        Fe    = Fe + area(:,mm).*E.*(lam-1);
    end
    Psi = max(Psi,1e-30);       % Floored: the ZPR update divides by it
end
if nargout>4
    % Fe above IS assemble's Fe, bar for bar, so the internal forces
    % follow from it directly rather than from a second pass over the model
    Fc = Fe.*G.Bdir;
    Fint = accumarray(G.DOF(:),Fc(:),[G.numDof 1]);
end
end


function [Fint,Kt]=assemble(G,M,area,u,wantK)
% Internal forces and, when wantK, the sparse tangent stiffness
lam  = barStretch(G,u);
Fe = zeros(G.numBars,1); kBar = zeros(G.numBars,1);
for mm=1:M.m
    E    = barModulus(lam,M.Et(mm),M.Ec(mm));
    Fe = Fe + area(:,mm).*E.*(lam-1);
    kBar = kBar + area(:,mm).*E;
end
Fc   = Fe.*G.Bdir;
Fint = accumarray(G.DOF(:),Fc(:),[G.numDof 1]);

Kt = [];
if wantK
    Kt = sparse(G.Krow,G.Kcol,reshape((kBar./G.L).*G.Kpat,[],1),G.numDof,G.numDof);
end
end


function E=barModulus(lam,Et,Ec)
% One-sided bilinear bar modulus: Et in tension, Ec in compression
E = Et*(lam>=1) + Ec*(lam<1);
end


function lam=barStretch(G,u)
% Axial stretch of every bar: 1 + elongation/L. Asked for by both the analysis
% and the assembly, so the definition lives here once
lam = 1 + sum(G.Bdir.*u(G.DOF),2)./G.L;
end


function J=objectiveJ(Fext,u,X,L,Psi)
% The objective, in ONE place: J = -Pi = F'u - integral of the strain-energy
J = Fext.'*u - sum(sum(X.*(L.*Psi)));
end

function M=materials(p,G)
% Initialize the bilinear materials, tie eligibility, area bounds and budgets
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

% The volume budget is per CONSTRAINT, not per material: materials sharing a
% group share one budget. [] = auto, the whole ground structure at x0
volGroups = p.volGroups(:).'; ncon = max(volGroups);
Vuser = p.Vmax(:); Vmax = zeros(ncon,1);
for j=1:ncon
    if isempty(Vuser), Vmax(j) = sum(x0(volGroups==j))*sum(G.L);
    else,              Vmax(j) = Vuser(min(j,numel(Vuser)));
    end
end

M = struct('m',m,'Et',Et,'Ec',Ec,'Gamma',p.GammaFactor*max(p.Emod(:)), ...
           'allowed',allowed,'X',double(allowed).*x0.', ...
           'xmax',p.xmaxFactor.*x0,'move',p.moveFactor.*x0, ...
           'volGroups',volGroups,'ncon',ncon,'Vmax',Vmax);
end


function ok=angleOK(cx,cy,angles)
% TRUE for bars matching an allowed tie angle (degrees, mod 180).
% Angle 'a' also admits 180-a, so a limit is symmetric about the vertical
tol = 1e-6;
theta = mod(atan2d(cy,cx),180);
ok = false(numel(cx),1);
for a = unique(mod([angles(:); 180-angles(:)],180)).'
    d  = abs(theta-a);
    ok = ok | (min(d,180-d) < tol);   % min(...) closes the 0/180 wrap
end
end


function tf=isMirrored(nodeMirror,fixedDof,Fext,numDof)
% Is the PROBLEM left-right symmetric about x = width/2? Geometry alone is not
% enough -- the restraints and the load must mirror too
isFixed = false(numDof,1); isFixed(fixedDof) = true;
ix = (1:numel(nodeMirror))'; mx = nodeMirror(:);

tf = isequal(isFixed(2*ix),isFixed(2*mx));            % vertical restraint
if ~tf, return, end

tol = 1e-9*max(1,max(abs(Fext)));
% A single horizontal restraint only removes rigid horizontal translation
% when the net horizontal load is zero (the default pin/roller model).
% Multiple horizontal restraints must themselves mirror: otherwise averaging
% would impose symmetry on a physically asymmetric boundary-value problem.
fixedX = isFixed(2*ix-1);
horizontalOK = isequal(fixedX,isFixed(2*mx-1)) ...
    || (nnz(fixedX)==1 && abs(sum(Fext(2*ix-1)))<=tol);
if ~horizontalOK, tf = false; return, end
tf = all(abs(Fext(2*ix)  -Fext(2*mx))  <=tol) ...     % Fy mirrors
  && all(abs(Fext(2*ix-1)+Fext(2*mx-1))<=tol);        % Fx flips sign
end


function Xnew=zprUpdate(X,L,Psi,eta,Vmax,xmax,move)
% ZPR update for the materials sharing ONE volume constraint: grow useful bars,
% shrink the rest, and bisect on the multiplier phi until the budget is met
g = size(X,2);
xLow  = max(0,X-reshape(move,1,g));               % row vectors broadcast down
xHigh = min(reshape(xmax,1,g),X+reshape(move,1,g));
Lg    = repmat(L,1,g);
tryArea  = @(phi) min(xHigh,max(xLow,X.*(Psi./phi).^eta));
groupVol = @(phi) sum(sum(Lg.*tryArea(phi)));

if groupVol(realmin)<=Vmax   % Largest allowed areas already fit the budget
    Xnew = tryArea(realmin); return
end
phiLo = 1e-30; phiHi = 1e30;
for it=1:200
    phi = sqrt(phiLo*phiHi);
    if groupVol(phi)>Vmax, phiLo = phi; else, phiHi = phi; end
end
Xnew = tryArea(sqrt(phiLo*phiHi));
end


function S=packResult(p,G,BC,M,O)
% Package the finished design, report it, check the drawing, plot and save
X = O.X; L = G.L; m = M.m;

matVol   = zeros(max(m,2),1); matVol(1:m) = sum(L.*X,1).';
matVfrac = zeros(max(m,2),1);
if sum(matVol)>0, matVfrac(1:m) = matVol(1:m)/sum(matVol); end

S = baseResult(p,G,BC);   % geometry, supports, loads, documentation
S.X = X;
S.Fe = O.Fe;   % Signed: + tension, - compression. Tells ties from
                       % struts when there is only ONE material
S.J = O.Jval;     S.Z = O.michellZ/(p.P*p.height);
S.matVol = matVol;     S.matVfrac = matVfrac;
S.nActive = nnz(any(X>0,2));
S.resid = O.resid;     S.equilOK = O.equilOK;
S.Vmax = M.Vmax;       S.P = p.P;

% aTop: min/max area over the surviving bars -- the structural resolution
aAct = X(X>0);
if isempty(aAct), S.aTop = NaN; else, S.aTop = min(aAct)/max(aAct); end

S.tieFrac = p.tieFrac;
S.tieAngles = p.tieAngles;  S.minLenCells = p.minLenCells;
S.nBars = G.numBars;        % candidates offered
S.barMirror = G.barMirror;  % left-right twin of each bar, purely geometric:
                            % ask it whether an ANSWER came out symmetric
S.symmetricLR = O.symmetricLR;  % whether the mirror average was APPLIED
S.elig = M.allowed;         S.hist = O.hist;
S.nIter = find(~isnan(O.hist.J),1,'last');
S.converged = O.converged;
S.alphaF = p.alphaF;  S.Nfilter = p.Nfilter;

S.plotShowFrac = p.plotShowFrac;
S.plotMergeCollinear = p.plotMergeCollinear;
S.plotPruneDangling = p.plotPruneDangling;
S.plotMaxArea = p.plotMaxArea;
S.plotMaxWidth = p.plotMaxWidth;
S.plotWidthGamma = p.plotWidthGamma;
S.barColor = p.barColor;
S.resultDir = '';   % Set by Results.save below, so a later rescale pass can
                    % write back here without being told the path again

if ~S.equilOK
    fprintf(2,'  WARNING: final equilibrium check failed (relative residual %.3e).\n',S.resid);
end

%% --- Check the drawing --------------------------------------------------
Mx = Results.metrics(S,S.plotShowFrac,S.plotMergeCollinear);
S.nShown = Mx.nShown;   S.nMerged = Mx.nMerged;   S.nDangle = Mx.nDangle;
S.nIsolated = Mx.nIsolated;  S.nLoadIsolated = Mx.nLoadIsolated;

if Mx.nLoadIsolated>0 || Mx.nDangle>0 || Mx.nIsolated>0
    fprintf(2,['  !! the DRAWING (bars >= %.3g of max area) is not a valid truss: ' ...
               '%d loaded node(s) off the load path, %d dangling, %d isolated.\n'], ...
            S.plotShowFrac,Mx.nLoadIsolated,Mx.nDangle,Mx.nIsolated);
    if S.equilOK
        fprintf(2,['     The full design IS in equilibrium, so this is the plot ' ...
                   'slicing an un-discretized\n     design mid-member.  Raise ' ...
                   'minLenCells to discretize it, or lower plotShowFrac to see ' ...
                   'the\n     members being hidden.\n']);
    end
end

%% --- Plot and save ------------------------------------------------------
S.fig = [];
if p.doPlot, S.fig = Results.plot(S); end
if ~isempty(p.resultDir), S.resultDir = Results.save(S,S.fig,p.resultDir); end
end
