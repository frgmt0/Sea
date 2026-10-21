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
#   SEA, BAYSICK          used by cross_pack.sh
#   SEA_TEST_TIMEOUT      seconds per program, forwarded (default 10)
#   SEA_KERNELS           if set, forwarded to the remote runs (letters, digits, underscores)
#   SEA_CROSS_HOST        default host
#
# Packs a bundle (tests/cross_pack.sh) into a local temp directory, streams it as tar into ONE
# ssh call that unpacks it into a remote mktemp -d directory (removed on exit; HUP/INT/TERM/PIPE
# clean up and exit 2) and runs tests/cross_run.sh there.
#
# Exit status: that of cross_run.sh (0 all passed, 1 failures, 2 setup error); 2 also if packing
# fails, ssh fails (255) or the remote status is anything else.

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
trap 'rm -rf "$TMP"' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

if ! sh "$ROOT/tests/cross_pack.sh" -o "$TMP/bundle" "$@"; then
    echo "cross.sh: packing the test bundle failed" >&2
    exit 2
fi

# Remote script: no single quote anywhere, so it survives any login shell.
REMOTE='d=$(mktemp -d "${TMPDIR:-/tmp}/sea-cross.XXXXXX") || exit 2; trap "rm -rf \"\$d\"" EXIT; trap "rm -rf \"\$d\"; exit 2" HUP INT TERM PIPE; tar -C "$d" -xf - || exit 2; SEA_TEST_TIMEOUT='"$TIMEOUT"' '"$KPFX"'sh "$d/tests/cross_run.sh" "$@" "$d"'

COPYFILE_DISABLE=1 tar --no-xattrs -C "$TMP/bundle" -cf - . | ssh -o BatchMode=yes -- "$HOST" "sh -c '$REMOTE' sh $VERBOSE"
st=$?
if [ $st -eq 255 ]; then
    echo "cross.sh: ssh to '$HOST' failed" >&2
    exit 2
fi
case $st in
0 | 1 | 2) exit $st ;;
esac
echo "cross.sh: remote command ended with unexpected status $st" >&2
exit 2
