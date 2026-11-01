#!/bin/sh
# tests/la/la_link.sh -- link isolation of the matrix product (POSIX sh; macOS and Linux).
# docs/DESIGN.md 2.13.8 ("Link isolation"), 4.3, lead decision L-ja.
#
# usage (Mac):   sh tests/la/la_link.sh [-v] [-p PROGRAM.sea]
# usage (Linux): sh tests/la/la_link.sh [-v] -s PROGRAM.s LIBSEA LIBBAYSICKRT
#   -v             print the link map's libbaysickrt.a members on success too
#   -p PROGRAM.sea the program to build (default tests/programs/la_mm_exact.sea, which calls MATMUL)
#   -s PROGRAM.s   Linux: the program's x86_64-linux assembly, compiled on the Mac (the cross bundle's
#                  cases/programs/la_mm_exact.s); LIBSEA and LIBBAYSICKRT the two runtime archives
#
# Environment (Mac): SEA the driver (default: BUILD/sea, BUILD default build/ of the Sea repository),
# SEA_COMPILE_TIMEOUT (default 120). Environment (Linux): AS (default as), CC (default gcc).
#
# What it does. On the Mac the program is compiled with `sea build -S`, assembled with `as` as the
# driver assembles it, and linked with the driver's `ld` command (driver/sea, step 8: sea.o, libsea.a,
# libbaysickrt.a, -lSystem, -syslibroot of `xcrun --show-sdk-path`, -e _main, -arch arm64,
# -platform_version macos 11.0 11.0) with `-map FILE` added; the map's "# Object files:" section names
# each loaded archive member as `ARCHIVE(member)`. On Linux the assembly is assembled with `as --64`
# and linked as tests/cross_run.sh links every case (gcc -no-pie, libsea.a, libbaysickrt.a, -lm) with
# `-Wl,-Map,FILE` added; GNU ld's map starts with the section "Archive member included to satisfy
# reference by file (symbol)", one line per loaded member starting in column 1 as `ARCHIVE(member)`
# (the referencing file after it, or indented on the next line). `-Wl,--trace` is not used: GNU ld
# 2.47 (the host's) prints only the archive's path there, not its members. `nm` cannot do this
# either: an executable has symbols, not members.
#
# Pass criterion: every member of libbaysickrt.a the map names matches `rt_kinit.o` or `rt_k*.o`, and
# `rt_kinit.o` is among them. Any other libbaysickrt.a member, no rt_kinit.o, or no map is a failure,
# the members named.
#
# Output: `la/la_link: passed (libbaysickrt.a members: ...)`, or `FAIL la/la_link: <reason>`.
# Exit status: 0 passed, 1 failed, 2 setup error.

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VERBOSE=0
PROG=
ASMIN=
while [ $# -gt 0 ]; do
    case "$1" in
    -v) VERBOSE=1; shift ;;
    -p) [ $# -ge 2 ] || { echo "la_link.sh: missing argument for '-p'" >&2; exit 2; }; PROG=$2; shift 2 ;;
    -s) [ $# -ge 2 ] || { echo "la_link.sh: missing argument for '-s'" >&2; exit 2; }; ASMIN=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "la_link.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-lalink.XXXXXX") || { echo "la_link.sh: cannot create temporary directory" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

fail() { echo "FAIL la/la_link: $1"; exit 1; }
setup() { echo "la_link.sh: $1" >&2; exit 2; }

# run_limited SECONDS DIR CMD... : run CMD in DIR (stdin /dev/null), kill it after SECONDS
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

if [ "$(uname -s)" = Darwin ]; then
    [ $# -eq 0 ] || setup "usage (Mac): sh tests/la/la_link.sh [-v] [-p PROGRAM.sea]"
    [ -z "$ASMIN" ] || setup "-s is the Linux form; on the Mac the program is compiled here"
    BUILD=${BUILD:-$ROOT/build}
    case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
    SEA=${SEA:-$BUILD/sea}
    case $SEA in /*) ;; *) SEA=$(pwd)/$SEA ;; esac
    [ -x "$SEA" ] || setup "driver '$SEA' not found or not executable; run 'make' first"
    SEADIR=$(dirname "$SEA")
    LIBSEA=$SEADIR/libsea.a
    LIBRT=$SEADIR/libbaysickrt.a
    [ -f "$LIBSEA" ] || setup "runtime library '$LIBSEA' not found"
    [ -f "$LIBRT" ] || setup "runtime library '$LIBRT' not found"
    PROG=${PROG:-$ROOT/tests/programs/la_mm_exact.sea}
    case $PROG in /*) ;; *) PROG=$(pwd)/$PROG ;; esac
    [ -f "$PROG" ] || setup "program '$PROG' not found"
    cp "$PROG" "$TMP/prog.sea" || setup "cannot copy $PROG"
    run_limited "${SEA_COMPILE_TIMEOUT:-120}" "$TMP" "$SEA" build -S -o prog.s prog.sea >"$TMP/c.out" 2>"$TMP/c.err"
    st=$?
    [ $st -eq 0 ] && [ -f "$TMP/prog.s" ] || fail "compiling $(basename "$PROG") failed (status $st): $(head -3 "$TMP/c.err" | tr '\n' ' ')"
    SDK=$(env -u SDKROOT xcrun --show-sdk-path 2>/dev/null | sed -n 1p)
    [ -n "$SDK" ] && [ -d "$SDK" ] || setup "cannot determine the macOS SDK path (xcrun --show-sdk-path)"
    (cd "$TMP" && env -u SDKROOT as -arch arm64 -mmacosx-version-min=11.0 -o prog.o prog.s) >"$TMP/a.out" 2>&1 \
        || fail "assembling failed: $(head -3 "$TMP/a.out" | tr '\n' ' ')"
    # the driver's ld command (driver/sea step 8), with -map added
    (cd "$TMP" && env -u SDKROOT ld -o prog prog.o "$LIBSEA" "$LIBRT" -lSystem -syslibroot "$SDK" -e _main \
        -arch arm64 -platform_version macos 11.0 11.0 -map "$TMP/link.map") >"$TMP/l.out" 2>&1 \
        || fail "linking failed: $(head -3 "$TMP/l.out" | tr '\n' ' ')"
    [ -s "$TMP/link.map" ] || fail "the linker wrote no map"
    # the "# Object files:" section: lines `[  N] PATH`, a member as `ARCHIVE(member)`
    awk '
    /^# Object files:/ { on = 1; next }
    /^# / && on { on = 0 }
    on && /^\[/ { sub(/^\[[^]]*\][[:space:]]*/, ""); print }' "$TMP/link.map" > "$TMP/loaded"
    [ -s "$TMP/loaded" ] || fail "the link map has no '# Object files:' section"
    WHAT=map
else
    [ -n "$ASMIN" ] && [ $# -eq 2 ] || setup "usage (Linux): sh tests/la/la_link.sh [-v] -s PROGRAM.s LIBSEA LIBBAYSICKRT"
    [ -z "$PROG" ] || setup "-p is the Mac form; on Linux pass the compiled assembly with -s"
    LIBSEA=$1
    LIBRT=$2
    for f in "$ASMIN" "$LIBSEA" "$LIBRT"; do [ -f "$f" ] || setup "'$f' not found"; done
    AS=${AS:-as}
    CC=${CC:-gcc}
    "$AS" --64 -o "$TMP/prog.o" "$ASMIN" >"$TMP/a.out" 2>&1 || fail "assembling failed: $(head -3 "$TMP/a.out" | tr '\n' ' ')"
    # as tests/cross_run.sh links every case, with a link map added
    "$CC" -no-pie -o "$TMP/prog" "$TMP/prog.o" "$LIBSEA" "$LIBRT" -lm -Wl,-Map,"$TMP/link.map" >"$TMP/l.out" 2>&1 \
        || fail "linking failed: $(head -3 "$TMP/l.out" | tr '\n' ' ')"
    [ -s "$TMP/link.map" ] || fail "the linker wrote no map"
    # the section "Archive member included ...": its column-1 lines up to the first column-1 line
    # that names no archive member (the next section's title); the member is the line's first field
    awk '
    /^Archive member included/ { on = 1; next }
    on && /^[^[:space:]]/ { if ($1 ~ /\.a\(.*\)$/ || $1 ~ /^\(.*\.a\)/) print $1; else exit }' "$TMP/link.map" > "$TMP/loaded"
    [ -s "$TMP/loaded" ] || fail "the link map has no 'Archive member included' section"
    WHAT=map
fi

# the members of libbaysickrt.a: `.../libbaysickrt.a(member)` (also `(.../libbaysickrt.a)member`,
# the form GNU ld's --trace prints in some versions; accepted in case a map ever uses it)
sed -n -e 's|^.*libbaysickrt\.a(\([^)]*\))[[:space:]]*$|\1|p' \
       -e 's|^(.*libbaysickrt\.a)\([^[:space:]]*\)[[:space:]]*$|\1|p' "$TMP/loaded" | sort -u > "$TMP/members"
MEMBERS=$(tr '\n' ' ' <"$TMP/members" | sed 's/ $//')
[ -s "$TMP/members" ] || fail "the link $WHAT names no member of libbaysickrt.a (rt_kinit.o expected)"
BAD=
while IFS= read -r m; do
    case $m in
    rt_kinit.o | rt_k*.o) ;;
    *) BAD="$BAD $m" ;;
    esac
done < "$TMP/members"
[ -z "$BAD" ] || fail "libbaysickrt.a members other than rt_kinit.o and rt_k*.o are linked:$BAD (all: $MEMBERS)"
grep -qx 'rt_kinit.o' "$TMP/members" || fail "rt_kinit.o is not linked (members: $MEMBERS)"
echo "la/la_link: passed (libbaysickrt.a members: $MEMBERS)"
if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$TMP/members"; fi
exit 0
