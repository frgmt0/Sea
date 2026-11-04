#!/bin/sh
# tests/cross.sh -- compile on the Mac, run on a Linux x86_64 host (POSIX sh; docs/DESIGN.md 6.6.1).
#
# usage: sh tests/cross.sh [-v] [-H HOST] [PATTERN...]
#   -v        show diffs for failures
#   -H HOST   ssh destination (default: $SEA_CROSS_HOST, else "desktop"); key authentication
#             is required (ssh -o BatchMode=yes)
#   PATTERN   only cases whose name contains one of the patterns (literally)
#
# Environment:
#   SEA, BAYSICK, LIRCHK  used by cross_pack.sh (LIRCHK: the sea.lir validator, default
#                         build/tools/lirchk beside the driver; every x86_64 sea.lir is checked)
#   SEA_TEST_TIMEOUT      seconds per program, forwarded (default 10)
#   SEA_KERNELS           if set, forwarded to the remote runs, which then use that one variant
#                         (letters, digits, underscores); if unset, every case runs under both
#                         x86_64 variants, the default (avx2) and sse2 (Decision 104), and the
#                         summary reports the counts of each; the host must offer AVX2
#   SEA_CROSS_HOST        default host
#
# Packs a bundle (tests/cross_pack.sh) into a local temp directory, streams it as tar into ONE
# ssh call that unpacks it into a remote mktemp -d directory (removed on exit; HUP/INT/TERM/PIPE
# clean up and exit 2) and runs tests/cross_run.sh there (the bundle in D/bundle, the deferred
# runs kept in D/keep: cross_run.sh -k D/keep).
#
# The output of cross_run.sh is passed through as it is: `FAIL <name>: ...` (first variant) and
# `FAIL <name> [sse2]: ...` lines (with -v, their diffs), `DEFER ports/NAME (VARIANT)` lines, then
# one `variant <v>: passed: P  failed: F` line per variant, the line of the once-only cases (build
# failures, rt/, math/math_check) and the totals `passed: P  failed: F, D deferred`.
#
# The return path (DESIGN.md 2.13.9, Decision 127): after cross_run.sh ends with status 0 or 1 the
# remote script writes one line `#sea-cross-files N` and then `tar -C D/keep -cf - . | base64`, N
# being the byte count of that base64 text (N = 0 and nothing after the marker when no run was
# kept); nothing follows. The tar holds every file of D/keep, so each deferred run's kept SVG
# (ports/NAME.VARIANT.svg, phase 9, DESIGN.md 2.14.9 "Cross") comes back beside its .out and .json. An awk splitter copies every line before the marker to the standard output
# and writes the rest to $TMP/kept.b64, whose length must be N (else a setup error). When the host
# deferred a run or returned files, tests/cross_accept.sh judges the kept runs on the Mac (it prints
# `PASS`/`FAIL ports/NAME (VARIANT)` lines and its own `passed:` line). The last line is
#     host: P passed, F failed, D deferred; Mac: P2 passed, F2 failed
# and D must equal P2 + F2 (else a setup error).
#
# Exit status: 0 when the host reports no failure and cross_accept.sh none, 1 when either has a
# failure, 2 on a setup error of either (packing fails, ssh fails (255), the remote status is not
# 0, 1 or 2, the marker is missing, the length differs, the counts disagree, cross_accept.sh ends
# with 2 or another status).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${SEA_CROSS_HOST:-desktop}
TIMEOUT=${SEA_TEST_TIMEOUT:-10}
VERBOSE=
while [ $# -gt 0 ]; do
    case "$1" in
    -v) VERBOSE=-v; shift ;;
    -H)
        if [ $# -lt 2 ]; then echo "cross.sh: missing argument for '-H'" >&2; exit 2; fi
        HOST=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "cross.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done

case "$TIMEOUT" in
'' | *[!0-9]*) echo "cross.sh: SEA_TEST_TIMEOUT must be a number of seconds" >&2; exit 2 ;;
esac
KPFX=
case "${SEA_KERNELS:-}" in
'') ;;
*[!A-Za-z0-9_]*) echo "cross.sh: SEA_KERNELS must contain only letters, digits and underscores" >&2; exit 2 ;;
*) KPFX="SEA_KERNELS=$SEA_KERNELS " ;;
esac

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-cross.XXXXXX") || {
    echo "cross.sh: cannot create temporary directory" >&2
    exit 2
}


SSHPID=
AWKPID=
cleanup() {
    # stop a still-running ssh (exact pid); the remote side then sees its stdin close, kills the
    # run and removes its directory (see the remote script)
    if [ -n "$SSHPID" ]; then kill "$SSHPID" 2>/dev/null; fi
    if [ -n "$AWKPID" ]; then kill "$AWKPID" 2>/dev/null; fi
    rm -rf "$TMP"
}
trap 'cleanup' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'cleanup; exit 2' HUP INT TERM PIPE

if ! sh "$ROOT/tests/cross_pack.sh" -o "$TMP/bundle" "$@"; then
    echo "cross.sh: packing the test bundle failed" >&2
    exit 2
fi

# Remote script (no single quote in it, so it survives any login shell). The tar stream is
# followed by an open, silent stdin: when the connection or this script goes away, that stdin
# reaches end of file, and the watcher kills the whole run (its own process group when setsid
# exists) and the EXIT/HUP/INT/TERM trap removes the directory. Nothing is left on the host.
# After a run ending with 0 or 1 it writes the return path: the marker line and the base64 text of
# the tar of the kept runs (2.13.9 item 3).
REMOTE=$(cat <<'EOF'
d=$(mktemp -d "${TMPDIR:-/tmp}/sea-cross.XXXXXX") || exit 2
rp=
stop() { if [ -n "$rp" ]; then kill -TERM -- "-$rp" 2>/dev/null || kill -TERM "$rp" 2>/dev/null; wait "$rp" 2>/dev/null; fi; }
trap "stop; rm -rf \"\$d\"" EXIT
trap "stop; rm -rf \"\$d\"; exit 2" HUP INT TERM PIPE
mkdir "$d/bundle" "$d/keep" || exit 2
exec 3<&0
tar -C "$d/bundle" -xf - <&3 || exit 2
S=; if command -v setsid >/dev/null 2>&1; then S=setsid; fi
$S sh "$d/bundle/tests/cross_run.sh" "$@" -k "$d/keep" "$d/bundle" </dev/null &
rp=$!
( cat <&3 >/dev/null; kill -TERM -- "-$rp" 2>/dev/null || kill -TERM "$rp" 2>/dev/null ) >/dev/null 2>&1 &
wp=$!
wait "$rp"
st=$?
kill "$wp" 2>/dev/null
rp=
if [ $st -ne 0 ] && [ $st -ne 1 ]; then exit $st; fi
: > "$d/kept.b64" || exit 2
if [ -n "$(cd "$d/keep" && find . -type f | head -n 1)" ]; then
    tar -C "$d/keep" -cf - . > "$d/kept.tar" || exit 2
    base64 < "$d/kept.tar" > "$d/kept.b64" || exit 2
fi
n=$(wc -c < "$d/kept.b64" | tr -d " ")
echo "#sea-cross-files $n"
cat "$d/kept.b64" || exit 2
exit $st
EOF
)
REMOTE="SEA_TEST_TIMEOUT=$TIMEOUT; export SEA_TEST_TIMEOUT; ${KPFX:+$KPFX; export SEA_KERNELS;} $REMOTE"

# The splitter: every line before the marker goes to the standard output (as it arrives) and to
# $TMP/report.txt; the marker's N goes to $TMP/kept.n; every later line goes to $TMP/kept.b64.
mkfifo "$TMP/in" "$TMP/out" || { echo "cross.sh: cannot create a fifo" >&2; exit 2; }
awk -v rep="$TMP/report.txt" -v b64="$TMP/kept.b64" -v nf="$TMP/kept.n" '
BEGIN { printf "" > rep }
m { print > b64; next }
/^#sea-cross-files [0-9]+$/ { m = 1; print $2 > nf; close(nf); printf "" > b64; next }
{ print; fflush(); print > rep }' < "$TMP/out" &
AWKPID=$!
ssh -o BatchMode=yes -- "$HOST" "sh -c '$REMOTE' sh $VERBOSE" < "$TMP/in" > "$TMP/out" &
SSHPID=$!
exec 3>"$TMP/in"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$TMP/bundle" -cf - . >&3
wait "$SSHPID"
st=$?
SSHPID=
exec 3>&-
wait "$AWKPID"
ast=$?
AWKPID=
if [ $st -eq 255 ]; then
    echo "cross.sh: ssh to '$HOST' failed" >&2
    exit 2
fi
case $st in
0 | 1) ;;
2) exit 2 ;;
*) echo "cross.sh: remote command ended with unexpected status $st" >&2; exit 2 ;;
esac
[ $ast -eq 0 ] || { echo "cross.sh: the output splitter failed (status $ast)" >&2; exit 2; }

# the return path: the marker and the length of what followed it
if [ ! -f "$TMP/kept.n" ]; then
    echo "cross.sh: the host sent no '#sea-cross-files N' line" >&2
    exit 2
fi
N=$(cat "$TMP/kept.n")
GOT=$(wc -c < "$TMP/kept.b64" | tr -d ' ')
if [ "$GOT" != "$N" ]; then
    echo "cross.sh: the kept files are $GOT bytes of base64, the host announced $N" >&2
    exit 2
fi

# the host's counts, from its totals line `passed: P  failed: F, D deferred`
HC=$(sed -n 's/^passed: \([0-9][0-9]*\)  failed: \([0-9][0-9]*\), \([0-9][0-9]*\) deferred$/\1 \2 \3/p' "$TMP/report.txt" | tail -n 1)
if [ -z "$HC" ]; then
    echo "cross.sh: the host's report has no 'passed: P  failed: F, D deferred' line" >&2
    exit 2
fi
set -- $HC
HP=$1; HF=$2; HD=$3

# the Mac side (2.13.9 item 4): only when the host deferred a run or returned files
MP=0; MF=0; mst=0
if [ "$HD" -ne 0 ] || [ "$N" -ne 0 ]; then
    { sh "$ROOT/tests/cross_accept.sh" $VERBOSE "$TMP/bundle" "$TMP/kept.b64" "$TMP/report.txt"; echo $? > "$TMP/accept.st"; } | tee "$TMP/accept.txt"
    mst=$(cat "$TMP/accept.st" 2>/dev/null)
    case $mst in
    0 | 1) ;;
    *) echo "cross.sh: tests/cross_accept.sh failed (setup error)" >&2; exit 2 ;;
    esac
    MC=$(sed -n 's/^passed: \([0-9][0-9]*\)  failed: \([0-9][0-9]*\)$/\1 \2/p' "$TMP/accept.txt" | tail -n 1)
    [ -n "$MC" ] || { echo "cross.sh: tests/cross_accept.sh printed no 'passed: P  failed: F' line" >&2; exit 2; }
    set -- $MC
    MP=$1; MF=$2
fi
echo "host: $HP passed, $HF failed, $HD deferred; Mac: $MP passed, $MF failed"
if [ "$HD" -ne $((MP + MF)) ]; then
    echo "cross.sh: the host deferred $HD runs but the Mac judged $((MP + MF))" >&2
    exit 2
fi
if [ $st -eq 1 ] || [ "$HF" -ne 0 ] || [ "$mst" -eq 1 ] || [ "$MF" -ne 0 ]; then exit 1; fi
exit 0
