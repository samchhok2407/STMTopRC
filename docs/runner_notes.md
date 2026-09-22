# Study runner notes

Study entry points are functions. Panel runs all three cases; deep beam and bridge also run all cases by default (pass `false` for the first only). An optional absolute output root separates new results. Run all three study functions to reproduce the twelve cases.

- Panel: same level-10 grid with three material/budget configurations and uniform filtering (`alphaF=1e-4`, `Nfilter=1`). Objective agreement does not imply exact allocation/count agreement.
- Deep beam: five tie restrictions. Scenario 2 has a coarser mesh and smaller automatic budget. Its objective does not isolate restriction effects. Sweep figures use common square-root area scaling.
- Bridge: four modulus ratios, nine 40 kN loads, an inferred 0.05 m^3 budget, and fixed damping 0.5. Common square-root scaling retains each case's display threshold.

The optimizer models nodal forces and restraints, not finite bearing plates.
