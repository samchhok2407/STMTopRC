# Reproducing the manuscript studies

This procedure uses the three study functions shipped with STMTopRC. Commands
below assume MATLAB's current folder is the repository root. The tested
environment is base MATLAB R2026a Update 2 on Windows; no optional toolbox is
required. Compatibility with earlier releases has not been established.

## Record the environment

Record the repository commit, MATLAB version (`version`), platform (`computer`),
operating system, processor, memory, and any changed settings. Retain the exact
study files. The software saves effective inputs in `S.parameters`, but does
not automatically record all hardware or repository metadata.

Use a fresh absolute destination so old and new case files are not mixed:

```matlab
addpath(fullfile(pwd,'examples'), ...
        fullfile(pwd,'tests'));
outRoot = fullfile(pwd,'results','reproduction');
if ~exist(outRoot,'dir'), mkdir(outRoot); end
diary(fullfile(outRoot,'execution.log'));
disp(version);
disp(computer);
selftest_release;
```

The short asymmetric regression intentionally reaches its six-iteration limit.
That warning is expected. The test checks symmetry handling, not convergence of
that deliberately truncated run.

## Execute the studies

```matlab
panel = run_validation_Zhang2018(outRoot);
beam = run_deepbeam_Ex1_to_Ex5(true,outRoot);
bridge = run_bridge_Ex7a_to_Ex7d(true,outRoot);
diary off;
```

| Study | Cases | Interpretation |
|---|---:|---|
| Panel | 3 | Objective comparison with published printed values; allocation and member counts checked separately |
| Deep beam | 5 | Demonstration of tie restrictions; no corresponding published numerical target for these five layouts |
| Bridge | 4 | Reference comparison with an inferred physical volume budget |

See [study settings](examples.md) for geometry, loads, materials and filters.
The deep-beam and bridge functions run all cases by default; pass `false` as
the first argument to run only the first case. Running an existing destination overwrites its case files.

## Inspect the numerical checks

The returned cells contain one structure per case. This example checks all
twelve returned structures without introducing another runner:

```matlab
cases = [panel, beam, bridge];
for k = 1:numel(cases)
    S = cases{k};
    assert(S.converged, 'Area update did not converge: %s', S.label);
    assert(S.equilOK, 'Final equilibrium failed: %s', S.label);
    groups = S.parameters.volGroups(:);
    used = accumarray(groups,S.matVol(1:numel(groups)), ...
                     [numel(S.Vmax),1]);
    assert(all(used <= S.Vmax + 1e-8*max(S.Vmax,eps)), ...
           'Volume budget exceeded: %s', S.label);
    assert(S.nDangle==0 && S.nIsolated==0 && S.nLoadIsolated==0, ...
           'Displayed graph needs inspection: %s', S.label);
end
J = cellfun(@(S) S.J,panel);
published = [1.136 1.136 1.179];
relativePercent = 100*abs(J-published)./published;
assert(all(relativePercent < 0.045)); % stated comparison, not an optimality test
assert(all(round(J(1:2),3)==published(1:2)));
% The separate-budget value rounds to 1.180, not 1.179.
```

These checks serve different purposes. Area convergence is not proof of a
global optimum. Force equilibrium is not a stability test. Display connectivity
is not a strength or detailing check. The final force-residual normalization
is described in [the numerical notes](engine_notes.md).

The independent Appendix B regression gives `Z/(PH)=97/12` from exact grid
coordinates and `8.086` when the printed rounded forces and lengths are used.
It verifies force recovery and load-path evaluation, not the optimizer.

## Compare and retain outputs

[The recorded verification table](../results/verification.csv) is a fixed
snapshot, not an automatically updated result of the study functions. Compare
your returned `S.J`, `S.Z`, `S.nActive`, `S.nMerged`, `S.nIter` and `S.resid`
with the corresponding row. Panel `Z` is NaN because those cases disable
load-path reporting. Do not interpret that NaN as a failed state solve.

The 2026-09-22 panel results agree with published objectives within 0.045%;
only the first two match at three decimal places. The separate-budget objective
is 1.179519 and rounds to 1.180. Shared material fractions are about
0.6230/0.3770, rather than the source's 0.63/0.37.
Deep-beam Scenario 2 changes mesh and automatic budgets, so its objective cannot
isolate the effect of the tie restriction. The bridge's 0.05 m^3 budget is
inferred; its objective agreement is not an independent validation.

Each case saves effective inputs and the result in `result.mat`, numerical
summaries in `summary.txt`, and PNG/FIG layouts when plotting is enabled.
MAT/FIG files are excluded from Git and must be regenerated or supplied in a
separate data archive. Keep settings, logs and result structures together.

Study return values contain `elapsedSeconds`, measured around each Engine call.
This includes construction, solution, metrics, plotting and initial saving;
it excludes MATLAB startup and subsequent common-scale figure regeneration.
Elapsed time is added after the initial save and is not guaranteed to appear
in every case's MAT file. Timings from different computers are not performance
comparisons between algorithms.

For a publication, identify the exact commit or release and the archive
containing any additional data. Update citation metadata only after the actual
version and archive identifier are assigned.
