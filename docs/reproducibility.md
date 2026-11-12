# Reproducing the manuscript results

All results reported in the manuscript are regenerated, without editing any
source file, by `examples/run_all_verification.m`. The tested environment is
base MATLAB R2026a Update 2 on 64-bit Windows 11.

## Run

From the repository root:

```matlab
addpath(fullfile(pwd,'examples'));
outRoot = fullfile(pwd,'results','reproduction');   % absolute; keeps results/ untouched
T = run_all_verification(outRoot);
```

The script runs the regression tests, then the three panel cases, the
five deep-beam cases and the three members with openings, each through its own
runner. It redraws the five deep-beam layouts on one common line-width scale,
as in the manuscript, and writes the case folders, `verification.csv` and
`execution.log` (with the MATLAB version and platform) under `outRoot`.
Without an argument it writes to `results/` and replaces the shipped files.

## Checks

For every case the script checks that

1. the optimization converged (Eq. (8) of the manuscript),
2. the final equilibrium residual is below 1e-3 (Eq. (9)),
3. every volume budget is satisfied,
4. the displayed layout connects the loads to the supports, and
5. the objective agrees with the release-regression baseline to a relative
   1e-6 (`ReleaseBaselineJ`, `BaselineRelDiffJ`).

Every state solve inside every run must also converge; otherwise the run
stops. The script stops with an error, after writing `verification.csv`, if
any case fails. The baselines are the objectives recorded by this release:
they show that a rerun reproduces the release, and are distinct from the
published values of the source papers that the manuscript compares with.
These checks do not establish a global optimum, structural stability or RC
design capacity.

## Compare

Compare the new `verification.csv` with the shipped
[results/verification.csv](../results/verification.csv). Objectives, load paths,
member counts and iteration counts should agree; run times (the `Engine`
call, `S.elapsedSeconds`) depend on the computer and on other running programs. The panel cases report `Z` as NaN
because they do not compute the load path.

The script also draws Fig. 6 of the manuscript (`convergence_history.png` and
`.fig`) from the shared-budget panel of the same run.
