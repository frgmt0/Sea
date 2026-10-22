function run_all(makePlots, nRepeat, threads, names)
%RUN_ALL  Run every Sea acceptance workload, export the reference JSON and report, time each one.
%
%   run_all                    run each workload 5 times without figures, write reference/*
%   run_all(true)              also draw the figures and save them to output/
%   run_all(false, N)          run each workload N times (timing statistics over N runs)
%   run_all(false, N, 1)       the same with MATLAB limited to one computational thread
%   run_all(false, N, 'default')  the default (all threads); same as leaving it out
%   run_all(false, N, T, NAMES)   only the workloads in the cell array NAMES, e.g.
%                                 {'w6_topopt'}; 'all' = W1-W6. Leaving NAMES out runs the
%                                 five v1 acceptance workloads W1-W5 (DESIGN.md §1.2).
%
%   Works from any current folder: all paths are relative to this file. Each workload runs
%   in its own workspace with SEA_EXPORT_REFERENCE = true, so reference/<name>.json is
%   (re)written on every repetition (the results are deterministic). On the LAST repetition
%   of each workload, its printed report is also captured with diary to reference/<name>.txt
%   (an existing file is deleted first; the file holds only that script's output). The capture
%   never shares a repetition with figure drawing (plot warnings would leak into the text):
%   with makePlots = true the capture is made on repetition N-1 and the figures on N, and with
%   makePlots = true and N = 1 no report is captured (a note is printed). The state of the
%   user's own diary (on/off and file) is saved and restored around each capture.
%
%   The timing table (first, median and best over the N repetitions) is printed. With N >= 5
%   it is also written to reference/baseline_timings_matlab.json, or, for threads = 1, to
%   reference/baseline_timings_matlab_1thread.json. With N < 5 (a quick run) no timing file is
%   written. The timing file records the MATLAB version, architecture, the number of
%   computational threads in effect (max_num_comp_threads), the machine model and CPU brand,
%   and all timings. When NAMES is not the default W1-W5 set, the timing file name gets the
%   suffix _<name1>_<name2>... (baseline_timings_matlab_w6_topopt.json,
%   baseline_timings_matlab_1thread_w6_topopt.json), so the committed W1-W5 baseline is not
%   overwritten.
%   With a single workload, jsonencode writes the per-workload timing fields as flat arrays
%   (total_seconds, compute_seconds) and plain numbers (the medians and bests) instead of
%   arrays of rows.
%
%   threads = 1 calls maxNumCompThreads(1) for the duration of the run and restores the
%   previous value afterwards (also on error).
%
%   "total" is the wall time of the whole script (setup, compute, report, figures, export);
%   "compute" is the script's own tic/toc around its numerical part. The first repetition
%   includes MATLAB's JIT warm-up; "best" is the minimum and "median" the median over all
%   repetitions.
%
%   Reference procedure: run_all(false, 5, 1) first, then run_all(false, 5), so that the
%   reference JSON and report texts last written come from the default-threaded run.
%   For W6 alone: run_all(false, 5, 1, {'w6_topopt'}) then run_all(false, 5, 'default',
%   {'w6_topopt'}).

minBaselineRepeat = 5;
if nargin < 1, makePlots = false; end
if nargin < 2, nRepeat = 5; end
if nargin < 3, threads = 'default'; end
v1Names = {'w1_shaft_design', 'w2_truss_fem', 'w3_quarter_car', 'w4_heat_plate', ...
           'w5_tolerance_mc'};
allNames = [v1Names, {'w6_topopt'}];
if nargin < 4
    names = v1Names;
elseif (ischar(names) && strcmp(names, 'all')) ...
        || (isstring(names) && isscalar(names) && names == "all")
    names = allNames;
end
if ~iscellstr(names) || isempty(names) || ~all(ismember(names, allNames)) ...
        || numel(unique(names)) ~= numel(names)
    error('run_all:args', 'names must be ''all'' or a cell array of distinct workload names');
end
names = names(:).';   % a row, whatever shape was passed
if ~(isnumeric(nRepeat) && isscalar(nRepeat) && isfinite(nRepeat) && nRepeat >= 1 ...
        && nRepeat == fix(nRepeat))
    error('run_all:args', 'nRepeat must be a positive integer');
end
if isnumeric(threads) && isscalar(threads) && threads == 1
    singleThread = true;
elseif (ischar(threads) || isstring(threads)) && strcmp(threads, 'default')
    singleThread = false;
else
    error('run_all:args', 'threads must be ''default'' or 1');
end

here = fileparts(mfilename('fullpath'));
refDir = fullfile(here, 'reference');
if ~isfolder(refDir)
    mkdir(refDir);
end
nW = numel(names);
totalS = zeros(nW, nRepeat);
computeS = zeros(nW, nRepeat);

% Thread limit for the whole run; the previous value comes back when this function ends.
if singleThread
    previousThreads = maxNumCompThreads;
    restoreThreads = onCleanup(@() maxNumCompThreads(previousThreads)); %#ok<NASGU>
    maxNumCompThreads(1);
end
threadsInEffect = maxNumCompThreads;

% Repetition on which the report is captured: never one that draws figures.
if ~makePlots
    captureRep = nRepeat;
elseif nRepeat >= 2
    captureRep = nRepeat - 1;
else
    captureRep = 0;
end

for w = 1:nW
    scriptPath = fullfile(here, [names{w} '.m']);
    if ~exist(scriptPath, 'file')
        error('run_all:missing', 'workload script not found: %s', scriptPath);
    end
    reportPath = fullfile(refDir, [names{w} '.txt']);
    for r = 1:nRepeat
        plotThis = makePlots && r == nRepeat;
        if r == captureRep
            captureTo = reportPath;
        else
            captureTo = '';
        end
        [totalS(w, r), computeS(w, r)] = run_one(scriptPath, plotThis, captureTo);
    end
end

[machineModel, cpuBrand, machineNote] = machine_info();

fprintf('\n=== Sea workloads: MATLAB %s on %s, %d repetition(s), %d computational thread(s) ===\n', ...
    version, computer('arch'), nRepeat, threadsInEffect);
if ~isempty(machineModel)
    fprintf('Machine: %s', machineModel);
    if ~isempty(cpuBrand) && ~strcmp(cpuBrand, machineModel)
        fprintf(' (%s)', cpuBrand);
    end
    fprintf('\n');
elseif ~isempty(machineNote)
    fprintf('Machine: unknown (%s)\n', machineNote);
end
fprintf('%-18s | %9s %9s %9s | %9s %9s %9s\n', 'workload', 'total 1st', 'median', 'best', ...
    'comp 1st', 'median', 'best');
for w = 1:nW
    fprintf('%-18s | %8.3fs %8.3fs %8.3fs | %8.3fs %8.3fs %8.3fs\n', names{w}, ...
        totalS(w, 1), median(totalS(w, :)), min(totalS(w, :)), ...
        computeS(w, 1), median(computeS(w, :)), min(computeS(w, :)));
end
fprintf('%-18s | %8.3fs %8.3fs %8.3fs | %8.3fs %8.3fs %8.3fs\n', 'sum', ...
    sum(totalS(:, 1)), sum(median(totalS, 2)), sum(min(totalS, [], 2)), ...
    sum(computeS(:, 1)), sum(median(computeS, 2)), sum(min(computeS, [], 2)));

if singleThread
    timingStem = 'baseline_timings_matlab_1thread';
else
    timingStem = 'baseline_timings_matlab';
end
if isequal(names, v1Names)
    timingName = [timingStem '.json'];
else
    timingName = [timingStem '_' strjoin(names, '_') '.json'];
end
writeTiming = nRepeat >= minBaselineRepeat;
if writeTiming
    timing = struct();
    timing.matlab_version = version;
    timing.arch = computer('arch');
    timing.n_repeat = nRepeat;
    timing.threads_mode = char(string(threads));
    timing.max_num_comp_threads = threadsInEffect;
    timing.machine_model = machineModel;
    timing.cpu_brand = cpuBrand;
    timing.machine_note = machineNote;
    timing.workloads = names;
    timing.total_seconds = totalS;
    timing.compute_seconds = computeS;
    timing.total_seconds_median = median(totalS, 2);
    timing.compute_seconds_median = median(computeS, 2);
    timing.total_seconds_best = min(totalS, [], 2);
    timing.compute_seconds_best = min(computeS, [], 2);
    fid = fopen(fullfile(refDir, timingName), 'w');
    if fid < 0
        error('run_all:export', 'cannot write %s', fullfile(refDir, timingName));
    end
    fprintf(fid, '%s\n', jsonencode(timing, 'PrettyPrint', true));
    fclose(fid);
end

fprintf('\nReference files written to %s:\n', refDir);
for w = 1:nW
    if captureRep > 0
        fprintf('  %s.json  %s.txt\n', names{w}, names{w});
    else
        fprintf('  %s.json\n', names{w});
    end
end
if captureRep == 0
    fprintf(['\nNote: figures were requested with a single repetition, so no report text ' ...
             '(reference/<name>.txt) was captured; use at least 2 repetitions.\n']);
end
if writeTiming
    fprintf('  %s\n', timingName);
else
    fprintf(['\nNote: %d repetition(s) is fewer than %d, so no baseline timing file was ' ...
             'written.\n'], nRepeat, minBaselineRepeat);
end
fprintf(['\nCompare with the NumPy cross-check (from a shell in %s):\n' ...
         '  uv run --no-project --with numpy python reference_py/compare.py\n'], here);
end

function [seaTotal, seaCompute] = run_one(seaScriptPath, seaPlot, seaReportPath)
% Runs one workload script in this function's private workspace. When seaReportPath is not
% empty, the script's printed report (and nothing else) is captured to that file with diary.
SEA_EXPORT_REFERENCE = true; %#ok<NASGU> read by the script
SEA_PLOT = seaPlot; %#ok<NASGU>
SEA_SAVE_FIGURES = seaPlot; %#ok<NASGU>
computeSeconds = NaN;
seaCapture = ~isempty(seaReportPath);
if seaCapture
    % diary appends to an existing file, so start from a fresh one. The guard switches the
    % diary off again whenever this function ends, also when the script throws an error.
    seaDiaryState = get(0, 'Diary');
    seaDiaryFile = get(0, 'DiaryFile');
    seaDiaryGuard = onCleanup(@() restore_diary(seaDiaryState, seaDiaryFile)); %#ok<NASGU>
    if exist(seaReportPath, 'file')
        delete(seaReportPath);
    end
    diary(seaReportPath);
    diary('on');
end
seaT0 = tic;
run(seaScriptPath);
seaTotal = toc(seaT0);
if seaCapture
    diary('off');   % the guard then puts the user's own diary state back
end
seaCompute = computeSeconds;
end

function restore_diary(state, file)
% Puts the user's diary state back: the file they had and on/off as it was.
diary('off');
set(0, 'DiaryFile', file);
if strcmp(state, 'on')
    diary('on');
end
end

function [model, brand, note] = machine_info()
% Machine model and CPU brand string, as cheaply as the platform allows; empty if unknown.
model = '';
brand = '';
note = '';
if ismac
    [st, out] = system('sysctl -n hw.model');
    if st == 0
        model = strtrim(out);
    end
    [st, out] = system('sysctl -n machdep.cpu.brand_string');
    if st == 0
        brand = strtrim(out);
    end
elseif isunix
    try
        txt = fileread('/proc/cpuinfo');
        tok = regexp(txt, 'model name\s*:\s*([^\n]*)', 'tokens', 'once');
        if ~isempty(tok)
            model = strtrim(tok{1});
            brand = model;
        end
    catch
        model = '';
    end
end
if isempty(model)
    note = 'machine model not available on this platform (not macOS, or Linux without /proc/cpuinfo model name)';
end
end
