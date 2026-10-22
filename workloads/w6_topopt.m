%% w6_topopt.m -- Topology optimisation: 2D SIMP minimum compliance (MBB beam, cantilever)
%
% Sea workload 6. Original implementation: the structure, naming and code are written for
% this benchmark. The method is the published one:
%   * SIMP material interpolation E(x) = Emin + x^p (E0 - Emin) (Bendsoe 1989; Sigmund 2001,
%     "A 99 line topology optimization code written in Matlab").
%   * Bilinear Q4 plane-stress elements, element stiffness by 2x2 Gauss quadrature.
%   * Density filter (Bruns & Tortorelli 2001; Bourdin 2001) or sensitivity filter
%     (Sigmund 1994/2001), both with the linear "hat" weights max(0, rmin - distance).
%   * Optimality-criteria (OC) update with a move limit and bisection on the Lagrange
%     multiplier of the volume constraint (as in Andreassen et al. 2011, "Efficient topology
%     optimization in MATLAB using 88 lines of code").
%   * Sparse assembly and a sparse direct solve of K(free,free) u = f(free) per iteration.
%
% The specification (also followed step by step by reference_py/w6_topopt.py):
%   Mesh: nelx x nely unit square elements, x to the right, y upwards. Node (i, j),
%     i = 0..nelx, j = 0..nely, has the number n = i*(nely+1) + j + 1 and the DOFs 2n-1 (u_x)
%     and 2n (u_y). Element (i, j), i = 0..nelx-1, j = 0..nely-1, is x(j+1, i+1) of the
%     nely x nelx density matrix (row 1 = bottom row), element number e = i*nely + j + 1 (the
%     column-major linear index), nodes (i,j), (i+1,j), (i+1,j+1), (i,j+1).
%   Load cases: 'mbb' = half MBB beam: u_x = 0 on the left edge (symmetry), u_y = 0 at the
%     bottom-right node (roller), load -1 in y at the top-left node. 'cantilever': all DOFs
%     of the left edge fixed, load -1 in y at the middle node of the right edge.
%   Start: x = volfrac everywhere; xPhys = filtered x (density filter) or x.
%   Iteration (until max|x_new - x| <= tolChange, at most maxIter updates):
%     solve; c = sum_e E(xPhys_e) u_e' KE u_e; dc_e = -p (E0-Emin) xPhys_e^(p-1) u_e' KE u_e;
%     filter dc (and dv = 1); OC update with bisection l1 = 0, l2 = lambdaHi, while
%     (l2-l1)/(l1+l2) > tolLambda: x_new = max(0, max(x-move, min(1, min(x+move,
%     x .* sqrt(-dc./dv/lmid))))), xPhys = filter(x_new) or x_new, l1 = lmid if
%     sum(xPhys) > volfrac*nel else l2 = lmid.
%   After the loop the final xPhys is solved once more for its compliance c_final.
%
% Flags (set them in the workspace before running; all default to the value shown):
%   SEA_EXPORT_REFERENCE = false  write reference/w6_topopt.json
%   SEA_PLOT             = true   draw figures
%   SEA_SAVE_FIGURES     = false  save figures to output/ (only when SEA_PLOT is true)

if ~exist('SEA_EXPORT_REFERENCE', 'var'), SEA_EXPORT_REFERENCE = false; end
if ~exist('SEA_PLOT', 'var'),             SEA_PLOT = true;              end
if ~exist('SEA_SAVE_FIGURES', 'var'),     SEA_SAVE_FIGURES = false;     end
wlName = 'w6_topopt';
wlDir  = fileparts(mfilename('fullpath'));
if isempty(wlDir), wlDir = pwd; end
tCompute = tic;

%% ---------------------------------------------------------------- inputs
prm.E0        = 1;      % Young's modulus of solid material [-]
prm.Emin      = 1e-9;   % Young's modulus of void (keeps K nonsingular) [-]
prm.nu        = 0.3;    % Poisson's ratio [-]
prm.penal     = 3;      % SIMP penalisation exponent p [-]
prm.volfrac   = 0.5;    % prescribed volume fraction [-]
prm.move      = 0.2;    % OC move limit [-]
prm.tolChange = 0.01;   % stop when max |x_new - x| <= tolChange ...
prm.maxIter   = 200;    % ... or after maxIter design updates
prm.lambdaHi  = 1e9;    % initial upper bound of the Lagrange multiplier bisection
prm.tolLambda = 1e-9;   % bisection stops when (l2 - l1)/(l1 + l2) <= tolLambda
nEarly = 10;            % compliance history exported for iterations 1..nEarly
nMid   = 50;            % ... and the compliance at iteration nMid

% The three cases. filter: 1 = sensitivity filter, 2 = density filter. rmin in elements.
cases = struct( ...
    'name',   {'MBB beam, density filter', 'MBB beam, sensitivity filter', ...
               'Cantilever, density filter'}, ...
    'load',   {'mbb', 'mbb', 'cantilever'}, ...
    'filter', {2, 1, 2}, ...
    'nelx',   {120, 120, 100}, ...
    'nely',   {40, 40, 50}, ...
    'rmin',   {4.8, 4.8, 4.0});
fieldKey = {'x_mbb_density', 'x_mbb_sensitivity', 'x_cantilever_density'};
filterName = {'sensitivity', 'density'};

%% ---------------------------------------------------------------- element and optimisation
% Element stiffness of the unit square for E = 1; E(x) scales it.
KE = q4_stiffness([0 0; 1 0; 1 1; 0 1], 1, prm.nu);

nCase = numel(cases);
iters = zeros(1, nCase);
converged = false(1, nCase);
changeFinal = zeros(1, nCase);
cFirst = zeros(1, nCase);
cEarly = zeros(nCase, nEarly);
cMid = zeros(1, nCase);
cFinal = zeros(1, nCase);
volFinal = zeros(1, nCase);
volErrMax = zeros(1, nCase);
grayness = zeros(1, nCase);
nSolid = zeros(1, nCase);
xField = cell(1, nCase);
cHistory = cell(1, nCase);
for k = 1:nCase
    res = run_topopt(cases(k), KE, prm);
    if numel(res.cHist) < max(nEarly, nMid)
        error('w6:iterations', 'case %d stopped after %d iterations, fewer than %d', ...
            k, numel(res.cHist), max(nEarly, nMid));
    end
    iters(k) = res.iters;
    converged(k) = res.converged;
    changeFinal(k) = res.change;
    cFirst(k) = res.cHist(1);
    cEarly(k, :) = res.cHist(1:nEarly);
    cMid(k) = res.cHist(nMid);
    cFinal(k) = res.cFinal;
    volFinal(k) = mean(res.xPhys(:));
    volErrMax(k) = res.volErrMax;
    grayness(k) = 4 * mean(res.xPhys(:) .* (1 - res.xPhys(:)));   % 0 = black and white
    nSolid(k) = nnz(res.xPhys > 0.5);
    xField{k} = res.xPhys;
    cHistory{k} = res.cHist;
end

computeSeconds = toc(tCompute);

%% ---------------------------------------------------------------- report
fprintf('\n=== W6  Topology optimisation: 2D SIMP minimum compliance ===\n');
fprintf('Q4 plane stress, E0 = %g, Emin = %g, nu = %.2f, p = %g, volume fraction %.2f\n', ...
    prm.E0, prm.Emin, prm.nu, prm.penal, prm.volfrac);
fprintf('OC: move %.2f, bisection to %g; stop at max change <= %.3f or %d updates\n', ...
    prm.move, prm.tolLambda, prm.tolChange, prm.maxIter);
fprintf('\n%-30s %10s %-12s %5s %5s %4s %11s %11s %9s %7s %6s\n', 'Case', 'mesh', 'filter', ...
    'rmin', 'iters', 'conv', 'c(1)', 'c(final)', 'volume', 'gray', 'solid');
for k = 1:nCase
    fprintf('%-30s %4d x %-3d %-12s %5.2f %5d %4d %11.4f %11.4f %9.6f %7.4f %6d\n', ...
        cases(k).name, cases(k).nelx, cases(k).nely, filterName{cases(k).filter}, ...
        cases(k).rmin, iters(k), converged(k), cFirst(k), cFinal(k), volFinal(k), grayness(k), ...
        nSolid(k));
end
fprintf('\nCompliance at iteration %d: %s\n', nMid, strtrim(sprintf('%.4f  ', cMid)));
fprintf('Largest volume-constraint error after an OC update: %.3e\n', max(volErrMax));
fprintf('Compute time: %.3f s\n', computeSeconds);

%% ---------------------------------------------------------------- figures
if SEA_PLOT
    fig = figure('Name', 'W6 topology optimisation', 'Color', 'w');
    for k = 1:nCase
        subplot(2, 2, k);
        imagesc(xField{k});
        axis xy;              % row 1 (the bottom row of elements) at the bottom
        axis equal tight;
        colormap(gca, flipud(gray(256)));
        clim([0 1]);
        title(sprintf('%s: c = %.3f', cases(k).name, cFinal(k)));
    end
    subplot(2, 2, 4);
    hold on;
    for k = 1:nCase
        semilogy(1:numel(cHistory{k}), cHistory{k});
    end
    hold off;
    set(gca, 'YScale', 'log');
    grid on; xlabel('Iteration'); ylabel('Compliance');
    legend({cases.name});
    title('Convergence');
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
    ref.case_name = {cases.name};
    ref.case_load = {cases.load};
    ref.case_filter = [cases.filter];
    ref.case_nelx = [cases.nelx];
    ref.case_nely = [cases.nely];
    ref.case_rmin = [cases.rmin];
    ref.ke = KE;
    ref.iters = iters;
    ref.converged = converged;
    ref.change_final = changeFinal;
    ref.c_first = cFirst;
    ref.c_early = cEarly;
    ref.c_mid = cMid;
    ref.c_final = cFinal;
    ref.vol_final = volFinal;
    ref.vol_err_max = volErrMax;
    ref.gray = grayness;
    ref.n_solid = nSolid;
    for k = 1:nCase
        ref.(fieldKey{k}) = xField{k};
    end
    write_reference(wlDir, wlName, ref);
end

%% ================================================================ local functions
function res = run_topopt(cs, KE, prm)
% One SIMP minimum-compliance run for the case cs. Returns the iteration count, convergence
% flag, last change, compliance history, final compliance and density field, and the
% largest volume-constraint error seen after an OC update.
nelx = cs.nelx;
nely = cs.nely;
nDof = 2 * (nelx + 1) * (nely + 1);
edof = element_dofs(nelx, nely);
% Triplet pattern of the 64 entries of every element matrix: column c of the nel x 64
% arrays is entry (a, b) of KE with c = (b-1)*8 + a, i.e. KE(:) order.
iK = repmat(edof, 1, 8);
jK = kron(edof, ones(1, 8));
iK = iK(:);
jK = jK(:);
[fixed, F] = load_case(cs.load, nelx, nely);
free = setdiff(1:nDof, fixed);

W = filter_kernel(cs.rmin);
Hs = conv2(ones(nely, nelx), W, 'same');    % sum of the weights of each element
x = prm.volfrac * ones(nely, nelx);
if cs.filter == 2
    xPhys = conv2(x, W, 'same') ./ Hs;
else
    xPhys = x;
end

cHist = zeros(1, prm.maxIter);
volErr = zeros(1, prm.maxIter);
change = Inf;
it = 0;
while it < prm.maxIter && change > prm.tolChange
    it = it + 1;
    % FE analysis with the SIMP moduli of the current physical densities
    Ee = prm.Emin + xPhys(:).^prm.penal * (prm.E0 - prm.Emin);
    U = fe_solve(Ee, KE, iK, jK, nDof, free, F);
    ce = element_energy(U, edof, KE);
    cHist(it) = sum(Ee .* ce);
    % Sensitivities of compliance and volume, then the filter
    dc = reshape(-prm.penal * (prm.E0 - prm.Emin) * xPhys(:).^(prm.penal - 1) .* ce, ...
        nely, nelx);
    dv = ones(nely, nelx);
    if cs.filter == 1
        dc = conv2(x .* dc, W, 'same') ./ Hs ./ max(1e-3, x);
    else
        dc = conv2(dc ./ Hs, W, 'same');
        dv = conv2(dv ./ Hs, W, 'same');
    end
    % Optimality-criteria update
    [xNew, xPhys] = oc_update(x, dc, dv, cs.filter, W, Hs, prm);
    volErr(it) = abs(mean(xPhys(:)) - prm.volfrac);
    change = max(abs(xNew(:) - x(:)));
    x = xNew;
end

% Compliance of the final design
Ee = prm.Emin + xPhys(:).^prm.penal * (prm.E0 - prm.Emin);
U = fe_solve(Ee, KE, iK, jK, nDof, free, F);
res.iters = it;
res.converged = change <= prm.tolChange;
res.change = change;
res.cHist = cHist(1:it);
res.cFinal = sum(Ee .* element_energy(U, edof, KE));
res.xPhys = xPhys;
res.volErrMax = max(volErr(1:it));
end

function [xNew, xPhys] = oc_update(x, dc, dv, filterType, W, Hs, prm)
% Optimality-criteria update: the Lagrange multiplier of the volume constraint is found by
% bisection so that the physical densities use exactly the prescribed volume.
l1 = 0;
l2 = prm.lambdaHi;
target = prm.volfrac * numel(x);
ratio = -dc ./ dv;
if any(ratio(:) < 0)
    error('w6:sens', 'a compliance sensitivity is positive; the OC update needs dc <= 0');
end
while (l2 - l1) / (l1 + l2) > prm.tolLambda
    lmid = 0.5 * (l1 + l2);
    xB = x .* sqrt(ratio / lmid);
    xNew = max(0, max(x - prm.move, min(1, min(x + prm.move, xB))));
    if filterType == 2
        xPhys = conv2(xNew, W, 'same') ./ Hs;
    else
        xPhys = xNew;
    end
    if sum(xPhys(:)) > target     % too much material: raise the multiplier
        l1 = lmid;
    else
        l2 = lmid;
    end
end
end

function U = fe_solve(Ee, KE, iK, jK, nDof, free, F)
% Assemble the sparse global stiffness from the element moduli and solve for the
% displacements with zero prescribed DOFs.
sK = Ee * KE(:).';                          % nel x 64, column c = KE(c) scaled per element
K = sparse(iK, jK, sK(:), nDof, nDof);
K = (K + K.') / 2;                          % exactly symmetric, so backslash uses Cholesky
U = zeros(nDof, 1);
U(free) = K(free, free) \ F(free);
end

function ce = element_energy(U, edof, KE)
% u_e' * KE * u_e for every element (column vector in element order).
Ue = U(edof);                               % nel x 8
ce = sum((Ue * KE) .* Ue, 2);
end

function edof = element_dofs(nelx, nely)
% DOF table (nel x 8), rows in element order e = i*nely + j + 1, element nodes
% (i,j), (i+1,j), (i+1,j+1), (i,j+1), each node contributing (u_x, u_y).
[jj, ii] = ndgrid(0:nely - 1, 0:nelx - 1);
n1 = ii(:) * (nely + 1) + jj(:) + 1;        % bottom-left node
n2 = (ii(:) + 1) * (nely + 1) + jj(:) + 1;  % bottom-right node
n3 = n2 + 1;                                % top-right node
n4 = n1 + 1;                                % top-left node
edof = [2*n1 - 1, 2*n1, 2*n2 - 1, 2*n2, 2*n3 - 1, 2*n3, 2*n4 - 1, 2*n4];
end

function [fixed, F] = load_case(kind, nelx, nely)
% Prescribed DOFs and load vector of a load case.
nDof = 2 * (nelx + 1) * (nely + 1);
F = zeros(nDof, 1);
switch kind
    case 'mbb'
        % symmetry line x = 0 (u_x = 0), roller at the bottom-right node, load at top-left
        fixed = [2 * (1:nely + 1) - 1, 2 * (nelx * (nely + 1) + 1)];
        F(2 * (nely + 1)) = -1;
    case 'cantilever'
        if mod(nely, 2) ~= 0
            error('w6:config', 'the cantilever needs an even nely (load at the mid node)');
        end
        % clamped left edge, load at the middle node of the right edge
        fixed = 1:2 * (nely + 1);
        F(2 * (nelx * (nely + 1) + nely / 2 + 1)) = -1;
    otherwise
        error('w6:config', 'unknown load case ''%s''', kind);
end
fixed = sort(fixed);
end

function W = filter_kernel(rmin)
% Filter weights max(0, rmin - distance) on the integer offsets |dx|, |dy| <= ceil(rmin)-1.
R = ceil(rmin) - 1;
[dx, dy] = meshgrid(-R:R, -R:R);
W = max(0, rmin - sqrt(dx.^2 + dy.^2));
end

function KE = q4_stiffness(xy, E, nu)
% Plane-stress Q4 element stiffness (unit thickness) by 2x2 Gauss quadrature; xy holds the
% four node coordinates counterclockwise. DOF order u1x u1y u2x u2y u3x u3y u4x u4y.
D = E / (1 - nu^2) * [1 nu 0; nu 1 0; 0 0 (1 - nu) / 2];
g = 1 / sqrt(3);
gp = [-g, g];
KE = zeros(8, 8);
for eta = gp
    for xi = gp
        [B, detJ] = q4_B(xy, xi, eta);
        KE = KE + (B.' * D * B) * detJ;
    end
end
KE = 0.5 * (KE + KE.');                     % exactly symmetric
end

function [B, detJ] = q4_B(xy, xi, eta)
% Strain-displacement matrix (3 x 8) and Jacobian determinant at the natural point (xi, eta).
dN = 0.25 * [-(1 - eta), (1 - eta), (1 + eta), -(1 + eta);
             -(1 - xi), -(1 + xi), (1 + xi), (1 - xi)];
J = dN * xy;                                % [dx/dxi dy/dxi; dx/deta dy/deta]
detJ = J(1, 1) * J(2, 2) - J(1, 2) * J(2, 1);
dNxy = J \ dN;                              % [dN/dx; dN/dy]
B = zeros(3, 8);
B(1, 1:2:8) = dNxy(1, :);
B(2, 2:2:8) = dNxy(2, :);
B(3, 1:2:8) = dNxy(2, :);
B(3, 2:2:8) = dNxy(1, :);
end

function write_reference(wlDir, wlName, ref)
% Write the reference results as JSON to reference/<name>.json.
refDir = fullfile(wlDir, 'reference');
if ~exist(refDir, 'dir'), mkdir(refDir); end
fid = fopen(fullfile(refDir, [wlName '.json']), 'w');
if fid < 0
    error('w6:export', 'cannot open reference file for writing');
end
fprintf(fid, '%s\n', jsonencode(ref, 'PrettyPrint', true));
fclose(fid);
end
