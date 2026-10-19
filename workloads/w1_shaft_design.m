%% w1_shaft_design.m -- Gear-shaft sizing study (scalar-heavy design calculation + sweeps)
%
% Sea acceptance workload 1. Original workload: all hardware, material and load values are
% invented for this benchmark. Methods are public textbook methods:
%   * DE-Goodman fatigue criterion for a rotating shaft (fully reversed bending, mean torque
%     plus a torque ripple), Marin surface/size/reliability factors.
%   * Peterson notch-sensitivity q = 1/(1 + a/r).
%   * First-yield check with the von Mises maximum stress.
%   * Dunkerley combination of shaft and gear-mass critical speeds.
%   * Ball-bearing basic rating life L10 = (C/P)^3 revolutions.
%
% The required diameter has no closed form because the Marin size factor and the notch
% radius both depend on the diameter, so it is found by bisection.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w1_shaft_design.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w1_shaft_design';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- configuration
cfg.finish      = 'machined';  % surface finish: ground | machined | hot-rolled | as-forged
cfg.reliability = 0.99;        % required reliability [-], one of the tabulated values
cfg.nTarget     = 2.0;         % required safety factor (fatigue and yield) [-]
cfg.lifeTarget  = 20000;       % required bearing L10 life [h]

% Shaft and gear geometry (invented)
geo.L        = 0.420;          % bearing span [m]
geo.a        = 0.150;          % gear distance from left bearing [m]
geo.rg       = 0.085;          % gear pitch radius [m]
geo.phi      = 20*pi/180;      % gear pressure angle [rad]
geo.mGear    = 9.5;            % gear mass [kg]
geo.ripple   = 0.12;           % alternating torque / mean torque [-]
geo.rRatio   = 0.04;           % shoulder fillet radius / diameter [-]
geo.Kt       = 1.90;           % theoretical stress concentration, bending [-]
geo.Kts      = 1.45;           % theoretical stress concentration, torsion [-]
geo.seatRatio = 1/1.20;        % bearing seat diameter / shoulder diameter [-]

% Material table (invented values, steels of increasing strength)
mats = struct( ...
    'name', {'CS-low', 'CS-med', 'AS-QT1', 'AS-QT2'}, ...
    'Sut',  {470e6,     640e6,    1030e6,   1460e6}, ...   % ultimate strength [Pa]
    'Sy',   {380e6,     530e6,    890e6,    1290e6}, ...   % yield strength [Pa]
    'E',    {205e9,     205e9,    207e9,    207e9},  ...   % Young's modulus [Pa]
    'rho',  {7860,      7850,     7850,     7840});        % density [kg/m^3]

% Invented deep-groove ball-bearing catalog: bore [mm], dynamic rating C [N]
brgBore = [15 17 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100];
brgC    = [7.9 9.7 12.9 14.2 19.8 25.9 31.2 33.9 35.6 44.1 52.8 56.6 62.4 67.1 71.0 ...
           84.0 96.5 109.0 113.5] * 1e3;
brgLabel = cell(1, numel(brgBore));
for i = 1:numel(brgBore)
    brgLabel{i} = sprintf('DG-%03d', brgBore(i));
end

% Preferred shaft diameters (R20 series) [mm]
stdD = [10 11.2 12.5 14 16 18 20 22.4 25 28 31.5 35.5 40 45 50 56 63 71 80 90 100 ...
        112 125 140 160 180 200 224 250 280];

% Design cases
caseLabel = {'Conveyor drive', 'Pump coupling', 'Mixer gearbox', 'Fan jackshaft', 'Winch input'};
casePower = [7.5 22 15 4 30] * 1e3;          % transmitted power [W]
caseRpm   = [960 2900 420 1450 720];          % shaft speed [rev/min]
caseMat   = [2 2 3 1 4];                      % index into mats
caseFinish = {'machined', 'ground', 'machined', 'hot-rolled', 'ground'};

%% ---------------------------------------------------------------- validation
surface_factor(cfg.finish, mats(1).Sut);   % validates cfg.finish (errors if unknown)
ke = reliability_factor(cfg.reliability);
if cfg.nTarget <= 1
    error('w1:config', 'nTarget must exceed 1, got %g', cfg.nTarget);
end
if geo.a <= 0 || geo.a >= geo.L
    error('w1:config', 'gear position a=%g must lie inside the span L=%g', geo.a, geo.L);
end
if numel(caseLabel) ~= numel(casePower) || numel(casePower) ~= numel(caseRpm) || ...
        numel(caseRpm) ~= numel(caseMat) || numel(caseMat) ~= numel(caseFinish)
    error('w1:config', 'design case tables have inconsistent lengths');
end

%% ---------------------------------------------------------------- design cases
nCase = numel(caseLabel);
res = struct('dReq', zeros(1, nCase), 'iters', zeros(1, nCase), 'dStd', zeros(1, nCase), ...
    'nf', zeros(1, nCase), 'ny', zeros(1, nCase), 'Se', zeros(1, nCase), ...
    'Kf', zeros(1, nCase), 'Kfs', zeros(1, nCase), 'torque', zeros(1, nCase), ...
    'Mmax', zeros(1, nCase), 'critRpm', zeros(1, nCase), 'critRatio', zeros(1, nCase), ...
    'R1', zeros(1, nCase), 'R2', zeros(1, nCase), 'brgIdx', zeros(1, nCase), ...
    'L10h', zeros(1, nCase), 'mass', zeros(1, nCase));
caseBearing = cell(1, nCase);
for c = 1:nCase
    mat = mats(caseMat(c));
    p = make_params(geo, cfg, mat, caseFinish{c}, ke);
    [T, Mmax, F] = shaft_loads(casePower(c), caseRpm(c), geo);
    [dReq, iters] = bisect_diameter(Mmax, T, p, cfg.nTarget, 0.005, 0.300, 1e-7);
    k = find(stdD >= dReq*1e3, 1);
    if isempty(k)
        error('w1:design', 'case "%s" needs d=%.1f mm, above the preferred range', ...
            caseLabel{c}, dReq*1e3);
    end
    dStd = stdD(k) / 1e3;
    [nf, ny, Se, Kf, Kfs] = shaft_safety(dStd, Mmax, T, p);
    [critRpm, ~, ~] = critical_speed(dStd, geo, mat);
    R1 = F * (geo.L - geo.a) / geo.L;
    R2 = F * geo.a / geo.L;
    dSeat = dStd * geo.seatRatio;
    Pbrg = max(R1, R2);
    life = (brgC ./ Pbrg).^3 * 1e6 / (60 * caseRpm(c));
    b = find(brgBore >= dSeat*1e3 & life >= cfg.lifeTarget, 1);
    if isempty(b)
        caseBearing{c} = 'none';
        res.brgIdx(c) = 0;
        res.L10h(c) = NaN;
    else
        caseBearing{c} = brgLabel{b};
        res.brgIdx(c) = b;
        res.L10h(c) = round(life(b));
    end
    res.dReq(c) = dReq;   res.iters(c) = iters;  res.dStd(c) = dStd;
    res.nf(c) = nf;       res.ny(c) = ny;        res.Se(c) = Se;
    res.Kf(c) = Kf;       res.Kfs(c) = Kfs;      res.torque(c) = T;
    res.Mmax(c) = Mmax;   res.critRpm(c) = critRpm;
    res.critRatio(c) = critRpm / caseRpm(c);
    res.R1(c) = R1;       res.R2(c) = R2;
    res.mass(c) = mat.rho * pi * dStd^2 / 4 * geo.L;
end

%% ---------------------------------------------------------------- sweep A: material curves
% Safety factors versus diameter for every material at design case 1 loads (vectorized).
dSweep = linspace(0.010, 0.080, 2001);
[T1, M1] = shaft_loads(casePower(1), caseRpm(1), geo);
nMat = numel(mats);
nfCurve = zeros(nMat, numel(dSweep));
nyCurve = zeros(nMat, numel(dSweep));
dMinMat = zeros(1, nMat);
for m = 1:nMat
    p = make_params(geo, cfg, mats(m), cfg.finish, ke);
    [nfCurve(m, :), nyCurve(m, :)] = shaft_safety(dSweep, M1, T1, p);
    ok = find(min(nfCurve(m, :), nyCurve(m, :)) >= cfg.nTarget, 1);
    if isempty(ok)
        dMinMat(m) = NaN;
    else
        dMinMat(m) = dSweep(ok);
    end
end

%% ---------------------------------------------------------------- sweep B: power x speed grid
% Required diameter over a power/speed grid, by scalar bisection at every grid point,
% then re-checked with a vectorized bisection over the whole grid at once.
gridP   = linspace(0.5e3, 45e3, 90);     % [W]
gridRpm = linspace(250, 3600, 120);      % [rev/min]
pGrid = make_params(geo, cfg, mats(caseMat(1)), cfg.finish, ke);
dGrid = zeros(numel(gridP), numel(gridRpm));
itGrid = zeros(numel(gridP), numel(gridRpm));
yieldLimited = false(numel(gridP), numel(gridRpm));
for i = 1:numel(gridP)
    for j = 1:numel(gridRpm)
        [Tg, Mg] = shaft_loads(gridP(i), gridRpm(j), geo);
        [dGrid(i, j), itGrid(i, j)] = bisect_diameter(Mg, Tg, pGrid, cfg.nTarget, ...
            0.005, 0.300, 1e-7);
        [nfg, nyg] = shaft_safety(dGrid(i, j), Mg, Tg, pGrid);
        yieldLimited(i, j) = nyg < nfg;
    end
end

% Vectorized bisection over the whole grid (fusion target: every line is element-wise)
[RPM, PW] = meshgrid(gridRpm, gridP);
omegaG = 2*pi*RPM/60;
TG = PW ./ omegaG;
FG = TG / geo.rg / cos(geo.phi);
MG = FG * geo.a * (geo.L - geo.a) / geo.L;
lo = 0.005 * ones(size(PW));
hi = 0.300 * ones(size(PW));
for it = 1:40
    mid = 0.5 * (lo + hi);
    [nfv, nyv] = shaft_safety(mid, MG, TG, pGrid);
    up = min(nfv, nyv) < cfg.nTarget;
    lo(up) = mid(up);
    hi(~up) = mid(~up);
end
dGridVec = 0.5 * (lo + hi);
vecMaxDiff = max(abs(dGridVec(:) - dGrid(:)));

[dGridMax, kMax] = max(dGrid(:));
[iMax, jMax] = ind2sub(size(dGrid), kMax);
[dGridMin, kMin] = min(dGrid(:));
[iMin, jMin] = ind2sub(size(dGrid), kMin);
fracYield = nnz(yieldLimited) / numel(yieldLimited);

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W1  Gear-shaft sizing study ===\n');
fprintf('Finish: %s   reliability: %.4g (ke = %.3f)   target n: %.2f   bearing life: %d h\n', ...
    cfg.finish, cfg.reliability, ke, cfg.nTarget, cfg.lifeTarget);
fprintf('Span %.0f mm, gear at %.0f mm, pitch radius %.0f mm, ripple %.0f %%\n\n', ...
    geo.L*1e3, geo.a*1e3, geo.rg*1e3, geo.ripple*100);

fprintf('%-15s %7s %6s %7s %8s %8s %6s %6s %6s %8s %7s %-7s %8s\n', 'Case', 'P[kW]', ...
    'rpm', 'Mat', 'dReq[mm]', 'dStd[mm]', 'it', 'nf', 'ny', 'crit[rpm]', 'ratio', ...
    'Bearing', 'L10[h]');
for c = 1:nCase
    fprintf('%-15s %7.2f %6d %7s %8.3f %8.1f %6d %6.3f %6.3f %8.0f %7.2f %-7s %8d\n', ...
        caseLabel{c}, casePower(c)/1e3, caseRpm(c), mats(caseMat(c)).name, ...
        res.dReq(c)*1e3, res.dStd(c)*1e3, res.iters(c), res.nf(c), res.ny(c), ...
        res.critRpm(c), res.critRatio(c), caseBearing{c}, res.L10h(c));
end

fprintf('\nMaterial comparison at case "%s" loads (T = %.2f N m, M = %.2f N m):\n', ...
    caseLabel{1}, T1, M1);
for m = 1:nMat
    fprintf('  %-8s Sut %5.0f MPa  min d for n >= %.1f: %7.3f mm\n', mats(m).name, ...
        mats(m).Sut/1e6, cfg.nTarget, dMinMat(m)*1e3);
end

fprintf('\nPower x speed grid (%d x %d points, material %s):\n', numel(gridP), ...
    numel(gridRpm), mats(caseMat(1)).name);
fprintf('  largest  d = %7.3f mm at P = %6.2f kW, %6.1f rpm\n', dGridMax*1e3, ...
    gridP(iMax)/1e3, gridRpm(jMax));
fprintf('  smallest d = %7.3f mm at P = %6.2f kW, %6.1f rpm\n', dGridMin*1e3, ...
    gridP(iMin)/1e3, gridRpm(jMin));
fprintf('  yield-limited points: %.2f %%   total bisection iterations: %d\n', ...
    100*fracYield, sum(itGrid(:)));
fprintf('  scalar vs vectorized bisection max difference: %.3e m\n', vecMaxDiff);
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W1 shaft design', 'Color', 'w');
    tl = tiledlayout(fig, 2, 2);
    nexttile(tl);
    hold on;
    for m = 1:nMat
        plot(dSweep*1e3, min(nfCurve(m, :), nyCurve(m, :)), 'LineWidth', 1.2);
    end
    plot(dSweep([1 end])*1e3, cfg.nTarget*[1 1], 'k--');
    hold off;
    ylim([0 6]); grid on;
    xlabel('Diameter [mm]'); ylabel('Safety factor [-]');
    legend([{mats.name}, {'target'}], 'Location', 'northwest');
    title('Safety factor vs diameter');

    nexttile(tl);
    contour(gridRpm, gridP/1e3, dGrid*1e3, 15, 'ShowText', 'on');
    xlabel('Speed [rpm]'); ylabel('Power [kW]');
    title('Required diameter [mm]');

    nexttile(tl);
    barh(res.dStd*1e3);
    set(gca, 'YTickLabel', caseLabel);
    xlabel('Standard diameter [mm]');
    title('Design cases');

    nexttile(tl);
    plot(gridRpm, dGrid(end, :)*1e3, gridRpm, dGrid(round(end/2), :)*1e3, ...
        gridRpm, dGrid(1, :)*1e3);
    grid on;
    xlabel('Speed [rpm]'); ylabel('Required diameter [mm]');
    legend(sprintf('%.1f kW', gridP(end)/1e3), sprintf('%.1f kW', ...
        gridP(round(end/2))/1e3), sprintf('%.1f kW', gridP(1)/1e3));
    title('Diameter vs speed');
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
    ref.ke = ke;
    ref.case_label = caseLabel;
    ref.case_bearing = caseBearing;
    ref.case_dReq = res.dReq;
    ref.case_iters = res.iters;
    ref.case_dStd = res.dStd;
    ref.case_nf = res.nf;
    ref.case_ny = res.ny;
    ref.case_Se = res.Se;
    ref.case_Kf = res.Kf;
    ref.case_Kfs = res.Kfs;
    ref.case_torque = res.torque;
    ref.case_Mmax = res.Mmax;
    ref.case_critRpm = res.critRpm;
    ref.case_R1 = res.R1;
    ref.case_R2 = res.R2;
    ref.case_L10h = res.L10h;
    ref.case_mass = res.mass;
    ref.sweep_d = dSweep;
    ref.sweep_nf = nfCurve;
    ref.sweep_ny = nyCurve;
    ref.mat_dMin = dMinMat;
    ref.grid_P = gridP;
    ref.grid_rpm = gridRpm;
    ref.grid_d = dGrid;
    ref.grid_iters_total = sum(itGrid(:));
    ref.grid_yield_fraction = fracYield;
    ref.grid_d_max = dGridMax;
    ref.grid_d_min = dGridMin;
    ref.grid_vec_maxdiff = vecMaxDiff;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function p = make_params(geo, cfg, mat, finish, ke)
% Collect the material- and finish-dependent constants used by shaft_safety.
p.Sut = mat.Sut;
p.Sy = mat.Sy;
p.ka = surface_factor(finish, mat.Sut);
p.ke = ke;
if mat.Sut <= 1400e6
    p.SePrime = 0.5 * mat.Sut;
else
    p.SePrime = 700e6;
end
p.aPeterson = 0.0254e-3 * (2070e6 / mat.Sut)^1.8;   % Peterson characteristic length [m]
p.rRatio = geo.rRatio;
p.Kt = geo.Kt;
p.Kts = geo.Kts;
p.ripple = geo.ripple;
p.nTarget = cfg.nTarget;
end

function ka = surface_factor(finish, Sut)
% Marin surface factor ka = a * Sut[MPa]^b.
switch lower(finish)
    case 'ground'
        a = 1.58;  b = -0.085;
    case 'machined'
        a = 4.51;  b = -0.265;
    case 'hot-rolled'
        a = 57.7;  b = -0.718;
    case 'as-forged'
        a = 272;   b = -0.995;
    otherwise
        error('w1:config', 'unknown surface finish "%s"', finish);
end
ka = a * (Sut / 1e6)^b;
end

function ke = reliability_factor(R)
% Marin reliability factor from the standard table.
table = [0.50 1.000; 0.90 0.897; 0.95 0.868; 0.99 0.814; 0.999 0.753; 0.9999 0.702];
k = find(abs(table(:, 1) - R) < 1e-12, 1);
if isempty(k)
    error('w1:config', 'reliability %.6g is not tabulated', R);
end
ke = table(k, 2);
end

function [T, Mmax, F] = shaft_loads(P, rpm, geo)
% Torque, maximum bending moment and resultant gear force for power P [W] at rpm.
omega = 2*pi*rpm/60;
T = P / omega;
F = T / geo.rg / cos(geo.phi);
Mmax = F * geo.a * (geo.L - geo.a) / geo.L;
end

function [nf, ny, Se, Kf, Kfs] = shaft_safety(d, Mmax, T, p)
% DE-Goodman fatigue and von Mises yield safety factors; element-wise in d, Mmax, T.
dmm = d * 1e3;
kb = ones(size(dmm));
m1 = dmm > 2.79 & dmm <= 51;
kb(m1) = 1.24 * dmm(m1).^(-0.107);
m2 = dmm > 51;
kb(m2) = 1.51 * min(dmm(m2), 254).^(-0.157);
Se = p.ka .* kb .* p.ke .* p.SePrime;
r = p.rRatio * d;
q = 1 ./ (1 + p.aPeterson ./ r);
qs = 1 ./ (1 + 0.6 * p.aPeterson ./ r);
Kf = 1 + q .* (p.Kt - 1);
Kfs = 1 + qs .* (p.Kts - 1);
Ma = Mmax;            % rotating shaft: fully reversed bending
Mm = 0;
Tm = T;
Ta = p.ripple * T;
c16 = 16 ./ (pi * d.^3);
alt = sqrt(4*(Kf.*Ma).^2 + 3*(Kfs.*Ta).^2);
mmean = sqrt(4*(Kf.*Mm).^2 + 3*(Kfs.*Tm).^2);
nf = 1 ./ (c16 .* (alt ./ Se + mmean ./ p.Sut));
sigMax = sqrt((32*Kf.*(Mm + Ma) ./ (pi*d.^3)).^2 + 3*(16*Kfs.*(Tm + Ta) ./ (pi*d.^3)).^2);
ny = p.Sy ./ sigMax;
end

function [d, iters] = bisect_diameter(Mmax, T, p, nTarget, lo, hi, tol)
% Smallest diameter with min(nf, ny) >= nTarget, by bisection on [lo, hi].
[nfLo, nyLo] = shaft_safety(lo, Mmax, T, p);
[nfHi, nyHi] = shaft_safety(hi, Mmax, T, p);
if min(nfLo, nyLo) >= nTarget
    d = lo; iters = 0;
    return;
end
if min(nfHi, nyHi) < nTarget
    error('w1:bisect', 'no diameter up to %.3f m reaches n = %.2f', hi, nTarget);
end
iters = 0;
while hi - lo > tol
    mid = 0.5 * (lo + hi);
    [nfM, nyM] = shaft_safety(mid, Mmax, T, p);
    if min(nfM, nyM) < nTarget
        lo = mid;
    else
        hi = mid;
    end
    iters = iters + 1;
end
d = hi;
end

function [critRpm, wShaft, wGear] = critical_speed(d, geo, mat)
% First critical speed by Dunkerley: uniform simply supported shaft plus gear point mass.
I = pi * d^4 / 64;
mPerLen = mat.rho * pi * d^2 / 4;
wShaft = (pi / geo.L)^2 * sqrt(mat.E * I / mPerLen);
b = geo.L - geo.a;
kGear = 3 * mat.E * I * geo.L / (geo.a^2 * b^2);
wGear = sqrt(kGear / geo.mGear);
wCrit = 1 / sqrt(1/wShaft^2 + 1/wGear^2);
critRpm = wCrit * 60 / (2*pi);
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w1:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
