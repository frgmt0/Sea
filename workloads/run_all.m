function run_all(makePlots, nRepeat)
%RUN_ALL  Run every Sea acceptance workload, export the reference JSON and time each one.
%
%   run_all            run each workload 3 times without figures, write reference/*.json
%   run_all(true)      also draw the figures and save them to output/
%   run_all(false, N)  run each workload N times (timing statistics over N runs)
%
%   Works from any current folder: all paths are relative to this file. Each workload runs
%   in its own workspace with SEA_EXPORT_REFERENCE = true, so reference/<name>.json is
%   (re)written on every repetition (the results are deterministic). The timing table is
%   printed and also written to reference/baseline_timings_matlab.json.
%
%   "total" is the wall time of the whole script (setup, compute, report, figures, export);
%   "compute" is the script's own tic/toc around its numerical part. The first repetition
%   includes MATLAB's JIT warm-up; "best" is the minimum over all repetitions.

if nargin < 1, makePlots = false; end
if nargin < 2, nRepeat = 3; end
if nRepeat < 1
    error('run_all:args', 'nRepeat must be at least 1');
end

here = fileparts(mfilename('fullpath'));
names = {'w1_shaft_design', 'w2_truss_fem', 'w3_quarter_car', 'w4_heat_plate', ...
         'w5_tolerance_mc'};
nW = numel(names);
totalS = zeros(nW, nRepeat);
computeS = zeros(nW, nRepeat);

for w = 1:nW
    scriptPath = fullfile(here, [names{w} '.m']);
    if ~exist(scriptPath, 'file')
        error('run_all:missing', 'workload script not found: %s', scriptPath);
    end
    for r = 1:nRepeat
        plotThis = makePlots && r == nRepeat;
        [totalS(w, r), computeS(w, r)] = run_one(scriptPath, plotThis);
    end
end

refDir = fullfile(here, 'reference');
fprintf('\n=== Sea workloads: MATLAB %s on %s, %d repetition(s) ===\n', version, ...
    computer('arch'), nRepeat);
fprintf('%-18s %12s %12s %12s %12s\n', 'workload', 'total 1st', 'total best', ...
    'compute 1st', 'compute best');
for w = 1:nW
    fprintf('%-18s %11.3fs %11.3fs %11.3fs %11.3fs\n', names{w}, totalS(w, 1), ...
        min(totalS(w, :)), computeS(w, 1), min(computeS(w, :)));
end
fprintf('%-18s %11.3fs %11.3fs %11.3fs %11.3fs\n', 'sum', sum(totalS(:, 1)), ...
    sum(min(totalS, [], 2)), sum(computeS(:, 1)), sum(min(computeS, [], 2)));

timing = struct();
timing.matlab_version = version;
timing.arch = computer('arch');
timing.n_repeat = nRepeat;
timing.workloads = names;
timing.total_seconds = totalS;
timing.compute_seconds = computeS;
fid = fopen(fullfile(refDir, 'baseline_timings_matlab.json'), 'w');
if fid < 0
    error('run_all:export', 'cannot write %s', fullfile(refDir, 'baseline_timings_matlab.json'));
end
fprintf(fid, '%s\n', jsonencode(timing, 'PrettyPrint', true));
fclose(fid);

fprintf('\nReference JSON written to %s:\n', refDir);
for w = 1:nW
    fprintf('  %s.json\n', names{w});
end
fprintf('  baseline_timings_matlab.json\n');
fprintf(['\nCompare with the NumPy cross-check (from a shell in %s):\n' ...
         '  uv run --no-project --with numpy python reference_py/compare.py\n'], here);
end

function [seaTotal, seaCompute] = run_one(seaScriptPath, seaPlot)
% Runs one workload script in this function's private workspace.
SEA_EXPORT_REFERENCE = true; %#ok<NASGU> read by the script
SEA_PLOT = seaPlot; %#ok<NASGU>
SEA_SAVE_FIGURES = seaPlot; %#ok<NASGU>
computeSeconds = NaN;
seaT0 = tic;
run(seaScriptPath);
seaTotal = toc(seaT0);
seaCompute = computeSeconds;
end
