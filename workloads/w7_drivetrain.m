%% w7_drivetrain.m -- Off-road buggy drivetrain study: CVT/gearbox acceleration sweep and a
%  two-stage spur reduction design-space search
%
% Sea acceptance workload 7. Original workload: the vehicle, engine, CVT, tire, gear, material
% and table values are invented for this benchmark. Methods are public textbook methods:
%   * Straight-line acceleration from rest over a fixed distance with two mechanical states, the
%     vehicle speed v and the rear (driven) wheel speed wW. Engine torque from a torque-vs-speed
%     table (linear interpolation) through a CVT ratio r, a fixed gearbox reduction G and a
%     driveline efficiency; aerodynamic drag 1/2*rho*Cd*A*v^2 and rolling resistance Crr*m*g.
%   * Driveline inertia: wheels, gearbox and engine/CVT primary reflected to the wheel through the
%     current ratio, J = Jw + Jd*G^2 + eta*Je*(r*G)^2, plus the torque that a changing ratio
%     takes from the engine's inertia (Je*G*rdot*wW). Front wheel inertia adds Jf/rw^2 to the mass.
%   * Rear axle load with static weight transfer N = m*g*wf + m*a*h/L (a from the previous step).
%   * Tire longitudinal force F = mu(kappa)*N from a piecewise-linear slip curve (linear to the
%     peak, a slow fall after it), slip kappa = (wW*rw - v)/max(v, vRef0).
%   * Centrifugal clutch (no drive below its engagement speed; while it slips the engine revs
%     freely to its stall speed) and a load-sensitive CVT: the ratio moves at a rate proportional
%     to the axial force imbalance of the primary flyweights (kFly*n^2) against the secondary
%     spring (F0 + kSp*(rLow - r)) and torque-feedback helix (kHx*Te*r), between rLow and rMin.
%     Engine governor with a linear droop to a cutoff speed.
%   * Time stepping with a fixed step: the wheel speed by a linearly implicit Euler step (the
%     tire force linearised in wW, so the stiff slip mode stays stable at dt = 1 ms), the ratio by
%     explicit Euler, then the vehicle by semi-implicit Euler (v first, then x with the new v).
%     The run ends when the distance is reached (crossing time and trap speed interpolated
%     linearly between the last two steps) or at a maximum time.
%   * Best gearbox reduction per CVT configuration by a grid minimum refined with the vertex of
%     the parabola through the minimum and its two neighbours; top speed per reduction from the
%     steady-state force balance (tire slip from the road load, the CVT ratio at its force
%     balance by an inner bisection), solved by bisection.
%   * Two-stage spur gear reduction: minimum pinion teeth for no undercut (full-depth teeth,
%     rack form N = 2/sin^2(phi)), Lewis bending stress sigma = Kv*Wt/(F*m*Y) with the Lewis
%     form factor of 20-degree full-depth teeth, a Barth velocity factor Kv = (6.1 + V)/6.1
%     (cut or milled profile), and the face-width range 9m <= F <= 14m.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w7_drivetrain.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w7_drivetrain';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- vehicle and engine
veh.m      = 265;           % vehicle + driver mass [kg]
veh.Cd     = 0.88;          % drag coefficient [-]
veh.A      = 1.02;          % frontal area [m^2]
veh.rho    = 1.17;          % air density [kg/m^3]
veh.Crr    = 0.052;         % rolling resistance coefficient on dirt [-]
veh.wfRear = 0.60;          % static rear (driven) axle weight fraction [-]
veh.h      = 0.45;          % centre of gravity height [m]
veh.L      = 1.65;          % wheelbase [m]
veh.rw     = 0.292;         % rolling radius of the driven wheels [m]
veh.eta    = 0.88;          % driveline efficiency, CVT input to wheels [-]
veh.g      = 9.81;          % gravity [m/s^2]
veh.Jw     = 1.10;          % rear wheels, tires and axle [kg m^2]
veh.Jd     = 0.012;         % CVT secondary and gearbox input shaft [kg m^2]
veh.Je     = 0.022;         % crankshaft, flywheel, clutch and CVT primary [kg m^2]
veh.Jf     = 0.90;          % front wheels [kg m^2]

% Tire on dirt (invented): piecewise-linear mu(kappa)
tire.muPk  = 0.72;          % peak friction coefficient [-]
tire.kPk   = 0.10;          % slip at the peak [-]
tire.muSl  = 0.66;          % friction coefficient at full slide [-]
tire.kSl   = 0.80;          % slip from which mu stays at muSl [-]
tire.vRef0 = 1.0;           % lowest reference speed of the slip definition [m/s]

% Single-cylinder engine at full throttle (invented): torque [N m] vs speed [rev/min]
eng.rpm     = [1500 1900 2300 2700 3100 3500 3900 4300];
eng.tq      = [14.6 16.9 18.4 19.2 19.3 18.6 17.1 14.8];
eng.nIdle   = 1500;         % engine speed when the throttle opens at t = 0 [rev/min]
eng.revRate = 7400;         % free rev-up rate of the engine with the clutch open [rev/min/s]
eng.nGov    = 3800;         % governor: torque falls linearly above this speed [rev/min]
eng.nCut    = 3950;         % governor cutoff: no torque at or above this speed [rev/min]

% CVT configurations (invented): clutch engagement and stall speed, low and minimum ratio,
% primary flyweight constant, secondary spring preload and rate, torque-feedback helix constant
cvt = struct( ...
    'name',    {'Stock', 'Launch', 'Overdrive'}, ...
    'nEngage', {1900,    2100,     1850}, ...   % clutch starts to drive [rev/min]
    'nStall',  {2650,    2900,     2500}, ...   % engine speed while the clutch slips [rev/min]
    'rLow',    {2.60,    2.90,     2.40}, ...   % launch (low) ratio [-]
    'rMin',    {0.88,    0.95,     0.72}, ...   % minimum ratio [-]
    'kFly',    {100,     92,       108}, ...    % flyweight force per (krev/min)^2 [N]
    'F0',      {720,     800,      690}, ...    % spring preload at rLow [N]
    'kSp',     {190,     170,      160}, ...    % spring force per unit of upshift [N]
    'kHx',     {6.0,     7.0,      5.0});       % helix force per N m of secondary torque [N/(N m)]
cShift = 0.01;              % ratio change rate per newton of force imbalance [1/(N s)]

% Acceleration run and sweep
runCfg.dist = 45;           % run distance [m]
runCfg.dt   = 1e-3;         % time step [s]
runCfg.tMax = 12;           % maximum simulated time [s]
Gsweep   = linspace(6, 15, 46);     % gearbox reductions [-]
crrScale = [1, 0.75, 1.25];         % rolling resistance factors: base and sensitivity runs
traceEvery = 20;                    % export every 20th speed sample of the traced run

%% ---------------------------------------------------------------- gear design inputs
gd.Ks       = 1.40;         % service (shock) factor on the design torque [-]
gd.etaStage = 0.98;         % efficiency of one gear stage [-]
gd.Sall     = 420;          % allowable Lewis bending stress, case-hardened steel [MPa]
gd.FOS      = 1.5;          % factor of safety on bending [-]
gd.ratioTol = 0.0035;       % allowed relative error of the overall ratio [-]
gd.a1Win    = [42 90];      % stage 1 centre distance window [mm]
gd.a2Win    = [60 125];     % stage 2 centre distance window [mm]
gd.Dmax     = 200;          % maximum gear outside diameter (housing) [mm]
gd.Fstep    = 0.5;          % face width step [mm]
gd.kMin     = 9;            % face width limits kMin*m <= F <= kMax*m [-]
gd.kMax     = 14;
gd.sLimit   = gd.Sall / gd.FOS;   % stress limit [MPa]
phiDeg   = [20 22.5 25];          % pressure angles [deg]
mod1     = 1.5:0.25:3.5;          % stage 1 modules [mm]
mod2     = 2.0:0.25:4.5;          % stage 2 modules [mm]
splitExp = linspace(0.40, 0.60, 11);   % stage split: stage 1 ratio = Gtarget^splitExp
nOffset  = 10;                    % pinion teeth Nmin .. Nmin + nOffset - 1

% Lewis form factor, 20-degree full-depth teeth (public table), vs number of teeth
lewisN = [12 13 14 15 16 17 18 19 20 21 22 24 26 28 30 34 38 43 50 60 75 100 150 300 400];
lewisY = [0.245 0.261 0.277 0.290 0.296 0.303 0.309 0.314 0.322 0.328 0.331 0.337 0.346 ...
          0.353 0.359 0.371 0.384 0.397 0.409 0.422 0.435 0.447 0.460 0.472 0.480];
% Invented pressure-angle scaling: Y(phi) = Y20 * (tan(phi)/tan(20 deg))^0.45

% Invented recommended backlash [mm] by centre-distance band (rows) and module band (columns)
blAEdges = [0 50 80 125 200];     % centre distance band edges [mm]
blMEdges = [0 2 3 5];             % module band edges [mm]
blMinTab = [0.05 0.07 0.09; 0.07 0.09 0.12; 0.09 0.12 0.15; 0.12 0.15 0.19];
blMaxTab = [0.11 0.14 0.17; 0.14 0.17 0.21; 0.17 0.21 0.26; 0.21 0.26 0.32];

%% ---------------------------------------------------------------- validation
if any(diff(eng.rpm) <= 0) || numel(eng.rpm) ~= numel(eng.tq)
    error('w7:config', 'engine table must have increasing speeds and one torque per speed');
end
if ~(eng.nGov < eng.nCut && eng.nCut <= eng.rpm(end))
    error('w7:config', 'governor speeds must satisfy nGov < nCut <= %g', eng.rpm(end));
end
for c = 1:numel(cvt)
    if ~(eng.nIdle < cvt(c).nEngage && cvt(c).nEngage < cvt(c).nStall && ...
            cvt(c).nStall < eng.nGov)
        error('w7:config', 'CVT "%s": need nIdle < nEngage < nStall < nGov', cvt(c).name);
    end
    if ~(cvt(c).rMin > 0 && cvt(c).rMin < cvt(c).rLow)
        error('w7:config', 'CVT "%s": need 0 < rMin < rLow', cvt(c).name);
    end
    if cvt(c).kFly * (cvt(c).nStall / 1000)^2 >= cvt(c).F0
        error('w7:config', 'CVT "%s" would shift while the clutch slips', cvt(c).name);
    end
end
if ~(tire.kPk > 0 && tire.kPk < tire.kSl && tire.muSl <= tire.muPk)
    error('w7:config', 'tire curve needs 0 < kPk < kSl and muSl <= muPk');
end
if any(diff(lewisN) <= 0) || numel(lewisN) ~= numel(lewisY)
    error('w7:config', 'Lewis table must have increasing tooth counts');
end
eng.tqGov = interp1(eng.rpm, eng.tq, eng.nGov);   % torque where the governor droop starts

%% ---------------------------------------------------------------- part A: acceleration sweep
nCfg = numel(cvt);
nG = numel(Gsweep);
nCrr = numel(crrScale);
tDist = zeros(nCfg, nG, nCrr);      % time to distance [s]
vTrap = zeros(nCfg, nG, nCrr);      % speed at the distance [m/s]
nSteps = zeros(nCfg, nG, nCrr);     % integration steps per run
vTop = zeros(nCfg, nG);             % steady-state top speed [m/s]
topIters = zeros(nCfg, nG);         % bisection iterations
for c = 1:nCfg
    for s = 1:nCrr
        crr = veh.Crr * crrScale(s);
        for i = 1:nG
            [tDist(c, i, s), vTrap(c, i, s), nSteps(c, i, s)] = ...
                accel_run(Gsweep(i), cvt(c), veh, tire, eng, runCfg, cShift, crr, false);
        end
    end
    for i = 1:nG
        [vTop(c, i), topIters(c, i)] = top_speed(Gsweep(i), cvt(c), veh, tire, eng, veh.Crr);
    end
end
totalSteps = sum(nSteps(:));

% Best reduction per configuration and rolling-resistance case: grid minimum + parabola vertex
iBest = zeros(nCfg, nCrr);
tBest = zeros(nCfg, nCrr);
Gbest = zeros(nCfg, nCrr);
for c = 1:nCfg
    for s = 1:nCrr
        [tBest(c, s), iBest(c, s)] = min(tDist(c, :, s));
        Gbest(c, s) = refine_min(Gsweep, tDist(c, :, s), iBest(c, s));
    end
end

% Region statistics (steps per CVT region, wheelspin) and first upshift of each best grid run
regBest = zeros(nCfg, 7);
tShift = zeros(1, nCfg);
for c = 1:nCfg
    [~, ~, ~, regBest(c, :), vTr, tShift(c)] = accel_run(Gsweep(iBest(c, 1)), cvt(c), veh, ...
        tire, eng, runCfg, cShift, veh.Crr, true);
    if c == 1
        traceStock = vTr;
    end
end

%% ---------------------------------------------------------------- part B: gear design search
[~, cfgPick] = min(tBest(:, 1));            % the fastest configuration at base rolling resistance
Gtarget = round(100 * Gbest(cfgPick, 1)) / 100;   % overall gear ratio to build [-]
Tin = max(eng.tq) * cvt(cfgPick).rLow * gd.Ks * 1000;   % stage 1 pinion design torque [N mm]
cp = cvt(cfgPick);   % design speed: the engine speed where the CVT starts to shift at peak torque
nIn = 1000 * sqrt((cp.F0 + cp.kHx * max(eng.tq) * cp.rLow) / cp.kFly) / cp.rLow;   % [rev/min]
phi20 = 20 * pi / 180;
tan20 = sin(phi20) / cos(phi20);

nPhi = numel(phiDeg);
nMin = zeros(1, nPhi);
yScale = zeros(1, nPhi);
nCand = 0; nDup = 0; nRejRatio = 0; nRejGeom = 0; nRejStress = 0;
fePhi = zeros(1, 0); feM1 = zeros(1, 0); feM2 = zeros(1, 0); feSplit = zeros(1, 0);
feNp1 = zeros(1, 0); feNg1 = zeros(1, 0); feNp2 = zeros(1, 0); feNg2 = zeros(1, 0);
feF1 = zeros(1, 0); feF2 = zeros(1, 0); feA1 = zeros(1, 0); feA2 = zeros(1, 0);
feErr = zeros(1, 0); feS1 = zeros(1, 0); feS2 = zeros(1, 0); feMass = zeros(1, 0);
for ip = 1:nPhi
    phi = phiDeg(ip) * pi / 180;
    sp = sin(phi);
    nMin(ip) = ceil(2 / (sp * sp));
    yScale(ip) = ((sp / cos(phi)) / tan20)^0.45;
    for i1 = 1:numel(mod1)
        m1 = mod1(i1);
        for i2 = 1:numel(mod2)
            m2 = mod2(i2);
            for o1 = 0:nOffset - 1
                Np1 = nMin(ip) + o1;
                Y1 = interp1(lewisN, lewisY, Np1) * yScale(ip);
                for o2 = 0:nOffset - 1
                    Np2 = nMin(ip) + o2;
                    Y2 = interp1(lewisN, lewisY, Np2) * yScale(ip);
                    prevNg1 = -1; prevNg2 = -1;
                    for is = 1:numel(splitExp)
                        nCand = nCand + 1;
                        % stage 1 teeth for the split; stage 2 compensates; if the overall
                        % ratio is out of tolerance, move the stage 1 gear by one tooth
                        base = round(Np1 * Gtarget^splitExp(is));
                        ok = false;
                        for dN = [0 -1 1]
                            Ng1 = base + dN;
                            Ng2 = round(Np2 * Gtarget * Np1 / Ng1);
                            err = Ng1 * Ng2 / (Np1 * Np2) / Gtarget - 1;
                            if abs(err) <= gd.ratioTol
                                ok = true;
                                break;
                            end
                        end
                        if ~ok
                            nRejRatio = nRejRatio + 1;
                            continue;
                        end
                        if Ng1 == prevNg1 && Ng2 == prevNg2   % same teeth as the previous split
                            nDup = nDup + 1;
                            continue;
                        end
                        prevNg1 = Ng1; prevNg2 = Ng2;
                        a1 = m1 * (Np1 + Ng1) / 2;
                        a2 = m2 * (Np2 + Ng2) / 2;
                        if a1 < gd.a1Win(1) || a1 > gd.a1Win(2) || a2 < gd.a2Win(1) || ...
                                a2 > gd.a2Win(2) || m1 * (Ng1 + 2) > gd.Dmax || ...
                                m2 * (Ng2 + 2) > gd.Dmax
                            nRejGeom = nRejGeom + 1;
                            continue;
                        end
                        [ok1, F1, s1] = size_face(Tin, nIn, m1, Np1, Y1, gd);
                        if ~ok1
                            nRejStress = nRejStress + 1;
                            continue;
                        end
                        [ok2, F2, s2] = size_face(Tin * Ng1 / Np1 * gd.etaStage, ...
                            nIn * Np1 / Ng1, m2, Np2, Y2, gd);
                        if ~ok2
                            nRejStress = nRejStress + 1;
                            continue;
                        end
                        dp1 = m1 * Np1; dg1 = m1 * Ng1; dp2 = m2 * Np2; dg2 = m2 * Ng2;
                        vol = pi / 4 * (F1 * (dp1 * dp1 + dg1 * dg1) + ...
                            F2 * (dp2 * dp2 + dg2 * dg2)) / 1000;   % blank volume [cm^3]
                        fePhi(end + 1) = phiDeg(ip);   feM1(end + 1) = m1;
                        feM2(end + 1) = m2;            feSplit(end + 1) = splitExp(is);
                        feNp1(end + 1) = Np1;          feNg1(end + 1) = Ng1;
                        feNp2(end + 1) = Np2;          feNg2(end + 1) = Ng2;
                        feF1(end + 1) = F1;            feF2(end + 1) = F2;
                        feA1(end + 1) = a1;            feA2(end + 1) = a2;
                        feErr(end + 1) = err;          feS1(end + 1) = s1;
                        feS2(end + 1) = s2;            feMass(end + 1) = vol;
                    end
                end
            end
        end
    end
end
nFeas = numel(feMass);
if nFeas == 0
    error('w7:design', 'no feasible gear design for ratio %.2f', Gtarget);
end
[massSorted, ord] = sort(feMass);           % stable: equal masses keep search order
nTop = min(10, nFeas);
top = ord(1:nTop);
feasPerPhi = zeros(1, nPhi);
for ip = 1:nPhi
    feasPerPhi(ip) = nnz(fePhi == phiDeg(ip));
end
b = top(1);                                 % the lightest feasible design

%% ---------------------------------------------------------------- part C: backlash lookup
blA = [feA1(b), feA2(b)];
blM = [feM1(b), feM2(b)];
blBandA = zeros(1, 2); blBandM = zeros(1, 2);
blMin = zeros(1, 2); blMax = zeros(1, 2);
for k = 1:2
    if blA(k) >= blAEdges(end) || blM(k) >= blMEdges(end)
        error('w7:backlash', 'stage %d is outside the backlash table', k);
    end
    blBandA(k) = find(blA(k) >= blAEdges(1:end - 1), 1, 'last');
    blBandM(k) = find(blM(k) >= blMEdges(1:end - 1), 1, 'last');
    blMin(k) = blMinTab(blBandA(k), blBandM(k));
    blMax(k) = blMaxTab(blBandA(k), blBandM(k));
end

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
regName = {'clutch open', 'clutch slip', 'low ratio', 'shifting', 'min ratio', 'governor', ...
           'wheelspin'};
fprintf('\n=== W7  Off-road buggy drivetrain study ===\n');
fprintf(['Vehicle %.0f kg, Cd*A %.3f m^2, Crr %.3f, tire mu %.2f peak / %.2f slide, ' ...
    'rear weight %.0f %%, wheel radius %.0f mm\n'], veh.m, veh.Cd * veh.A, veh.Crr, ...
    tire.muPk, tire.muSl, 100 * veh.wfRear, veh.rw * 1e3);
fprintf('Run: %.0f m from rest, dt = %.1e s, limit %.0f s; governor %.0f..%.0f rpm\n\n', ...
    runCfg.dist, runCfg.dt, runCfg.tMax, eng.nGov, eng.nCut);
fprintf('%6s', 'G');
for c = 1:nCfg
    fprintf(' | %-9s %7s %7s', cvt(c).name, 'trap', 'top');
end
fprintf('\n');
for i = 1:nG
    fprintf('%6.2f', Gsweep(i));
    for c = 1:nCfg
        fprintf(' | %9.4f %7.3f %7.3f', tDist(c, i, 1), vTrap(c, i, 1), vTop(c, i));
    end
    fprintf('\n');
end
fprintf('(times to %.0f m in s; trap and top speeds in m/s)\n\n', runCfg.dist);
fprintf('%-10s %8s %9s %9s | %9s %9s\n', 'CVT', 'G grid', 't[s]', 'G*', 'G* Crr-25%', ...
    'G* Crr+25%');
for c = 1:nCfg
    fprintf('%-10s %8.2f %9.4f %9.4f | %9.4f %9.4f\n', cvt(c).name, Gsweep(iBest(c, 1)), ...
        tBest(c, 1), Gbest(c, 1), Gbest(c, 2), Gbest(c, 3));
end
fprintf('Time at the grid best with Crr -25 %% and +25 %% [s]:');
for c = 1:nCfg
    fprintf(' %s %.4f %.4f', cvt(c).name, tBest(c, 2), tBest(c, 3));
end
fprintf('\nFirst upshift in each best run [s]:');
for c = 1:nCfg
    fprintf(' %s %.3f', cvt(c).name, tShift(c));
end
fprintf('\nSteps per CVT region in each best run:\n');
for k = 1:7
    fprintf('  %-17s', regName{k});
    for c = 1:nCfg
        fprintf(' %6d', regBest(c, k));
    end
    fprintf('\n');
end
fprintf('Integration steps in all %d runs: %d\n\n', nCfg * nG * nCrr, totalSteps);

fprintf('Gear reduction for the %s CVT: target ratio %.2f, design torque %.1f N m at %.1f rpm\n', ...
    cvt(cfgPick).name, Gtarget, Tin / 1000, nIn);
fprintf('Minimum pinion teeth (no undercut):');
for ip = 1:nPhi
    fprintf(' %.1f deg: %d', phiDeg(ip), nMin(ip));
end
fprintf('\nCandidates %d: ratio rejects %d, repeats %d, geometry rejects %d, stress rejects %d\n', ...
    nCand, nRejRatio, nDup, nRejGeom, nRejStress);
fprintf('Feasible designs: %d (%d / %d / %d by pressure angle)\n', nFeas, feasPerPhi(1), ...
    feasPerPhi(2), feasPerPhi(3));
fprintf('%4s %5s %5s %5s %5s %4s %4s %4s %4s %6s %6s %7s %7s %8s %7s %7s %9s\n', 'rank', 'phi', ...
    'm1', 'm2', 'split', 'Np1', 'Ng1', 'Np2', 'Ng2', 'F1', 'F2', 'a1', 'a2', 'err[%]', 's1', 's2', ...
    'vol[cm3]');
for r = 1:nTop
    k = top(r);
    fprintf(['%4d %5.1f %5.2f %5.2f %5.2f %4d %4d %4d %4d %6.1f %6.1f %7.2f %7.2f %+8.4f ' ...
        '%7.1f %7.1f %9.2f\n'], ...
        r, fePhi(k), feM1(k), feM2(k), feSplit(k), feNp1(k), feNg1(k), feNp2(k), feNg2(k), ...
        feF1(k), feF2(k), feA1(k), feA2(k), 100 * feErr(k), feS1(k), feS2(k), feMass(k));
end
fprintf('Best design: ratio %.4f (Ng1 Np1 Ng2 Np2 = %d %d %d %d), blank volume %.2f cm^3\n', ...
    feNg1(b) * feNg2(b) / (feNp1(b) * feNp2(b)), feNg1(b), feNp1(b), feNg2(b), feNp2(b), ...
    feMass(b));
for k = 1:2
    fprintf(['  stage %d: centre distance %.2f mm (band %d), module %.2f mm (band %d), ' ...
        'backlash %.2f..%.2f mm\n'], ...
        k, blA(k), blBandA(k), blM(k), blBandM(k), blMin(k), blMax(k));
end
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W7 drivetrain', 'Color', 'w');
    tl = tiledlayout(fig, 2, 2);
    nexttile(tl);
    plot(Gsweep, tDist(:, :, 1), '-o', 'MarkerSize', 3);
    grid on; xlabel('Gearbox reduction [-]'); ylabel(sprintf('Time to %.0f m [s]', runCfg.dist));
    legend({cvt.name}, 'Location', 'north');
    title('Acceleration run');

    nexttile(tl);
    plot(Gsweep, vTop, '-');
    grid on; xlabel('Gearbox reduction [-]'); ylabel('Top speed [m/s]');
    legend({cvt.name});
    title('Steady-state top speed');

    nexttile(tl);
    plot((1:numel(traceStock)) * runCfg.dt, traceStock);
    grid on; xlabel('Time [s]'); ylabel('Speed [m/s]');
    title(sprintf('%s CVT, G = %.2f', cvt(1).name, Gsweep(iBest(1, 1))));

    nexttile(tl);
    plot(1:nFeas, massSorted, '-');
    grid on; xlabel('Rank'); ylabel('Blank volume [cm^3]');
    title(sprintf('%d feasible gear designs', nFeas));
    if SEA_SAVE_FIGURES
        outDir = fullfile(wlDir, 'output');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        exportgraphics(fig, fullfile(outDir, [wlName '.png']), 'Resolution', 150);
    end
end

%% ---------------------------------------------------------------- reference export
if SEA_EXPORT_REFERENCE
    ref = struct();
    ref.workload = wlName;  ref.cfg_name = {cvt.name};  ref.G = Gsweep;
    ref.t_dist = tDist(:, :, 1);  ref.t_dist_lo = tDist(:, :, 2);  ref.t_dist_hi = tDist(:, :, 3);
    ref.v_trap = vTrap(:, :, 1);  ref.v_trap_lo = vTrap(:, :, 2);  ref.v_trap_hi = vTrap(:, :, 3);
    ref.steps = nSteps(:, :, 1);  ref.steps_lo = nSteps(:, :, 2);  ref.steps_hi = nSteps(:, :, 3);
    ref.total_steps = totalSteps;  ref.v_top = vTop;  ref.top_iters = topIters;
    ref.i_best = iBest(:, 1).';  ref.i_best_lo = iBest(:, 2).';  ref.i_best_hi = iBest(:, 3).';
    ref.t_best = tBest(:, 1).';  ref.t_best_lo = tBest(:, 2).';  ref.t_best_hi = tBest(:, 3).';
    ref.G_best = Gbest(:, 1).';  ref.G_best_lo = Gbest(:, 2).';  ref.G_best_hi = Gbest(:, 3).';
    ref.region_steps = regBest;  ref.t_shift = tShift;  ref.trace_v = traceStock(traceEvery:traceEvery:end);
    ref.cfg_pick = cfgPick;  ref.G_target = Gtarget;  ref.n_min = nMin;  ref.y_scale = yScale;
    ref.n_cand = nCand;  ref.n_dup = nDup;  ref.n_rej_ratio = nRejRatio;
    ref.n_rej_geom = nRejGeom;  ref.n_rej_stress = nRejStress;  ref.n_feasible = nFeas;
    ref.feasible_per_phi = feasPerPhi;  ref.mass_sorted = massSorted;
    ref.top_phi = fePhi(top);  ref.top_m1 = feM1(top);  ref.top_m2 = feM2(top);
    ref.top_split = feSplit(top);  ref.top_Np1 = feNp1(top);  ref.top_Ng1 = feNg1(top);
    ref.top_Np2 = feNp2(top);  ref.top_Ng2 = feNg2(top);  ref.top_F1 = feF1(top);
    ref.top_F2 = feF2(top);  ref.top_a1 = feA1(top);  ref.top_a2 = feA2(top);
    ref.top_err = feErr(top);  ref.top_s1 = feS1(top);  ref.top_s2 = feS2(top);
    ref.top_mass = feMass(top);
    ref.backlash_band_a = blBandA;  ref.backlash_band_m = blBandM;
    ref.backlash_min = blMin;  ref.backlash_max = blMax;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function [tCross, vCross, k, regSteps, vTrace, tShift] = accel_run(G, c, veh, tire, eng, ...
    runCfg, cShift, crr, record)
% One acceleration run from rest. Returns the time and speed at the distance (NaN if
% runCfg.tMax is reached first), the number of steps, the steps spent in each CVT region (1..6)
% and with the tire beyond its peak slip (7), the speed after every step when record is true,
% and the time of the first upshift (NaN if none).
dt = runCfg.dt;
mv = veh.m + veh.Jf / (veh.rw * veh.rw);     % vehicle mass with the front wheel inertia
Nstat = veh.m * veh.g * veh.wfRear;          % static rear axle load [N]
Nmax = veh.m * veh.g;
kTr = veh.m * veh.h / veh.L;                 % weight transfer per unit acceleration [kg]
nMax = round(runCfg.tMax / dt);
regSteps = zeros(1, 7);
if record
    vTrace = zeros(1, nMax);
else
    vTrace = zeros(1, 0);
end
v = 0; x = 0; wW = 0; r = c.rLow; aPrev = 0; k = 0;
vPrev = 0; xPrev = 0;
tShift = NaN;
while x < runCfg.dist && k < nMax
    t = k * dt;
    [Td, Jeq, rNew, reg] = driveline(wW, r, t, G, c, veh, eng, cShift, dt);
    regSteps(reg) = regSteps(reg) + 1;
    if rNew < c.rLow && isnan(tShift)
        tShift = t;
    end
    Nr = Nstat + kTr * aPrev;                % rear axle load with weight transfer
    if Nr > Nmax
        Nr = Nmax;
    elseif Nr < 0
        Nr = 0;
    end
    vRef = max(v, tire.vRef0);
    kappa = (wW * veh.rw - v) / vRef;
    [mu, dmu] = slip_curve(kappa, tire);
    if kappa > tire.kPk
        regSteps(7) = regSteps(7) + 1;
    end
    Fx = mu * Nr;
    dFdw = dmu * Nr * veh.rw / vRef;         % d Fx / d wW
    % linearly implicit Euler step of the wheel: J*dw/dt = Td - rw*(Fx + dFdw*(wNew - wW))
    wNew = wW + dt * (Td - Fx * veh.rw) / (Jeq + dt * veh.rw * dFdw);
    if wNew < 0
        wNew = 0;
    end
    Fx = Fx + dFdw * (wNew - wW);            % the tire force the step used
    vPrev = v; xPrev = x;
    v = v + dt * (Fx - road_load(v, veh, crr)) / mv;
    if v < 0
        v = 0;
    end
    aPrev = (v - vPrev) / dt;
    x = x + v * dt;
    wW = wNew;
    r = rNew;
    k = k + 1;
    if record
        vTrace(k) = v;
    end
end
if x >= runCfg.dist
    frac = (runCfg.dist - xPrev) / (x - xPrev);
    tCross = (k - 1) * dt + frac * dt;
    vCross = vPrev + frac * (v - vPrev);
else
    tCross = NaN;
    vCross = NaN;
end
if record
    vTrace = vTrace(1:k);
end
end

function [Td, Jeq, rNew, reg] = driveline(wW, r, t, G, c, veh, eng, cShift, dt)
% Drive torque at the rear wheels [N m], driveline inertia reflected to them [kg m^2], the CVT
% ratio after this step and the region: 1 clutch open, 2 clutch slipping, 3 locked at rLow,
% 4 shifting, 5 at rMin, 6 governor (droop or cutoff).
nOut = wW * G * 60 / (2 * pi);               % CVT output speed [rev/min]
nFree = min(eng.nIdle + eng.revRate * t, c.nStall);   % engine speed with the clutch slipping
nLock = r * nOut;                            % engine speed with the clutch locked
JwG = veh.Jw + veh.Jd * (G * G);
if nFree < c.nEngage
    Td = 0;  Jeq = JwG;  rNew = r;  reg = 1;
    return;
elseif nLock < nFree
    Te = engine_torque(nFree, eng);
    Td = veh.eta * r * G * Te;  Jeq = JwG;  rNew = r;  reg = 2;
    return;
end
[Te, gov] = engine_torque(nLock, eng);
rNew = r - dt * cShift * shift_imbalance(r, nLock, Te, c);
if rNew > c.rLow
    rNew = c.rLow;
elseif rNew < c.rMin
    rNew = c.rMin;
end
rDot = (rNew - r) / dt;
rG = r * G;
Td = veh.eta * rG * (Te - veh.Je * G * rDot * wW);
Jeq = JwG + veh.eta * veh.Je * (rG * rG);
if gov
    reg = 6;
elseif r == c.rLow
    reg = 3;
elseif r == c.rMin
    reg = 5;
else
    reg = 4;
end
end

function [Te, gov] = engine_torque(n, eng)
% Full-throttle engine torque [N m] at n [rev/min], with the governor droop and cutoff.
if n >= eng.nCut
    Te = 0;  gov = true;
elseif n > eng.nGov
    Te = eng.tqGov * (eng.nCut - n) / (eng.nCut - eng.nGov);  gov = true;
else
    Te = interp1(eng.rpm, eng.tq, n);  gov = false;
end
end

function f = shift_imbalance(r, nE, Te, c)
% CVT axial force balance [N]: primary flyweights minus secondary spring and torque helix;
% positive moves the ratio towards rMin (upshift).
f = c.kFly * ((nE / 1000) * (nE / 1000)) - c.F0 - c.kSp * (c.rLow - r) - c.kHx * Te * r;
end

function [mu, dmu] = slip_curve(kappa, tire)
% Piecewise-linear friction coefficient mu(kappa), odd in kappa, and its slope d mu/d|kappa|.
s = abs(kappa);
if s <= tire.kPk
    mu = tire.muPk * s / tire.kPk;
    dmu = tire.muPk / tire.kPk;
elseif s < tire.kSl
    dmu = -(tire.muPk - tire.muSl) / (tire.kSl - tire.kPk);
    mu = tire.muPk + dmu * (s - tire.kPk);
else
    mu = tire.muSl;
    dmu = 0;
end
if kappa < 0
    mu = -mu;
end
end

function R = road_load(v, veh, crr)
% Rolling resistance plus aerodynamic drag [N] at speed v [m/s].
R = crr * veh.m * veh.g + 0.5 * veh.rho * veh.Cd * veh.A * (v * v);
end

function r = steady_ratio(nOut, c, eng)
% Equilibrium CVT ratio at output speed nOut [rev/min]: rLow or rMin when the force balance
% does not change sign between them, else its root by bisection to 1e-9.
nE = c.rLow * nOut;
if shift_imbalance(c.rLow, nE, engine_torque(nE, eng), c) <= 0
    r = c.rLow;
    return;
end
nE = c.rMin * nOut;
if shift_imbalance(c.rMin, nE, engine_torque(nE, eng), c) >= 0
    r = c.rMin;
    return;
end
a = c.rMin;
b = c.rLow;
while b - a > 1e-9
    mid = 0.5 * (a + b);
    nE = mid * nOut;
    if shift_imbalance(mid, nE, engine_torque(nE, eng), c) > 0
        b = mid;
    else
        a = mid;
    end
end
r = 0.5 * (a + b);
end

function F = steady_force(v, G, c, veh, tire, eng, crr)
% Steady-state drive force [N] at speed v: static axle load, tire slip in the linear range from
% the road load, the clutch slipping below its stall speed, else the CVT at its force balance.
Nr = veh.m * veh.g * veh.wfRear;
kappa = road_load(v, veh, crr) / Nr * tire.kPk / tire.muPk;
wW = (v + kappa * max(v, tire.vRef0)) / veh.rw;
nOut = wW * G * 60 / (2 * pi);
if c.rLow * nOut < c.nStall
    F = engine_torque(c.nStall, eng) * c.rLow * G * veh.eta / veh.rw;
else
    r = steady_ratio(nOut, c, eng);
    F = engine_torque(r * nOut, eng) * r * G * veh.eta / veh.rw;
end
end

function [vt, iters] = top_speed(G, c, veh, tire, eng, crr)
% Steady-state top speed: the root of steady drive force - road load, by bisection on
% [0.5, 45] m/s to 1e-6 m/s.
lo = 0.5;
hi = 45;
if steady_force(lo, G, c, veh, tire, eng, crr) - road_load(lo, veh, crr) <= 0 || ...
        steady_force(hi, G, c, veh, tire, eng, crr) - road_load(hi, veh, crr) >= 0
    error('w7:topspeed', 'top speed for G = %.3f is not bracketed by [%g, %g]', G, lo, hi);
end
iters = 0;
while hi - lo > 1e-6
    mid = 0.5 * (lo + hi);
    if steady_force(mid, G, c, veh, tire, eng, crr) - road_load(mid, veh, crr) > 0
        lo = mid;
    else
        hi = mid;
    end
    iters = iters + 1;
end
vt = 0.5 * (lo + hi);
end

function xv = refine_min(x, y, i)
% Abscissa of the vertex of the parabola through (x, y) at i-1, i, i+1 (the grid minimum and
% its neighbours); the grid point itself at either end of the grid.
if i > 1 && i < numel(x)
    x1 = x(i - 1); x2 = x(i); x3 = x(i + 1);
    y1 = y(i - 1); y2 = y(i); y3 = y(i + 1);
    num = (x2 - x1) * (x2 - x1) * (y2 - y3) - (x2 - x3) * (x2 - x3) * (y2 - y1);
    den = (x2 - x1) * (y2 - y3) - (x2 - x3) * (y2 - y1);
    xv = x2 - 0.5 * num / den;
else
    xv = x(i);
end
end

function [ok, F, sigma] = size_face(T, n, m, Np, Y, gd)
% Face width of one stage from the Lewis bending stress of its pinion: start at kMin*m and
% grow in steps of gd.Fstep until sigma <= gd.sLimit; not ok if F would exceed kMax*m.
% T pinion torque [N mm], n pinion speed [rev/min], m module [mm], Np pinion teeth.
d = m * Np;                       % pitch diameter [mm]
Wt = 2 * T / d;                   % tangential load [N]
V = pi * d * n / 60000;           % pitch-line speed [m/s]
Kv = (6.1 + V) / 6.1;             % Barth velocity factor, cut or milled profile
F = gd.kMin * m;
sigma = Kv * Wt / (F * m * Y);
ok = true;
while sigma > gd.sLimit
    F = F + gd.Fstep;
    if F > gd.kMax * m
        ok = false;
        break;
    end
    sigma = Kv * Wt / (F * m * Y);
end
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w7:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
