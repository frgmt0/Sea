#!/bin/sh
# tests/stage.sh -- each pass on its own, on the committed golden output of the previous pass
# (docs/DESIGN.md 6.2, "stage.sh"). POSIX sh. Builds nothing: it runs the pass executables of
# build/ (run make first).
#
# For every tests/passes/NAME.<prev> that has the golden next file NAME.<next>:
#     pass 2a  seaname     NAME.ast  -> NAME.res
#     pass 2a  seacheck    NAME.res  -> NAME.hir1
#     pass 2b  seaexpand   NAME.hir1 -> NAME.hir
#     pass 3a  seafuse     NAME.hir  -> NAME.hirf     (NAME.hir itself when there is no NAME.hirf, L-ek)
#     pass 3a  sealoop     NAME.hirf -> NAME.hirl     (NAME.hir when there is no NAME.hirf)
#     pass 3a  sealower    NAME.hirl -> NAME.lir1
#     pass 3b  seaopt      NAME.lir1 -> NAME.lir2
#     pass 3c  sealopt     NAME.lir2 -> NAME.lir3     (skipped when NAME.lir3 is absent)
#     pass 3d  seavec      NAME.lir3 -> NAME.lir      (7b: a copy; skipped when NAME.lir is absent)
#     pass 4   seagen_a64  NAME.lir  -> NAME.s     (golden assembly, optional)
# the golden previous file is copied as sea.<prev> into a fresh directory, the pass runs there
# (standard input /dev/null), must exit 0, and the sea.<next> it wrote must be byte-identical
# to the golden file and end with #end (the assembly of pass 4 has no #end). Pass 1
# (seaparse, NAME.sea -> NAME.ast) is tested through the driver: `sea build --emit ast
# --no-prelude NAME.sea`, which runs no other pass.
#
# A golden file whose pass executable is not built is a FAILURE ("not built"), not a skip.
#
# A NAME.hirl with neither NAME.hir nor NAME.sea is not a sealoop golden but the input of a
# sealower test written by hand (a record sealoop does not write yet, DESIGN.md 3.5.9): the
# sealoop pair skips it, the sealower pair runs on it.
#
# A NAME.hir with no NAME.hir1 and no NAME.sea (or with a NAME.prelude) is the input of a sealoop
# test written by hand (a two-file sea.hir with the prelude, DESIGN.md 6.2, Decision 55): the
# seaexpand pair skips it; with a NAME.sea and no NAME.prelude the missing NAME.hir1 is a FAILURE. A NAME.hirl with no
# NAME.hir and a NAME.prelude starts the chain at sealower (the dumps of a prelude test are
# committed goldens): the sealoop pair skips it. The goldens hold the prelude's `#file std.sea`.
#
# A NAME.lir with neither NAME.lir1 nor NAME.sea is not a seaopt golden but a pass-4 test: LIR
# written by hand, with NAME.out (expected standard output) [+ NAME.err, NAME.status]. It runs
# seagen_a64 on it (as sea.lir, standard input /dev/null), assembles sea.s with `as`, links it
# with libsea.a and libbaysickrt.a as the driver does, and runs the program (standard input
# /dev/null). Exit status must be NAME.status (else 0), standard output must equal NAME.out and
# standard error NAME.err (else empty). A missing tool or library is a FAILURE. Name:
# stage/seagen_a64/NAME.
#
# A NAME.sea test with a NAME.lir1 and a NAME.lir2 but no NAME.hirl (the opt5_* dumps: .sea +
# .lir1 + .lir2 [+ .lir], DESIGN.md 6.2) starts the chain at seaopt: the sealower pair skips it
# (keyed on NAME.lir2, L-aw). With neither NAME.hirl nor NAME.lir2 the missing NAME.hirl is a
# FAILURE. A hand-written seaopt test (NAME.lir1 + NAME.lir2, no NAME.sea, no NAME.lir3) has no
# sealopt golden: the pair sealopt lir2 lir3 is skipped whenever NAME.lir3 is absent (L-bj). A
# NAME.lir2 with neither NAME.lir1 nor NAME.sea is a hand-written sealopt input: the seaopt pair
# skips it. A NAME.lir3 is the sealopt golden and a NAME.lir that has a NAME.lir3 or a NAME.lir2 the seavec
# golden (equal to NAME.lir3 in 7b), never a pass-4 test. A NAME.lir3 with neither NAME.lir2 nor NAME.sea is a
# hand-written seavec input: the sealopt pair skips it.
# A NAME.lir with a NAME.lir1 but neither NAME.lir2 nor NAME.sea is neither: a setup FAILURE.
# The pair seafuse hir hirf runs on every NAME.hir (golden NAME.hirf, else NAME.hir itself, L-ek).
#
# The ra5_live_* tests (Decision 75, DESIGN.md 6.2) also check the shape rule on the -S output of both
# targets: seagen_a64 on the LIR, seagen_x64 on a copy retargeted as tests/cross_pack.sh does. Every
# innermost loop (the range from a `L<f>_<b>_top:` label / `.L<f>_<b>_top:` to the last branch back
# to it that contains no other loop top label) must contain no frame access (arm64 `[sp`, `[x29`;
# x86_64 `(%rsp)`, `(%rbp)`), and there must be at least one such loop. Outer loops are not checked.

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

# meta_get FILE KEY ; heap_begin BASE ; heap_end : the heap check of DESIGN.md 6.2, exactly as
# tests/run.sh: SEA_HEAP_CHECK=1 for a program run (heap=off or env=SEA_HEAP_CHECK=V in
# BASE.meta change it); after an exit with status 0 under the value 1 the last line of standard
# error must be `heap: 0 live objects` and is removed (LEAK is set otherwise).
meta_get() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }
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
    _l=$(tail -n 1 "$TMP/p.err" 2>/dev/null)
    if [ "$_l" = "heap: 0 live objects" ]; then
        sed '$d' "$TMP/p.err" > "$TMP/p.err.new" && mv "$TMP/p.err.new" "$TMP/p.err"
    else
        LEAK="leak: ${_l:-no heap line}"
    fi
}

# stage PASS PREV NEXT : one pass over every golden pair
stage() {
    _p=$1; _prev=$2; _next=$3
    for g in "$ROOT"/tests/passes/*."$_next"; do
        [ -e "$g" ] || continue
        nm=$(basename "$g" ".$_next")
        in=$ROOT/tests/passes/$nm.$_prev
        pv=$_prev
        # sealoop reads NAME.hirf where a test has one, else NAME.hir (L-ek)
        if [ "$_p" = sealoop ] && [ ! -f "$in" ]; then in=$ROOT/tests/passes/$nm.hir; fi
        name=stage/$_p/$nm
        # a hand-written NAME.lir2 (no NAME.lir1, no NAME.sea) is a sealopt-only test: no seaopt golden
        if [ "$_next" = lir3 ] && [ ! -f "$in" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then continue; fi
        if [ "$_next" = lir2 ] && [ ! -f "$in" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then continue; fi
        # a hand-written NAME.lir (no NAME.lir1, no NAME.sea) is a pass-4 test, not a golden
        if [ "$_next" = lir ] && [ ! -f "$in" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then continue; fi
        # a hand-written NAME.hirl (no NAME.hir, no NAME.sea) is a sealower test: no sealoop golden
        if [ "$_next" = hirl ] && [ ! -f "$in" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then continue; fi
        # a hand-written NAME.lir1 (no NAME.hirl, no NAME.sea) is a seaopt-only test: no sealower golden
        if [ "$_next" = lir1 ] && [ ! -f "$in" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then continue; fi
        # a NAME.lir1 with no NAME.hirl but a NAME.lir2 (the opt5_* dumps) starts at seaopt: no
        # sealower golden. Without NAME.lir2 the missing NAME.hirl is a failure.
        if [ "$_next" = lir1 ] && [ ! -f "$in" ] && [ -f "$ROOT/tests/passes/$nm.lir2" ]; then continue; fi
        # 4h (DESIGN.md 6.2): a golden NAME.hir with no NAME.hir1 is a stage-only input of sealoop
        # (hand-written two-file sea.hir, no NAME.sea) or the start of a prelude test: no seaexpand
        # golden. A NAME.sea test without NAME.prelude still needs its NAME.hir1.
        if [ "$_next" = hir ] && [ ! -f "$in" ] && { [ ! -f "$ROOT/tests/passes/$nm.sea" ] || [ -f "$ROOT/tests/passes/$nm.prelude" ]; }; then continue; fi
        # a NAME.hirl with no NAME.hir but a NAME.prelude starts at .hirl (the prelude test
        # builds the dumps from the real prelude): no sealoop golden
        if [ "$_next" = hirl ] && [ ! -f "$in" ] && [ -f "$ROOT/tests/passes/$nm.prelude" ]; then continue; fi
        selected "$name" || continue
        if [ ! -f "$in" ]; then fail "$name" "golden input $(basename "$in") missing"; continue; fi
        if [ ! -x "$BUILD/$_p" ]; then fail "$name" "pass '$_p' not built ($BUILD/$_p)"; continue; fi
        w=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
        cp "$in" "$w/sea.$pv"
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

# loop_frames FILE.s : the number of frame accesses summed over the innermost loops of FILE.s, then
# the number of innermost loops (two numbers on one line)
loop_frames() {
    awk '
    { L[NR] = $0 }
    END {
        loops = 0; bad = 0
        for (i = 1; i <= NR; i++) if (L[i] ~ /_top:$/) {
            lab = L[i]; sub(/:$/, "", lab); sub(/^[ \t]+/, "", lab); last = 0
            for (j = i + 1; j <= NR; j++) { n = split(L[j], w, /[ \t,]+/); if (w[n] == lab) last = j }
            if (!last) continue
            inner = 1; fr = 0
            for (j = i + 1; j <= last; j++) {
                s = L[j]
                if (s ~ /_top:$/) { inner = 0; break }
                if (s ~ /^[ \t]*$/ || s ~ /^[ \t]*[.A-Za-z0-9_]+:/ || s ~ /^[ \t]*(\/\/|#)/ || s ~ /^[ \t]*\./) continue
                if (s ~ /\[sp|\[x29|\(%rsp\)|\(%rbp\)/) fr++
            }
            if (inner) { loops++; bad += fr }
        }
        print bad, loops
    }' "$1"
}

# pass 4 on hand-written LIR: build, run and compare the output
for g in "$ROOT"/tests/passes/*.lir; do
    [ -e "$g" ] || continue
    nm=$(basename "$g" .lir)
    if [ -f "$ROOT/tests/passes/$nm.lir1" ] && [ ! -f "$ROOT/tests/passes/$nm.lir2" ] && [ ! -f "$ROOT/tests/passes/$nm.sea" ]; then
        # neither a pass-4 test (it has a NAME.lir1) nor a sealopt golden (no NAME.lir2, no NAME.sea): a setup failure
        selected "stage/sealopt/$nm" && fail "stage/sealopt/$nm" "$nm.lir has $nm.lir1 but neither $nm.lir2 nor $nm.sea (setup error)"
        continue
    fi
    [ -f "$ROOT/tests/passes/$nm.lir1" ] && continue
    [ -f "$ROOT/tests/passes/$nm.lir2" ] && continue
    [ -f "$ROOT/tests/passes/$nm.lir3" ] && continue
    [ -f "$ROOT/tests/passes/$nm.sea" ] && continue
    name=stage/seagen_a64/$nm
    selected "$name" || continue
    d=$ROOT/tests/passes
    if [ ! -f "$d/$nm.out" ]; then fail "$name" "expected output $nm.out missing"; continue; fi
    if [ ! -x "$BUILD/seagen_a64" ]; then fail "$name" "pass 'seagen_a64' not built ($BUILD/seagen_a64)"; continue; fi
    if [ ! -f "$BUILD/libsea.a" ] || [ ! -f "$BUILD/libbaysickrt.a" ]; then fail "$name" "runtime library not built ($BUILD)"; continue; fi
    want=0
    [ -f "$d/$nm.status" ] && want=$(sed -n 1p "$d/$nm.status")
    exp_err=$TMP/empty
    [ -f "$d/$nm.err" ] && exp_err=$d/$nm.err
    w=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
    cp "$g" "$w/sea.lir"
    ok=1
    run_limited "$TIMEOUT" "$w" "$BUILD/seagen_a64" >"$TMP/p.out" 2>"$TMP/p.err"
    st=$?
    [ $st -eq 0 ] || { fail "$name" "seagen_a64 exit status $st: $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
    [ $ok = 1 ] && [ ! -f "$w/sea.s" ] && { fail "$name" "no sea.s written"; ok=0; }
    # ra5_live_*: the loops must have no frame access in the -S output of both targets (DESIGN.md 6.2)
    case $nm in ra5_live_*)
        if [ $ok = 1 ]; then
            set -- $(loop_frames "$w/sea.s")
            if [ "$2" -lt 1 ]; then fail "$name" "arm64: no innermost loop found in sea.s"; ok=0
            elif [ "$1" != 0 ]; then fail "$name" "arm64: $1 frame accesses in the innermost loops"; ok=0; fi
        fi
        if [ $ok = 1 ]; then
            if [ ! -x "$BUILD/seagen_x64" ]; then fail "$name" "pass 'seagen_x64' not built ($BUILD/seagen_x64)"; ok=0; else
                wx=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
                awk '!d && $1 == "#target" { print "#target x86_64-linux"; d = 1; next } { print }' "$g" > "$wx/sea.lir"
                run_limited "$TIMEOUT" "$wx" "$BUILD/seagen_x64" >"$TMP/p.out" 2>"$TMP/p.err"
                st=$?
                if [ $st -ne 0 ] || [ ! -f "$wx/sea.s" ]; then fail "$name" "seagen_x64 exit status $st: $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0
                else
                    set -- $(loop_frames "$wx/sea.s")
                    if [ "$2" -lt 1 ]; then fail "$name" "x86_64: no innermost loop found in sea.s"; ok=0
                    elif [ "$1" != 0 ]; then fail "$name" "x86_64: $1 frame accesses in the innermost loops"; ok=0; fi
                fi
                rm -rf "$wx"
            fi
        fi ;;
    esac
    if [ $ok = 1 ]; then
        SDK=$(env -u SDKROOT xcrun --show-sdk-path 2>/dev/null | sed -n 1p)
        if [ -z "$SDK" ] || [ ! -d "$SDK" ]; then fail "$name" "cannot determine macOS SDK path"; ok=0; fi
    fi
    if [ $ok = 1 ]; then
        (cd "$w" && env -u SDKROOT as -arch arm64 -mmacosx-version-min=11.0 -o sea.o sea.s) >"$TMP/p.out" 2>"$TMP/p.err" </dev/null
        st=$?
        [ $st -eq 0 ] || { fail "$name" "as failed ($st): $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
    fi
    if [ $ok = 1 ]; then
        (cd "$w" && env -u SDKROOT ld -o prog sea.o "$BUILD/libsea.a" "$BUILD/libbaysickrt.a" -lSystem \
            -syslibroot "$SDK" -e _main -arch arm64 -platform_version macos 11.0 11.0) >"$TMP/p.out" 2>"$TMP/p.err" </dev/null
        st=$?
        [ $st -eq 0 ] || { fail "$name" "ld failed ($st): $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
    fi
    if [ $ok = 1 ]; then
        heap_begin "$d/$nm"
        run_limited "$TIMEOUT" "$w" "$w/prog" >"$TMP/p.out" 2>"$TMP/p.err"
        st=$?
        heap_end
        [ -n "$LEAK" ] && { fail "$name" "$LEAK"; ok=0; }
        [ "$st" = "$want" ] || { fail "$name" "exit status $st, expected $want"; ok=0; }
        [ $ok = 1 ] && { same "$d/$nm.out" "$TMP/p.out" "standard output" "$name" || ok=0; }
        [ $ok = 1 ] && { same "$exp_err" "$TMP/p.err" "standard error" "$name" || ok=0; }
    fi
    rm -rf "$w"
    [ $ok = 1 ] && pass
done

# stage_fuse : the pair seafuse hir hirf over every NAME.hir. The golden is NAME.hirf where a test
# has one; a test without it holds none of the constructs seafuse rewrites, so seafuse must write
# NAME.hir itself byte for byte (L-ek, DESIGN.md 2.12.3).
stage_fuse() {
    for g in "$ROOT"/tests/passes/*.hir; do
        [ -e "$g" ] || continue
        nm=$(basename "$g" .hir)
        name=stage/seafuse/$nm
        selected "$name" || continue
        gold=$ROOT/tests/passes/$nm.hirf
        [ -f "$gold" ] || gold=$g
        if [ ! -x "$BUILD/seafuse" ]; then fail "$name" "pass 'seafuse' not built ($BUILD/seafuse)"; continue; fi
        w=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
        cp "$g" "$w/sea.hir"
        run_limited "$TIMEOUT" "$w" "$BUILD/seafuse" >"$TMP/p.out" 2>"$TMP/p.err"
        st=$?
        ok=1
        [ $st -eq 0 ] || { fail "$name" "exit status $st: $(head -3 "$TMP/p.err" | tr '\n' ' ')"; ok=0; }
        [ $ok = 1 ] && [ ! -f "$w/sea.hirf" ] && { fail "$name" "no sea.hirf written"; ok=0; }
        [ $ok = 1 ] && { same "$gold" "$w/sea.hirf" "sea.hirf" "$name" || ok=0; }
        if [ $ok = 1 ]; then
            if ! { cmp -s "$w/sea.hirf" "$TMP/end5" || tail -c 6 "$w/sea.hirf" | cmp -s - "$TMP/end6"; }; then
                fail "$name" "sea.hirf does not end with #end"; ok=0
            fi
        fi
        [ $ok = 1 ] && { same "$TMP/empty" "$TMP/p.err" "stderr" "$name" || ok=0; }
        rm -rf "$w"
        [ $ok = 1 ] && pass
    done
}

stage seaname ast res
stage seacheck res hir1
stage seaexpand hir1 hir
stage_fuse
stage sealoop hirf hirl
stage sealower hirl lir1
stage seaopt lir1 lir2
stage sealopt lir2 lir3
stage seavec lir3 lir
stage seagen_a64 lir s

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
