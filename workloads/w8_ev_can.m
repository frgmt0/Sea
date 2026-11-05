%% w8_ev_can.m -- EV CAN log analysis: dual-motor torque vectoring controller on a 500 kbit/s bus
%
% Sea acceptance workload 8. Original workload: the controller sketch, the motor and vehicle
% model, the message set and the faults are invented for this benchmark (DESIGN.md §2.16). The
% input is the committed bus log w8_ev_can/w8_ev_can.log, written by the host simulation of the
% ESP32 sketch in candump -L form, one frame per line: "(<seconds>.<microseconds>) can0 <ID>#<DATA>".
% The analysis (DESIGN.md §2.16.8, A1-A11) is exact: every count and every intermediate value is
% an integer held exactly in a double (all below 2^53), and every derived float is a fixed short
% sequence of IEEE operations on such integers in the stated order, so the Sea port matches it
% bit for bit. Integer division of the controller law is truncation toward zero, fix(a / b).
%   * A1 Decode: each line split at its two spaces; the timestamp split at '.' into the seconds
%     and exactly six microsecond digits, t = seconds*1e6 + microseconds (never a float parse);
%     a three-digit hexadecimal identifier; the data bytes as two hex digits each, or R for a
%     remote frame. Lines not starting with '(' are skipped and counted; a malformed line, a
%     time going backwards or a second interface is an error naming the line.
%   * A2 Counts, periods and largest gaps per identifier of the message set.
%   * A3 Bus: the exact frame length on the wire of every frame (CRC-15 over SOF ... data, then
%     bit stuffing over SOF ... CRC), the bits charged per frame (frame + 3-bit intermission),
%     the mean load and the load per 100 ms window, and a check that no frame started before
%     the previous one's intermission ended.
%   * A4 Checksums (S = (id & 0xFF) + (id >> 8) + bytes before the last, CS = (S & 0xFF) xor 0xFF).
%   * A5 Rolling counters: VCU counter gaps, IMU drops, feedback drops (counter steps above 1
%     modulo 16), late feedback (a step of 1 after more than 12 ms) and every feedback gap.
%   * A6 The controller law recomputed from the frames of each control cycle (matched by the
%     shared 4-bit counter): torque request, yaw-rate demand with its lateral limit, torque split
%     and the rate-limited wheel commands, each disagreement counted.
%   * A7 VCU state counts and state changes; A8 torque tracking per motor: the command held by
%     the motor controller against the measured torque, a dead-time search over 0..50 ms in 1 ms
%     steps (first smallest summed absolute error), maxima of torque, speed and current;
%     A9 torque vectoring gain (least squares through the origin) and yaw error RMS; A10 remote
%     requests, answers and latency, firmware and serial; A11 top speed.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w8_ev_can.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w8_ev_can';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
logPath = fullfile(wlDir, 'w8_ev_can', 'w8_ev_can.log');

%% ---------------------------------------------------------------- message set (DESIGN.md §2.16.3)
ids = hex2dec(["0A0" "101" "102" "120" "121" "181" "182" "381" "382" "710"]).';  % ascending
nId = numel(ids);
csIds   = hex2dec(["101" "102" "121" "181" "182"]).';   % identifiers with a checksum byte
idImu   = hex2dec("0A0");
idCmdL  = hex2dec("101");  idCmdR = hex2dec("102");
idDrv   = hex2dec("120");  idYaw  = hex2dec("121");
idFbL   = hex2dec("181");  idFbR  = hex2dec("182");
idInfoL = hex2dec("381");  idInfoR = hex2dec("382");
crcPoly = hex2dec("4599"); % CRC-15 polynomial
gapLimitUs = 12000;        % a feedback interval above this is a gap event [us]
winUs      = 100000;       % bus load window [us]
lagStepUs  = 1000;         % dead-time search step [us]
nLag       = 51;           % lags 0, 1 ms, ..., 50 ms

% Character lookup tables (index = character code + 1): hex digit and decimal digit values, -1
% for any other character.
hexLut = -ones(1, 65536);
hexLut(double('0':'9') + 1) = 0:9;
hexLut(double('A':'F') + 1) = 10:15;
hexLut(double('a':'f') + 1) = 10:15;
decLut = -ones(1, 65536);
decLut(double('0':'9') + 1) = 0:9;

tCompute = tic;

%% ---------------------------------------------------------------- A1 decode
allLines = readlines(logPath);
nonEmpty = strlength(allLines) > 0;
isFrameLine = nonEmpty & startsWith(allLines, "(");
nSkipped = sum(nonEmpty & ~isFrameLine);
lineNo = find(isFrameLine);              % line numbers of the frame lines in the file
fl = allLines(isFrameLine);
nFrames = numel(fl);
if nFrames == 0
    error('w8:log', '%s: no frame lines', logPath);
end
check_lines(count(fl, " ") == 2, lineNo, fl, 'not a candump -L line');
tsField = extractBefore(fl, " ");
rest    = extractAfter(fl, " ");
ifField = extractBefore(rest, " ");
frField = extractAfter(rest, " ");

% Timestamp "(<seconds>.<microseconds>)": the seconds and exactly six microsecond digits.
nTs = strlength(tsField);
check_lines(nTs >= 3 & endsWith(tsField, ")"), lineNo, fl, 'bad timestamp');
tsInner = extractBetween(tsField, 2, nTs - 1);
check_lines(count(tsInner, ".") == 1, lineNo, fl, 'bad timestamp');
secText = extractBefore(tsInner, ".");
usText  = extractAfter(tsInner, ".");
check_lines(strlength(secText) >= 1 & strlength(usText) == 6, lineNo, fl, 'bad timestamp');
secChars = char(pad(secText, max(strlength(secText)), 'left', '0'));
usChars  = char(usText);
secDig = reshape(decLut(double(secChars) + 1), size(secChars));   % shape kept for one column
usDig  = reshape(decLut(double(usChars) + 1), size(usChars));
check_lines(all(secDig >= 0, 2) & all(usDig >= 0, 2), lineNo, fl, 'bad timestamp');
secs = zeros(nFrames, 1);
for k = 1:size(secDig, 2)
    secs = secs * 10 + secDig(:, k);
end
micro = zeros(nFrames, 1);
for k = 1:6
    micro = micro * 10 + usDig(:, k);
end
% t must stay an exact integer in a double: below 2^53 us (seconds below 9 007 199 254).
check_lines(secs < 9007199254, lineNo, fl, 'timestamp too large');
t = secs * 1000000 + micro;              % [us], exact

% Frame "<ID>#<DATA>": three hex digits, then R or 0-8 bytes as two hex digits each.
check_lines(count(frField, "#") == 1, lineNo, fl, 'bad frame');
idText   = extractBefore(frField, "#");
dataText = extractAfter(frField, "#");
check_lines(strlength(idText) == 3, lineNo, fl, 'bad identifier');
idChars = char(idText);
idDig = reshape(hexLut(double(idChars) + 1), size(idChars));
check_lines(all(idDig >= 0, 2), lineNo, fl, 'bad identifier');
id = idDig(:, 1) * 256 + idDig(:, 2) * 16 + idDig(:, 3);
check_lines(id <= 2047, lineNo, fl, 'identifier out of range');
rtr = dataText == "R";
nData = strlength(dataText);
nData(rtr) = 0;
check_lines(mod(nData, 2) == 0 & nData <= 16, lineNo, fl, 'bad data');
dataText(rtr) = "";
dataChars = char(pad(dataText, 16, 'right', '0'));
dataNib = reshape(hexLut(double(dataChars) + 1), size(dataChars));
check_lines(all(dataNib >= 0, 2), lineNo, fl, 'bad data byte');
bytes = dataNib(:, 1:2:15) * 16 + dataNib(:, 2:2:16);   % n x 8, zero beyond the data
nBytes = nData / 2;                                       % D, 0 for a remote frame

% One interface on every frame; times never earlier than the line before.
iface = char(ifField(1));
check_lines(ifField == ifField(1), lineNo, fl, 'second interface');
check_lines([true; t(2:end) >= t(1:end - 1)], lineNo, fl, 'time earlier than the line before');
tRel = t - t(1);
span = tRel(end);
spanS = span / 1000000;

%% ---------------------------------------------------------------- A2 counts and periods
frameCounts = zeros(1, nId);
remoteCounts = zeros(1, nId);
periodMs = NaN(1, nId);
maxGapMs = zeros(1, nId);
known = false(nFrames, 1);
for i = 1:nId
    isId = id == ids(i);
    known = known | isId;
    td = t(isId & ~rtr);
    frameCounts(i) = numel(td);
    remoteCounts(i) = sum(isId & rtr);
    if numel(td) >= 2
        periodMs(i) = (td(end) - td(1)) / (1000 * (numel(td) - 1));
        maxGapMs(i) = max(td(2:end) - td(1:end - 1)) / 1000;
    end
end
nUnknown = sum(~known);

%% ---------------------------------------------------------------- A3 bus
% DLC code on the wire: the byte count of a data frame, the table's code for a remote frame.
dlcCode = nBytes;
dlcCode(rtr & (id == idInfoL | id == idInfoR)) = 6;
% Unstuffed bits SOF .. last data bit, most significant bit first in every field.
nPre = 19 + 8 * nBytes;                  % bits before the CRC
bits = zeros(nFrames, 98);
for b = 10:-1:0
    bits(:, 12 - b) = bitand(bitshift(id, -b), 1);        % columns 2..12: identifier
end
bits(:, 13) = rtr;                                        % R; IDE and r0 (14, 15) are 0
for b = 3:-1:0
    bits(:, 19 - b) = bitand(bitshift(dlcCode, -b), 1);   % columns 16..19: DLC code
end
for j = 1:8
    for b = 7:-1:0
        bits(:, 20 + 8 * (j - 1) + (7 - b)) = bitand(bitshift(bytes(:, j), -b), 1);
    end
end
% CRC-15 over the bits SOF .. last data bit (register 0, polynomial 0x4599).
crc = zeros(nFrames, 1);
for k = 1:83
    act = k <= nPre;
    nx = bitxor(bits(:, k), bitand(bitshift(crc, -14), 1)) == 1;
    cNew = bitand(bitshift(crc, 1), 32767);
    cNew(nx) = bitxor(cNew(nx), crcPoly);
    crc(act) = cNew(act);
end
% Its 15 bits (14 .. 0) follow the data; the unstuffed frame then has n0 = 34 + 8 D bits.
rowIdx = (1:nFrames).';
for q = 1:15
    bits(sub2ind([nFrames 98], rowIdx, nPre + q)) = bitand(bitshift(crc, -(15 - q)), 1);
end
n0 = nPre + 15;
% Stuff bits: after five equal bits (a stuff bit counting as the previous bit) one stuff bit of
% the opposite value, which starts a new run of 1.
prevBit = bits(:, 1);
runLen = ones(nFrames, 1);
stuff = zeros(nFrames, 1);
for k = 2:98
    act = k <= n0;
    bk = bits(:, k);
    same = act & bk == prevBit;
    other = act & bk ~= prevBit;
    runLen(same) = runLen(same) + 1;
    prevBit(other) = bk(other);
    runLen(other) = 1;
    hit = act & runLen == 5;
    stuff(hit) = stuff(hit) + 1;
    prevBit(hit) = 1 - prevBit(hit);
    runLen(hit) = 1;
end
frameLen = n0 + stuff + 10;              % L [bit times]
charged = frameLen + 3;                  % B [bit times]
busBits = sum(charged);
stuffBits = sum(stuff);
if span > 0
    busLoad = busBits / (0.5 * span);
else
    busLoad = NaN;                       % one instant: no load defined (L-on)
end
nWin = floor(span / winUs);
win = floor(tRel / winUs);
inWin = win < nWin;
busLoadWin = (accumarray(win(inWin) + 1, charged(inWin), [nWin 1]) / 50000).';
if nWin > 0
    [busLoadMax, iMaxWin] = max(busLoadWin);
else
    busLoadMax = 0;
    iMaxWin = 0;
end
busOverlaps = sum(t(2:end) - 2 * frameLen(2:end) < t(1:end - 1) + 6);

%% ---------------------------------------------------------------- A4 checksums
csBad = false(nFrames, 1);
hasCs = ~rtr & ismember(id, csIds);
sumS = bitand(id, 255) + bitshift(id, -8);
for j = 1:7
    sumS = sumS + bytes(:, j) .* (j < nBytes);              % bytes b0 .. b(D-2)
end
csCalc = bitxor(bitand(sumS, 255), 255);
csLast = zeros(nFrames, 1);
withData = nBytes >= 1;
csLast(withData) = bytes(sub2ind([nFrames 8], rowIdx(withData), nBytes(withData)));
csBad(hasCs) = ~withData(hasCs) | csLast(hasCs) ~= csCalc(hasCs);
badChecksum = zeros(1, nId);
for i = 1:nId
    badChecksum(i) = sum(csBad & id == ids(i));
end

%% ---------------------------------------------------------------- signals (DESIGN.md §2.16.3)
le16 = @(lo, hi) lo + 256 * hi;                           % unsigned 16-bit word, exact
s16 = @(u) u - 65536 * (u >= 32768);                      % sign extension from 16 bits
isCmdL = id == idCmdL & ~rtr;  isCmdR = id == idCmdR & ~rtr;
isDrv  = id == idDrv & ~rtr;   isYaw  = id == idYaw & ~rtr;
isImu  = id == idImu & ~rtr;
isFb   = {id == idFbL & ~rtr, id == idFbR & ~rtr};
% A frame too short for a signal the analysis reads from it is an error naming its line (L-on):
% 0x0A0 and 0x101/0x102 up to byte 2, 0x121 and 0x181/0x182 up to byte 6, 0x120 all 8 bytes,
% and the first data frame of 0x381/0x382 (firmware and serial) up to byte 5.
needBytes = zeros(nFrames, 1);
needBytes(isImu | isCmdL | isCmdR) = 3;
needBytes(isYaw | isFb{1} | isFb{2}) = 7;
needBytes(isDrv) = 8;
for idInfo = [idInfoL idInfoR]
    needBytes(find(id == idInfo & ~rtr, 1)) = 6;
end
check_lines(nBytes >= needBytes, lineNo, fl, 'frame too short for its signals');
% TQ_CMD_L/R: TorqueCmd (Intel s16, bytes 0-1), Counter (byte 2 bits 0-3)
tqCmd = s16(le16(bytes(:, 1), bytes(:, 2)));
ctr4b2 = bitand(bytes(:, 3), 15);
% VCU_DRIVER: the Intel word of bytes 0-1 holds PedalPos (bits 0-9), State (10-11), Counter
% (12-15); TorqueReq, SteerAngle, VehSpeed (Intel s16 in bytes 2-3, 4-5, 6-7)
drvWord = le16(bytes(:, 1), bytes(:, 2));
pedal = bitand(drvWord, 1023);
drvState = bitand(bitshift(drvWord, -10), 3);
drvCtr = bitshift(drvWord, -12);
tqReq = s16(le16(bytes(:, 3), bytes(:, 4)));
steer = s16(le16(bytes(:, 5), bytes(:, 6)));
vehSpeed = s16(le16(bytes(:, 7), bytes(:, 8)));
% VCU_YAW: YawRateDes, YawRateMeas, TorqueSplit (Intel s16), byte 6: Counter (bits 0-3),
% YawLimit (bit 7)
rDesLog = s16(le16(bytes(:, 1), bytes(:, 2)));
rMeasLog = s16(le16(bytes(:, 3), bytes(:, 4)));
splitLog = s16(le16(bytes(:, 5), bytes(:, 6)));
ctr4b6 = bitand(bytes(:, 7), 15);
yawLimLog = bitand(bitshift(bytes(:, 7), -7), 1);
% MCU_FB_L/R (Motorola): TorqueAct (s16, byte 0 high), Speed (s16, byte 2 high), DcCurrent
% (12 bits signed: byte 4 = bits 11-4, byte 5 bits 4-7 = bits 3-0), Status (byte 5 bits 0-3)
tqAct = s16(le16(bytes(:, 2), bytes(:, 1)));
speedFb = s16(le16(bytes(:, 4), bytes(:, 3)));
curRaw = bytes(:, 5) * 16 + bitshift(bytes(:, 6), -4);
curFb = curRaw - 4096 * (curRaw >= 2048);
statFb = bitand(bytes(:, 6), 15);

%% ---------------------------------------------------------------- A5 counters, drops, late frames
vcuCounterGaps = 0;
vcuCtr = {ctr4b2(isCmdL), ctr4b2(isCmdR), drvCtr(isDrv), ctr4b6(isYaw)};
for k = 1:4
    c = vcuCtr{k};
    vcuCounterGaps = vcuCounterGaps + sum(mod(c(2:end) - c(1:end - 1), 16) ~= 1);
end
cImu = bytes(isImu, 3);
imuDropped = sum(mod(cImu(2:end) - cImu(1:end - 1), 256) - 1);
fbDropped = zeros(1, 2);
fbLate = zeros(1, 2);
gapT = cell(1, 2);
gapMs = cell(1, 2);
for m = 1:2
    c = ctr4b6(isFb{m});
    tm = t(isFb{m});
    tr = tRel(isFb{m});
    g = mod(c(2:end) - c(1:end - 1), 16);
    dtm = tm(2:end) - tm(1:end - 1);
    fbDropped(m) = sum(g - 1);
    fbLate(m) = sum(g == 1 & dtm > gapLimitUs);
    ev = find(dtm > gapLimitUs);
    gapT{m} = (tr(ev + 1) / 1000000).';
    gapMs{m} = (dtm(ev) / 1000).';
end

%% ---------------------------------------------------------------- A6 VCU cycles and the law
% For every 0x121 frame, the last 0x101, 0x102 and 0x120 frames before it (0 when none) and
% the position of each in its own identifier's frame list.
pos = (1:nFrames).';
lastL = cummax(pos .* isCmdL);  ordL = cumsum(isCmdL);
lastR = cummax(pos .* isCmdR);  ordR = cumsum(isCmdR);
lastD = cummax(pos .* isDrv);
yawRows = find(isYaw);
vcuCycles = numel(yawRows);
jL = lastL(yawRows);  jR = lastR(yawRows);  jD = lastD(yawRows);
present = jL > 0 & jR > 0 & jD > 0;
okCtr = false(vcuCycles, 1);
okCtr(present) = ctr4b2(jL(present)) == ctr4b6(yawRows(present)) ...
    & ctr4b2(jR(present)) == ctr4b6(yawRows(present)) ...
    & drvCtr(jD(present)) == ctr4b6(yawRows(present));
cycleMismatch = sum(~okCtr);
yr = yawRows(okCtr);  jL = jL(okCtr);  jR = jR(okCtr);  jD = jD(okCtr);
% The previous command of each motor: the frame of that identifier before the cycle's (0 first).
cmdListL = tqCmd(isCmdL);  cmdListR = tqCmd(isCmdR);
pL = ordL(jL);  pR = ordR(jR);
prevL = zeros(numel(yr), 1);  prevR = zeros(numel(yr), 1);
prevL(pL > 1) = cmdListL(pL(pL > 1) - 1);
prevR(pR > 1) = cmdListR(pR(pR > 1) - 1);
% Logged fields of the matched cycles.
st   = drvState(jD);  p = pedal(jD);  treq = tqReq(jD);  delta = steer(jD);  vcs = vehSpeed(jD);
rdes = rDesLog(yr);  rmeas = rMeasLog(yr);  dT = splitLog(yr);  yawLim = yawLimLog(yr);
cmdL = tqCmd(jL);  cmdR = tqCmd(jR);
isRun = st == 1;
% Step 6: torque request.
pd = zeros(size(p));
pd(p >= 50) = fix((p(p >= 50) - 50) * 1000 / 950);
treqLaw = zeros(size(p));
treqLaw(isRun & pd > 0) = 2 * pd(isRun & pd > 0);
treqLaw(isRun & pd == 0 & vcs > 300) = -200;
lawTreq = sum(treq ~= treqLaw);
% Step 7: yaw-rate demand with the lateral limit above 1 m/s.
rdesLaw = fix(vcs * 10 .* delta / 2400);
ylimLaw = zeros(size(p));
fast = vcs > 100;
rLim = zeros(size(p));
rLim(fast) = fix(800000 ./ vcs(fast));
rClamp = min(max(rdesLaw, -rLim), rLim);
ylimLaw(fast) = rClamp(fast) ~= rdesLaw(fast);
rdesLaw(fast) = rClamp(fast);
lawRdes = sum(rdes ~= rdesLaw | yawLim ~= ylimLaw);
% Step 8: split from the logged yaw-rate demand and measurement.
dtLaw = zeros(size(p));
dtLaw(isRun) = min(max(fix((200 * rdes(isRun) + 600 * (rdes(isRun) - rmeas(isRun))) / 1000), ...
    -400), 400);
lawDt = sum(dT ~= dtLaw);
% Steps 9 and 10: wheel targets from the logged request and split, then the rate limit.
tRLaw = min(max(fix((treq + dT) / 2), -1000), 1000);
tLLaw = min(max(fix((treq - dT) / 2), -1000), 1000);
cmdLLaw = prevL + min(max(tLLaw - prevL, -50), 50);
cmdRLaw = prevR + min(max(tRLaw - prevR, -50), 50);
lawCmd = sum(cmdL ~= cmdLLaw | cmdR ~= cmdRLaw);

%% ---------------------------------------------------------------- A7 states
stAll = drvState(isDrv);
stateCycles = zeros(1, 4);
for s = 0:3
    stateCycles(s + 1) = sum(stAll == s);
end
tDrvRel = tRel(isDrv);
chg = find(stAll(2:end) ~= stAll(1:end - 1)) + 1;
stateChangeT = (tDrvRel(chg) / 1000000).';
stateChangeTo = stAll(chg).';

%% ---------------------------------------------------------------- A8 torque tracking
lagCost = zeros(2, nLag);
delayMs = zeros(1, 2);
trackErr = NaN(1, 2);
torqueCmdMax = zeros(1, 2);
torqueActMax = zeros(1, 2);
speedMaxRpm = zeros(1, 2);
currentMaxA = zeros(1, 2);
derateFrames = zeros(1, 2);
cmdTimeoutFrames = zeros(1, 2);
isCmd = {isCmdL, isCmdR};
for m = 1:2
    tc = t(isCmd{m});  vc = tqCmd(isCmd{m});
    valid = isFb{m} & ~csBad;
    tf = t(valid);  af = tqAct(valid);
    nm = numel(tf);
    for l = 1:nLag
        kc = count_le(tc, tf - (l - 1) * lagStepUs);     % commands at or before t_i - lag
        h = zeros(nm, 1);
        h(kc > 0) = vc(kc(kc > 0));
        lagCost(m, l) = sum(abs(af - h));
    end
    [costBest, lBest] = min(lagCost(m, :));
    delayMs(m) = (lBest - 1) * lagStepUs / 1000;
    if nm > 0
        trackErr(m) = costBest / (10 * nm);
    end
    if ~isempty(vc)
        torqueCmdMax(m) = max(abs(vc)) / 10;
    end
    if nm > 0
        torqueActMax(m) = max(abs(af)) / 10;
        speedMaxRpm(m) = max(abs(speedFb(valid)));
        currentMaxA(m) = max(abs(curFb(valid))) / 2;
    end
    derateFrames(m) = sum(bitand(statFb(valid), 2) ~= 0);
    cmdTimeoutFrames(m) = sum(bitand(statFb(valid), 4) ~= 0);
end

%% ---------------------------------------------------------------- A9 torque vectoring
sel = isRun & abs(rdes) >= 50;
xs = rdes(sel);
ys = cmdR(sel) - cmdL(sel);
splitN = numel(xs);
sxx = sum(xs .* xs);
sxy = sum(xs .* ys);
if sxx ~= 0
    splitGain = 100 * (sxy / sxx);
else
    splitGain = NaN;
end
eRun = rdes(isRun) - rmeas(isRun);
nRunCyc = numel(eRun);
se = sum(eRun .* eRun);
if nRunCyc > 0
    yawErrRms = sqrt(se / nRunCyc) / 1000;
else
    yawErrRms = NaN;
end
yawLimitCycles = sum(yawLim == 1);

%% ---------------------------------------------------------------- A10 motor controllers
infoIds = [idInfoL idInfoR];
rtrRequests = zeros(1, 2);
rtrAnswered = zeros(1, 2);
rtrLatencyMax = zeros(1, 2);
mcuFw = zeros(1, 2);
mcuSerial = zeros(1, 2);
for m = 1:2
    rows = find(id == infoIds(m));
    rtrRequests(m) = sum(rtr(rows));
    for k = 1:numel(rows)
        if rtr(rows(k)) && k < numel(rows) && ~rtr(rows(k + 1))
            rtrAnswered(m) = rtrAnswered(m) + 1;
            rtrLatencyMax(m) = max(rtrLatencyMax(m), t(rows(k + 1)) - t(rows(k)));
        end
    end
    firstData = rows(find(~rtr(rows), 1));
    if ~isempty(firstData)
        bd = bytes(firstData, :);
        mcuFw(m) = le16(bd(1), bd(2));
        mcuSerial(m) = le16(bd(3), bd(4)) + 65536 * le16(bd(5), bd(6));
    end
end

%% ---------------------------------------------------------------- A11 speed
vDrv = vehSpeed(isDrv);
if isempty(vDrv)
    vMax = 0;
else
    vMax = max(vDrv) / 100;
end

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
name = {'INIT', 'RUN', 'FAULT_FB', 'FAULT_APPS'};
sideName = {'left', 'right'};
gapTL = gapT{1};  gapMsL = gapMs{1};  gapTR = gapT{2};  gapMsR = gapMs{2};
fprintf('\n=== W8  EV CAN log: dual-motor torque vectoring ===\n');
fprintf('Log: %d frames on %s over %.6f s; %d other lines skipped, %d unknown identifiers\n', ...
    nFrames, iface, spanS, nSkipped, nUnknown);
fprintf('Bus 500 kbit/s: %d bits incl. %d stuff bits, mean load %.3f %%, peak %.3f %% in window %d of %d (100 ms); overlaps %d\n', ...
    busBits, stuffBits, 100 * busLoad, 100 * busLoadMax, iMaxWin, nWin, busOverlaps);
fprintf('%5s %8s %7s %11s %12s %7s\n', 'ID', 'frames', 'remote', 'period[ms]', 'max-gap[ms]', 'bad-cs');
for i = 1:nId
    if ismember(ids(i), csIds)
        csText = sprintf('%d', badChecksum(i));
    else
        csText = '-';
    end
    fprintf('%5s %8d %7d %11.3f %12.3f %7s\n', sprintf('%03X', ids(i)), frameCounts(i), remoteCounts(i), ...
        periodMs(i), maxGapMs(i), csText);
end
fprintf('Feedback: left dropped %d late %d, right dropped %d late %d; IMU dropped %d; VCU counter gaps %d\n', ...
    fbDropped(1), fbLate(1), fbDropped(2), fbLate(2), imuDropped, vcuCounterGaps);
for m = 1:2
    side = sideName{m};
    fprintf('MCU %-5s firmware %d.%02d serial %08X, %d of %d remote requests answered, max latency %d us\n', ...
        side, bitshift(mcuFw(m), -8), bitand(mcuFw(m), 255), mcuSerial(m), rtrAnswered(m), ...
        rtrRequests(m), rtrLatencyMax(m));
end
fprintf('VCU: %d cycles, %d mismatched; law mismatches: request %d, yaw demand %d, split %d, commands %d\n', ...
    vcuCycles, cycleMismatch, lawTreq, lawRdes, lawDt, lawCmd);
fprintf('Cycles per state: INIT %d, RUN %d, FAULT_FB %d, FAULT_APPS %d\n', stateCycles);
for k = 1:numel(stateChangeTo)
    fprintf('  state %-10s from %10.6f s\n', name{stateChangeTo(k) + 1}, stateChangeT(k));
end
fprintf('%-6s %9s %13s %12s %12s %8s %8s %9s\n', 'motor', 'delay[ms]', 'mean-err[Nm]', ...
    'max-cmd[Nm]', 'max-act[Nm]', 'derated', 'max-rpm', 'max-I[A]');
for m = 1:2
    side = sideName{m};
    fprintf('%-6s %9d %13.4f %12.1f %12.1f %8d %8d %9.1f\n', side, delayMs(m), trackErr(m), ...
        torqueCmdMax(m), torqueActMax(m), derateFrames(m), speedMaxRpm(m), currentMaxA(m));
end
fprintf('Torque vectoring: %d cycles, gain %.4f N m per rad/s; yaw error RMS %.5f rad/s; yaw limit in %d cycles\n', ...
    splitN, splitGain, yawErrRms, yawLimitCycles);
fprintf('Top speed %.2f m/s\n', vMax);
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W8 EV CAN log', 'Color', 'w', 'Position', [100 100 960 720]);
    tl = tiledlayout(fig, 2, 2);

    % Panel 0: commands and valid feedback of both motors over 49 s <= t_rel < 59 s.
    nexttile(tl);
    inPlot = tRel >= 49000000 & tRel < 59000000;
    validL = isFb{1} & ~csBad & inPlot;
    validR = isFb{2} & ~csBad & inPlot;
    plot(tRel(isCmdL & inPlot) / 1000000, tqCmd(isCmdL & inPlot) / 10, '-');
    hold on;
    plot(tRel(validL) / 1000000, tqAct(validL) / 10, '-');
    plot(tRel(isCmdR & inPlot) / 1000000, tqCmd(isCmdR & inPlot) / 10, '-');
    plot(tRel(validR) / 1000000, tqAct(validR) / 10, '-');
    hold off;
    legend({'L command', 'L measured', 'R command', 'R measured'});
    xlabel('Time [s]'); ylabel('Torque [N m]');
    title(sprintf('Torque tracking, delay L %d ms, R %d ms', delayMs(1), delayMs(2)));
    grid on;

    % Panel 1: torque split against yaw-rate demand (every fourth cycle) and the fitted line.
    nexttile(tl);
    xr = xs / 1000;
    yn = ys / 10;
    plot(xr(1:4:end), yn(1:4:end), '.');
    hold on;
    xmin = min(xr);  xmax = max(xr);
    plot([xmin xmax], splitGain * [xmin xmax], '-');
    hold off;
    legend({'cycles', 'fit'});
    xlabel('Yaw rate demand [rad/s]'); ylabel('Torque split R-L [N m]');
    title('Torque split vs yaw demand');
    grid on;

    % Panel 2: bus load per 100 ms window (left axis) and feedback gaps (right axis).
    nexttile(tl);
    yyaxis left;
    plot((0:nWin - 1) * 0.1, 100 * busLoadWin, '-');
    ylabel('Load per 100 ms [%]');
    yyaxis right;
    plot(gapTL, gapMsL, 'o');
    hold on;
    plot(gapTR, gapMsR, 's');
    hold off;
    ylabel('Feedback gap [ms]');
    legend({'bus load', 'left gaps', 'right gaps'});
    xlabel('Time [s]');
    title(sprintf('Bus load, mean %.2f %%', 100 * busLoad));
    grid on;

    % Panel 3: data frames per identifier.
    nexttile(tl);
    bar(1:10, frameCounts);
    xticks(1:10); xticklabels(compose('%03X', ids));
    xlabel('Identifier'); ylabel('Data frames');
    title(sprintf('%d frames in %.1f s', nFrames, spanS));
    if SEA_SAVE_FIGURES
        outDir = fullfile(wlDir, 'output');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        exportgraphics(fig, fullfile(outDir, [wlName '.png']), 'Resolution', 150);
    end
end

%% ---------------------------------------------------------------- reference export
if SEA_EXPORT_REFERENCE
    ref = struct();
    ref.workload = wlName;  ref.iface = iface;  ref.n_frames = nFrames;
    ref.n_skipped = nSkipped;  ref.n_unknown = nUnknown;  ref.span_s = spanS;
    ref.ids = ids;  ref.frame_counts = frameCounts;  ref.remote_counts = remoteCounts;
    ref.period_ms = periodMs;  ref.max_gap_ms = maxGapMs;  ref.bad_checksum = badChecksum;
    ref.bus_bits = busBits;  ref.stuff_bits = stuffBits;  ref.bus_load = busLoad;
    ref.bus_load_win = busLoadWin;  ref.bus_load_max = busLoadMax;
    ref.bus_load_max_win = iMaxWin;  ref.bus_overlaps = busOverlaps;
    ref.vcu_counter_gaps = vcuCounterGaps;  ref.imu_dropped = imuDropped;
    ref.fb_dropped = fbDropped;  ref.fb_late = fbLate;
    ref.gap_t_L = gapTL;  ref.gap_ms_L = gapMsL;  ref.gap_t_R = gapTR;  ref.gap_ms_R = gapMsR;
    ref.vcu_cycles = vcuCycles;  ref.cycle_mismatch = cycleMismatch;
    ref.law_treq_mismatch = lawTreq;  ref.law_rdes_mismatch = lawRdes;
    ref.law_dt_mismatch = lawDt;  ref.law_cmd_mismatch = lawCmd;
    ref.state_cycles = stateCycles;  ref.state_change_t = stateChangeT;
    ref.state_change_to = stateChangeTo;
    ref.delay_ms = delayMs;  ref.lag_cost = lagCost;  ref.track_err = trackErr;
    ref.torque_cmd_max = torqueCmdMax;  ref.torque_act_max = torqueActMax;
    ref.speed_max_rpm = speedMaxRpm;  ref.current_max_A = currentMaxA;
    ref.derate_frames = derateFrames;  ref.cmd_timeout_frames = cmdTimeoutFrames;
    ref.split_n = splitN;  ref.split_gain = splitGain;
    ref.yaw_err_rms = yawErrRms;  ref.yaw_limit_cycles = yawLimitCycles;
    ref.rtr_requests = rtrRequests;  ref.rtr_answered = rtrAnswered;
    ref.rtr_latency_max_us = rtrLatencyMax;  ref.mcu_fw = mcuFw;  ref.mcu_serial = mcuSerial;
    ref.v_max = vMax;
    write_reference(wlDir, wlName, ref);
end

%% ---------------------------------------------------------------- local functions
function check_lines(ok, lineNo, lines, what)
% Stops with an error naming the first frame line for which ok is false.
% Inputs: ok (logical, one per frame line), lineNo (their line numbers in the file), lines
% (their text), what (the kind of defect).
bad = find(~ok, 1);
if ~isempty(bad)
    error('w8:log', 'line %d: %s: "%s"', lineNo(bad), what, lines(bad));
end
end

function k = count_le(tc, tq)
% For each query time tq(i), the number of command times tc (non-decreasing, log order) that
% are <= tq(i): the position of the last command at or before tq(i) in tc, 0 before the first.
% A merge by sorting: at equal times a command sorts before a query, so it is counted.
nC = numel(tc);
nQ = numel(tq);
ev = sortrows([tc(:), zeros(nC, 1), (1:nC).'; tq(:), ones(nQ, 1), (1:nQ).'], [1 2 3]);
cnt = cumsum(ev(:, 2) == 0);
isQ = ev(:, 2) == 1;
k = zeros(nQ, 1);
k(ev(isQ, 3)) = cnt(isQ);
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w8:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
