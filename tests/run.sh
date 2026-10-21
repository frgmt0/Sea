#!/bin/sh
# tests/run.sh -- Sea test runner for programs/, errors/ and passes/ (POSIX sh, docs/DESIGN.md 6.2).
# Builds nothing: it uses the installed compiler build/sea (run make first).
#
# usage: sh tests/run.sh [-v] [PATTERN...]
#   -v        show diffs for failures
#   PATTERN   only run tests whose name (programs/NAME, errors/NAME, passes/NAME.X) contains one
#
# Environment:
#   SEA                   the driver to test      (default: build/sea; BUILD overrides build/)
#   SEA_TEST_TIMEOUT      seconds per program run (default: 10)
#   SEA_COMPILE_TIMEOUT   seconds per compilation (default: 120)
#
# Every test is compiled with the driver run in the test's own directory with the bare file
# name (`sea build NAME.sea`), so diagnostics read `NAME.sea:LINE:COL: error: ...` and
# `NAME.sea:LINE: error: ...`. Programs run in a fresh empty working directory.
#
# tests/programs/NAME.sea  a program that must compile and run
#   NAME.out    REQUIRED  exact expected standard output (not compared with stdout=epipe or
#                         stdout=closed)
#   NAME.err    optional  exact expected standard error (absent = must be empty)
#   NAME.status optional  expected exit status of the program (absent = 0)
#   NAME.in     optional  the program's standard input (absent = /dev/null)
#   NAME.args   optional  the program's arguments, one per line
#   NAME.files/ optional  fixtures copied into the working directory first
#   NAME.expect/ optional files that must exist afterwards, byte-identical
#   NAME.meta   optional  key=value lines: stdout=epipe connects standard output to a pipe
#                         whose reading end is closed before the program starts;
#                         stdout=closed starts the program with standard output closed (>&-)
#   Afterwards the working directory may hold only the expected files and unchanged fixtures.
#
# tests/errors/NAME.sea    a program with a compile-time or run-time error
#   NAME.err    REQUIRED  exact expected standard error; NAME.status REQUIRED  expected status
#   If `sea build` fails, this is a compile-time test: the driver's standard error and exit
#   status are compared, standard output must be empty and no output file may exist. If it
#   succeeds, it is a run-time test: the program's stderr, status and (NAME.out, default
#   empty) stdout are compared; .in, .args, .files/, .expect/ and .meta apply as above.
#
# tests/passes/NAME.sea    dump tests (DESIGN.md 3.8): for each NAME.X (X = ast hir1 hir lir1
#   lir) present, `sea build --emit X --no-prelude NAME.sea` must exit 0 with empty stderr and
#   write exactly NAME.X to stdout. If NAME.out exists, the program built with --no-prelude and
#   run (no stdin, no arguments) must print exactly NAME.out, with empty stderr and status 0.
#
# Exit status: 0 if every selected test passed, 1 otherwise, 2 on setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"

if [ ! -x "$SEA" ]; then
    echo "run.sh: driver '$SEA' not found or not executable; run 'make' first" >&2
    exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-tests.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
: > "$TMP/empty"

PASS=0
FAIL=0
FAILED=""

selected() {
    [ -z "$PATTERNS" ] && return 0
    set -f  # patterns are literal, never globs
    for p in $PATTERNS; do
        case "$1" in *"$p"*) set +f; return 0 ;; esac
    done
    set +f
    return 1
}

# run_limited SECONDS INFILE WORKDIR CMD... : run CMD in WORKDIR with stdin from INFILE, kill
# it after SECONDS; returns CMD's exit status (137 if killed). The caller redirects output.
run_limited() {
    _t=$1; _in=$2; _wd=$3; shift 3
    (cd "$_wd" && exec "$@" <"$_in") &
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

stdin_for() { # stdin_for BASE : BASE.in if it exists, else /dev/null
    if [ -f "$1.in" ]; then echo "$1.in"; else echo /dev/null; fi
}

pass() { PASS=$((PASS + 1)); }

fail() { # fail NAME REASON
    FAIL=$((FAIL + 1))
    FAILED="$FAILED $1"
    echo "FAIL $1: $2"
}

same() { # same EXPECTED ACTUAL LABEL NAME : exact comparison; records a failure on mismatch
    if cmp -s "$1" "$2"; then return 0; fi
    fail "$4" "$3 differs"
    if [ "$VERBOSE" = 1 ]; then diff -u "$1" "$2" | sed 's/^/    /' | head -60; fi
    return 1
}

meta_get() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; } # meta_get FILE KEY

# check_meta BASE : only the known keys; any other line is a corpus mistake (exit 2).
check_meta() {
    [ -f "$1.meta" ] || return 0
    while IFS= read -r _l || [ -n "$_l" ]; do
        case $_l in
        "" | stdout=epipe | stdout=closed) ;;
        *) echo "run.sh: $(basename "$1").meta: unknown line '$_l'" >&2; exit 2 ;;
        esac
    done < "$1.meta"
}

newwork() { # newwork BASE : fresh working directory $WORK, fixtures copied in
    WORK=$(mktemp -d "$TMP/work.XXXXXX") || return 1
    if [ -d "$1.files" ]; then cp -R "$1.files/." "$WORK/" || return 1; fi
    return 0
}

relfiles() { (cd "$1" && find . -type f | sed 's|^\./||' | sort); }

# check_files NAME BASE : the files left in $WORK are the expected ones plus unchanged fixtures.
check_files() {
    _n=$1; _b=$2
    if [ -d "$_b.expect" ]; then
        for _r in $(relfiles "$_b.expect"); do
            if [ ! -f "$WORK/$_r" ]; then fail "$_n" "missing file $_r"; return 1; fi
            same "$_b.expect/$_r" "$WORK/$_r" "file $_r" "$_n" || return 1
        done
    fi
    for _r in $(relfiles "$WORK"); do
        if [ -f "$_b.expect/$_r" ]; then continue; fi
        if [ -f "$_b.files/$_r" ]; then
            if cmp -s "$_b.files/$_r" "$WORK/$_r"; then continue; fi
            fail "$_n" "fixture $_r changed"; return 1
        fi
        fail "$_n" "unexpected file $_r"; return 1
    done
    return 0
}

# sea_build DIR ARGS... : run the driver in DIR; stdout to $TMP/c.out, stderr to $TMP/c.err.
sea_build() {
    _d=$1; shift
    run_limited "$CTIMEOUT" /dev/null "$_d" "$SEA" build "$@" >"$TMP/c.out" 2>"$TMP/c.err"
}

# run_prog BASE EXE : run a compiled program in $WORK with BASE.in, BASE.args and BASE.meta;
# sets st and leaves $TMP/r.out, $TMP/r.err.
run_prog() {
    _b=$1; _exe=$2
    set --
    if [ -f "$_b.args" ]; then
        while IFS= read -r _a || [ -n "$_a" ]; do set -- "$@" "$_a"; done < "$_b.args"
    fi
    if [ "$(meta_get "$_b.meta" stdout)" = epipe ]; then
        # Deterministic: a FIFO whose reader has opened it and exited again, with the write end
        # held open here, so the program (exec'd with that end as its stdout) finds a pipe
        # that no process reads. runit.sh does this inside the time-limited process.
        cat >"$TMP/runit.sh" <<'RUNIT'
#!/bin/sh
# runit.sh FIFO EXE ARGS... : exec EXE with stdout a pipe whose reading end is closed
fifo=$1; shift
rm -f "$fifo"; mkfifo "$fifo" || exit 125
( : <"$fifo" ) &
rp=$!
exec 4>"$fifo"          # returns once the reader has opened its end
wait $rp                # the reader has exited: no reader is left
rm -f "$fifo"
exec "$@" >&4 2>"$ERRFILE"
RUNIT
        : >"$TMP/r.out"
        ERRFILE=$TMP/r.err; export ERRFILE
        run_limited "$TIMEOUT" "$(stdin_for "$_b")" "$WORK" sh "$TMP/runit.sh" "$TMP/epipe.fifo" "$_exe" "$@"
        st=$?
    elif [ "$(meta_get "$_b.meta" stdout)" = closed ]; then
        # descriptor 1 closed in the program itself: its writes fail with EBADF
        : >"$TMP/r.out"
        ERRFILE=$TMP/r.err; export ERRFILE
        run_limited "$TIMEOUT" "$(stdin_for "$_b")" "$WORK" sh -c 'exec "$@" >&- 2>"$ERRFILE"' sh "$_exe" "$@"
        st=$?
    else
        run_limited "$TIMEOUT" "$(stdin_for "$_b")" "$WORK" "$_exe" "$@" >"$TMP/r.out" 2>"$TMP/r.err"
        st=$?
    fi
}

want_status() { # want_status BASE : expected exit status (BASE.status or 0)
    if [ -f "$1.status" ]; then sed -n 1p "$1.status"; else echo 0; fi
}

# ---- tests/programs ---------------------------------------------------------
for src in "$ROOT"/tests/programs/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    name=programs/$nm
    selected "$name" || continue
    base=${src%.sea}
    check_meta "$base"
    if [ ! -f "$base.out" ]; then fail "$name" "missing $nm.out"; continue; fi
    exe=$TMP/prog; rm -f "$exe"
    sea_build "$ROOT/tests/programs" "$nm.sea" -o "$exe"
    bst=$?
    if [ $bst -ne 0 ]; then
        fail "$name" "compile failed (status $bst): $(head -3 "$TMP/c.err" | tr '\n' ' ')"
        continue
    fi
    if ! newwork "$base"; then fail "$name" "cannot prepare the work directory"; rm -rf "$WORK"; continue; fi
    run_prog "$base" "$exe"
    experr=$TMP/empty; [ -f "$base.err" ] && experr=$base.err
    want=$(want_status "$base")
    ok=1
    [ "$st" = "$want" ] || { fail "$name" "exit status $st, expected $want"; ok=0; }
    if [ $ok = 1 ] && [ "$(meta_get "$base.meta" stdout)" != epipe ] && [ "$(meta_get "$base.meta" stdout)" != closed ]; then
        same "$base.out" "$TMP/r.out" "stdout" "$name" || ok=0
    fi
    [ $ok = 1 ] && { same "$experr" "$TMP/r.err" "stderr" "$name" || ok=0; }
    [ $ok = 1 ] && { check_files "$name" "$base" || ok=0; }
    rm -rf "$WORK"
    [ $ok = 1 ] && pass
done

# ---- tests/errors -----------------------------------------------------------
for src in "$ROOT"/tests/errors/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    name=errors/$nm
    selected "$name" || continue
    base=${src%.sea}
    check_meta "$base"
    if [ ! -f "$base.err" ] || [ ! -f "$base.status" ]; then
        fail "$name" "missing $nm.err or $nm.status"; continue
    fi
    want=$(want_status "$base")
    exe=$TMP/prog; rm -f "$exe"
    sea_build "$ROOT/tests/errors" "$nm.sea" -o "$exe"
    bst=$?
    if [ $bst -ne 0 ]; then
        # compile-time test
        if [ -d "$base.files" ] || [ -d "$base.expect" ]; then
            echo "run.sh: errors/$nm: .files/.expect only for tests that compile" >&2; exit 2
        fi
        ok=1
        [ "$bst" = "$want" ] || { fail "$name" "driver exit status $bst, expected $want"; ok=0; }
        [ $ok = 1 ] && [ -e "$exe" ] && { fail "$name" "an output file was created despite the error"; ok=0; }
        [ $ok = 1 ] && { same "$base.err" "$TMP/c.err" "compiler stderr" "$name" || ok=0; }
        [ $ok = 1 ] && { same "$TMP/empty" "$TMP/c.out" "compiler stdout" "$name" || ok=0; }
        [ $ok = 1 ] && pass
        continue
    fi
    if [ -s "$TMP/c.err" ]; then fail "$name" "compiler wrote to stderr: $(head -3 "$TMP/c.err" | tr '\n' ' ')"; continue; fi
    if ! newwork "$base"; then fail "$name" "cannot prepare the work directory"; rm -rf "$WORK"; continue; fi
    run_prog "$base" "$exe"
    expout=$TMP/empty; [ -f "$base.out" ] && expout=$base.out
    ok=1
    [ "$st" = "$want" ] || { fail "$name" "program exit status $st, expected $want"; ok=0; }
    [ $ok = 1 ] && { same "$base.err" "$TMP/r.err" "stderr" "$name" || ok=0; }
    if [ $ok = 1 ] && [ "$(meta_get "$base.meta" stdout)" != epipe ] && [ "$(meta_get "$base.meta" stdout)" != closed ]; then
        same "$expout" "$TMP/r.out" "stdout" "$name" || ok=0
    fi
    [ $ok = 1 ] && { check_files "$name" "$base" || ok=0; }
    rm -rf "$WORK"
    [ $ok = 1 ] && pass
done

# ---- tests/passes (dump tests, DESIGN.md 3.8) --------------------------------
for src in "$ROOT"/tests/passes/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    base=${src%.sea}
    for x in ast hir1 hir lir1 lir; do
        [ -f "$base.$x" ] || continue
        name=passes/$nm.$x
        selected "$name" || continue
        sea_build "$ROOT/tests/passes" --emit "$x" --no-prelude "$nm.sea"
        bst=$?
        ok=1
        [ $bst -eq 0 ] || { fail "$name" "--emit $x exit status $bst: $(head -3 "$TMP/c.err" | tr '\n' ' ')"; ok=0; }
        [ $ok = 1 ] && { same "$base.$x" "$TMP/c.out" "dump" "$name" || ok=0; }
        [ $ok = 1 ] && { same "$TMP/empty" "$TMP/c.err" "stderr" "$name" || ok=0; }
        [ $ok = 1 ] && pass
    done
    if [ -f "$base.out" ]; then
        name=passes/$nm.out
        selected "$name" || continue
        exe=$TMP/prog; rm -f "$exe"
        sea_build "$ROOT/tests/passes" --no-prelude "$nm.sea" -o "$exe"
        if [ $? -ne 0 ]; then fail "$name" "compile failed: $(head -3 "$TMP/c.err" | tr '\n' ' ')"; continue; fi
        WORK=$(mktemp -d "$TMP/work.XXXXXX")
        run_limited "$TIMEOUT" /dev/null "$WORK" "$exe" >"$TMP/r.out" 2>"$TMP/r.err"
        st=$?
        rm -rf "$WORK"
        ok=1
        [ $st -eq 0 ] || { fail "$name" "exit status $st, expected 0"; ok=0; }
        [ $ok = 1 ] && { same "$base.out" "$TMP/r.out" "stdout" "$name" || ok=0; }
        [ $ok = 1 ] && { same "$TMP/empty" "$TMP/r.err" "stderr" "$name" || ok=0; }
        [ $ok = 1 ] && pass
    fi
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
