#!/bin/sh
# tests/stage.sh -- each pass on its own, on the committed golden output of the previous pass
# (docs/DESIGN.md 6.2, "stage.sh"). POSIX sh. Builds nothing: it runs the pass executables of
# build/ (run make first).
#
# For every tests/passes/NAME.<prev> that has the golden next file NAME.<next>:
#     pass 2a  seacheck    NAME.ast  -> NAME.hir1
#     pass 2b  seaexpand   NAME.hir1 -> NAME.hir
#     pass 3a  sealower    NAME.hir  -> NAME.lir1
#     pass 3b  seaopt      NAME.lir1 -> NAME.lir
#     pass 4   seagen_a64  NAME.lir  -> NAME.s     (golden assembly, optional)
# the golden previous file is copied as sea.<prev> into a fresh directory, the pass runs there
# (standard input /dev/null), must exit 0, and the sea.<next> it wrote must be byte-identical
# to the golden file and end with #end (the assembly of pass 4 has no #end). Pass 1
# (seaparse, NAME.sea -> NAME.ast) is tested through the driver: `sea build --emit ast
# --no-prelude NAME.sea`, which runs no other pass.
#
# A golden file whose pass executable is not built is a FAILURE ("not built"), not a skip.
#
# usage: sh tests/stage.sh [-v] [PATTERN...]      PATTERN: a substring of the test name
#        (stage/<pass>/NAME). Environment: BUILD (default build/), SEA_TEST_TIMEOUT (10).
# Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-stage.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
: > "$TMP/empty"
printf '#end\n' > "$TMP/end5"
printf '\n#end\n' > "$TMP/end6"

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
same() {
    if cmp -s "$1" "$2"; then return 0; fi
    fail "$4" "$3 differs"
    if [ "$VERBOSE" = 1 ]; then diff -u "$1" "$2" | sed 's/^/    /' | head -60; fi
    return 1
}

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
    wait "$_wpid" 2>/dev/null
    return $_st
}

# stage PASS PREV NEXT : one pass over every golden pair
stage() {
    _p=$1; _prev=$2; _next=$3
    for g in "$ROOT"/tests/passes/*."$_next"; do
        [ -e "$g" ] || continue
        nm=$(basename "$g" ".$_next")
        in=$ROOT/tests/passes/$nm.$_prev
        name=stage/$_p/$nm
        selected "$name" || continue
        if [ ! -f "$in" ]; then fail "$name" "golden input $nm.$_prev missing"; continue; fi
        if [ ! -x "$BUILD/$_p" ]; then fail "$name" "pass '$_p' not built ($BUILD/$_p)"; continue; fi
        w=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
        cp "$in" "$w/sea.$_prev"
        run_limited "$TIMEOUT" "$w" "$BUILD/$_p" >"$TMP/p.out" 2>"$TMP/p.err"
        st=$?
        ok=1
        [ $st -eq 0 ] || { fail "$name" "exit status $st: $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
        [ $ok = 1 ] && [ ! -f "$w/sea.$_next" ] && { fail "$name" "no sea.$_next written"; ok=0; }
        [ $ok = 1 ] && { same "$g" "$w/sea.$_next" "sea.$_next" "$name" || ok=0; }
        if [ $ok = 1 ] && [ "$_next" != s ]; then
            if ! { cmp -s "$w/sea.$_next" "$TMP/end5" || tail -c 6 "$w/sea.$_next" | cmp -s - "$TMP/end6"; }; then
                fail "$name" "sea.$_next does not end with #end"; ok=0
            fi
        fi
        [ $ok = 1 ] && { same "$TMP/empty" "$TMP/p.err" "stderr" "$name" || ok=0; }
        rm -rf "$w"
        [ $ok = 1 ] && pass
    done
}

# pass 1 through the driver
for g in "$ROOT"/tests/passes/*.ast; do
    [ -e "$g" ] || continue
    nm=$(basename "$g" .ast)
    [ -f "$ROOT/tests/passes/$nm.sea" ] || continue
    name=stage/seaparse/$nm
    selected "$name" || continue
    if [ ! -x "$BUILD/seaparse" ] || [ ! -x "$BUILD/sea" ]; then fail "$name" "pass 'seaparse' (or the driver) not built ($BUILD)"; continue; fi
    (cd "$ROOT/tests/passes" && exec "$BUILD/sea" build --emit ast --no-prelude "$nm.sea") >"$TMP/p.out" 2>"$TMP/p.err" </dev/null
    st=$?
    ok=1
    [ $st -eq 0 ] || { fail "$name" "exit status $st: $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
    [ $ok = 1 ] && { same "$g" "$TMP/p.out" "sea.ast" "$name" || ok=0; }
    [ $ok = 1 ] && { same "$TMP/empty" "$TMP/p.err" "stderr" "$name" || ok=0; }
    [ $ok = 1 ] && pass
done

stage seacheck ast hir1
stage seaexpand hir1 hir
stage sealower hir lir1
stage seaopt lir1 lir
stage seagen_a64 lir s

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
