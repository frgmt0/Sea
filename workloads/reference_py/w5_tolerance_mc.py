"""Independent NumPy re-implementation of w5_tolerance_mc.m (cross-check only).

The Park-Miller LCG is exact in double precision, so the uniform stream (and lcg_final) is
bit-identical to MATLAB. Box-Muller uses log/cos, where MATLAB's and NumPy's math libraries
may differ in the last bit; integer counts (histogram, rejects) can therefore differ only if a
sample lands within ~1e-16 of a bin edge or limit (see ../README.md).
"""

import math

import numpy as np

from common import ParkMiller, mlinspace, prctile_mid, write_reference

NAME = "w5_tolerance_mc"

DIMS = [
    ("housing depth", 84.00, 0.050, "normal", +1, 23.1e-6),
    ("gasket", 0.25, 0.040, "triangular", +1, 80e-6),
    ("bearing 1", 19.00, 0.012, "normal", -1, 11.5e-6),
    ("spacer", 24.75, 0.030, "uniform", -1, 11.5e-6),
    ("gear hub", 22.00, 0.040, "triangular", -1, 11.5e-6),
    ("bearing 2", 17.00, 0.012, "normal", -1, 11.5e-6),
    ("retaining ring", 1.20, 0.030, "uniform", -1, 12.0e-6),
]
nSample, seed = 1000000, 7340117
Tref, Tlo, Thi = 20.0, 20.0, 95.0
LSL, USL, hotMax = 0.20, 0.42, 0.45
histLo, histHi, nBin = 0.0, 0.6, 60
pct = [0.135, 2.5, 50, 97.5, 99.865]
yieldTarget = 0.9973


def stack_gap(dev, k, nom, sgn, alpha, Top):
    n = dev.shape[0]
    gc = np.zeros(n)
    gh = np.zeros(n)
    dT = Top - Tref
    for d in range(len(nom)):
        ln = nom[d] + k * dev[:, d]
        gc = gc + sgn[d] * ln
        gh = gh + sgn[d] * (ln * (1 + alpha[d] * dT))
    return gc, gh


def main():
    nDim = len(DIMS)
    nom = np.array([d[1] for d in DIMS])
    tol = np.array([d[2] for d in DIMS])
    sgn = np.array([float(d[4]) for d in DIMS])
    alpha = np.array([d[5] for d in DIMS])

    nomGap, wcHalf, rssVar = 0.0, 0.0, 0.0
    for name, nm, tl, dist, sg, al in DIMS:
        nomGap = nomGap + sg * nm
        wcHalf = wcHalf + tl
        sig = {"normal": tl / 3, "uniform": tl / math.sqrt(3),
               "triangular": tl / math.sqrt(6)}[dist]
        rssVar = rssVar + sig ** 2
    rssSigma = math.sqrt(rssVar)

    rng = ParkMiller(seed)
    dev = np.zeros((nSample, nDim))
    for d, (name, nm, tl, dist, sg, al) in enumerate(DIMS):
        if dist == "normal":
            u = rng.fill(2 * nSample)
            u1, u2 = u[0::2], u[1::2]
            z = np.sqrt(-2 * np.log(u1)) * np.cos(2 * math.pi * u2)
            dev[:, d] = z * (tl / 3)
        elif dist == "uniform":
            u = rng.fill(nSample)
            dev[:, d] = tl * (2 * u - 1)
        elif dist == "triangular":
            u = rng.fill(nSample)
            low = u < 0.5
            v = np.zeros(nSample)
            v[low] = -tl + tl * np.sqrt(2 * u[low])
            v[~low] = tl - tl * np.sqrt(2 * (1 - u[~low]))
            dev[:, d] = v
        else:
            raise ValueError(dist)
    u = rng.fill(nSample)
    Top = Tlo + (Thi - Tlo) * u
    lcgFinal = rng.s

    gapCold, gapHot = stack_gap(dev, 1.0, nom, sgn, alpha, Top)
    muC, sdC = gapCold.mean(), gapCold.std(ddof=1)
    muH, sdH = gapHot.mean(), gapHot.std(ddof=1)
    cpk = min(USL - muC, muC - LSL) / (3 * sdC)
    nLow = int(np.sum(gapCold < LSL))
    nHigh = int(np.sum(gapCold > USL))
    nHot = int(np.sum(gapHot > hotMax))
    passed = (gapCold >= LSL) & (gapCold <= USL) & (gapHot <= hotMax)
    yieldMC = np.count_nonzero(passed) / nSample

    binW = (histHi - histLo) / nBin
    idx = np.floor((gapCold - histLo) / binW) + 1
    inRange = (idx >= 1) & (idx <= nBin)
    counts = np.bincount(idx[inRange].astype(int) - 1, minlength=nBin)
    underflow = int(np.sum(idx < 1))
    overflow = int(np.sum(idx > nBin))

    sortedC = np.sort(gapCold)
    sortedH = np.sort(gapHot)
    pC = [prctile_mid(sortedC, p) for p in pct]
    pH = [prctile_mid(sortedH, p) for p in pct]

    contrib = np.array([dev[:, d].var(ddof=1) / gapCold.var(ddof=1) for d in range(nDim)])
    rank = np.argsort(-contrib, kind="stable") + 1

    scale = mlinspace(0.4, 1.6, 25)
    yieldScale = np.zeros(scale.size)
    cpkScale = np.zeros(scale.size)
    for k in range(scale.size):
        gc, gh = stack_gap(dev, scale[k], nom, sgn, alpha, Top)
        ok = (gc >= LSL) & (gc <= USL) & (gh <= hotMax)
        yieldScale[k] = np.count_nonzero(ok) / nSample
        m = gc.mean()
        cpkScale[k] = min(USL - m, m - LSL) / (3 * gc.std(ddof=1))
    okIdx = np.nonzero(yieldScale >= yieldTarget)[0]
    scaleMax = scale[okIdx[-1]] if okIdx.size else np.nan

    ref = dict(workload=NAME, n_sample=nSample, lcg_final=lcgFinal, first_dev=dev[:10, :],
               first_top=Top[:10], nom_gap=nomGap, wc_half=wcHalf, rss_sigma=rssSigma,
               mean_cold=muC, std_cold=sdC, mean_hot=muH, std_hot=sdH, min_cold=sortedC[0],
               max_cold=sortedC[-1], min_hot=sortedH[0], max_hot=sortedH[-1], cpk=cpk,
               n_low=nLow, n_high=nHigh, n_hot=nHot, yield_=yieldMC, hist_counts=counts,
               hist_underflow=underflow, hist_overflow=overflow, pct=pct, pct_cold=pC,
               pct_hot=pH, contrib=contrib, rank=rank, scale=scale, yield_scale=yieldScale,
               cpk_scale=cpkScale, scale_max=scaleMax)
    ref["yield"] = ref.pop("yield_")
    path = write_reference(NAME, ref)
    print("W5 tolerance stack-up (NumPy cross-check)")
    print("  nominal %.4f, WC +-%.4f, RSS sigma %.5f" % (nomGap, wcHalf, rssSigma))
    print("  cold mean %.6f std %.6f  hot mean %.6f std %.6f  Cpk %.4f"
          % (muC, sdC, muH, sdH, cpk))
    print("  rejects low %d high %d hot %d  yield %.4f%%" % (nLow, nHigh, nHot, 100 * yieldMC))
    print("  percentiles cold", np.round(pC, 5), "hot", np.round(pH, 5))
    print("  contrib %", np.round(100 * contrib, 2), "rank", rank)
    print("  hist under %d over %d max %d" % (underflow, overflow, counts.max()))
    print("  yield vs scale", np.round(100 * yieldScale, 3))
    print("  scale max", scaleMax, " lcg final", lcgFinal)
    print("  wrote", path)


if __name__ == "__main__":
    main()
