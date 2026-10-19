"""Independent NumPy re-implementation of w3_quarter_car.m (cross-check only).

The RK4 inner loop uses Python floats with the same operation order as the MATLAB vector
expressions (x + (dt/2)*k1, x + (dt/6)*(((k1 + 2*k2) + 2*k3) + k4)), so trajectories agree
to rounding. All forces are continuous across the branch points (damper sign change, bump
stop contact, tire lift-off), so rounding differences do not get amplified.
"""

import math

import numpy as np

from common import mlinspace, mround, write_reference

NAME = "w3_quarter_car"

ms, mu, ks, kt, ct = 380.0, 42.0, 24e3, 210e3, 60.0
rebRatio, gap, kbs, kbs3 = 1.6, 0.065, 180e3, 4e7
g = 9.81
Wtot = (ms + mu) * g
speed, dt, tEnd = 16.0, 1e-3, 8.0
bumpX0, bumpL, bumpH = 4.0, 0.6, 0.07
nWave, nLo, nHi, Gd0, n0 = 60, 0.05, 3.0, 256e-6, 0.1
rampT, seed, rmsStart = 1.0, 20240917, 1.0
kRef = 8


def qc_deriv(zs, zu, vs, vu, zr, vr, c):
    vrel = vs - vu
    cdamp = c * rebRatio if vrel > 0 else c
    Fsusp = -ks * (zs - zu) - cdamp * vrel
    dc = zu - zs - gap
    Fbs = 0.0
    if dc > 0:
        Fbs = kbs * dc + kbs3 * (dc * dc * dc)
    Fsusp = Fsusp + Fbs
    Ft = Wtot + kt * (zr - zu) + ct * (vr - vu)
    if Ft < 0:
        Ft = 0.0
    return vs, vu, Fsusp / ms, (-Fsusp + Ft - Wtot) / mu, Ft, Fbs


def simulate(c, zr, vr, nStep):
    zr = zr.tolist()
    vr = vr.tolist()
    Y = np.zeros((4, nStep + 1))
    acc = np.zeros(nStep + 1)
    Ft = np.zeros(nStep + 1)
    bsOn = np.zeros(nStep + 1, dtype=bool)
    x0 = x1 = x2 = x3 = 0.0
    h2 = dt / 2
    h6 = dt / 6
    Yl = [[0.0] * (nStep + 1) for _ in range(4)]
    accl = [0.0] * (nStep + 1)
    Ftl = [0.0] * (nStep + 1)
    bsl = [False] * (nStep + 1)
    for k in range(nStep):
        j = 2 * k
        a0, a1, a2, a3, ft, fbs = qc_deriv(x0, x1, x2, x3, zr[j], vr[j], c)
        b0, b1, b2, b3, _, _ = qc_deriv(x0 + h2 * a0, x1 + h2 * a1, x2 + h2 * a2,
                                        x3 + h2 * a3, zr[j + 1], vr[j + 1], c)
        c0, c1, c2, c3, _, _ = qc_deriv(x0 + h2 * b0, x1 + h2 * b1, x2 + h2 * b2,
                                        x3 + h2 * b3, zr[j + 1], vr[j + 1], c)
        d0, d1, d2, d3, _, _ = qc_deriv(x0 + dt * c0, x1 + dt * c1, x2 + dt * c2,
                                        x3 + dt * c3, zr[j + 2], vr[j + 2], c)
        Yl[0][k] = x0; Yl[1][k] = x1; Yl[2][k] = x2; Yl[3][k] = x3
        accl[k] = a2
        Ftl[k] = ft
        bsl[k] = fbs > 0
        x0 = x0 + h6 * (a0 + 2 * b0 + 2 * c0 + d0)
        x1 = x1 + h6 * (a1 + 2 * b1 + 2 * c1 + d1)
        x2 = x2 + h6 * (a2 + 2 * b2 + 2 * c2 + d2)
        x3 = x3 + h6 * (a3 + 2 * b3 + 2 * c3 + d3)
    e0, e1, e2, e3, ft, fbs = qc_deriv(x0, x1, x2, x3, zr[2 * nStep], vr[2 * nStep], c)
    Yl[0][nStep] = x0; Yl[1][nStep] = x1; Yl[2][nStep] = x2; Yl[3][nStep] = x3
    accl[nStep] = e2
    Ftl[nStep] = ft
    bsl[nStep] = fbs > 0
    Y[:] = np.array(Yl)
    acc[:] = accl
    Ft[:] = Ftl
    bsOn[:] = bsl
    return Y, acc, Ft, bsOn


def main():
    nStep = int(mround(tEnd / dt))
    t = np.arange(nStep + 1) * dt
    th = np.arange(2 * nStep + 1) * (dt / 2)
    xh = speed * th

    zBump = np.zeros(th.size)
    vBump = np.zeros(th.size)
    inB = (xh >= bumpX0) & (xh <= bumpX0 + bumpL)
    arg = 2 * math.pi * (xh[inB] - bumpX0) / bumpL
    zBump[inB] = bumpH / 2 * (1 - np.cos(arg))
    vBump[inB] = bumpH / 2 * np.sin(arg) * (2 * math.pi * speed / bumpL)

    nk = mlinspace(nLo, nHi, nWave)
    dn = (nHi - nLo) / (nWave - 1)
    Ak = np.sqrt(2 * Gd0 * (nk / n0) ** (-2) * dn)
    phik = np.zeros(nWave)
    s = float(seed)
    for k in range(nWave):
        s = math.fmod(16807 * s, 2147483647.0)
        phik[k] = 2 * math.pi * s / 2147483647
    argR = np.outer(2 * math.pi * xh, nk) + phik
    zRough0 = np.sin(argR) @ Ak
    vRough0 = (np.cos(argR) * (2 * math.pi * speed * nk)) @ Ak
    ramp = np.minimum(th / rampT, 1)
    rampD = (th < rampT).astype(float) / rampT
    zRough = ramp * zRough0
    vRough = ramp * vRough0 + rampD * zRough0

    Mlin = np.array([[ms, 0], [0, mu]])
    Klin = np.array([[ks, -ks], [-ks, ks + kt]])
    lam = np.sort(np.linalg.eigvals(np.linalg.solve(Mlin, Klin)).real)
    fNat = np.sqrt(lam) / (2 * math.pi)
    cSweep = mlinspace(500, 6300, 30)
    zeta = cSweep / (2 * math.sqrt(ks * ms))

    nC = cSweep.size
    out = {k: np.zeros(nC) for k in ["peakAcc", "maxComp", "maxExt", "peakTire", "settle",
                                     "overshoot", "liftBump", "rmsAcc", "rmsTire", "liftFrac", "bsFrac",
                                     "travelRough"]}
    tBump = bumpX0 / speed
    iRms = t >= rmsStart
    for ic in range(nC):
        c = cSweep[ic]
        Y, acc, Ft, _ = simulate(c, zBump, vBump, nStep)
        zs, zu = Y[0], Y[1]
        out["peakAcc"][ic] = np.max(np.abs(acc))
        out["maxComp"][ic] = np.max(zu - zs)
        out["maxExt"][ic] = np.max(zs - zu)
        out["peakTire"][ic] = np.max(Ft) / Wtot
        out["liftBump"][ic] = np.count_nonzero(Ft == 0) * dt
        out["overshoot"][ic] = np.max(zs) / bumpH
        band = 0.02 * np.max(np.abs(zs))
        idx = np.nonzero(np.abs(zs) > band)[0]
        if idx.size == 0 or idx[-1] == zs.size - 1:
            out["settle"][ic] = np.nan
        else:
            out["settle"][ic] = t[idx[-1] + 1] - tBump
        if ic == kRef - 1:
            refZs, refAcc, refFt = zs.copy(), acc.copy(), Ft.copy()
        Y, acc, Ft, bsOn = simulate(c, zRough, vRough, nStep)
        out["rmsAcc"][ic] = math.sqrt(np.mean(acc[iRms] ** 2))
        out["rmsTire"][ic] = math.sqrt(np.mean(((Ft[iRms] - Wtot) / Wtot) ** 2))
        out["liftFrac"][ic] = np.count_nonzero(Ft[iRms] == 0) / np.count_nonzero(iRms)
        out["bsFrac"][ic] = np.count_nonzero(bsOn[iRms]) / np.count_nonzero(iRms)
        out["travelRough"][ic] = np.max(np.abs(Y[0, iRms] - Y[1, iRms]))
        if ic == kRef - 1:
            refRoughAcc = acc.copy()

    J = out["rmsAcc"] / out["rmsAcc"].min() + out["rmsTire"] / out["rmsTire"].min()
    iBest = int(np.argmin(J))
    if 0 < iBest < nC - 1:
        c3 = cSweep[iBest - 1:iBest + 2]
        J3 = J[iBest - 1:iBest + 2]
        coef = np.linalg.solve(np.column_stack([c3 ** 2, c3, np.ones(3)]), J3)
        cBest = -coef[1] / (2 * coef[0])
    else:
        cBest = cSweep[iBest]

    ref = dict(workload=NAME, f_nat=fNat, road_phase=phik, road_amp=Ak,
               road_rough=zRough[0::2], c=cSweep, zeta=zeta, peak_acc=out["peakAcc"],
               max_comp=out["maxComp"], max_ext=out["maxExt"], peak_tire=out["peakTire"],
               overshoot=out["overshoot"], settle=out["settle"], rms_acc=out["rmsAcc"],
               rms_tire=out["rmsTire"], lift_time_bump=out["liftBump"], lift_frac=out["liftFrac"],
               bumpstop_frac=out["bsFrac"], travel_rough=out["travelRough"], J=J,
               i_best=iBest + 1, c_best=cBest, k_ref=kRef, ref_zs=refZs, ref_acc=refAcc,
               ref_tire=refFt, ref_rough_acc=refRoughAcc)
    path = write_reference(NAME, ref)
    print("W3 quarter car (NumPy cross-check)")
    print("  natural frequencies [Hz]:", fNat)
    for ic in range(nC):
        print("  c %7.1f zeta %.3f peakAcc %8.4f comp %6.2f ext %6.2f tire %.3f settle %6.3f "
              "rmsAcc %.5f rmsTire %.5f lift %.3f%% bs %.3f%% J %.4f"
              % (cSweep[ic], zeta[ic], out["peakAcc"][ic], out["maxComp"][ic] * 1e3,
                 out["maxExt"][ic] * 1e3, out["peakTire"][ic], out["settle"][ic],
                 out["rmsAcc"][ic], out["rmsTire"][ic], 100 * out["liftFrac"][ic],
                 100 * out["bsFrac"][ic], J[ic]))
    print("  bump-run lift time max %.3f s" % out["liftBump"].max())
    print("  best grid c %.1f, refined c* %.1f" % (cSweep[iBest], cBest))
    print("  wrote", path)


if __name__ == "__main__":
    main()
