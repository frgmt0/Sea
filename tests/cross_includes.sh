#!/bin/sh
# tests/cross_includes.sh -- run Sea's GNU as include check on a Linux x86_64 host (POSIX sh).
#
# usage: sh tests/cross_includes.sh [-H HOST] [-B BAYSICK_DIR]
#   -H HOST         ssh destination (default: $SEA_CROSS_HOST, else "desktop");
#                   key authentication is required (ssh -o BatchMode=yes)
#   -B BAYSICK_DIR  the Baysick checkout whose include/limits.inc and
#                   include/runtime.inc Sea is checked against (default: the
#                   parent of the Sea repository, Sea being Baysick's submodule)
#
# Packs Makefile.linux, include/limits.inc, errors.inc, rt.inc,
# tests/include_check_x86_64.s and tests/include_asserts.inc, with Baysick's two
# include files, into a local temp directory, streams it as tar into ONE ssh call
# that unpacks it into a remote mktemp -d directory (removed on exit; HUP/INT/TERM/
# PIPE clean up and exit 2), and runs `make -f Makefile.linux check-includes` there.
# Nothing else on the host is touched. docs/DESIGN.md 6.2.
#
# Exit status: 0 the check passed, 1 it failed, 2 setup error (packing, ssh).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${SEA_CROSS_HOST:-desktop}
BAYSICK=$ROOT/..
while [ $# -gt 0 ]; do
    case "$1" in
    -H)
        if [ $# -lt 2 ]; then echo "cross_includes.sh: missing argument for '-H'" >&2; exit 2; fi
        HOST=$2; shift 2 ;;
    -B)
        if [ $# -lt 2 ]; then echo "cross_includes.sh: missing argument for '-B'" >&2; exit 2; fi
        BAYSICK=$2; shift 2 ;;
    *) echo "cross_includes.sh: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

for f in "$BAYSICK/include/limits.inc" "$BAYSICK/include/runtime.inc"; do
    if [ ! -f "$f" ]; then
        echo "cross_includes.sh: $f not found (use -B BAYSICK_DIR)" >&2
        exit 2
    fi
done

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-cross-incl.XXXXXX") || {
    echo "cross_includes.sh: cannot create temporary directory" >&2
    exit 2
}
trap 'rm -rf "$TMP"' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

# Bundle layout: baysick/include/ (Baysick's two files) and baysick/sea/ (Sea's),
# so Makefile.linux's default BAYSICK=.. finds them.
B=$TMP/bundle
if ! mkdir -p "$B/baysick/include" "$B/baysick/sea/include" "$B/baysick/sea/tests" ||
   ! cp "$BAYSICK/include/limits.inc" "$BAYSICK/include/runtime.inc" "$B/baysick/include/" ||
   ! cp "$ROOT/Makefile.linux" "$B/baysick/sea/" ||
   ! cp "$ROOT/include/limits.inc" "$ROOT/include/errors.inc" "$ROOT/include/rt.inc" "$B/baysick/sea/include/" ||
   ! cp "$ROOT/tests/include_check_x86_64.s" "$ROOT/tests/include_asserts.inc" "$B/baysick/sea/tests/"; then
    echo "cross_includes.sh: packing the files failed" >&2
    exit 2
fi

# Remote script: no single quote anywhere, so it survives any login shell.
REMOTE='d=$(mktemp -d "${TMPDIR:-/tmp}/sea-cross-incl.XXXXXX") || exit 2; trap "rm -rf \"\$d\"" EXIT; trap "rm -rf \"\$d\"; exit 2" HUP INT TERM PIPE; tar -C "$d" -xf - || exit 2; make -C "$d/baysick/sea" -f Makefile.linux check-includes || exit 1'

COPYFILE_DISABLE=1 tar --no-xattrs -C "$B" -cf - . | ssh -o BatchMode=yes -- "$HOST" "sh -c '$REMOTE'"
st=$?
if [ $st -eq 255 ]; then
    echo "cross_includes.sh: ssh to '$HOST' failed" >&2
    exit 2
fi
case $st in
0 | 1 | 2) exit $st ;;
esac
echo "cross_includes.sh: unexpected remote status $st" >&2
exit 2
