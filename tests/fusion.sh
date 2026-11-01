#!/bin/sh
# tests/fusion.sh -- the temporaries check of phase 7 (docs/DESIGN.md 2.12.10 "The temporaries
# check", Decision 105, L-fa, L-fk). POSIX sh + awk. Builds nothing: it uses the installed
# compiler build/sea (run make first).
#
# usage: sh tests/fusion.sh [-v] [PATTERN...]     PATTERN: a substring of the test name fusion/NAME
#   -v  also print each run's standard output and heap line
#
# tests/fusion/NAME.sea   a program that takes its iteration count K from args() (one decimal
#   argument) and whose header comment holds, besides the hand derivation of its allocations per
#   iteration from F1-F5 (L-fa), the two lines the check reads:
#       // fusion K: N                       the K of the check
#       // Allocations per iteration: N.     the derived count (the derivation's last line)
# The program is compiled as tests/run.sh compiles (`sea build --keep-temps NAME.sea` in
# tests/fusion/, the kept sea.lir validated with lirchk, the driver's `sea: temporary files kept
# in DIR` line removed from its standard error, which must then be empty), then run twice in a
# fresh empty working directory, with the argument K and with K + 1, stdin /dev/null, under
# SEA_HEAP_CHECK=count. Each run must exit 0 with a standard error that is exactly one line,
# `heap: A allocations, L live objects` (DESIGN.md 4.5, the count mode), with L = 0, and leave the
# working directory empty. The check passes when A(K + 1) - A(K) equals the derived count: the
# allocations of one iteration, everything outside the loop cancelling. A difference other than
# the derived count is a compiler defect (fusion not doing what F1-F5 require) or a runtime
# counting defect; it is never fixed by changing the expected number (2.12.10).
#
# Environment: BUILD (default build/), SEA (default $BUILD/sea), LIRCHK (default
# $BUILD/tools/lirchk), SEA_COMPILE_TIMEOUT (seconds per compilation, 120), SEA_TEST_TIMEOUT
# (seconds per run, 10), TMPDIR.
# Output as tests/run.sh: `ok   fusion/NAME: ...` per passing test, `FAIL fusion/NAME: reason`,
# then `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
LIRCHK=${LIRCHK:-$BUILD/tools/lirchk}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"

if [ ! -x "$SEA" ]; then
    echo "fusion.sh: driver '$SEA' not found or not executable; run 'make' first" >&2
    exit 2
fi
if [ ! -x "$LIRCHK" ]; then
    echo "fusion.sh: validator '$LIRCHK' not found or not executable; run 'make' first (LIRCHK overrides)" >&2
    exit 2
fi
ls "$ROOT"/tests/fusion/*.sea >/dev/null 2>&1 || { echo "fusion.sh: no tests/fusion/*.sea" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-fusion.XXXXXX") || exit 2
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

# header_num FILE.sea PREFIX : the number N of the first line `PREFIX N` (for the count, `PREFIX N.`)
header_num() {
    awk -v pre="$2" '
    index($0, pre) == 1 {
        s = substr($0, length(pre) + 1); sub(/\.$/, "", s)
        if (s ~ /^[0-9]+$/) { print s; exit }
    }' "$1"
}

# count_run EXE ARG : run EXE ARG under SEA_HEAP_CHECK=count in a fresh directory; sets RUN_A
# (the allocation count) or RUN_WHY (the reason it failed)
count_run() {
    RUN_A=; RUN_WHY=
    _arg=$2
    _w=$(mktemp -d "$TMP/work.XXXXXX") || { RUN_WHY="cannot create a work directory"; return 1; }
    SEA_HEAP_CHECK=count; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" "$_w" "$1" "$2" >"$TMP/r.out" 2>"$TMP/r.err"
    _st=$?
    unset SEA_HEAP_CHECK
    _left=$(ls -A "$_w")
    rm -rf "$_w"
    if [ $_st -ne 0 ]; then RUN_WHY="K=$2: exit status $_st: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; return 1; fi
    if [ -n "$_left" ]; then RUN_WHY="K=$2: unexpected files left: $_left"; return 1; fi
    if [ "$(wc -l <"$TMP/r.err" | tr -d ' ')" != 1 ]; then
        RUN_WHY="K=$2: standard error is not exactly the heap line: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; return 1
    fi
    _l=$(cat "$TMP/r.err")
    _a=$(printf '%s\n' "$_l" | sed -n 's/^heap: \([0-9][0-9]*\) allocations, \([0-9][0-9]*\) live objects$/\1 \2/p')
    if [ -z "$_a" ]; then RUN_WHY="K=$2: no count-mode heap line: '$_l'"; return 1; fi
    set -- $_a
    if [ "$2" != 0 ]; then RUN_WHY="K=$_arg: leak: '$_l'"; return 1; fi
    RUN_A=$1
    if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$TMP/r.out"; echo "    $_l"; fi
    return 0
}

for src in "$ROOT"/tests/fusion/*.sea; do
    nm=$(basename "$src" .sea)
    name=fusion/$nm
    selected "$name" || continue
    k=$(header_num "$src" "// fusion K: ")
    want=$(header_num "$src" "// Allocations per iteration: ")
    if [ -z "$k" ] || [ -z "$want" ]; then
        echo "fusion.sh: $nm.sea lacks its '// fusion K: N' or '// Allocations per iteration: N.' header line" >&2
        exit 2
    fi
    exe=$TMP/$nm
    run_limited "$CTIMEOUT" "$ROOT/tests/fusion" "$SEA" build --keep-temps -o "$exe" "$nm.sea" \
        >"$TMP/c.out" 2>"$TMP/c.raw"
    st=$?
    kept=$(sed -n 's/^sea: temporary files kept in //p' "$TMP/c.raw" | head -1)
    grep -v '^sea: temporary files kept in ' "$TMP/c.raw" > "$TMP/c.err"
    lc=0
    if [ $st -eq 0 ] && [ -n "$kept" ] && [ -f "$kept/sea.lir" ]; then
        run_limited "$CTIMEOUT" "$kept" "$LIRCHK" >"$TMP/k.out" 2>"$TMP/k.err" || lc=$?
    fi
    [ -n "$kept" ] && [ -d "$kept" ] && rm -rf "$kept"
    if [ $st -ne 0 ] || [ -s "$TMP/c.out" ] || [ -s "$TMP/c.err" ] || [ ! -x "$exe" ]; then
        fail "$name" "sea build failed (status $st): $(cat "$TMP/c.err" "$TMP/c.out" | head -3 | tr '\n' ' ')"; continue
    fi
    if [ $lc -ne 0 ]; then
        fail "$name" "lirchk: rejects sea.lir (status $lc): $(cat "$TMP/k.err" "$TMP/k.out" | head -3 | tr '\n' ' ')"; continue
    fi
    count_run "$exe" "$k" || { fail "$name" "$RUN_WHY"; continue; }
    a1=$RUN_A
    k2=$((k + 1))
    count_run "$exe" "$k2" || { fail "$name" "$RUN_WHY"; continue; }
    a2=$RUN_A
    d=$((a2 - a1))
    if [ "$d" -eq "$want" ]; then
        pass
        echo "ok   $name: $a1 allocations at K=$k, $a2 at K=$k2: $d per iteration"
    else
        fail "$name" "$a1 allocations at K=$k, $a2 at K=$k2: $d per iteration, derived $want"
    fi
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
