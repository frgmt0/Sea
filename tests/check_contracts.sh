#!/bin/sh
# tests/check_contracts.sh -- the contract drift check (POSIX sh + awk), docs/DESIGN.md 2.6, 3.9, 6.2.
#
# usage: sh tests/check_contracts.sh [SEA_DIR]     (default: the Sea repository of this script)
#
# The include checks (make check-includes) prove that the contract files agree with
# themselves; this check proves that they agree with the documents. Both directions:
#   1. every `.equiv SEA_<NAME>, <value>` of include/limits.inc, errors.inc and rt.inc
#      (except the include guards SEA_*_INC) equals a table row "| `SEA_<NAME>` | <value> |"
#      of docs/DESIGN.md, and every such row is an .equiv of the same value;
#   2. every error record of errors.inc (code, NAME, phase, at, args, text) equals a row of the
#      error table of DESIGN.md 2.6.2, every errno record (id, NAME, darwin, linux, text) a row of
#      the errno table, and vice versa;
#   3. every `head` and `rec` line of include/passes.txt equals a row of the record tables of
#      DESIGN.md 3.2-3.6 (opcode, pops, fields; DESIGN.md 3.9 says how the tables are read), and
#      vice versa.
# Values are compared as text (both sides write them the same way). Nothing is written outside a
# temporary directory, which is removed on exit.
#
# Exit status: 0 the contracts agree; 1 a difference (listed on standard error); 2 setup error.

ROOT=${1:-$(cd "$(dirname "$0")/.." && pwd)}
DOC=$ROOT/docs/DESIGN.md
for f in "$DOC" "$ROOT/include/limits.inc" "$ROOT/include/errors.inc" "$ROOT/include/rt.inc" \
         "$ROOT/include/passes.txt"; do
    if [ ! -f "$f" ]; then
        echo "check_contracts.sh: $f not found" >&2
        exit 2
    fi
done

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-contracts.XXXXXX") || {
    echo "check_contracts.sh: cannot create temporary directory" >&2
    exit 2
}
trap 'rm -rf "$TMP"' EXIT
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

LC_ALL=C
export LC_ALL

# ---- 1. names and values ---------------------------------------------------------------
awk '
$1 == ".equiv" && $2 ~ /^SEA_[A-Z0-9_]+,$/ {
    n = $2; sub(/,$/, "", n)
    if (n ~ /_INC$/) next
    print n, $3
}' "$ROOT/include/limits.inc" "$ROOT/include/errors.inc" "$ROOT/include/rt.inc" |
    sort > "$TMP/equ.inc" || exit 2

awk -F '|' '
/^\| `SEA_[A-Z0-9_]+` \|/ {
    n = $2; v = $3
    gsub(/[ `]/, "", n); gsub(/[ `]/, "", v)
    print n, v
}' "$DOC" | sort > "$TMP/equ.doc" || exit 2

# ---- 2. error and errno records ----------------------------------------------------------
# errors.inc: the records of SEA_ERROR_LIST and SEA_ERRNO_LIST; text unescaped (\" and \\).
awk '
function unq(s) {
    sub(/^"/, "", s); sub(/"$/, "", s)
    gsub(/\\\\/, "\001", s); gsub(/\\"/, "\"", s); gsub(/\001/, "\\", s)
    return s
}
/^\.macro SEA_ERROR_LIST / { list = "E"; next }
/^\.macro SEA_ERRNO_LIST / { list = "N"; next }
/^\.endm/ { list = ""; next }
list != "" && /^    \\m / {
    s = substr($0, 8)
    k = (list == "E") ? 5 : 4
    out = list
    for (i = 1; i <= k; i++) {
        p = index(s, ", ")
        if (p == 0) { print "BAD-LINE " $0; next }
        out = out "|" substr(s, 1, p - 1)
        s = substr(s, p + 2)
    }
    print out "|" unq(s)
}' "$ROOT/include/errors.inc" | sort > "$TMP/err.inc" || exit 2

# DESIGN.md: error table rows "| code | `NAME` | phase | at | args | `text` | source |" and
# errno rows "| id | `NAME` | darwin | linux | `text` |".
awk '
function cell(s) {
    sub(/^ +/, "", s); sub(/ +$/, "", s)
    if (s ~ /^`.*`$/) s = substr(s, 2, length(s) - 2)
    return s
}
/^\| [0-9]+ \| `[A-Z0-9_]+` \| / {
    line = $0
    gsub(/\\\|/, "\001", line)
    n = split(line, c, "|")
    for (i = 2; i < n; i++) { c[i] = cell(c[i]); gsub(/\001/, "|", c[i]) }
    if (c[4] ~ /^(R|D|C1|C2|CX|P)$/)
        print "E|" c[2] "|" c[3] "|" c[4] "|" c[5] "|" c[6] "|" c[7]
    else if (c[4] ~ /^-?[0-9]+$/ && c[5] ~ /^-?[0-9]+$/)
        print "N|" c[2] "|" c[3] "|" c[4] "|" c[5] "|" c[6]
    else
        print "BAD-ROW " $0
}' "$DOC" | sort > "$TMP/err.doc" || exit 2

# ---- 3. record formats -------------------------------------------------------------------
awk '
/^head / { s = "head #" $2; for (i = 3; i <= NF; i++) s = s " " $i; print s; next }
/^rec / {
    s = substr($2, 1, 1) " " $4 " " $5
    for (i = 6; i <= NF; i++) s = s " " $i
    print s
}' "$ROOT/include/passes.txt" | sort > "$TMP/rec.txt" || exit 2

awk '
function spans(s, arr,    n, p, q) {
    n = 0
    while ((p = index(s, "`")) > 0) {
        s = substr(s, p + 1)
        q = index(s, "`")
        if (q == 0) break
        arr[++n] = substr(s, 1, q - 1)
        s = substr(s, q + 1)
    }
    return n
}
function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
/^## / { insec = ($0 ~ /^## 3\./); kind = ""; intab = 0; next }
!insec { next }
/^### 3\.2 / { kind = "head" }
/^### 3\.4 / { kind = "A" }
/^### 3\.5 / { kind = "H" }
/^### 3\.6 / { kind = "L" }
/^### 3\.[13789] / { kind = "" }
kind != "" && /^\| (Record|Instruction) \|/ {
    intab = 1; popcol = 0; after = 0
    line = $0; n = split(line, h, "|")
    for (i = 2; i < n; i++) {
        x = trim(h[i])
        if (x == "Pops") popcol = i
        if (i == 3 && x ~ /after/) after = 1
    }
    next
}
intab && /^\|-/ { next }
intab && !/^\|/ { intab = 0; next }
intab {
    line = $0
    gsub(/\\\|/, "\001", line)
    n = split(line, c, "|")
    no = spans(c[2], ops)
    fc = trim(c[3])
    fields = ""
    if (fc != "—") {
        delete fs
        if (spans(fc, fs) < 1) { print "BAD-ROW " $0; next }
        m = split(fs[1], tok, " ")
        for (j = 1; j <= m; j++) {
            t = tok[j]
            if (index(t, ":") == 0) {
                match(t, /^[a-z]+/)
                t = substr(t, 1, RLENGTH) ":" t
            }
            fields = fields " " t
        }
    }
    if (after && index(fc, "no `pos`") == 0) fields = " pos:pos" fields
    pops = "0"
    if (popcol) {
        delete ps
        if (spans(c[popcol], ps) < 1) { print "BAD-ROW " $0; next }
        pops = ps[1]
    }
    for (j = 1; j <= no; j++) {
        k = split(ops[j], w, " ")
        for (q = 1; q <= k; q++) {
            if (kind == "head") print "head " w[q] fields
            else print kind " " w[q] " " pops fields
        }
    }
}' "$DOC" | sort > "$TMP/rec.doc" || exit 2

# ---- compare -------------------------------------------------------------------------------
st=0
report() {   # report LABEL LEFT RIGHT LEFT_NAME RIGHT_NAME
    if ! cmp -s "$2" "$3"; then
        st=1
        comm -23 "$2" "$3" | sed "s|^|$1: only in $4: |" >&2
        comm -13 "$2" "$3" | sed "s|^|$1: only in $5: |" >&2
    fi
}
report "names" "$TMP/equ.inc" "$TMP/equ.doc" "include/*.inc" "docs/DESIGN.md"
report "errors" "$TMP/err.inc" "$TMP/err.doc" "include/errors.inc" "docs/DESIGN.md 2.6.2"
report "records" "$TMP/rec.txt" "$TMP/rec.doc" "include/passes.txt" "docs/DESIGN.md 3"
if grep -h '^BAD-' "$TMP/err.inc" "$TMP/err.doc" "$TMP/rec.doc" >&2; then st=1; fi

ne=$(wc -l < "$TMP/equ.inc"); nr=$(wc -l < "$TMP/err.inc"); np=$(wc -l < "$TMP/rec.txt")
if [ $st -ne 0 ]; then
    echo "check_contracts.sh: the contract files and docs/DESIGN.md disagree (above)" >&2
    exit 1
fi
echo "contracts agree with docs/DESIGN.md:" $ne "names," $nr "error and errno records," $np "record formats"
exit 0
