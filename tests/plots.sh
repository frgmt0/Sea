#!/bin/sh
# tests/plots.sh -- the plot tests of phase 9 (docs/DESIGN.md 2.14.8 "The runner", Decision 137 (a)).
# POSIX sh, Mac. Builds nothing: it uses the installed compiler build/sea (run make first).
#
# usage: sh tests/plots.sh [-v] [--save-out DIR] [--only NAME] [PATTERN...]
#   -v              show diffs and plot_struct.py's report for failures
#   --save-out DIR  also copy the standard output of every passing case to DIR/NAME.out and every
#                   file its .struct names to DIR/NAME.expect/PATH (used by tests/cross_pack.sh)
#   --only NAME     run exactly the case plots/NAME (cross_pack.sh: a pattern is a substring and
#                   would also select plots/NAME_more)
#   PATTERN         a substring of the test name (plots/NAME)
#
# tests/plots/NAME.sea     a plotting program; NAME.struct (REQUIRED) its structure (2.14.8, the
#   format read by tests/plot_struct.py), NAME.out (optional) its exact standard output (absent:
#   empty). The program is compiled as tests/run.sh compiles (`sea build --keep-temps NAME.sea` in
#   tests/plots/, under SEA_COMPILE_TIMEOUT; the kept sea.lir validated with lirchk; the driver's
#   `sea: temporary files kept in DIR` line removed from its standard error, which must then be
#   empty), the executable written into a fresh run directory T/run, and run there (working
#   directory T/run) with SEA_HEAP_CHECK=1, standard input /dev/null, no arguments, under
#   SEA_TEST_TIMEOUT. The status must be 0, standard error exactly `heap: 0 live objects` and LF,
#   standard output equal to NAME.out, and T/run must hold only the executable and the files the
#   .struct names in its `file` lines (with the directories that contain them). Then
#       timeout 120 uv run --no-project python tests/plot_struct.py tests/plots/NAME.struct T/run
#   must print PASS and exit 0 (1 is a failure of the case, 2 a corpus mistake: setup error).
#
# Environment: BUILD (default build/), SEA (default $BUILD/sea), LIRCHK (default
# $BUILD/tools/lirchk), SEA_COMPILE_TIMEOUT (seconds per compilation, 120), SEA_TEST_TIMEOUT
# (seconds per run, 10), TMPDIR. Needs uv (as test-accept does).
# Output as tests/run.sh: `FAIL plots/NAME: reason`, then `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
LIRCHK=${LIRCHK:-$BUILD/tools/lirchk}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=0
SAVE=
ONLY=
while [ $# -gt 0 ]; do
    case $1 in
    -v) VERBOSE=1; shift ;;
    --save-out)
        [ $# -ge 2 ] || { echo "plots.sh: missing argument for '--save-out'" >&2; exit 2; }
        SAVE=$2; shift 2 ;;
    --only)
        [ $# -ge 2 ] || { echo "plots.sh: missing argument for '--only'" >&2; exit 2; }
        ONLY=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "plots.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
PATTERNS="$*"

[ -x "$SEA" ] || { echo "plots.sh: driver '$SEA' not found or not executable; run 'make' first" >&2; exit 2; }
[ -x "$LIRCHK" ] || { echo "plots.sh: validator '$LIRCHK' not found or not executable; run 'make' first (LIRCHK overrides)" >&2; exit 2; }
command -v uv >/dev/null 2>&1 || { echo "plots.sh: uv not found (it runs tests/plot_struct.py)" >&2; exit 2; }
[ -f "$ROOT/tests/plot_struct.py" ] || { echo "plots.sh: tests/plot_struct.py missing" >&2; exit 2; }
ls "$ROOT"/tests/plots/*.sea >/dev/null 2>&1 || { echo "plots.sh: no tests/plots/*.sea" >&2; exit 2; }
if [ -n "$ONLY" ] && [ ! -f "$ROOT/tests/plots/$ONLY.sea" ]; then
    echo "plots.sh: no tests/plots/$ONLY.sea" >&2; exit 2
fi
if [ -n "$SAVE" ]; then mkdir -p "$SAVE" || { echo "plots.sh: cannot create '$SAVE'" >&2; exit 2; }; fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-plots.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
: > "$TMP/empty"

PASS=0
FAIL=0
FAILED=""
selected() {
    if [ -n "$ONLY" ]; then [ "$1" = "plots/$ONLY" ]; return; fi
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

# struct_files STRUCT : the paths of its `file` lines, one per line (leading blanks ignored, as
# plot_struct.py reads them; the path is the rest of the line after `file `)
struct_files() {
    sed -n 's/^[[:space:]]*file \(.*\)$/\1/p' "$1"
}

# allowed_dirs : every directory prefix of the paths in $TMP/files (a/b/c.svg gives a and a/b)
allowed_dirs() {
    awk '{ n = split($0, p, "/"); d = ""; for (i = 1; i < n; i++) { d = (d == "" ? p[i] : d "/" p[i]); print d } }' "$TMP/files" | sort -u
}

for src in "$ROOT"/tests/plots/*.sea; do
    nm=$(basename "$src" .sea)
    name=plots/$nm
    selected "$name" || continue
    base=${src%.sea}
    if [ ! -f "$base.struct" ]; then
        echo "plots.sh: tests/plots/$nm.sea has no $nm.struct" >&2; exit 2
    fi
    struct_files "$base.struct" > "$TMP/files"
    if [ ! -s "$TMP/files" ]; then echo "plots.sh: tests/plots/$nm.struct names no file" >&2; exit 2; fi
    if grep -q -e '^/' -e '^\.\./' -e '/\.\./' -e '^\./' "$TMP/files"; then
        echo "plots.sh: tests/plots/$nm.struct: a file path must be relative and plain" >&2; exit 2
    fi
    if grep -qx "$nm" "$TMP/files"; then
        echo "plots.sh: tests/plots/$nm.struct: a file may not have the executable's name" >&2; exit 2
    fi
    rm -rf "$TMP/t"; mkdir -p "$TMP/t/run" || exit 2
    exe=$TMP/t/run/$nm
    run_limited "$CTIMEOUT" "$ROOT/tests/plots" "$SEA" build --keep-temps -o "$exe" "$nm.sea" \
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
        fail "$name" "lirchk rejects sea.lir (status $lc): $(cat "$TMP/k.err" "$TMP/k.out" | head -3 | tr '\n' ' ')"; continue
    fi
    SEA_HEAP_CHECK=1; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" "$TMP/t/run" "./$nm" >"$TMP/r.out" 2>"$TMP/r.err"
    st=$?
    unset SEA_HEAP_CHECK
    if [ $st -ne 0 ]; then
        fail "$name" "exit status $st: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; continue
    fi
    printf 'heap: 0 live objects\n' > "$TMP/heap"
    if ! cmp -s "$TMP/heap" "$TMP/r.err"; then
        fail "$name" "standard error is not exactly the heap line: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; continue
    fi
    expout=$TMP/empty; [ -f "$base.out" ] && expout=$base.out
    if ! cmp -s "$expout" "$TMP/r.out"; then
        fail "$name" "stdout differs"
        if [ "$VERBOSE" = 1 ]; then diff -u "$expout" "$TMP/r.out" | sed 's/^/    /' | head -60; fi
        continue
    fi
    # the run directory: the executable, the named files and their directories, nothing else
    allowed_dirs > "$TMP/dirs"
    bad=
    for r in $(cd "$TMP/t/run" && find . -mindepth 1 | sed 's|^\./||' | sort); do
        if [ -d "$TMP/t/run/$r" ]; then
            grep -qxF "$r" "$TMP/dirs" || { bad="unexpected directory $r"; break; }
        else
            [ "$r" = "$nm" ] && continue
            grep -qxF "$r" "$TMP/files" || { bad="unexpected file $r"; break; }
        fi
    done
    if [ -n "$bad" ]; then fail "$name" "$bad"; continue; fi
    missing=
    while IFS= read -r f; do
        [ -f "$TMP/t/run/$f" ] || { missing=$f; break; }
    done < "$TMP/files"
    if [ -n "$missing" ]; then fail "$name" "the program did not write $missing"; continue; fi
    timeout 120 uv run --no-project python "$ROOT/tests/plot_struct.py" "$base.struct" "$TMP/t/run" \
        >"$TMP/p.out" 2>"$TMP/p.err"
    st=$?
    if [ $st -eq 2 ]; then
        echo "plots.sh: tests/plots/$nm.struct: $(cat "$TMP/p.err" "$TMP/p.out" | head -3 | tr '\n' ' ')" >&2; exit 2
    fi
    if [ $st -ne 0 ]; then
        fail "$name" "$(cat "$TMP/p.out" "$TMP/p.err" | head -3 | tr '\n' ' ')"; continue
    fi
    if [ -n "$SAVE" ]; then
        /bin/cp -f "$TMP/r.out" "$SAVE/$nm.out" || { echo "plots.sh: cannot write $SAVE/$nm.out" >&2; exit 2; }
        rm -rf "$SAVE/$nm.expect"
        while IFS= read -r f; do
            mkdir -p "$SAVE/$nm.expect/$(dirname "$f")" \
                && /bin/cp -f "$TMP/t/run/$f" "$SAVE/$nm.expect/$f" \
                || { echo "plots.sh: cannot write $SAVE/$nm.expect/$f" >&2; exit 2; }
        done < "$TMP/files"
    fi
    pass
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
