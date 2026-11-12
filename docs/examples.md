# Study settings

The eleven manuscript cases, each defined completely in its runner in
`examples/`. Full-precision results, iteration counts, run times and checks
are in [verification.csv](../results/verification.csv).

## Panel benchmark: Zhang et al. (2018), Example 1

30 x 10 m panel, 30 x 10 cells, connectivity level 10 (341 nodes, 19,632 bars),
total volume 0.15 m^3, moduli [7E, 2E] or [7E, 0] and [0, 2E] with E = 1e7 kN/m^2,
`alphaF = 1e-4`, `Nfilter = 1`, `tolRel = 3e-4`.

| Runner | Budget | Published J | Computed J | Fractions | Displayed members |
|---|---|---:|---:|---|---:|
| `run_panel_1mat_1vol` | one material, 0.15 m^3 | 1.136 | 1.136422 | 1 | 48 |
| `run_panel_2mat_1vol` | shared, 0.15 m^3 | 1.136 | 1.136441 | 0.62 / 0.38 | 48 |
| `run_panel_2mat_2vol` | separate, 0.075 m^3 each | 1.179 | 1.179498 | 0.50 / 0.50 | 70 |

Computed from the full-precision objectives, the largest relative difference
from the published values is 0.042%.

## Deep beam: tie restrictions after Zhao et al. (2023), Fig. 1(d, f, h, j, l)

60 x 15 in, P = 1 kip, Et = 29,007.5 ksi, Ec = 4,351.1 ksi, `tolRel = 1e-6`.
Scenarios 1 and 3 to 5 use a 16 x 4 mesh (automatic budget 493.34 in^3 per
material); Scenario 2 uses 12 x 3 (190.38 in^3 per material).

| Runner | Tie restriction | Computed J (kip in) | Computed Z/(PH) |
|---|---|---:|---:|
| `run_deepbeam_tie_full_depth` | none | 1.087e-3 | 7.73 |
| `run_deepbeam_tie_23H` | y <= 2H/3 | 2.915e-3 | 7.88 |
| `run_deepbeam_tie_half_H` | y <= H/2 | 1.119e-3 | 7.85 |
| `run_deepbeam_tie_0_90` | 0, 90 deg | 1.321e-3 | 8.60 |
| `run_deepbeam_tie_0_45_90` | 0, 45, 90 deg | 1.125e-3 | 7.88 |

The five cases demonstrate how regional and directional tie restrictions alter
the optimized layout and the computed load path. The source defines the five
restriction scenarios but does not report directly corresponding numerical J
or Z values for them, so these cases are software demonstrations, not
numerical validation benchmarks. The numerical load-path check against the
source is the determinate truss of its Appendix B (`tests/selftest_ZhaoAppendixB.m`).

## Members with openings: Starcev-Curcin et al. (2016, 2020)

Published ST-method models in kN and mm, Es = 200 GPa, pin-roller supports and
full ground-structure connectivity.

| Runner | Member | Grid | Loads | Ec | Ties |
|---|---|---|---|---|---|
| `run_rc_beam_four_holes` | 7200 x 1200 mm, four 400 x 400 mm holes | 19 x 4 nodes | 3 x 100 kN | 30 GPa | 0, 45, 90 deg |
| `run_deepbeam_one_hole` | 8000 x 4000 mm, one 4000 x 1000 mm hole | 9 x 5 nodes | 2 x 1000 kN | 31 GPa | 0, 45, 90 deg |
| `run_deepbeam_two_holes` | specimen W1, 1800 x 1200 mm, two 400 x 400 mm holes | 200 mm cells | 2 x 100 kN | 31 GPa | any |

The computed member forces agree with the published values within 0.02 kN for
the two examples of the 2016 paper and within 0.03 kN for W1.

### W1 and `inactiveFactor`

`run_deepbeam_two_holes` uses `inactiveFactor = 1e-3` instead of the default
`1e-6`. The value changes the design, so W1 is a calibrated reference
comparison, not an independent validation. Rerunning the runner with only
`p.inactiveFactor` changed gives:

| inactiveFactor | J (kN mm) | Z/(PH) | Displayed members | Same layout as 1e-3 | Max force difference (kN) | Iterations |
|---:|---:|---:|---:|---|---:|---:|
| 1e-6 (default) | 460.64 | 3.730 | 17 | no | 15.1 | 303 |
| 1e-5 | 460.64 | 3.730 | 17 | no | 15.1 | 304 |
| 1e-4 | 460.64 | 3.730 | 17 | no | 15.1 | 305 |
| 1e-3 | 458.01 | 3.714 | 17 | yes | 0 | 570 |

All four runs converge and satisfy equilibrium. From 1e-6 to 1e-4 the
optimizer settles on one layout; only 1e-3 reaches the published W1 layout,
with a 0.57% lower objective.
