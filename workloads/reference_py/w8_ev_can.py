"""Independent NumPy re-implementation of w8_ev_can.m (cross-check only).

Written from DESIGN.md section 2.16.8 alone (never from the MATLAB script, the sketch or the
simulator), so that it checks them. It decodes the committed bus log w8_ev_can/w8_ev_can.log and
runs the analysis A1-A11: every count, time, bit length, checksum, counter step, law value and sum
is a Python int (exact), division is truncation toward zero (tdiv) where the law says so, and each
derived float is the stated short sequence of IEEE operations on exact integers, in the stated
order (L-nl). So every key is expected to be identical to MATLAB's.
Run: uv run --no-project --with numpy python reference_py/w8_ev_can.py
"""

import math
import os
import re
import time

import numpy as np

from common import HERE, write_reference

NAME = "w8_ev_can"
LOG_PATH = os.path.join(os.path.dirname(HERE), "w8_ev_can", "w8_ev_can.log")

# The ten identifiers of section 2.16.3, ascending; the five with a checksum byte.
IDS = [0x0A0, 0x101, 0x102, 0x120, 0x121, 0x181, 0x182, 0x381, 0x382, 0x710]
CHECKSUM_IDS = (0x101, 0x102, 0x121, 0x181, 0x182)
STATE_NAME = ["INIT", "RUN", "FAULT_FB", "FAULT_APPS"]
ST_RUN = 1
GAP_US = 12000                       # a feedback interval above 12 ms is a gap event (A5)
LAGS = list(range(0, 50001, 1000))   # A8's 51 lags [us]
WIN_US = 100000                      # A3's 100 ms windows

# One candump -L line of a standard frame: (<sec>.<6 us digits>) <iface> <3 hex>#<data or R>.
LINE_RE = re.compile(r"\(([0-9]+)\.([0-9]{6})\) ([^ ]+) ([0-9A-Fa-f]{3})#(R|(?:[0-9A-Fa-f]{2}){0,8})")


def tdiv(a, b):
    """a / b truncated toward zero (b > 0), as the sketch's w8_tdiv32/64."""
    q = abs(a) // b
    return q if a >= 0 else -q


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def s16(raw):
    """Two's complement of a 16-bit raw value."""
    return raw - 65536 if raw >= 32768 else raw


def s12(raw):
    return raw - 4096 if raw >= 2048 else raw


def le16s(b, k):
    return s16(b[k] | (b[k + 1] << 8))


def be16s(b, k):
    return s16((b[k] << 8) | b[k + 1])


def checksum_ok(ident, b):
    """Section 2.16.3: the last byte equals ((I&0xFF)+(I>>8)+b0+...+b(D-2)) & 0xFF XOR 0xFF."""
    if len(b) == 0:
        return False
    s = (ident & 0xFF) + (ident >> 8) + sum(b[:-1])
    return b[-1] == ((s & 0xFF) ^ 0xFF)


def frame_bits(ident, rtr, dlc, b):
    """Section 2.16.3's frame length on the wire: (n0, s, L, B) with CRC-15 and stuff bits."""
    bits = [0]                                             # SOF
    bits += [(ident >> k) & 1 for k in range(10, -1, -1)]  # identifier, MSB first
    bits += [1 if rtr else 0, 0, 0]                        # RTR, IDE, r0
    bits += [(dlc >> k) & 1 for k in range(3, -1, -1)]     # DLC code
    for byte in b:                                         # data bytes, byte 0 first
        bits += [(byte >> k) & 1 for k in range(7, -1, -1)]
    c = 0
    for x in bits:
        n = x ^ ((c >> 14) & 1)
        c = (c << 1) & 0x7FFF
        if n:
            c ^= 0x4599
    bits += [(c >> k) & 1 for k in range(14, -1, -1)]      # CRC, bit 14 first
    n0 = len(bits)
    s = 0
    prev = -1
    run = 0
    for x in bits:
        if x == prev:
            run += 1
        else:
            prev = x
            run = 1
        if run == 5:                  # one stuff bit of the opposite value starts a new run
            s += 1
            prev = 1 - x
            run = 1
    L = n0 + s + 10
    return n0, s, L, L + 3


def decode(path):
    """A1: read and decode the log. Returns (frames, n_skipped, iface); each frame is
    (t, id, rtr, data bytes, line number)."""
    with open(path, "rb") as fh:
        text = fh.read().decode("utf-8")
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()                   # the LF that ends the last line
    frames = []
    nSkipped = 0
    iface = None
    tPrev = None
    for ln, line in enumerate(lines, start=1):
        if len(line) == 0:
            continue
        if line[0] != "(":
            nSkipped += 1
            continue
        m = LINE_RE.fullmatch(line)
        if m is None:
            raise ValueError("line %d: malformed frame line \"%s\"" % (ln, line))
        t = int(m.group(1)) * 1000000 + int(m.group(2))
        if iface is None:
            iface = m.group(3)
        elif m.group(3) != iface:
            raise ValueError("line %d: interface %s differs from %s" % (ln, m.group(3), iface))
        if tPrev is not None and t < tPrev:
            raise ValueError("line %d: time earlier than the line before" % ln)
        tPrev = t
        ident = int(m.group(4), 16)
        if ident > 0x7FF:
            raise ValueError("line %d: identifier out of range \"%s\"" % (ln, m.group(4)))
        d = m.group(5)
        rtr = d == "R"
        data = [] if rtr else [int(d[2 * k:2 * k + 2], 16) for k in range(len(d) // 2)]
        frames.append((t, ident, rtr, data, ln))
    if not frames:
        raise ValueError("%s: no frame lines" % path)   # L-on
    return frames, nSkipped, iface


def need(fr, nbytes):
    """The data bytes of a frame whose signals are read; an error if it is too short."""
    if len(fr[3]) < nbytes:
        raise ValueError("line %d: frame %03X has %d data bytes, %d needed"
                         % (fr[4], fr[1], len(fr[3]), nbytes))
    return fr[3]


def analyse(frames):
    nFrames = len(frames)
    t0 = frames[0][0] if nFrames else 0
    trel = [fr[0] - t0 for fr in frames]
    span = trel[-1] if nFrames else 0
    idx = {ident: k for k, ident in enumerate(IDS)}

    # ---------------------------------------------------------------- A2 counts
    frameCounts = [0] * 10
    remoteCounts = [0] * 10
    nUnknown = 0
    dataT = {ident: [] for ident in IDS}       # t of the data frames, per identifier
    dataF = {ident: [] for ident in IDS}       # the data frames themselves
    remoteT = {ident: [] for ident in IDS}
    for i, fr in enumerate(frames):
        k = idx.get(fr[1])
        if k is None:
            nUnknown += 1
            continue
        if fr[2]:
            remoteCounts[k] += 1
            remoteT[fr[1]].append(fr[0])
        else:
            frameCounts[k] += 1
            dataT[fr[1]].append(fr[0])
            dataF[fr[1]].append((i, fr))
    periodMs = []
    maxGapMs = []
    for ident in IDS:
        ts = dataT[ident]
        n = len(ts)
        if n < 2:
            periodMs.append(math.nan)
            maxGapMs.append(0.0)
        else:
            periodMs.append((ts[-1] - ts[0]) / (1000 * (n - 1)))
            maxGapMs.append(max(ts[j] - ts[j - 1] for j in range(1, n)) / 1000)

    # ---------------------------------------------------------------- A3 bus
    busBits = 0
    stuffBits = 0
    W = span // WIN_US
    winBits = [0] * W
    busOverlaps = 0
    for i, fr in enumerate(frames):
        if fr[2]:
            dlc = 6 if fr[1] in (0x381, 0x382) else 0
        else:
            dlc = len(fr[3])
        _, s, L, B = frame_bits(fr[1], fr[2], dlc, fr[3])
        busBits += B
        stuffBits += s
        w = trel[i] // WIN_US
        if w < W:
            winBits[w] += B
        if i >= 1 and fr[0] - 2 * L < frames[i - 1][0] + 6:
            busOverlaps += 1
    busLoad = busBits / (0.5 * span) if span > 0 else math.nan
    busLoadWin = [b / 50000 for b in winBits]
    if W > 0:
        busLoadMax = max(busLoadWin)
        busLoadMaxWin = busLoadWin.index(busLoadMax) + 1
    else:
        busLoadMax = 0.0
        busLoadMaxWin = 0

    # ---------------------------------------------------------------- A4 checksums
    badChecksum = [0] * 10
    valid = {}                                 # frame index -> checksum valid (checksummed ids)
    for ident in CHECKSUM_IDS:
        for i, fr in dataF[ident]:
            ok = checksum_ok(ident, fr[3])
            valid[i] = ok
            if not ok:
                badChecksum[idx[ident]] += 1

    # ---------------------------------------------------------------- A5 counters
    def counter(fr):
        ident = fr[1]
        if ident in (0x101, 0x102):
            return need(fr, 3)[2] & 0x0F
        if ident == 0x120:
            return need(fr, 2)[1] >> 4           # bits 12-15 of the Intel word in bytes 0-1
        if ident == 0x0A0:
            return need(fr, 3)[2]
        return need(fr, 7)[6] & 0x0F             # 0x121, 0x181, 0x182: byte 6 bits 0-3

    vcuCounterGaps = 0
    for ident in (0x101, 0x102, 0x120, 0x121):
        cs = [counter(fr) for _, fr in dataF[ident]]
        vcuCounterGaps += sum(1 for j in range(1, len(cs)) if (cs[j] - cs[j - 1]) % 16 != 1)
    cs = [counter(fr) for _, fr in dataF[0x0A0]]
    imuDropped = sum((cs[j] - cs[j - 1]) % 256 - 1 for j in range(1, len(cs)))
    fbDropped = [0, 0]
    fbLate = [0, 0]
    gapT = [[], []]
    gapMs = [[], []]
    for m, ident in enumerate((0x181, 0x182)):
        fl = dataF[ident]
        for j in range(1, len(fl)):
            i, fr = fl[j]
            g = (counter(fr) - counter(fl[j - 1][1])) % 16
            dt = fr[0] - fl[j - 1][1][0]
            fbDropped[m] += g - 1
            if g == 1 and dt > GAP_US:
                fbLate[m] += 1
            if dt > GAP_US:
                gapT[m].append(trel[i] / 1000000)
                gapMs[m].append(dt / 1000)

    # ---------------------------------------------------------------- A6 VCU cycles and the law
    vcuCycles = frameCounts[idx[0x121]]
    cycleMismatch = 0
    lawTreq = lawRdes = lawDt = lawCmd = 0
    last = {0x101: None, 0x102: None, 0x120: None}
    prevCmd = {0x101: 0, 0x102: 0}   # TorqueCmd of the 0x101/0x102 frame before the last one
    lastCmd = {0x101: None, 0x102: None}
    cycles = []                      # matched cycles: (state, rdes, rmeas, yawlimit, cmdL, cmdR)
    for i, fr in enumerate(frames):
        ident = fr[1]
        if fr[2]:
            continue
        if ident in (0x101, 0x102):
            prevCmd[ident] = lastCmd[ident] if lastCmd[ident] is not None else 0
            lastCmd[ident] = le16s(need(fr, 2), 0)
            last[ident] = fr
        elif ident == 0x120:
            last[ident] = fr
        elif ident == 0x121:
            b = need(fr, 7)
            c = b[6] & 0x0F
            if any(last[k] is None or counter(last[k]) != c for k in (0x101, 0x102, 0x120)):
                cycleMismatch += 1
                continue
            rdesLog = le16s(b, 0)
            rmeas = le16s(b, 2)
            dtLog = le16s(b, 4)
            yawLimLog = (b[6] >> 7) & 1
            d = need(last[0x120], 8)
            word = d[0] | (d[1] << 8)
            p = word & 0x3FF
            state = (word >> 10) & 0x3
            treqLog = le16s(d, 2)
            delta = le16s(d, 4)
            vcs = le16s(d, 6)
            cmdL = lastCmd[0x101]
            cmdR = lastCmd[0x102]
            prevL = prevCmd[0x101]
            prevR = prevCmd[0x102]
            # step 6: the torque request from PedalPos, State and VehSpeed
            pd = 0 if p < 50 else tdiv((p - 50) * 1000, 950)
            if state == ST_RUN:
                treq = 2 * pd if pd > 0 else (-200 if vcs > 300 else 0)
            else:
                treq = 0
            if treq != treqLog:
                lawTreq += 1
            # step 7: the yaw-rate demand from VehSpeed and SteerAngle
            rdes = tdiv(vcs * 10 * delta, 2400)
            yawLim = 0
            if vcs > 100:
                rlim = tdiv(800000, vcs)
                rc = clamp(rdes, -rlim, rlim)
                yawLim = 1 if rc != rdes else 0
                rdes = rc
            if rdes != rdesLog or yawLim != yawLimLog:
                lawRdes += 1
            # step 8: the split from State, YawRateDes and YawRateMeas
            if state == ST_RUN:
                dT = clamp(tdiv(200 * rdesLog + 600 * (rdesLog - rmeas), 1000), -400, 400)
            else:
                dT = 0
            if dT != dtLog:
                lawDt += 1
            # steps 9 and 10: wheel targets and the rate limit from TorqueReq, TorqueSplit
            tR = clamp(tdiv(treqLog + dtLog, 2), -1000, 1000)
            tL = clamp(tdiv(treqLog - dtLog, 2), -1000, 1000)
            if (prevL + clamp(tL - prevL, -50, 50) != cmdL
                    or prevR + clamp(tR - prevR, -50, 50) != cmdR):
                lawCmd += 1
            cycles.append((state, rdesLog, rmeas, yawLimLog, cmdL, cmdR))

    # ---------------------------------------------------------------- A7 states
    stateCycles = [0, 0, 0, 0]
    stateChangeT = []
    stateChangeTo = []
    prevState = None
    for i, fr in dataF[0x120]:
        b = need(fr, 2)
        st = ((b[0] | (b[1] << 8)) >> 10) & 0x3
        stateCycles[st] += 1
        if prevState is not None and st != prevState:
            stateChangeT.append(trel[i] / 1000000)
            stateChangeTo.append(st)
        prevState = st

    # ---------------------------------------------------------------- A8 torque tracking
    lagCost = [[0] * len(LAGS) for _ in range(2)]
    delayMs = [0, 0]
    trackErr = [math.nan, math.nan]
    torqueCmdMax = [0.0, 0.0]
    torqueActMax = [0.0, 0.0]
    speedMaxRpm = [0, 0]
    currentMaxA = [0.0, 0.0]
    derateFrames = [0, 0]
    cmdTimeoutFrames = [0, 0]
    for m, (cid, fid) in enumerate(((0x101, 0x181), (0x102, 0x182))):
        cT = np.array([fr[0] for _, fr in dataF[cid]], dtype=np.int64)
        cV = np.array([le16s(need(fr, 2), 0) for _, fr in dataF[cid]], dtype=np.int64)
        fb = [fr for i, fr in dataF[fid] if valid[i]]
        nm = len(fb)
        aT = np.array([fr[0] for fr in fb], dtype=np.int64)
        aV = np.array([be16s(need(fr, 8), 0) for fr in fb], dtype=np.int64)
        for k, lag in enumerate(LAGS):
            j = np.searchsorted(cT, aT - lag, side="right") - 1   # last command at <= t - lag
            h = np.where(j >= 0, cV[np.maximum(j, 0)] if cV.size else 0, 0)
            lagCost[m][k] = int(np.abs(aV - h).sum(dtype=np.int64))
        best = min(range(len(LAGS)), key=lambda k: (lagCost[m][k], k))
        delayMs[m] = LAGS[best] // 1000
        if nm > 0:
            trackErr[m] = lagCost[m][best] / (10 * nm)
        if cV.size:
            torqueCmdMax[m] = int(np.abs(cV).max()) / 10
        if nm > 0:
            torqueActMax[m] = int(np.abs(aV).max()) / 10
            speedMaxRpm[m] = max(abs(be16s(fr[3], 2)) for fr in fb)
            currentMaxA[m] = max(abs(s12((fr[3][4] << 4) | (fr[3][5] >> 4))) for fr in fb) / 2
            derateFrames[m] = sum(1 for fr in fb if fr[3][5] & 0x2)
            cmdTimeoutFrames[m] = sum(1 for fr in fb if fr[3][5] & 0x4)

    # ---------------------------------------------------------------- A9 torque vectoring
    splitN = 0
    sxx = 0
    sxy = 0
    se = 0
    nRun = 0
    yawLimitCycles = 0
    splitX = []
    splitY = []
    for state, rdes, rmeas, yawLim, cmdL, cmdR in cycles:
        yawLimitCycles += yawLim
        if state != ST_RUN:
            continue
        e = rdes - rmeas
        se += e * e
        nRun += 1
        if abs(rdes) >= 50:
            y = cmdR - cmdL
            splitN += 1
            sxx += rdes * rdes
            sxy += rdes * y
            splitX.append(rdes)
            splitY.append(y)
    splitGain = 100 * (sxy / sxx) if sxx != 0 else math.nan
    yawErrRms = math.sqrt(se / nRun) / 1000 if nRun > 0 else math.nan

    # ---------------------------------------------------------------- A10 motor controllers
    rtrRequests = [0, 0]
    rtrAnswered = [0, 0]
    rtrLatencyMax = [0, 0]
    mcuFw = [0, 0]
    mcuSerial = [0, 0]
    for m, ident in enumerate((0x381, 0x382)):
        pending = None                # time of the last remote frame not yet answered
        for fr in frames:
            if fr[1] != ident:
                continue
            if fr[2]:
                rtrRequests[m] += 1
                pending = fr[0]
            elif pending is not None:
                rtrAnswered[m] += 1
                rtrLatencyMax[m] = max(rtrLatencyMax[m], fr[0] - pending)
                pending = None
        if dataF[ident]:
            b = need(dataF[ident][0][1], 6)
            mcuFw[m] = b[0] | (b[1] << 8)
            mcuSerial[m] = b[2] | (b[3] << 8) | (b[4] << 16) | (b[5] << 24)

    # ---------------------------------------------------------------- A11 speed
    vs = [le16s(need(fr, 8), 6) for _, fr in dataF[0x120]]
    vMax = max(vs) / 100 if vs else 0.0

    return dict(
        n_frames=nFrames, span=span, n_unknown=nUnknown,
        frame_counts=frameCounts, remote_counts=remoteCounts, period_ms=periodMs,
        max_gap_ms=maxGapMs, bad_checksum=badChecksum, bus_bits=busBits, stuff_bits=stuffBits,
        bus_load=busLoad, bus_load_win=busLoadWin, bus_load_max=busLoadMax,
        bus_load_max_win=busLoadMaxWin, n_win=W, bus_overlaps=busOverlaps,
        vcu_counter_gaps=vcuCounterGaps, imu_dropped=imuDropped, fb_dropped=fbDropped,
        fb_late=fbLate, gap_t_L=gapT[0], gap_ms_L=gapMs[0], gap_t_R=gapT[1], gap_ms_R=gapMs[1],
        vcu_cycles=vcuCycles, cycle_mismatch=cycleMismatch, law_treq_mismatch=lawTreq,
        law_rdes_mismatch=lawRdes, law_dt_mismatch=lawDt, law_cmd_mismatch=lawCmd,
        state_cycles=stateCycles, state_change_t=stateChangeT, state_change_to=stateChangeTo,
        delay_ms=delayMs, lag_cost=lagCost, track_err=trackErr, torque_cmd_max=torqueCmdMax,
        torque_act_max=torqueActMax, speed_max_rpm=speedMaxRpm, current_max_A=currentMaxA,
        derate_frames=derateFrames, cmd_timeout_frames=cmdTimeoutFrames, split_n=splitN,
        split_gain=splitGain, yaw_err_rms=yawErrRms, yaw_limit_cycles=yawLimitCycles,
        rtr_requests=rtrRequests, rtr_answered=rtrAnswered, rtr_latency_max_us=rtrLatencyMax,
        mcu_fw=mcuFw, mcu_serial=mcuSerial, v_max=vMax)


def main():
    tCompute = time.perf_counter()
    frames, nSkipped, iface = decode(LOG_PATH)
    r = analyse(frames)
    computeSeconds = time.perf_counter() - tCompute

    ref = dict(
        workload=NAME, iface=iface if iface is not None else "", n_frames=r["n_frames"],
        n_skipped=nSkipped, n_unknown=r["n_unknown"], span_s=r["span"] / 1000000,
        ids=IDS, frame_counts=r["frame_counts"], remote_counts=r["remote_counts"],
        period_ms=r["period_ms"], max_gap_ms=r["max_gap_ms"], bad_checksum=r["bad_checksum"],
        bus_bits=r["bus_bits"], stuff_bits=r["stuff_bits"], bus_load=r["bus_load"],
        bus_load_win=r["bus_load_win"], bus_load_max=r["bus_load_max"],
        bus_load_max_win=r["bus_load_max_win"], bus_overlaps=r["bus_overlaps"])
    for key in ("vcu_counter_gaps", "imu_dropped", "fb_dropped", "fb_late", "gap_t_L",
                "gap_ms_L", "gap_t_R", "gap_ms_R", "vcu_cycles", "cycle_mismatch",
                "law_treq_mismatch", "law_rdes_mismatch", "law_dt_mismatch", "law_cmd_mismatch",
                "state_cycles", "state_change_t", "state_change_to", "delay_ms", "lag_cost",
                "track_err", "torque_cmd_max", "torque_act_max", "speed_max_rpm",
                "current_max_A", "derate_frames", "cmd_timeout_frames", "split_n",
                "split_gain", "yaw_err_rms", "yaw_limit_cycles", "rtr_requests",
                "rtr_answered", "rtr_latency_max_us", "mcu_fw", "mcu_serial", "v_max"):
        ref[key] = r[key]
    ref["lag_cost"] = np.array(r["lag_cost"], dtype=np.int64)   # 2 x 51, a list of two rows
    path = write_reference(NAME, ref)

    # The report of DESIGN.md section 2.16.8, line for line.
    print("\n=== W8  EV CAN log: dual-motor torque vectoring ===")
    print("Log: %d frames on %s over %.6f s; %d other lines skipped, %d unknown identifiers"
          % (r["n_frames"], ref["iface"], ref["span_s"], nSkipped, r["n_unknown"]))
    print("Bus 500 kbit/s: %d bits incl. %d stuff bits, mean load %.3f %%, peak %.3f %% in "
          "window %d of %d (100 ms); overlaps %d"
          % (r["bus_bits"], r["stuff_bits"], 100 * r["bus_load"], 100 * r["bus_load_max"],
             r["bus_load_max_win"], r["n_win"], r["bus_overlaps"]))
    print("%5s %8s %7s %11s %12s %7s" % ("ID", "frames", "remote", "period[ms]", "max-gap[ms]",
                                        "bad-cs"))
    for i, ident in enumerate(IDS):
        csText = "%d" % r["bad_checksum"][i] if ident in CHECKSUM_IDS else "-"
        print("%5s %8d %7d %11.3f %12.3f %7s"
              % ("%03X" % ident, r["frame_counts"][i], r["remote_counts"][i],
                 r["period_ms"][i], r["max_gap_ms"][i], csText))
    print("Feedback: left dropped %d late %d, right dropped %d late %d; IMU dropped %d; "
          "VCU counter gaps %d"
          % (r["fb_dropped"][0], r["fb_late"][0], r["fb_dropped"][1], r["fb_late"][1],
             r["imu_dropped"], r["vcu_counter_gaps"]))
    for m, side in enumerate(("left", "right")):
        print("MCU %-5s firmware %d.%02d serial %08X, %d of %d remote requests answered, "
              "max latency %d us"
              % (side, r["mcu_fw"][m] >> 8, r["mcu_fw"][m] & 255, r["mcu_serial"][m],
                 r["rtr_answered"][m], r["rtr_requests"][m], r["rtr_latency_max_us"][m]))
    print("VCU: %d cycles, %d mismatched; law mismatches: request %d, yaw demand %d, split %d, "
          "commands %d"
          % (r["vcu_cycles"], r["cycle_mismatch"], r["law_treq_mismatch"],
             r["law_rdes_mismatch"], r["law_dt_mismatch"], r["law_cmd_mismatch"]))
    print("Cycles per state: INIT %d, RUN %d, FAULT_FB %d, FAULT_APPS %d"
          % tuple(r["state_cycles"]))
    for t, to in zip(r["state_change_t"], r["state_change_to"]):
        print("  state %-10s from %10.6f s" % (STATE_NAME[to], t))
    print("%-6s %9s %13s %12s %12s %8s %8s %9s" % ("motor", "delay[ms]", "mean-err[Nm]",
                                                 "max-cmd[Nm]", "max-act[Nm]", "derated",
                                                 "max-rpm", "max-I[A]"))
    for m, side in enumerate(("left", "right")):
        print("%-6s %9d %13.4f %12.1f %12.1f %8d %8d %9.1f"
              % (side, r["delay_ms"][m], r["track_err"][m], r["torque_cmd_max"][m],
                 r["torque_act_max"][m], r["derate_frames"][m], r["speed_max_rpm"][m],
                 r["current_max_A"][m]))
    print("Torque vectoring: %d cycles, gain %.4f N m per rad/s; yaw error RMS %.5f rad/s; "
          "yaw limit in %d cycles"
          % (r["split_n"], r["split_gain"], r["yaw_err_rms"], r["yaw_limit_cycles"]))
    print("Top speed %.2f m/s" % r["v_max"])
    print("Compute time: %.3f s" % computeSeconds)
    print("  wrote", path)


if __name__ == "__main__":
    main()
