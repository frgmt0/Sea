%% w5_tolerance_mc.m -- Monte Carlo tolerance stack-up of a bearing/gear axial stack
%
% Sea acceptance workload 5. Original workload: the assembly, dimensions, tolerances and
% specification limits are invented for this benchmark. Methods are public textbook methods:
%   * Linear 1D tolerance chain (axial end play of a gear shaft in an aluminium housing).
%   * Worst-case and root-sum-square (RSS) analytic limits.
%   * Monte Carlo with an in-script Park-Miller LCG (no rand/randn): Box-Muller normals,
%     uniform and symmetric triangular (inverse CDF) distributions, a uniform operating
%     temperature with per-part thermal expansion.
%   * Statistics: mean, std, Cpk, fixed-edge histogram counts, percentiles (midpoint rule),
%     variance contributions, and a tolerance-scaling sweep with yield.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w5_tolerance_mc.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w5_tolerance_mc';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- inputs
% Chain members: sign +1 opens the gap, -1 closes it. Lengths in mm, CTE in 1/K.
dims = struct( ...
    'name',  {'housing depth', 'gasket', 'bearing 1', 'spacer', 'gear hub', 'bearing 2', ...
              'retaining ring'}, ...
    'nom',   {84.00,  0.25,  19.00,  24.75,  22.00,  17.00,  1.20}, ...
    'tol',   {0.050,  0.040, 0.012,  0.030,  0.040,  0.012,  0.030}, ...
    'dist',  {'normal', 'triangular', 'normal', 'uniform', 'triangular', 'normal', ...
              'uniform'}, ...
    'sign',  {+1, +1, -1, -1, -1, -1, -1}, ...
    'alpha', {23.1e-6, 80e-6, 11.5e-6, 11.5e-6, 11.5e-6, 11.5e-6, 12.0e-6});
nSample = 1000000;       % Monte Carlo samples [-]
seed    = 7340117;       % LCG seed [-]
Tref    = 20;            % reference (inspection) temperature [degC]
Tlo     = 20;            % operating temperature range, uniform [degC]
Thi     = 95;
LSL     = 0.20;          % cold end-play lower limit [mm]
USL     = 0.42;          % cold end-play upper limit [mm]
hotMax  = 0.45;          % hot end-play upper limit [mm]
histLo  = 0.0;           % histogram range for the cold gap [mm]
histHi  = 0.6;
nBin    = 60;
pct     = [0.135 2.5 50 97.5 99.865];   % percentiles to report [%]
scale   = linspace(0.4, 1.6, 25);       % tolerance scaling factors for the sweep [-]
yieldTarget = 0.9973;

nDim = numel(dims);
for d = 1:nDim
    switch dims(d).dist
        case {'normal', 'uniform', 'triangular'}
        otherwise
            error('w5:config', 'dimension "%s": unknown distribution "%s"', ...
                dims(d).name, dims(d).dist);
    end
    if dims(d).tol <= 0
        error('w5:config', 'dimension "%s": tolerance must be positive', dims(d).name);
    end
end

%% ---------------------------------------------------------------- analytic limits
nomGap = 0;
wcHalf = 0;
rssVar = 0;
sigmaDim = zeros(1, nDim);
for d = 1:nDim
    nomGap = nomGap + dims(d).sign * dims(d).nom;
    wcHalf = wcHalf + dims(d).tol;
    switch dims(d).dist
        case 'normal'
            sigmaDim(d) = dims(d).tol / 3;
        case 'uniform'
            sigmaDim(d) = dims(d).tol / sqrt(3);
        case 'triangular'
            sigmaDim(d) = dims(d).tol / sqrt(6);
    end
    rssVar = rssVar + sigmaDim(d)^2;
end
rssSigma = sqrt(rssVar);

%% ---------------------------------------------------------------- sampling
s = seed;
dev = zeros(nSample, nDim);           % deviation of each dimension from nominal [mm]
for d = 1:nDim
    switch dims(d).dist
        case 'normal'
            [u, s] = lcg_fill(s, 2 * nSample);
            u1 = u(1:2:end);
            u2 = u(2:2:end);
            z = sqrt(-2 * log(u1)) .* cos(2 * pi * u2);
            dev(:, d) = z * (dims(d).tol / 3);
        case 'uniform'
            [u, s] = lcg_fill(s, nSample);
            dev(:, d) = dims(d).tol * (2 * u - 1);
        case 'triangular'
            [u, s] = lcg_fill(s, nSample);
            t = dims(d).tol;
            lowHalf = u < 0.5;
            v = zeros(nSample, 1);
            v(lowHalf) = -t + t * sqrt(2 * u(lowHalf));
            v(~lowHalf) = t - t * sqrt(2 * (1 - u(~lowHalf)));
            dev(:, d) = v;
    end
end
[u, s] = lcg_fill(s, nSample);
Top = Tlo + (Thi - Tlo) * u;
lcgFinal = s;

nom = [dims.nom];
sgn = [dims.sign];
alpha = [dims.alpha];
[gapCold, gapHot] = stack_gap(dev, 1, nom, sgn, alpha, Top, Tref);

%% ---------------------------------------------------------------- statistics
muC = mean(gapCold);   sdC = std(gapCold);
muH = mean(gapHot);    sdH = std(gapHot);
cpk = min(USL - muC, muC - LSL) / (3 * sdC);
nLow = nnz(gapCold < LSL);
nHigh = nnz(gapCold > USL);
nHot = nnz(gapHot > hotMax);
pass = gapCold >= LSL & gapCold <= USL & gapHot <= hotMax;
yieldMC = nnz(pass) / nSample;

binW = (histHi - histLo) / nBin;
idx = floor((gapCold - histLo) / binW) + 1;
inRange = idx >= 1 & idx <= nBin;
counts = accumarray(idx(inRange), 1, [nBin 1]).';
underflow = nnz(idx < 1);
overflow = nnz(idx > nBin);
edges = histLo + (0:nBin) * binW;

sortedC = sort(gapCold);
sortedH = sort(gapHot);
pC = zeros(1, numel(pct));
pH = zeros(1, numel(pct));
for k = 1:numel(pct)
    pC(k) = prctile_mid(sortedC, pct(k));
    pH(k) = prctile_mid(sortedH, pct(k));
end

contrib = zeros(1, nDim);
for d = 1:nDim
    contrib(d) = var(dev(:, d)) / var(gapCold);
end
[~, rnk] = sort(contrib, 'descend');

%% ---------------------------------------------------------------- tolerance scaling sweep
yieldScale = zeros(1, numel(scale));
cpkScale = zeros(1, numel(scale));
for k = 1:numel(scale)
    [gc, gh] = stack_gap(dev, scale(k), nom, sgn, alpha, Top, Tref);
    ok = gc >= LSL & gc <= USL & gh <= hotMax;
    yieldScale(k) = nnz(ok) / nSample;
    m = mean(gc);
    cpkScale(k) = min(USL - m, m - LSL) / (3 * std(gc));
end
kOk = find(yieldScale >= yieldTarget, 1, 'last');
if isempty(kOk)
    scaleMax = NaN;
else
    scaleMax = scale(kOk);
end

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W5  Monte Carlo tolerance stack-up (%d samples) ===\n', nSample);
fprintf('%-15s %8s %7s %-10s %4s %9s\n', 'Dimension', 'nom[mm]', 'tol', 'dist', 'sgn', ...
    'var share');
for d = 1:nDim
    fprintf('%-15s %8.3f %7.3f %-10s %+4d %8.2f%%\n', dims(d).name, dims(d).nom, ...
        dims(d).tol, dims(d).dist, dims(d).sign, 100 * contrib(d));
end
fprintf('\nNominal gap %.4f mm; worst case %.4f .. %.4f mm; RSS 3-sigma %.4f .. %.4f mm\n', ...
    nomGap, nomGap - wcHalf, nomGap + wcHalf, nomGap - 3*rssSigma, nomGap + 3*rssSigma);
fprintf('Cold gap: mean %.5f, std %.5f, min %.5f, max %.5f mm, Cpk %.3f\n', muC, sdC, ...
    sortedC(1), sortedC(end), cpk);
fprintf('Hot gap : mean %.5f, std %.5f, min %.5f, max %.5f mm\n', muH, sdH, sortedH(1), ...
    sortedH(end));
fprintf('Rejects: %d below LSL, %d above USL, %d too loose when hot; yield %.4f %%\n', ...
    nLow, nHigh, nHot, 100 * yieldMC);
fprintf('Percentiles (cold / hot) [mm]:\n');
for k = 1:numel(pct)
    fprintf('  P%-7.3f %9.5f %9.5f\n', pct(k), pC(k), pH(k));
end
fprintf('Largest contributors: %s, %s, %s\n', dims(rnk(1)).name, dims(rnk(2)).name, ...
    dims(rnk(3)).name);
fprintf('Histogram: %d bins of %.3f mm, underflow %d, overflow %d, fullest bin %d\n', ...
    nBin, binW, underflow, overflow, max(counts));
fprintf('Largest tolerance scale with yield >= %.2f %%: %.2f\n', 100*yieldTarget, scaleMax);
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W5 tolerance stack-up', 'Color', 'w');
    subplot(2, 2, 1);
    bar(edges(1:end-1) + binW/2, counts, 1);
    hold on;
    yl = ylim;
    plot([LSL LSL], yl, 'r--', [USL USL], yl, 'r--');
    hold off;
    xlabel('Cold end play [mm]'); ylabel('Count');
    title('Cold end-play histogram');

    subplot(2, 2, 2);
    barh(100 * contrib(rnk));
    set(gca, 'YTickLabel', {dims(rnk).name}, 'YDir', 'reverse');
    xlabel('Variance share [%]');
    title('Contributors');

    subplot(2, 2, 3);
    plot(scale, 100 * yieldScale, '-o');
    grid on; xlabel('Tolerance scale [-]'); ylabel('Yield [%]');
    title('Yield vs tolerance scale');

    subplot(2, 2, 4);
    plot(scale, cpkScale, '-s');
    grid on; xlabel('Tolerance scale [-]'); ylabel('Cpk [-]');
    title('Cpk vs tolerance scale');
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
    ref.n_sample = nSample;
    ref.lcg_final = lcgFinal;
    ref.first_dev = dev(1:10, :);
    ref.first_top = Top(1:10).';
    ref.nom_gap = nomGap;
    ref.wc_half = wcHalf;
    ref.rss_sigma = rssSigma;
    ref.mean_cold = muC;
    ref.std_cold = sdC;
    ref.mean_hot = muH;
    ref.std_hot = sdH;
    ref.min_cold = sortedC(1);
    ref.max_cold = sortedC(end);
    ref.min_hot = sortedH(1);
    ref.max_hot = sortedH(end);
    ref.cpk = cpk;
    ref.n_low = nLow;
    ref.n_high = nHigh;
    ref.n_hot = nHot;
    ref.yield = yieldMC;
    ref.hist_counts = counts;
    ref.hist_underflow = underflow;
    ref.hist_overflow = overflow;
    ref.pct = pct;
    ref.pct_cold = pC;
    ref.pct_hot = pH;
    ref.contrib = contrib;
    ref.rank = rnk;
    ref.scale = scale;
    ref.yield_scale = yieldScale;
    ref.cpk_scale = cpkScale;
    ref.scale_max = scaleMax;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function [u, s] = lcg_fill(s, n)
% n uniforms in (0,1) from the Park-Miller minimal-standard LCG (exact in double).
u = zeros(n, 1);
for i = 1:n
    s = mod(16807 * s, 2147483647);
    u(i) = s / 2147483647;
end
end

function [gapCold, gapHot] = stack_gap(dev, k, nom, sgn, alpha, Top, Tref)
% End play at the reference temperature and at the operating temperature, with the
% deviations scaled by k. Terms are summed in chain order.
n = size(dev, 1);
gapCold = zeros(n, 1);
gapHot = zeros(n, 1);
dT = Top - Tref;
for d = 1:numel(nom)
    len = nom(d) + k * dev(:, d);
    gapCold = gapCold + sgn(d) * len;
    gapHot = gapHot + sgn(d) * (len .* (1 + alpha(d) * dT));
end
end

function v = prctile_mid(xs, p)
% Percentile of sorted data by the midpoint rule: r = p/100*N + 0.5, linear interpolation,
% clamped to the first and last samples.
n = numel(xs);
r = p / 100 * n + 0.5;
if r <= 1
    v = xs(1);
elseif r >= n
    v = xs(n);
else
    k = floor(r);
    f = r - k;
    v = xs(k) + f * (xs(k + 1) - xs(k));
end
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w5:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
