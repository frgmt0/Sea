#!/bin/sh
# tests/accept.sh -- the phase-6 acceptance programs: the ports (docs/DESIGN.md 6.3). POSIX sh, Mac.
#
# For each ports/NAME.sea (NAME a workload name, with NAME.tokens): in a fresh temporary
# directory T, `sea build -o T/run/NAME` (in ports/, with the prelude) under the compile
# timeout, then run T/run/NAME in the working directory T/run with --export-reference,
# SEA_HEAP_CHECK=1 and standard input /dev/null under a 120-second timeout; standard output goes
# to T/report.txt and standard error to T/stderr.txt. The status must be 0, standard error
# exactly `heap: 0 live objects` and LF, and T/run must hold NAME.json and nothing else but the
# executable. Then
#     uv run --no-project --with numpy python <workloads>/reference_py/compare.py \
#         --candidate T/run NAME
#     uv run --no-project --with numpy python <workloads>/reference_py/compare_report.py \
#         NAME T/report.txt ports/NAME.tokens --candidate-json T/run/NAME.json
# must both exit 0. <workloads> is sea/workloads (a directory of the sea repo).
#
# usage: sh tests/accept.sh [-v] [--save-out DIR] [PATTERN...]
#   -v              show the comparers' reports for failures
#   --save-out DIR  also copy the standard output of every passing case to DIR/NAME.out and its
#                   NAME.json to DIR/NAME.json (used by tests/cross_pack.sh)
#   PATTERN         a substring of the test name (ports/NAME)
# Environment: BUILD (default build/), SEA (default $BUILD/sea), WORKLOADS (default
# sea/workloads), SEA_COMPILE_TIMEOUT (seconds per compilation, default 120),
# SEA_ACCEPT_TIMEOUT (seconds per run and per comparison, default 120).
# Output as tests/run.sh: `FAIL ports/NAME: <reason>`, `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error (no uv, no workloads directory, ...).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
WORKLOADS=${WORKLOADS:-$ROOT/workloads}
TIMEOUT=${SEA_ACCEPT_TIMEOUT:-120}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
VERBOSE=0
SAVE=
while [ $# -gt 0 ]; do
    case $1 in
    -v) VERBOSE=1; shift ;;
    --save-out)
        [ $# -ge 2 ] || { echo "accept.sh: missing argument for '--save-out'" >&2; exit 2; }
        SAVE=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "accept.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
PATTERNS="$*"

COMPARE=$WORKLOADS/reference_py/compare.py
COMPARE_REPORT=$WORKLOADS/reference_py/compare_report.py
[ -x "$SEA" ] || { echo "accept.sh: driver '$SEA' not found or not executable; run 'make' first" >&2; exit 2; }
command -v uv >/dev/null 2>&1 || { echo "accept.sh: uv not found (it runs compare.py)" >&2; exit 2; }
[ -f "$COMPARE" ] || { echo "accept.sh: '$COMPARE' not found (is the sea/workloads directory there?)" >&2; exit 2; }
[ -f "$COMPARE_REPORT" ] || { echo "accept.sh: '$COMPARE_REPORT' not found" >&2; exit 2; }
if [ -n "$SAVE" ]; then mkdir -p "$SAVE" || { echo "accept.sh: cannot create '$SAVE'" >&2; exit 2; }; fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-accept6.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM

PASS=0
FAIL=0
FAILED=""
selected() {
    [ -z "$PATTERNS" ] && return 0
    set -f
    for p in $PATTERNS; do
        case "$1" in *"$p"*) set +f; return 0 ;; esac
    done
    set +f
    return 1
}
pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }

# run_limited SECONDS WORKDIR CMD... : stdin /dev/null; killed after SECONDS (status 137)
run_limited() {
    _t=$1; _wd=$2; shift 2
    (cd "$_wd" && exec "$@" </dev/null) &
    _cpid=$!
    (
        _i=0
        while [ "$_i" -lt $((_t * 10)) ]; do
            sleep 0.1
            kill -0 "$_cpid" 2>/dev/null || exit 0
            _i=$((_i + 1))
        done
        kill -9 "$_cpid" 2>/dev/null
    ) &
    _wpid=$!
    wait "$_cpid"
    _st=$?
    kill "$_wpid" 2>/dev/null
    wait "$_wpid" 2>/dev/null
    return $_st
}

printf 'heap: 0 live objects\n' > "$TMP/heapline"

for src in "$ROOT"/ports/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    name=ports/$nm
    selected "$name" || continue
    base=${src%.sea}
    if [ ! -f "$base.tokens" ]; then fail "$name" "missing $nm.tokens"; continue; fi
    d=$(mktemp -d "$TMP/case.XXXXXX") || exit 2
    mkdir "$d/run"
    run_limited "$CTIMEOUT" "$ROOT/ports" "$SEA" build "$nm.sea" -o "$d/run/$nm" >"$d/c.out" 2>"$d/c.err"
    st=$?
    if [ $st -ne 0 ]; then
        fail "$name" "compile failed (status $st): $(head -3 "$d/c.err" | tr '\n' ' ')"; rm -rf "$d"; continue
    fi
    SEA_HEAP_CHECK=1; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" "$d/run" "$d/run/$nm" --export-reference >"$d/report.txt" 2>"$d/stderr.txt"
    st=$?
    unset SEA_HEAP_CHECK
    ok=1
    [ $st -eq 0 ] || { fail "$name" "exit status $st, expected 0"; ok=0; }
    if [ $ok = 1 ] && ! cmp -s "$d/stderr.txt" "$TMP/heapline"; then
        fail "$name" "standard error is not exactly 'heap: 0 live objects': $(head -3 "$d/stderr.txt" | tr '\n' ' ')"; ok=0
    fi
    if [ $ok = 1 ]; then
        extra=$(cd "$d/run" && /bin/ls -A | grep -v -x -F -e "$nm" -e "$nm.json")
        if [ -n "$extra" ]; then fail "$name" "the program wrote unexpected files: $(echo "$extra" | tr '\n' ' ')"; ok=0; fi
    fi
    if [ $ok = 1 ] && [ ! -f "$d/run/$nm.json" ]; then fail "$name" "the program did not write $nm.json"; ok=0; fi
    if [ $ok = 1 ]; then
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE" --candidate "$d/run" "$nm" >"$d/cmp.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "compare.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/cmp.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/cmp.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ]; then
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE_REPORT" "$nm" "$d/report.txt" "$base.tokens" \
            --candidate-json "$d/run/$nm.json" >"$d/rep.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "compare_report.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/rep.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/rep.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ] && [ -n "$SAVE" ]; then
        /bin/cp -f "$d/report.txt" "$SAVE/$nm.out" && /bin/cp -f "$d/run/$nm.json" "$SAVE/$nm.json" \
            || { echo "accept.sh: cannot write to '$SAVE'" >&2; exit 2; }
    fi
    rm -rf "$d"
    [ $ok = 1 ] && pass
done

if [ -z "$PATTERNS" ] && [ $((PASS + FAIL)) -eq 0 ]; then
    echo "accept.sh: no port selected (no $ROOT/ports/*.sea)" >&2
    exit 2
fi

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
