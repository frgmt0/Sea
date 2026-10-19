%% w2_truss_fem.m -- X-braced 2D bridge truss: sizing, load-angle sweep, damage study
%
% Sea acceptance workload 2. Original workload: the truss, loads, material and section
% catalog are invented for this benchmark. Methods are public textbook methods:
%   * 2D pin-jointed truss finite elements (direct stiffness method), dense K\f solves.
%   * Fully stressed design (FSD) resizing with an Euler buckling floor for thin tubes of
%     fixed diameter/thickness ratio (I = A^2*(D/t)/(8*pi)), then snapping to a catalog.
%   * Load-angle sweep with many right-hand sides, influence lines, and a single-member
%     removal (alternate load path) study that re-assembles and re-solves per member.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w2_truss_fem.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w2_truss_fem';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- inputs
nPanel  = 60;          % number of panels [-]
panelL  = 1.00;        % panel length [m]
height  = 6.00;        % truss depth [m]
E       = 205e9;       % Young's modulus [Pa]
rho     = 7850;        % density [kg/m^3]
g       = 9.81;        % gravity [m/s^2]
sigY    = 275e6;       % yield strength [Pa]
sigAll  = sigY / 1.67; % allowable stress [Pa]
DoverT  = 20;          % tube diameter / wall thickness [-]
nBuck   = 2.0;         % buckling safety factor used in sizing [-]
Amin    = 1e-3;        % minimum member area [m^2]
wDeck   = 24e3;        % deck line load on the bottom chord [N/m]
Ppoint  = 80e3;        % magnitude of the swept point load [N]
nAngle  = 1441;        % number of load angles in the sweep [-]
fsdTol  = 1e-9;        % FSD convergence: max relative area change [-]
fsdMaxIt = 300;        % FSD iteration cap [-]
catalogA = [4 5 6.3 8 10 12.5 16 20 25 31.5 40 50 63 80 100 125 160 200 250 315 ...
            400 500 630] * 1e-4;   % available tube areas [m^2] (R10 series)

%% ---------------------------------------------------------------- geometry
nBot = nPanel + 1;
nNode = 2 * nBot;
xy = zeros(nNode, 2);
for i = 0:nPanel
    xy(i + 1, :) = [i * panelL, 0];             % bottom chord node
    xy(nBot + i + 1, :) = [i * panelL, height]; % top chord node
end
conn = zeros(5 * nPanel + 1, 2);
group = zeros(5 * nPanel + 1, 1);   % 1 bottom chord, 2 top chord, 3 vertical, 4 diagonal
e = 0;
for i = 0:nPanel - 1
    e = e + 1; conn(e, :) = [i + 1, i + 2];               group(e) = 1;
    e = e + 1; conn(e, :) = [nBot + i + 1, nBot + i + 2]; group(e) = 2;
end
for i = 0:nPanel
    e = e + 1; conn(e, :) = [i + 1, nBot + i + 1];        group(e) = 3;
end
for i = 0:nPanel - 1
    e = e + 1; conn(e, :) = [i + 1, nBot + i + 2];        group(e) = 4;
    e = e + 1; conn(e, :) = [nBot + i + 1, i + 2];        group(e) = 4;
end
nElem = e;
nDof = 2 * nNode;
groupName = {'bottom chord', 'top chord', 'vertical', 'diagonal'};

dx = xy(conn(:, 2), 1) - xy(conn(:, 1), 1);
dy = xy(conn(:, 2), 2) - xy(conn(:, 1), 2);
Le = sqrt(dx.^2 + dy.^2);
ce = dx ./ Le;
se = dy ./ Le;

fixedDof = [1, 2, 2 * nBot];          % pin at bottom-left, roller (uy) at bottom-right
freeDof = setdiff(1:nDof, fixedDof);
midBot = nPanel / 2 + 1;              % midspan bottom node
midTop = nBot + nPanel / 2 + 1;       % midspan top node

if mod(nPanel, 2) ~= 0
    error('w2:config', 'nPanel must be even so that a midspan node exists');
end

% Deck load (constant): tributary length per bottom node
Fdeck = zeros(nDof, 1);
for i = 1:nBot
    trib = panelL;
    if i == 1 || i == nBot
        trib = panelL / 2;
    end
    Fdeck(2 * i) = -wDeck * trib;
end

%% ---------------------------------------------------------------- fully stressed design
A = 0.01 * ones(nElem, 1);
fsdIters = 0;
fsdChange = Inf;
while fsdIters < fsdMaxIt && fsdChange > fsdTol
    fsdIters = fsdIters + 1;
    K = assemble_truss(conn, ce, se, Le, E * A, nDof);
    F = Fdeck + self_weight(conn, Le, A, rho, g, nDof);
    u = solve_free(K, F, freeDof, nDof);
    N = member_forces(conn, ce, se, Le, E * A, u);
    Areq = abs(N) / sigAll;
    comp = N < 0;
    Abuck = sqrt(8 * abs(N) .* Le.^2 * nBuck ./ (pi * E * DoverT));
    Areq(comp) = max(Areq(comp), Abuck(comp));
    Anew = max(Areq, Amin);
    fsdChange = max(abs(Anew - A) ./ A);
    A = Anew;
end
fsdConverged = fsdChange <= fsdTol;
Afsd = A;

% Snap to the catalog
Acat = zeros(nElem, 1);
for e = 1:nElem
    k = find(catalogA >= Afsd(e), 1);
    if isempty(k)
        error('w2:catalog', 'member %d needs %.4g m^2, larger than the catalog', e, Afsd(e));
    end
    Acat(e) = catalogA(k);
end

%% ---------------------------------------------------------------- design check
EA = E * Acat;
K = assemble_truss(conn, ce, se, Le, EA, nDof);
Fsw = self_weight(conn, Le, Acat, rho, g, nDof);
F0 = Fdeck + Fsw;
u0 = solve_free(K, F0, freeDof, nDof);
N0 = member_forces(conn, ce, se, Le, EA, u0);
sig0 = N0 ./ Acat;
sigCr = pi * E * Acat * DoverT ./ (8 * Le.^2);
fos0 = member_fos(sig0, sigY, sigCr);
[fosMin0, eCrit0] = min(fos0);
mass = sum(rho * Acat .* Le);
midDefl0 = u0(2 * midBot);
reactions = K * u0 - F0;

%% ---------------------------------------------------------------- load-angle sweep (multi-RHS)
theta = linspace(0, 2*pi, nAngle);
Fsweep = repmat(F0, 1, nAngle);
Fsweep(2 * midTop - 1, :) = Fsweep(2 * midTop - 1, :) + Ppoint * cos(theta);
Fsweep(2 * midTop, :)     = Fsweep(2 * midTop, :)     + Ppoint * sin(theta);
Usweep = solve_free(K, Fsweep, freeDof, nDof);
B = force_matrix(conn, ce, se, Le, EA, nDof);   % N = B*u
Nsweep = B * Usweep;
Ssweep = Nsweep ./ Acat;
utilSweep = max(abs(Ssweep) / sigAll, [], 1);
fosSweep = zeros(1, nAngle);
for k = 1:nAngle
    fosSweep(k) = min(member_fos(Ssweep(:, k), sigY, sigCr));
end
[utilWorst, kWorst] = max(utilSweep);
[fosWorst, kFosWorst] = min(fosSweep);
deflSweep = Usweep(2 * midBot, :);
dispMagTop = hypot(Usweep(2 * midTop - 1, :), Usweep(2 * midTop, :));

%% ---------------------------------------------------------------- influence lines
Funit = zeros(nDof, nBot);
for i = 1:nBot
    Funit(2 * i, i) = -1;
end
Uinf = solve_free(K, Funit, freeDof, nDof);
Ninf = B * Uinf;
eMidChord = nPanel - 1;                  % bottom-chord member just left of midspan
eEndDiag = 2 * nPanel + (nPanel + 1) + 1; % first diagonal
inflDefl = Uinf(2 * midBot, :);
inflChord = Ninf(eMidChord, :);
inflDiag = Ninf(eEndDiag, :);

%% ---------------------------------------------------------------- member removal study
utilRemoved = zeros(1, nElem);
mechanism = false(1, nElem);
for r = 1:nElem
    keep = true(nElem, 1);
    keep(r) = false;
    Kr = assemble_truss(conn(keep, :), ce(keep), se(keep), Le(keep), EA(keep), nDof);
    Fr = Fdeck + self_weight(conn(keep, :), Le(keep), Acat(keep), rho, g, nDof);
    if rcond(Kr(freeDof, freeDof)) < 1e-12
        mechanism(r) = true;
        utilRemoved(r) = NaN;
        continue;
    end
    ur = solve_free(Kr, Fr, freeDof, nDof);
    Nr = member_forces(conn(keep, :), ce(keep), se(keep), Le(keep), EA(keep), ur);
    utilRemoved(r) = max(abs(Nr ./ Acat(keep))) / sigY;
end
[utilRemWorst, rWorst] = max(utilRemoved);
nOverstressed = nnz(utilRemoved > 1);

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W2  X-braced bridge truss ===\n');
fprintf('%d panels x %.2f m, depth %.2f m: %d nodes, %d members, %d free DOF\n', ...
    nPanel, panelL, height, nNode, nElem, numel(freeDof));
fprintf('FSD: %d iterations, converged = %d, final max relative change %.3e\n', ...
    fsdIters, fsdConverged, fsdChange);
fprintf('Steel mass after catalog snap: %.1f kg\n', mass);
fprintf('\n%-13s %6s %10s %10s %12s %12s\n', 'Group', 'count', 'Amin[cm2]', ...
    'Amax[cm2]', 'Nmin[kN]', 'Nmax[kN]');
for gI = 1:4
    m = group == gI;
    fprintf('%-13s %6d %10.2f %10.2f %12.2f %12.2f\n', groupName{gI}, nnz(m), ...
        min(Acat(m))*1e4, max(Acat(m))*1e4, min(N0(m))/1e3, max(N0(m))/1e3);
end
fprintf('\nDesign load case: midspan deflection %.3f mm, min FOS %.3f (member %d, %s)\n', ...
    midDefl0*1e3, fosMin0, eCrit0, groupName{group(eCrit0)});
fprintf('Reactions: left (%.2f, %.2f) kN, right %.2f kN; applied total %.2f kN\n', ...
    reactions(1)/1e3, reactions(2)/1e3, reactions(2*nBot)/1e3, -sum(F0)/1e3);
fprintf('\nLoad-angle sweep (%d angles, %.0f kN at midspan top node):\n', nAngle, Ppoint/1e3);
fprintf('  worst utilisation %.4f at %.2f deg; lowest FOS %.4f at %.2f deg\n', ...
    utilWorst, theta(kWorst)*180/pi, fosWorst, theta(kFosWorst)*180/pi);
fprintf('  midspan deflection range %.3f .. %.3f mm\n', min(deflSweep)*1e3, ...
    max(deflSweep)*1e3);
fprintf('Influence lines: max midspan deflection per kN %.4f mm, chord force per kN %.4f\n', ...
    max(abs(inflDefl))*1e3*1e3, max(abs(inflChord))*1e3);
fprintf('Member removal: %d mechanisms, %d cases overstressed, worst utilisation %.4f ', ...
    nnz(mechanism), nOverstressed, utilRemWorst);
fprintf('(remove member %d, %s)\n', rWorst, groupName{group(rWorst)});
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W2 truss', 'Color', 'w');
    subplot(2, 2, [1 2]);
    hold on;
    scale = 0.25 * height / max(abs(u0));
    for e = 1:nElem
        n1 = conn(e, 1); n2 = conn(e, 2);
        plot(xy([n1 n2], 1), xy([n1 n2], 2), '-', 'Color', [0.75 0.75 0.75]);
        xd = xy([n1 n2], 1) + scale * u0([2*n1-1, 2*n2-1]);
        yd = xy([n1 n2], 2) + scale * u0([2*n1, 2*n2]);
        if N0(e) < 0
            plot(xd, yd, 'b-', 'LineWidth', 0.5 + 3 * Acat(e) / max(Acat));
        else
            plot(xd, yd, 'r-', 'LineWidth', 0.5 + 3 * Acat(e) / max(Acat));
        end
    end
    hold off; axis equal;
    title(sprintf('Deformed shape (x%.0f), red tension, blue compression', scale));
    xlabel('x [m]'); ylabel('y [m]');

    subplot(2, 2, 3);
    plot(theta*180/pi, utilSweep, theta*180/pi, 1 ./ fosSweep);
    grid on; xlim([0 360]);
    xlabel('Load angle [deg]'); ylabel('[-]');
    legend('max utilisation', '1 / min FOS');
    title('Load-angle sweep');

    subplot(2, 2, 4);
    bar(utilRemoved);
    xlabel('Removed member'); ylabel('Max utilisation');
    title('Single-member removal');
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
    ref.n_node = nNode;
    ref.n_elem = nElem;
    ref.fsd_iters = fsdIters;
    ref.fsd_converged = fsdConverged;
    ref.A_fsd = Afsd.';
    ref.A_cat = Acat.';
    ref.mass = mass;
    ref.u0 = u0.';
    ref.N0 = N0.';
    ref.fos0 = fos0.';
    ref.fos_min0 = fosMin0;
    ref.e_crit0 = eCrit0;
    ref.mid_defl0 = midDefl0;
    ref.reactions = [reactions(1), reactions(2), reactions(2*nBot)];
    ref.theta = theta;
    ref.util_sweep = utilSweep;
    ref.fos_sweep = fosSweep;
    ref.defl_sweep = deflSweep;
    ref.disp_top_sweep = dispMagTop;
    ref.util_worst = utilWorst;
    ref.k_worst = kWorst;
    ref.fos_worst = fosWorst;
    ref.k_fos_worst = kFosWorst;
    ref.infl_defl = inflDefl;
    ref.infl_chord = inflChord;
    ref.infl_diag = inflDiag;
    ref.util_removed = utilRemoved;
    ref.mechanism_count = nnz(mechanism);
    ref.overstressed_count = nOverstressed;
    ref.util_removed_worst = utilRemWorst;
    ref.r_worst = rWorst;
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function K = assemble_truss(conn, c, s, L, EA, nDof)
% Global stiffness matrix of a 2D truss, assembled member by member.
K = zeros(nDof, nDof);
for e = 1:size(conn, 1)
    k = EA(e) / L(e);
    cc = c(e) * c(e) * k;
    cs = c(e) * s(e) * k;
    ss = s(e) * s(e) * k;
    ke = [cc cs -cc -cs; cs ss -cs -ss; -cc -cs cc cs; -cs -ss cs ss];
    idx = [2*conn(e, 1) - 1, 2*conn(e, 1), 2*conn(e, 2) - 1, 2*conn(e, 2)];
    K(idx, idx) = K(idx, idx) + ke;
end
end

function F = self_weight(conn, L, A, rho, g, nDof)
% Member self weight lumped half to each end node (downward).
F = zeros(nDof, 1);
for e = 1:size(conn, 1)
    w = rho * g * A(e) * L(e) / 2;
    F(2*conn(e, 1)) = F(2*conn(e, 1)) - w;
    F(2*conn(e, 2)) = F(2*conn(e, 2)) - w;
end
end

function U = solve_free(K, F, freeDof, nDof)
% Solve K(free,free) * U(free,:) = F(free,:) with zero prescribed displacements.
U = zeros(nDof, size(F, 2));
U(freeDof, :) = K(freeDof, freeDof) \ F(freeDof, :);
end

function N = member_forces(conn, c, s, L, EA, u)
% Axial member forces (tension positive).
nE = size(conn, 1);
N = zeros(nE, 1);
for e = 1:nE
    i1 = 2*conn(e, 1); i2 = 2*conn(e, 2);
    du = u(i2 - 1) - u(i1 - 1);
    dv = u(i2) - u(i1);
    N(e) = EA(e) / L(e) * (c(e) * du + s(e) * dv);
end
end

function B = force_matrix(conn, c, s, L, EA, nDof)
% Matrix B with N = B*u for all members.
nE = size(conn, 1);
B = zeros(nE, nDof);
for e = 1:nE
    k = EA(e) / L(e);
    i1 = 2*conn(e, 1); i2 = 2*conn(e, 2);
    B(e, [i1 - 1, i1, i2 - 1, i2]) = k * [-c(e), -s(e), c(e), s(e)];
end
end

function fos = member_fos(sig, sigY, sigCr)
% Factor of safety per member: yield, and Euler buckling for compression members.
fos = sigY ./ abs(sig);
comp = sig < 0;
fos(comp) = min(fos(comp), sigCr(comp) ./ abs(sig(comp)));
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w2:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
