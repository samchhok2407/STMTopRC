# STMTopRC

Release **v1.0.0 - 2026-11-12**. DOI: [10.5281/zenodo.24137933](https://doi.org/10.5281/zenodo.24137933)

MATLAB ground-structure topology optimization for reinforced-concrete
strut-and-tie models. The package combines bilinear axial materials, grouped
volume constraints, ZPR area updates, discrete filtering, and tie-region and
tie-angle restrictions. It is intended for research and teaching; it does not
perform RC strength, anchorage, nodal-zone or detailing checks.

This repository accompanies the manuscript *Ground-structure topology
optimization of reinforced-concrete strut-and-tie models: the STMTopRC MATLAB
package* by Samchhok Tit and Donghyuk Jung ([authors](AUTHORS.md)).

## Requirements

Base MATLAB R2026a Update 2 on 64-bit Windows 11. No toolboxes and no setup
are needed; keep the `src`, `examples` and `tests` folders together.

```sh
git clone --branch v1.0.0 https://github.com/samchhok2407/STMTopRC.git
```

## Quick start

From the repository root in MATLAB:

```matlab
addpath(fullfile(pwd,'examples'));
run_all_verification
```

`run_all_verification` reproduces all results reported in the manuscript
without editing any source file. It runs the regression tests and the eleven
cases, checks each case, and writes `results/verification.csv`.

Each case also has its own runner:

| Study | Runners | Role |
|---|---|---|
| Panel (3) | `run_panel_1mat_1vol`, `run_panel_2mat_1vol`, `run_panel_2mat_2vol` | Comparison with the published panel benchmark |
| Deep beam (5) | `run_deepbeam_tie_full_depth`, `run_deepbeam_tie_23H`, `run_deepbeam_tie_half_H`, `run_deepbeam_tie_0_90`, `run_deepbeam_tie_0_45_90` | Tie-region and tie-angle restrictions |
| Openings (3) | `run_rc_beam_four_holes`, `run_deepbeam_one_hole`, `run_deepbeam_two_holes` | Comparison with published ST-method models |

```matlab
S = run_deepbeam_tie_half_H;        % one case
outRoot = fullfile(pwd,'results','new_run');
run_all_verification(outRoot);      % keep the shipped results untouched
```

To model a new problem, copy a runner under a new name and edit its inputs.

## Inputs and units

Required fields: `width`, `height`, `nx`, `ny`, `P`, `Emod` and `x0`. Missing or
unknown fields raise an error. All other inputs and defaults are listed in the
[parameter guide](docs/parameter_guide.md).

`Emod` has columns `[Et Ec]`. One row defines one bilinear material; two rows
`[Et 0; 0 Ec]` define approximately tension-only (ties, row 1) and
compression-only (struts, row 2) materials. This release supports only these
two models, not an arbitrary number of materials, and tie-region and tie-angle
restrictions need the two-row model. The solver does not convert units, so a
consistent system is needed:

| Quantity | Panel | Deep beam | Openings |
|---|---|---|---|
| Lengths | m | in | mm |
| Forces | kN | kip | kN |
| Moduli | kN/m^2 | ksi | kN/mm^2 |
| Objective J | kN m | kip in | kN mm |

## Outputs

Each case writes `result.mat`, `summary.txt`, `layout.png` (1000 dpi) and
`layout.fig` to its folder under `results/`. The results of all eleven cases
are included.

| Result field | Meaning |
|---|---|
| `S.parameters` | Effective inputs, including defaults |
| `S.X`, `S.Fe` | Areas by material and signed bar forces (+ tension) |
| `S.J`, `S.Z` | Objective and normalized load path Z/(PH) |
| `S.matVol`, `S.Vmax` | Material volumes and budgets |
| `S.converged`, `S.stopReason` | Convergence, and `'converged'` or `'maxIter'` |
| `S.resid`, `S.equilOK`, `S.Fscale` | Final equilibrium residual, check and reference force |
| `S.stateInfo`, `S.kRef`, `S.Gamma` | Final Newton solve, Tikhonov reference stiffness and term |
| `S.nActive`, `S.nMerged` | Active (analysed) and displayed member counts |
| `S.hist` | Per-iteration `J`, `Z`, `dX`, volume fractions `Vfrac` and Newton iterations `nNR` |
| `S.elapsedSeconds` | Time of the `Engine` call |

`results/verification.csv` records, for every case, the objective, load path,
member counts, iterations, run time, residual and checks. `ReleaseBaselineJ`
is the objective this release recorded and `BaselineRelDiffJ` the relative
difference from it; a case passes when all checks hold and `BaselineRelDiffJ`
is at most 1e-6. These are release-regression baselines, distinct from the
published values of the source papers that the manuscript compares with.

`run_all_verification` also draws manuscript Fig. 6 (`convergence_history.png` and
`.fig`) from the shared-budget panel it has just run; `tests/convergence_history.m`
redraws it alone from the saved result.

## Regression tests

```matlab
addpath(fullfile(pwd,'tests'));
selftest_release;
```

This runs the load-path check (Appendix B of Zhao et al. 2023), the
state-solver check against a direct solution of Ku = f, the finite-difference
sensitivity check, the six symmetry-detection cases, the robustness checks
(`selftest_robustness`: a Newton solve that cannot converge stops the run, the
`maxIter` safeguard flags the run, the same problem in kN-m and N-mm gives the
same design, one-material tie restrictions are refused, averaged and
unaveraged symmetric designs agree, out-of-range settings and snapped loads
are reported), a small optimizer regression and input-error checks.

## Documentation

| Location | Contents |
|---|---|
| [Parameter guide](docs/parameter_guide.md) | Inputs, defaults and units |
| [Study settings](docs/examples.md) | Case definitions and results |
| [Reproducibility](docs/reproducibility.md) | Rerunning and checking the cases |
| [Changelog](CHANGELOG.md) | Release notes |

## License and citation

Licensed under [GPL-3.0-or-later](LICENSE.txt). Please cite this release as:

> Tit S, Jung D. STMTopRC: A MATLAB package for ground-structure topology
> optimization of reinforced-concrete strut-and-tie models. Version 1.0.0.
> Zenodo; 2026. https://doi.org/10.5281/zenodo.24137933

The concept DOI [10.5281/zenodo.22877545](https://doi.org/10.5281/zenodo.22877545) always resolves to the latest
archived version. Citation metadata is in
[CITATION.cff](CITATION.cff). Contact: samchhok_ku25@korea.ac.kr;
corresponding author: jungd@korea.ac.kr.
