#!/bin/sh
# tests/accept4.sh -- the phase-4 acceptance programs (docs/DESIGN.md 6.3). POSIX sh, Mac.
#
# For each tests/accept/NAME.sea (with NAME.keys and NAME.wl): in a fresh temporary directory
# `sea build` it (in tests/accept/, as tests/run.sh builds, with the prelude), run it with
# SEA_HEAP_CHECK=1 and standard input /dev/null under a 120-second timeout. The status must be
# 0 and standard error exactly `heap: 0 live objects` and LF; standard output is written to
# <dir>/<wl>.json, and then
#     uv run --no-project --with numpy python <workloads>/reference_py/compare.py \
#         --candidate <dir> --keys <keys> <wl>
# must exit 0 (under the same timeout). <workloads> is sea/workloads (the submodule).
#
# usage: sh tests/accept4.sh [-v] [--save-out DIR] [PATTERN...]
#   -v              show the comparer's report for failures
#   --save-out DIR  also copy the standard output of every passing case to DIR/NAME.out (used
#                   by tests/cross_pack.sh: the Linux host compares against these bytes)
#   PATTERN         a substring of the test name (accept/NAME)
# Environment: BUILD (default build/), SEA (default $BUILD/sea), WORKLOADS (default
# sea/workloads), SEA_ACCEPT_TIMEOUT (seconds per run and per comparison, default 120).
# Output as tests/run.sh: `FAIL accept/NAME: <reason>`, `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error (no uv, no workloads checkout, ...).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
WORKLOADS=${WORKLOADS:-$ROOT/workloads}
TIMEOUT=${SEA_ACCEPT_TIMEOUT:-120}
VERBOSE=0
SAVE=
while [ $# -gt 0 ]; do
    case $1 in
    -v) VERBOSE=1; shift ;;
    --save-out)
        [ $# -ge 2 ] || { echo "accept4.sh: missing argument for '--save-out'" >&2; exit 2; }
        SAVE=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "accept4.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
PATTERNS="$*"

COMPARE=$WORKLOADS/reference_py/compare.py
[ -x "$SEA" ] || { echo "accept4.sh: driver '$SEA' not found or not executable; run 'make' first" >&2; exit 2; }
command -v uv >/dev/null 2>&1 || { echo "accept4.sh: uv not found (it runs compare.py)" >&2; exit 2; }
[ -f "$COMPARE" ] || { echo "accept4.sh: '$COMPARE' not found (is the sea/workloads submodule checked out?)" >&2; exit 2; }
if [ -n "$SAVE" ]; then mkdir -p "$SAVE" || { echo "accept4.sh: cannot create '$SAVE'" >&2; exit 2; }; fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-accept.XXXXXX") || exit 2
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

for src in "$ROOT"/tests/accept/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    name=accept/$nm
    selected "$name" || continue
    base=${src%.sea}
    if [ ! -f "$base.keys" ] || [ ! -f "$base.wl" ]; then fail "$name" "missing $nm.keys or $nm.wl"; continue; fi
    keys=$(sed -n 1p "$base.keys")
    wl=$(sed -n 1p "$base.wl")
    if [ -z "$keys" ] || [ -z "$wl" ]; then fail "$name" "$nm.keys or $nm.wl is empty"; continue; fi
    d=$(mktemp -d "$TMP/case.XXXXXX") || exit 2
    run_limited "${SEA_COMPILE_TIMEOUT:-120}" "$ROOT/tests/accept" "$SEA" build "$nm.sea" -o "$d/prog" >"$d/c.out" 2>"$d/c.err"
    st=$?
    if [ $st -ne 0 ]; then
        fail "$name" "compile failed (status $st): $(head -3 "$d/c.err" | tr '\n' ' ')"; rm -rf "$d"; continue
    fi
    mkdir "$d/run"
    SEA_HEAP_CHECK=1; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" "$d/run" "$d/prog" >"$d/$wl.json" 2>"$d/r.err"
    st=$?
    unset SEA_HEAP_CHECK
    ok=1
    [ $st -eq 0 ] || { fail "$name" "exit status $st, expected 0"; ok=0; }
    if [ $ok = 1 ] && ! cmp -s "$d/r.err" "$TMP/heapline"; then
        fail "$name" "standard error is not exactly 'heap: 0 live objects': $(head -3 "$d/r.err" | tr '\n' ' ')"; ok=0
    fi
    if [ $ok = 1 ] && [ -n "$(ls -A "$d/run")" ]; then fail "$name" "the program wrote files"; ok=0; fi
    if [ $ok = 1 ]; then
        mkdir "$d/cand"; cp "$d/$wl.json" "$d/cand/$wl.json"
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE" --candidate "$d/cand" --keys "$keys" "$wl" >"$d/cmp.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "compare.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/cmp.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/cmp.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ] && [ -n "$SAVE" ]; then cp "$d/$wl.json" "$SAVE/$nm.out" || { echo "accept4.sh: cannot write '$SAVE/$nm.out'" >&2; exit 2; }; fi
    rm -rf "$d"
    [ $ok = 1 ] && pass
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
