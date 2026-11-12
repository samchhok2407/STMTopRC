# Changelog

## 1.0.0 - 2026-11-12

Release accompanying the manuscript *Ground-structure topology optimization of
reinforced-concrete strut-and-tie models: the STMTopRC MATLAB package*.

- Ground-structure engine (`src/Engine.m`) and result utilities
  (`src/Results.m`) with bilinear axial materials, grouped volume constraints,
  ZPR updates, adaptive damping, discrete filtering, tie-region and tie-angle
  restrictions, and polygonal domains with openings (`domain`).
- Supported materials: one bilinear `[Et Ec]` row, or two rows `[Et 0; 0 Ec]`
  (ties, struts). Tie-region and tie-angle restrictions require the two-row
  model and are rejected for one row
  (`Engine:tieRestrictionRequiresTwoMaterials`).
- Newton-Raphson state solver with a branch-dependent tangent and an
  energy-based (Armijo) backtracking line search. Every state solve must
  converge; a failure stops the run (`Engine:stateNotConverged`,
  `Engine:lineSearchFailed`) instead of passing an unconverged state to the
  update. `S.hist.nNR` and `S.stateInfo` record the solves.
- Relative residuals use the reference force `max(norm(Fext), P)` (`S.Fscale`),
  so convergence and the equilibrium check do not depend on the force unit.
- Tikhonov regularization `GammaFactor * kRef`, with `kRef` the largest
  diagonal entry of a reference stiffness assembled from the initial areas and
  the larger modulus of each material (`S.kRef`, `S.Gamma`).
- The convergence test stops every run; `maxIter` (default 10000) is only a
  safeguard cap, and a run that reaches it prints a warning and returns
  `S.converged = false`, `S.stopReason = 'maxIter'`.
- Input validation of every model, optimizer, filter and plotting setting;
  `Engine:snapped` warns when a support or load is moved to the nearest node.
- Eleven case runners in `examples/`, one per manuscript case: the published
  panel benchmark (`run_panel_*`, 3), the deep-beam tie restrictions
  (`run_deepbeam_tie_*`, 5) and three members with openings
  (`run_rc_beam_four_holes`, `run_deepbeam_one_hole`, `run_deepbeam_two_holes`).
- `examples/run_all_verification.m` runs the regression tests and all eleven
  cases, checks each one against its release-regression baseline and writes
  `results/verification.csv`.
- `tests/convergence_history.m` plots manuscript Fig. 6, the
  convergence history (objective, maximum area change, material volume
  fractions) of the shared-budget panel; `S.hist.Vfrac` records the fractions
  per iteration.
- Regression tests `selftest_ZhaoAppendixB`, `selftest_stateSolver`,
  `selftest_sensitivity`, `selftest_symmetry` and `selftest_robustness`, run
  by `selftest_release`.
- `S.elapsedSeconds` (the `Engine` call) is saved in every `result.mat`.
- Layout plots (saved at 1000 dpi) can show the ground structure, domain
  boundary, applied loads, supports, reactions, and member forces or areas.
- Signed member forces follow the manuscript notation (`Fe`, `S.Fe`).
- Full GNU GPL v3 license text and GPL-3.0-or-later source notices.

### Verification

Verified on 2026-11-12 using base MATLAB R2026a Update 2 on 64-bit Windows 11.
The regression tests and all eleven cases passed convergence, final
equilibrium, volume-budget and displayed-connectivity checks, with every
state solve converged. The panel objectives agree with the published values
within 0.042%, computed from the full-precision objectives; the members with
openings agree with the published ST-method member forces within 0.03 kN. The
five deep-beam cases are demonstrations of tie restrictions, not numerical
validation benchmarks. W1 depends on `inactiveFactor` (see `docs/examples.md`).
The full-precision snapshot is `results/verification.csv`. These checks do not
establish global optimality, stability or RC design capacity.
