%% w4_heat_plate.m -- 2D steady heat conduction in a cooled plate by finite differences
%
% Sea acceptance workload 4. Original workload: geometry, conductivity, heat source and
% boundary temperatures are invented for this benchmark. Methods are public textbook methods:
%   * 5-point finite-difference Laplacian on a uniform grid (241 x 161 nodes).
%   * Dirichlet edges (bottom: linear temperature ramp, top: fixed temperature), insulated
%     (Neumann, mirrored ghost node) side edges, an embedded coolant channel held at a fixed
%     temperature, and a rectangular volumetric heat source.
%   * Solver 1: point SOR with scalar loops in lexicographic order and a max-change
%     convergence test.  Solver 2: red-black SOR written with whole-array (vectorized)
%     stencil updates.  Both use the same relaxation factor and tolerance.
%   * Post-processing: conservative heat-flow balance over the Dirichlet boundaries, the
%     residual of each solution, the heat-flux field (central differences), centerline data.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w4_heat_plate.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w4_heat_plate';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- inputs
W      = 0.30;          % plate width [m]
H      = 0.20;          % plate height [m]
h      = 0.00125;       % grid spacing [m]
kCond  = 167;           % thermal conductivity [W/(m K)]
tPlate = 0.005;         % plate thickness [m]
Tbot0  = 40;            % bottom edge temperature at x = 0 [degC]
Tbot1  = 65;            % bottom edge temperature at x = W [degC]
Ttop   = 20;            % top edge temperature [degC]
Thole  = 12;            % coolant channel temperature [degC]
holeC  = [0.215, 0.105];% coolant channel center [m]
holeR  = 0.018;         % coolant channel radius [m]
srcBox = [0.06 0.11 0.07 0.12];   % heat source x0 x1 y0 y1 [m]
qSrc   = 2.5e7;         % volumetric heat generation [W/m^3]
tol    = 1e-8;          % convergence: max temperature change per sweep [K]
maxIt  = 20000;         % iteration cap [-]

nx = round(W / h) + 1;
ny = round(H / h) + 1;
x = (0:nx-1) * h;
y = (0:ny-1) * h;
[X, Y] = meshgrid(x, y);              % ny x nx, rows are y

hole = (X - holeC(1)).^2 + (Y - holeC(2)).^2 <= holeR^2;
src = zeros(ny, nx);
inSrc = X >= srcBox(1) & X <= srcBox(2) & Y >= srcBox(3) & Y <= srcBox(4);
src(inSrc) = h^2 * qSrc / kCond;      % source term of the scaled 5-point equation [K]
if any(hole(:) & inSrc(:))
    error('w4:config', 'heat source and coolant channel overlap');
end
if any(hole(1, :)) || any(hole(ny, :)) || any(hole(:, 1)) || any(hole(:, nx))
    error('w4:config', 'coolant channel touches the plate edge');
end

fixed = hole;
fixed(1, :) = true;
fixed(ny, :) = true;
unknown = ~fixed;

T0 = Ttop * ones(ny, nx);
T0(1, :) = Tbot0 + (Tbot1 - Tbot0) * x / W;
T0(ny, :) = Ttop;
T0(hole) = Thole;

% Relaxation factor from the Jacobi spectral radius of the rectangle (insulated sides)
rhoJ = (1 + cos(pi / (ny - 1))) / 2;
omega = 2 / (1 + sqrt(1 - rhoJ^2));

%% ---------------------------------------------------------------- solver 1: scalar SOR
T = T0;
itSor = 0;
dMax = Inf;
while dMax > tol && itSor < maxIt
    itSor = itSor + 1;
    dMax = 0;
    for i = 1:nx
        for j = 2:ny-1
            if fixed(j, i)
                continue;
            end
            if i == 1
                tw = T(j, 2);
            else
                tw = T(j, i-1);
            end
            if i == nx
                te = T(j, nx-1);
            else
                te = T(j, i+1);
            end
            tgs = (tw + te + T(j-1, i) + T(j+1, i) + src(j, i)) / 4;
            tn = T(j, i) + omega * (tgs - T(j, i));
            d = abs(tn - T(j, i));
            if d > dMax
                dMax = d;
            end
            T(j, i) = tn;
        end
    end
end
Tsor = T;
dSor = dMax;

%% ---------------------------------------------------------------- solver 2: red-black SOR
[I, J] = meshgrid(1:nx, 1:ny);
red = mod(I + J, 2) == 0 & unknown;
black = mod(I + J, 2) == 1 & unknown;
redIn = red(2:ny-1, :);
blackIn = black(2:ny-1, :);
T = T0;
itRb = 0;
dMax = Inf;
while dMax > tol && itRb < maxIt
    itRb = itRb + 1;
    [T, d1] = rb_half_sweep(T, src, redIn, omega);
    [T, d2] = rb_half_sweep(T, src, blackIn, omega);
    dMax = max(d1, d2);
end
Trb = T;
dRb = dMax;

%% ---------------------------------------------------------------- post-processing
resSor = residual(Tsor, src, unknown);
resRb  = residual(Trb, src, unknown);
diffSolvers = max(abs(Tsor(:) - Trb(:)));

T = Tsor;
Thot = T;
Thot(~unknown) = -Inf;                % hot spot over the solved (non-Dirichlet) nodes
[Tmax, kMax] = max(Thot(:));
[jMax, iMax] = ind2sub(size(T), kMax);
Tmean = mean(T(unknown));

% Conservative heat flows into the plate (per plate thickness) [W]
wEdge = ones(1, nx);
wEdge([1 nx]) = 0.5;
Qbot = kCond * tPlate * sum(wEdge .* (T(1, :) - T(2, :)));
Qtop = kCond * tPlate * sum(wEdge .* (T(ny, :) - T(ny-1, :)));
holeIdx = find(hole);
[hj, hi] = ind2sub(size(T), holeIdx);
Qhole = 0;
shifts = [1 0; -1 0; 0 1; 0 -1];
for s = 1:4
    nb = sub2ind(size(T), hj + shifts(s, 1), hi + shifts(s, 2));
    m = unknown(nb);
    Qhole = Qhole + kCond * tPlate * sum(T(holeIdx(m)) - T(nb(m)));
end
cellW = ones(ny, nx);
cellW(:, [1 nx]) = 0.5;
Qgen = sum(qSrc * h^2 * tPlate * cellW(inSrc & unknown));
Qbalance = Qbot + Qtop + Qhole + Qgen;

% Heat-flux field by central differences on interior nodes [W/m^2]
qx = -kCond * (T(2:ny-1, 3:nx) - T(2:ny-1, 1:nx-2)) / (2*h);
qy = -kCond * (T(3:ny, 2:nx-1) - T(1:ny-2, 2:nx-1)) / (2*h);
qMag = sqrt(qx.^2 + qy.^2);
[qMax, kq] = max(qMag(:));
[jq, iq] = ind2sub(size(qMag), kq);
xq = x(iq + 1);
yq = y(jq + 1);

iMid = (nx + 1) / 2;
jMid = (ny + 1) / 2;
profX = T(jMid, :);
profY = T(:, iMid).';
sub = T(1:8:ny, 1:8:nx);

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W4  Steady heat conduction in a cooled plate ===\n');
fprintf('Grid %d x %d (h = %.3f mm), %d unknowns, %d coolant nodes, omega = %.5f\n', ...
    nx, ny, h*1e3, nnz(unknown), nnz(hole), omega);
fprintf('Scalar SOR    : %5d sweeps, last change %.3e K, max residual %.3e K\n', ...
    itSor, dSor, resSor);
fprintf('Red-black SOR : %5d sweeps, last change %.3e K, max residual %.3e K\n', ...
    itRb, dRb, resRb);
fprintf('Max difference between the two solutions: %.3e K\n', diffSolvers);
fprintf('\nHot spot %.4f degC at (x, y) = (%.4f, %.4f) m\n', Tmax, x(iMax), y(jMax));
fprintf('T mean %.4f degC over the unknown nodes\n', Tmean);
fprintf('Heat flow into the plate [W]:\n');
flowLabel = {'bottom edge', 'top edge', 'coolant channel', 'heat source', 'balance'};
flowValue = [Qbot, Qtop, Qhole, Qgen, Qbalance];
for s = 1:numel(flowLabel)
    fprintf('  %-16s %12.6f\n', flowLabel{s}, flowValue(s));
end
fprintf('Peak heat flux %.4e W/m^2 at (x, y) = (%.4f, %.4f) m\n', qMax, xq, yq);
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W4 heat plate', 'Color', 'w');
    subplot(2, 2, [1 3]);
    imagesc(x, y, T);
    axis xy;
    axis equal tight;
    colorbar;
    hold on;
    contour(x, y, T, 20, 'k');
    hold off;
    xlabel('x [m]'); ylabel('y [m]');
    title('Temperature [degC]');

    subplot(2, 2, 2);
    plot(x, profX, y, profY);
    grid on; xlabel('Position [m]'); ylabel('T [degC]');
    legend('horizontal centerline', 'vertical centerline');
    title('Centerline profiles');

    subplot(2, 2, 4);
    bar([Qbot, Qtop, Qhole, Qgen]);
    set(gca, 'XTickLabel', {'bottom', 'top', 'coolant', 'source'});
    ylabel('Heat flow into plate [W]');
    title(sprintf('Balance error %.2e W', Qbalance));
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
    ref.nx = nx;
    ref.ny = ny;
    ref.n_unknown = nnz(unknown);
    ref.n_hole = nnz(hole);
    ref.omega = omega;
    ref.it_sor = itSor;
    ref.it_rb = itRb;
    ref.res_sor = resSor;
    ref.res_rb = resRb;
    ref.diff_solvers = diffSolvers;
    ref.T_max = Tmax;
    ref.x_Tmax = x(iMax);
    ref.y_Tmax = y(jMax);
    ref.T_mean = Tmean;
    ref.Q_bottom = Qbot;
    ref.Q_top = Qtop;
    ref.Q_hole = Qhole;
    ref.Q_gen = Qgen;
    ref.Q_balance = Qbalance;
    ref.q_max = qMax;
    ref.x_qmax = xq;
    ref.y_qmax = yq;
    ref.profile_x = profX;
    ref.profile_y = profY;
    ref.T_sub = sub;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function [T, dMax] = rb_half_sweep(T, src, colorIn, omega)
% One colour of red-black SOR on rows 2..ny-1, whole-array form. Side edges are insulated:
% the ghost column mirrors the first interior column.
ny = size(T, 1);
Tp = [T(2:ny-1, 2), T(2:ny-1, :), T(2:ny-1, end-1)];
Tc = T(2:ny-1, :);
tgs = (Tp(:, 1:end-2) + Tp(:, 3:end) + T(1:ny-2, :) + T(3:ny, :) + src(2:ny-1, :)) / 4;
Tn = Tc + omega * (tgs - Tc);
dMax = max(abs(Tn(colorIn) - Tc(colorIn)));
Tc(colorIn) = Tn(colorIn);
T(2:ny-1, :) = Tc;
end

function r = residual(T, src, unknown)
% Max |5-point residual| over the unknown nodes, in the scaled form (K).
[ny, nx] = size(T);
Tp = [T(:, 2), T, T(:, nx-1)];
R = zeros(ny, nx);
R(2:ny-1, :) = Tp(2:ny-1, 1:nx) + Tp(2:ny-1, 3:nx+2) + T(1:ny-2, :) + T(3:ny, :) ...
    - 4 * T(2:ny-1, :) + src(2:ny-1, :);
r = max(abs(R(unknown)));
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w4:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
