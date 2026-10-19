"""Independent NumPy re-implementation of w4_heat_plate.m (cross-check only).

The scalar SOR sweep is a plain Python loop over Python floats in the same order as the
MATLAB script (columns i = 1..nx outer, rows j = 2..ny-1 inner) with the same summation
order, so the iteration count is expected to match exactly. It is slow in Python (tens of
seconds); that is expected. Arrays are indexed T[j, i] (row = y), as in MATLAB.
"""

import math

import numpy as np

from common import mround, write_reference

NAME = "w4_heat_plate"

W, H, h = 0.30, 0.20, 0.00125
kCond, tPlate = 167.0, 0.005
Tbot0, Tbot1, Ttop, Thole = 40.0, 65.0, 20.0, 12.0
holeC, holeR = (0.215, 0.105), 0.018
srcBox = (0.06, 0.11, 0.07, 0.12)
qSrc, tol, maxIt = 2.5e7, 1e-8, 20000


def rb_half_sweep(T, src, colorIn, omega):
    ny = T.shape[0]
    Tp = np.hstack([T[1:ny - 1, 1:2], T[1:ny - 1, :], T[1:ny - 1, -2:-1]])
    Tc = T[1:ny - 1, :].copy()
    tgs = (Tp[:, :-2] + Tp[:, 2:] + T[0:ny - 2, :] + T[2:ny, :] + src[1:ny - 1, :]) / 4
    Tn = Tc + omega * (tgs - Tc)
    dMax = float(np.max(np.abs(Tn[colorIn] - Tc[colorIn])))
    Tc[colorIn] = Tn[colorIn]
    T = T.copy()
    T[1:ny - 1, :] = Tc
    return T, dMax


def residual(T, src, unknown):
    ny, nx = T.shape
    Tp = np.hstack([T[:, 1:2], T, T[:, nx - 2:nx - 1]])
    R = np.zeros((ny, nx))
    R[1:ny - 1, :] = (Tp[1:ny - 1, 0:nx] + Tp[1:ny - 1, 2:nx + 2] + T[0:ny - 2, :]
                      + T[2:ny, :] - 4 * T[1:ny - 1, :] + src[1:ny - 1, :])
    return float(np.max(np.abs(R[unknown])))


def main():
    nx = int(mround(W / h)) + 1
    ny = int(mround(H / h)) + 1
    x = np.arange(nx) * h
    y = np.arange(ny) * h
    X, Y = np.meshgrid(x, y)
    hole = (X - holeC[0]) ** 2 + (Y - holeC[1]) ** 2 <= holeR ** 2
    src = np.zeros((ny, nx))
    inSrc = (X >= srcBox[0]) & (X <= srcBox[1]) & (Y >= srcBox[2]) & (Y <= srcBox[3])
    src[inSrc] = h ** 2 * qSrc / kCond
    fixed = hole.copy()
    fixed[0, :] = True
    fixed[ny - 1, :] = True
    unknown = ~fixed
    T0 = Ttop * np.ones((ny, nx))
    T0[0, :] = Tbot0 + (Tbot1 - Tbot0) * x / W
    T0[ny - 1, :] = Ttop
    T0[hole] = Thole
    rhoJ = (1 + math.cos(math.pi / (ny - 1))) / 2
    omega = 2 / (1 + math.sqrt(1 - rhoJ ** 2))

    # ---- scalar SOR (columns as Python lists)
    cols = [T0[:, i].tolist() for i in range(nx)]
    srcc = [src[:, i].tolist() for i in range(nx)]
    fixc = [fixed[:, i].tolist() for i in range(nx)]
    itSor, dMax = 0, math.inf
    while dMax > tol and itSor < maxIt:
        itSor += 1
        dMax = 0.0
        for i in range(nx):
            col = cols[i]
            cw = cols[1] if i == 0 else cols[i - 1]
            ce = cols[nx - 2] if i == nx - 1 else cols[i + 1]
            fc = fixc[i]
            sc = srcc[i]
            for j in range(1, ny - 1):
                if fc[j]:
                    continue
                t = col[j]
                tgs = (cw[j] + ce[j] + col[j - 1] + col[j + 1] + sc[j]) / 4
                tn = t + omega * (tgs - t)
                d = abs(tn - t)
                if d > dMax:
                    dMax = d
                col[j] = tn
    Tsor = np.array(cols).T
    dSor = dMax

    # ---- red-black SOR
    I, J = np.meshgrid(np.arange(1, nx + 1), np.arange(1, ny + 1))
    red = ((I + J) % 2 == 0) & unknown
    black = ((I + J) % 2 == 1) & unknown
    redIn, blackIn = red[1:ny - 1, :], black[1:ny - 1, :]
    T = T0.copy()
    itRb, dMax = 0, math.inf
    while dMax > tol and itRb < maxIt:
        itRb += 1
        T, d1 = rb_half_sweep(T, src, redIn, omega)
        T, d2 = rb_half_sweep(T, src, blackIn, omega)
        dMax = max(d1, d2)
    Trb = T
    dRb = dMax

    resSor = residual(Tsor, src, unknown)
    resRb = residual(Trb, src, unknown)
    diffSolvers = float(np.max(np.abs(Tsor - Trb)))

    T = Tsor
    flatF = np.where(unknown, T, -np.inf).ravel(order="F")
    kMax = int(np.argmax(flatF))
    jMax, iMax = kMax % ny, kMax // ny
    Tmax = flatF[kMax]
    Tmean = float(np.mean(T.T[unknown.T]))   # column-major order, as T(unknown)

    wEdge = np.ones(nx)
    wEdge[[0, nx - 1]] = 0.5
    Qbot = kCond * tPlate * np.sum(wEdge * (T[0, :] - T[1, :]))
    Qtop = kCond * tPlate * np.sum(wEdge * (T[ny - 1, :] - T[ny - 2, :]))
    holeIdx = np.nonzero(hole.ravel(order="F"))[0]
    hj, hi = holeIdx % ny, holeIdx // ny
    Qhole = 0.0
    for dj, di in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        nj, ni = hj + dj, hi + di
        m = unknown[nj, ni]
        Qhole = Qhole + kCond * tPlate * np.sum(T[hj[m], hi[m]] - T[nj[m], ni[m]])
    cellW = np.ones((ny, nx))
    cellW[:, [0, nx - 1]] = 0.5
    msk = (inSrc & unknown).T
    Qgen = np.sum(qSrc * h ** 2 * tPlate * cellW.T[msk])
    Qbalance = Qbot + Qtop + Qhole + Qgen

    qx = -kCond * (T[1:ny - 1, 2:nx] - T[1:ny - 1, 0:nx - 2]) / (2 * h)
    qy = -kCond * (T[2:ny, 1:nx - 1] - T[0:ny - 2, 1:nx - 1]) / (2 * h)
    qMag = np.sqrt(qx ** 2 + qy ** 2)
    qf = qMag.ravel(order="F")
    kq = int(np.argmax(qf))
    jq, iq = kq % qMag.shape[0], kq // qMag.shape[0]
    iMid, jMid = (nx + 1) // 2 - 1, (ny + 1) // 2 - 1

    ref = dict(workload=NAME, nx=nx, ny=ny, n_unknown=int(unknown.sum()),
               n_hole=int(hole.sum()), omega=omega, it_sor=itSor, it_rb=itRb, res_sor=resSor,
               res_rb=resRb, diff_solvers=diffSolvers, T_max=Tmax, x_Tmax=x[iMax],
               y_Tmax=y[jMax], T_mean=Tmean, Q_bottom=Qbot, Q_top=Qtop, Q_hole=Qhole,
               Q_gen=Qgen, Q_balance=Qbalance, q_max=qf[kq], x_qmax=x[iq + 1],
               y_qmax=y[jq + 1], profile_x=T[jMid, :], profile_y=T[:, iMid],
               T_sub=T[0:ny:8, 0:nx:8])
    path = write_reference(NAME, ref)
    print("W4 heat plate (NumPy cross-check)")
    print("  grid %dx%d unknowns %d hole %d omega %.6f" % (nx, ny, unknown.sum(), hole.sum(),
                                                          omega))
    print("  scalar SOR %d sweeps (last %.3e, res %.3e); red-black %d sweeps (last %.3e, res %.3e)"
          % (itSor, dSor, resSor, itRb, dRb, resRb))
    print("  solver diff %.3e" % diffSolvers)
    print("  Tmax %.6f at (%.5f, %.5f), Tmean %.6f" % (Tmax, x[iMax], y[jMax], Tmean))
    print("  Q bottom %.6f top %.6f hole %.6f gen %.6f balance %.3e"
          % (Qbot, Qtop, Qhole, Qgen, Qbalance))
    print("  q max %.6e at (%.5f, %.5f)" % (qf[kq], x[iq + 1], y[jq + 1]))
    print("  wrote", path)


if __name__ == "__main__":
    main()
