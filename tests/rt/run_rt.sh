#!/bin/sh
# sea/tests/rt/run_rt.sh -- runtime tests of the arm64-macos runtime (POSIX sh).
# DESIGN.md 6.2 "rt/arm64_macos/NAME.s". Builds nothing in the tree: everything
# goes to a temporary directory.
#
# usage: sh sea/tests/rt/run_rt.sh [-v] [PATTERN...]
#   -v        show the differences of failures
#   PATTERN   only run tests whose name contains one of the patterns
#
# Environment:
#   BAYSICK         the Baysick checkout (default: the parent of sea/); its
#                   build/libbaysickrt.a supplies the kernels (`make` there first)
#   SEA_RT_TIMEOUT  seconds per program run (default 20)
#
# A test is tests/rt/arm64_macos/NAME.s: an assembly program that defines
# `_sea_main` and `_sea_sites` (and may call the runtime through rt.inc and
# the internal symbols of rt_out.s). It is assembled and linked with the
# rt_main.o (explicit, first), then a libsea.a built here from every
# runtime/arm64_macos/rt_*.s with the Makefile's flags (members are pulled only
# for an undefined symbol), plus Baysick's libbaysickrt.a.
# Sidecars (beside NAME.s):
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
#                                     SEA_KERNELS and BAYSICK_KERNELS are
#                                     otherwise unset
#                  requires=fmt_g     needs a real _sea_fmt_g from rt_fmt.s
# Every program runs in a fresh empty working directory with stdin from
# /dev/null. A skipped test is reported on its own line and counted: no test is
# skipped silently. Exit status 0 if nothing failed (skips are listed and counted),
# 1 if a test failed, 2 on a setup problem.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BAYSICK=${BAYSICK:-$(cd "$ROOT/.." && pwd)}
BSKRT=$BAYSICK/build/libbaysickrt.a
TIMEOUT=${SEA_RT_TIMEOUT:-20}
RTDIR=$ROOT/runtime/arm64_macos
TESTDIR=$ROOT/tests/rt/arm64_macos
CORE="rt_main rt_out rt_err rt_clock"

VERBOSE=0
if [ "$1" = "-v" ]; then VERBOSE=1; shift; fi

if [ ! -f "$BSKRT" ]; then
    echo "run_rt.sh: $BSKRT not found (run make in $BAYSICK)" >&2
    exit 2
fi
SDK=$(env -u SDKROOT -u DEVELOPER_DIR xcrun --show-sdk-path) || { echo "run_rt.sh: xcrun --show-sdk-path failed" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-rt.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$TMP/obj" "$TMP/work"
: >"$TMP/empty"

AS="env -u SDKROOT -u DEVELOPER_DIR as -arch arm64 -mmacosx-version-min=11.0 -I $ROOT/include -I $BAYSICK/include"
LD="env -u SDKROOT -u DEVELOPER_DIR ld -arch arm64 -platform_version macos 11.0 11.0 -e _main -lSystem -syslibroot $SDK"

PASS=0; FAIL=0; SKIP=0; SKIPPED=""; FAILED=""

fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }
skip() { SKIP=$((SKIP + 1)); SKIPPED="$SKIPPED $1"; echo "SKIP $1: $2"; }

# ---- the runtime objects -----------------------------------------------------
# Every runtime file is assembled with the Makefile's flags (RT_ASFLAGS) and archived as
# libsea.a, the same way `make runtime` does. The core files must assemble; any other
# file that does not is reported and left out. rt_main.o is linked explicitly first
# (it defines `main`; the linker pulls the other members from libsea.a on demand).
for m in $CORE; do
    if [ ! -f "$RTDIR/$m.s" ]; then echo "run_rt.sh: $RTDIR/$m.s missing" >&2; exit 2; fi
done
LIBOBJS=""
HAVE_FMT=0
for s in "$RTDIR"/rt_*.s; do
    m=$(basename "$s" .s)
    if $AS -o "$TMP/obj/$m.o" "$s" 2>"$TMP/as.err"; then
        LIBOBJS="$LIBOBJS $TMP/obj/$m.o"
        if [ "$m" = rt_fmt ]; then HAVE_FMT=1; fi
    else
        case " $CORE " in
        *" $m "*) echo "run_rt.sh: $m.s does not assemble:" >&2; cat "$TMP/as.err" >&2; exit 2 ;;
        esac
        echo "NOTE: $m.s does not assemble and is left out of libsea.a:"
        sed 's/^/      /' "$TMP/as.err" | head -5
    fi
done
ar rcs "$TMP/libsea.a" $LIBOBJS || exit 2
COREOBJS=$TMP/obj/rt_main.o
EXTRALIB=$TMP/libsea.a
# rt_err.o references _sea_fmt_g (rt_fmt.s). Without a real one a link-time
# double is added so the other tests can link; it traps if ever called, and the
# tests that need the real routine (requires=fmt_g) are skipped, loudly.
REALFMTG=0
if [ $HAVE_FMT = 1 ] && nm "$TMP/obj/rt_fmt.o" 2>/dev/null | grep -q ' [Tt] _sea_fmt_g$'; then REALFMTG=1; fi
FMTDOUBLE=""
if [ $REALFMTG = 0 ]; then
    cat >"$TMP/fmtg_double.s" <<'EOF'
    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_fmt_g
    .p2align 2
_sea_fmt_g:
    brk #1
EOF
    $AS -o "$TMP/obj/fmtg_double.o" "$TMP/fmtg_double.s" || exit 2
    FMTDOUBLE=$TMP/obj/fmtg_double.o
    echo "NOTE: no _sea_fmt_g in the runtime (rt_fmt.s absent or incomplete): tests with requires=fmt_g are skipped"
fi

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

# run_limited SECONDS WORKDIR CMD... : status of CMD, killed after SECONDS
run_limited() {
    _t=$1; _wd=$2; shift 2
    (cd "$_wd" && exec "$@") &
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

    # tests of rt_fmt.s need it; tests that say requires=fmt_g need the real _sea_fmt_g
    case "$name" in rt_fmt_*) [ $HAVE_FMT = 1 ] || { skip "$name" "rt_fmt.s absent or not assembling"; continue; } ;; esac
    if [ "$(meta_get "$meta" requires)" = fmt_g ] && [ $REALFMTG = 0 ]; then
        skip "$name" "needs _sea_fmt_g from rt_fmt.s"; continue
    fi

    if ! $AS -o "$TMP/t.o" "$src" 2>"$TMP/as.err"; then
        fail "$name" "does not assemble: $(head -3 "$TMP/as.err" | tr '\n' ' ')"; continue
    fi
    if ! $LD $COREOBJS "$TMP/t.o" $FMTDOUBLE $EXTRALIB "$BSKRT" -o "$TMP/exe" 2>"$TMP/ld.err"; then
        fail "$name" "does not link: $(head -3 "$TMP/ld.err" | tr '\n' ' ')"; continue
    fi

    mode=plain
    case "$(meta_get "$meta" stdout)" in "") ;; epipe) mode=epipe ;; slowpipe) mode=slowpipe ;;
        *) echo "run_rt.sh: $name: bad stdout= in $name.meta" >&2; exit 2 ;; esac
    envargs="-u SEA_KERNELS -u BAYSICK_KERNELS"
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
echo "passed: $PASS  failed: $FAIL  skipped: $SKIP"
[ $SKIP -ne 0 ] && echo "skipped tests:$SKIPPED"
if [ $FAIL -ne 0 ]; then echo "failed tests:$FAILED"; exit 1; fi
if [ $NTESTS -eq 0 ]; then echo "run_rt.sh: no test selected" >&2; exit 2; fi
exit 0
