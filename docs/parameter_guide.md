# Parameter Guide

Every parameter `Engine` accepts. The authoritative version is the `DEFAULTS`
block at the top of `src/Engine.m` — if this page and that block disagree,
believe the block.

Parameters are set as struct fields; anything omitted takes its default:

```matlab
p.width=60; p.height=15; p.nx=16; p.ny=4; p.P=1;
p.Emod=[29007.5 0; 0 4351.1]; p.x0=[0.01 0.01];
p.tieFrac=0.5; p.alphaF=1e-3;             % direct, auditable case setup
p.maxIter = 2000;                                       % or as a struct field
S = Engine(p);
```

Missing required fields and unknown parameter names now produce explicit errors.
Core geometry, material dimensions, volume groups, budgets, and boundary-coordinate
ranges are validated before the model is allocated. Validation is not exhaustive
for every solver or plotting option. In-domain coordinates still snap to nodes.

## Model parameters — required, no defaults

These describe the structure being optimized, so they differ from paper to
paper. They deliberately have no defaults: a case that forgot one would
otherwise inherit another paper's beam, run without complaint, and produce a
plausible but wrong figure. Missing fields are rejected with `Engine:missingParameter`.

| name | meaning |
|---|---|
| `width` | domain width (span) |
| `height` | domain height (depth) |
| `nx` | ground-structure cells across x |
| `ny` | ground-structure cells across y |
| `P` | reference load magnitude (normalizes `Z`) |
| `Emod` | `[Et Ec]` per row; row 1 = tie, row 2 = strut |
| `x0` | initial bar area per material |
| `maxIter` | maximum optimization iterations |

`P` is the **reference** load, not the total. On a case with several loaded
nodes it is the load on one of them — that is the convention `Z/(P·H)` is
reported against.

## Supports and loads

Leave both empty for the built-in simply-supported deep-beam case: pin
bottom-left, roller bottom-right, load `P` down at top mid-span.

| name | default | meaning |
|---|---|---|
| `supports` | `[]` | `[x y fixX fixY ; ...]` |
| `loads` | `[]` | `[x y Fx Fy ; ...]` |
| `loadAt` | `'top'` | default single load: `'top'` or `'bottom'` |

Positions are snapped to the nearest node, so they need not land exactly on the
grid — but a snapped load can break mirror symmetry and silently switch the
symmetry averaging off, so place them on nodes when you can.

## Material and volume

| name | default | meaning |
|---|---|---|
| `inactiveFactor` | `1e-6` | floor on the inactive branch of each material |
| `volGroups` | `[]` | `volGroups(mat)` = constraint index; `[]` = one per material |
| `Vmax` | `[]` | per-constraint budget; `[]` = auto (`x0·sum(L)`) |
| `xmaxFactor` | `1e4` | `xmax = xmaxFactor · x0` |
| `moveFactor` | `1e4` | move limit = `moveFactor · x0` |

**`Vmax` is the parameter most likely to mislead you.** On auto it scales with
the total bar length of the ground structure, so changing `gsLevel`, the mesh
**or `minLenCells`** silently changes how much material the structure may use.
Fix it by hand for any comparison across those.

## Ground structure and domain

| name | default | meaning |
|---|---|---|
| `gsLevel` | `Inf` | keep bars within N cells (Chebyshev); `Inf` = all pairs |
| `minLenCells` | `0` | minimum member length, in grid cells (**length control**) |
| `groundOnly` | `false` | build the ground structure, supports and loads, then return **without optimizing** |

`minLenCells` is the usual fix for a design that never discretizes — it culls
short hairline bars without deleting long load-carrying diagonals. No shipped
study varies it; it is an engine control available to yours.

> **It does not simply shrink the candidate set.** The collinear-redundancy rule
> is itself length-aware — a member passing through a third node is discarded
> only when *both* resulting pieces are at least `minLenCells` long — so a larger
> minimum disqualifies fewer members as redundant and can leave **more**
> candidates than before. What it guarantees is a minimum member *length* within
> the set, not a smaller set. It also changes `sum(L)`, so pin `Vmax` by hand
> before comparing two runs that differ in it.

`groundOnly` returns the generated model without optimization.

## Optimizer

| name | default | meaning |
|---|---|---|
| `alpha` | `1.0` | ZPR damping exponent; `eta0 = 1/(1+alpha)` |
| `maxIter` | required, no default | maximum optimization iterations |
| `tolOpt` | `1e-9` | stop when `max\|dX\|` falls below this (**absolute**) |
| `tolRel` | `0` | also stop when `max\|dX\| < tolRel·max(area)`; `0` = off |
| `maxNR` | `40` | maximum Newton–Raphson iterations per state solve |
| `tolNR` | `1e-8` | Newton–Raphson residual tolerance |
| `GammaFactor` | `1e-10` | Tikhonov term = `GammaFactor · max(Emod)` |
| `etaMin` | `0.20` | lower bound on the adaptive damping |
| `etaMax` | `1.00` | upper bound on the adaptive damping |
| `etaInc` | `1.20` | damping growth factor for steady bars |
| `etaDec` | `0.70` | damping decay factor for oscillating bars |

**`tolOpt` and `tolRel` are not interchangeable.** `tolOpt` is an absolute
change in area, so what counts as converged depends on how big the areas happen
to be — on a model whose bars are thousands of square millimetres it may never
fire at all, and `maxIter` ends the run instead. `tolRel` is scale-free and is
the right test when comparing models whose areas differ by orders of magnitude.
Setting `tolOpt = 0` leaves `tolRel` in sole charge.

The five `eta*` parameters rarely need touching. Reach for them only if a run
oscillates without converging — or to pin damping off (`etaMin = etaMax = 0.5`,
`etaInc = etaDec = 1`) when reproducing a source that uses a fixed OC exponent,
as the bridge case does.

## Discrete filter

| name | default | meaning |
|---|---|---|
| `alphaF` | `1e-4` | prune bars below this fraction of the max area |
| `Nfilter` | `350` | start filtering after this iteration |

`alphaF` **changes the design**, so member counts are not comparable across
cases that use different values. Filtering is applied separately to each material column. Its surviving areas
satisfy that column's threshold immediately after filtering. The global `aTop`
across all materials need not exceed `alphaF`. A rerun with a different filter
schedule need not be identical, even when a final-layout filter is a no-op.
Always check equilibrium after the final solve.

## Tie placement

| name | default | meaning |
|---|---|---|
| `tieFrac` | `1.0` | ties confined to `y <= tieFrac · height` |
| `tieAngles` | `[]` | allowed tie angles in degrees; `[]` = any |

An angle `a` also allows `180-a`. Struts are never restricted. These act on
which bars are *eligible* to carry the tie material, not on the sign of the
converged force — which is why a layout can still show tension outside its
permitted tie region, carried there by a strut.

## Live animation — removed

`animate`, `showGround`, `animateEvery` and `groundPause` no longer exist. The
live-view window was display only and never touched a reported number; it was
removed on 9 September 2026. A run prints its iteration table as it goes and
draws the final layout when `doPlot` is true.

## Output

| name | default | meaning |
|---|---|---|
| `doPlot` | `true` | draw the optimized layout |
| `resultDir` | `''` | save dir; bare name = `results/<name>`; `''` = no save |
| `label` | `'STM run'` | title used in figures and printouts |
| `plotShowFrac` | `0.02` | hide members below this fraction of max area |
| `plotMergeCollinear` | `true` | collapse pass-through nodes when plotting |
| `plotPruneDangling` | `false` | iteratively hide one-ended branches in the plotted member list |
| `plotMaxArea` | `[]` | bar area drawn at full line width; `[]` = this design's own largest |
| `plotMaxWidth` | `5` | line width added at `plotMaxArea` |
| `plotWidthGamma` | `1` | exponent on the area fraction; `1` = width proportional to area; `0.5` = square root |
| `barColor` | `[]` | RGB triplet drawn for every bar; `[]` = blue tie / red strut |
| `showZ` | `true` | compute and report the load-path number `Z/(P·H)` |

Layouts are drawn without a `J` / `Z` / member-count caption.

`plotShowFrac` **changes only the picture**, never the design — unlike
`alphaF`. An absolute path in `resultDir` is used as given.

`plotMaxArea` is what makes line thickness comparable **between** figures. Line
width carries bar area, so the normalizing area decides what a thickness means:
left at `[]` every figure divides by its own largest bar, which draws the
thickest member of every design at the same width whatever its area actually is.
Setting it to one area shared by a set of runs makes a given thickness mean the
same area in all of them. Two settings then govern how that scale is spent:

- **`plotMaxWidth`** — how much width the range has. A shared scale puts the
  whole set's heaviest bar at the top, so a panel whose own bars are a fifth of
  that draws as hairlines at the width a single figure would use.
- **`plotWidthGamma`** — how the width is distributed across the range. `1`
  makes width proportional to area; below `1` it lifts the light end, so a panel
  far below the set's maximum still reads instead of looking empty. Any value is
  monotone, so a thicker line still means a larger area within a panel and
  between panels; proportionality is what is given up, which is why widths on a
  shared scale are read as an ordering rather than measured.

You rarely set any of them by hand. A study's runner ends with

```matlab
Results.rescale({resultA, resultB, ...}, 'gamma', 0.5)
```

which takes the largest displayed bar over the set, redraws each layout against
it and overwrites that run's saved figure. Like `plotShowFrac`, all three are
plot-time only: no number the run reports moves.

## Documentation-only

Carried into `summary.txt`, never used in the math.

| name | default | meaning |
|---|---|---|
| `units` | `''` | unit system, e.g. `'kN, m'` or `'kip, in'` |
| `source` | `''` | paper and figure this case reproduces |

The engine is unit-agnostic. Declaring `units` is how a reader knows whether
`Vmax = 0.15` means cubic metres or cubic inches.

## Reporting checks and reproducibility

`Results.loadPath(Fe,L)` returns the physical load path, without normalization.
`S.Z` is normalized by `P*height`. Positive axial force means tension.
`S.parameters` records all effective inputs including defaults for new runs.

The final equilibrium flag uses `norm(Fint(free)-Fext(free))/max(norm(Fext(free)),1) < 1e-3`.
This is separate from the Newton tolerance and the optimization stopping test.
Display reachability and dangling-node checks are necessary topology checks;
they do not establish stiffness rank, stability or code-compliant RC capacity.
The collinear merge test uses normalized cross-product tolerance `1e-6`.
The degree-one load alignment test uses `1e-9`. These are reporting constants,
not solver parameters. Display thresholds and width scaling do not alter J or Z.
The defaults `xmin=0`, `xmax=xmaxFactor*x0`, and move=`moveFactor*x0` apply per material.
