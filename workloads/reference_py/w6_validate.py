"""Physics validation of the W6 finite-element solver and optimiser (reference_py/w6_topopt.py).

Each check compares the code W6 runs with an independent truth and prints its numbers:

  (a) cantilever tip deflection against Euler-Bernoulli + Timoshenko shear, under mesh
      refinement (Q4 is too stiff in bending, so it converges from below at O(h^2));
  (b) patch tests: uniform-strain boundary data reproduces the uniform stress to round-off,
      on the workload's own grid assembly and on a distorted five-element patch;
  (c) energy identities: the element sum of strain energy equals 1/2 u'Ku equals 1/2 f'u, and
      compliance equals f'u;
  (d) every OC update meets the volume constraint to the bisection tolerance;
  (e) the analytic sensitivities (no filter, density filter) against central finite
      differences of the compliance.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/w6_validate.py
Exit status 0 if every check passes, 1 otherwise.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import w6_topopt as w  # noqa: E402

FAILS = []


def verdict(name, ok, text):
    print("  %s %s" % ("PASS" if ok else "FAIL", text))
    if not ok:
        FAILS.append(name)


def dense_K(nelx, nely, KE, Ee):
    """Dense global stiffness by plain element scatter (independent of the block solver)."""
    edof = w.element_dofs(nelx, nely)
    n = 2 * (nelx + 1) * (nely + 1)
    K = np.zeros((n, n))
    for e in range(edof.shape[0]):
        K[np.ix_(edof[e], edof[e])] += Ee[e] * KE
    return K


def node_xy(nelx, nely):
    """Coordinates of the grid nodes in node order n = i*(nely+1) + j."""
    i, j = np.meshgrid(np.arange(nelx + 1), np.arange(nely + 1), indexing="ij")
    return np.stack([i.ravel(), j.ravel()], axis=1).astype(float)


# ------------------------------------------------------------------ (a)
def check_cantilever():
    print("(a) Cantilever tip deflection, L/h = 10, E = 1, nu = 0.3, P = 1 (parabolic shear at "
          "the tip), clamped edge")
    ratio = 10
    nu = w.NU
    E = 1.0
    G = E / (2.0 * (1.0 + nu))
    h_beam = 1.0
    L = ratio * h_beam
    P = 1.0
    I = h_beam ** 3 / 12.0
    d_eb = P * L ** 3 / (3.0 * E * I)
    d_timo = d_eb + P * L / ((5.0 / 6.0) * G * h_beam)
    print("  Euler-Bernoulli PL^3/(3EI) = %.6f; + shear PL/(kGA), k = 5/6: Timoshenko = %.6f "
          "(shear part %.3f %%)" % (d_eb, d_timo, 100 * (d_timo - d_eb) / d_eb))
    rows = []
    for nely in (2, 4, 8, 16, 32):
        nelx = ratio * nely
        a = h_beam / nely                    # element size; the grid is scaled by a
        # Q4 stiffness is independent of the element size in 2D, so the unit-square KE serves.
        KE = w.q4_stiffness(w.UNIT_SQUARE, E, nu)
        ndof = 2 * (nelx + 1) * (nely + 1)
        F = np.zeros(ndof)
        # consistent nodal loads of tau(y) = 3P/(2h) (1 - (2y/h - 1)^2) on the tip edge,
        # integrated exactly per segment (Simpson is exact for the cubic tau * N)
        tau = lambda y: 1.5 * P / h_beam * (1.0 - (2.0 * y / h_beam - 1.0) ** 2)
        for j in range(nely):
            y0, y1 = j * a, (j + 1) * a
            ym = 0.5 * (y0 + y1)
            f0 = a / 6.0 * (tau(y0) * 1.0 + 4.0 * tau(ym) * 0.5 + tau(y1) * 0.0)
            f1 = a / 6.0 * (tau(y0) * 0.0 + 4.0 * tau(ym) * 0.5 + tau(y1) * 1.0)
            n0 = nelx * (nely + 1) + j
            F[2 * n0 + 1] -= f0
            F[2 * (n0 + 1) + 1] -= f1
        fixed = np.arange(2 * (nely + 1))
        U = w.fe_solve(nelx, nely, KE, np.ones(nelx * nely), fixed, F)
        tip = -U[2 * (nelx * (nely + 1) + nely // 2) + 1]
        rows.append((nely, nelx, ndof, tip))
    tips = [t for _, _, _, t in rows]
    print("  %6s %6s %7s %14s %10s %12s %10s" % ("nely", "nelx", "DOF", "tip deflection",
                                                 "/Timo", "increment", "inc. ratio"))
    for k, (nely, nelx, ndof, tip) in enumerate(rows):
        inc = "" if k == 0 else "%.4e" % (tip - tips[k - 1])
        rat = "" if k < 2 else "%.3f" % ((tips[k - 1] - tips[k - 2]) / (tip - tips[k - 1]))
        print("  %6d %6d %7d %14.6f %10.6f %12s %10s" % (nely, nelx, ndof, tip, tip / d_timo,
                                                         inc, rat))
    # Richardson extrapolation from the three finest meshes, observed order
    t1, t2, t3 = tips[-3:]
    order = math.log((t2 - t1) / (t3 - t2)) / math.log(2.0)
    t_inf = t3 + (t3 - t2) / (2.0 ** order - 1.0)
    print("  observed order from the three finest meshes %.3f; Richardson limit %.6f = %.5f x "
          "Timoshenko, %.5f x Euler-Bernoulli" % (order, t_inf, t_inf / d_timo, t_inf / d_eb))
    monotone = all(b > a for a, b in zip(tips, tips[1:]))
    verdict("a", monotone and abs(order - 2.0) < 0.2 and abs(t_inf / d_timo - 1.0) < 0.005,
            "monotone from below: %s; order %.3f within 0.2 of 2; limit within 0.5 %% of "
            "Timoshenko (%.3f %%) and outside it from Euler-Bernoulli (%.3f %%)" % (
                monotone, order, 100 * (t_inf / d_timo - 1.0), 100 * (t_inf / d_eb - 1.0)))


# ------------------------------------------------------------------ (b)
def uniform_field(xy):
    a, b, c, d = 1.0e-3, 0.4e-3, -0.7e-3, 2.0e-3      # u = a x + b y, v = c x + d y
    u = a * xy[:, 0] + b * xy[:, 1]
    v = c * xy[:, 0] + d * xy[:, 1]
    eps = np.array([a, d, b + c])
    return np.stack([u, v], axis=1).ravel(), eps


def patch_solve(K, nodes_xy, boundary):
    """Prescribe the uniform-strain displacements on the boundary nodes, solve the rest."""
    ubc, eps = uniform_field(nodes_xy)
    n = K.shape[0]
    pres = np.zeros(n, dtype=bool)
    for b in boundary:
        pres[2 * b] = pres[2 * b + 1] = True
    free = ~pres
    u = ubc.copy()
    u[free] = np.linalg.solve(K[np.ix_(free, free)], -K[np.ix_(free, pres)] @ ubc[pres])
    return u, ubc, eps, free


def stresses(xy_elems, ue, E, nu):
    D = w.plane_stress_D(E, nu)
    out = []
    for xy, u in zip(xy_elems, ue):
        for eta in w.GAUSS2:
            for xi in w.GAUSS2:
                B, _ = w.q4_B(xy, xi, eta)
                out.append(D @ (B @ u))
    return np.array(out)


def check_patch():
    print("(b) Patch tests: u = 1e-3 x + 0.4e-3 y, v = -0.7e-3 x + 2e-3 y on the boundary")
    E, nu = 1.0, w.NU
    D = w.plane_stress_D(E, nu)
    # b1: the workload's grid, element table and assembly (8 x 4 elements)
    nelx, nely = 8, 4
    KE = w.q4_stiffness(w.UNIT_SQUARE, E, nu)
    K = dense_K(nelx, nely, KE, np.ones(nelx * nely))
    xy = node_xy(nelx, nely)
    boundary = [n for n in range(xy.shape[0])
                if xy[n, 0] in (0, nelx) or xy[n, 1] in (0, nely)]
    u, ubc, eps, free = patch_solve(K, xy, boundary)
    edof = w.element_dofs(nelx, nely)
    corners = np.array([[0, 0], [1, 0], [1, 1], [0, 1]], dtype=float)
    e_xy = [corners + xy[edof[e, 0] // 2] for e in range(edof.shape[0])]
    sig = stresses(e_xy, u[edof], E, nu)
    s_exact = D @ eps
    du = np.max(np.abs(u[free] - ubc[free])) / np.max(np.abs(ubc))
    ds = np.max(np.abs(sig - s_exact)) / np.max(np.abs(s_exact))
    print("  grid 8x4 (%d interior unknowns): max rel interior displacement error %.2e, "
          "max rel Gauss-point stress error %.2e" % (int(free.sum()), du, ds))
    verdict("b1", du < 1e-12 and ds < 1e-12, "grid patch reproduces the uniform state to "
            "round-off (bound 1e-12)")
    # b2: distorted five-element patch (unit-thickness rectangle 0.24 x 0.12, four interior
    # nodes off the grid), general Q4 element
    pts = np.array([[0.0, 0.0], [0.24, 0.0], [0.24, 0.12], [0.0, 0.12],
                    [0.04, 0.02], [0.18, 0.03], [0.16, 0.08], [0.08, 0.08]])
    quads = [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7]]
    K = np.zeros((16, 16))
    exy = []
    for q in quads:
        xyq = pts[q]
        exy.append(xyq)
        Kq = w.q4_stiffness(xyq, E, nu)
        idx = np.ravel([[2 * n, 2 * n + 1] for n in q])
        K[np.ix_(idx, idx)] += Kq
    u, ubc, eps, free = patch_solve(K, pts, [0, 1, 2, 3])
    ue = [u[np.ravel([[2 * n, 2 * n + 1] for n in q])] for q in quads]
    sig = stresses(exy, ue, E, nu)
    du = np.max(np.abs(u[free] - ubc[free])) / np.max(np.abs(ubc))
    ds = np.max(np.abs(sig - s_exact)) / np.max(np.abs(s_exact))
    print("  distorted 5-element patch: max rel interior displacement error %.2e, max rel "
          "Gauss-point stress error %.2e" % (du, ds))
    verdict("b2", du < 1e-12 and ds < 1e-12, "distorted patch reproduces the uniform state to "
            "round-off (bound 1e-12)")


# ------------------------------------------------------------------ (c)
def check_energy():
    print("(c) Energy identities with SIMP moduli of a random density field")
    rng = np.random.default_rng(7)
    for kind, nelx, nely in (("mbb", 30, 10), ("cantilever", 24, 12)):
        KE = w.q4_stiffness(w.UNIT_SQUARE, 1.0, w.NU)
        edof = w.element_dofs(nelx, nely)
        fixed, F = w.load_case(kind, nelx, nely)
        xPhys = rng.uniform(0.0, 1.0, (nely, nelx))
        U, Ee, xe = w.analyse(nelx, nely, KE, fixed, F, xPhys)
        c, _ = w.compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx)
        K = dense_K(nelx, nely, KE, Ee)
        se_elem = 0.5 * c
        se_quad = 0.5 * float(U @ K @ U)
        work = 0.5 * float(F @ U)
        r1 = abs(se_elem - work) / work
        r2 = abs(se_quad - work) / work
        r3 = abs(c - 2 * work) / (2 * work)
        print("  %-10s %dx%d: 1/2 sum_e E_e u_e'KE u_e = %.12f, 1/2 u'Ku = %.12f, "
              "1/2 f'u = %.12f" % (kind, nelx, nely, se_elem, se_quad, work))
        print("  %-10s rel diff elem sum vs 1/2 f'u %.2e, 1/2 u'Ku vs 1/2 f'u %.2e, c vs f'u "
              "%.2e" % ("", r1, r2, r3))
        verdict("c", max(r1, r2, r3) < 1e-9, "energy identities hold (bound 1e-9)")
    # The same identity on the workload's MBB mesh at iteration 1 shows the round-off floor of
    # a compliance computed from a direct solve (it sets the c_first rule).
    nelx, nely = 120, 40
    KE = w.q4_stiffness(w.UNIT_SQUARE, 1.0, w.NU)
    edof = w.element_dofs(nelx, nely)
    fixed, F = w.load_case("mbb", nelx, nely)
    xPhys = np.full((nely, nelx), w.VOLFRAC)
    for rev in (False, True):
        U, Ee, xe = w.analyse(nelx, nely, KE, fixed, F, xPhys, reverse=rev)
        c, _ = w.compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx)
        print("  MBB 120x40, uniform 0.5, solver %s: c = %.13f, f'u = %.13f, rel diff %.2e" % (
            "reversed" if rev else "forward ", c, -U[2 * nely + 1], abs(c + U[2 * nely + 1]) / c))


# ------------------------------------------------------------------ (d)
def check_volume():
    print("(d) Volume constraint after every OC update (bisection to (l2-l1)/(l1+l2) <= %g)"
          % w.TOL_LAMBDA)
    worst = 0.0
    for name, kind, ft, nelx, nely, rmin in w.CASES:
        r = w.run_case(kind, ft, nelx, nely, rmin)
        worst = max(worst, r["vol_err_max"])
        print("  %-30s %3d iterations: max |mean(xPhys) - %.2f| = %.2e, final volume %.13f" % (
            name, r["iters"], w.VOLFRAC, r["vol_err_max"], r["vol"]))
    verdict("d", worst < 1e-8, "every update within 1e-8 of the volume fraction (worst %.2e)"
            % worst)


# ------------------------------------------------------------------ (e)
def check_sensitivities():
    print("(e) Analytic sensitivities against central differences of the compliance")
    rng = np.random.default_rng(11)
    for kind, nelx, nely, ft, rmin in (("mbb", 12, 4, 0, 1.5), ("mbb", 12, 4, 2, 1.5),
                                       ("cantilever", 10, 6, 2, 2.5)):
        KE = w.q4_stiffness(w.UNIT_SQUARE, 1.0, w.NU)
        edof = w.element_dofs(nelx, nely)
        fixed, F = w.load_case(kind, nelx, nely)
        W = w.filter_kernel(rmin)
        Hs = w.apply_kernel(np.ones((nely, nelx)), W)
        x = rng.uniform(0.2, 0.9, (nely, nelx))

        def phys(xd):
            return w.apply_kernel(xd, W) / Hs if ft == 2 else xd

        def comp(xd):
            U, Ee, xe = w.analyse(nelx, nely, KE, fixed, F, phys(xd))
            return w.compliance_and_sens(KE, edof, U, Ee, xe, nely, nelx)

        c0, dc = comp(x)
        dc, _ = w.filter_sens(ft, x, dc, W, Hs)
        rels = []
        for step in (1e-3, 1e-4, 1e-5, 1e-6):
            fd = np.zeros_like(x)
            for j in range(nely):
                for i in range(nelx):
                    xp = x.copy()
                    xm = x.copy()
                    xp[j, i] += step
                    xm[j, i] -= step
                    fd[j, i] = (comp(xp)[0] - comp(xm)[0]) / (2 * step)
            rels.append(np.max(np.abs(fd - dc)) / np.max(np.abs(dc)))
        print("  %-10s %dx%d, %-22s: c = %.6f; max |dc_fd - dc| / max |dc| for steps 1e-3, "
              "1e-4, 1e-5, 1e-6: %s" % (kind, nelx, nely, "no filter" if ft == 0 else
                                        "density filter r=%.1f" % rmin, c0,
                                        ", ".join("%.2e" % r for r in rels)))
        verdict("e", min(rels) < 1e-7,
                "best agreement %.2e (bound 1e-7); error ratio steps 1e-3 : 1e-4 = %.0f (100 for "
                "pure O(step^2) truncation; less once round-off enters)" % (min(rels),
                                                                         rels[0] / rels[1]))
    print("  (the sensitivity filter is a heuristic that modifies the gradient by design; it "
          "is not a derivative and is not checked here)")


def main():
    check_cantilever()
    check_patch()
    check_energy()
    check_volume()
    check_sensitivities()
    print("\n%s" % ("ALL W6 VALIDATION CHECKS PASS" if not FAILS else
                    "FAILED: %s" % ", ".join(FAILS)))
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())
