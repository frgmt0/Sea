"""Independent NumPy re-implementation of w2_truss_fem.m (cross-check only).

Index conventions: everything is 0-based internally; indices that the MATLAB script exports
(member numbers, sweep positions) are converted to MATLAB's 1-based numbering on export.
Dense solves use numpy.linalg.solve (LU with partial pivoting). MATLAB's backslash detects
the symmetric positive definite K(free,free) and uses Cholesky, so results agree to rounding
(see the tolerances in ../README.md), not bit for bit.
"""

import math

import numpy as np

from common import mlinspace, write_reference

NAME = "w2_truss_fem"

nPanel, panelL, height = 60, 1.00, 6.00
E, rho, g = 205e9, 7850.0, 9.81
sigY = 275e6
sigAll = sigY / 1.67
DoverT, nBuck, Amin = 20.0, 2.0, 1e-3
wDeck, Ppoint, nAngle = 24e3, 80e3, 1441
fsdTol, fsdMaxIt = 1e-9, 300
catalogA = np.array([4, 5, 6.3, 8, 10, 12.5, 16, 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160,
                     200, 250, 315, 400, 500, 630]) * 1e-4


def assemble_truss(conn, c, s, L, EA, nDof):
    K = np.zeros((nDof, nDof))
    for e in range(conn.shape[0]):
        k = EA[e] / L[e]
        cc = c[e] * c[e] * k
        cs = c[e] * s[e] * k
        ss = s[e] * s[e] * k
        ke = np.array([[cc, cs, -cc, -cs], [cs, ss, -cs, -ss], [-cc, -cs, cc, cs],
                       [-cs, -ss, cs, ss]])
        n1, n2 = conn[e]
        idx = np.array([2 * n1, 2 * n1 + 1, 2 * n2, 2 * n2 + 1])
        K[np.ix_(idx, idx)] += ke
    return K


def self_weight(conn, L, A, nDof):
    F = np.zeros(nDof)
    for e in range(conn.shape[0]):
        w = rho * g * A[e] * L[e] / 2
        F[2 * conn[e, 0] + 1] -= w
        F[2 * conn[e, 1] + 1] -= w
    return F


def solve_free(K, F, free, nDof):
    Kff = K[np.ix_(free, free)]
    if F.ndim == 1:
        U = np.zeros(nDof)
        U[free] = np.linalg.solve(Kff, F[free])
    else:
        U = np.zeros((nDof, F.shape[1]))
        U[free, :] = np.linalg.solve(Kff, F[free, :])
    return U


def member_forces(conn, c, s, L, EA, u):
    N = np.zeros(conn.shape[0])
    for e in range(conn.shape[0]):
        i1 = 2 * conn[e, 0]
        i2 = 2 * conn[e, 1]
        du = u[i2] - u[i1]
        dv = u[i2 + 1] - u[i1 + 1]
        N[e] = EA[e] / L[e] * (c[e] * du + s[e] * dv)
    return N


def force_matrix(conn, c, s, L, EA, nDof):
    B = np.zeros((conn.shape[0], nDof))
    for e in range(conn.shape[0]):
        k = EA[e] / L[e]
        i1 = 2 * conn[e, 0]
        i2 = 2 * conn[e, 1]
        B[e, [i1, i1 + 1, i2, i2 + 1]] = k * np.array([-c[e], -s[e], c[e], s[e]])
    return B


def member_fos(sig, sigCr):
    fos = sigY / np.abs(sig)
    comp = sig < 0
    fos[comp] = np.minimum(fos[comp], sigCr[comp] / np.abs(sig[comp]))
    return fos


def rcond1(A):
    """Reciprocal 1-norm condition number (exact; MATLAB's rcond is an estimate of it)."""
    try:
        return 1.0 / (np.linalg.norm(A, 1) * np.linalg.norm(np.linalg.inv(A), 1))
    except np.linalg.LinAlgError:
        return 0.0


def main():
    nBot = nPanel + 1
    nNode = 2 * nBot
    xy = np.zeros((nNode, 2))
    for i in range(nPanel + 1):
        xy[i] = [i * panelL, 0.0]
        xy[nBot + i] = [i * panelL, height]
    conn, group = [], []
    for i in range(nPanel):
        conn.append([i, i + 1]); group.append(1)
        conn.append([nBot + i, nBot + i + 1]); group.append(2)
    for i in range(nPanel + 1):
        conn.append([i, nBot + i]); group.append(3)
    for i in range(nPanel):
        conn.append([i, nBot + i + 1]); group.append(4)
        conn.append([nBot + i, i + 1]); group.append(4)
    conn = np.array(conn)
    group = np.array(group)
    nElem = conn.shape[0]
    nDof = 2 * nNode
    dx = xy[conn[:, 1], 0] - xy[conn[:, 0], 0]
    dy = xy[conn[:, 1], 1] - xy[conn[:, 0], 1]
    Le = np.sqrt(dx ** 2 + dy ** 2)
    ce = dx / Le
    se = dy / Le
    fixed = [0, 1, 2 * nBot - 1]
    free = np.array([d for d in range(nDof) if d not in fixed])
    midBot = nPanel // 2           # 0-based node index
    midTop = nBot + nPanel // 2

    Fdeck = np.zeros(nDof)
    for i in range(nBot):
        trib = panelL / 2 if i in (0, nBot - 1) else panelL
        Fdeck[2 * i + 1] = -wDeck * trib

    A = 0.01 * np.ones(nElem)
    fsdIters, fsdChange = 0, math.inf
    while fsdIters < fsdMaxIt and fsdChange > fsdTol:
        fsdIters += 1
        K = assemble_truss(conn, ce, se, Le, E * A, nDof)
        F = Fdeck + self_weight(conn, Le, A, nDof)
        u = solve_free(K, F, free, nDof)
        N = member_forces(conn, ce, se, Le, E * A, u)
        Areq = np.abs(N) / sigAll
        comp = N < 0
        Abuck = np.sqrt(8 * np.abs(N) * Le ** 2 * nBuck / (math.pi * E * DoverT))
        Areq[comp] = np.maximum(Areq[comp], Abuck[comp])
        Anew = np.maximum(Areq, Amin)
        fsdChange = float(np.max(np.abs(Anew - A) / A))
        A = Anew
    fsdConverged = fsdChange <= fsdTol
    Afsd = A.copy()
    Acat = np.array([catalogA[np.nonzero(catalogA >= a)[0][0]] for a in Afsd])

    EA = E * Acat
    K = assemble_truss(conn, ce, se, Le, EA, nDof)
    F0 = Fdeck + self_weight(conn, Le, Acat, nDof)
    u0 = solve_free(K, F0, free, nDof)
    N0 = member_forces(conn, ce, se, Le, EA, u0)
    sig0 = N0 / Acat
    sigCr = math.pi * E * Acat * DoverT / (8 * Le ** 2)
    fos0 = member_fos(sig0, sigCr)
    eCrit0 = int(np.argmin(fos0))
    mass = float(np.sum(rho * Acat * Le))
    reactions = K @ u0 - F0

    theta = mlinspace(0, 2 * math.pi, nAngle)
    Fsweep = np.repeat(F0[:, None], nAngle, axis=1)
    Fsweep[2 * midTop, :] += Ppoint * np.cos(theta)
    Fsweep[2 * midTop + 1, :] += Ppoint * np.sin(theta)
    Usweep = solve_free(K, Fsweep, free, nDof)
    B = force_matrix(conn, ce, se, Le, EA, nDof)
    Ssweep = (B @ Usweep) / Acat[:, None]
    utilSweep = np.max(np.abs(Ssweep) / sigAll, axis=0)
    fosSweep = np.array([np.min(member_fos(Ssweep[:, k], sigCr)) for k in range(nAngle)])
    kWorst = int(np.argmax(utilSweep))
    kFos = int(np.argmin(fosSweep))
    deflSweep = Usweep[2 * midBot + 1, :]
    dispTop = np.hypot(Usweep[2 * midTop, :], Usweep[2 * midTop + 1, :])

    Funit = np.zeros((nDof, nBot))
    for i in range(nBot):
        Funit[2 * i + 1, i] = -1.0
    Uinf = solve_free(K, Funit, free, nDof)
    Ninf = B @ Uinf
    eMidChord = nPanel - 2          # MATLAB member nPanel-1 (1-based)
    eEndDiag = 2 * nPanel + (nPanel + 1)   # MATLAB member 3*nPanel+2 (1-based)

    utilRemoved = np.zeros(nElem)
    mechanism = np.zeros(nElem, dtype=bool)
    for r in range(nElem):
        keep = np.ones(nElem, dtype=bool)
        keep[r] = False
        Kr = assemble_truss(conn[keep], ce[keep], se[keep], Le[keep], EA[keep], nDof)
        Fr = Fdeck + self_weight(conn[keep], Le[keep], Acat[keep], nDof)
        if rcond1(Kr[np.ix_(free, free)]) < 1e-12:
            mechanism[r] = True
            utilRemoved[r] = np.nan
            continue
        ur = solve_free(Kr, Fr, free, nDof)
        Nr = member_forces(conn[keep], ce[keep], se[keep], Le[keep], EA[keep], ur)
        utilRemoved[r] = np.max(np.abs(Nr / Acat[keep])) / sigY
    # MATLAB max ignores NaN and returns the first maximum.
    rWorst = int(np.nanargmax(utilRemoved))

    ref = dict(workload=NAME, n_node=nNode, n_elem=nElem, fsd_iters=fsdIters,
               fsd_converged=bool(fsdConverged), A_fsd=Afsd, A_cat=Acat, mass=mass, u0=u0,
               N0=N0, fos0=fos0, fos_min0=fos0[eCrit0], e_crit0=eCrit0 + 1,
               mid_defl0=u0[2 * midBot + 1],
               reactions=[reactions[0], reactions[1], reactions[2 * nBot - 1]], theta=theta,
               util_sweep=utilSweep, fos_sweep=fosSweep, defl_sweep=deflSweep,
               disp_top_sweep=dispTop, util_worst=utilSweep[kWorst], k_worst=kWorst + 1,
               fos_worst=fosSweep[kFos], k_fos_worst=kFos + 1,
               infl_defl=Uinf[2 * midBot + 1, :], infl_chord=Ninf[eMidChord, :],
               infl_diag=Ninf[eEndDiag, :], util_removed=utilRemoved,
               mechanism_count=int(mechanism.sum()),
               overstressed_count=int(np.sum(utilRemoved > 1)),
               util_removed_worst=utilRemoved[rWorst], r_worst=rWorst + 1)
    path = write_reference(NAME, ref)
    names = {1: "bottom chord", 2: "top chord", 3: "vertical", 4: "diagonal"}
    print("W2 truss (NumPy cross-check)")
    print("  nodes %d members %d  FSD iters %d converged %s change %.3e  mass %.1f kg"
          % (nNode, nElem, fsdIters, fsdConverged, fsdChange, mass))
    print("  mid deflection %.3f mm, min FOS %.4f member %d (%s)"
          % (u0[2 * midBot + 1] * 1e3, fos0[eCrit0], eCrit0 + 1, names[group[eCrit0]]))
    print("  reactions", reactions[[0, 1, 2 * nBot - 1]] / 1e3, " applied", -F0.sum() / 1e3)
    print("  sweep worst util %.4f at %.2f deg, worst FOS %.4f at %.2f deg"
          % (utilSweep[kWorst], theta[kWorst] * 180 / math.pi, fosSweep[kFos],
             theta[kFos] * 180 / math.pi))
    print("  removal: %d mechanisms, %d overstressed, worst %.4f (member %d %s)"
          % (mechanism.sum(), np.sum(utilRemoved > 1), utilRemoved[rWorst], rWorst + 1,
             names[group[rWorst]]))
    print("  wrote", path)


if __name__ == "__main__":
    main()
