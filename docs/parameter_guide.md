# Parameter guide

Every parameter `Engine` accepts. The defaults are those of the `DEFAULTS`
block at the top of `src/Engine.m`. Parameters are struct fields; anything
omitted takes its default:

```matlab
p.width=60; p.height=15; p.nx=16; p.ny=4; p.P=1;
p.Emod=[29007.5 0; 0 4351.1]; p.x0=[0.01 0.01];
p.tieFrac=0.5;
S = Engine(p);
```

Missing required fields, unknown names and out-of-range values raise an error.

## Required parameters

These have no defaults; a missing field raises `Engine:missingParameter`.

| name | meaning |
|---|---|
| `width` | domain width (span) |
| `height` | domain height (depth) |
| `nx` | ground-structure cells across x |
| `ny` | ground-structure cells across y |
| `P` | reference load magnitude (normalizes `Z`) |
| `Emod` | `[Et Ec]` per row: one row, or two rows with row 1 = tie, row 2 = strut |
| `x0` | initial bar area per material |

`P` is the reference load used to normalize the load path, `Z/(P·H)`; it need
not equal the total load. It is also the lower bound of the reference force
for relative residuals (see Reporting).

### Supported materials

This release supports exactly two material models:

- one bilinear material, `Emod = [Et Ec]`, whose members are classified as
  ties or struts by the sign of their force; or
- two approximately one-sided materials, `Emod = [Et 0; 0 Ec]`, with row 1
  the ties and row 2 the struts.

Although the ZPR formulation is general, arbitrary numbers of material layers
are not implemented: material row 1 is the tie material, the plots assume
tie/strut materials, and `Emod` with more than two rows is rejected.

## Supports and loads

Leave both empty for the built-in simply-supported deep-beam case: pin
bottom-left, roller bottom-right, load `P` down at top mid-span.

| name | default | meaning |
|---|---|---|
| `supports` | `[]` | `[x y fixX fixY ; ...]` |
| `loads` | `[]` | `[x y Fx Fy ; ...]` |

Positions snap to the nearest node. When a support or load is moved by more
than 1e-6 of the larger domain dimension, `Engine:snapped` warns with the
largest move and the node used. A snapped load can break mirror symmetry and
switch symmetry averaging off.

## Material and volume

| name | default | meaning |
|---|---|---|
| `inactiveFactor` | `1e-6` | floor on the inactive branch of each material |
| `volGroups` | `[]` | `volGroups(mat)` = constraint index; `[]` = one per material |
| `Vmax` | `[]` | per-constraint budget; `[]` = auto (`x0·sum(L)`) |
| `xmaxFactor` | `1e4` | `xmax = xmaxFactor · x0` |
| `moveFactor` | `1e4` | move limit = `moveFactor · x0` |

With `Vmax = []` the budget of group j is the sum of `x0` over its materials
times the total length of all candidate bars, so it changes with the mesh,
`gsLevel` and `minLenCells`. Prescribe `Vmax` for mesh comparisons. The
automatic budget is based on the full geometric candidate set and is
independent of material eligibility: changing only `tieFrac` or `tieAngles`
does not change any budget.

`inactiveFactor` is not only a numerical floor: it sets the stiffness of the
inactive branch and can change the optimized layout (see the W1 study in
[examples.md](examples.md)).

## Ground structure and domain

| name | default | meaning |
|---|---|---|
| `domain` | `[]` | `[]` = full rectangle; or a struct with `outer` (outline corners), `holes` (cell array of openings) and optional `xLines`, `yLines` (grid lines) |
| `gsLevel` | `Inf` | keep bars within N cells (Chebyshev); `Inf` = all pairs |
| `minLenCells` | `0` | minimum member length, in grid cells |
| `groundOnly` | `false` | build the ground structure, supports and loads, then return without optimizing |
| `evalAreas` | `[]` | numBars x m areas: evaluate this design (state, `S.J`, `S.Fe`, `S.u`, sensitivity `S.dJdx` = -L·Psi) without optimizing |
| `useSymmetry` | `true` | `false` never averages left-right twins, even for a symmetric problem |

`minLenCells` removes short bars; because it also changes the total bar
length, prescribe `Vmax` when comparing runs that differ in it.

## Optimizer

| name | default | meaning |
|---|---|---|
| `alpha` | `1.0` | ZPR damping exponent; `eta0 = 1/(1+alpha)` |
| `tolOpt` | `1e-9` | stop when `max\|dX\|` falls below this (absolute) |
| `tolRel` | `0` | also stop when `max\|dX\| < tolRel·max(area)`; `0` = off |
| `maxIter` | `10000` | safeguard cap on optimization iterations |
| `maxNR` | `40` | maximum Newton–Raphson iterations per state solve |
| `tolNR` | `1e-8` | Newton–Raphson tolerance on the relative residual `‖R‖/Fscale` |
| `GammaFactor` | `1e-10` | Tikhonov term = `GammaFactor · kRef` (see below) |
| `etaMin` | `0.20` | lower bound on the adaptive damping |
| `etaMax` | `1.00` | upper bound on the adaptive damping |
| `etaInc` | `1.20` | damping growth factor for steady bars |
| `etaDec` | `0.70` | damping decay factor for oscillating bars |

`tolOpt` is an absolute area change and `tolRel` a change relative to the
largest area; the run stops when the larger threshold is met (manuscript
Eq. (8)). `maxIter` is only a safeguard against non-terminating runs; a run
that reaches it prints a warning and returns `S.converged = false` and
`S.stopReason = 'maxIter'`.

Every state solve must converge to `‖R‖ < tolNR · Fscale` within `maxNR`
iterations. The Newton step uses the branch-dependent tangent stiffness and a
backtracking line search on the total potential energy (Armijo sufficient
decrease), which is smooth across the tension/compression kink; near the
solution a drop in the residual norm is accepted instead. A solve that does
not converge stops the run with `Engine:stateNotConverged`, and a step that
reduces neither the energy nor the residual stops it with
`Engine:lineSearchFailed`; an unconverged state is never passed to the
sensitivity and area update. `S.hist.nNR` records the Newton iterations of
every state solve and `S.stateInfo` the final one.

The regularization magnitude is scaled by a reference stiffness `kRef`: the
largest diagonal entry of a stiffness assembled from the initial member areas
with the larger tensile/compressive modulus of each material (not the tangent
of an equilibrium state). Because `kRef` is a stiffness, the regularization is
the same relative size in any consistent unit system. `S.kRef` and `S.Gamma`
record the values used. The `eta*` parameters rarely need changing; adjust
them only if a run oscillates without converging.

## Discrete filter

| name | default | meaning |
|---|---|---|
| `alphaF` | `1e-4` | prune bars below this fraction of the max area |
| `Nfilter` | `350` | filter from this iteration on (k >= Nfilter) |

`alphaF` changes the design, so member counts are comparable only between
cases with the same value. Filtering is applied to each material separately.
Discrete filtering is irreversible in the current implementation: the ZPR
update is multiplicative, so a bar set to zero area stays at zero. `Nfilter`
and `alphaF` therefore decide which members can still take part in the design.

## Tie placement

| name | default | meaning |
|---|---|---|
| `tieFrac` | `1.0` | ties confined to `y <= tieFrac · height` |
| `tieAngles` | `[]` | allowed tie angles in degrees; `[]` = any |

An angle `a` (0 to 180 degrees) also allows `180-a`. The restrictions decide
which bars may carry the tie material (row 1); struts are never restricted.
Tie-region and tie-angle restrictions are available only for the two-material
formulation `[Et 0; 0 Ec]`. With a single `[Et Ec]` row the same material also
carries every strut, so a restriction would remove struts too; it is rejected
with `Engine:tieRestrictionRequiresTwoMaterials`.

## Output

| name | default | meaning |
|---|---|---|
| `doPlot` | `true` | draw the optimized layout |
| `resultDir` | `''` | save dir; bare name = `results/<name>`; `''` = no save |
| `label` | `'STM run'` | title used in figures and printouts |
| `plotShowFrac` | `0.02` | hide members below this fraction of max area |
| `plotMergeCollinear` | `true` | collapse pass-through nodes when plotting |
| `plotMaxArea` | `[]` | bar area drawn at full line width; `[]` = this design's own largest |
| `plotMaxWidth` | `5` | line width added at `plotMaxArea` |
| `plotWidthGamma` | `1` | exponent on the area fraction; `1` = width proportional to area; `0.5` = square root |
| `barColor` | `[]` | RGB triplet drawn for every bar; `[]` = blue tie / red strut |
| `plotGround` | `false` | `true` draws the candidate ground structure in light grey behind the layout |
| `plotBoundary` | `true` | `true` draws the domain outline and its openings (the rectangle when no `domain` is given) |
| `plotLoads` | `false` | `true` draws the external forces: applied loads (black arrows with values), pin/roller supports and the support reactions beside each support |
| `plotFontSize` | `11` | font size (pt) of all figure text: member labels, loads and reactions |
| `plotLabel` | `'none'` | Member labels beside each member: `'force'` (signed, + tension) or `'area'` |
| `showZ` | `true` | compute and report the load-path number `Z/(P·H)` |

`plotShowFrac`, `plotMaxArea`, `plotMaxWidth` and `plotWidthGamma` affect only
the figure, never the design, `J` or `Z`. `Results.rescale(cases,'gamma',0.5)`
redraws a set of runs on one common line-width scale.

## Documentation-only

Carried into `summary.txt`, never used in the math.

| name | default | meaning |
|---|---|---|
| `units` | `''` | unit system, e.g. `'kN, m'` or `'kip, in'` |
| `source` | `''` | paper and figure this case reproduces |

The engine does not convert units; use a consistent force and length system.

## Reporting

`Results.loadPath(Fe,L)` returns the dimensional load path; `S.Z` stores
`Z/(P·H)`. Positive axial force is tension. `S.parameters` records all
effective inputs.

Every relative residual uses the reference force
`Fscale = max(norm(Fext(free)), abs(P))`, stored in `S.Fscale`, so it is the
same in any force unit. The final equilibrium check is
`norm(Fint(free)-Fext(free))/Fscale < 1e-3` (manuscript Eq. (9)), evaluated
without the regularization term and separate from the Newton tolerance and the
optimization stopping test.

`S.nActive` counts the bars with nonzero area in the analysed design;
`S.nShown` the bars drawn (area at least `plotShowFrac` of the largest); and
`S.nMerged` the displayed members after collinear segments are merged. Only
the display uses the threshold and the merging; `J`, `Z` and the forces come
from the full design. `S.elapsedSeconds` is the time of the whole `Engine`
call (model, optimization and plotting, not file export) and is saved in
every `result.mat`.
