#!/bin/sh
# bench/micro.sh -- the phase-5 micro-benchmarks (docs/DESIGN.md 5.9). POSIX sh, macOS.
#
# usage: sh bench/micro.sh [--cross [-H HOST]]
#   (no option)  build and measure on this Mac; writes bench/results/micro-arm64-macos.tsv
#   --cross      compile on the Mac for x86_64-linux, pack, measure on the Linux host over ssh
#                (default $SEA_CROSS_HOST, else desktop; -H HOST); writes
#                bench/results/micro-x86_64-linux.tsv
#
# Environment:
#   SEA      the phase-5 driver (default: build/sea of this repository)
#   SEA4     the phase-4 driver, REQUIRED: build/sea of the phase-4 compiler (sea commit a6bfeb9)
#            built in a scratch directory that is not committed, e.g.
#              git archive a6bfeb9 | tar -x -C SCRATCH/sea4 && make -C SCRATCH/sea4 BAYSICK=..
#   BAYSICK  the Baysick checkout (default: the parent of this repository)
#   SEA4_SRC the phase-4 source tree (default: the parent of the directory of SEA4); its
#            Makefile.linux, include/ and runtime/x86_64_linux/ go into the cross bundle
#   BENCH_MIN_REPS, BENCH_MIN_SECONDS   forwarded to bench/micro/run.sh (5, 1.0)
#
# The C references are built with `xcrun cc -O2 -ffp-contract=off` (Mac) and `gcc -O2
# -ffp-contract=off` (host). Each run is validated before it is timed (micro/run.sh); a failed
# validation stops the script with exit status 1 and writes no results file.
# Exit status: 0 done, 1 validation failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SEA=${SEA:-$ROOT/build/sea}
BAYSICK=${BAYSICK:-$(cd "$ROOT/.." && pwd)}
HOST=${SEA_CROSS_HOST:-desktop}
CROSS=
while [ $# -gt 0 ]; do
    case "$1" in
    --cross) CROSS=1; shift ;;
    -H) [ $# -ge 2 ] || { echo "micro.sh: missing argument for '-H'" >&2; exit 2; }; HOST=$2; shift 2 ;;
    *) echo "micro.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
done
fail() { echo "micro.sh: $1" >&2; exit 2; }
[ -x "$SEA" ] || fail "driver '$SEA' not found; run 'make' first"
[ -n "${SEA4:-}" ] && [ -x "$SEA4" ] || fail "SEA4 (the phase-4 driver, see the header) is not set or not executable"
SEA4_SRC=${SEA4_SRC:-$(cd "$(dirname "$SEA4")/.." && pwd)}
SRC=$ROOT/bench/micro
OUT=$ROOT/bench/results
mkdir -p "$OUT" || fail "cannot create $OUT"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-micro.XXXXXX") || fail "cannot create a temporary directory"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
trap 'cleanup; exit 2' HUP INT TERM PIPE

if [ -z "$CROSS" ]; then
    [ "$(uname -sm)" = "Darwin arm64" ] || fail "run on an Apple-silicon Mac (or use --cross)"
    mkdir "$TMP/bin" || exit 2
    for b in lcg sor; do
        "$SEA" build "$SRC/$b.sea" -o "$TMP/bin/$b.p5" || fail "phase-5 compile of $b.sea failed"
        "$SEA4" build "$SRC/$b.sea" -o "$TMP/bin/$b.p4" || fail "phase-4 compile of $b.sea failed"
        xcrun cc -O2 -ffp-contract=off -o "$TMP/bin/$b.c" "$SRC/${b}_ref.c" -lm || fail "C reference $b failed"
    done
    sh "$SRC/run.sh" arm64-macos "$TMP/bin" >"$TMP/tsv"
    st=$?
    [ $st -eq 0 ] || exit $st
    cp "$TMP/tsv" "$OUT/micro-arm64-macos.tsv" || fail "cannot write the results file"
    cat "$OUT/micro-arm64-macos.tsv"
    exit 0
fi

# ---- cross: compile on the Mac, pack, one ssh call that builds and measures on the host
B=$TMP/bundle
mkdir -p "$B/progs" "$B/baysick/include" "$B/baysick/src/runtime_x86_64_linux" || exit 2
for v in sea5:"$ROOT" sea4:"$SEA4_SRC"; do
    d=${v%%:*}; s=${v#*:}
    mkdir -p "$B/$d/include" "$B/$d/runtime/x86_64_linux" || exit 2
    cp "$s/Makefile.linux" "$B/$d/" && cp "$s"/include/*.inc "$B/$d/include/" \
        && cp "$s"/runtime/x86_64_linux/*.s "$B/$d/runtime/x86_64_linux/" || fail "cannot pack $s"
done
cp "$BAYSICK/Makefile.linux" "$B/baysick/" && cp "$BAYSICK"/include/*.inc "$B/baysick/include/" \
    && cp "$BAYSICK"/src/runtime_x86_64_linux/*.s "$B/baysick/src/runtime_x86_64_linux/" \
    || fail "cannot pack Baysick's runtime"
for b in lcg sor; do
    "$SEA" build --target x86_64-linux -S -o "$B/progs/$b.p5.s" "$SRC/$b.sea" || fail "phase-5 compile of $b.sea failed"
    "$SEA4" build --target x86_64-linux -S -o "$B/progs/$b.p4.s" "$SRC/$b.sea" || fail "phase-4 compile of $b.sea failed"
    cp "$SRC/${b}_ref.c" "$B/progs/" || exit 2
done
cp "$SRC/run.sh" "$B/run.sh" || exit 2

# The remote build-and-measure script travels in the bundle as remote.sh. The only command
# given to ssh is the short one below (no single quote in it); the directory it unpacks into
# is a mktemp -d directory removed on exit, so nothing is left on the host.
cat >"$B/remote.sh" <<'REMOTE_END'
set -e
make -C baysick -f Makefile.linux all >&2
for v in sea5 sea4; do
    make -C $v -f Makefile.linux all BAYSICK=../baysick >&2
done
mkdir bin
for b in lcg sor; do
    for c in p5 p4; do
        v=sea5; if [ $c = p4 ]; then v=sea4; fi
        as --64 -o progs/$b.$c.o progs/$b.$c.s
        gcc -no-pie -o bin/$b.$c progs/$b.$c.o $v/build-x86_64-linux/libsea.a baysick/build-x86_64-linux/libbaysickrt.a -lm
    done
    gcc -O2 -ffp-contract=off -o bin/$b.c progs/${b}_ref.c -lm
done
set +e
sh run.sh x86_64-linux bin
exit $?
REMOTE_END
REMOTE='d=$(mktemp -d "${TMPDIR:-/tmp}/sea-micro.XXXXXX") || exit 2; trap "rm -rf $d" EXIT; tar -C $d -xf - || exit 2; cd $d || exit 2; sh remote.sh'
COPYFILE_DISABLE=1 tar --no-xattrs -C "$B" -cf - . | ssh -o BatchMode=yes -- "$HOST" "$REMOTE" >"$TMP/tsv"
st=$?
if [ $st -ne 0 ]; then
    echo "micro.sh: remote run ended with status $st" >&2
    [ $st -eq 1 ] && exit 1
    exit 2
fi
cp "$TMP/tsv" "$OUT/micro-x86_64-linux.tsv" || fail "cannot write the results file"
cat "$OUT/micro-x86_64-linux.tsv"
exit 0
