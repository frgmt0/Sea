"""Independent NumPy re-implementation of w7_drivetrain.m (cross-check only).

Follows the MATLAB script statement by statement: the time-stepping loop, the CVT branches, the
bisection, the parabola vertex and the gear search use Python floats with MATLAB's operation
order, so every discrete decision (region, crossing step, tooth counts, face-width steps,
rejections) is taken on the same values. The only library functions whose last bit may differ
from MATLAB's are interp1 (written out below as y1 + (x - x1)*(y2 - y1)/(x2 - x1)), sin, cos and
the real power; see ../README.md for the comparison tolerances.
Run: uv run --no-project --with numpy python reference_py/w7_drivetrain.py
"""

import bisect
import math

import numpy as np

from common import mlinspace, mround, write_reference

NAME = "w7_drivetrain"

VEH = dict(m=265.0, Cd=0.88, A=1.02, rho=1.17, Crr=0.052, wfRear=0.60, h=0.45, L=1.65,
           rw=0.292, eta=0.88, g=9.81, Jw=1.10, Jd=0.012, Je=0.022, Jf=0.90)
TIRE = dict(muPk=0.72, kPk=0.10, muSl=0.66, kSl=0.80, vRef0=1.0)
ENG = dict(rpm=[1500.0, 1900.0, 2300.0, 2700.0, 3100.0, 3500.0, 3900.0, 4300.0],
           tq=[14.6, 16.9, 18.4, 19.2, 19.3, 18.6, 17.1, 14.8],
           nIdle=1500.0, revRate=7400.0, nGov=3800.0, nCut=3950.0)
CVT = [
    dict(name="Stock", nEngage=1900.0, nStall=2650.0, rLow=2.60, rMin=0.88, kFly=100.0,
         F0=720.0, kSp=190.0, kHx=6.0),
    dict(name="Launch", nEngage=2100.0, nStall=2900.0, rLow=2.90, rMin=0.95, kFly=92.0,
         F0=800.0, kSp=170.0, kHx=7.0),
    dict(name="Overdrive", nEngage=1850.0, nStall=2500.0, rLow=2.40, rMin=0.72, kFly=108.0,
         F0=690.0, kSp=160.0, kHx=5.0),
]
C_SHIFT = 0.01
RUN = dict(dist=45.0, dt=1e-3, tMax=12.0)
CRR_SCALE = [1.0, 0.75, 1.25]
TRACE_EVERY = 20

GD = dict(Ks=1.40, etaStage=0.98, Sall=420.0, FOS=1.5, ratioTol=0.0035, a1Win=(42.0, 90.0),
          a2Win=(60.0, 125.0), Dmax=200.0, Fstep=0.5, kMin=9.0, kMax=14.0)
GD["sLimit"] = GD["Sall"] / GD["FOS"]
PHI_DEG = [20.0, 22.5, 25.0]
MOD1 = [1.5 + 0.25 * k for k in range(9)]      # 1.5:0.25:3.5 (exact in binary)
MOD2 = [2.0 + 0.25 * k for k in range(11)]     # 2.0:0.25:4.5
N_OFFSET = 10
LEWIS_N = [12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 24.0, 26.0, 28.0,
           30.0, 34.0, 38.0, 43.0, 50.0, 60.0, 75.0, 100.0, 150.0, 300.0, 400.0]
LEWIS_Y = [0.245, 0.261, 0.277, 0.290, 0.296, 0.303, 0.309, 0.314, 0.322, 0.328, 0.331, 0.337,
           0.346, 0.353, 0.359, 0.371, 0.384, 0.397, 0.409, 0.422, 0.435, 0.447, 0.460, 0.472,
           0.480]
BL_A_EDGES = [0.0, 50.0, 80.0, 125.0, 200.0]
BL_M_EDGES = [0.0, 2.0, 3.0, 5.0]
BL_MIN = [[0.05, 0.07, 0.09], [0.07, 0.09, 0.12], [0.09, 0.12, 0.15], [0.12, 0.15, 0.19]]
BL_MAX = [[0.11, 0.14, 0.17], [0.14, 0.17, 0.21], [0.17, 0.21, 0.26], [0.21, 0.26, 0.32]]

REG_NAME = ["clutch open", "clutch slip", "low ratio", "shifting", "min ratio", "governor",
            "wheelspin"]


def interp1(xs, ys, x):
    """MATLAB interp1(xs, ys, x) (linear, scalar x); NaN outside [xs(1), xs(end)]."""
    if not (xs[0] <= x <= xs[-1]):
        return math.nan
    j = bisect.bisect_right(xs, x) - 1
    if j >= len(xs) - 1:
        return ys[-1]
    if x == xs[j]:
        return ys[j]
    return ys[j] + (x - xs[j]) * (ys[j + 1] - ys[j]) / (xs[j + 1] - xs[j])


def engine_torque(n, eng):
    """Full-throttle engine torque [N m] at n [rev/min] with the governor; (Te, governed)."""
    if n >= eng["nCut"]:
        return 0.0, True
    elif n > eng["nGov"]:
        return eng["tqGov"] * (eng["nCut"] - n) / (eng["nCut"] - eng["nGov"]), True
    return interp1(eng["rpm"], eng["tq"], n), False


def shift_imbalance(r, nE, Te, c):
    """CVT axial force balance [N]: primary flyweights minus secondary spring and torque helix."""
    return (c["kFly"] * ((nE / 1000) * (nE / 1000)) - c["F0"] - c["kSp"] * (c["rLow"] - r)
            - c["kHx"] * Te * r)


def driveline(wW, r, t, G, c, eng, dt):
    """Wheel drive torque, equivalent inertia, next CVT ratio and region, as in the MATLAB file."""
    nOut = wW * G * 60 / (2 * math.pi)
    nFree = min(eng["nIdle"] + eng["revRate"] * t, c["nStall"])
    nLock = r * nOut
    JwG = VEH["Jw"] + VEH["Jd"] * (G * G)
    if nFree < c["nEngage"]:
        return 0.0, JwG, r, 1
    elif nLock < nFree:
        Te, _ = engine_torque(nFree, eng)
        return VEH["eta"] * r * G * Te, JwG, r, 2
    Te, gov = engine_torque(nLock, eng)
    rNew = r - dt * C_SHIFT * shift_imbalance(r, nLock, Te, c)
    if rNew > c["rLow"]:
        rNew = c["rLow"]
    elif rNew < c["rMin"]:
        rNew = c["rMin"]
    rDot = (rNew - r) / dt
    rG = r * G
    Td = VEH["eta"] * rG * (Te - VEH["Je"] * G * rDot * wW)
    Jeq = JwG + VEH["eta"] * VEH["Je"] * (rG * rG)
    if gov:
        reg = 6
    elif r == c["rLow"]:
        reg = 3
    elif r == c["rMin"]:
        reg = 5
    else:
        reg = 4
    return Td, Jeq, rNew, reg


def slip_curve(kappa):
    """Piecewise-linear friction coefficient mu(kappa), odd in kappa, and d mu / d kappa."""
    s = abs(kappa)
    if s <= TIRE["kPk"]:
        mu = TIRE["muPk"] * s / TIRE["kPk"]
        dmu = TIRE["muPk"] / TIRE["kPk"]
    elif s < TIRE["kSl"]:
        dmu = -(TIRE["muPk"] - TIRE["muSl"]) / (TIRE["kSl"] - TIRE["kPk"])
        mu = TIRE["muPk"] + dmu * (s - TIRE["kPk"])
    else:
        mu = TIRE["muSl"]
        dmu = 0.0
    if kappa < 0:
        mu = -mu
    return mu, dmu


def road_load(v, crr):
    return crr * VEH["m"] * VEH["g"] + 0.5 * VEH["rho"] * VEH["Cd"] * VEH["A"] * (v * v)


def accel_run(G, c, eng, crr, record):
    """One run; returns (tCross, vCross, k, regSteps, vTrace, tShift)."""
    dt = RUN["dt"]
    dist = RUN["dist"]
    m = VEH["m"]
    mv = m + VEH["Jf"] / (VEH["rw"] * VEH["rw"])
    Nstat = m * VEH["g"] * VEH["wfRear"]
    Nmax = m * VEH["g"]
    kTr = m * VEH["h"] / VEH["L"]
    nMax = int(mround(RUN["tMax"] / dt))
    reg_steps = [0] * 7
    trace = []
    v = 0.0; x = 0.0; wW = 0.0; r = c["rLow"]; aPrev = 0.0; k = 0
    vPrev = 0.0; xPrev = 0.0
    tShift = math.nan
    while x < dist and k < nMax:
        t = k * dt
        Td, Jeq, rNew, reg = driveline(wW, r, t, G, c, eng, dt)
        reg_steps[reg - 1] += 1
        if rNew < c["rLow"] and math.isnan(tShift):
            tShift = t
        Nr = Nstat + kTr * aPrev
        if Nr > Nmax:
            Nr = Nmax
        elif Nr < 0:
            Nr = 0.0
        vRef = max(v, TIRE["vRef0"])
        kappa = (wW * VEH["rw"] - v) / vRef
        mu, dmu = slip_curve(kappa)
        if kappa > TIRE["kPk"]:
            reg_steps[6] += 1
        Fx = mu * Nr
        dFdw = dmu * Nr * VEH["rw"] / vRef
        wNew = wW + dt * (Td - Fx * VEH["rw"]) / (Jeq + dt * VEH["rw"] * dFdw)
        if wNew < 0:
            wNew = 0.0
        Fx = Fx + dFdw * (wNew - wW)
        vPrev = v; xPrev = x
        v = v + dt * (Fx - road_load(v, crr)) / mv
        if v < 0:
            v = 0.0
        aPrev = (v - vPrev) / dt
        x = x + v * dt
        wW = wNew
        r = rNew
        k = k + 1
        if record:
            trace.append(v)
    if x >= dist:
        frac = (dist - xPrev) / (x - xPrev)
        tCross = (k - 1) * dt + frac * dt
        vCross = vPrev + frac * (v - vPrev)
    else:
        tCross = math.nan
        vCross = math.nan
    return tCross, vCross, k, reg_steps, trace, tShift


def steady_ratio(nOut, c, eng):
    """Equilibrium CVT ratio at output speed nOut [rev/min] (bisection on the force balance)."""
    nE = c["rLow"] * nOut
    Te, _ = engine_torque(nE, eng)
    if shift_imbalance(c["rLow"], nE, Te, c) <= 0:
        return c["rLow"]
    nE = c["rMin"] * nOut
    Te, _ = engine_torque(nE, eng)
    if shift_imbalance(c["rMin"], nE, Te, c) >= 0:
        return c["rMin"]
    a = c["rMin"]
    b = c["rLow"]
    while b - a > 1e-9:
        mid = 0.5 * (a + b)
        nE = mid * nOut
        Te, _ = engine_torque(nE, eng)
        if shift_imbalance(mid, nE, Te, c) > 0:
            b = mid
        else:
            a = mid
    return 0.5 * (a + b)


def steady_force(v, G, c, eng, crr):
    """Steady-state drive force [N] at speed v: tire slip from the road load, CVT at balance."""
    Nr = VEH["m"] * VEH["g"] * VEH["wfRear"]
    kappa = road_load(v, crr) / Nr * TIRE["kPk"] / TIRE["muPk"]
    wW = (v + kappa * max(v, TIRE["vRef0"])) / VEH["rw"]
    nOut = wW * G * 60 / (2 * math.pi)
    if c["rLow"] * nOut < c["nStall"]:
        Te, _ = engine_torque(c["nStall"], eng)
        return Te * c["rLow"] * G * VEH["eta"] / VEH["rw"]
    r = steady_ratio(nOut, c, eng)
    Te, _ = engine_torque(r * nOut, eng)
    return Te * r * G * VEH["eta"] / VEH["rw"]


def top_speed(G, c, eng, crr):
    lo = 0.5
    hi = 45.0
    if (steady_force(lo, G, c, eng, crr) - road_load(lo, crr) <= 0
            or steady_force(hi, G, c, eng, crr) - road_load(hi, crr) >= 0):
        raise ValueError("top speed for G = %.3f is not bracketed" % G)
    iters = 0
    while hi - lo > 1e-6:
        mid = 0.5 * (lo + hi)
        if steady_force(mid, G, c, eng, crr) - road_load(mid, crr) > 0:
            lo = mid
        else:
            hi = mid
        iters += 1
    return 0.5 * (lo + hi), iters


def first_min(y):
    """MATLAB [m, i] = min(y): first minimum, NaN ignored; i is 0-based here."""
    best = math.nan
    ib = 0
    for i, val in enumerate(y):
        if not math.isnan(val) and (math.isnan(best) or val < best):
            best = val
            ib = i
    return best, ib


def refine_min(x, y, i):
    """Parabola vertex through i-1, i, i+1 (0-based i)."""
    if 0 < i < len(x) - 1:
        x1, x2, x3 = x[i - 1], x[i], x[i + 1]
        y1, y2, y3 = y[i - 1], y[i], y[i + 1]
        num = (x2 - x1) * (x2 - x1) * (y2 - y3) - (x2 - x3) * (x2 - x3) * (y2 - y1)
        den = (x2 - x1) * (y2 - y3) - (x2 - x3) * (y2 - y1)
        return x2 - 0.5 * num / den
    return x[i]


def size_face(T, n, m, Np, Y):
    d = m * Np
    Wt = 2 * T / d
    V = math.pi * d * n / 60000
    Kv = (6.1 + V) / 6.1
    F = GD["kMin"] * m
    sigma = Kv * Wt / (F * m * Y)
    ok = True
    while sigma > GD["sLimit"]:
        F = F + GD["Fstep"]
        if F > GD["kMax"] * m:
            ok = False
            break
        sigma = Kv * Wt / (F * m * Y)
    return ok, F, sigma


def main():
    eng = dict(ENG)
    eng["tqGov"] = interp1(eng["rpm"], eng["tq"], eng["nGov"])
    G_sweep = mlinspace(6, 15, 46).tolist()
    split = mlinspace(0.40, 0.60, 11).tolist()

    # ---------------------------------------------------------------- part A
    nCfg, nG, nCrr = len(CVT), len(G_sweep), len(CRR_SCALE)
    tDist = np.zeros((nCfg, nG, nCrr))
    vTrap = np.zeros((nCfg, nG, nCrr))
    nSteps = np.zeros((nCfg, nG, nCrr))
    vTop = np.zeros((nCfg, nG))
    topIters = np.zeros((nCfg, nG))
    for c in range(nCfg):
        for s in range(nCrr):
            crr = VEH["Crr"] * CRR_SCALE[s]
            for i in range(nG):
                t_, v_, k_, _, _, _ = accel_run(G_sweep[i], CVT[c], eng, crr, False)
                tDist[c, i, s] = t_
                vTrap[c, i, s] = v_
                nSteps[c, i, s] = k_
        for i in range(nG):
            vTop[c, i], topIters[c, i] = top_speed(G_sweep[i], CVT[c], eng, VEH["Crr"])
    totalSteps = int(nSteps.sum())

    iBest = np.zeros((nCfg, nCrr), dtype=int)       # 0-based
    tBest = np.zeros((nCfg, nCrr))
    Gbest = np.zeros((nCfg, nCrr))
    for c in range(nCfg):
        for s in range(nCrr):
            row = tDist[c, :, s].tolist()
            tBest[c, s], iBest[c, s] = first_min(row)
            Gbest[c, s] = refine_min(G_sweep, row, iBest[c, s])

    regBest = np.zeros((nCfg, 7))
    tShift = np.zeros(nCfg)
    traceStock = None
    for c in range(nCfg):
        _, _, _, reg, tr, ts = accel_run(G_sweep[iBest[c, 0]], CVT[c], eng, VEH["Crr"], True)
        regBest[c, :] = reg
        tShift[c] = ts
        if c == 0:
            traceStock = np.array(tr)

    # ---------------------------------------------------------------- part B
    _, cfgPick = first_min(tBest[:, 0].tolist())
    Gtarget = mround(100 * Gbest[cfgPick, 0]) / 100
    Tin = max(eng["tq"]) * CVT[cfgPick]["rLow"] * GD["Ks"] * 1000
    cp = CVT[cfgPick]
    nIn = 1000 * math.sqrt((cp["F0"] + cp["kHx"] * max(eng["tq"]) * cp["rLow"]) / cp["kFly"]) / cp["rLow"]
    phi20 = 20 * math.pi / 180
    tan20 = math.sin(phi20) / math.cos(phi20)

    nPhi = len(PHI_DEG)
    nMin = [0] * nPhi
    yScale = [0.0] * nPhi
    nCand = nDup = nRejRatio = nRejGeom = nRejStress = 0
    fe = {k: [] for k in ["phi", "m1", "m2", "split", "Np1", "Ng1", "Np2", "Ng2", "F1", "F2",
                          "a1", "a2", "err", "s1", "s2", "mass"]}
    tol = GD["ratioTol"]
    for ip in range(nPhi):
        phi = PHI_DEG[ip] * math.pi / 180
        sp = math.sin(phi)
        nMin[ip] = math.ceil(2 / (sp * sp))
        yScale[ip] = ((sp / math.cos(phi)) / tan20) ** 0.45
        for m1 in MOD1:
            for m2 in MOD2:
                for o1 in range(N_OFFSET):
                    Np1 = nMin[ip] + o1
                    Y1 = interp1(LEWIS_N, LEWIS_Y, float(Np1)) * yScale[ip]
                    for o2 in range(N_OFFSET):
                        Np2 = nMin[ip] + o2
                        Y2 = interp1(LEWIS_N, LEWIS_Y, float(Np2)) * yScale[ip]
                        prevNg1 = -1; prevNg2 = -1
                        for sx in split:
                            nCand += 1
                            base = mround(Np1 * Gtarget ** sx)
                            ok = False
                            for dN in (0, -1, 1):
                                Ng1 = base + dN
                                Ng2 = mround(Np2 * Gtarget * Np1 / Ng1)
                                err = Ng1 * Ng2 / (Np1 * Np2) / Gtarget - 1
                                if abs(err) <= tol:
                                    ok = True
                                    break
                            if not ok:
                                nRejRatio += 1
                                continue
                            if Ng1 == prevNg1 and Ng2 == prevNg2:
                                nDup += 1
                                continue
                            prevNg1 = Ng1; prevNg2 = Ng2
                            a1 = m1 * (Np1 + Ng1) / 2
                            a2 = m2 * (Np2 + Ng2) / 2
                            if (a1 < GD["a1Win"][0] or a1 > GD["a1Win"][1] or a2 < GD["a2Win"][0]
                                    or a2 > GD["a2Win"][1] or m1 * (Ng1 + 2) > GD["Dmax"]
                                    or m2 * (Ng2 + 2) > GD["Dmax"]):
                                nRejGeom += 1
                                continue
                            ok1, F1, s1 = size_face(Tin, nIn, m1, Np1, Y1)
                            if not ok1:
                                nRejStress += 1
                                continue
                            ok2, F2, s2 = size_face(Tin * Ng1 / Np1 * GD["etaStage"],
                                                    nIn * Np1 / Ng1, m2, Np2, Y2)
                            if not ok2:
                                nRejStress += 1
                                continue
                            dp1 = m1 * Np1; dg1 = m1 * Ng1; dp2 = m2 * Np2; dg2 = m2 * Ng2
                            vol = math.pi / 4 * (F1 * (dp1 * dp1 + dg1 * dg1)
                                                 + F2 * (dp2 * dp2 + dg2 * dg2)) / 1000
                            for key, val in (("phi", PHI_DEG[ip]), ("m1", m1), ("m2", m2),
                                             ("split", sx), ("Np1", Np1), ("Ng1", Ng1),
                                             ("Np2", Np2), ("Ng2", Ng2), ("F1", F1), ("F2", F2),
                                             ("a1", a1), ("a2", a2), ("err", err), ("s1", s1),
                                             ("s2", s2), ("mass", vol)):
                                fe[key].append(val)
    fe = {k: np.array(v, dtype=float) for k, v in fe.items()}
    nFeas = fe["mass"].size
    if nFeas == 0:
        raise ValueError("no feasible gear design")
    order = np.argsort(fe["mass"], kind="stable")
    massSorted = fe["mass"][order]
    nTop = min(10, nFeas)
    top = order[:nTop]
    feasPerPhi = [int(np.count_nonzero(fe["phi"] == p)) for p in PHI_DEG]
    b = top[0]

    # ---------------------------------------------------------------- part C
    blA = [fe["a1"][b], fe["a2"][b]]
    blM = [fe["m1"][b], fe["m2"][b]]
    blBandA = [0, 0]; blBandM = [0, 0]; blMin = [0.0, 0.0]; blMax = [0.0, 0.0]
    for k in range(2):
        if blA[k] >= BL_A_EDGES[-1] or blM[k] >= BL_M_EDGES[-1]:
            raise ValueError("stage %d is outside the backlash table" % (k + 1))
        blBandA[k] = max(j for j in range(len(BL_A_EDGES) - 1) if blA[k] >= BL_A_EDGES[j]) + 1
        blBandM[k] = max(j for j in range(len(BL_M_EDGES) - 1) if blM[k] >= BL_M_EDGES[j]) + 1
        blMin[k] = BL_MIN[blBandA[k] - 1][blBandM[k] - 1]
        blMax[k] = BL_MAX[blBandA[k] - 1][blBandM[k] - 1]

    ref = dict(
        workload=NAME, cfg_name=[c["name"] for c in CVT], G=np.array(G_sweep),
        t_dist=tDist[:, :, 0], t_dist_lo=tDist[:, :, 1], t_dist_hi=tDist[:, :, 2],
        v_trap=vTrap[:, :, 0], v_trap_lo=vTrap[:, :, 1], v_trap_hi=vTrap[:, :, 2],
        steps=nSteps[:, :, 0], steps_lo=nSteps[:, :, 1], steps_hi=nSteps[:, :, 2],
        total_steps=totalSteps, v_top=vTop, top_iters=topIters,
        i_best=iBest[:, 0] + 1, i_best_lo=iBest[:, 1] + 1, i_best_hi=iBest[:, 2] + 1,
        t_best=tBest[:, 0], t_best_lo=tBest[:, 1], t_best_hi=tBest[:, 2],
        G_best=Gbest[:, 0], G_best_lo=Gbest[:, 1], G_best_hi=Gbest[:, 2],
        region_steps=regBest, t_shift=tShift, trace_v=traceStock[TRACE_EVERY - 1::TRACE_EVERY],
        cfg_pick=cfgPick + 1, G_target=Gtarget, n_min=nMin, y_scale=yScale,
        n_cand=nCand, n_dup=nDup, n_rej_ratio=nRejRatio, n_rej_geom=nRejGeom,
        n_rej_stress=nRejStress, n_feasible=nFeas, feasible_per_phi=feasPerPhi,
        mass_sorted=massSorted,
        top_phi=fe["phi"][top], top_m1=fe["m1"][top], top_m2=fe["m2"][top],
        top_split=fe["split"][top], top_Np1=fe["Np1"][top], top_Ng1=fe["Ng1"][top],
        top_Np2=fe["Np2"][top], top_Ng2=fe["Ng2"][top], top_F1=fe["F1"][top],
        top_F2=fe["F2"][top], top_a1=fe["a1"][top], top_a2=fe["a2"][top],
        top_err=fe["err"][top], top_s1=fe["s1"][top], top_s2=fe["s2"][top],
        top_mass=fe["mass"][top],
        backlash_band_a=blBandA, backlash_band_m=blBandM, backlash_min=blMin,
        backlash_max=blMax)
    path = write_reference(NAME, ref)

    print("W7 drivetrain (NumPy cross-check)")
    print("  %d runs, %d integration steps; time to %.0f m from %.4f to %.4f s"
          % (nCfg * nG * nCrr, totalSteps, RUN["dist"], np.nanmin(tDist), np.nanmax(tDist)))
    for c in range(nCfg):
        print("  %-10s grid best G %.2f t %.4f s, refined G* %.4f (Crr-25%% %.4f, +25%% %.4f), "
              "top speed %.3f..%.3f m/s"
              % (CVT[c]["name"], G_sweep[iBest[c, 0]], tBest[c, 0], Gbest[c, 0], Gbest[c, 1],
                 Gbest[c, 2], vTop[c].min(), vTop[c].max()))
        print("    region steps:", " ".join("%s %d" % (REG_NAME[k], regBest[c, k])
                                            for k in range(7)))
    print("  gear target %.2f (%s CVT), candidates %d, ratio rejects %d, repeats %d, "
          "geometry rejects %d, stress rejects %d, feasible %d %s"
          % (Gtarget, CVT[cfgPick]["name"], nCand, nRejRatio, nDup, nRejGeom, nRejStress,
             nFeas, feasPerPhi))
    for r in range(nTop):
        k = top[r]
        print("  %2d phi %4.1f m %.2f/%.2f split %.2f teeth %d/%d %d/%d F %.1f/%.1f "
              "a %.2f/%.2f err %+.4f%% s %.1f/%.1f vol %.2f cm3"
              % (r + 1, fe["phi"][k], fe["m1"][k], fe["m2"][k], fe["split"][k], fe["Np1"][k],
                 fe["Ng1"][k], fe["Np2"][k], fe["Ng2"][k], fe["F1"][k], fe["F2"][k],
                 fe["a1"][k], fe["a2"][k], 100 * fe["err"][k], fe["s1"][k], fe["s2"][k],
                 fe["mass"][k]))
    print("  backlash bands a %s m %s, min %s max %s mm" % (blBandA, blBandM, blMin, blMax))
    print("  wrote", path)


if __name__ == "__main__":
    main()
