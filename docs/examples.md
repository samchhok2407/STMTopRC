# Manuscript study settings

For the latest rerun, see `../results/verification.csv`. The numerical/timing table below records the earlier 13 September run, not a timing measurement made during the latest verification run.
Verified 2026-09-13 using the current runners, MATLAB R2026a Update 2 and base MATLAB. Historical saved outputs are not the source of the revised manuscript tables.

The package has three self-contained runners. Panel runs all three cases; deep-beam and bridge runners enable the first case by default. Pass `true` to the deep-beam or bridge runner for the others. Run all three studies to reproduce the twelve cases. Copy and rename a runner function to create a new case; no case registry is required. Set a new absolute resultDir to preserve historical outputs.

## Panel benchmark — Zhang et al. 2018 Table 4
30×10 m; 30×10 cells; 341 nodes and 19,632 bars; connectivity level 10; total Vmax = 0.15 m³; tolRel = 3e-4.

| Source panel | maxIter | Nfilter | alphaF | Budgets |
|---|---:|---:|---:|---|
| Fig7c |1000|100|1e-3|one 0.15|
| Fig8c |600|1|1e-3|shared 0.15|
| Fig8d |1000|1|1e-6|separate 0.075 each|

Computed objectives 1.13640063555, 1.13642585758 and 1.17935063918 match the printed values 1.136, 1.136 and 1.179. Shared fractions 0.621796078783/0.378203921217 differ from 0.63/0.37 by 0.82 percentage points; do not claim exact allocation reproduction. Separate fractions are 0.5/0.5. Published member counts 48, 25+19 and 42+33 remain contextual.

## Deep-beam demonstrations — Zhao et al. 2023 Fig1(d,f,h,j,l)
Geometry is 60×15 in; P = 1 kip; Et = 29,007.5 ksi; Ec = 4,351.1 ksi. Settings: maxIter = 2000, tolRel = 1e-6, alphaF = 1e-4 and Nfilter = 350. Four 16×4 meshes have 2,196 candidate bars; scenario 2 uses 12×3 and 835 bars. Automatic budgets are 493.3380866 in³ per material (total 986.6761731), or 190.3805558 per material for scenario 2 (total 380.7611116). These five source panels have no directly associated published numerical objective/load-path targets. They demonstrate restrictions, rather than validate published values. Different mesh-dependent budgets prohibit direct objective comparison between scenario 2 and the other cases.

## Bridge reference comparison — Zhang et al. 2017
Source: Example 2, Fig. 11(a), Fig. 13(a–d) and Table 3. Geometry: 20×5 m; 18×7 grid; 152 nodes and 7,083 bars. Et = 7e7 kN/m²; Ec/Et = 1, .09, .04 and .0225. Settings: maxIter = 6000, fixed eta = .5, alphaF = 1e-4, Nfilter = 1 and tolRel = 0. Vmax = .05 m³ is inferred from J/Psi*, so this is a reference comparison. Published objectives are 1.92, 12.25, 21.96 and 29.57; the largest relative difference is 0.5379%. Display thresholds are .01, .005, .005 and .001, respectively.

## Fresh outcomes
Active members have positive area in any material. Displayed members follow plot threshold and collinear merging. These are not the source's Published members. All twelve runs below converged and passed final equilibrium and displayed connectivity checks. Timing is one wall-clock run including Engine construction, solve, metrics, plotting and initial saving; it excludes MATLAB startup and later common-scale plotting.

| Case | J | Z/(PH) | Active members | Displayed members | Iterations | Seconds | Equilibrium residual |
|---|---:|---:|---:|---:|---:|---:|---:|
|Ex1_deepbeam_full_depth|0.001087405004|7.729301948068732|44|31|716|8.6089535|1.200e-10|
|Ex2_deepbeam_tie_23H|0.002915000501|7.8750000000108935|26|15|1544|9.4121458|2.172e-11|
|Ex3_deepbeam_tie_half_H|0.001118734725|7.851190476214265|40|27|452|6.1571808|5.639e-11|
|Ex4_deepbeam_tie_0_90|0.001321029543|8.60000000001441|54|33|1065|10.9054482|1.099e-10|
|Ex5_deepbeam_tie_0_45_90|0.001124908452|7.875005988999845|54|23|1707|16.3893739|1.115e-10|
|Ex7_longspan_bridge\EcEt_0.0225|29.48442515|48.760141101880066|32|26|350|6.105196|1.211e-09|
|Ex7_longspan_bridge\EcEt_0.04|22.07812662|31.903548799502577|55|45|968|12.0761529|2.829e-13|
|Ex7_longspan_bridge\EcEt_0.09|12.24315797|20.70433358869541|79|60|1528|18.2552754|7.148e-10|
|Ex7_longspan_bridge\EcEt_1|1.918642026|18.32381936502688|68|50|3307|38.4387585|4.234e-09|
|Zhang2018_Fig7c|1.136400636|not requested|103|48|455|27.5011554|2.173e-10|
|Zhang2018_Fig8c|1.136425858|not requested|97|48|411|29.9878394|3.627e-10|
|Zhang2018_Fig8d|1.179350639|not requested|175|73|584|64.8662545|3.254e-10|

The separate tests/selftest_ZhaoAppendixB.m verifies coordinates, force recovery, lengths and the production Results.loadPath evaluator. It does not validate the optimizer. See the revision verification files for full-precision values, supplied inputs and S.parameters.
