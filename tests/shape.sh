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
# (lead decision L-ar): from the target's `--emit lir` the function number f (its position among the `func`
# records) and the block numbers b of the `loop` and `do` blocks of FUNC that contain no other
# loop (the LIR of the target: `--emit lir` for arm64, `--target x86_64-linux --emit lir` for x86_64, since
# seavec writes different blocks per target); each candidate is measured in the -S text and the line passes when at least one meets every
# requirement; the block that did is printed. A failing line prints every candidate's measurement.
#
# The vector check (7f; DESIGN.md 2.12.10, Decision 108, lead decision L-fl) adds the line kind
#     vector TARGET FUNC FIRST LAST [OP ...]
# TARGET arm64 | x86_64 (arm64-macos, x86_64-linux accepted), FUNC as above, FIRST..LAST a line
# range of the program's file. From the target's `--emit lir`, a vector candidate is a `loop` block
# of FUNC containing no other loop whose body holds a lane-computing instruction of the vector set
# (`x`/`y` `add sub mul div min max sqrt neg abs cmp sel`; its lane count, 2 for `x` and 4 for `y`);
# it is from the line range when one of its own records has a site F:L of the program's file
# (the F of the first `func` record's pos) with FIRST <= L <= LAST, or else the nearest record with
# a site before its `loop` record in FUNC has one (a vector body holds no failing instruction, so
# no site: the statement's checks, run before the loop, carry its line; inlined code keeps its
# callee's lines). Its -S range (as above) must hold, for every distinct lane-computing opcode of the
# block, at least one instruction of that opcode's form: arm64 `.2d`/`.16b` operands (fadd fsub fmul
# fdiv fsqrt fneg fabs; fcmgt for min/max; fcmgt/fcmge/fcmeq for cmp; bsl/bif/bit for sel); x86_64
# 2 lanes the SSE2 forms (addpd subpd mulpd divpd sqrtpd xorpd andpd, cmpltpd/cmppd for min/max,
# cmppd for cmp, andnpd for sel); 4 lanes the AVX2 forms (vaddpd …, vcmppd, vblendvpd). OP ... (Decision
# 119), each one of add sub mul div min max sqrt neg abs cmp sel, are the lane ops the loop must
# hold: a candidate qualifies only when its LIR body holds every listed op (and then, as for every
# op, the -S form of each); none listed, any candidate may qualify. The line
# passes when one candidate with 2 lanes (on x86_64 also one with 4 lanes, both loops present,
# L-fl) meets every requirement. No frame-access or call condition applies (a vector body calls the
# vector elementary functions). Programs are taken from tests/accept/ and ports/ alike (PATH).
#
# usage: sh tests/shape.sh [-v] [PATTERN...]      PATTERN: a substring of the test name
#        (shape/NAME:TARGET:FUNC, shape/NAME:vector:TARGET:FUNC:FIRST-LAST[:OP+OP...]). -v also prints each
#        candidate's measurement for passing lines.
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

# vtarget NAME : arm64 or x86_64 for a vector line's target name, nothing for an unknown one
vtarget() {
    case $1 in arm64|arm64-macos) echo arm64 ;; x86_64|x86_64-linux) echo x86_64 ;; esac
}

# vcands FILE.lir FUNC FIRST LAST : one line `f b lanes ops site inrange` per vector candidate of FUNC
# (a `loop` holding no other loop/do with a lane-computing instruction): lanes 2 or 4, ops the
# distinct lane-computing opcodes without their x/y prefix (comma-separated), site the F:L that
# decided the line range (`-` if none), inrange 1 when that L lies in FIRST..LAST of the program's file
vcands() {
    awk -v want="$2" -v lo="$3" -v hi="$4" '
    function L(s) { return substr(s, index(s, ":") + 1) + 0 }
    function F(s) { return substr(s, 1, index(s, ":") - 1) }
    $1 == "func" { f++; if (pf == "") pf = F($4); cur = ($2 == want); depth = 0; last = ""; next }
    $1 == "endfunc" { cur = 0; next }
    !cur { next }
    $1 == "loop" || $1 == "do" {
        if (depth > 0) inner[depth] = 0
        depth++; blk[depth] = $2; kind[depth] = $1; inner[depth] = 1
        pre[depth] = last; own[depth] = ""; ln[depth] = 0; ops[depth] = ""; delete seen
        next
    }
    $1 == "endloop" || $1 == "enddo" {
        if (depth > 0) {
            if (inner[depth] && kind[depth] == "loop" && ops[depth] != "") {
                s = own[depth]; if (s == "") s = pre[depth]
                ok = (s != "" && F(s) == pf && L(s) >= lo + 0 && L(s) <= hi + 0)
                print f, blk[depth], ln[depth], substr(ops[depth], 2), (s == "" ? "-" : s), ok
            }
            depth--
        }
        next
    }
    {
        site = ""
        for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+:[0-9]+$/) site = $i
        if (site != "") {
            last = site
            # a site of the block itself decides when it lies in the range (or is the first one)
            if (depth > 0 && F(site) == pf && (own[depth] == "" || (L(site) >= lo + 0 && L(site) <= hi + 0))) own[depth] = site
        }
    }
    depth > 0 && $1 ~ /^[xy](add|sub|mul|div|min|max|sqrt|neg|abs|cmp|sel)$/ {
        op = substr($1, 2)
        ln[depth] = (substr($1, 1, 1) == "y") ? 4 : 2
        if (!(op in seen)) { seen[op] = 1; ops[depth] = ops[depth] "," op }
    }' "$1"
}

# vmeasure FILE.s F B TARGET LANES OPS : for the range of measure (top label L<F>_<B>_top to its last
# closing branch, no other top label inside) one line `op=count ...`, the number of instructions of
# each lane-computing opcode's form for that target and lane count (see the header), or `none`
vmeasure() {
    awk -v lab="L$2_$3_top" -v tgt="$4" -v lanes="$5" -v ops="$6" '
    BEGIN {
        if (tgt == "arm64") {
            M["add"] = "fadd"; M["sub"] = "fsub"; M["mul"] = "fmul"; M["div"] = "fdiv"
            M["sqrt"] = "fsqrt"; M["neg"] = "fneg"; M["abs"] = "fabs"; M["min"] = "fcmgt"
            M["max"] = "fcmgt"; M["cmp"] = "fcmgt fcmge fcmeq"; M["sel"] = "bsl bif bit"
        } else if (lanes == 2) {
            M["add"] = "addpd"; M["sub"] = "subpd"; M["mul"] = "mulpd"; M["div"] = "divpd"
            M["sqrt"] = "sqrtpd"; M["neg"] = "xorpd"; M["abs"] = "andpd"; M["min"] = "cmpltpd cmppd"
            M["max"] = "cmpltpd cmppd"; M["cmp"] = "cmppd"; M["sel"] = "andnpd"
        } else {
            M["add"] = "vaddpd"; M["sub"] = "vsubpd"; M["mul"] = "vmulpd"; M["div"] = "vdivpd"
            M["sqrt"] = "vsqrtpd"; M["neg"] = "vxorpd"; M["abs"] = "vandpd"; M["min"] = "vcmppd"
            M["max"] = "vcmppd"; M["cmp"] = "vcmppd"; M["sel"] = "vblendvpd"
        }
    }
    { S[NR] = $0 }
    END {
        top = 0
        for (i = 1; i <= NR; i++) { s = S[i]; sub(/^[ \t]+/, "", s); sub(/^\./, "", s); if (s == lab ":") { top = i; break } }
        if (!top) { print "none"; exit }
        last = 0
        for (j = top + 1; j <= NR; j++) {
            n = split(S[j], w, /[ \t,]+/); t = w[n]; sub(/^\./, "", t)
            if (t == lab && S[j] !~ /^[ \t]*\.?[A-Za-z0-9_]+:/) last = j
        }
        if (!last) { print "none"; exit }
        for (j = top + 1; j <= last; j++) {
            s = S[j]
            # the top label of another loop inside the range: not innermost code (tested before
            # label lines are skipped)
            if (s ~ /^[ \t]*\.?L[0-9]+_[0-9]+_top:/) { print "none"; exit }
            if (s ~ /^[ \t]*$/ || s ~ /^[ \t]*\.?[A-Za-z0-9_]+:/ || s ~ /^[ \t]*(\/\/|#)/ || s ~ /^[ \t]*\./) continue
            n = split(s, w, /[ \t,]+/); k = 1; if (w[1] == "") k = 2
            mn = w[k]
            # the register form of the lane count: arm64 .2d/.16b operands, x86_64 %xmm (SSE2) or %ymm (AVX2)
            if (tgt == "arm64") { if (s !~ /v[0-9]+\.(2d|16b)/) continue }
            else if (lanes == 2) { if (s !~ /%xmm/ || mn ~ /^v/) continue }
            else { if (s !~ /%ymm/) continue }
            H[mn]++
        }
        no = split(ops, o, ",")
        out = ""
        for (q = 1; q <= no; q++) {
            c = 0; nf = split(M[o[q]], forms, " ")
            for (r = 1; r <= nf; r++) c += H[forms[r]]
            out = out (q > 1 ? " " : "") o[q] "=" c
        }
        print out
    }' "$1"
}

# vcheck MEASUREMENT : the opcodes with no instruction of their form (nothing if every one has one);
# an empty measurement (vmeasure failed) is itself a reason
vcheck() {
    if [ -z "$1" ]; then echo "no measurement of the -S range; "; return; fi
    echo "$1" | awk '{ for (i = 1; i <= NF; i++) { p = index($i, "="); if (substr($i, p + 1) + 0 == 0) printf "%s has no instruction; ", substr($i, 1, p - 1) } }'
}

# compile PROGRAM_DIR ARGS... : sea build in the program directory, bare file name (as tests/run.sh)
for sf in "$ROOT"/tests/shape/*.shape; do
    [ -e "$sf" ] || continue
    nm=$(basename "$sf" .shape)
    prog=$(awk '$1 == "program" { print $2; exit }' "$sf")
    # lines of this file selected by the pattern?
    any=0
    while read -r tgt fn spec; do
        case $tgt in
            arm64|x86_64) selected "shape/$nm:$tgt:$fn" && any=1 ;;
            vector) set -- $spec; _vn="shape/$nm:vector:$fn:${1:-}:${2:-}-${3:-}"; if [ $# -gt 3 ]; then shift 3; _vn="$_vn:$(echo "$@" | tr " " "+")"; fi; selected "$_vn" && any=1 ;;
        esac
    done < "$sf"
    [ $any = 1 ] || continue
    if [ -z "$prog" ] || [ ! -f "$ROOT/$prog" ]; then fail "shape/$nm" "program '$prog' not found"; continue; fi
    pdir=$ROOT/$(dirname "$prog"); pfile=$(basename "$prog")
    w=$TMP/$nm; mkdir -p "$w"
    ok=1
    run_limited "$CTIMEOUT" "$pdir" "$SEA" build --emit lir "$pfile" >"$w/sea.lir" 2>"$w/c.err"
    [ $? -eq 0 ] || { fail "shape/$nm" "--emit lir failed: $(head -3 "$w/c.err" | tr '\n' ' ')"; ok=0; }
    if [ $ok = 1 ]; then
        run_limited "$CTIMEOUT" "$pdir" "$SEA" build --target x86_64-linux --emit lir "$pfile" >"$w/x86_64.lir" 2>"$w/c.err"
        [ $? -eq 0 ] || { fail "shape/$nm" "x86_64 --emit lir failed: $(head -3 "$w/c.err" | tr '\n' ' ')"; ok=0; }
    fi
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
        lf=$w/sea.lir; [ "$tgt" = x86_64 ] && lf=$w/x86_64.lir
        cands=$(candidates "$lf" "$fn")
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

    # the vector lines (7f, Decision 108, L-fl; the required lane ops, Decision 119)
    while read -r kw tgt fn lo hi req; do
        [ "$kw" = vector ] || continue
        t=$(vtarget "$tgt")
        name=shape/$nm:vector:$tgt:$fn:$lo-$hi
        [ -n "$req" ] && name="$name:$(echo $req | tr ' ' '+')"
        selected "$name" || continue
        case $lo$hi in *[!0-9]*|'') fail "$name" "bad line range '$lo $hi'"; continue ;; esac
        if [ -z "$t" ]; then fail "$name" "bad vector line (vector TARGET FUNC FIRST LAST [OP ...])"; continue; fi
        bad=
        for op in $req; do
            case " add sub mul div min max sqrt neg abs cmp sel " in *" $op "*) ;; *) bad="$bad $op" ;; esac
        done
        if [ -n "$bad" ]; then fail "$name" "unknown lane op(s):$bad"; continue; fi
        lf=$w/sea.lir; [ "$t" = x86_64 ] && lf=$w/x86_64.lir
        cands=$(vcands "$lf" "$fn" "$lo" "$hi")
        if [ -z "$cands" ]; then fail "$name" "no innermost vector loop of '$fn' in the $t --emit lir"; continue; fi
        won2=
        won4=
        report=
        while read -r f b ln ops site inr; do
            if [ "$inr" != 1 ]; then report="$report
    candidate L${f}_$b ($ln lanes, $ops): site $site outside lines $lo-$hi"; continue; fi
            lacks=
            for op in $req; do
                case ",$ops," in *",$op,"*) ;; *) lacks="$lacks $op" ;; esac
            done
            if [ -n "$lacks" ]; then report="$report
    candidate L${f}_$b ($ln lanes, site $site, $ops): does not qualify, lacks:$lacks"; continue; fi
            m=$(vmeasure "$w/$t.s" "$f" "$b" "$t" "$ln" "$ops")
            if [ "$m" = none ]; then report="$report
    candidate L${f}_$b ($ln lanes, site $site, $ops): no top label / closing branch (or another loop inside) in the $t -S text"; continue; fi
            why=$(vcheck "$m")
            if [ -z "$why" ]; then
                if [ "$ln" = 2 ] && [ -z "$won2" ]; then won2="L${f}_$b (2 lanes, site $site: $m)"; fi
                if [ "$ln" = 4 ] && [ -z "$won4" ]; then won4="L${f}_$b (4 lanes, site $site: $m)"; fi
                report="$report
    candidate L${f}_$b ($ln lanes, site $site, $ops): qualifies: ok: $m"
            else
                report="$report
    candidate L${f}_$b ($ln lanes, site $site, $ops): qualifies, but: $why
        measured: $m"
            fi
        done <<EOF
$cands
EOF
        missing=
        [ -n "$won2" ] || missing="a 2-lane loop"
        if [ "$t" = x86_64 ] && [ -z "$won4" ]; then missing="${missing:+$missing and }a 4-lane loop"; fi
        if [ -z "$missing" ]; then
            pass
            if [ "$t" = x86_64 ]; then echo "ok   $name: $won4; $won2"; else echo "ok   $name: $won2"; fi
            [ "$VERBOSE" = 1 ] && echo "$report" | sed '/^$/d'
        else
            fail "$name" "found no $missing of '$fn' from lines $lo-$hi${req:+ holding $req} with its vector instructions in the -S text$report"
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
