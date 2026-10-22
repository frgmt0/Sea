"""Independent NumPy re-implementation of w6_topopt.m (cross-check only).

2D SIMP compliance minimisation (MBB half-beam and cantilever), written from the published
method (Bendsoe 1989 SIMP; Sigmund 2001; Andreassen et al. 2011) with this repository's own
structure and naming. The algorithm, the parameters and the exported keys are specified in
the header of ../w6_topopt.m; this file follows it step by step.

Conventions (as in the MATLAB script): unit square elements, nelx columns by nely rows, x to
the right and y upwards. Node (i, j), i = 0..nelx, j = 0..nely, has the 0-based number
n = i*(nely+1) + j and the DOFs 2n (u_x) and 2n+1 (u_y). Element (i, j), i = 0..nelx-1,
j = 0..nely-1, is stored at field[j, i] (row = y), which is MATLAB's x(j+1, i+1); its 0-based
linear number in column-major order is e = i*nely + j.

Linear solver: the global stiffness matrix is block tridiagonal when the DOFs are grouped by
node column (an element couples only node columns i and i+1), so it is factored by a block
Cholesky over the nelx+1 columns with dense LAPACK kernels (numpy.linalg.cholesky / solve).
MATLAB uses its sparse direct solver (CHOLMOD for the SPD K(free,free)), so the two agree to
rounding, not bit for bit. The other ports use NumPy only, and so does this one.

Only for the round-off study (w6_roundoff.py) and the validation (w6_validate.py): `run_case`
takes options that change the solver's elimination order, the filter's summation order, or
perturb an input by one ulp. The workload itself uses the defaults.
"""

import math

import numpy as np

from common import write_reference

NAME = "w6_topopt"

# ------------------------------------------------------------------ parameters (as w6_topopt.m)
E0 = 1.0             # Young's modulus of solid material [-]
EMIN = 1e-9          # Young's modulus of void (keeps K nonsingular) [-]
NU = 0.3             # Poisson's ratio [-]
PENAL = 3.0          # SIMP penalisation exponent p [-]
VOLFRAC = 0.5        # prescribed volume fraction [-]
MOVE = 0.2           # OC move limit [-]
TOL_CHANGE = 0.01    # stop when max |x_new - x| <= TOL_CHANGE ...
MAX_ITER = 200       # ... or after MAX_ITER design updates
LAMBDA_HI = 1e9      # initial upper bound of the OC Lagrange multiplier bisection
TOL_LAMBDA = 1e-9    # bisection stops when (l2 - l1)/(l1 + l2) <= TOL_LAMBDA
N_EARLY = 10         # compliance history exported for iterations 1..N_EARLY
N_MID = 50           # ... and the compliance at iteration N_MID

# The three cases: name, load case, filter (1 = sensitivity, 2 = density), nelx, nely, rmin.
CASES = [
    ("MBB beam, density filter", "mbb", 2, 120, 40, 4.8),
    ("MBB beam, sensitivity filter", "mbb", 1, 120, 40, 4.8),
    ("Cantilever, density filter", "cantilever", 2, 100, 50, 4.0),
]
FIELD_KEYS = ["x_mbb_density", "x_mbb_sensitivity", "x_cantilever_density"]


# ------------------------------------------------------------------ Q4 element
def plane_stress_D(E, nu):
    """Plane-stress constitutive matrix (Voigt order xx, yy, xy with engineering shear)."""
    f = E / (1.0 - nu * nu)
    return f * np.array([[1.0, nu, 0.0], [nu, 1.0, 0.0], [0.0, 0.0, (1.0 - nu) / 2.0]])


def q4_shape_derivs(xi, eta):
    """Derivatives of the four bilinear shape functions w.r.t. (xi, eta), nodes ordered
    (-1,-1), (1,-1), (1,1), (-1,1). Returns a 2x4 array [dN/dxi; dN/deta]."""
    return 0.25 * np.array([[-(1 - eta), (1 - eta), (1 + eta), -(1 + eta)],
                            [-(1 - xi), -(1 + xi), (1 + xi), (1 - xi)]])


def q4_B(xy, xi, eta):
    """Strain-displacement matrix (3x8) and Jacobian determinant of a Q4 element with node
    coordinates xy (4x2, counterclockwise) at the natural point (xi, eta)."""
    dN = q4_shape_derivs(xi, eta)
    J = dN @ xy                         # 2x2: [dx/dxi dy/dxi; dx/deta dy/deta]
    detJ = J[0, 0] * J[1, 1] - J[0, 1] * J[1, 0]
    dNxy = np.linalg.solve(J, dN)       # 2x4: [dN/dx; dN/dy]
    B = np.zeros((3, 8))
    B[0, 0::2] = dNxy[0]
    B[1, 1::2] = dNxy[1]
    B[2, 0::2] = dNxy[1]
    B[2, 1::2] = dNxy[0]
    return B, detJ


GAUSS2 = (-1.0 / math.sqrt(3.0), 1.0 / math.sqrt(3.0))


def q4_stiffness(xy, E, nu):
    """8x8 stiffness of a plane-stress Q4 element of unit thickness by 2x2 Gauss quadrature
    (exact for a parallelogram). DOF order u1x u1y u2x u2y u3x u3y u4x u4y."""
    D = plane_stress_D(E, nu)
    K = np.zeros((8, 8))
    for eta in GAUSS2:          # same loop order as the MATLAB script
        for xi in GAUSS2:
            B, detJ = q4_B(xy, xi, eta)
            K += (B.T @ D @ B) * detJ
    return 0.5 * (K + K.T)      # exactly symmetric (the rounding of B^T D B need not be)


UNIT_SQUARE = np.array([[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]])


# ------------------------------------------------------------------ mesh
def element_dofs(nelx, nely):
    """0-based DOF table (nel x 8), rows in column-major element order e = i*nely + j.
    Element nodes: (i,j), (i+1,j), (i+1,j+1), (i,j+1)."""
    i, j = np.meshgrid(np.arange(nelx), np.arange(nely), indexing="xy")
    i = i.ravel(order="F")
    j = j.ravel(order="F")
    n1 = i * (nely + 1) + j
    n2 = (i + 1) * (nely + 1) + j
    n3 = n2 + 1
    n4 = n1 + 1
    return np.stack([2 * n1, 2 * n1 + 1, 2 * n2, 2 * n2 + 1, 2 * n3, 2 * n3 + 1,
                     2 * n4, 2 * n4 + 1], axis=1)


def load_case(kind, nelx, nely, load=-1.0):
    """Fixed DOFs (0-based) and the load vector of a case."""
    ndof = 2 * (nelx + 1) * (nely + 1)
    F = np.zeros(ndof)
    if kind == "mbb":
        # Half MBB beam: symmetry (u_x = 0) on the left edge, roller (u_y = 0) at the
        # bottom-right corner, unit downward load at the top-left corner.
        fixed = np.concatenate([2 * np.arange(nely + 1),
                                [2 * (nelx * (nely + 1)) + 1]])
        F[2 * nely + 1] = load
    elif kind == "cantilever":
        if nely % 2:
            raise ValueError("cantilever needs an even nely")
        # Clamped left edge, unit downward load at the middle of the right edge.
        fixed = np.arange(2 * (nely + 1))
        F[2 * (nelx * (nely + 1) + nely // 2) + 1] = load
    else:
        raise ValueError("unknown load case %s" % kind)
    return np.sort(fixed), F


# ------------------------------------------------------------------ linear solver
class BlockTridiagSolver:
    """K u = f for the grid stiffness matrix, factored by block Cholesky over node columns.

    Prescribed (zero) DOFs are removed by replacing their rows and columns with those of the
    identity and their right-hand side with 0, which leaves the free unknowns' solution of
    K(free,free) u(free) = f(free) unchanged. reverse=True eliminates the columns from right
    to left (a different rounding of the same exact solution; round-off study only).
    """

    def __init__(self, nelx, nely, KE, Ee, fixed, reverse=False):
        m = 2 * (nely + 1)
        nc = nelx + 1
        self.m, self.nc, self.reverse = m, nc, reverse
        # local (column offset, row-in-column) of the 8 element DOFs, element at row j
        coff = np.array([0, 0, 1, 1, 1, 1, 0, 0])
        loff = np.array([0, 1, 0, 1, 2, 3, 2, 3])
        Dg = np.zeros((nc, m, m))
        Og = np.zeros((nc - 1, m, m))      # Og[i] = K(column i, column i+1)
        ii, jj = np.meshgrid(np.arange(nelx), np.arange(nely), indexing="xy")
        ii = ii.ravel(order="F")
        jj = jj.ravel(order="F")
        for a in range(8):
            for b in range(8):
                vals = Ee * KE[a, b]
                ra = 2 * jj + loff[a]
                rb = 2 * jj + loff[b]
                if coff[a] == coff[b]:
                    np.add.at(Dg, (ii + coff[a], ra, rb), vals)
                elif coff[a] == 0:
                    np.add.at(Og, (ii, ra, rb), vals)
                # coff[a] == 1, coff[b] == 0 is the transpose of the case above (KE symmetric)
        for g in fixed:
            c, l = divmod(int(g), m)
            Dg[c, l, :] = 0.0
            Dg[c, :, l] = 0.0
            Dg[c, l, l] = 1.0
            if c < nc - 1:
                Og[c, l, :] = 0.0
            if c > 0:
                Og[c - 1, :, l] = 0.0
        self.fixed = np.asarray(fixed, dtype=int)
        if reverse:
            # renumber the columns right to left: the coupling block becomes the transpose
            Dg = Dg[::-1].copy()
            Og = np.transpose(Og[::-1], (0, 2, 1)).copy()
        # factor: L_i L_i^T = D_i - C_{i-1} C_{i-1}^T, C_i = O_i^T L_i^{-T}
        self.L = np.zeros_like(Dg)
        self.C = np.zeros_like(Og)
        for c in range(nc):
            S = Dg[c].copy()
            if c > 0:
                S -= self.C[c - 1] @ self.C[c - 1].T
            self.L[c] = np.linalg.cholesky(S)
            if c < nc - 1:
                self.C[c] = np.linalg.solve(self.L[c], Og[c]).T

    def solve(self, f):
        m, nc = self.m, self.nc
        b = f.copy()
        b[self.fixed] = 0.0
        b = b.reshape(nc, m)
        if self.reverse:
            b = b[::-1]
        y = np.zeros((nc, m))
        for c in range(nc):
            r = b[c] - (self.C[c - 1] @ y[c - 1] if c > 0 else 0.0)
            y[c] = np.linalg.solve(self.L[c], r)
        u = np.zeros((nc, m))
        for c in range(nc - 1, -1, -1):
            r = y[c] - (self.C[c].T @ u[c + 1] if c < nc - 1 else 0.0)
            u[c] = np.linalg.solve(self.L[c].T, r)
        if self.reverse:
            u = u[::-1]
        return u.reshape(-1)


def fe_solve(nelx, nely, KE, Ee, fixed, F, reverse=False):
    return BlockTridiagSolver(nelx, nely, KE, Ee, fixed, reverse).solve(F)


def element_energy(KE, edof, U):
    """u_e^T KE u_e per element (column-major element order)."""
    Ue = U[edof]
    return np.einsum("ea,ab,eb->e", Ue, KE, Ue)


# ------------------------------------------------------------------ filter
def filter_kernel(rmin):
    """Weights w(dy, dx) = max(0, rmin - sqrt(dx^2 + dy^2)) on the integer offsets with
    |dx|, |dy| <= ceil(rmin) - 1, as a (2R+1) x (2R+1) array (symmetric)."""
    R = int(math.ceil(rmin)) - 1
    d = np.arange(-R, R + 1, dtype=float)
    dx, dy = np.meshgrid(d, d)
    return np.maximum(0.0, rmin - np.sqrt(dx * dx + dy * dy))


def apply_kernel(A, W, reverse=False):
    """sum over offsets of W(dy,dx) * A(j+dy, i+dx), zero outside the domain: MATLAB's
    conv2(A, W, 'same') for the symmetric W. reverse=True sums the offsets in the opposite
    order (round-off study only)."""
    ny, nx = A.shape
    R = (W.shape[0] - 1) // 2
    P = np.zeros((ny + 2 * R, nx + 2 * R))
    P[R:R + ny, R:R + nx] = A
    out = np.zeros_like(A)
    offs = [(a, b) for b in range(2 * R + 1) for a in range(2 * R + 1)]
    if reverse:
        offs = offs[::-1]
    for a, b in offs:
        w = W[a, b]
        if w != 0.0:
            out += w * P[a:a + ny, b:b + nx]
    return out


# ------------------------------------------------------------------ optimiser
def oc_update(x, dc, dv, ft, W, Hs, volfrac, move, filt_rev=False):
    """Optimality-criteria update with bisection on the Lagrange multiplier. Returns
    (x_new, xPhys_new, n_bisect)."""
    l1, l2 = 0.0, LAMBDA_HI
    target = volfrac * x.size
    nb = 0
    ratio = -dc / dv
    if np.any(ratio < 0):
        raise ValueError("a compliance sensitivity is positive; the OC update needs dc <= 0")
    while (l2 - l1) / (l1 + l2) > TOL_LAMBDA:
        lmid = 0.5 * (l1 + l2)
        xB = x * np.sqrt(ratio / lmid)
        xnew = np.maximum(0.0, np.maximum(x - move, np.minimum(1.0, np.minimum(x + move, xB))))
        if ft == 2:
            xPhys = apply_kernel(xnew, W, filt_rev) / Hs
        else:
            xPhys = xnew
        if np.sum(xPhys) > target:      # too much material: raise the multiplier
            l1 = lmid
        else:
            l2 = lmid
        nb += 1
    return xnew, xPhys, nb


def analyse(nelx, nely, KE, fixed, F, xPhys, e0=E0, reverse=False):
    """FE analysis of the physical densities xPhys (nely x nelx): returns the displacements U,
    the SIMP moduli Ee and the densities xe, both in element order."""
    xe = xPhys.ravel(order="F")
    Ee = EMIN + xe ** PENAL * (e0 - EMIN)
    U = fe_solve(nelx, nely, KE, Ee, fixed, F, reverse)
    return U, Ee, xe


def compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx, e0=E0):
    """Compliance c = sum_e E_e u_e' KE u_e and its derivative dc w.r.t. xPhys (nely x nelx)."""
    ce = element_energy(KE, edof, U)
    c = float(np.sum(Ee * ce))
    dc = (-PENAL * (e0 - EMIN) * xe ** (PENAL - 1) * ce).reshape((nely, nelx), order="F")
    return c, dc


def filter_sens(ft, x, dc, W, Hs, reverse=False):
    """Filtered sensitivities (dc, dv) w.r.t. the design variables x: ft = 1 sensitivity filter
    (heuristic), ft = 2 density filter (chain rule through xPhys = H x / Hs), ft = 0 none."""
    dv = np.ones_like(x)
    if ft == 1:
        dc = apply_kernel(x * dc, W, reverse) / Hs / np.maximum(1e-3, x)
    elif ft == 2:
        dc = apply_kernel(dc / Hs, W, reverse)
        dv = apply_kernel(dv / Hs, W, reverse)
    return dc, dv


def run_case(kind, ft, nelx, nely, rmin, *, reverse_solver=False, reverse_filter=False,
             e0=E0, nu=NU, load=-1.0, volfrac=VOLFRAC, max_iter=MAX_ITER, tol_change=TOL_CHANGE,
             noise=0.0, keep_history=False):
    """One topology optimisation run. Returns a dict of results.

    The keyword options exist for the round-off study only (w6_roundoff.py): noise > 0
    multiplies every displacement of every solve by (1 + noise*r), r uniform in [-1, 1] from a
    fixed seed, which models an inexact (iterative) solver of that relative accuracy."""
    rng = np.random.default_rng(12345)
    KE = q4_stiffness(UNIT_SQUARE, 1.0, nu)
    edof = element_dofs(nelx, nely)
    fixed, F = load_case(kind, nelx, nely, load)
    W = filter_kernel(rmin)
    Hs = apply_kernel(np.ones((nely, nelx)), W, reverse_filter)
    x = np.full((nely, nelx), volfrac)
    xPhys = x.copy()
    if ft == 2:
        xPhys = apply_kernel(x, W, reverse_filter) / Hs
    c_hist = []
    vol_err = []
    xhist = []
    change = math.inf
    it = 0
    nb_total = 0
    while it < max_iter and change > tol_change:
        it += 1
        U, Ee, xe = analyse(nelx, nely, KE, fixed, F, xPhys, e0, reverse_solver)
        if noise > 0.0:
            U = U * (1.0 + noise * rng.uniform(-1.0, 1.0, U.size))
        c, dc = compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx, e0)
        c_hist.append(c)
        dc, dv = filter_sens(ft, x, dc, W, Hs, reverse_filter)
        xnew, xPhys, nb = oc_update(x, dc, dv, ft, W, Hs, volfrac, MOVE, reverse_filter)
        nb_total += nb
        vol_err.append(abs(float(np.mean(xPhys)) - volfrac))
        change = float(np.max(np.abs(xnew - x)))
        x = xnew
        if keep_history:
            xhist.append(xPhys.copy())
    # compliance of the final design (one more solve)
    U, Ee, xe = analyse(nelx, nely, KE, fixed, F, xPhys, e0, reverse_solver)
    c_final, _ = compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx, e0)
    return dict(iters=it, converged=change <= tol_change, change=change, c_hist=c_hist,
                c_first=c_hist[0], c_final=c_final, vol=float(np.mean(xPhys)),
                vol_err_max=max(vol_err), gray=float(4.0 * np.mean(xPhys * (1.0 - xPhys))),
                n_solid=int(np.sum(xPhys > 0.5)), xPhys=xPhys, f_dot_u=float(F @ U),
                n_bisect=nb_total, xhist=xhist)


def main():
    res = []
    for name, kind, ft, nelx, nely, rmin in CASES:
        r = run_case(kind, ft, nelx, nely, rmin)
        res.append(r)
        print("%-30s %3dx%-3d rmin %.1f  iters %3d conv %d  c1 %.6f  c %.6f  vol %.6f  "
              "gray %.4f  change %.4f" % (name, nelx, nely, rmin, r["iters"], r["converged"],
                                         r["c_first"], r["c_final"], r["vol"], r["gray"],
                                         r["change"]))
    early = [r["c_hist"][:N_EARLY] for r in res]
    mid = [r["c_hist"][N_MID - 1] for r in res]
    ref = dict(workload=NAME,
               case_name=[c[0] for c in CASES], case_load=[c[1] for c in CASES],
               case_filter=[c[2] for c in CASES], case_nelx=[c[3] for c in CASES],
               case_nely=[c[4] for c in CASES], case_rmin=[c[5] for c in CASES],
               ke=q4_stiffness(UNIT_SQUARE, 1.0, NU),
               iters=[r["iters"] for r in res], converged=[bool(r["converged"]) for r in res],
               change_final=[r["change"] for r in res],
               c_first=[r["c_first"] for r in res], c_early=early, c_mid=mid,
               c_final=[r["c_final"] for r in res], vol_final=[r["vol"] for r in res],
               vol_err_max=[r["vol_err_max"] for r in res], gray=[r["gray"] for r in res],
               n_solid=[r["n_solid"] for r in res])
    for key, r in zip(FIELD_KEYS, res):
        ref[key] = r["xPhys"]
    path = write_reference(NAME, ref)
    print("  wrote", path)


if __name__ == "__main__":
    main()
