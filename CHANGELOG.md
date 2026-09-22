# Changelog

## 1.0.0 - 2026-09-22

- Ground-structure engine and result utilities with bilinear axial materials,
  grouped volume constraints, ZPR updates, discrete filtering and tie restrictions.
- Three study functions cover twelve manuscript cases; all cases run by default.
- All panel cases use `alphaF=1e-4`, `Nfilter=1` and `maxIter=1000`.
- Refreshed panel layouts, summaries and the twelve-case verification table.
- Aligned signed member-force notation with the manuscript (`Fe` and `S.Fe`).
- Added input validation, asymmetric-restraint and result-persistence regressions.
- Consolidated installation and usage in one root README, with supporting
  parameter, numerical-method, study and reproduction documentation.
- Included the full GNU GPL v3 license and GPL-3.0-or-later source notices.

### Verification

Verified on 2026-09-22 using base MATLAB R2026a Update 2 on 64-bit Windows.
Release regressions and all twelve studies passed convergence, final equilibrium,
volume-budget and displayed-connectivity checks. The three panel objectives
agree with published values within 0.045%; two match at printed precision.
The separate-budget objective is 1.179519, rounding to 1.180 rather than 1.179.
The full-precision numerical and timing snapshot is `results/verification.csv`.
These checks do not establish global optimality, stability or RC design capacity.
