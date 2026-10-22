#!/bin/sh
# tools/passlines.sh -- each built pass program against Baysick's per-program limits
# (docs/DESIGN.md 2.7, 2.10). POSIX sh + awk.
#
# usage: sh tools/passlines.sh lines|limits [BUILD_DIR]
#   lines    the stored-line count of every build/gen/<pass>.bas against LIM_LINES
#   limits   the same, plus FOR statements against LIM_FORS, bytes of string constants outside
#            DATA against LIM_LABEL_BYTES, and the longest physical line against LIM_PHYS_LINE_LEN
#
# The limits are read from Baysick's include/limits.inc ($BAYSICK, default ..), never written
# here. A pass whose build/gen/<pass>.bas does not exist is reported as "not built" (it is
# not an error: the passes arrive one by one). Exit status: 0 every built pass is within the
# limits, 1 a limit is exceeded, 2 setup error (Baysick's limits.inc not found, bad usage).
#
# What is counted (Baysick LANGUAGE.md 1.2, 4.3, 7.8): a stored line is a non-blank line; a
# FOR statement is a statement whose first word is FOR; string-constant bytes are the bytes
# between quotes on every line except REM and DATA lines, the quoted name of a SUB or CALL
# excluded (it is not a label).

mode=${1:-}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${2:-${BUILD:-$ROOT/build}}
BAYSICK=${BAYSICK:-$ROOT/..}
PASSES="seaparse seaname seacheck seaexpand sealoop sealower seaopt seagen_a64 seagen_x64"
case $mode in
lines | limits) ;;
*) echo "usage: sh tools/passlines.sh lines|limits [BUILD_DIR]" >&2; exit 2 ;;
esac

inc="$BAYSICK/include/limits.inc"
if [ ! -f "$inc" ]; then
    echo "passlines.sh: Baysick's limits.inc not found at '$inc' (set BAYSICK)" >&2
    exit 2
fi
limit() { awk -v n="$1" '$1 == ".equ" { s = $2; sub(/,$/, "", s); if (s == n) { print $3; exit } }' "$inc"; }
LIM_LINES=$(limit LIM_LINES)
LIM_FORS=$(limit LIM_FORS)
LIM_LABEL_BYTES=$(limit LIM_LABEL_BYTES)
LIM_PHYS=$(limit LIM_PHYS_LINE_LEN)
if [ -z "$LIM_LINES" ] || [ -z "$LIM_FORS" ] || [ -z "$LIM_LABEL_BYTES" ] || [ -z "$LIM_PHYS" ]; then
    echo "passlines.sh: a limit is missing from '$inc'" >&2
    exit 2
fi

status=0
if [ "$mode" = lines ]; then
    printf '%-12s %8s %8s\n' pass lines limit
else
    printf '%-12s %8s %8s %6s %6s %10s %8s %5s %s\n' pass lines limit FORs limit str-bytes limit maxln verdict
fi
for p in $PASSES; do
    f="$BUILD/gen/$p.bas"
    if [ ! -f "$f" ]; then
        # seagen_x64 is a later phase: silent while the pass is not part of the build
        [ "$p" = seagen_x64 ] && continue
        printf '%-12s not built\n' "$p"
        continue
    fi
    res=$(LC_ALL=C awk -v lim_lines="$LIM_LINES" -v lim_fors="$LIM_FORS" -v lim_str="$LIM_LABEL_BYTES" -v lim_phys="$LIM_PHYS" '
    {
        line = $0; n = length(line)
        if (n > 0 && substr(line, n, 1) == "\r") { line = substr(line, 1, n - 1); n-- }
        if (n > maxln) maxln = n
        if (n > lim_phys && badlines < 5) { bad = bad " " NR; badlines++ }
        s = line
        if (s ~ /^[ \t]*$/) next
        lines++
        sub(/^[ \t]*[0-9]+[ \t]*/, "", s)             # the line number
        word = toupper(s); gsub(/[ \t]/, "", word)    # blanks are insignificant (compaction)
        if (word ~ /^REM/ || word ~ /^DATA/) next
        if (word ~ /^FOR/) fors++
        # bytes between quotes; a SUB or CALL name (the first string) is not counted
        skip = (word ~ /^SUB/ || word ~ /^CALL/) ? 1 : 0
        inq = 0; cnt = 0
        for (i = 1; i <= length(s); i++) {
            c = substr(s, i, 1)
            if (c == "\"") {
                if (inq) { if (skip) skip = 0; else str += cnt; inq = 0 }
                else { inq = 1; cnt = 0 }
            } else if (inq) cnt++
        }
    }
    END {
        v = ""
        if (lines > lim_lines) v = v " lines"
        if (fors > lim_fors) v = v " FORs"
        if (str > lim_str) v = v " strings"
        if (maxln > lim_phys) v = v " longline(" substr(bad, 2) ")"
        print lines + 0, fors + 0, str + 0, maxln + 0, (v == "" ? "ok" : "EXCEEDED" v)
    }' "$f")
    set -- $res
    if [ "$mode" = lines ]; then
        v=ok; [ "$1" -gt "$LIM_LINES" ] && v=EXCEEDED
        printf '%-12s %8s %8s  %s\n' "$p" "$1" "$LIM_LINES" "$v"
        [ "$v" = ok ] || status=1
    else
        printf '%-12s %8s %8s %6s %6s %10s %8s %5s %s\n' "$p" "$1" "$LIM_LINES" "$2" "$LIM_FORS" "$3" "$LIM_LABEL_BYTES" "$4" "$5"
        case $5 in EXCEEDED*) status=1; echo "  $p: $*" ;; esac
    fi
done
exit $status
