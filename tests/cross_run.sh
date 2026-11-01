#!/bin/sh
# tests/cross_run.sh -- run an x86_64-linux test bundle (Linux, POSIX sh; docs/DESIGN.md 6.6.1).
#
# usage: sh tests/cross_run.sh [-v] [BUNDLE_DIR]
#   -v          show diffs for failures
#   BUNDLE_DIR  bundle made by tests/cross_pack.sh (default: the directory above this script's)
#
# Environment:
#   SEA_TEST_TIMEOUT  seconds per program run (default 10)
#   AS                GNU assembler (default as)
#   CC                C compiler driver, used to link (default gcc)
#   SEA_KERNELS       when set, the one kernel variant every program runs under (letters, digits,
#                     underscores); when unset, both x86_64 variants (DESIGN.md 6.6.1, Decision 104)
#
# Builds Baysick's x86_64 runtime and Sea's from the bundle, then for every case assembles and
# links the compiler's .s and compares the run exactly like tests/run.sh (same sidecars, .meta
# keys, output format and exit status: 0 all passed, 1 any failed, 2 setup error).
#
# Variants (Decision 104): every program, error, passes, accept and ports case is built once and
# run twice, first with SEA_KERNELS unset (the best usable variant, avx2 on a host that passes the
# setup check) and then with SEA_KERNELS=sse2, against the same expected files; a failure of the
# second run is named `FAIL <name> [sse2]: ...`. The setup requires AVX2 (`grep -qw avx2
# /proc/cpuinfo`) whatever is asked for, else exit 2: the 4-lane code (the y-class tests run AVX2
# instructions unconditionally) cannot be tested, and a run never passes with only the sse2 arm
# executed. An rt/ case keeps its own env= lines and runs once, as does math/math_check. The
# summary names the counts of each variant: `variant <v>: passed P  failed F`, then
# `once (build, rt, math): passed P  failed F`, then the totals.
#
# fusion/NAME (phase 7, DESIGN.md 2.12.10, the temporaries check; tests/fusion.sh's check on the
# host): NAME.s with the sidecar NAME.fusion (`k=K`, `per_iteration=N`). The build is run, under
# each variant like a program case, twice in a fresh empty working directory, with the argument K
# and with K + 1 (stdin /dev/null, SEA_HEAP_CHECK=count); each run must exit 0 with a standard
# error of exactly one line `heap: A allocations, L live objects`, L = 0, and leave no file. The
# variant passes when A(K + 1) - A(K) = N, the allocations per iteration derived by hand. Each passing
# variant prints `ok   fusion/NAME [variant]: A(K) allocations at K=K, A(K+1) at K=K+1`.

AS=${AS:-as}
CC=${CC:-gcc}
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
if [ $# -gt 1 ]; then
    echo "cross_run.sh: usage: sh tests/cross_run.sh [-v] [BUNDLE_DIR]" >&2
    exit 2
fi
BUNDLE=${1:-$(dirname "$0")/..}
BUNDLE=$(cd "$BUNDLE" 2>/dev/null && pwd) || {
    echo "cross_run.sh: cannot enter bundle directory '${1:-}'" >&2
    exit 2
}
if [ "$(cat "$BUNDLE/BUNDLE" 2>/dev/null)" != "sea-x86_64-linux-bundle 1" ]; then
    echo "cross_run.sh: '$BUNDLE' is not a Sea x86_64-linux bundle (BUNDLE marker missing or wrong)" >&2
    exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-crossrun.XXXXXX") || {
    echo "cross_run.sh: cannot create temporary directory" >&2
    exit 2
}
trap 'rm -rf "$TMP"' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE
: > "$TMP/empty"

command -v "$AS" >/dev/null 2>&1 || { echo "cross_run.sh: assembler '$AS' not found" >&2; exit 2; }
command -v "$CC" >/dev/null 2>&1 || { echo "cross_run.sh: C compiler '$CC' not found (needed to link)" >&2; exit 2; }
command -v make >/dev/null 2>&1 || { echo "cross_run.sh: make not found" >&2; exit 2; }
# the AVX2 setup check (Decision 104): without it the 4-lane copies cannot run
if ! grep -qw avx2 /proc/cpuinfo 2>/dev/null; then
    echo "cross_run.sh: host lacks avx2: the 4-lane code cannot be tested" >&2
    exit 2
fi
# the variants every program case runs under: the user's SEA_KERNELS alone, else default and sse2
case "${SEA_KERNELS:-}" in
'') VARIANTS="default sse2" ;;
*[!A-Za-z0-9_]*) echo "cross_run.sh: SEA_KERNELS must contain only letters, digits and underscores" >&2; exit 2 ;;
*) VARIANTS=$SEA_KERNELS ;;
esac
unset SEA_KERNELS
SETSID=; if command -v setsid >/dev/null 2>&1; then SETSID=1; fi

# ---- setup: build both runtimes from the bundle ---------------------------------
if ! make -C "$BUNDLE/baysick" -f Makefile.linux all AS="$AS" >"$TMP/make.log" 2>&1; then
    echo "cross_run.sh: building Baysick's x86_64 runtime failed:" >&2
    sed 's/^/    /' "$TMP/make.log" >&2
    exit 2
fi
if ! make -C "$BUNDLE" -f Makefile.linux check-includes all BAYSICK=baysick AS="$AS" >"$TMP/make.log" 2>&1; then
    echo "cross_run.sh: building Sea's x86_64 runtime failed:" >&2
    sed 's/^/    /' "$TMP/make.log" >&2
    exit 2
fi
BSKRT=$BUNDLE/baysick/build-x86_64-linux/libbaysickrt.a
LIBSEA=$BUNDLE/build-x86_64-linux/libsea.a
RTMAIN=$BUNDLE/build-x86_64-linux/obj/rt_main.o
for f in "$BSKRT" "$LIBSEA" "$RTMAIN"; do
    [ -f "$f" ] || { echo "cross_run.sh: runtime build produced no $f" >&2; exit 2; }
done

PASS=0
FAIL=0
FAILED=""
# per variant counters (VI is the index of the variant being run, empty outside the program cases):
# P1/F1 the first variant, P2/F2 the second (when there is one); VSUF is the label of a failure.
VI=
VSUF=
P1=0; F1=0; P2=0; F2=0

# run_limited SECONDS INFILE WORKDIR CMD... : status of CMD run in WORKDIR (137 if killed).
# With setsid the command runs in its own process group, and the whole group is killed on
# timeout and reaped afterwards (a slowpipe reader or other helper never outlives its case).
run_limited() {
    _t=$1; _in=$2; _wd=$3; shift 3
    if [ -n "$SETSID" ]; then
        (cd "$_wd" && exec setsid "$@" <"$_in") &
    else
        (cd "$_wd" && exec "$@" <"$_in") &
    fi
    _cpid=$!
    (
        _i=0
        while [ "$_i" -lt $((_t * 10)) ]; do
            sleep 0.1
            kill -0 "$_cpid" 2>/dev/null || exit 0
            _i=$((_i + 1))
        done
        kill -9 -- "-$_cpid" 2>/dev/null || kill -9 "$_cpid" 2>/dev/null
    ) &
    _wpid=$!
    wait "$_cpid"
    _st=$?
    kill "$_wpid" 2>/dev/null
    wait "$_wpid" 2>/dev/null
    [ -n "$SETSID" ] && kill -9 -- "-$_cpid" 2>/dev/null
    return $_st
}

stdin_for() { if [ -f "$1.in" ]; then echo "$1.in"; else echo /dev/null; fi; }
pass() {
    PASS=$((PASS + 1))
    case $VI in 1) P1=$((P1 + 1)) ;; 2) P2=$((P2 + 1)) ;; esac
}
fail() {
    FAIL=$((FAIL + 1))
    case $VI in 1) F1=$((F1 + 1)) ;; 2) F2=$((F2 + 1)) ;; esac
    FAILED="$FAILED $1$VSUF"
    echo "FAIL $1$VSUF: $2"
}

same() { # same EXPECTED ACTUAL LABEL NAME
    if cmp -s "$1" "$2"; then return 0; fi
    fail "$4" "$3 differs"
    if [ "$VERBOSE" = 1 ]; then diff -u "$1" "$2" | sed 's/^/    /' | head -60; fi
    return 1
}

meta_get() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }
meta_all() { sed -n "s/^$2=//p" "$1" 2>/dev/null; }

# check_meta BASE KEYS : every line of BASE.meta must be a known one (else exit 2)
check_meta() {
    [ -f "$1.meta" ] || return 0
    while IFS= read -r _l || [ -n "$_l" ]; do
        case $_l in
        "" | stdout=epipe | stdout=closed) ;;
        env=SEA_HEAP_CHECK=*) ;;
        filter=compute-time) [ "$2" = ports ] && continue
            echo "cross_run.sh: $(basename "$1").meta: unknown line '$_l'" >&2; exit 2 ;;
        heap=off) [ "$2" = rt ] || continue
            echo "cross_run.sh: $(basename "$1").meta: unknown line '$_l'" >&2; exit 2 ;;
        stdout=slowpipe | env=*) [ "$2" = rt ] && continue
            echo "cross_run.sh: $(basename "$1").meta: unknown line '$_l'" >&2; exit 2 ;;
        *) echo "cross_run.sh: $(basename "$1").meta: unknown line '$_l'" >&2; exit 2 ;;
        esac
    done < "$1.meta"
}

newwork() { # newwork BASE : fresh work directory $WORK with the fixtures
    WORK=$(mktemp -d "$TMP/work.XXXXXX") || return 1
    if [ -d "$1.files" ]; then cp -R "$1.files/." "$WORK/" || return 1; fi
    return 0
}

relfiles() { (cd "$1" && find . -type f | sed 's|^\./||' | sort); }

check_files() { # check_files NAME BASE
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

# asm_link NAME SRC EXTRAOBJ ASFLAGS... : assemble SRC, link into $TMP/prog. Each step must
# exit 0 with empty standard error. Records the failure and returns 1 otherwise.
asm_link() {
    _name=$1; _src=$2; _extra=$3; shift 3
    rm -f "$TMP/prog" "$TMP/prog.o"
    "$AS" --64 "$@" -o "$TMP/prog.o" "$_src" >"$TMP/a.out" 2>"$TMP/a.err"
    _st=$?
    if [ $_st -ne 0 ] || [ -s "$TMP/a.out" ] || [ -s "$TMP/a.err" ]; then
        fail "$_name" "assemble failed (status $_st): $(head -3 "$TMP/a.err" | tr '\n' ' ')"
        return 1
    fi
    # shellcheck disable=SC2086
    "$CC" -no-pie -o "$TMP/prog" $_extra "$TMP/prog.o" "$LIBSEA" "$BSKRT" -lm >"$TMP/l.out" 2>"$TMP/l.err"
    _st=$?
    if [ $_st -ne 0 ] || [ -s "$TMP/l.out" ] || [ -s "$TMP/l.err" ]; then
        fail "$_name" "link failed (status $_st): $(head -3 "$TMP/l.err" | tr '\n' ' ')"
        return 1
    fi
    return 0
}

# heap_begin / heap_end: exactly as tests/run.sh (DESIGN.md 6.2): SEA_HEAP_CHECK=1 for the run unless
# the meta says heap=off or env=SEA_HEAP_CHECK=V; the line `heap: 0 live objects` is required and
# removed after an exit with status 0 when the value is exactly 1 (LEAK set otherwise).
heap_begin() {
    HEAPVAL=1
    if [ "$(meta_get "$1.meta" heap)" = off ]; then HEAPVAL=; fi
    _e=$(meta_get "$1.meta" env)
    case $_e in SEA_HEAP_CHECK=*) HEAPVAL=${_e#SEA_HEAP_CHECK=} ;; esac
    if [ -n "$HEAPVAL" ]; then SEA_HEAP_CHECK=$HEAPVAL; export SEA_HEAP_CHECK; else unset SEA_HEAP_CHECK; fi
}
heap_end() {
    LEAK=
    unset SEA_HEAP_CHECK
    if [ "$HEAPVAL" != 1 ] || [ "$st" != 0 ]; then return 0; fi
    _l=$(tail -n 1 "$TMP/r.err" 2>/dev/null)
    if [ "$_l" = "heap: 0 live objects" ]; then
        sed '$d' "$TMP/r.err" > "$TMP/r.err.new" && mv "$TMP/r.err.new" "$TMP/r.err"
    else
        LEAK="leak: ${_l:-no heap line}"
    fi
}

# run_prog BASE EXE : as tests/run.sh: stdin, arguments, stdout=epipe|closed. Sets st,
# leaves $TMP/r.out and $TMP/r.err.
run_prog() {
    _b=$1; _exe=$2
    heap_begin "$_b"
    set --
    if [ -f "$_b.args" ]; then
        while IFS= read -r _a || [ -n "$_a" ]; do set -- "$@" "$_a"; done < "$_b.args"
    fi
    if [ "$(meta_get "$_b.meta" stdout)" = epipe ]; then
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
        : >"$TMP/r.out"
        ERRFILE=$TMP/r.err; export ERRFILE
        run_limited "$TIMEOUT" "$(stdin_for "$_b")" "$WORK" sh -c 'exec "$@" >&- 2>"$ERRFILE"' sh "$_exe" "$@"
        st=$?
    else
        run_limited "$TIMEOUT" "$(stdin_for "$_b")" "$WORK" "$_exe" "$@" >"$TMP/r.out" 2>"$TMP/r.err"
        st=$?
    fi
    heap_end
}

want_status() { if [ -f "$1.status" ]; then sed -n 1p "$1.status"; else echo 0; fi; }

# case_names KIND : sorted unique NAMEs having NAME.s or NAME.packfail
case_names() {
    ls "$BUNDLE/cases/$1" 2>/dev/null | sed -n -e 's/\.s$//p' -e 's/\.packfail$//p' | sort -u
}

# do_case KIND NAME : build and run one compiled case
do_case() {
    _kind=$1; _n=$2
    name=$_kind/$_n
    base=$BUNDLE/cases/$_kind/$_n
    case $_kind in ports) check_meta "$base" ports ;; *) check_meta "$base" prog ;; esac
    if [ -f "$base.packfail" ]; then
        fail "$name" "compile (on the Mac) failed: $(head -3 "$base.packfail" | tr '\n' ' ')"; return
    fi
    case $_kind in
    programs) [ -f "$base.out" ] || { fail "$name" "missing $_n.out"; return; } ;;
    errors) [ -f "$base.err" ] && [ -f "$base.status" ] || { fail "$name" "missing $_n.err or $_n.status"; return; } ;;
    passes) [ -f "$base.out" ] || { fail "$name" "missing $_n.out"; return; } ;;
    accept) [ -f "$base.out" ] || { fail "$name" "missing $_n.out"; return; } ;;
    ports) [ -f "$base.out" ] && [ -f "$base.expect/$_n.json" ] || { fail "$name" "missing $_n.out or $_n.expect/$_n.json"; return; } ;;
    esac
    asm_link "$name" "$base.s" "" || return
    # the one build is run under every variant (Decision 104); a failure of the second is labelled
    _savet=$TIMEOUT
    case $_kind in accept | ports) TIMEOUT=${SEA_ACCEPT_TIMEOUT:-120} ;; esac
    _vi=0
    for _v in $VARIANTS; do
        _vi=$((_vi + 1))
        VI=$_vi
        VSUF=
        if [ "$_v" = default ]; then
            unset SEA_KERNELS
        else
            SEA_KERNELS=$_v; export SEA_KERNELS
            if [ $_vi -gt 1 ]; then VSUF=" [$_v]"; fi
        fi
        run_variant "$name" "$base" "$_kind"
    done
    unset SEA_KERNELS
    VI=
    VSUF=
    TIMEOUT=$_savet
}

# run_variant NAME BASE KIND : run the program built in $TMP/prog (under the SEA_KERNELS the caller
# set) and compare it with the expected files of BASE; counts one pass or the failures.
run_variant() {
    name=$1; base=$2; _kind=$3
    if ! newwork "$base"; then fail "$name" "cannot prepare the work directory"; rm -rf "$WORK"; return; fi
    run_prog "$base" "$TMP/prog"
    experr=$TMP/empty; [ -f "$base.err" ] && experr=$base.err
    expout=$TMP/empty; [ -f "$base.out" ] && expout=$base.out
    want=$(want_status "$base")
    # filter=compute-time (L-cn): drop the "Compute time" line from both outputs before comparing
    if [ "$(meta_get "$base.meta" filter)" = compute-time ]; then
        grep -v '^Compute time: .* s$' "$expout" > "$TMP/f.exp"
        grep -v '^Compute time: .* s$' "$TMP/r.out" > "$TMP/f.out"
        expout=$TMP/f.exp
        mv -f "$TMP/f.out" "$TMP/r.out"
    fi
    ok=1
    [ "$st" = "$want" ] || { fail "$name" "exit status $st, expected $want"; ok=0; }
    [ -n "$LEAK" ] && { fail "$name" "$LEAK"; ok=0; }
    if [ $ok = 1 ] && [ "$(meta_get "$base.meta" stdout)" != epipe ] && [ "$(meta_get "$base.meta" stdout)" != closed ]; then
        same "$expout" "$TMP/r.out" "stdout" "$name" || ok=0
    fi
    [ $ok = 1 ] && { same "$experr" "$TMP/r.err" "stderr" "$name" || ok=0; }
    if [ $ok = 1 ] && [ "$_kind" != passes ]; then check_files "$name" "$base" || ok=0; fi
    rm -rf "$WORK"
    [ $ok = 1 ] && pass
}

for k in programs errors passes accept ports; do
    for n in $(case_names $k); do do_case $k "$n"; done
done

# ---- fusion/NAME: the temporaries check (2.12.10) ----------------------------------
# count_run ARG : run $TMP/prog ARG under SEA_HEAP_CHECK=count in a fresh directory; sets RUN_A
# (the allocation count) or RUN_WHY (the reason the run failed)
count_run() {
    RUN_A=; RUN_WHY=
    _arg=$1
    WORK=$(mktemp -d "$TMP/work.XXXXXX") || { RUN_WHY="cannot prepare the work directory"; return 1; }
    SEA_HEAP_CHECK=count; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" /dev/null "$WORK" "$TMP/prog" "$_arg" >"$TMP/r.out" 2>"$TMP/r.err"
    _st=$?
    unset SEA_HEAP_CHECK
    _left=$(ls -A "$WORK")
    rm -rf "$WORK"
    if [ $_st -ne 0 ]; then RUN_WHY="K=$_arg: exit status $_st: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; return 1; fi
    if [ -n "$_left" ]; then RUN_WHY="K=$_arg: unexpected files left: $_left"; return 1; fi
    if [ "$(wc -l <"$TMP/r.err" | tr -d ' ')" != 1 ]; then
        RUN_WHY="K=$_arg: standard error is not exactly the heap line: $(head -3 "$TMP/r.err" | tr '\n' ' ')"; return 1
    fi
    _l=$(cat "$TMP/r.err")
    _a=$(printf '%s\n' "$_l" | sed -n 's/^heap: \([0-9][0-9]*\) allocations, \([0-9][0-9]*\) live objects$/\1 \2/p')
    if [ -z "$_a" ]; then RUN_WHY="K=$_arg: no count-mode heap line: '$_l'"; return 1; fi
    set -- $_a
    if [ "$2" != 0 ]; then RUN_WHY="K=$_arg: leak: '$_l'"; return 1; fi
    RUN_A=$1
    return 0
}

# do_fusion NAME : build one fusion case and check it under every variant (Decision 104)
do_fusion() {
    name=fusion/$1
    base=$BUNDLE/cases/fusion/$1
    if [ -f "$base.packfail" ]; then
        fail "$name" "compile (on the Mac) failed: $(head -3 "$base.packfail" | tr '\n' ' ')"; return
    fi
    fk=$(meta_get "$base.fusion" k)
    fn=$(meta_get "$base.fusion" per_iteration)
    case "$fk:$fn" in
    *[!0-9:]* | :* | *:) echo "cross_run.sh: $1.fusion: missing or bad k= / per_iteration= line" >&2; exit 2 ;;
    esac
    asm_link "$name" "$base.s" "" || return
    _vi=0
    for _v in $VARIANTS; do
        _vi=$((_vi + 1))
        VI=$_vi
        VSUF=
        if [ "$_v" = default ]; then
            unset SEA_KERNELS
        else
            SEA_KERNELS=$_v; export SEA_KERNELS
            if [ $_vi -gt 1 ]; then VSUF=" [$_v]"; fi
        fi
        if ! count_run "$fk"; then fail "$name" "$RUN_WHY"; continue; fi
        _a1=$RUN_A
        if ! count_run $((fk + 1)); then fail "$name" "$RUN_WHY"; continue; fi
        _a2=$RUN_A
        if [ $((_a2 - _a1)) -eq "$fn" ]; then
            pass
            echo "ok   $name$VSUF: $_a1 allocations at K=$fk, $_a2 at K=$((fk + 1))"
        else
            fail "$name" "$_a1 allocations at K=$fk, $_a2 at K=$((fk + 1)): $((_a2 - _a1)) per iteration, derived $fn"
        fi
    done
    unset SEA_KERNELS
    VI=
    VSUF=
}
for n in $(case_names fusion); do do_fusion "$n"; done

# ---- rt/NAME: the runtime tests (4.7.1) --------------------------------------------
cat >"$TMP/runrt.sh" <<'RUNRT'
#!/bin/sh
# runrt.sh EXE MODE OUT ERR : stdin /dev/null; epipe: stdout a pipe whose reader has gone;
# slowpipe: stdout a pipe whose reader starts reading after 1 s
exe=$1; mode=$2; out=$3; err=$4
if [ "$mode" = epipe ]; then
    fifo=$out.fifo
    mkfifo "$fifo" || exit 125
    ( : <"$fifo" ) &
    rp=$!
    exec 4>"$fifo"
    wait $rp
    : >"$out"
    exec "$exe" </dev/null >&4 2>"$err"
fi
if [ "$mode" = slowpipe ]; then
    fifo=$out.fifo
    mkfifo "$fifo" || exit 125
    { sleep 1; cat; } <"$fifo" >"$out" &
    "$exe" </dev/null >"$fifo" 2>"$err"
    st=$?
    wait
    exit $st
fi
exec "$exe" </dev/null >"$out" 2>"$err"
RUNRT
for src in "$BUNDLE"/tests/rt/x86_64_linux/*.s; do
    [ -e "$src" ] || continue
    n=$(basename "$src" .s)
    name=rt/$n
    base=${src%.s}
    check_meta "$base" rt
    asm_link "$name" "$src" "$RTMAIN" --fatal-warnings -I "$BUNDLE/include" -I "$BUNDLE/baysick/include" || continue
    mode=plain
    case "$(meta_get "$base.meta" stdout)" in
    "") ;; epipe) mode=epipe ;; slowpipe) mode=slowpipe ;;
    *) echo "cross_run.sh: $name: bad stdout= in $n.meta" >&2; exit 2 ;;
    esac
    envargs="-u SEA_KERNELS -u BAYSICK_KERNELS -u SEA_HEAP_CHECK"
    for kv in $(meta_all "$base.meta" env); do envargs="$envargs $kv"; done
    WORK=$(mktemp -d "$TMP/work.XXXXXX") || { fail "$name" "cannot prepare the work directory"; continue; }
    rm -f "$TMP/r.out" "$TMP/r.err" "$TMP/r.out.fifo"
    # shellcheck disable=SC2086
    run_limited "$TIMEOUT" /dev/null "$WORK" env $envargs sh "$TMP/runrt.sh" "$TMP/prog" "$mode" "$TMP/r.out" "$TMP/r.err" 2>/dev/null
    st=$?
    rm -rf "$WORK"
    want=0; [ -f "$base.status" ] && want=$(tr -d ' \n' <"$base.status")
    expout=$TMP/empty; [ -f "$base.out" ] && expout=$base.out
    experr=$TMP/empty; [ -f "$base.err" ] && experr=$base.err
    ok=1
    [ "$st" = "$want" ] || { fail "$name" "exit status $st, expected $want"; ok=0; }
    [ $ok = 1 ] && { same "$experr" "$TMP/r.err" "stderr" "$name" || ok=0; }
    [ $ok = 1 ] && { same "$expout" "$TMP/r.out" "stdout" "$name" || ok=0; }
    [ $ok = 1 ] && pass
done


# ---- math/math_check: bit-exact elementary functions against the vectors (4.10.6) ------
if [ ! -f "$BUNDLE/tests/math/math_check.c" ]; then
    # absent only if the packing patterns deliberately excluded it
    if [ -z "$(cat "$BUNDLE/PATTERNS" 2>/dev/null)" ]; then fail math/math_check "the bundle lacks the math case"; fi
else
    name=math/math_check
    # two translation units: the 4-lane part is compiled with -mavx2 and runs only when the CPU
    # reports AVX2 (DESIGN.md 2.12.8)
    { "$CC" -O1 -ffp-contract=off -c -o "$TMP/math_check.o" "$BUNDLE/tests/math/math_check.c" &&
      "$CC" -O1 -ffp-contract=off -mavx2 -c -o "$TMP/math_check_y.o" "$BUNDLE/tests/math/math_check_y.c" &&
      "$CC" -o "$TMP/math_check" "$TMP/math_check.o" "$TMP/math_check_y.o" "$LIBSEA" -lm -lpthread; } \
        >"$TMP/m.cc" 2>&1
    if [ $? -ne 0 ] || [ -s "$TMP/m.cc" ]; then
        fail "$name" "build failed: $(head -3 "$TMP/m.cc" | tr '\n' ' ')"
    else
        run_limited 60 /dev/null "$TMP" "$TMP/math_check" "$BUNDLE/tests/math" >"$TMP/m.out" 2>"$TMP/m.err"
        st=$?
        if [ $st -eq 0 ] && [ ! -s "$TMP/m.err" ]; then
            pass
        else
            fail "$name" "exit status $st: $(grep -v ' cases ok$' "$TMP/m.out" "$TMP/m.err" | head -3 | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$TMP/m.out" | head -60; fi
        fi
    fi
fi

if [ $((PASS + FAIL)) -eq 0 ]; then echo "cross_run.sh: the bundle holds no case" >&2; exit 2; fi
echo "----"
_vi=0
for _v in $VARIANTS; do
    _vi=$((_vi + 1))
    case $_vi in 1) _p=$P1; _f=$F1 ;; *) _p=$P2; _f=$F2 ;; esac
    _l=$_v
    if [ "$_v" = default ]; then _l="default (SEA_KERNELS unset, avx2)"; fi
    echo "variant $_l: passed: $_p  failed: $_f"
done
echo "once (build, rt, math): passed: $((PASS - P1 - P2))  failed: $((FAIL - F1 - F2))"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
