#!/bin/sh
# tests/cross_pack.sh -- build the x86_64-linux test bundle (macOS, POSIX sh; docs/DESIGN.md 6.6.1).
#
# usage: sh tests/cross_pack.sh -o BUNDLE_DIR [PATTERN...]
#   -o BUNDLE_DIR  output directory; must not exist or must be empty (else exit 2)
#   PATTERN        only pack cases whose name (programs/NAME, errors/NAME, passes/NAME,
#                  accept/NAME, ports/NAME, rt/NAME, fusion/NAME, plots/NAME, la/NAME) contains one of the patterns
#                  (matched literally)
#
# Environment:
#   SEA      the driver (default: build/sea of the Sea repository); the pass executables are
#            looked up in $SEA_HOME, else the driver's directory (seagen_x64 is needed)
#   BAYSICK  the Baysick checkout (default: the parent of the Sea repository); its
#            Makefile.linux, include/*.inc and src/runtime_x86_64_linux/*.s go to the bundle
#   SEA_COMPILE_TIMEOUT  seconds per compilation (default 120)
#   LIRCHK   the sea.lir validator (default: tools/lirchk beside the driver, i.e. build/tools/lirchk)
#
# Every x86_64 sea.lir a case is compiled through (the driver's, seavec's output, a hand-written
# pass-4 input) is validated with lirchk (Decision 116, the vector classes and LF records
# included); a rejection is a pack failure of that case (NAME.packfail, "lirchk rejects ...").
#
# Cases (6.6.1): every programs/ test; every errors/ test that compiles (a compile-time test:
# driver exit SEA_EXIT_COMPILE, exactly NAME.err on stderr, empty stdout, NAME.status equal, is
# target-independent and skipped silently); passes/NAME.sea with NAME.out (--no-prelude);
# hand-written passes/NAME.lir (retargeted, run through seagen_x64; not one beside a NAME.lir3, L-fc);
# passes/NAME.lirx64 with a NAME.out and no NAME.sea (L-fc): without a NAME.lir3 a hand-written
# x86_64-linux-only pass-4 test (run through seagen_x64 as it is), with a NAME.lir3 a hand-written
# seavec test (NAME.lir3 retargeted, run through seavec and then seagen_x64); rt/x86_64_linux/NAME.s.
# math/math_check (tests/math: harness source and *.vec, built and run on the host).
# la/la_check and la/la_link (phase 8, DESIGN.md 2.13.8): tests/la/{gen_consts.sh,la_check.c,la_link.sh},
# with the marker files la_check.case / la_link.case, and cases/la/la_mm_exact.s for la_link.
# ports/NAME (phase 6): the Mac builds and checks the port with tests/accept.sh; the case is the port with
# NAME.out (stdout without the "Compute time" line), NAME.args (--export-reference and, from phase 9,
# --figures), NAME.meta (filter=compute-time) and NAME.expect/NAME.json and NAME.expect/output/NAME.svg.
# fusion/NAME (phase 7, DESIGN.md 2.12.10): every tests/fusion/NAME.sea compiled like a program case, with
# the sidecar NAME.fusion (lines `k=K` and `per_iteration=N`, from the program's header lines
# `// fusion K: K` and `// Allocations per iteration: N.`, as tests/fusion.sh reads them); the host runs
# it with K and K + 1 under SEA_HEAP_CHECK=count and checks the difference of the allocation counts.
# plots/NAME (phase 9, DESIGN.md 2.14.8 "Cross", L-la): the Mac runs tests/plots.sh for the case (build,
# run under the heap check, tests/plot_struct.py on NAME.struct; a failure is a pack failure); the case
# is then compiled like a program case, with NAME.out (the Mac's standard output, possibly empty) and
# NAME.expect/PATH for every file the .struct names (subdirectories included): the host runs it under
# both variants and compares the output and each SVG byte for byte (the existing NAME.expect/ check).
# A case whose compilation fails gets NAME.packfail ("status <n>", then stderr) instead of NAME.s.
#
# Exit status: 0 the bundle is complete (even with .packfail files), 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SEA=${SEA:-$ROOT/build/sea}
BAYSICK=${BAYSICK:-$(cd "$ROOT/.." && pwd)}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
BUNDLE=
while [ $# -gt 0 ]; do
    case "$1" in
    -o)
        if [ $# -lt 2 ]; then echo "cross_pack.sh: missing argument for '-o'" >&2; exit 2; fi
        BUNDLE=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "cross_pack.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
PATTERNS="$*"

setup_fail() { echo "cross_pack.sh: $1" >&2; exit 2; }

[ -n "$BUNDLE" ] || setup_fail "usage: sh tests/cross_pack.sh -o BUNDLE_DIR [PATTERN...]"
case $SEA in /*) ;; *) SEA=$(pwd)/$SEA ;; esac
case $BAYSICK in /*) ;; *) BAYSICK=$(pwd)/$BAYSICK ;; esac
[ -x "$SEA" ] || setup_fail "driver '$SEA' not found or not executable; run 'make' first"
SEADIR=${SEA_HOME:-$(dirname "$SEA")}
LIRCHK=${LIRCHK:-$(dirname "$SEA")/tools/lirchk}
case $LIRCHK in /*) ;; *) LIRCHK=$(pwd)/$LIRCHK ;; esac
[ -x "$LIRCHK" ] || setup_fail "validator '$LIRCHK' not found or not executable; run 'make' first (LIRCHK overrides)"
if [ ! -x "$SEADIR/seavec" ]; then
    setup_fail "pass 'seavec' not found in '$SEADIR' (run 'make')"
fi
if [ ! -x "$SEADIR/seagen_x64" ]; then
    setup_fail "pass 'seagen_x64' not found in '$SEADIR': the x86_64 code generator is not built (passes/seagen_x64 not written yet, or run 'make')"
fi
for f in "$BAYSICK/Makefile.linux" "$BAYSICK/include/runtime.inc" "$BAYSICK/include/limits.inc"; do
    [ -f "$f" ] || setup_fail "Baysick file '$f' not found (BAYSICK=$BAYSICK)"
done
ls "$BAYSICK"/src/runtime_x86_64_linux/*.s >/dev/null 2>&1 || setup_fail "no Baysick x86_64 runtime sources in $BAYSICK/src/runtime_x86_64_linux"
ls "$ROOT"/runtime/x86_64_linux/*.s >/dev/null 2>&1 || setup_fail "no Sea x86_64 runtime sources in $ROOT/runtime/x86_64_linux (not written yet)"
[ -f "$ROOT/Makefile.linux" ] || setup_fail "$ROOT/Makefile.linux missing"
if [ -e "$BUNDLE" ]; then
    [ -d "$BUNDLE" ] || setup_fail "'$BUNDLE' exists and is not a directory"
    [ -z "$(ls -A "$BUNDLE" 2>/dev/null)" ] || setup_fail "bundle directory '$BUNDLE' is not empty"
fi

EX_COMPILE=$(awk '$1 == ".equiv" { s = $2; sub(/,$/, "", s); if (s == "SEA_EXIT_COMPILE") { print $3; exit } }' "$ROOT/include/errors.inc")
[ -n "$EX_COMPILE" ] || setup_fail "SEA_EXIT_COMPILE not found in include/errors.inc"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-pack.XXXXXX") || setup_fail "cannot create temporary directory"
trap 'rm -rf "$TMP"' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

mkdir -p "$BUNDLE/include" "$BUNDLE/runtime/x86_64_linux" "$BUNDLE/tests/rt/x86_64_linux" \
    "$BUNDLE/baysick/include" "$BUNDLE/baysick/src/runtime_x86_64_linux" \
    "$BUNDLE/cases/programs" "$BUNDLE/cases/errors" "$BUNDLE/cases/passes" "$BUNDLE/cases/accept" \
    "$BUNDLE/cases/ports" "$BUNDLE/cases/fusion" "$BUNDLE/cases/plots" \
    || setup_fail "cannot create bundle directory '$BUNDLE'"
echo "sea-x86_64-linux-bundle 1" > "$BUNDLE/BUNDLE" || setup_fail "cannot write $BUNDLE/BUNDLE"
printf '%s\n' "$PATTERNS" > "$BUNDLE/PATTERNS" || setup_fail "cannot write $BUNDLE/PATTERNS"
cp "$ROOT/Makefile.linux" "$BUNDLE/" || setup_fail "cannot copy Makefile.linux"
# Every include file: all of include/*.inc, and the bundle must hold each file the bundle's
# Makefile.linux lists in its INCLUDES (derived from that line, not a second list here).
cp "$ROOT"/include/*.inc "$BUNDLE/include/" || setup_fail "cannot copy include files"
for inc in $(sed -n 's/^INCLUDES[[:space:]]*:=[[:space:]]*//p' "$ROOT/Makefile.linux"); do
    [ -f "$BUNDLE/$inc" ] || setup_fail "Makefile.linux needs $inc, which is not in the bundle"
done
cp "$ROOT"/runtime/x86_64_linux/*.s "$BUNDLE/runtime/x86_64_linux/" || setup_fail "cannot copy the runtime"
cp "$ROOT/tests/cross_run.sh" "$ROOT/tests/include_check_x86_64.s" "$ROOT/tests/include_asserts.inc" \
    "$BUNDLE/tests/" || setup_fail "cannot copy test support files"
if [ -f "$ROOT/tests/rt/run_rt_linux.sh" ]; then
    cp "$ROOT/tests/rt/run_rt_linux.sh" "$BUNDLE/tests/rt/" || setup_fail "cannot copy run_rt_linux.sh"
fi
cp "$BAYSICK/Makefile.linux" "$BUNDLE/baysick/" || setup_fail "cannot copy Baysick's Makefile.linux"
cp "$BAYSICK"/include/*.inc "$BUNDLE/baysick/include/" || setup_fail "cannot copy Baysick's include files"
cp "$BAYSICK"/src/runtime_x86_64_linux/*.s "$BUNDLE/baysick/src/runtime_x86_64_linux/" \
    || setup_fail "cannot copy Baysick's x86_64 runtime"

selected() {
    [ -z "$PATTERNS" ] && return 0
    set -f  # patterns are literal, never globs
    for p in $PATTERNS; do
        case "$1" in *"$p"*) set +f; return 0 ;; esac
    done
    set +f
    return 1
}

# run_limited SECONDS DIR CMD... : run CMD in DIR (stdin /dev/null), kill it after SECONDS.
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

PACKED=0
BAD=0

# check_meta BASE : only the known keys of tests/run.sh (a corpus mistake is a setup error)
check_meta() {
    [ -f "$1.meta" ] || return 0
    while IFS= read -r _l || [ -n "$_l" ]; do
        case $_l in
        "" | stdout=epipe | stdout=closed | heap=off | env=SEA_HEAP_CHECK=*) ;;
        *) setup_fail "$(basename "$1").meta: unknown line '$_l'" ;;
        esac
    done < "$1.meta"
}

# sidecars SRCBASE DESTBASE EXT... : copy the sidecar files and directories present
sidecars() {
    _s=$1; _d=$2; shift 2
    for _e in "$@"; do
        if [ -f "$_s.$_e" ]; then cp "$_s.$_e" "$_d.$_e" || setup_fail "cannot copy $_s.$_e"; fi
        if [ -d "$_s.$_e" ]; then cp -R "$_s.$_e" "$_d.$_e" || setup_fail "cannot copy $_s.$_e"; fi
    done
}

# packfail DEST STATUS FILE : record a failed compilation
packfail() {
    {
        echo "status $2"
        cat "$3"
        if [ -s "$TMP/c.out" ]; then echo "unexpected stdout:"; cat "$TMP/c.out"; fi
    } > "$1.packfail" || setup_fail "cannot write $1.packfail"
    BAD=$((BAD + 1))
}

# lirchk_dir DIR : validate DIR/sea.lir with lirchk (Decision 116). On a rejection the first lines of
# its messages are left in $TMP/k.msg and 1 is returned.
lirchk_dir() {
    run_limited "$CTIMEOUT" "$1" "$LIRCHK" >"$TMP/k.out" 2>"$TMP/k.err"
    _kst=$?
    if [ $_kst -ne 0 ]; then
        {
            echo "lirchk rejects sea.lir (status $_kst):"
            cat "$TMP/k.err" "$TMP/k.out" | head -3
        } > "$TMP/k.msg"
        return 1
    fi
    return 0
}

# pack_sea KIND DIR NAME [--no-prelude] : compile DIR/NAME.sea to cases/KIND/NAME.s. The driver runs
# with --keep-temps: its line `sea: temporary files kept in DIR` is removed from the standard error,
# and DIR/sea.lir (written when the compilation got as far as pass 3d) is validated with lirchk.
# Returns 1 when the case is a compile-time error test (skipped), else 0.
pack_sea() {
    _kind=$1; _dir=$2; _nm=$3; shift 3
    _out=$BUNDLE/cases/$_kind/$_nm.s
    run_limited "$CTIMEOUT" "$_dir" "$SEA" build --keep-temps --target x86_64-linux -S -o "$_out" "$@" "$_nm.sea" \
        >"$TMP/c.out" 2>"$TMP/c.err.raw"
    _st=$?
    _kept=$(sed -n 's/^sea: temporary files kept in //p' "$TMP/c.err.raw" | head -1)
    grep -v '^sea: temporary files kept in ' "$TMP/c.err.raw" > "$TMP/c.err"
    _lc=0
    if [ -n "$_kept" ] && [ -f "$_kept/sea.lir" ] && [ $_st -eq 0 ]; then
        lirchk_dir "$_kept" || _lc=1
    fi
    if [ -n "$_kept" ] && [ -d "$_kept" ]; then rm -rf "$_kept"; fi
    if [ $_lc -ne 0 ]; then
        rm -f "$_out"
        packfail "$BUNDLE/cases/$_kind/$_nm" "$_st" "$TMP/k.msg"
        return 0
    fi
    if [ $_st -eq 0 ] && [ ! -s "$TMP/c.out" ] && [ ! -s "$TMP/c.err" ] && [ -f "$_out" ]; then
        return 0
    fi
    rm -f "$_out"
    if [ "$_kind" = errors ] && [ $_st -eq "$EX_COMPILE" ] && [ ! -s "$TMP/c.out" ] \
        && [ -f "$_dir/$_nm.err" ] && cmp -s "$_dir/$_nm.err" "$TMP/c.err" \
        && [ -f "$_dir/$_nm.status" ] && [ "$(sed -n 1p "$_dir/$_nm.status")" = "$_st" ]; then
        return 1
    fi
    packfail "$BUNDLE/cases/$_kind/$_nm" "$_st" "$TMP/c.err"
    return 0
}

# pack_p4 NAME BASE W : pass 4 (seagen_x64) on W/sea.lir, the x86_64-linux LIR of a hand-written test
# (BASE.out, sidecars of BASE). W/sea.lir is validated with lirchk first; the sea.s is the case's NAME.s.
# W is removed. A failure is recorded as NAME.packfail.
pack_p4() {
    _nm=$1; _base=$2; _w=$3
    dest=$BUNDLE/cases/passes/$_nm
    if ! lirchk_dir "$_w"; then
        packfail "$dest" 0 "$TMP/k.msg"
    else
        run_limited "$CTIMEOUT" "$_w" "$SEADIR/seagen_x64" >"$TMP/c.out" 2>"$TMP/c.err"
        st=$?
        if [ $st -eq 0 ] && [ ! -s "$TMP/c.err" ] && [ -f "$_w/sea.s" ]; then
            cp "$_w/sea.s" "$dest.s" || setup_fail "cannot write $dest.s"
            # the pass writes nothing to stdout (the driver sends it to stderr): any is a failure
            if [ -s "$TMP/c.out" ]; then rm -f "$dest.s"; packfail "$dest" "$st" "$TMP/c.err"; fi
        else
            packfail "$dest" "$st" "$TMP/c.err"
        fi
    fi
    rm -rf "$_w"
    sidecars "$_base" "$dest" out err status meta
    PACKED=$((PACKED + 1))
}

for src in "$ROOT"/tests/programs/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "programs/$nm" || continue
    base=${src%.sea}
    check_meta "$base"
    pack_sea programs "$ROOT/tests/programs" "$nm"
    sidecars "$base" "$BUNDLE/cases/programs/$nm" out err status in args meta files expect
    PACKED=$((PACKED + 1))
done

for src in "$ROOT"/tests/errors/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "errors/$nm" || continue
    base=${src%.sea}
    check_meta "$base"
    pack_sea errors "$ROOT/tests/errors" "$nm" || continue
    sidecars "$base" "$BUNDLE/cases/errors/$nm" out err status in args meta files expect
    PACKED=$((PACKED + 1))
done

# passes/NAME.sea with NAME.out: built with --no-prelude and run; with a NAME.prelude marker
# (Decision 57) built with the real prelude, and the marker is a corpus mistake beside a dump
# kind other than hir, hirf, hirl and lir1 (ast, res, hir1, lir2, lir3, lir; as tests/run.sh rejects it)
for src in "$ROOT"/tests/passes/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    base=${src%.sea}
    [ -f "$base.out" ] || continue
    selected "passes/$nm" || continue
    if [ -f "$base.prelude" ]; then
        for x in ast res hir1 lir2 lir3 lir; do
            [ -f "$base.$x" ] && setup_fail "passes/$nm.prelude: not allowed beside a .$x dump (only .hir, .hirf, .hirl, .lir1 and .out)"
        done
        pack_sea passes "$ROOT/tests/passes" "$nm"
    else
        pack_sea passes "$ROOT/tests/passes" "$nm" --no-prelude
    fi
    check_meta "$base"
    sidecars "$base" "$BUNDLE/cases/passes/$nm" out meta
    PACKED=$((PACKED + 1))
done

# accept/NAME (DESIGN.md 6.3, 6.6.1): the Mac builds and runs the program and checks it with
# tests/accept4.sh (heap check, compare.py --keys); its standard output is packed as NAME.out
# and no other sidecar. A Mac run that fails its check is a pack failure (NAME.packfail).
for src in "$ROOT"/tests/accept/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "accept/$nm" || continue
    mkdir -p "$BUNDLE/cases/accept" || setup_fail "cannot create $BUNDLE/cases/accept"
    rm -rf "$TMP/acc"
    SEA="$SEA" sh "$ROOT/tests/accept4.sh" --save-out "$TMP/acc" "accept/$nm" >"$TMP/acc.out" 2>"$TMP/acc.err"
    st=$?
    if [ $st -eq 2 ]; then setup_fail "tests/accept4.sh: $(head -3 "$TMP/acc.err" | tr '\n' ' ')"; fi
    if [ $st -eq 0 ] && [ -f "$TMP/acc/$nm.out" ]; then
        if pack_sea accept "$ROOT/tests/accept" "$nm"; then
            cp "$TMP/acc/$nm.out" "$BUNDLE/cases/accept/$nm.out" || setup_fail "cannot write $nm.out"
        fi
    else
        cat "$TMP/acc.out" "$TMP/acc.err" > "$TMP/acc.all"
        packfail "$BUNDLE/cases/accept/$nm" "$st" "$TMP/acc.all"
    fi
    PACKED=$((PACKED + 1))
done

# ports/NAME (DESIGN.md 6.3, 6.6.1, L-cn): the Mac builds and runs the port and checks it with
# tests/accept.sh (heap check, compare.py, compare_report.py, plot_struct.py on ports/NAME.struct);
# its standard output, without the lines matching `^Compute time: .* s$`, is packed as NAME.out with
# the meta line filter=compute-time and the arguments --export-reference and --figures (NAME.args,
# one per line; phase 9, DESIGN.md 2.14.9 "Cross", L-la); its NAME.json is packed as
# NAME.expect/NAME.json and its output/NAME.svg as NAME.expect/output/NAME.svg, for every port, the
# deferred ones included (the host compares a non-deferred port's SVG byte for byte through the
# NAME.expect/ mechanism and keeps a deferred one's for tests/cross_accept.sh). A Mac run that fails
# its check is a pack failure (NAME.packfail).
# Phase 8 (DESIGN.md 2.13.9, Decision 127) and phase 9 (2.14.9 "The `// cross:` header grammar",
# Decision 138): a port whose header (its leading `//` lines) has the line `// cross: ` followed by
# `compare=accept`, then optionally ` except=KEY[,KEY...]`, then optionally ` svg=approx`, in that
# order (`compare=accept`, `compare=accept except=f_nat,c_best`, `compare=accept svg=approx`,
# `compare=accept except=a,b svg=approx`), gets that line's value as a second NAME.meta line; the host
# then defers the comparison to tests/cross_accept.sh (svg=approx: the kept SVG is judged by the
# structure and skeleton comparison of Decision 138, else byte for byte).

# cross_header SRC : print the value of SRC's `// cross: ` header line (nothing without one); a
# malformed or repeated `// cross:` header line is a corpus mistake (setup error)
cross_header() {
    awk -v f="$1" '
    !/^\/\// { exit }
    /^\/\/ *cross:/ {
        v = $0; sub(/^\/\/ cross: /, "", v)
        if (n++ || v == $0 || v !~ /^compare=accept( except=[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*)?( svg=approx)?$/) {
            print "cross_pack.sh: " f ": bad or repeated header line '\''" $0 "'\''" > "/dev/stderr"; bad = 1; exit
        }
        val = v
    }
    END { if (bad) exit 2; if (val != "") print val }' "$1"
}

for src in "$ROOT"/ports/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "ports/$nm" || continue
    xc=$(cross_header "$src") || exit 2
    rm -rf "$TMP/acc"
    SEA="$SEA" sh "$ROOT/tests/accept.sh" --save-out "$TMP/acc" "ports/$nm" >"$TMP/acc.out" 2>"$TMP/acc.err"
    st=$?
    if [ $st -eq 2 ]; then setup_fail "tests/accept.sh: $(head -3 "$TMP/acc.err" | tr '\n' ' ')"; fi
    if [ $st -eq 0 ] && [ -f "$TMP/acc/$nm.out" ] && [ -f "$TMP/acc/$nm.json" ] && [ -f "$TMP/acc/output/$nm.svg" ]; then
        if pack_sea ports "$ROOT/ports" "$nm"; then
            dest=$BUNDLE/cases/ports/$nm
            grep -v '^Compute time: .* s$' "$TMP/acc/$nm.out" > "$dest.out"
            [ $? -le 1 ] || setup_fail "cannot write $nm.out"
            mkdir -p "$dest.expect/output" && /bin/cp -f "$TMP/acc/$nm.json" "$dest.expect/$nm.json" \
                && /bin/cp -f "$TMP/acc/output/$nm.svg" "$dest.expect/output/$nm.svg" || setup_fail "cannot write $nm.expect"
            printf 'filter=compute-time\n' > "$dest.meta" || setup_fail "cannot write $nm.meta"
            if [ -n "$xc" ]; then printf '%s\n' "$xc" >> "$dest.meta" || setup_fail "cannot write $nm.meta"; fi
            printf '%s\n' --export-reference --figures > "$dest.args" || setup_fail "cannot write $nm.args"
        fi
    else
        cat "$TMP/acc.out" "$TMP/acc.err" > "$TMP/acc.all"
        packfail "$BUNDLE/cases/ports/$nm" "$st" "$TMP/acc.all"
    fi
    PACKED=$((PACKED + 1))
done

# fusion/NAME (DESIGN.md 2.12.10, the temporaries check): compiled like a program case; the sidecar
# NAME.fusion holds `k=K` and `per_iteration=N`, read from the program's header lines `// fusion K: K`
# and `// Allocations per iteration: N.` (the derived count, L-fa) exactly as tests/fusion.sh reads
# them; a program without both lines is a corpus mistake (setup error).
fusion_num() {
    awk -v pre="$2" '
    index($0, pre) == 1 {
        s = substr($0, length(pre) + 1); sub(/\.$/, "", s)
        if (s ~ /^[0-9]+$/) { print s; exit }
    }' "$1"
}
for src in "$ROOT"/tests/fusion/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "fusion/$nm" || continue
    fk=$(fusion_num "$src" "// fusion K: ")
    fn=$(fusion_num "$src" "// Allocations per iteration: ")
    [ -n "$fk" ] && [ -n "$fn" ] || setup_fail "tests/fusion/$nm.sea lacks its '// fusion K: N' or '// Allocations per iteration: N.' header line"
    pack_sea fusion "$ROOT/tests/fusion" "$nm"
    printf 'k=%s\nper_iteration=%s\n' "$fk" "$fn" > "$BUNDLE/cases/fusion/$nm.fusion" \
        || setup_fail "cannot write $nm.fusion"
    PACKED=$((PACKED + 1))
done

# plots/NAME (DESIGN.md 2.14.8 "Cross", L-la): tests/plots.sh checks the case on the Mac (--only: exactly
# this case) and saves its standard output and the files its .struct names (--save-out); a Mac run that
# fails is a pack failure (NAME.packfail). The case is then compiled like a program case; NAME.out and
# NAME.expect/ (the saved files at their paths) are its expected files on the host.
for src in "$ROOT"/tests/plots/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "plots/$nm" || continue
    rm -rf "$TMP/plt"
    SEA="$SEA" LIRCHK="$LIRCHK" sh "$ROOT/tests/plots.sh" --save-out "$TMP/plt" --only "$nm" >"$TMP/plt.out" 2>"$TMP/plt.err"
    st=$?
    if [ $st -eq 2 ]; then setup_fail "tests/plots.sh: $(head -3 "$TMP/plt.err" | tr '\n' ' ')"; fi
    if [ $st -eq 0 ] && [ -f "$TMP/plt/$nm.out" ] && [ -d "$TMP/plt/$nm.expect" ]; then
        if pack_sea plots "$ROOT/tests/plots" "$nm"; then
            dest=$BUNDLE/cases/plots/$nm
            /bin/cp -f "$TMP/plt/$nm.out" "$dest.out" || setup_fail "cannot write $nm.out"
            /bin/cp -R "$TMP/plt/$nm.expect" "$dest.expect" || setup_fail "cannot write $nm.expect"
        fi
    else
        cat "$TMP/plt.out" "$TMP/plt.err" > "$TMP/plt.all"
        packfail "$BUNDLE/cases/plots/$nm" "$st" "$TMP/plt.all"
    fi
    PACKED=$((PACKED + 1))
done

# passes/NAME.lir with none of NAME.sea, NAME.lir1, NAME.lir2 and NAME.lir3: pass-4 tests, retargeted
# (a NAME.lir beside a NAME.lir3 is a seavec golden, as in tests/stage.sh)
for lir in "$ROOT"/tests/passes/*.lir; do
    [ -e "$lir" ] || continue
    nm=$(basename "$lir" .lir)
    base=${lir%.lir}
    [ -f "$base.lir1" ] && continue
    [ -f "$base.lir2" ] && continue
    [ -f "$base.lir3" ] && continue
    [ -f "$base.sea" ] && continue
    selected "passes/$nm" || continue
    check_meta "$base"
    w=$(mktemp -d "$TMP/w.XXXXXX") || setup_fail "cannot create temporary directory"
    if ! awk '!d && $1 == "#target" { print "#target x86_64-linux"; d = 1; next } { print }' "$lir" > "$w/sea.lir"; then
        setup_fail "cannot retarget $lir"
    fi
    pack_p4 "$nm" "$base" "$w"
done

# passes/NAME.lirx64 with a NAME.out and no NAME.sea (L-fc): x86_64-linux pass-4 tests. Without a
# NAME.lir3 the file is the test input (hand-written, x86_64-linux only: gen7_y*, gen7_vfeat); with a
# hand-written NAME.lir3 the test is seavec on NAME.lir3 retargeted, then pass 4 on its output (the
# live seavec output, not the golden NAME.lirx64, which tests/stage.sh compares). A seavec failure
# is a pack failure. Without a NAME.out it is only a seavec golden (stage.sh's), not a run case.
for g in "$ROOT"/tests/passes/*.lirx64; do
    [ -e "$g" ] || continue
    nm=$(basename "$g" .lirx64)
    base=${g%.lirx64}
    [ -f "$base.sea" ] && continue
    [ -f "$base.out" ] || continue
    selected "passes/$nm" || continue
    check_meta "$base"
    w=$(mktemp -d "$TMP/w.XXXXXX") || setup_fail "cannot create temporary directory"
    if [ -f "$base.lir3" ]; then
        if ! awk '!d && $1 == "#target" { print "#target x86_64-linux"; d = 1; next } { print }' "$base.lir3" > "$w/sea.lir3"; then
            setup_fail "cannot retarget $base.lir3"
        fi
        run_limited "$CTIMEOUT" "$w" "$SEADIR/seavec" >"$TMP/c.out" 2>"$TMP/c.err"
        st=$?
        if [ $st -ne 0 ] || [ -s "$TMP/c.err" ] || [ -s "$TMP/c.out" ] || [ ! -f "$w/sea.lir" ]; then
            rm -rf "$w"
            packfail "$BUNDLE/cases/passes/$nm" "$st" "$TMP/c.err"
            sidecars "$base" "$BUNDLE/cases/passes/$nm" out err status meta
            PACKED=$((PACKED + 1))
            continue
        fi
    else
        cp "$g" "$w/sea.lir" || setup_fail "cannot copy $g"
    fi
    pack_p4 "$nm" "$base" "$w"
done

# rt/NAME: the x86_64 runtime tests
for src in "$ROOT"/tests/rt/x86_64_linux/*.s; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .s)
    selected "rt/$nm" || continue
    base=${src%.s}
    cp "$src" "$BUNDLE/tests/rt/x86_64_linux/$nm.s" || setup_fail "cannot copy $src"
    sidecars "$base" "$BUNDLE/tests/rt/x86_64_linux/$nm" out err status meta files
    PACKED=$((PACKED + 1))
done


# math/math_check: the elementary-function harness and its vectors (DESIGN.md 4.10.6)
if selected "math/math_check"; then
    [ -f "$ROOT/tests/math/math_check.c" ] || setup_fail "tests/math/math_check.c missing"
    [ -f "$ROOT/tests/math/math_check_y.c" ] || setup_fail "tests/math/math_check_y.c missing"
    for fn in log exp sin cos pow hypot; do
        [ -f "$ROOT/tests/math/$fn.vec" ] || setup_fail "tests/math/$fn.vec missing"
    done
    mkdir -p "$BUNDLE/tests/math" || setup_fail "cannot create $BUNDLE/tests/math"
    cp "$ROOT/tests/math/math_check.c" "$ROOT/tests/math/math_check_y.c" "$ROOT"/tests/math/*.vec "$BUNDLE/tests/math/" \
        || setup_fail "cannot copy tests/math"
    PACKED=$((PACKED + 1))
fi

# la/la_check and la/la_link (DESIGN.md 2.13.8, L-ja, L-jd): once-only cases. The bundle gets
# tests/la/gen_consts.sh (run on the host: it writes sea_consts.h from the bundle's include/),
# la_check.c and la_link.sh; la/la_link also gets its own compilation of
# tests/programs/la_mm_exact.sea as cases/la/la_mm_exact.s (or .packfail).
if selected "la/la_check" || selected "la/la_link"; then
    for f in gen_consts.sh la_check.c la_link.sh; do
        [ -f "$ROOT/tests/la/$f" ] || setup_fail "tests/la/$f missing"
    done
    mkdir -p "$BUNDLE/tests/la" "$BUNDLE/cases/la" || setup_fail "cannot create $BUNDLE/tests/la"
    cp "$ROOT/tests/la/gen_consts.sh" "$ROOT/tests/la/la_check.c" "$ROOT/tests/la/la_link.sh" "$BUNDLE/tests/la/" \
        || setup_fail "cannot copy tests/la"
    if selected "la/la_check"; then : > "$BUNDLE/tests/la/la_check.case"; PACKED=$((PACKED + 1)); fi
    if selected "la/la_link"; then
        [ -f "$ROOT/tests/programs/la_mm_exact.sea" ] || setup_fail "tests/programs/la_mm_exact.sea missing (la/la_link)"
        pack_sea la "$ROOT/tests/programs" la_mm_exact
        : > "$BUNDLE/tests/la/la_link.case"
        PACKED=$((PACKED + 1))
    fi
fi

if [ $PACKED -eq 0 ]; then echo "cross_pack.sh: no case selected (patterns: ${PATTERNS:-none}; compile-time error tests are not packed)" >&2; exit 2; fi
echo "packed: $PACKED cases ($BAD failed to compile)"
exit 0
