# Changelog

## Unreleased

### Changed

- Made `LICENSE.txt` carry the verbatim GNU GPL v3 text and removed the
  duplicate `COPYING.txt`, so the license is detected automatically. The
  `GPL-3.0-or-later` grant is stated by the SPDX header in each source file.

- Flattened the package layout: `src/`, `examples/`, `tests/`, `docs/` and
  `results/` now sit at the repository root instead of a nested `STMTopRC/`
  directory. Study runners and `Results` locate their own paths relatively,
  so no MATLAB code changed. Documentation paths were updated to match.
- Removed the duplicate `STMTopRC/LICENSE.txt`; the root notice is retained.

- Aligned member-force notation with the manuscript: `Fe` and `S.Fe`.
  `Results.load` converts the legacy saved force field to the current name.

- Shortened license notices; preserved the unchanged full GPL text in `COPYING.txt`.

- Added author, contribution, reproducibility and troubleshooting guidance.
- Expanded the root README with installation, units, study and result-field notes.
- Consolidated usage, output and regression instructions into one root README.
- Kept three independently callable study functions for the manuscript examples.
- Added required/unknown input errors and core model validation.
- Corrected symmetry detection for asymmetric horizontal restraints.
- Made display metrics respect the stored collinear-merge setting.
- Added errors for unpaired rescaling options and failed summary-file opening.
- Added release regression checks and refreshed all twelve case outputs.
- Corrected citation metadata and clarified numerical and modeling limitations.
- Removed obsolete documentation and illustrative assets from the software package.

### Verification

All twelve manuscript cases passed convergence, final equilibrium, volume-budget
and displayed-connectivity checks on MATLAB R2026a Update 2. Panel objectives
matched published values at their printed precision. The saved verification table
records this run; the individual study functions regenerate case outputs.

## 1.0.0 - 2026-09-16

Initial version with the ground-structure engine, result utilities and three
study definitions. This version uses bilinear axial materials, grouped volume
constraints, ZPR updates, discrete filtering and tie-placement restrictions.
The changes above have not been assigned a new release tag.
