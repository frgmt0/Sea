"""Independent NumPy re-implementation of w1_shaft_design.m (cross-check only).

Mirrors the MATLAB script's numerics operation by operation; see ../README.md for the
comparison tolerances. Run: uv run --no-project --with numpy python reference_py/w1_shaft_design.py
"""

import math

import numpy as np

from common import mlinspace, mround, write_reference

NAME = "w1_shaft_design"

CFG = dict(finish="machined", reliability=0.99, nTarget=2.0, lifeTarget=20000)
GEO = dict(L=0.420, a=0.150, rg=0.085, phi=20 * math.pi / 180, mGear=9.5, ripple=0.12,
           rRatio=0.04, Kt=1.90, Kts=1.45, seatRatio=1 / 1.20)
MATS = [
    dict(name="CS-low", Sut=470e6, Sy=380e6, E=205e9, rho=7860),
    dict(name="CS-med", Sut=640e6, Sy=530e6, E=205e9, rho=7850),
    dict(name="AS-QT1", Sut=1030e6, Sy=890e6, E=207e9, rho=7850),
    dict(name="AS-QT2", Sut=1460e6, Sy=1290e6, E=207e9, rho=7840),
]
BRG_BORE = np.array([15, 17, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95,
                     100], dtype=float)
BRG_C = np.array([7.9, 9.7, 12.9, 14.2, 19.8, 25.9, 31.2, 33.9, 35.6, 44.1, 52.8, 56.6, 62.4,
                  67.1, 71.0, 84.0, 96.5, 109.0, 113.5]) * 1e3
BRG_LABEL = ["DG-%03d" % b for b in BRG_BORE.astype(int)]
STD_D = np.array([10, 11.2, 12.5, 14, 16, 18, 20, 22.4, 25, 28, 31.5, 35.5, 40, 45, 50, 56, 63,
                  71, 80, 90, 100, 112, 125, 140, 160, 180, 200, 224, 250, 280])
CASE_LABEL = ["Conveyor drive", "Pump coupling", "Mixer gearbox", "Fan jackshaft", "Winch input"]
CASE_POWER = np.array([7.5, 22, 15, 4, 30]) * 1e3
CASE_RPM = np.array([960, 2900, 420, 1450, 720], dtype=float)
CASE_MAT = [2, 2, 3, 1, 4]
CASE_FINISH = ["machined", "ground", "machined", "hot-rolled", "ground"]


def surface_factor(finish, Sut):
    table = {"ground": (1.58, -0.085), "machined": (4.51, -0.265),
             "hot-rolled": (57.7, -0.718), "as-forged": (272, -0.995)}
    if finish.lower() not in table:
        raise ValueError("unknown surface finish %s" % finish)
    a, b = table[finish.lower()]
    return a * (Sut / 1e6) ** b


def reliability_factor(R):
    table = [(0.50, 1.000), (0.90, 0.897), (0.95, 0.868), (0.99, 0.814), (0.999, 0.753),
             (0.9999, 0.702)]
    for r, k in table:
        if abs(r - R) < 1e-12:
            return k
    raise ValueError("reliability not tabulated")


def make_params(mat, finish, ke):
    p = dict(Sut=mat["Sut"], Sy=mat["Sy"], ka=surface_factor(finish, mat["Sut"]), ke=ke)
    p["SePrime"] = 0.5 * mat["Sut"] if mat["Sut"] <= 1400e6 else 700e6
    p["aPeterson"] = 0.0254e-3 * (2070e6 / mat["Sut"]) ** 1.8
    p["rRatio"] = GEO["rRatio"]
    p["Kt"] = GEO["Kt"]
    p["Kts"] = GEO["Kts"]
    p["ripple"] = GEO["ripple"]
    return p


def shaft_loads(P, rpm):
    omega = 2 * math.pi * rpm / 60
    T = P / omega
    F = T / GEO["rg"] / math.cos(GEO["phi"])
    Mmax = F * GEO["a"] * (GEO["L"] - GEO["a"]) / GEO["L"]
    return T, Mmax, F


def shaft_safety(d, Mmax, T, p):
    """Element-wise; d, Mmax, T may be floats or arrays of one shape."""
    scalar = np.ndim(d) == 0 and np.ndim(Mmax) == 0
    d = np.asarray(d, dtype=float)
    shape = np.broadcast(d, np.asarray(Mmax), np.asarray(T)).shape
    d = np.broadcast_to(d, shape).astype(float)
    Mmax = np.broadcast_to(np.asarray(Mmax, dtype=float), shape)
    T = np.broadcast_to(np.asarray(T, dtype=float), shape)
    dmm = d * 1e3
    kb = np.ones(shape)
    m1 = (dmm > 2.79) & (dmm <= 51)
    kb[m1] = 1.24 * dmm[m1] ** (-0.107)
    m2 = dmm > 51
    kb[m2] = 1.51 * np.minimum(dmm[m2], 254) ** (-0.157)
    Se = p["ka"] * kb * p["ke"] * p["SePrime"]
    r = p["rRatio"] * d
    q = 1 / (1 + p["aPeterson"] / r)
    qs = 1 / (1 + 0.6 * p["aPeterson"] / r)
    Kf = 1 + q * (p["Kt"] - 1)
    Kfs = 1 + qs * (p["Kts"] - 1)
    Ma = Mmax
    Mm = 0.0
    Tm = T
    Ta = p["ripple"] * T
    c16 = 16 / (math.pi * d ** 3)
    alt = np.sqrt(4 * (Kf * Ma) ** 2 + 3 * (Kfs * Ta) ** 2)
    mmean = np.sqrt(4 * (Kf * Mm) ** 2 + 3 * (Kfs * Tm) ** 2)
    nf = 1 / (c16 * (alt / Se + mmean / p["Sut"]))
    sigMax = np.sqrt((32 * Kf * (Mm + Ma) / (math.pi * d ** 3)) ** 2
                     + 3 * (16 * Kfs * (Tm + Ta) / (math.pi * d ** 3)) ** 2)
    ny = p["Sy"] / sigMax
    if scalar:
        return float(nf), float(ny), float(Se), float(Kf), float(Kfs)
    return nf, ny, Se, Kf, Kfs


def shaft_safety_scalar(d, Mmax, T, p):
    """Fast scalar path with the same operation order as shaft_safety."""
    dmm = d * 1e3
    if 2.79 < dmm <= 51:
        kb = 1.24 * dmm ** (-0.107)
    elif dmm > 51:
        kb = 1.51 * min(dmm, 254) ** (-0.157)
    else:
        kb = 1.0
    Se = p["ka"] * kb * p["ke"] * p["SePrime"]
    r = p["rRatio"] * d
    q = 1 / (1 + p["aPeterson"] / r)
    qs = 1 / (1 + 0.6 * p["aPeterson"] / r)
    Kf = 1 + q * (p["Kt"] - 1)
    Kfs = 1 + qs * (p["Kts"] - 1)
    Ta = p["ripple"] * T
    c16 = 16 / (math.pi * d ** 3)
    alt = math.sqrt(4 * (Kf * Mmax) ** 2 + 3 * (Kfs * Ta) ** 2)
    mmean = math.sqrt(4 * (Kf * 0.0) ** 2 + 3 * (Kfs * T) ** 2)
    nf = 1 / (c16 * (alt / Se + mmean / p["Sut"]))
    sigMax = math.sqrt((32 * Kf * (0.0 + Mmax) / (math.pi * d ** 3)) ** 2
                       + 3 * (16 * Kfs * (T + Ta) / (math.pi * d ** 3)) ** 2)
    ny = p["Sy"] / sigMax
    return nf, ny


def bisect_diameter(Mmax, T, p, nTarget, lo, hi, tol):
    nfLo, nyLo = shaft_safety_scalar(lo, Mmax, T, p)
    nfHi, nyHi = shaft_safety_scalar(hi, Mmax, T, p)
    if min(nfLo, nyLo) >= nTarget:
        return lo, 0
    if min(nfHi, nyHi) < nTarget:
        raise ValueError("no diameter reaches target")
    iters = 0
    while hi - lo > tol:
        mid = 0.5 * (lo + hi)
        nfM, nyM = shaft_safety_scalar(mid, Mmax, T, p)
        if min(nfM, nyM) < nTarget:
            lo = mid
        else:
            hi = mid
        iters += 1
    return hi, iters


def critical_speed(d, mat):
    I = math.pi * d ** 4 / 64
    mPerLen = mat["rho"] * math.pi * d ** 2 / 4
    wShaft = (math.pi / GEO["L"]) ** 2 * math.sqrt(mat["E"] * I / mPerLen)
    b = GEO["L"] - GEO["a"]
    kGear = 3 * mat["E"] * I * GEO["L"] / (GEO["a"] ** 2 * b ** 2)
    wGear = math.sqrt(kGear / GEO["mGear"])
    wCrit = 1 / math.sqrt(1 / wShaft ** 2 + 1 / wGear ** 2)
    return wCrit * 60 / (2 * math.pi)


def main():
    surface_factor(CFG["finish"], MATS[0]["Sut"])
    ke = reliability_factor(CFG["reliability"])
    nT = CFG["nTarget"]
    n_case = len(CASE_LABEL)
    keys = ["dReq", "iters", "dStd", "nf", "ny", "Se", "Kf", "Kfs", "torque", "Mmax",
            "critRpm", "R1", "R2", "L10h", "mass"]
    res = {k: np.zeros(n_case) for k in keys}
    bearing = []
    for c in range(n_case):
        mat = MATS[CASE_MAT[c] - 1]
        p = make_params(mat, CASE_FINISH[c], ke)
        T, Mmax, F = shaft_loads(CASE_POWER[c], CASE_RPM[c])
        dReq, iters = bisect_diameter(Mmax, T, p, nT, 0.005, 0.300, 1e-7)
        k = np.nonzero(STD_D >= dReq * 1e3)[0][0]
        dStd = STD_D[k] / 1e3
        nf, ny, Se, Kf, Kfs = shaft_safety(dStd, Mmax, T, p)
        crit = critical_speed(dStd, mat)
        R1 = F * (GEO["L"] - GEO["a"]) / GEO["L"]
        R2 = F * GEO["a"] / GEO["L"]
        dSeat = dStd * GEO["seatRatio"]
        Pbrg = max(R1, R2)
        life = (BRG_C / Pbrg) ** 3 * 1e6 / (60 * CASE_RPM[c])
        ok = np.nonzero((BRG_BORE >= dSeat * 1e3) & (life >= CFG["lifeTarget"]))[0]
        if ok.size == 0:
            bearing.append("none")
            res["L10h"][c] = np.nan
        else:
            bearing.append(BRG_LABEL[ok[0]])
            res["L10h"][c] = mround(life[ok[0]])
        for key, val in zip(["dReq", "iters", "dStd", "nf", "ny", "Se", "Kf", "Kfs", "torque",
                             "Mmax", "critRpm", "R1", "R2"],
                            [dReq, iters, dStd, nf, ny, Se, Kf, Kfs, T, Mmax, crit, R1, R2]):
            res[key][c] = val
        res["mass"][c] = mat["rho"] * math.pi * dStd ** 2 / 4 * GEO["L"]

    dSweep = mlinspace(0.010, 0.080, 2001)
    T1, M1, _ = shaft_loads(CASE_POWER[0], CASE_RPM[0])
    nfCurve = np.zeros((len(MATS), dSweep.size))
    nyCurve = np.zeros((len(MATS), dSweep.size))
    dMinMat = np.zeros(len(MATS))
    for m, mat in enumerate(MATS):
        p = make_params(mat, CFG["finish"], ke)
        nfCurve[m], nyCurve[m], _, _, _ = shaft_safety(dSweep, M1, T1, p)
        ok = np.nonzero(np.minimum(nfCurve[m], nyCurve[m]) >= nT)[0]
        dMinMat[m] = dSweep[ok[0]] if ok.size else np.nan

    gridP = mlinspace(0.5e3, 45e3, 90)
    gridRpm = mlinspace(250, 3600, 120)
    pGrid = make_params(MATS[CASE_MAT[0] - 1], CFG["finish"], ke)
    dGrid = np.zeros((gridP.size, gridRpm.size))
    itGrid = np.zeros_like(dGrid)
    yieldLimited = np.zeros(dGrid.shape, dtype=bool)
    for i in range(gridP.size):
        for j in range(gridRpm.size):
            Tg, Mg, _ = shaft_loads(gridP[i], gridRpm[j])
            dGrid[i, j], itGrid[i, j] = bisect_diameter(Mg, Tg, pGrid, nT, 0.005, 0.300, 1e-7)
            nfg, nyg = shaft_safety_scalar(dGrid[i, j], Mg, Tg, pGrid)
            yieldLimited[i, j] = nyg < nfg

    RPM, PW = np.meshgrid(gridRpm, gridP)
    omegaG = 2 * math.pi * RPM / 60
    TG = PW / omegaG
    FG = TG / GEO["rg"] / math.cos(GEO["phi"])
    MG = FG * GEO["a"] * (GEO["L"] - GEO["a"]) / GEO["L"]
    lo = 0.005 * np.ones(PW.shape)
    hi = 0.300 * np.ones(PW.shape)
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        nfv, nyv, _, _, _ = shaft_safety(mid, MG, TG, pGrid)
        up = np.minimum(nfv, nyv) < nT
        lo[up] = mid[up]
        hi[~up] = mid[~up]
    dGridVec = 0.5 * (lo + hi)
    # MATLAB dGrid(:) is column-major; max over the difference is order independent.
    vecMaxDiff = float(np.max(np.abs(dGridVec - dGrid)))
    colmajor = dGrid.ravel(order="F")
    kMax = int(np.argmax(colmajor))  # first occurrence, as MATLAB max
    kMin = int(np.argmin(colmajor))
    fracYield = np.count_nonzero(yieldLimited) / yieldLimited.size

    ref = dict(workload=NAME, ke=ke, case_label=CASE_LABEL, case_bearing=bearing,
               case_dReq=res["dReq"], case_iters=res["iters"], case_dStd=res["dStd"],
               case_nf=res["nf"], case_ny=res["ny"], case_Se=res["Se"], case_Kf=res["Kf"],
               case_Kfs=res["Kfs"], case_torque=res["torque"], case_Mmax=res["Mmax"],
               case_critRpm=res["critRpm"], case_R1=res["R1"], case_R2=res["R2"],
               case_L10h=res["L10h"], case_mass=res["mass"], sweep_d=dSweep,
               sweep_nf=nfCurve, sweep_ny=nyCurve, mat_dMin=dMinMat, grid_P=gridP,
               grid_rpm=gridRpm, grid_d=dGrid, grid_iters_total=float(itGrid.sum()),
               grid_yield_fraction=fracYield, grid_d_max=colmajor[kMax],
               grid_d_min=colmajor[kMin], grid_vec_maxdiff=vecMaxDiff)
    path = write_reference(NAME, ref)

    print("W1 shaft design (NumPy cross-check)")
    for c in range(n_case):
        print("  %-15s dReq %8.3f mm  dStd %6.1f  it %2d  nf %.3f  ny %.3f  crit %7.0f rpm  %s  L10 %s h"
              % (CASE_LABEL[c], res["dReq"][c] * 1e3, res["dStd"][c] * 1e3, res["iters"][c],
                 res["nf"][c], res["ny"][c], res["critRpm"][c], bearing[c], res["L10h"][c]))
    print("  material dMin [mm]:", np.round(dMinMat * 1e3, 3))
    print("  grid d max %.3f mm, min %.3f mm, yield fraction %.4f, iters %d, vec diff %.3e"
          % (colmajor[kMax] * 1e3, colmajor[kMin] * 1e3, fracYield, itGrid.sum(), vecMaxDiff))
    print("  wrote", path)


if __name__ == "__main__":
    main()
