# Contributing to STMTopRC

Contributions can improve the numerical implementation, examples, tests or
documentation. Describe the concrete problem and the resulting behavior in an
issue or pull request. Keep a change focused so its numerical effect can be
reviewed separately from formatting or file reorganization.

## Reporting a problem

Include the MATLAB release, operating system, repository commit, study function
or minimal parameter structure, exact error message, and expected behavior.
For a numerical discrepancy, include the effective inputs from `S.parameters`,
the objective, convergence flag, equilibrium residual, and volume budgets.
Attach a small reproducible example rather than unrelated local files.

## Working on the code

- `src/Engine.m` owns model construction, state analysis and area updates.
- `src/Results.m` owns evaluation, plotting and persistence.
- The three functions in `examples/` own the manuscript case settings.
- `tests/` contains evaluation and implementation regressions.

Preserve existing input and result-field meanings unless an intentional API
change is documented. State whether a numerical change affects the state solve,
optimization, display, or reporting. Display changes should not alter the
objective or physical force-length sum.

## Checking a change

From the repository root:

```matlab
addpath(fullfile(pwd,'tests'));
selftest_release;
```

For numerical changes, also rerun the affected study functions in a separate
absolute output directory. Follow [the reproduction procedure](docs/reproducibility.md)
to compare objectives, material volumes, residuals and member counts. Explain
intentional differences; do not replace a reference snapshot simply to make a
comparison pass. Documentation-only changes require working links and correct
commands, not a complete optimization rerun.

Record relevant checks and limitations in the pull request. Keep generated
MAT/FIG files and machine-specific paths out of source changes. Update parameter
documentation when accepted inputs or defaults change.

STMTopRC is distributed under [GPL-3.0-or-later](LICENSE.txt). Identify any
external code introduced by a contribution and preserve its applicable notices.
Method citations alone do not establish the provenance of copied code.
