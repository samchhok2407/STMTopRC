# Numerical implementation

The implementation is in `src/Engine.m` and `src/Results.m`. Required model fields include `maxIter`; see [parameters](parameter_guide.md).

The rectangular grid has `(nx+1)*(ny+1)` nodes. Candidate pairs are filtered for through-node redundancy, minimum length, and Chebyshev connectivity. Supports and loads snap to nearest nodes; repeated loads accumulate.

Axial strain uses undeformed directions. Materials have separate tensile/compressive moduli; nominal zero branches use an `inactiveFactor` floor. Newton iterations use residual backtracking and diagonal stabilization. Final equilibrium uses unregularized physical internal forces. Intermediate Newton failures are not individually flagged; final equilibrium must be checked separately from area convergence.

`J = f'*u - sum(area.*length.*energyDensity)`, equal to half compliance at an equilibrated bilinear state. Sensitivity is minus length times energy density. ZPR uses one bisection multiplier per disjoint volume group, bounded/damped updates, and filtering that zeros small areas while retaining full arrays.

Mirror averaging requires mirrored vertical restraints and reflected loads. Horizontal restraints must mirror too, except that one horizontal restraint may remove rigid translation under zero net horizontal load. This preserves the default pin/roller case.

Convergence tests area change against `max(tolOpt,tolRel*max(area))`, after at least six iterations. Final equilibrium uses `norm(Fint(free)-Fext(free))/max(norm(Fext(free)),1)`, with threshold `1e-3`. For loads below one force unit this is a mixed absolute/relative criterion, not scale-invariant relative error.

Load path uses all physical forces. Display thresholding, merging, and width scaling do not alter the optimized state. Connectivity does not establish stability or RC capacity.
