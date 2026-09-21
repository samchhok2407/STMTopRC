# STMTopRC

MATLAB ground-structure topology optimization for reinforced-concrete strut-and-tie models. Bilinear axial materials, grouped volume constraints, ZPR area updates, discrete filtering, and tie location/angle restrictions support research and teaching. The package does not perform RC strength, anchorage, nodal-zone, or detailing checks.

This repository accompanies the manuscript *Ground-structure topology
optimization of reinforced-concrete strut-and-tie models: the STMTopRC MATLAB
package* by Samchhok Tit and Donghyuk Jung. See [authors and contact](AUTHORS.md).

## Features

- Rectangular ground structures with connectivity and member-length controls.
- One bilinear material or two approximately one-sided materials.
- Shared or separate material-volume budgets with ZPR area updates.
- Tie-depth and tie-angle restrictions, adaptive damping and discrete filtering.
- Signed axial forces, material volumes, equilibrium checks and layout export.
- Three manuscript studies and independent evaluation/regression checks.

## Requirements and installation

Tested with **base MATLAB R2026a Update 2** on Windows. No Optimization Toolbox
is required. Earlier releases have not been verified.

Download the repository ZIP or clone it:

```sh
git clone https://github.com/samchhok2407/STMTopRC.git
```

Open MATLAB in the downloaded repository root. No compilation or setup script
is needed. Keep the `src`, `examples` and `tests`
directories together. The studies add the source path automatically.

Two source files implement rectangular ground-structure optimization and result evaluation. One bilinear material or two approximately one-sided materials share candidate bars. The objective is negative total potential energy, `J = -Pi`; at equilibrium for this bilinear model, `J = 0.5*f'*u`.

## Quick start

From the repository root in MATLAB:

```matlab
addpath(fullfile(pwd,'examples'));
panel = run_validation_Zhang2018;        % three panel cases
beam = run_deepbeam_Ex1_to_Ex5(true);     % five deep-beam cases
bridge = run_bridge_Ex7a_to_Ex7d(true);   % four bridge cases
```

These are the three study entry points for the manuscript. Omit `true` from
the deep-beam or bridge call to run only its first case. Runners do not clear
the caller's workspace and return cell arrays of result structures; for
example, `panel{1}.J` gives the first panel's objective.

To preserve existing results, select an absolute output root:

```matlab
outRoot = fullfile(pwd,'results','new_run');
panel = run_validation_Zhang2018(outRoot);
beam = run_deepbeam_Ex1_to_Ex5(true,outRoot);
bridge = run_bridge_Ex7a_to_Ex7d(true,outRoot);
```

Each study writes its own case subdirectories. Outputs already present at the
selected destination are overwritten.

Each study defines its inputs locally. Edit it or copy it under a new function/file name for another model.

| Study function | Cases | Role |
|---|---:|---|
| `run_validation_Zhang2018` | 3 | Published panel objective comparison |
| `run_deepbeam_Ex1_to_Ex5(true)` | 5 | Tie-placement demonstrations |
| `run_bridge_Ex7a_to_Ex7d(true)` | 4 | Modulus-ratio reference comparison |

See [study settings](docs/examples.md) for the dimensions, mesh,
loading and case-specific numerical settings.

## Materials and units

`Emod` has columns `[Et Ec]`: tensile and compressive moduli. A single row
defines one bilinear material. Two rows `[Et 0; 0 Ec]` define approximately
tension-only and compression-only materials. Nominal zeros are replaced by
soft branches; they are not exact unilateral constraints.

The solver does not convert units. Use a consistent force/length system:

| Quantity | Panel and bridge | Deep beam |
|---|---|---|
| Coordinates and lengths | m | in |
| Forces | kN | kip |
| Moduli | kN/m^2 | kip/in^2 (ksi) |
| Areas | m^2 | in^2 |
| Volumes | m^3 | in^3 |
| Objective J and dimensional load path | kN m | kip in |

`S.Z` is dimensionless because it is divided by the reference `P*height`.
`P` need not equal the sum of all applied loads.

## Repository layout

```text
README.md                  project guide
AUTHORS.md                 authors and contact
CONTRIBUTING.md            issue and contribution guidance
CITATION.cff               software citation and method references
LICENSE.txt                full GPL v3 license text
src/                       Engine.m and Results.m
examples/                  three study functions
tests/                     two regression functions
docs/                      parameters, methods and reproduction notes
results/                   computed layouts and numerical summaries
```

## Regression checks

From the repository root in MATLAB:

```matlab
addpath(fullfile(pwd,'tests'));
selftest_release;
```

This includes the Appendix B load-path check, a small optimizer regression,
and checks for input errors, display settings and asymmetric restraints. It
does not execute the twelve study cases. The short asymmetric test deliberately
reaches its iteration limit; that warning is expected.

The [reproduction procedure](docs/reproducibility.md) explains how to
record the environment, rerun all three studies and compare their results.

## Outputs

By default, results are saved under `results/`, one subdirectory
per case. With the shipped plotting settings, each case writes `result.mat`,
`summary.txt`, `layout.png`, and `layout.fig`. When `doPlot=false`, only the MAT
file and text summary are written. Binary MAT/FIG files are local generated
artifacts. Effective inputs are in `S.parameters`. Deep-beam and bridge sweeps
regenerate figures using a common area scale; with `gamma=0.5`, added line
width follows the square root of area.

`results/verification.csv` is the retained snapshot of the verification run, with objectives, load paths, member counts, timings, residuals and checks. The three study runners regenerate individual case outputs; they do not update this verification snapshot. Timing includes construction, solving, metrics, plotting and initial saving; it excludes MATLAB startup and later common-scale regeneration.

Optimization convergence, physical equilibrium, volume feasibility, and displayed connectivity are distinct checks. Connectivity does not establish stability or capacity. `S.Z` is normalized by `P*height`; `Results.loadPath` returns the dimensional force-length sum. The bridge's reference P is 40 kN per loaded node, not its 360 kN total.

Panel objectives are checked against printed published targets; shared-budget fractions do not exactly match. Deep beams demonstrate restrictions. The bridge uses an inferred budget and is a reference comparison.

| Result field | Meaning |
|---|---|
| `S.parameters` | Effective inputs, including filled defaults |
| `S.X`, `S.Fe` | Areas by material and summed signed bar forces |
| `S.J`, `S.Z` | Negative total potential energy and normalized load path |
| `S.matVol`, `S.Vmax` | Material volumes and budgets per volume group |
| `S.converged`, `S.resid`, `S.equilOK` | Area convergence and final force equilibrium |
| `S.nActive`, `S.nMerged` | Active and displayed/merged member counts |
| `S.hist` | Objective, normalized load-path and area-change histories |

Member force `Fe` follows the manuscript notation, with positive values in
tension and negative values in compression. `Results.load` converts older
saved result files to the current `S.Fe` field automatically.

Blue represents ties and red struts; the single-material panel uses brown.
For two materials, the dominant material area determines the displayed color.
For a single material without a color override, force sign determines color.

## Inputs and limits

Required: `width`, `height`, `nx`, `ny`, `P`, `Emod`, `x0`, `maxIter`. Missing or unknown fields produce errors. Core geometry, materials, volume groups, and budget dimensions are checked; validation is not exhaustive for every option. Coordinates inside the domain still snap to the nearest node.

Zero moduli use `inactiveFactor=1e-6` soft branches. Tie restrictions apply to material 1; material 2 can still carry small tensile forces. Automatic budgets depend on mesh and candidate lengths. Use explicit budgets for controlled mesh comparisons.

## Documentation

| Location | Contents |
|---|---|
| [Parameters](docs/parameter_guide.md) | Inputs, defaults and units |
| [Algorithms](docs/engine_notes.md) | Numerical implementation |
| [Runner notes](docs/runner_notes.md) | Study assumptions |
| [Study settings](docs/examples.md) | Model definitions and historical results |
| [Reproducibility](docs/reproducibility.md) | Environment, execution, checks and retained data |
| [Troubleshooting](docs/troubleshooting.md) | Common symptoms and corrective steps |
| [Results](results/) | Computed layouts, summaries and verification table |
| [Changelog](CHANGELOG.md) | Changes and release preparation |

For questions or proposed changes, see [CONTRIBUTING.md](CONTRIBUTING.md).

## License and citation

The software release includes code, tests, current documentation, license/citation metadata, and computed example outputs. Manuscript drafts, reference PDFs, temporary logs, and generated MATLAB binaries are excluded by `.gitignore`. MAT/FIG outputs can be regenerated or distributed separately in a data archive.

Use [CITATION.cff](CITATION.cff) to cite the software. It records the source formulations and DOIs for Zhang et al. (2017, 2018), Zhao et al. (2023), Ramos and Paulino (2016), and Groenwold and Etman (2008).

Licensed under [GPL-3.0-or-later](LICENSE.txt). Each source file carries an
`SPDX-License-Identifier: GPL-3.0-or-later` header.
Contact: samchhok_ku25@korea.ac.kr; corresponding author: jungd@korea.ac.kr.
