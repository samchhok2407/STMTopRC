# Troubleshooting

Run commands from the repository root unless a different current folder is
explicitly stated. These notes concern the current three study functions.

| Symptom | What to check | Suggested action |
|---|---|---|
| Study function is undefined | Current folder and MATLAB path | Run `addpath(fullfile(pwd,'examples'))` from the repository root. Use `which run_validation_Zhang2018 -all` to detect another copy. |
| `Engine` or `Results` is undefined in a custom script | Source path | Add `fullfile(pwd,'src')`; supplied studies do this themselves. |
| Only one deep-beam or bridge case runs | Function argument | Pass `true` or omit the argument to select the complete study; `false` selects only the first case. |
| Missing or unknown parameter error | Field names and required inputs | Check `width`, `height`, `nx`, `ny`, `P`, `Emod`, `x0`, `maxIter` and the parameter guide. Correct the input rather than suppressing the error. |
| A support or force acts at an unexpected node | Grid spacing and supplied coordinates | Inspect `S.NODE`, `S.suppNodes`, `S.loadNodes` and `S.Fext`. In-domain coordinates snap to the nearest grid node. |
| Changing the mesh changes the physical budget | Automatic `Vmax` | Specify explicit physical budgets for a controlled mesh comparison. Automatic budgets depend on total candidate length. |
| Iteration limit reached | Area-change history and tolerances | Inspect `S.hist.dX`, `S.converged` and `S.resid`. Additional iterations may help, but do not claim convergence by simply loosening tolerances. |
| Expected warning during `selftest_release` | The short asymmetric test | Its six-iteration limit is intentional; the test must still end with its passed message. |
| Final equilibrium is false | Model, restraints and numerical settings | Check load/support definitions and the residual. Do not treat a converged area update or a clean-looking figure as a successful physical solve. |
| Displayed members appear disconnected | Plot threshold and full solution | Inspect `S.nLoadIsolated`, `S.nDangle` and `S.nIsolated`; lower `plotShowFrac` to inspect hidden members. Recheck stability independently. |
| Panel `S.Z` is NaN | `S.parameters.showZ` | The panel study deliberately disables load-path reporting. |
| No PNG or FIG was saved | `doPlot` and `resultDir` | Enable plotting and provide a result directory. A direct Engine call with empty `resultDir` saves nothing. |
| `Results.load` cannot find a case | Whether that case has run and its destination | Run the study first or pass the case's actual directory. MAT files are generated locally and are not included in a fresh clone. |
| Custom output appears under an unexpected folder | Absolute versus relative destination | Use an absolute `outRoot` for study functions. Engine's relative result names resolve beneath the package results directory. |
| Plot widths look different between runs | Individual versus common scaling | A sweep redraws its figures on a shared scale; gamma=0.5 uses square-root area scaling. Compare both scale and display threshold. |

If the problem remains, include the information listed in
[the contribution guide](../CONTRIBUTING.md) with a minimal example.
The [parameter guide](parameter_guide.md) and
[reproduction procedure](reproducibility.md) give the current settings and checks.
