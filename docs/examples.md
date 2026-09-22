# Manuscript study settings

Verified 2026-09-22 using base MATLAB R2026a Update 2 on 64-bit Windows.
See [verification.csv](../results/verification.csv) for full-precision outcomes,
iteration counts, measured runtimes and numerical checks for all twelve cases.

All three study functions run their complete study by default. Pass `false`
to the deep-beam or bridge function for the first case only. Supply an absolute
output root to preserve existing outputs.

## Panel comparison - Zhang et al. (2018), Table 4

Geometry: 30 x 10 m; 30 x 10 cells; 341 nodes and 19,632 bars;
connectivity level 10; total volume 0.15 m^3; `tolRel=3e-4`.

| Source panel | maxIter | Nfilter | alphaF | Budgets (m^3) |
|---|---:|---:|---:|---|
| Fig. 7(c) | 1000 | 1 | 1e-4 | One: 0.15 |
| Fig. 8(c) | 1000 | 1 | 1e-4 | Shared: 0.15 |
| Fig. 8(d) | 1000 | 1 | 1e-4 | Separate: 0.075 each |

| Case | Published J | Computed J | Difference (%) | Material fractions | Active / displayed / published members |
|---|---:|---:|---:|---|---|
| One material | 1.136 | 1.136371 | +0.033 | 1.0000 | 103 / 48 / 48 |
| Shared budget | 1.136 | 1.136368 | +0.032 | 0.6230 / 0.3770 | 111 / 48 / (25+19) |
| Separate budgets | 1.179 | 1.179519 | +0.044 | 0.5000 / 0.5000 | 129 / 70 / (42+33) |

The objectives agree within 0.045%; the first two match at three decimal places.
The third rounds to 1.180, not 1.179. The first two objectives differ by about
0.00027%. Shared fractions differ from 0.63/0.37 by about 0.70 percentage points.
Objective agreement does not establish exact allocation or member-count agreement.

## Deep-beam demonstrations — Zhao et al. 2023 Fig1(d,f,h,j,l)
Geometry is 60×15 in; P = 1 kip; Et = 29,007.5 ksi; Ec = 4,351.1 ksi. Settings: maxIter = 2000, tolRel = 1e-6, alphaF = 1e-4 and Nfilter = 350. Four 16×4 meshes have 2,196 candidate bars; scenario 2 uses 12×3 and 835 bars. Automatic budgets are 493.3380866 in³ per material (total 986.6761731), or 190.3805558 per material for scenario 2 (total 380.7611116). These five source panels have no directly associated published numerical objective/load-path targets. They demonstrate restrictions, rather than validate published values. Different mesh-dependent budgets prohibit direct objective comparison between scenario 2 and the other cases.

## Bridge reference comparison — Zhang et al. 2017
Source: Example 2, Fig. 11(a), Fig. 13(a–d) and Table 3. Geometry: 20×5 m; 18×7 grid; 152 nodes and 7,083 bars. Et = 7e7 kN/m²; Ec/Et = 1, .09, .04 and .0225. Settings: maxIter = 6000, fixed eta = .5, alphaF = 1e-4, Nfilter = 1 and tolRel = 0. Vmax = .05 m³ is inferred from J/Psi*, so this is a reference comparison. Published objectives are 1.92, 12.25, 21.96 and 29.57; the largest relative difference is 0.5379%. Display thresholds are .01, .005, .005 and .001, respectively.

## Interpreting the saved outcomes

Active members have positive area in any material. Displayed members follow
the display threshold and collinear merging; published counts are separate
reference quantities. All twelve cases passed convergence, final equilibrium,
volume-budget and displayed-connectivity checks.

Timings measure each Engine call, including construction, solution, metrics,
plotting and initial saving. They exclude MATLAB startup and later common-scale
figure regeneration and depend on the machine and execution conditions.

`tests/selftest_ZhaoAppendixB.m` independently checks coordinates, force recovery,
lengths and `Results.loadPath`; it does not validate the optimizer. Effective
inputs are stored in each regenerated result's `S.parameters`.
