#!/bin/sh
# sea/tests/rt/run_rt_linux.sh -- runtime tests of the x86_64-linux runtime (POSIX sh,
# on x86_64 Linux). DESIGN.md 4.7.1 "rt/x86_64_linux/NAME.s", 6.6.1. The Linux twin of
# tests/rt/run_rt.sh: same sidecars, same plumbing, same report.
#
# usage: sh tests/rt/run_rt_linux.sh [-v] [PATTERN...]
#        (normally through `make -f Makefile.linux test-rt`, which builds the runtime first)
#   -v        show the differences of failures
#   PATTERN   only run tests whose name contains one of the patterns
#
# Environment:
#   BAYSICK         the Baysick checkout or the bundle's copy of it (default: the parent
#                   of sea/); its build-x86_64-linux/libbaysickrt.a supplies the kernels
#                   (`make -f Makefile.linux` there first) and its include/ Baysick's
#                   runtime.inc
#   AS              the assembler (default: as)
#   SEA_RT_TIMEOUT  seconds per program run (default 20)
#
# A test is tests/rt/x86_64_linux/NAME.s: an assembly program that defines `sea_main`
# and `sea_sites` (and may call the runtime through rt.inc and the internal symbols of
# rt_out.s). It is assembled with the runtime flags (as --64 --fatal-warnings -I include
# -I $BAYSICK/include) and linked as
#   gcc -no-pie -o prog NAME.o build-x86_64-linux/obj/rt_main.o build-x86_64-linux/libsea.a \
#       $BAYSICK/build-x86_64-linux/libbaysickrt.a -lm
# (rt_main.o explicit and first; the other members are pulled from libsea.a on demand),
# against the runtime that `make -f Makefile.linux all` built. Sidecars (beside NAME.s):
#   NAME.out     expected stdout bytes (absent: empty)
#   NAME.err     expected stderr bytes (absent: empty)
#   NAME.status  expected exit status, one number (absent: 0)
#   NAME.meta    key=value lines:
#                  stdout=epipe       standard output is a pipe whose reading
#                                     end is closed before the program starts
#                  stdout=slowpipe    standard output is a pipe (FIFO) whose reader sleeps 1 s
#                                     before it starts reading (a full pipe: EAGAIN on a
#                                     non-blocking stdout)
#                  env=NAME=VALUE     an environment variable (repeatable);
#                                     SEA_KERNELS, BAYSICK_KERNELS and SEA_HEAP_CHECK are
#                                     otherwise unset
#                Empty lines are ignored; any other line is a setup error (exit 2),
#                as in cross_run.sh (DESIGN.md 4.7.1, 6.6.1).
# Every program runs in a fresh empty working directory with stdin from /dev/null,
# in its own process group: a run that exceeds SEA_RT_TIMEOUT is killed as a whole
# group (the program, the runner shell and a slowpipe reader), status 137.
# A program killed by a signal has the status the shell reports, 128 + the signal
# number (139 for SIGSEGV).
# Exit status 0 if nothing failed, 1 if a test failed, 2 on a setup problem.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BAYSICK=${BAYSICK:-$(cd "$ROOT/.." && pwd)}
case "$BAYSICK" in /*) ;; *) BAYSICK=$(cd "$ROOT/$BAYSICK" 2>/dev/null && pwd) || { echo "run_rt_linux.sh: BAYSICK directory not found" >&2; exit 2; } ;; esac
BSKRT=$BAYSICK/build-x86_64-linux/libbaysickrt.a
TIMEOUT=${SEA_RT_TIMEOUT:-20}
BUILD=$ROOT/build-x86_64-linux
TESTDIR=$ROOT/tests/rt/x86_64_linux
ASM=${AS:-as}

VERBOSE=0
if [ "$1" = "-v" ]; then VERBOSE=1; shift; fi

if [ "$(uname -sm)" != "Linux x86_64" ]; then
    echo "run_rt_linux.sh: run on x86_64 Linux (uname -sm is '$(uname -sm)')" >&2
    exit 2
fi
for f in "$BUILD/libsea.a" "$BUILD/obj/rt_main.o"; do
    if [ ! -f "$f" ]; then echo "run_rt_linux.sh: $f not found (run make -f Makefile.linux all)" >&2; exit 2; fi
done
if [ ! -f "$BSKRT" ]; then
    echo "run_rt_linux.sh: $BSKRT not found (run make -f Makefile.linux in $BAYSICK)" >&2
    exit 2
fi
if [ ! -f "$BAYSICK/include/runtime.inc" ]; then
    echo "run_rt_linux.sh: $BAYSICK/include/runtime.inc not found" >&2
    exit 2
fi
command -v gcc >/dev/null 2>&1 || { echo "run_rt_linux.sh: gcc not found (links the test programs)" >&2; exit 2; }
# rt_err.o references sea_fmt_g (rt_fmt.s): the archive must define it.
if ! nm "$BUILD/libsea.a" 2>/dev/null | grep -q ' T sea_fmt_g$'; then
    echo "run_rt_linux.sh: $BUILD/libsea.a defines no sea_fmt_g" >&2
    exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-rt.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$TMP/work"
: >"$TMP/empty"

ASCMD="$ASM --64 --fatal-warnings -I $ROOT/include -I $BAYSICK/include"

PASS=0; FAIL=0; FAILED=""

fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }

# ---- the per-run script (runs the program with the right plumbing) -----------
cat >"$TMP/runit.sh" <<'EOF'
#!/bin/sh
# runit.sh EXE MODE OUT ERR : run EXE with stdin /dev/null; MODE epipe: stdout is a
# pipe (a FIFO) whose reading end has been closed before EXE starts.
exe=$1; mode=$2; out=$3; err=$4
if [ "$mode" = epipe ]; then
    fifo=$out.fifo
    mkfifo "$fifo" || exit 125
    ( : <"$fifo" ) &
    rp=$!
    exec 4>"$fifo"          # returns once the reader has opened its end
    wait $rp                # the reader has exited: no reader is left
    : >"$out"
    exec "$exe" </dev/null >&4 2>"$err"
fi
if [ "$mode" = slowpipe ]; then
    fifo=$out.fifo
    mkfifo "$fifo" || exit 125
    { sleep 1; cat; } <"$fifo" >"$out" &     # a reader that starts reading after 1 s
    "$exe" </dev/null >"$fifo" 2>"$err"
    st=$?
    wait                    # the reader has copied everything
    exit $st
fi
exec "$exe" </dev/null >"$out" 2>"$err"
EOF

# run_limited SECONDS WORKDIR CMD... : status of CMD, killed after SECONDS (137). CMD runs
# as a job of its own (set -m): its process group id is its pid, so the watchdog kills
# the whole group (the runner shell, the program and a slowpipe reader), never one PID
# of it alone, and never anything outside it.
run_limited() {
    _t=$1; _wd=$2; shift 2
    set -m
    (cd "$_wd" && exec "$@") &
    _cpid=$!
    set +m
    (
        _i=0
        while [ "$_i" -lt $((_t * 10)) ]; do
            sleep 0.1
            kill -0 "$_cpid" 2>/dev/null || exit 0
            _i=$((_i + 1))
        done
        kill -9 -- "-$_cpid" 2>/dev/null
    ) &
    _wpid=$!
    wait "$_cpid"
    _st=$?
    kill "$_wpid" 2>/dev/null
    wait "$_wpid" 2>/dev/null
    return $_st
}

# check_meta META NAME : every line of META must be stdout=epipe, stdout=slowpipe,
# env=NAME=VALUE or empty; anything else is a setup error (exit 2).
check_meta() {
    [ -f "$1" ] || return 0
    while IFS= read -r _l || [ -n "$_l" ]; do
        case $_l in
        "" | stdout=epipe | stdout=slowpipe | env=?*=*) ;;
        *) echo "run_rt_linux.sh: $2.meta: unknown line '$_l'" >&2; exit 2 ;;
        esac
    done <"$1"
}

meta_get() { [ -f "$1" ] && sed -n "s/^$2=//p" "$1" | head -1; }
meta_all() { [ -f "$1" ] && sed -n "s/^$2=//p" "$1"; }

selected() {
    [ $# -eq 1 ] && return 0
    _n=$1; shift
    for _p in "$@"; do case "$_n" in *"$_p"*) return 0 ;; esac; done
    return 1
}

same() { # EXPECTED ACTUAL WHAT NAME
    if cmp -s "$1" "$2"; then return 0; fi
    fail "$4" "$3 differs"
    if [ $VERBOSE = 1 ]; then
        echo "--- expected"; od -c "$1" | head -20; echo "--- actual"; od -c "$2" | head -20
    fi
    return 1
}

# ---- the tests ------------------------------------------------------------------
NTESTS=0
for src in "$TESTDIR"/*.s; do
    [ -e "$src" ] || continue
    name=$(basename "$src" .s)
    selected "$name" "$@" || continue
    NTESTS=$((NTESTS + 1))
    base=${src%.s}
    meta=$base.meta

    check_meta "$meta" "$name"

    if ! $ASCMD -o "$TMP/t.o" "$src" 2>"$TMP/as.err"; then
        fail "$name" "does not assemble: $(head -3 "$TMP/as.err" | tr '\n' ' ')"; continue
    fi
    if ! gcc -no-pie -o "$TMP/exe" "$TMP/t.o" "$BUILD/obj/rt_main.o" "$BUILD/libsea.a" "$BSKRT" -lm 2>"$TMP/ld.err"; then
        fail "$name" "does not link: $(head -3 "$TMP/ld.err" | tr '\n' ' ')"; continue
    fi

    mode=plain
    case "$(meta_get "$meta" stdout)" in "") ;; epipe) mode=epipe ;; slowpipe) mode=slowpipe ;;
        *) echo "run_rt_linux.sh: $name: bad stdout= in $name.meta" >&2; exit 2 ;; esac
    envargs="-u SEA_KERNELS -u BAYSICK_KERNELS -u SEA_HEAP_CHECK"
    for kv in $(meta_all "$meta" env); do envargs="$envargs $kv"; done

    rm -rf "$TMP/work"; mkdir "$TMP/work"
    rm -f "$TMP/r.out" "$TMP/r.err" "$TMP/r.out.fifo"
    # shellcheck disable=SC2086
    run_limited "$TIMEOUT" "$TMP/work" env $envargs sh "$TMP/runit.sh" "$TMP/exe" "$mode" "$TMP/r.out" "$TMP/r.err" 2>/dev/null
    st=$?

    want=0
    [ -f "$base.status" ] && want=$(tr -d ' \n' <"$base.status")
    expout=$TMP/empty; [ -f "$base.out" ] && expout=$base.out
    experr=$TMP/empty; [ -f "$base.err" ] && experr=$base.err
    ok=1
    [ "$st" = "$want" ] || { fail "$name" "exit status $st, expected $want"; ok=0; }
    [ $ok = 1 ] && { same "$experr" "$TMP/r.err" "stderr" "$name" || ok=0; }
    [ $ok = 1 ] && { same "$expout" "$TMP/r.out" "stdout" "$name" || ok=0; }
    [ $ok = 1 ] && PASS=$((PASS + 1))
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then echo "failed tests:$FAILED"; exit 1; fi
if [ $NTESTS -eq 0 ]; then echo "run_rt_linux.sh: no test selected" >&2; exit 2; fi
exit 0
