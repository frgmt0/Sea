%% w3_quarter_car.m -- Nonlinear quarter-car ride study with hand-written fixed-step RK4
%
% Sea acceptance workload 3. Original workload: vehicle and road parameters are invented for
% this benchmark. Methods are public textbook methods:
%   * 2-DOF quarter-car (sprung + unsprung mass) with an asymmetric (rebound/compression)
%     damper, a progressive bump stop, tire damping and tire lift-off (no tensile tire force).
%   * Classical 4th-order Runge-Kutta with a fixed step, written out by hand.
%   * Road input: a smooth cosine bump, and a random-phase harmonic road whose amplitudes
%     follow a power-law displacement PSD Gd(n) = Gd0*(n/n0)^-2 (phases from an in-script LCG).
%   * Damping sweep with ride (RMS body acceleration), road-holding (dynamic tire load) and
%     travel metrics, settling time after the bump, and the linear natural frequencies.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w3_quarter_car.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w3_quarter_car';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- vehicle parameters
p.ms       = 380;          % sprung mass [kg]
p.mu       = 42;           % unsprung mass [kg]
p.ks       = 24e3;         % suspension spring [N/m]
p.kt       = 210e3;        % tire vertical stiffness [N/m]
p.ct       = 60;           % tire damping [N s/m]
p.rebRatio = 1.6;          % rebound / compression damping ratio [-]
p.gap      = 0.065;        % compression travel before the bump stop engages [m]
p.kbs      = 180e3;        % bump stop linear stiffness [N/m]
p.kbs3     = 4e7;          % bump stop cubic stiffness [N/m^3]
g          = 9.81;         % gravity [m/s^2]
p.Wtot     = (p.ms + p.mu) * g;   % static tire load [N]

%% ---------------------------------------------------------------- road and simulation
speed  = 16;               % vehicle speed [m/s]
dt     = 1e-3;             % RK4 step [s]
tEnd   = 8.0;              % simulated time [s]
bumpX0 = 4.0;              % bump start position [m]
bumpL  = 0.6;              % bump length [m]
bumpH  = 0.07;             % bump height [m]
nWave  = 60;               % number of road harmonics [-]
nLo    = 0.05;             % lowest spatial frequency [cycles/m]
nHi    = 3.0;              % highest spatial frequency [cycles/m]
Gd0    = 256e-6;           % road PSD at n0 [m^3]
n0     = 0.1;              % reference spatial frequency [cycles/m]
rampT  = 1.0;              % roughness fade-in time [s]
seed   = 20240917;         % LCG seed for the road phases
cSweep = linspace(500, 6300, 30);   % compression damping coefficients [N s/m]
rmsStart = 1.0;            % start of the RMS evaluation window [s]

nStep = round(tEnd / dt);
t  = (0:nStep) * dt;               % output times
th = (0:2*nStep) * (dt / 2);       % half-step grid used by the RK4 stages
xh = speed * th;

% Bump road on the half-step grid (vectorized)
zBump = zeros(size(th));
vBump = zeros(size(th));
inB = xh >= bumpX0 & xh <= bumpX0 + bumpL;
arg = 2*pi*(xh(inB) - bumpX0) / bumpL;
zBump(inB) = bumpH / 2 * (1 - cos(arg));
vBump(inB) = bumpH / 2 * sin(arg) * (2*pi*speed / bumpL);

% Random-phase harmonic road (phases from a Park-Miller LCG)
nk = linspace(nLo, nHi, nWave);
dn = (nHi - nLo) / (nWave - 1);
Ak = sqrt(2 * Gd0 * (nk / n0).^(-2) * dn);
phik = zeros(1, nWave);
s = seed;
for k = 1:nWave
    s = mod(16807 * s, 2147483647);
    phik(k) = 2 * pi * s / 2147483647;
end
argR = 2*pi * xh(:) * nk + phik;               % (2*nStep+1) x nWave, implicit expansion
zRough0 = sin(argR) * Ak(:);
vRough0 = (cos(argR) .* (2*pi*speed*nk)) * Ak(:);
ramp = min(th(:) / rampT, 1);
rampD = (th(:) < rampT) / rampT;
zRough = (ramp .* zRough0).';
vRough = (ramp .* vRough0 + rampD .* zRough0).';

%% ---------------------------------------------------------------- linear modal check
Mlin = [p.ms 0; 0 p.mu];
Klin = [p.ks -p.ks; -p.ks p.ks + p.kt];
lam = sort(eig(Mlin \ Klin));
fNat = sqrt(lam) / (2*pi);
zeta = cSweep / (2 * sqrt(p.ks * p.ms));

%% ---------------------------------------------------------------- damping sweep
nC = numel(cSweep);
peakAcc = zeros(1, nC);  maxComp = zeros(1, nC);  maxExt = zeros(1, nC);
peakTire = zeros(1, nC); settle = zeros(1, nC);   overshoot = zeros(1, nC);
liftBump = zeros(1, nC);
rmsAcc = zeros(1, nC);   rmsTire = zeros(1, nC);  liftFrac = zeros(1, nC);
bsFrac = zeros(1, nC);   travelRough = zeros(1, nC);
tBump = bumpX0 / speed;
iRms = t >= rmsStart;
kRef = 8;                          % damping case whose time histories are exported
for ic = 1:nC
    c = cSweep(ic);
    % --- bump run
    [Y, acc, Ft] = simulate(p, c, zBump, vBump, dt, nStep);
    zs = Y(1, :);  zu = Y(2, :);
    peakAcc(ic)  = max(abs(acc));
    maxComp(ic)  = max(zu - zs);
    maxExt(ic)   = max(zs - zu);
    peakTire(ic) = max(Ft) / p.Wtot;
    liftBump(ic) = nnz(Ft == 0) * dt;
    overshoot(ic) = max(zs) / bumpH;
    band = 0.02 * max(abs(zs));
    last = find(abs(zs) > band, 1, 'last');
    if isempty(last) || last == numel(zs)
        settle(ic) = NaN;
    else
        settle(ic) = t(last + 1) - tBump;
    end
    if ic == kRef
        refZs = zs; refAcc = acc; refFt = Ft;
    end
    % --- rough-road run
    [Y, acc, Ft, bsOn] = simulate(p, c, zRough, vRough, dt, nStep);
    rmsAcc(ic)  = sqrt(mean(acc(iRms).^2));
    rmsTire(ic) = sqrt(mean(((Ft(iRms) - p.Wtot) / p.Wtot).^2));
    liftFrac(ic) = nnz(Ft(iRms) == 0) / nnz(iRms);
    bsFrac(ic)  = nnz(bsOn(iRms)) / nnz(iRms);
    travelRough(ic) = max(abs(Y(1, iRms) - Y(2, iRms)));
    if ic == kRef
        refRoughAcc = acc;
    end
end

% Combined ride / road-holding cost and its minimum (parabolic refinement)
J = rmsAcc / min(rmsAcc) + rmsTire / min(rmsTire);
[Jmin, iBest] = min(J);
if iBest > 1 && iBest < nC
    c3 = cSweep(iBest-1:iBest+1);
    J3 = J(iBest-1:iBest+1);
    coef = [c3(:).^2, c3(:), ones(3, 1)] \ J3(:);
    cBest = -coef(2) / (2 * coef(1));
else
    cBest = cSweep(iBest);
end

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W3  Quarter-car ride study (RK4, dt = %.1e s, %d steps per run) ===\n', ...
    dt, nStep);
fprintf('Linear natural frequencies: body %.3f Hz, wheel hop %.3f Hz\n', fNat(1), fNat(2));
fprintf('Road: %d harmonics, %.2f..%.2f cycles/m, speed %.1f m/s, bump %.0f mm x %.2f m\n\n', ...
    nWave, nLo, nHi, speed, bumpH*1e3, bumpL);
fprintf('%8s %6s | %9s %8s %8s %7s %8s | %9s %8s %7s %7s\n', 'c[Ns/m]', 'zeta', ...
    'peakAcc', 'comp[mm]', 'ext[mm]', 'tire', 'settle', 'rmsAcc', 'rmsTire', 'lift%', 'J');
for ic = 1:nC
    fprintf('%8.1f %6.3f | %9.4f %8.2f %8.2f %7.3f %8.3f | %9.5f %8.5f %7.3f %7.4f\n', ...
        cSweep(ic), zeta(ic), peakAcc(ic), maxComp(ic)*1e3, maxExt(ic)*1e3, ...
        peakTire(ic), settle(ic), rmsAcc(ic), rmsTire(ic), 100*liftFrac(ic), J(ic));
end
fprintf('Bump run: wheel off the ground for up to %.3f s; bump stop reached for c <= %.0f N s/m\n', ...
    max(liftBump), max([0, cSweep(maxComp > p.gap)]));
fprintf('\nBest compromise: c = %.1f N s/m on the grid (J = %.4f), refined c* = %.1f N s/m\n', ...
    cSweep(iBest), Jmin, cBest);
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W3 quarter car', 'Color', 'w');
    subplot(2, 2, 1);
    plot(t, refZs*1e3, t, zBump(1:2:end)*1e3);
    grid on; xlim([tBump - 0.2, tBump + 2.5]);
    xlabel('Time [s]'); ylabel('[mm]');
    legend('body', 'road');
    title(sprintf('Bump response, c = %.0f N s/m', cSweep(kRef)));

    subplot(2, 2, 2);
    plot(t, refRoughAcc);
    grid on; xlabel('Time [s]'); ylabel('Body acceleration [m/s^2]');
    title('Rough road');

    subplot(2, 2, 3);
    yyaxis left;  plot(cSweep, rmsAcc, '-o'); ylabel('RMS acc [m/s^2]');
    yyaxis right; plot(cSweep, rmsTire, '-s'); ylabel('RMS dyn. tire load [-]');
    grid on; xlabel('Compression damping [N s/m]');
    title('Ride vs road holding');

    subplot(2, 2, 4);
    bar(cSweep, settle);
    xlabel('Compression damping [N s/m]'); ylabel('Settling time [s]');
    title('Settling after bump (2 % band)');
    if SEA_SAVE_FIGURES
        outDir = fullfile(wlDir, 'output');
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        exportgraphics(fig, fullfile(outDir, [wlName '.png']), 'Resolution', 150);
    end
end

%% ---------------------------------------------------------------- reference export
if SEA_EXPORT_REFERENCE
    ref = struct();
    ref.workload = wlName;
    ref.f_nat = fNat.';
    ref.road_phase = phik;
    ref.road_amp = Ak;
    ref.road_rough = zRough(1:2:end);
    ref.c = cSweep;
    ref.zeta = zeta;
    ref.peak_acc = peakAcc;
    ref.max_comp = maxComp;
    ref.max_ext = maxExt;
    ref.peak_tire = peakTire;
    ref.overshoot = overshoot;
    ref.settle = settle;
    ref.rms_acc = rmsAcc;
    ref.rms_tire = rmsTire;
    ref.lift_time_bump = liftBump;
    ref.lift_frac = liftFrac;
    ref.bumpstop_frac = bsFrac;
    ref.travel_rough = travelRough;
    ref.J = J;
    ref.i_best = iBest;
    ref.c_best = cBest;
    ref.k_ref = kRef;
    ref.ref_zs = refZs;
    ref.ref_acc = refAcc;
    ref.ref_tire = refFt;
    ref.ref_rough_acc = refRoughAcc;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function [Y, acc, Ft, bsOn] = simulate(p, c, zr, vr, dt, nStep)
% Fixed-step RK4. zr/vr hold the road on the half-step grid (2*nStep+1 samples).
% Outputs are sampled at the step starts t_k, k = 1..nStep+1.
Y = zeros(4, nStep + 1);
acc = zeros(1, nStep + 1);
Ft = zeros(1, nStep + 1);
bsOn = false(1, nStep + 1);
x = zeros(4, 1);
h2 = dt / 2;
h6 = dt / 6;
for k = 1:nStep
    j = 2*k - 1;
    [k1, Ft(k), Fbs] = qc_deriv(x, zr(j), vr(j), c, p);
    k2 = qc_deriv(x + h2*k1, zr(j + 1), vr(j + 1), c, p);
    k3 = qc_deriv(x + h2*k2, zr(j + 1), vr(j + 1), c, p);
    k4 = qc_deriv(x + dt*k3, zr(j + 2), vr(j + 2), c, p);
    Y(:, k) = x;
    acc(k) = k1(3);
    bsOn(k) = Fbs > 0;
    x = x + h6*(k1 + 2*k2 + 2*k3 + k4);
end
[kEnd, Ft(nStep + 1), Fbs] = qc_deriv(x, zr(2*nStep + 1), vr(2*nStep + 1), c, p);
Y(:, nStep + 1) = x;
acc(nStep + 1) = kEnd(3);
bsOn(nStep + 1) = Fbs > 0;
end

function [dx, Ft, Fbs] = qc_deriv(x, zr, vr, c, p)
% State x = [zs; zu; vs; vu] measured from static equilibrium.
zs = x(1); zu = x(2); vs = x(3); vu = x(4);
vrel = vs - vu;
if vrel > 0
    cdamp = c * p.rebRatio;     % rebound (extension)
else
    cdamp = c;                 % compression
end
Fsusp = -p.ks*(zs - zu) - cdamp*vrel;
dc = zu - zs - p.gap;
Fbs = 0;
if dc > 0
    Fbs = p.kbs*dc + p.kbs3*(dc*dc*dc);
end
Fsusp = Fsusp + Fbs;
Ft = p.Wtot + p.kt*(zr - zu) + p.ct*(vr - vu);
if Ft < 0
    Ft = 0;                    % tire lift-off
end
dx = [vs; vu; Fsusp / p.ms; (-Fsusp + Ft - p.Wtot) / p.mu];
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w3:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
