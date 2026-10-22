#!/bin/sh
# tests/protocol.sh -- the pass-protocol tests (docs/DESIGN.md 2.2 step 6, 6.2). POSIX sh.
# Builds nothing: it uses the pass executables and the driver of build/ (run make first).
#
# 1. Truncated input. Each built pass is run on an input that has the header records but no
#    final #end (pass 1: on standard input; the others: as sea.ast (seaname), sea.res (seacheck),
#    sea.hir1, sea.hir, sea.lir1, sea.lir in the working directory). It must exit with status 11
#    (SEA_EXIT_PASS_INTERNAL) and write exactly the text of the error record TRUNCATED of
#    errors.inc prefixed by the pass name (`<pass>: <text>`), followed by LF, to standard error, and nothing to standard output.
#    A pass whose executable is not built is a FAILURE ("not built"), not a skip.
# 2. The driver rejects a pass output without #end. With fake passes (shell scripts in a
#    scratch installation directory, SEA_HOME) one pass at a time writes its output file without
#    the final #end (or empty, or absent) and exits 0: the driver (build/sea) must stop with
#    status 4 and a message `sea: internal error: <pass> wrote no complete <file> (no final
#    #end)` naming the pass, and run no later pass. A complete output (with #end) lets the
#    chain go on.
#
# usage: sh tests/protocol.sh [-v] [PATTERN...]   Environment: BUILD (default build/),
#        SEA_TEST_TIMEOUT (10). Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-proto.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
: > "$TMP/empty"

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

run_limited() { # run_limited SECONDS INFILE WORKDIR CMD...
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

# ---- 1. truncated input ---------------------------------------------------------------
# The expected message and status come from the contract file.
INC=$ROOT/include/errors.inc
TRUNC_TEXT=$(awk '$1 == "\\m" && $3 == "TRUNCATED," { s = $0; a = index(s, "\""); b = 0
    for (i = length(s); i > a; i--) if (substr(s, i, 1) == "\"") { b = i; break }
    print substr(s, a + 1, b - a - 1); exit }' "$INC")
PASS_INTERNAL=$(awk '$1 == ".equiv" && $2 == "SEA_EXIT_PASS_INTERNAL," { print $3; exit }' "$INC")
if [ -z "$TRUNC_TEXT" ] || [ -z "$PASS_INTERNAL" ]; then
    echo "protocol.sh: TRUNCATED or SEA_EXIT_PASS_INTERNAL not found in $INC" >&2
    exit 2
fi
HEADER='#sea 1
#target arm64-macos
#file t.sea'

truncated() { # truncated PASS INPUTNAME(stdin|file name) 
    _p=$1; _in=$2
    name=protocol/truncated/$_p
    selected "$name" || return 0
    if [ ! -x "$BUILD/$_p" ]; then fail "$name" "pass '$_p' not built ($BUILD/$_p)"; return 0; fi
    w=$(mktemp -d "$TMP/w.XXXXXX") || exit 2
    if [ "$_in" = stdin ]; then
        printf '%s\n|\n' "$HEADER" > "$w/stdin"
    else
        printf '%s\n' "$HEADER" > "$w/$_in"
        : > "$w/stdin"
    fi
    run_limited "$TIMEOUT" "$w/stdin" "$w" "$BUILD/$_p" >"$TMP/p.out" 2>"$TMP/p.err"
    st=$?
    ok=1
    [ "$st" = "$PASS_INTERNAL" ] || { fail "$name" "exit status $st, expected $PASS_INTERNAL"; ok=0; }
    printf "%s: %s\n" "$_p" "$TRUNC_TEXT" > "$TMP/trunc.err"
    [ $ok = 1 ] && { same "$TMP/trunc.err" "$TMP/p.err" "stderr" "$name" || ok=0; }
    [ $ok = 1 ] && { same "$TMP/empty" "$TMP/p.out" "stdout" "$name" || ok=0; }
    rm -rf "$w"
    [ $ok = 1 ] && pass
}
truncated seaparse stdin
truncated seaname sea.ast
truncated seacheck sea.res
truncated seaexpand sea.hir1
truncated sealower sea.hir
truncated seaopt sea.lir1
truncated seagen_a64 sea.lir

# ---- 2. the driver rejects an output without #end -----------------------------------------
DRIVER=$BUILD/sea
SRC=$TMP/prog.sea
printf 'let x = 1\n' > "$SRC"

# fake_home DIR BADPASS MODE : an installation directory whose pass executables are shell
# scripts that log their name; BADPASS writes its output as MODE says (noend, empty, absent),
# the others write a complete output.
fake_home() {
    _h=$1; _bad=$2; _mode=$3
    mkdir -p "$_h"
    cp "$ROOT/include/errors.inc" "$ROOT/include/limits.inc" "$_h/"
    : > "$_h/std.sea"
    for spec in seaparse:sea.ast seaname:sea.res seacheck:sea.hir1 seaexpand:sea.hir sealower:sea.lir1 seaopt:sea.lir seagen_a64:sea.s; do
        _p=${spec%%:*}; _f=${spec##*:}
        {
            echo '#!/bin/sh'
            echo "echo $_p >> \"\$SEA_LOG\""
            if [ "$_p" = seaparse ]; then echo 'cat > /dev/null'; fi
            if [ "$_p" = "$_bad" ]; then
                case $_mode in
                noend) echo "printf '#sea 1\\n#target arm64-macos\\n' > $_f" ;;
                nolf)  echo "printf '#sea 1\\nx#end\\n' > $_f" ;;
                empty) echo ": > $_f" ;;
                absent) echo 'true' ;;
                esac
            elif [ "$_f" = sea.s ]; then
                echo "printf '\\t.text\\n' > $_f"
            else
                echo "printf '#sea 1\\n#target arm64-macos\\n#end\\n' > $_f"
            fi
            echo 'exit 0'
        } > "$_h/$_p"
        chmod +x "$_h/$_p"
    done
}

order="seaparse seaname seacheck seaexpand sealower seaopt seagen_a64"
file_of() { case $1 in seaparse) echo sea.ast ;; seaname) echo sea.res ;; seacheck) echo sea.hir1 ;; seaexpand) echo sea.hir ;; sealower) echo sea.lir1 ;; seaopt) echo sea.lir ;; esac; }

if [ ! -x "$DRIVER" ]; then
    fail "protocol/driver" "driver '$DRIVER' not built (run make)"
else
    for bad in seaparse seaname seacheck seaexpand sealower seaopt; do
        for mode in noend nolf empty absent; do
            name=protocol/driver-rejects/$bad-$mode
            selected "$name" || continue
            home=$TMP/home; rm -rf "$home"; fake_home "$home" "$bad" "$mode"
            SEA_LOG=$TMP/log; export SEA_LOG; : > "$SEA_LOG"
            (cd "$TMP" && SEA_HOME=$home "$DRIVER" build -S -o "$TMP/out.s" prog.sea) >"$TMP/d.out" 2>"$TMP/d.err"
            st=$?
            want="sea: internal error: $bad wrote no complete $(file_of "$bad") (no final #end)"
            # the passes that ran: up to and including BAD, in order
            ran=; for p in $order; do ran="$ran $p"; [ "$p" = "$bad" ] && break; done
            ok=1
            [ "$st" = 4 ] || { fail "$name" "driver exit status $st, expected 4"; ok=0; }
            [ $ok = 1 ] && [ "$(tr '\n' ' ' < "$TMP/log" | sed 's/ $//')" != "$(echo $ran)" ] && { fail "$name" "passes run: $(tr '\n' ' ' < "$TMP/log"), expected:$ran"; ok=0; }
            if [ $ok = 1 ]; then printf '%s\n' "$want" > "$TMP/want"; same "$TMP/want" "$TMP/d.err" "driver stderr" "$name" || ok=0; fi
            [ $ok = 1 ] && [ -e "$TMP/out.s" ] && { fail "$name" "an output file was written"; ok=0; }
            [ $ok = 1 ] && pass
            rm -f "$TMP/out.s"
        done
    done
    # control: complete outputs let the whole chain run and -S deliver sea.s
    name=protocol/driver-accepts/complete
    if selected "$name"; then
        home=$TMP/home; rm -rf "$home"; fake_home "$home" none noend
        SEA_LOG=$TMP/log; export SEA_LOG; : > "$SEA_LOG"
        (cd "$TMP" && SEA_HOME=$home "$DRIVER" build -S -o "$TMP/out.s" prog.sea) >"$TMP/d.out" 2>"$TMP/d.err"
        st=$?
        ok=1
        [ "$st" = 0 ] || { fail "$name" "driver exit status $st, expected 0: $(head -2 "$TMP/d.err" | tr '\n' ' ')"; ok=0; }
        [ $ok = 1 ] && [ "$(tr '\n' ' ' < "$TMP/log" | sed 's/ $//')" != "$(echo $order)" ] && { fail "$name" "passes run: $(tr '\n' ' ' < "$TMP/log")"; ok=0; }
        [ $ok = 1 ] && [ ! -s "$TMP/out.s" ] && { fail "$name" "no output written"; ok=0; }
        [ $ok = 1 ] && pass
        rm -f "$TMP/out.s"
    fi
fi

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
