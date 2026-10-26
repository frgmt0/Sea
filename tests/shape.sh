#!/bin/sh
# tests/shape.sh -- the shape tests of phase 5 (docs/DESIGN.md 5.2 "Targets for phase 5", 6.2
# "Shape tests"). POSIX sh + awk, Mac only: both targets' -S text is generated here. Builds
# nothing: it uses the installed compiler build/sea (run make first).
#
# tests/shape/NAME.shape (written by hand from 5.2's targets; blank lines and # lines ignored):
#     program PATH            the Sea program, relative to sea/ (tests/accept/w5_stats.sea)
#     TARGET FUNC KEY=N ...   TARGET arm64 | x86_64; FUNC the function's name as its `func` record
#                             writes it (.main for the main program); max=N the largest number of
#                             instructions between the loop's `L<f>_<b>_top:` (`.L<f>_<b>_top:`)
#                             label and its closing branch (inclusive); cold=N exactly N branches
#                             to cold blocks (L<f>_e<k>); any other KEY is a mnemonic with its exact
#                             count in that range.
# Every line also requires no frame access in the range (arm64 `[sp`, `[x29`; x86_64 `(%rsp)`,
# `(%rbp)`) and no call (`bl`, `blr`, `call`, `callq`). The loop is identified by its properties
# (lead decision L-ar): from `--emit lir` the function number f (its position among the `func`
# records) and the block numbers b of the `loop` and `do` blocks of FUNC that contain no other
# loop; each candidate is measured in the -S text and the line passes when at least one meets every
# requirement; the block that did is printed. A failing line prints every candidate's measurement.
#
# usage: sh tests/shape.sh [-v] [PATTERN...]      PATTERN: a substring of the test name
#        (shape/NAME:TARGET:FUNC). -v also prints each candidate's measurement for passing lines.
# Environment: BUILD (default build/), SEA (default $BUILD/sea), SEA_COMPILE_TIMEOUT (120).
# Output as tests/run.sh: `FAIL shape/NAME:TARGET:FUNC: reason`, `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"

if [ ! -x "$SEA" ]; then
    echo "shape.sh: driver '$SEA' not found or not executable; run 'make' first" >&2
    exit 2
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-shape.XXXXXX") || exit 2
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
    wait "$_wpid" 2>/dev/null
    return $_st
}

# candidates FILE.lir FUNC : one line `f b` per innermost loop/do block of the function named FUNC
# (f = the function's 1-based position among the `func` records, b = the block number)
candidates() {
    awk -v want="$2" '
    $1 == "func" { f++; cur = ($2 == want); depth = 0; next }
    $1 == "endfunc" { cur = 0; next }
    !cur { next }
    $1 == "loop" || $1 == "do" {
        if (depth > 0) inner[depth] = 0          # the enclosing loop is not innermost
        depth++; blk[depth] = $2; inner[depth] = 1; next
    }
    $1 == "endloop" || $1 == "enddo" {
        if (depth > 0) { if (inner[depth]) print f, blk[depth]; depth-- }
        next
    }' "$1"
}

# measure FILE.s F B : one line `N=<instructions> frame=<n> calls=<n> cold=<n> mn=count ...` for the range
# from the top label L<F>_<B>_top to the last branch back to it, or `none` when there is no such range
# or another loop top label lies inside it
measure() {
    awk -v lab="L$2_$3_top" '
    { L[NR] = $0 }
    END {
        top = 0
        for (i = 1; i <= NR; i++) { s = L[i]; sub(/^[ \t]+/, "", s); sub(/^\./, "", s); if (s == lab ":") { top = i; break } }
        if (!top) { print "none"; exit }
        last = 0
        for (j = top + 1; j <= NR; j++) {
            n = split(L[j], w, /[ \t,]+/); t = w[n]; sub(/^\./, "", t)
            if (t == lab && L[j] !~ /^[ \t]*\.?[A-Za-z0-9_]+:/) last = j
        }
        if (!last) { print "none"; exit }
        cnt = 0; fr = 0; calls = 0; cold = 0; nm = 0
        for (j = top + 1; j <= last; j++) {
            s = L[j]
            if (s ~ /^[ \t]*$/ || s ~ /^[ \t]*\.?[A-Za-z0-9_]+:/ || s ~ /^[ \t]*(\/\/|#)/ || s ~ /^[ \t]*\./) continue
            n = split(s, w, /[ \t,]+/)
            k = 1; if (w[1] == "") k = 2
            mn = w[k]
            if (mn ~ /_top$/) { print "none"; exit }
            cnt++
            if (!(mn in H)) { order[++nm] = mn }
            H[mn]++
            if (s ~ /\[sp|\[x29|\(%rsp\)|\(%rbp\)/) fr++
            if (mn == "bl" || mn == "blr" || mn == "call" || mn == "callq") calls++
            t = w[n]; sub(/^\./, "", t)
            if (t ~ /^L[0-9]+_e[0-9]+$/ && mn != "bl" && mn != "call" && mn != "callq") cold++
        }
        out = "N=" cnt " frame=" fr " calls=" calls " cold=" cold
        for (q = 1; q <= nm; q++) out = out " " order[q] "=" H[order[q]]
        print out
    }' "$1"
}

# check MEASUREMENT SPEC... : prints the reasons the measurement does not meet the spec (nothing if it does)
check() {
    _m=$1; shift
    awk -v m="$_m" -v spec="$*" '
    BEGIN {
        n = split(m, a, " ")
        for (i = 1; i <= n; i++) { p = index(a[i], "="); M[substr(a[i], 1, p - 1)] = substr(a[i], p + 1) }
        ns = split(spec, b, " ")
        for (i = 1; i <= ns; i++) {
            p = index(b[i], "="); key = substr(b[i], 1, p - 1); val = substr(b[i], p + 1) + 0
            if (key == "max") { if (M["N"] + 0 > val) printf "%d instructions > max %d; ", M["N"], val }
            else if (key == "cold") { if (M["cold"] + 0 != val) printf "%d cold branches, expected %d; ", M["cold"], val }
            else { have = (key in M) ? M[key] + 0 : 0; if (have != val) printf "%s x%d, expected x%d; ", key, have, val }
        }
        if (M["frame"] + 0 != 0) printf "%d frame accesses; ", M["frame"]
        if (M["calls"] + 0 != 0) printf "%d calls; ", M["calls"]
    }'
}

# compile PROGRAM_DIR ARGS... : sea build in the program directory, bare file name (as tests/run.sh)
for sf in "$ROOT"/tests/shape/*.shape; do
    [ -e "$sf" ] || continue
    nm=$(basename "$sf" .shape)
    prog=$(awk '$1 == "program" { print $2; exit }' "$sf")
    # lines of this file selected by the pattern?
    any=0
    while read -r tgt fn spec; do
        case $tgt in arm64|x86_64) selected "shape/$nm:$tgt:$fn" && any=1 ;; esac
    done < "$sf"
    [ $any = 1 ] || continue
    if [ -z "$prog" ] || [ ! -f "$ROOT/$prog" ]; then fail "shape/$nm" "program '$prog' not found"; continue; fi
    pdir=$ROOT/$(dirname "$prog"); pfile=$(basename "$prog")
    w=$TMP/$nm; mkdir -p "$w"
    ok=1
    run_limited "$CTIMEOUT" "$pdir" "$SEA" build --emit lir "$pfile" >"$w/sea.lir" 2>"$w/c.err"
    [ $? -eq 0 ] || { fail "shape/$nm" "--emit lir failed: $(head -3 "$w/c.err" | tr '\n' ' ')"; ok=0; }
    if [ $ok = 1 ]; then
        run_limited "$CTIMEOUT" "$pdir" "$SEA" build -S -o "$w/arm64.s" "$pfile" >/dev/null 2>"$w/c.err"
        [ $? -eq 0 ] && [ -s "$w/arm64.s" ] || { fail "shape/$nm" "arm64 -S failed: $(head -3 "$w/c.err" | tr '\n' ' ')"; ok=0; }
    fi
    if [ $ok = 1 ]; then
        run_limited "$CTIMEOUT" "$pdir" "$SEA" build --target x86_64-linux -S -o "$w/x86_64.s" "$pfile" >/dev/null 2>"$w/c.err"
        [ $? -eq 0 ] && [ -s "$w/x86_64.s" ] || { fail "shape/$nm" "x86_64 -S failed: $(head -3 "$w/c.err" | tr '\n' ' ')"; ok=0; }
    fi
    [ $ok = 1 ] || continue

    while read -r tgt fn spec; do
        case $tgt in arm64|x86_64) ;; *) continue ;; esac
        name=shape/$nm:$tgt:$fn
        selected "$name" || continue
        cands=$(candidates "$w/sea.lir" "$fn")
        if [ -z "$cands" ]; then fail "$name" "no function '$fn' with an innermost loop in --emit lir"; continue; fi
        won=
        report=
        while read -r f b; do
            m=$(measure "$w/$tgt.s" "$f" "$b")
            if [ "$m" = none ]; then report="$report
    candidate L${f}_$b: no top label / closing branch (or another loop inside) in the $tgt -S text"; continue; fi
            why=$(check "$m" $spec)
            if [ -z "$why" ]; then
                if [ -z "$won" ]; then won="L${f}_$b ($(echo "$m" | sed 's/ .*//'))"; fi
                report="$report
    candidate L${f}_$b: ok: $m"
            else
                report="$report
    candidate L${f}_$b: $why
        measured: $m"
            fi
        done <<EOF
$cands
EOF
        if [ -n "$won" ]; then
            pass
            echo "ok   $name: $won"
            [ "$VERBOSE" = 1 ] && echo "$report" | sed '/^$/d'
        else
            fail "$name" "no innermost loop of '$fn' meets: $spec$report"
        fi
    done < "$sf"
done

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
