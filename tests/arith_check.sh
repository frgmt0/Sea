#!/bin/sh
# tests/arith_check.sh -- the exact-arithmetic modules against their vectors (DESIGN.md 2.8, 6.2).
#
#   sh tests/arith_check.sh [-v] [-d vectordir]
#
# Builds three small Baysick programs, each a harness of tests/harness/ followed by the shared
# modules of passes/lib/ it tests (in the line order of DESIGN.md 2.6.3) and `99999 END`:
#   limb_h   + limb.bas                 reads limb.txt
#   f64emu_h + limb.bas + f64emu.bas    reads f64emu.txt
#   fltlit_h + limb.bas + fltlit.bas    reads float.txt
# compiles them with Baysick's compiler ($BAYSICK/build/baysick, BAYSICK defaulting to the
# parent repository) and runs each with its vector file (tests/vectors/, or -d vectordir) on
# standard input. A harness prints every vector with its results recomputed by the modules; the
# output must equal the vector file line for line, the program must exit with status 0 and
# write nothing on standard error. The vector files are made by tests/vectors/float.py and
# tests/vectors/f64emu.py (`uv run python ...`) from exact definitions, never from this output.
# -v prints every mismatching line (default: the first 10 per file). Exit status 0 when all
# vectors pass, 1 otherwise. Works in a temporary directory and leaves no files behind.

set -u
verbose=0
here=$(cd "$(dirname "$0")" && pwd)
sea=$(dirname "$here")
vec=$here/vectors
while [ $# -gt 0 ]; do
    case $1 in
        -v) verbose=1 ;;
        -d) shift; vec=$(cd "$1" && pwd) || exit 1 ;;
        *) echo "usage: sh tests/arith_check.sh [-v] [-d vectordir]" >&2; exit 2 ;;
    esac
    shift
done
BAYSICK=${BAYSICK:-$sea/..}
bsk=$BAYSICK/build/baysick
if [ ! -x "$bsk" ]; then
    echo "arith_check: $bsk not found (build Baysick first, or set BAYSICK)" >&2
    exit 1
fi
lib=$sea/passes/lib
work=$(mktemp -d "${TMPDIR:-/tmp}/sea_arith.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT INT TERM

fail=0
total=0
# check NAME VECTORS MODULE...
check() {
    name=$1
    vname=$2
    vfile=$vec/$2
    shift 2
    src=$work/$name.bas
    cat "$here/harness/$name.bas" > "$src"
    for m in "$@"; do
        cat "$lib/$m.bas" >> "$src"
    done
    echo "99999 END" >> "$src"
    if ! "$bsk" "$src" -o "$work/$name" > "$work/$name.cc" 2>&1; then
        echo "FAIL $name: does not compile"
        cat "$work/$name.cc"
        fail=1
        return
    fi
    if [ ! -f "$vfile" ]; then
        echo "FAIL $name: no vector file $vfile"
        fail=1
        return
    fi
    "$work/$name" < "$vfile" > "$work/$name.out" 2> "$work/$name.err"
    st=$?
    n=$(wc -l < "$vfile" | tr -d ' ')
    total=$((total + n))
    bad=$(awk -v v="$verbose" -v name="$name" '
        NR == FNR { want[FNR] = $0; nw = FNR; next }
        { got[FNR] = $0; ng = FNR }
        END {
            bad = 0
            m = (nw > ng) ? nw : ng
            for (i = 1; i <= m; i++) {
                if (want[i] == got[i] && i <= nw && i <= ng) continue
                bad++
                if (v || bad <= 10) {
                    printf "  %s line %d\n    expected: %s\n    got:      %s\n", name, i,
                        substr(want[i], 1, 200), substr(got[i], 1, 200) > "/dev/stderr"
                }
            }
            print bad
        }' "$vfile" "$work/$name.out")
    if [ "$st" -ne 0 ] || [ -s "$work/$name.err" ]; then
        echo "FAIL $name: exit status $st"
        head -5 "$work/$name.err"
        fail=1
    fi
    if [ "$bad" -ne 0 ]; then
        echo "FAIL $name: $bad of $n vectors differ ($vname)"
        fail=1
    else
        echo "ok   $name: $n vectors ($vname)"
    fi
}

check limb_h limb.txt limb
check f64emu_h f64emu.txt limb f64emu
check fltlit_h float.txt limb fltlit

if [ "$fail" -ne 0 ]; then
    echo "arith_check: FAILED"
    exit 1
fi
echo "arith_check: all $total vectors pass"
exit 0
