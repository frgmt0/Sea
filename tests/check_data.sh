#!/bin/sh
# tests/check_data.sh -- checks the DATA generator tools/gendata.bas (docs/DESIGN.md 2.6.2, 2.6.3).
#
# Builds the generator with Baysick's compiler into a temporary directory, runs it on the real
# contract files (sea/include) and checks the output against lines derived BY HAND from the
# contract files and DESIGN.md (never from what the generator prints):
#   * the table layout: consecutive line numbers from 89000 within 89000..99998, every line at
#     most 255 bytes, every line "<number> DATA ...", each table followed by its sentinel;
#   * every record present: the table lengths equal the record counts of the source files,
#     counted here with awk/grep (an independent implementation);
#   * chosen records: the code-19 example of 2.6.2, errno records, limits as limbs (a value of
#     more than 9 digits, a hexadecimal one, a negative one), entry records, passes.txt lines,
#     and every sentinel;
#   * a synthetic contract directory: 64-bit limb edge values, the DATA escaping (backslash,
#     quote, percent, blank, UTF-8, empty text), exit statuses;
#   * negative cases: a 256-byte DATA line, malformed records and constants, a bad selection:
#     exit status 1 and a message on standard error (a 255-byte line is accepted).
#
# Usage: sh tests/check_data.sh        (run from anywhere; POSIX sh + awk + grep + cmp)
# Environment: BAYSICK=<dir> the Baysick checkout (default: the parent of sea/);
#              GENDATA_BAS=<file> the generator source to test (default tools/gendata.bas),
#              used to demonstrate that the checks fail on a broken copy.
# Never sets SDKROOT/DEVELOPER_DIR.

SEA=$(cd "$(dirname "$0")/.." && pwd) || exit 2
BAYSICK=${BAYSICK:-$SEA/..}
BAYSICK_BIN=$BAYSICK/build/baysick
SRC=${GENDATA_BAS:-$SEA/tools/gendata.bas}
INC=$SEA/include

if [ ! -x "$BAYSICK_BIN" ]; then
    echo "check_data: $BAYSICK_BIN not found (build Baysick first: make -C $BAYSICK)" >&2
    exit 2
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/seadata.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT INT TERM

fails=0
checks=0

fail() {
    fails=$((fails + 1))
    echo "FAIL: $*" >&2
}

pass() {
    checks=$((checks + 1))
}

# check_eq NAME EXPECTED ACTUAL
check_eq() {
    if [ "$2" = "$3" ]; then
        pass
    else
        fail "$1: expected '$2', got '$3'"
    fi
}

# gen DIR BLOCK... : run the generator in DIR with the blocks on standard input; sets $st,
# standard output in $T/o, standard error in $T/e.
gen() {
    gd=$1
    shift
    (cd "$gd" && printf '%s\n' "$@" | "$T/gendata" >"$T/o" 2>"$T/e")
    st=$?
}

# has LINE : the exact line (number included) is in the output
has() {
    if grep -Fxq -- "$1" "$T/o"; then
        pass
    else
        fail "missing line: $1"
    fi
}

# negative NAME PATTERN : status 1 and PATTERN (fixed string) on standard error
negative() {
    if [ "$st" -ne 1 ]; then
        fail "$1: expected exit status 1, got $st"
    elif ! grep -Fq -- "$2" "$T/e"; then
        fail "$1: standard error lacks '$2': $(cat "$T/e")"
    else
        pass
    fi
}

# copy_inc DIR : a private copy of the four contract files
copy_inc() {
    mkdir -p "$1"
    cp "$INC/limits.inc" "$INC/errors.inc" "$INC/rt.inc" "$INC/passes.txt" "$1/"
}

# replace_line DIR FILE PREFIX NEWLINE : the first line of FILE that starts with PREFIX becomes
# NEWLINE (the change must really change the file)
replace_line() {
    PFX=$3 NEW=$4 awk 'BEGIN { p = ENVIRON["PFX"]; n = ENVIRON["NEW"] }
        !done && index($0, p) == 1 { print n; done = 1; next } { print }' "$1/$2" >"$1/$2.new"
    if cmp -s "$1/$2" "$1/$2.new"; then
        fail "replace_line: no line of $2 starts with '$3' (or the change is empty)"
    fi
    mv "$1/$2.new" "$1/$2"
}

# --- build ---------------------------------------------------------------------------------
if ! "$BAYSICK_BIN" "$SRC" -o "$T/gendata" >"$T/build.log" 2>&1; then
    echo "check_data: gendata does not compile:" >&2
    cat "$T/build.log" >&2
    exit 1
fi

# --- the real contract files -----------------------------------------------------------------
gen "$INC" errors errno exits consts entries records
check_eq "real contract files: exit status" 0 "$st"
cp "$T/o" "$T/real.out"

# every line: "<number> DATA ", consecutive numbers from 89000, at most 99998, at most 255 bytes
awk '
    { if ($2 != "DATA") bad = bad " nodata:" NR }
    { if ($1 != 88999 + NR) bad = bad " number:" NR }
    { if ($1 > 99998) bad = bad " range:" NR }
    { if (length($0) > 255) bad = bad " long:" NR }
    END { if (bad != "") { print bad; exit 1 } }
' "$T/real.out" >"$T/awk.out" 2>&1
check_eq "line layout (numbers consecutive from 89000, <= 99998, <= 255 bytes, DATA)" 0 "$?"

# independent record counts of the source files
E=$(awk '/^\.macro SEA_ERROR_LIST m/ { s = 1; next } /^\.endm/ { s = 0 } s && index($0, "    \\m ") == 1 { n++ } END { print n + 0 }' "$INC/errors.inc")
R=$(awk '/^\.macro SEA_ERRNO_LIST m/ { s = 1; next } /^\.endm/ { s = 0 } s && index($0, "    \\m ") == 1 { n++ } END { print n + 0 }' "$INC/errors.inc")
X=$(grep -c '^\.equiv SEA_EXIT_' "$INC/errors.inc")
C=$(cat "$INC/limits.inc" "$INC/rt.inc" | grep -E '^\.equiv SEA_[A-Z0-9_]+,[ ]+(-?[0-9]+|0x[0-9A-F]+)' | grep -vcE '^\.equiv SEA_[A-Z0-9_]*_INC,')
T5=$(awk '/^\.macro SEA_ENTRY_LIST m/ { s = 1; next } /^\.endm/ { s = 0 } s && index($0, "    \\m ") == 1 { n++ } END { print n + 0 }' "$INC/rt.inc")
P=$(grep -cvE '^(;|$)' "$INC/passes.txt")

S2=$((89000 + E + 1))     # first errno line
S3=$((S2 + R + 1))        # first exit line
S4=$((S3 + X + 1))        # first constant line
S5=$((S4 + C + 1))        # first entry line
S6=$((S5 + T5 + 1))       # first passes.txt line
LAST=$((S6 + P))          # the "end" sentinel
check_eq "total number of lines (records + 6 sentinels)" "$((LAST - 88999))" "$(wc -l <"$T/real.out" | tr -d ' ')"

# sentinels at the computed positions
has "$((89000 + E)) DATA -1"
has "$((S2 + R)) DATA -1"
has "$((S3 + X)) DATA -1"
has "$((S4 + C)) DATA \"-\""
has "$((S5 + T5)) DATA -1"
has "$LAST DATA \"end\",0"

# 2.6.2: the code-19 example, and the dense first run-time codes (code k is line 88999 + k)
has '89018 DATA 19,"LINE_STYLE","R","-","s","invalid%20line%20style%20%22%25s%22"'
has '89000 DATA 1,"INDEX_OOB","R","-","iii","index%20%25d%20out%20of%20bounds%20for%20dimension%20%25d%20of%20extent%20%25d"'
has '89003 DATA 4,"INT_OVERFLOW","R","-","-","integer%20overflow"'
has "89015 DATA 16,\"CANNOT_OPEN\",\"R\",\"-\",\"se\",\"cannot%20open%20'%25s':%20%25s\""
has '89020 DATA 21,"USER","R","-","s","%25s"'
# the last record (code 504 is the last line of the errors table)
has "$((89000 + E - 1)) DATA 504,\"BAD_DATA\",\"P\",\"-\",\"-\",\"internal%20error:%20bad%20DATA%20table\""

# errno records (id k is line S2 + k)
has "$S2 DATA 0,\"UNKNOWN\",-1,-1,\"unknown%20error\""
has "$((S2 + 15)) DATA 15,\"ENAMETOOLONG\",63,36,\"File%20name%20too%20long\""
has "$((S2 + 17)) DATA 17,\"EDQUOT\",69,122,\"Disk%20quota%20exceeded\""

# exit statuses: NAME is the part after SEA_EXIT_
has "$S3 DATA 0,\"RUN_OK\""
has "$((S3 + 1)) DATA 1,\"RUN_ERROR\""
has "$((S3 + 4)) DATA 10,\"PASS_COMPILE\""

# constants as four 16-bit limbs, most significant first
has "$S4 DATA \"LIM_LINE_BYTES\",0,0,0,4096"
has "$((S4 + 3)) DATA \"LIM_UESC_MAX\",0,0,16,65535"
has "$((S4 + 5)) DATA \"LIM_EXTENT\",0,0,32767,65535"
has "$((S4 + 6)) DATA \"LIM_STR_BYTES\",0,0,32767,65535"
has "$((S4 + 11)) DATA \"LIM_NODES\",0,0,1,34463"
has "$((S4 + C - 1)) DATA \"VAR_AVX2\",0,0,0,3"
grep -q ' DATA "STACK_BYTES",0,0,1024,0$' "$T/o" && pass || fail "missing STACK_BYTES limbs (67108864 = 0x4000000)"
grep -q ' DATA "LCACHE_MAX_BYTES",0,0,4096,0$' "$T/o" && pass || fail "missing LCACHE_MAX_BYTES limbs (268435456 = 0x10000000)"
grep -q ' DATA "SHAPE_VEC",65535,65535,65535,65535$' "$T/o" && pass || fail "missing SHAPE_VEC limbs (-1)"
grep -q ' DATA "SITE_NONE",65535,65535,65535,65535$' "$T/o" && pass || fail "missing SITE_NONE limbs (-1)"
if grep -q '_INC"' "$T/o"; then fail "an include guard was emitted as a constant"; else pass; fi
if grep -q '\\' "$T/o"; then fail "a macro-body line leaked into the output"; else pass; fi

# entry records
has "$S5 DATA 1,\"PRINTF\",\"sea_printf\",\"S\",\"pp\",\"-\""
has "$((S5 + 1)) DATA 2,\"NOW\",\"sea_now\",\"-\",\"-\",\"f\""

# passes.txt lines: kind, number of other fields, the fields as DATA strings
has "$S6 DATA \"enum\",3,\"target\",\"arm64-macos\",\"x86_64-linux\""
has "$((S6 + 1)) DATA \"enum\",6,\"shape\",\"s\",\"v\",\"m\",\"fv\",\"fm\""
HEADEND=$(grep -vE '^(;|$)' "$INC/passes.txt" | grep -n '^head end$' | cut -d: -f1)
has "$((S6 + HEADEND - 1)) DATA \"head\",1,\"end\""
RECPROG=$(grep -vE '^(;|$)' "$INC/passes.txt" | grep -n '^rec A 1 prog n n:u$' | cut -d: -f1)
has "$((S6 + RECPROG - 1)) DATA \"rec\",5,\"A\",\"1\",\"prog\",\"n\",\"n:u\""
# a rec line with a repeated optional field (notation ?*): the field text travels unchanged
grep -q 'lid:lid?\*n' "$INC/passes.txt" && { grep -q ' DATA "rec",.*"lid:lid?\*n"' "$T/o" && pass || fail "a rec line with lid:lid?*n is missing"; }
# every non-comment passes.txt line has its DATA line: kinds in order
grep -vE '^(;|$)' "$INC/passes.txt" | awk '{ print $1 }' >"$T/kinds.want"
awk -v s="$S6" -v l="$LAST" '$1 >= s && $1 < l { split($3, a, ","); gsub(/"/, "", a[1]); print a[1] }' "$T/real.out" >"$T/kinds.got"
cmp -s "$T/kinds.want" "$T/kinds.got" && pass || fail "passes.txt line kinds differ from the DATA kinds"

# selections: a single block starts at 89000 and ends with its own sentinel
gen "$INC" errno
check_eq "errno alone: exit status" 0 "$st"
has "89000 DATA 0,\"UNKNOWN\",-1,-1,\"unknown%20error\""
has "$((89000 + R)) DATA -1"
check_eq "errno alone: line count" "$((R + 1))" "$(wc -l <"$T/o" | tr -d ' ')"
gen "$INC" entries records
check_eq "entries + records: exit status" 0 "$st"
has '89000 DATA 1,"PRINTF","sea_printf","S","pp","-"'
has "$((89000 + T5)) DATA -1"

# --- a synthetic contract directory: edge values and escaping ----------------------------------
D=$T/syn
mkdir -p "$D"
cat >"$D/limits.inc" <<'EOF'
// comment line, ignored
.ifndef SEA_X_INC
.equiv SEA_X_INC, 1
.equiv SEA_T_A, 9223372036854775807
.equiv SEA_T_B,   -9223372036854775808   /* comment */
.equiv SEA_T_C, 0xFFFFFFFFFFFFFFFF
.equiv SEA_T_D, -65536
.equiv SEA_T_E, 4294967296
.equiv SEA_T_F, 0
.equiv SEA_T_G, -1
.equiv SEA_T_H, 0x0
.equiv SEA_T_I, 1000000007
.equiv SEA_ENT_\name, \id
.endif
EOF
cat >"$D/rt.inc" <<'EOF'
.equiv SEA_T_Z, -2
EOF
printf '%s\n' \
    '// errors' \
    '.macro SEA_ERROR_LIST m' \
    '// a comment inside the macro' \
    '    \m 1, A_B, R, -, -, "a\\b\"c%d "' \
    '    \m 2, E2, C1, byte, s, ""' >"$D/errors.inc"
printf '    \\m 3, UTF, D, over, -, "caf\303\251 x"\n' >>"$D/errors.inc"
cat >>"$D/errors.inc" <<'EOF'
.endm
.macro SEA_ERRNO_LIST m
    \m 0, UNKNOWN, -1, -1, "unknown error"
    \m 1, EPERM, 1, 1, "Operation not permitted"
.endm
.equiv SEA_EXIT_OK,             0   /* success */
.equiv SEA_EXIT_X, 255
.equiv SEA_E_RT_END, 22
EOF
printf '%s\n' '; comment' '' 'enum e a b' 'head h' 'rec A 1 r 0 f:u' >"$D/passes.txt"

gen "$D" consts
check_eq "synthetic consts: exit status" 0 "$st"
cat >"$T/want" <<'EOF'
89000 DATA "T_A",32767,65535,65535,65535
89001 DATA "T_B",32768,0,0,0
89002 DATA "T_C",65535,65535,65535,65535
89003 DATA "T_D",65535,65535,65535,0
89004 DATA "T_E",0,1,0,0
89005 DATA "T_F",0,0,0,0
89006 DATA "T_G",65535,65535,65535,65535
89007 DATA "T_H",0,0,0,0
89008 DATA "T_I",0,0,15258,51719
89009 DATA "T_Z",65535,65535,65535,65534
89010 DATA "-"
EOF
cmp -s "$T/want" "$T/o" && pass || { fail "synthetic consts differ:"; diff "$T/want" "$T/o" >&2; }

gen "$D" errors errno exits
check_eq "synthetic errors/errno/exits: exit status" 0 "$st"
cat >"$T/want" <<'EOF'
89000 DATA 1,"A_B","R","-","-","a\b%22c%25d%20"
89001 DATA 2,"E2","C1","byte","s","%"
89002 DATA 3,"UTF","D","over","-","caf%C3%A9%20x"
89003 DATA -1
89004 DATA 0,"UNKNOWN",-1,-1,"unknown%20error"
89005 DATA 1,"EPERM",1,1,"Operation%20not%20permitted"
89006 DATA -1
89007 DATA 0,"OK"
89008 DATA 255,"X"
89009 DATA -1
EOF
cmp -s "$T/want" "$T/o" && pass || { fail "synthetic errors/errno/exits differ:"; diff "$T/want" "$T/o" >&2; }

gen "$D" records
check_eq "synthetic records: exit status" 0 "$st"
cat >"$T/want" <<'EOF'
89000 DATA "enum",3,"e","a","b"
89001 DATA "head",1,"h"
89002 DATA "rec",5,"A","1","r","0","f:u"
89003 DATA "end",0
EOF
cmp -s "$T/want" "$T/o" && pass || { fail "synthetic records differ:"; diff "$T/want" "$T/o" >&2; }

# --- the 255-byte limit: 255 bytes pass, 256 fail ---------------------------------------------
BASE='89018 DATA 19,"LINE_STYLE","R","-","s",""'
N=$((255 - ${#BASE}))
A=$(awk -v n="$N" 'BEGIN { for (i = 0; i < n; i++) s = s "a"; print s }')
D=$T/long255
copy_inc "$D"
replace_line "$D" errors.inc '    \m 19, ' "    \\m 19, LINE_STYLE, R, -, s, \"$A\""
gen "$D" errors
check_eq "255-byte DATA line accepted: exit status" 0 "$st"
check_eq "255-byte DATA line: its length" 255 "$(awk '$1 == 89018 { print length($0) }' "$T/o")"

D=$T/long256
copy_inc "$D"
replace_line "$D" errors.inc '    \m 19, ' "    \\m 19, LINE_STYLE, R, -, s, \"${A}a\""
gen "$D" errors
negative "256-byte DATA line" "more than 255"
if grep -Fq '(record 19)' "$T/e"; then pass; else fail "256-byte DATA line: the message does not name record 19: $(cat "$T/e")"; fi

D=$T/long300
copy_inc "$D"
A300=$(awk 'BEGIN { for (i = 0; i < 300; i++) s = s "a"; print s }')
replace_line "$D" errors.inc '    \m 19, ' "    \\m 19, LINE_STYLE, R, -, s, \"$A300\""
gen "$D" errors
negative "300-byte text" "more than 255"

# a passes.txt line whose DATA line would exceed 255 bytes
D=$T/longrec
copy_inc "$D"
printf 'rec A 999 long 0 %s\n' "$(awk 'BEGIN { for (i = 0; i < 30; i++) printf "field%02d:u ", i; print "last:u" }')" >>"$D/passes.txt"
gen "$D" records
negative "over-long passes.txt DATA line" "more than 255"

# --- malformed records and constants -> status 1 ------------------------------------------------
case_rec() { # NAME NEWLINE PATTERN
    D=$T/m_$1
    copy_inc "$D"
    replace_line "$D" errors.inc '    \m 19, ' "$2"
    gen "$D" errors
    negative "malformed error record: $1" "$3"
}
case_rec code     '    \m 19x, LINE_STYLE, R, -, s, "x"'        "not a canonical decimal"
case_rec zero     '    \m 019, LINE_STYLE, R, -, s, "x"'        "not a canonical decimal"
case_rec name     '    \m 19, line_style, R, -, s, "x"'         "not a name"
case_rec few      '    \m 19, LINE_STYLE, R, -, s'              "too few fields"
case_rec noquote  '    \m 19, LINE_STYLE, R, -, s, unquoted'    "not quoted"
case_rec open     '    \m 19, LINE_STYLE, R, -, s, "open'       "not quoted"
case_rec rawq     '    \m 19, LINE_STYLE, R, -, s, "say "hi""'  "unescaped quote"
case_rec escape   '    \m 19, LINE_STYLE, R, -, s, "bad \q"'    "bad escape"
case_rec lone     '    \m 19, LINE_STYLE, R, -, s, "end\"'      "lone backslash"
case_rec indent   '   \m 19, LINE_STYLE, R, -, s, "x"'          "not a comment, a record"
case_rec stray    'oops 19, LINE_STYLE, R, -, s, "x"'           "not a comment, a record"
case_rec empty    '    \m 19, LINE_STYLE, , -, s, "x"'          "forbidden byte"

D=$T/m_errno
copy_inc "$D"
replace_line "$D" errors.inc '    \m 5, EEXIST' '    \m 5, EEXIST, 17, x17, "File exists"'
gen "$D" errno
negative "errno record with a non-numeric field" "not a canonical decimal"

D=$T/m_unclosed
copy_inc "$D"
replace_line "$D" errors.inc '.macro SEA_ERRNO_LIST m' '.macro SEA_ERRNO_LISX m'
gen "$D" errno
negative "errno macro absent" "no records"

D=$T/m_entry
copy_inc "$D"
replace_line "$D" rt.inc '    \m 2, NOW' '    \m 2, NOW, sea_now, -, -, f, extra'
gen "$D" entries
negative "entry record with a seventh field" "too many fields"

D=$T/m_exit
copy_inc "$D"
replace_line "$D" errors.inc '.equiv SEA_EXIT_RUN_OK,' '.equiv SEA_EXIT_RUN_OK,         zero   /* x */'
gen "$D" exits
negative "exit status that is not a number" "canonical decimal"

case_const() { # NAME NEWLINE PATTERN
    D=$T/c_$1
    copy_inc "$D"
    replace_line "$D" limits.inc '.equiv SEA_LIM_NODES,' "$2"
    gen "$D" consts
    negative "malformed constant: $1" "$3"
}
case_const junk      '.equiv SEA_LIM_NODES,          99999x'                   "decimal or upper-case 0x"
case_const lowerhex  '.equiv SEA_LIM_NODES,          0xff'                     "decimal or upper-case 0x"
case_const bigdec    '.equiv SEA_LIM_NODES,          9223372036854775808'      "does not fit 64 bits"
case_const bigneg    '.equiv SEA_LIM_NODES,          -9223372036854775809'     "does not fit 64 bits"
case_const bighex    '.equiv SEA_LIM_NODES,          0x10000000000000000'      "more than 16 digits"
case_const nohex     '.equiv SEA_LIM_NODES,          0x'                       "no digits"
case_const nodigit   '.equiv SEA_LIM_NODES,          -'                        "no digits"
case_const expr      '.equiv SEA_LIM_NODES,          SEA_LIM_SYMBOLS+1'        "decimal or upper-case 0x"
case_const nospace   '.equiv SEA_LIM_NODES,99999'                              "needs a blank"
case_const novalue   '.equiv SEA_LIM_NODES, '                                  "has no value"
case_const trailing  '.equiv SEA_LIM_NODES,          99999   // not a comment' "not a /* ... */ comment"
case_const openc     '.equiv SEA_LIM_NODES,          99999   /* open'        "not a /* ... */ comment"

D=$T/p_dblspace
copy_inc "$D"
replace_line "$D" passes.txt 'rec A 1 prog' 'rec A 1  prog n n:u'
gen "$D" records
negative "passes.txt line with a doubled blank" "empty field"

D=$T/p_trail
copy_inc "$D"
replace_line "$D" passes.txt 'rec A 1 prog' 'rec A 1 prog n n:u '
gen "$D" records
negative "passes.txt line with a trailing blank" "empty field"

D=$T/p_kind
copy_inc "$D"
replace_line "$D" passes.txt 'rec A 1 prog' 'recs A 1 prog n n:u'
gen "$D" records
negative "passes.txt line of an unknown kind" "not empty, a ; comment, enum, head or rec"

D=$T/p_few
copy_inc "$D"
replace_line "$D" passes.txt 'rec A 1 prog' 'rec A 1'
gen "$D" records
negative "passes.txt rec line without op and pops" "too few fields"

# --- the selection on standard input ------------------------------------------------------------
gen "$INC" bogus
negative "unknown block" "unknown block"
gen "$INC" "errors "
negative "block name with a trailing blank" "unknown block"
gen "$INC" records errors
negative "blocks out of order" "at most once, in the order"
gen "$INC" errors errors
negative "a block twice" "at most once, in the order"
(cd "$INC" && "$T/gendata" </dev/null >"$T/o" 2>"$T/e")
st=$?
negative "empty selection" "empty selection"

# a missing contract file stops the generator with status 1 (Baysick's CAN'T OPEN FILE)
D=$T/missing
mkdir -p "$D"
gen "$D" errors
if [ "$st" -eq 1 ]; then pass; else fail "missing errors.inc: expected exit status 1, got $st"; fi

# --- the mtab block (DESIGN.md 2.6.3, 4.10.3): the pow words of math_tables.inc ----------------
# expected lines derived here with awk from the label and word lines of the real file
mtab_want() {
    awk -v start="$2" '
        function flush() { if (nw > 0) { printf "%d DATA %s\n", ln++, line; line = ""; nw = 0 } }
        /^sea_mt_[a-z]+:$/ { flush(); t = substr($0, 8, length($0) - 8); next }
        /^    \.quad 0x[0-9A-F]{16}$/ {
            if (t != "const" && t != "exp" && t != "log") next
            h = substr($0, 13, 16); s = ""
            for (i = 0; i < 4; i++) {
                v = 0
                for (j = 1; j <= 4; j++) v = v * 16 + index("0123456789ABCDEF", substr(h, 4 * i + j, 1)) - 1
                s = s (i ? "," : "") v
            }
            line = line (nw ? "," : "") s; nw++
            if (nw == 8) flush()
        }
        BEGIN { ln = start + 1; printf "%d DATA 32,128,128\n", start }
        END { flush(); printf "%d DATA -1\n", ln }' "$1"
}
gen "$INC" mtab
check_eq "mtab: exit status" 0 "$st"
check_eq "mtab: line count" 86 "$(wc -l <"$T/o" | tr -d ' ')"
mtab_want "$INC/math_tables.inc" 89000 >"$T/want"
cmp -s "$T/want" "$T/o" && pass || { fail "mtab block differs from the words of math_tables.inc:"; diff "$T/want" "$T/o" | head -5 >&2; }
has "89000 DATA 32,128,128"
has "89085 DATA -1"
# word 0 of sea_mt_const is EXP_INVLN2N = #40671547652B82FE (DESIGN.md 4.10.4); exp record 0 = #0, #3FF0000000000000
grep -q '^89001 DATA 16487,5447,25899,33534,' "$T/o" && pass || fail "mtab: EXP_INVLN2N is not the first word"
grep -q '^89005 DATA 0,0,0,0,16368,0,0,0,' "$T/o" && pass || fail "mtab: exp record 0 does not start line 89005"
awk 'length($0) > 202 { bad = 1 } END { exit bad }' "$T/o" && pass || fail "mtab: a line longer than 202 bytes"
# after the other blocks: numbering continues across blocks, mtab last
gen "$INC" records mtab
check_eq "records + mtab: exit status" 0 "$st"
check_eq "records + mtab: the mtab block ends the output" "DATA -1" "$(tail -1 "$T/o" | cut -d' ' -f2-)"
gen "$INC" mtab records
negative "mtab before records" "at most once, in the order"
# negative cases on a private copy of math_tables.inc
D=$T/mt
copy_inc "$D"
awk '/^    \.quad 0x/ && !done && t == "exp" { done = 1; next } /^sea_mt_/ { t = substr($0, 8, length($0) - 8) } { print }' \
    "$INC/math_tables.inc" >"$D/math_tables.inc"
gen "$D" mtab
negative "mtab: sea_mt_exp one word short" "has 255 words, not 256"
awk '/^sea_mt_log:$/ { print "sea_mt_lag:"; next } { print }' "$INC/math_tables.inc" >"$D/math_tables.inc"
gen "$D" mtab
negative "mtab: no sea_mt_log" "lacks one of the tables"
awk '/^sea_mt_exp:$/ { print "sea_mt_log:"; next } /^sea_mt_log:$/ { print "sea_mt_exp:"; next } { print }' \
    "$INC/math_tables.inc" >"$D/math_tables.inc"
gen "$D" mtab
negative "mtab: tables out of order" "must come once each, in this order"
rm -f "$D/math_tables.inc"
gen "$D" mtab
if [ "$st" -eq 1 ]; then pass; else fail "missing math_tables.inc: expected exit status 1, got $st"; fi
gen "$D" errors
check_eq "no math_tables.inc, mtab not selected: exit status" 0 "$st"

# --- result ---------------------------------------------------------------------------------
if [ "$fails" -ne 0 ]; then
    echo "check_data: $fails of $((checks + fails)) checks FAILED" >&2
    exit 1
fi
echo "check_data: $checks checks passed"
exit 0
