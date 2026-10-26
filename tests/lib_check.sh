#!/bin/sh
# lib_check.sh -- tests of the shared pass modules passes/lib/{io,diag,tables,layout,ralloc}.bas and of the
# intermediate-file validator tools/seaval.bas (docs/DESIGN.md 2.2, 2.6.2, 2.6.3, 3, 3.9).
#
#   sh tests/lib_check.sh [-v]            (make test-lib)
#   environment: BAYSICK = the Baysick checkout (default: the parent of sea/), BUILD = the build
#   directory (default sea/build; only used to find an already built tools/gendata).
#
# Everything is built in a temporary directory with the concatenation model of DESIGN 2.6.3:
# a program = its own file(s), then the modules it uses, then the generated DATA blocks, then
# "99999 END". The DATA comes from tools/gendata (build/tools/gendata if present, else compiled
# here from tools/gendata.bas). Test programs ("harnesses") are written below as here-documents:
#   unit   one command per input line: the field encodings and the splitting of io.bas
#   proto  io_hdr, io_read, io_end: the header and the end-of-input discipline
#   copy   io_hdr_put, io_put, io_fin: a copy of a file is the file
#   diag   dg_compile / dg_internal: the diagnostics of DESIGN 2.6.2
#   tab    the loaders of tables.bas against counts taken from the contract files, tb_cval
#   boot   a table that does not fit: BAD_DATA
#   lay    layout.bas: the struct layout rule of DESIGN 4.8 (sizes, offsets, reference offsets)
#   ra     ralloc.bas: the register allocator of DESIGN 4.9.2 (intervals, scan, slots, moves)
# and the validator tools/seaval.bas is run on the dump examples of DESIGN 3.4, 3.5.8 and 3.6.7
# (taken from the document itself) and on mutated copies, which it must reject with status 11.
#
# Expected values come from the specification (DESIGN.md, LANGUAGE.md, the contract files), never
# from what the modules print. Exit status 0 if every check passed, else 1.

SEA=$(cd "$(dirname "$0")/.." && pwd) || exit 2
BAYSICK=${BAYSICK:-$SEA/..}
BAYSICK=$(cd "$SEA" && cd "$BAYSICK" && pwd) || { echo "lib_check: BAYSICK=$BAYSICK is not a directory" >&2; exit 2; }
BUILD=${BUILD:-$SEA/build}
case "$BUILD" in /*) ;; *) BUILD=$SEA/$BUILD ;; esac
VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

BSK=$BAYSICK/build/baysick
[ -x "$BSK" ] || { echo "lib_check: $BSK not found: run make in $BAYSICK first" >&2; exit 2; }
DOC=$SEA/docs/DESIGN.md

T=$(mktemp -d "${TMPDIR:-/tmp}/sea-libchk.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT INT TERM
mkdir -p "$T/gd" "$T/ex" "$T/mut"
PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    [ $VERBOSE -eq 1 ] && printf 'ok   %s\n' "$1"
    return 0
}
bad() {
    FAIL=$((FAIL + 1))
    printf 'FAIL %s\n' "$1"
    shift
    for m in "$@"; do printf '       %s\n' "$m"; done
    return 0
}

# ---- the DATA generator and the build of a program --------------------------------------------
cp "$SEA/include/limits.inc" "$SEA/include/errors.inc" "$SEA/include/rt.inc" "$SEA/include/passes.txt" "$T/gd/"
if [ -x "$BUILD/tools/gendata" ]; then
    GENDATA=$BUILD/tools/gendata
else
    GENDATA=$T/gendata
    "$BSK" "$SEA/tools/gendata.bas" -o "$GENDATA" || { echo "lib_check: cannot compile tools/gendata.bas" >&2; exit 2; }
fi

# build NAME MAIN BLOCK...: $T/NAME = MAIN + io diag tables + the DATA BLOCKs (canonical order given) + END
build() {
    name=$1
    main=$2
    shift 2
    cat "$main" "$SEA/passes/lib/io.bas" "$SEA/passes/lib/diag.bas" "$SEA/passes/lib/tables.bas" > "$T/$name.bas"
    if [ $# -gt 0 ]; then
        printf '%s\n' "$@" | (cd "$T/gd" && "$GENDATA" 89000) >> "$T/$name.bas" || { echo "lib_check: gendata failed for $name" >&2; exit 2; }
    fi
    echo "99999 END" >> "$T/$name.bas"
    "$BSK" "$T/$name.bas" -o "$T/$name" || { echo "lib_check: cannot compile $name" >&2; exit 2; }
}

# run PROG INPUT: stdout in $T/out, stderr in $T/err, status in $rc
runp() {
    "$1" < "$2" > "$T/out" 2> "$T/err"
    rc=$?
}

# expect DESC PROG INPUT RC OUTFILE ERRFILE: status, stdout and stderr must be exactly as given
expect() {
    runp "$2" "$3"
    if [ "$rc" -eq "$4" ] && cmp -s "$T/out" "$5" && cmp -s "$T/err" "$6"; then
        ok "$1"
    else
        bad "$1" "status $rc (wanted $4)" "stdout differs: $(diff "$5" "$T/out" | head -6 | tr '\n' '|' | cut -c1-300)" "stderr differs: $(diff "$6" "$T/err" | head -6 | tr '\n' '|' | cut -c1-300)"
    fi
}

# the text of an error of errors.inc by name (phase P and others): the last quoted field
errtext() {
    awk -v n="$1" '$0 ~ "^    \\\\m [0-9]+, " n ", " { s = $0; sub(/^[^"]*"/, "", s); sub(/"[^"]*$/, "", s); print s; exit }' "$SEA/include/errors.inc"
}

# limit VALUE of a .equiv SEA_NAME in limits.inc
limitof() {
    awk -v n="SEA_$1," '$1 == ".equiv" && $2 == n { print $3; exit }' "$SEA/include/limits.inc"
}

# ==============================================================================================
# 0. static checks of the module files (DESIGN 2.6.3 line ranges, Baysick limits)
# ==============================================================================================
chk_range() { # FILE FIRST LAST
    awk -v lo="$2" -v hi="$3" 'BEGIN { prev = 0 }
        { if ($1 !~ /^[0-9]+$/ || $1 + 0 < lo || $1 + 0 > hi || $1 + 0 <= prev || length($0) > 255) { print FILENAME ": line " NR ": " $0; bad = 1 } prev = $1 + 0 }
        $2 == "END" || $2 == "DATA" { print FILENAME ": line " NR ": a module has no END or DATA"; bad = 1 }
        END { exit bad }' "$1"
}
for spec in "passes/lib/io.bas 60000 62999" "passes/lib/diag.bas 63000 65999" "passes/lib/tables.bas 66000 68999" "passes/lib/lirrw.bas 69000 81999" "passes/lib/limb.bas 69000 74999" "passes/lib/f64emu.bas 75000 81999" "passes/lib/fltlit.bas 82000 85999" "passes/lib/layout.bas 86000 86999" "passes/lib/ralloc.bas 87000 88999" "tools/seaval.bas 1 59999"; do
    set -- $spec
    if [ ! -f "$SEA/$1" ]; then bad "module $1 exists"; continue; fi
    if msg=$(chk_range "$SEA/$1" "$2" "$3"); then ok "$1: line numbers $2-$3 ascending, lines <= 255 bytes, no END or DATA"; else bad "$1: line numbers $2-$3 ascending, lines <= 255 bytes, no END or DATA" "$msg"; fi
done
# lirrw.bas is a main-program part (DESIGN 2.6.3, L-bi): it holds no SUB
if grep -n '^[0-9]* SUB ' "$SEA/passes/lib/lirrw.bas" > "$T/lrsub"; then bad "passes/lib/lirrw.bas: a main-program part holds no SUB" "$(cat "$T/lrsub")"; else ok "passes/lib/lirrw.bas: holds no SUB"; fi
# the long-string work lists are sized by SEA_LIM_RECORD_BYTES
rb=$(limitof LIM_RECORD_BYTES)
n=$(grep -c "DIM W($rb)" "$SEA/passes/lib/io.bas")
if [ "$n" -eq 3 ]; then ok "io.bas: the three long work lists are DIM W(SEA_LIM_RECORD_BYTES = $rb)"; else bad "io.bas: three DIM W($rb) expected, found $n"; fi
# at most 16 parameters per SUB, one SUB name per SUB line (Baysick LANGUAGE 7.27)
if awk '/^[0-9]+ SUB / { s = $0; sub(/^[0-9]+ SUB "[^"]*"(: )?/, "", s); k = (s == "") ? 0 : gsub(/, /, ", ", s) + 1; if (k > 16) { print "line " NR ": " k " parameters"; bad = 1 } } END { exit bad }' \
    "$SEA/passes/lib/io.bas" "$SEA/passes/lib/diag.bas" "$SEA/passes/lib/tables.bas" "$SEA/passes/lib/limb.bas" "$SEA/passes/lib/f64emu.bas" "$SEA/passes/lib/fltlit.bas" "$SEA/passes/lib/layout.bas" "$SEA/passes/lib/ralloc.bas" > "$T/p16" 2>&1; then ok "modules: no SUB has more than 16 parameters"; else bad "modules: SUB with more than 16 parameters" "$(cat "$T/p16")"; fi

# ==============================================================================================
# 1. unit: field encodings and splitting (DESIGN 3.1)
# ==============================================================================================
cat > "$T/h_unit.bas" <<'EOF'
10 REM unit harness: one command per standard-input line, "<cmd> <argument>"
20 DIM W(300), L(4), F$(20)
30 IF END #0 THEN 990
40 LINPUT #0, L$
50 LET P = POS(L$, " ")
60 LET C$ = SEG$(L$, 1, P - 1)
70 LET A$ = SEG$(L$, P + 1, LEN(L$))
80 IF C$ = "E0" THEN 200
90 IF C$ = "E1" THEN 210
100 IF C$ = "D0" THEN 300
110 IF C$ = "D1" THEN 310
120 IF C$ = "U" THEN 400
130 IF C$ = "I" THEN 500
140 IF C$ = "F" THEN 600
150 IF C$ = "P" THEN 700
160 IF C$ = "S" THEN 800
170 IF C$ = "X" THEN 900
175 IF C$ = "H" THEN 950
176 IF C$ = "PL" THEN 960
180 PRINT "BAD COMMAND " & C$
185 STOP 3
200 CALL "io_esc": A$, 0, R$
205 GOTO 280
210 CALL "io_esc": A$, 1, R$
280 PRINT "[" & R$ & "]"
290 GOTO 30
300 CALL "io_unesc": A$, 0, R$, T
305 GOTO 320
310 CALL "io_unesc": A$, 1, R$, T
320 LET Q$ = "T=" & STR$(T) & " len=" & STR$(LEN(R$)) & " codes:"
330 IF LEN(R$) = 0 THEN 380
340 CHANGE R$ TO W
350 FOR I = 1 TO W(0)
360 LET Q$ = Q$ & " " & STR$(W(I))
370 NEXT I
380 PRINT Q$
390 GOTO 30
400 CALL "io_u": A$, V, T
410 PRINT "T=" & STR$(T) & " V=" & STR$(V)
420 GOTO 30
500 CALL "io_i": A$, V, K, L(), T
510 PRINT "T=" & STR$(T) & " K=" & STR$(K) & " V=" & STR$(V) & " L=" & STR$(L(1)) & "," & STR$(L(2)) & "," & STR$(L(3)) & "," & STR$(L(4))
520 GOTO 30
600 CALL "io_f": A$, L(), T
610 PRINT "T=" & STR$(T) & " L=" & STR$(L(1)) & "," & STR$(L(2)) & "," & STR$(L(3)) & "," & STR$(L(4))
620 GOTO 30
700 CALL "io_pos": A$, F, L1, C, T
710 PRINT "T=" & STR$(T) & " F=" & STR$(F) & " L=" & STR$(L1) & " C=" & STR$(C)
720 GOTO 30
800 CALL "io_site": A$, F, L1, T
810 PRINT "T=" & STR$(T) & " F=" & STR$(F) & " L=" & STR$(L1)
820 GOTO 30
900 CALL "io_split": A$, F$(), 20, N
910 LET Q$ = "N=" & STR$(N)
920 FOR I = 1 TO N
930 LET Q$ = Q$ & " [" & F$(I) & "]"
940 NEXT I
945 PRINT Q$
946 GOTO 30
950 LET L(1) = VAL(SEG$(A$, 1, POS(A$, ",") - 1))
951 LET A$ = SEG$(A$, POS(A$, ",") + 1, LEN(A$))
952 LET L(2) = VAL(SEG$(A$, 1, POS(A$, ",") - 1))
953 LET A$ = SEG$(A$, POS(A$, ",") + 1, LEN(A$))
954 LET L(3) = VAL(SEG$(A$, 1, POS(A$, ",") - 1))
955 LET L(4) = VAL(SEG$(A$, POS(A$, ",") + 1, LEN(A$)))
956 CALL "io_hex": L(), R$
957 PRINT R$
958 GOTO 30
960 CALL "io_plain": A$, O
961 PRINT "O=" & STR$(O)
962 GOTO 30
990 STOP
EOF
build unit "$T/h_unit.bas" errors

# input / expected output pairs, line by line (DESIGN 3.1 field types and escaping)
{
    printf 'E0 hello world\n'
    printf 'E0 100%%\n'
    printf 'E0 a"b\n'
    printf 'E1 a"b\n'
    printf 'E0 \n'
    printf 'E0 \303\251\n'
    printf 'E0 tab\there\n'
    printf 'D0 hello%%20world\n'
    printf 'D0 %%\n'
    printf 'D0 %%25\n'
    printf 'D0 a%%2\n'
    printf 'D0 %%zz\n'
    printf 'D0 %%2a\n'
    printf 'D0 %%41\n'
    printf 'D0 %%22\n'
    printf 'D1 %%22\n'
    printf 'D1 a"b\n'
    printf 'D0 \n'
    printf 'D0 a b\n'
    printf 'D0 %%0A\n'
    printf 'D0 %%C3%%A9\n'
    printf 'D0 a%%\n'
    printf 'U 0\nU 007\nU 123456789\nU 1234567890\nU \nU 12a\nU -1\n'
    printf 'I 0\nI -5\nI -0\nI 999999999\nI -999999999\nI 1000000000\n'
    printf 'I #FFFFFFFFC4653600\nI #000000003B9ACA00\nI #0000000000000005\nI #FFFFFFFFFFFFFFFF\n'
    printf 'I #ffffffffc4653600\nI #FFFFFFFFC4653601\nI #8000000000000000\nI #FFFFFFFFC4653600 \nI #FFFFFFFFC46536\n'
    printf 'F #3FB999999999999A\nF #8000000000000000\nF #3fb999999999999a\nF 3FB999999999999A\nF #3FB999999999999\n'
    printf 'P 0:2:8\nP 1:1:1\nP 0:0:1\nP 0:1:0\nP 0:1\nP 0:1:2:3\nP 0:1:\nP :1:1\nP 00:1:1\n'
    printf 'S 0:3\nS 0:3:4\nS 0:0\nS :3\nS 0:\n'
    printf 'X a b c\nX a  b\nX  a\nX a \nX \nX abc\nX a b\n'
    printf 'H 16313,39321,39321,39322\nH 0,0,0,0\nH 32768,255,4096,65535\n'
    printf 'PL hello\nPL a\tb\nPL \nPL \303\251\n'
} > "$T/unit.in"
cat > "$T/unit.exp" <<'EOF'
[hello%20world]
[100%25]
[a"b]
[a%22b]
[%]
[%C3%A9]
[tab%09here]
T=0 len=11 codes: 104 101 108 108 111 32 119 111 114 108 100
T=0 len=0 codes:
T=0 len=1 codes: 37
T=1 len=0 codes:
T=1 len=0 codes:
T=1 len=0 codes:
T=2 len=0 codes:
T=2 len=0 codes:
T=0 len=1 codes: 34
T=2 len=0 codes:
T=1 len=0 codes:
T=2 len=0 codes:
T=0 len=1 codes: 10
T=0 len=2 codes: 195 169
T=1 len=0 codes:
T=0 V=0
T=1 V=0
T=0 V=123456789
T=1 V=0
T=1 V=0
T=1 V=0
T=1 V=0
T=0 K=0 V=0 L=0,0,0,0
T=0 K=0 V=-5 L=65535,65535,65535,65531
T=1 K=0 V=0 L=0,0,0,0
T=0 K=0 V=999999999 L=0,0,15258,51711
T=0 K=0 V=-999999999 L=65535,65535,50277,13825
T=1 K=0 V=0 L=0,0,0,0
T=0 K=1 V=0 L=65535,65535,50277,13824
T=0 K=1 V=0 L=0,0,15258,51712
T=1 K=0 V=0 L=0,0,0,0
T=1 K=0 V=0 L=0,0,0,0
T=1 K=0 V=0 L=0,0,0,0
T=1 K=0 V=0 L=0,0,0,0
T=0 K=1 V=0 L=32768,0,0,0
T=1 K=0 V=0 L=0,0,0,0
T=1 K=0 V=0 L=0,0,0,0
T=0 L=16313,39321,39321,39322
T=0 L=32768,0,0,0
T=1 L=0,0,0,0
T=1 L=0,0,0,0
T=1 L=0,0,0,0
T=0 F=0 L=2 C=8
T=0 F=1 L=1 C=1
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=1 F=0 L=0 C=0
T=0 F=0 L=3
T=1 F=0 L=0
T=1 F=0 L=0
T=1 F=0 L=0
T=1 F=0 L=0
N=3 [a] [b] [c]
N=-1
N=-1
N=-1
N=-1
N=1 [abc]
N=2 [a] [b]
#3FB999999999999A
#0000000000000000
#800000FF1000FFFF
O=1
O=0
O=1
O=0
EOF
expect "unit: escapes, numbers, positions, splitting (DESIGN 3.1)" "$T/unit" "$T/unit.in" 0 "$T/unit.exp" /dev/null

# ==============================================================================================
# 2. proto: the header and the end-of-input discipline (DESIGN 2.2 step 6, 3.2)
# ==============================================================================================
cat > "$T/h_proto.bas" <<'EOF'
10 REM protocol harness: header, records until #end, then the end check
20 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8), H$(20)
30 DIM C(299,4), C$(299)
40 LET P$ = "proto"
50 CALL "tb_errors": P$, E(), E$(), 299, E0
60 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N5
70 LET Z(1) = 39
80 LET Z(2) = 299
90 LET Z(3) = 399
100 LET Z(4) = 1499
110 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
120 CALL "tb_cval": C(), C$(), N5, "FILE_VERSION", V, T
130 IF T = 0 THEN 150
140 CALL "dg_bug": P$, "FILE_VERSION missing"
150 CALL "io_hdr": 0, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V, T$, H$(), 20, N1, L$
160 PRINT "version " & STR$(V) & " target " & T$ & " files " & STR$(N1)
170 FOR I = 1 TO N1
180 PRINT "file " & STR$(I - 1) & " [" & H$(I) & "]"
190 NEXT I
200 LET L9 = N1 + 3
210 IF L$ = "#end" THEN 260
220 PRINT "rec " & L$
230 CALL "io_read": 0, L$, L9, P$, E(), E$(), E0
240 GOTO 210
260 CALL "io_end": 0, P$, E(), E$(), E0
270 PRINT "lines " & STR$(L9)
280 STOP
EOF
build proto "$T/h_proto.bas" errors consts records

printf '#sea 1\n#target arm64-macos\n#file ex.sea\n#file my%%20file.sea\nint 0:1:1 5\nprog 1\n#end\n' > "$T/proto1.in"
cat > "$T/proto1.exp" <<'EOF'
version 1 target arm64-macos files 2
file 0 [ex.sea]
file 1 [my file.sea]
rec int 0:1:1 5
rec prog 1
lines 7
EOF
expect "proto: a valid file: header, records, #end, nothing after" "$T/proto" "$T/proto1.in" 0 "$T/proto1.exp" /dev/null
printf '#sea 1\n#target x86_64-linux\n#end\n' > "$T/proto2.in"
printf 'version 1 target x86_64-linux files 0\nlines 3\n' > "$T/proto2.exp"
expect "proto: no #file records, empty body" "$T/proto" "$T/proto2.in" 0 "$T/proto2.exp" /dev/null
# a record that begins #files is a body record, not a header record
printf '#sea 1\n#target arm64-macos\n#files x\n#end\n' > "$T/proto3.in"
printf 'version 1 target arm64-macos files 0\nrec #files x\nlines 4\n' > "$T/proto3.exp"
expect "proto: #files is not a #file record" "$T/proto" "$T/proto3.in" 0 "$T/proto3.exp" /dev/null

# rejected inputs: status 11, stdout as far as the program got, stderr = the note + the text of errors.inc
TR=$(errtext TRUNCATED)
BH=$(errtext BAD_HEADER)
BR=$(errtext BAD_RECORD)
proto_rej() { # DESC INPUTFILE STDOUT_EXPECTED_FILE NOTE ERRTEXT
    printf 'proto: %s\n' "$5" > "$T/exp.err"
    expect "$1" "$T/proto" "$2" 11 "$3" "$T/exp.err"
}
printf '#sea 2\n#target arm64-macos\n#end\n' > "$T/p.in"
proto_rej "proto: wrong version -> BAD_HEADER, line 1" "$T/p.in" /dev/null "header line 1: expected '#sea' and the format version" "$BH"
printf '#sea 1\n#target riscv\n#end\n' > "$T/p.in"
proto_rej "proto: unknown target -> BAD_HEADER, line 2" "$T/p.in" /dev/null "header line 2: unknown target 'riscv'" "$BH"
printf '#sea 1\n#file a\n' > "$T/p.in"
proto_rej "proto: #target missing -> BAD_HEADER" "$T/p.in" /dev/null "header line 2: expected '#target' and a target name" "$BH"
printf '#sea 1\n#target arm64-macos\n#file\n#end\n' > "$T/p.in"
proto_rej "proto: #file without a path -> BAD_HEADER" "$T/p.in" /dev/null "header line 3: malformed #file record" "$BH"
printf '#sea 1\n#target arm64-macos\n#file a b\n#end\n' > "$T/p.in"
proto_rej "proto: #file with two fields -> BAD_HEADER" "$T/p.in" /dev/null "header line 3: malformed #file record" "$BH"
printf '#sea 1\n#target arm64-macos\n#file a%%zz\n#end\n' > "$T/p.in"
proto_rej "proto: bad escape in a path -> BAD_HEADER" "$T/p.in" /dev/null "header line 3: bad path escape in #file record" "$BH"
printf '#sea 1\n#target arm64-macos\n#file a\nint 0:1:1 5\n' > "$T/p.in"
printf 'version 1 target arm64-macos files 1\nfile 0 [a]\nrec int 0:1:1 5\n' > "$T/p.out"
proto_rej "proto: input ends before #end -> TRUNCATED (status 11)" "$T/p.in" "$T/p.out" "input ends after line 4" "$TR"
: > "$T/p.in"
proto_rej "proto: empty input -> TRUNCATED" "$T/p.in" /dev/null "input ends after line 0" "$TR"
printf '#sea 1\n#target arm64-macos\n' > "$T/p.in"
proto_rej "proto: input ends inside the header -> TRUNCATED" "$T/p.in" /dev/null "input ends after line 2" "$TR"
printf '#sea 1\n#target arm64-macos\n#end\nint 0:1:1 5\n' > "$T/p.in"
printf 'version 1 target arm64-macos files 0\n' > "$T/p.out"
proto_rej "proto: a record after #end -> BAD_RECORD" "$T/p.in" "$T/p.out" "records follow #end" "$BR"
# io_file: a pass-1 reader appends the later #file records (interleaved with source lines, DESIGN 3.2)
cat > "$T/h_file.bas" <<'EOF'
20 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), R(399,9), R$(399), F(1499,3), F$(1499), Z(8), H$(5)
30 DIM C(299,4), C$(299)
40 LET P$ = "file"
50 CALL "tb_errors": P$, E(), E$(), 299, E0
60 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N5
70 LET Z(1) = 39
80 LET Z(2) = 299
90 LET Z(3) = 399
100 LET Z(4) = 1499
110 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()
120 CALL "tb_cval": C(), C$(), N5, "FILE_VERSION", V, T
130 CALL "io_hdr": 0, P$, E(), E$(), E0, N(), N$(), W$(), Z(5), V, T$, H$(), 5, N1, L$
140 PRINT "header " & STR$(N1)
150 IF L$ = "#end" THEN 220
160 CALL "io_file": P$, E(), E$(), E0, L$, H$(), 5, N1, Y
170 IF Y = 0 THEN 190
180 PRINT "file " & STR$(N1 - 1) & " [" & H$(N1) & "]"
185 GOTO 200
190 PRINT "rec " & L$
200 CALL "io_read": 0, L$, L9, P$, E(), E$(), E0
210 GOTO 150
220 CALL "io_end": 0, P$, E(), E$(), E0
230 PRINT "files " & STR$(N1)
240 STOP
EOF
build file "$T/h_file.bas" errors consts records
printf '#sea 1\n#target arm64-macos\n#file a.sea\n|x\n#file my%%20b.sea\n|y\n#files z\n#end\n' > "$T/f1.in"
printf 'header 1\nrec |x\nfile 1 [my b.sea]\nrec |y\nrec #files z\nfiles 2\n' > "$T/f1.exp"
expect "io_file: a later #file record is appended to F\$() and N1; #files and body lines are not" "$T/file" "$T/f1.in" 0 "$T/f1.exp" /dev/null
printf '#sea 1\n#target arm64-macos\n#file a\n|x\n#file\n#end\n' > "$T/f2.in"
printf 'header 1\nrec |x\n' > "$T/f2.exp"
printf 'file: %s\n' "$BH" > "$T/f2.err"
expect "io_file: a #file record without a path -> BAD_HEADER" "$T/file" "$T/f2.in" 11 "$T/f2.exp" "$T/f2.err"
printf '#sea 1\n#target arm64-macos\n#file a\n|x\n#file b\n|x\n#file c\n|x\n#file d\n|x\n#file e\n|x\n#file f\n#end\n' > "$T/f3.in"
printf 'header 1\nrec |x\nfile 1 [b]\nrec |x\nfile 2 [c]\nrec |x\nfile 3 [d]\nrec |x\nfile 4 [e]\nrec |x\n' > "$T/f3.exp"
expect "io_file: more #file records than the capacity -> BAD_HEADER" "$T/file" "$T/f3.in" 11 "$T/f3.exp" "$T/f2.err"


# ==============================================================================================
# 3. copy: io_hdr_put / io_put / io_fin write what io_hdr / io_read read
# ==============================================================================================
sed -e '/^160 /,/^190 /d' -e '/^200 /,/^270 /d' -e 's/^280 STOP$//' "$T/h_proto.bas" > "$T/h_copy.bas"
cat >> "$T/h_copy.bas" <<'EOF'
160 CALL "io_hdr_put": 0, V, T$, H$(), N1
200 LET L9 = N1 + 3
210 IF L$ = "#end" THEN 260
220 CALL "io_put": 0, L$
230 CALL "io_read": 0, L$, L9, P$, E(), E$(), E0
240 GOTO 210
260 CALL "io_end": 0, P$, E(), E$(), E0
270 CALL "io_fin": 0
280 STOP
EOF
build copy "$T/h_copy.bas" errors consts records
printf '#sea 1\n#target x86_64-linux\n#file /tmp/a%%20b/%%25x%%0Ay.sea\n#file \303\251.sea\n#file %%\nstr 0:1:1 %%20%%25%%0A\nprog 1\n' > "$T/copy.in"
printf '#end\n' >> "$T/copy.in"
# the file with an escaped path is copied byte for byte (the path round-trips through decode and encode)
printf '#sea 1\n#target x86_64-linux\n#file /tmp/a%%20b/%%25x%%0Ay.sea\n#file %%C3%%A9.sea\n#file %%\nstr 0:1:1 %%20%%25%%0A\nprog 1\n#end\n' > "$T/copy.in"
expect "copy: header and records written back are the input" "$T/copy" "$T/copy.in" 0 "$T/copy.in" /dev/null

# ==============================================================================================
# 4. diag: compile errors and internal errors (DESIGN 2.6.2 Output, LANGUAGE 9.1)
# ==============================================================================================
cat > "$T/h_diag.bas" <<'EOF'
10 REM diagnostics harness: one line "KIND|NAME|FILE|LINE|COL|ARG|ARG..." on standard input
20 DIM E(299), E$(299,5), A$(8), G$(14), H$(3)
30 LET P$ = "dh"
40 CALL "tb_errors": P$, E(), E$(), 299, E0
50 LET H$(1) = "src/a b.sea"
60 LET H$(2) = "std.sea"
70 LINPUT #0, L$
90 LET K = 0
110 LET S = 1
120 LET Q = POS(L$, "|", S)
130 IF Q = 0 THEN 170
140 LET K = K + 1
150 LET G$(K) = SEG$(L$, S, Q - 1)
155 LET S = Q + 1
160 GOTO 120
170 LET K = K + 1
180 LET G$(K) = SEG$(L$, S, LEN(L$))
200 LET F = VAL(G$(3))
210 LET L = VAL(G$(4))
220 LET C = VAL(G$(5))
230 LET N2 = K - 5
240 FOR I = 1 TO N2
250 LET A$(I) = G$(I + 5)
260 NEXT I
270 IF G$(1) = "compile" THEN 300
280 CALL "dg_internal": P$, G$(2), E(), E$(), E0
290 STOP
300 CALL "dg_compile": P$, H$(), 2, F, L, C, G$(2), A$(), N2, E(), E$(), E0
310 STOP
EOF
build diag "$T/h_diag.bas" errors
diag_case() { # DESC INPUT RC STDERR-TEXT
    printf '%s\n' "$2" > "$T/d.in"
    printf '%s\n' "$4" > "$T/d.err"
    expect "diag: $1" "$T/diag" "$T/d.in" "$3" /dev/null "$T/d.err"
}
# LANGUAGE 9.1: <file>:<line>:<col>: error: <message>, status 10; the messages are those of errors.inc
diag_case "UNDECLARED, file 0" 'compile|UNDECLARED|0|3|7|nTraget' 10 "src/a b.sea:3:7: error: undeclared name 'nTraget'"
diag_case "TYPE_MISMATCH, file 1, two values" 'compile|TYPE_MISMATCH|1|10|2|f64|str' 10 'std.sea:10:2: error: type mismatch: expected f64, found str'
diag_case "FORMAT_ARG, a message with quotes (%22 in DATA)" 'compile|FORMAT_ARG|0|1|1|%d|an integer or f64|str' 10 'src/a b.sea:1:1: error: format "%d" expects an integer or f64, found str'
diag_case "a value containing %s is inserted, not rescanned" 'compile|UNDECLARED|0|3|7|a%sb' 10 "src/a b.sea:3:7: error: undeclared name 'a%sb'"
diag_case "no values" 'compile|NOT_EXHAUSTIVE|0|9|4' 10 'src/a b.sea:9:4: error: match is not exhaustive'
diag_case "a value that is the empty string" 'compile|UNDECLARED|0|3|7|' 10 "src/a b.sea:3:7: error: undeclared name ''"
diag_case "the capacity error (phase CX) is a compile error" 'compile|TOO_LARGE|1|2|3|nodes' 10 'std.sea:2:3: error: program too large: nodes'
diag_case "too few values -> bug in the pass, status 11" 'compile|UNDECLARED|0|3|7' 11 "dh: error 'UNDECLARED': 0 values for s"
diag_case "too many values -> status 11" 'compile|UNDECLARED|0|3|7|x|y' 11 "dh: error 'UNDECLARED': 2 values for s"
diag_case "unknown error name -> status 11" 'compile|NOPE|0|3|7' 11 "dh: error name 'NOPE' is not in the error table"
diag_case "a run-time error is no compile error" 'compile|INDEX_OOB|0|3|7|1|2|3' 11 "dh: error 'INDEX_OOB' is a run-time error, not a compile error"
diag_case "an internal check is no compile error" 'compile|TRUNCATED|0|3|7' 11 "dh: error 'TRUNCATED' is an internal check, not a compile error"
diag_case "file index beyond the header" 'compile|UNDECLARED|2|3|7|x' 11 'dh: position names file 2 but the header has 2'
diag_case "internal error TRUNCATED: <pass>: <text>, status 11" 'internal|TRUNCATED|0|0|0' 11 "dh: $TR"
diag_case "internal error BAD_RECORD" 'internal|BAD_RECORD|0|0|0' 11 "dh: $BR"
diag_case "internal error BAD_TREE" 'internal|BAD_TREE|0|0|0' 11 "dh: $(errtext BAD_TREE)"
diag_case "internal error BAD_DATA" 'internal|BAD_DATA|0|0|0' 11 "dh: $(errtext BAD_DATA)"
diag_case "a compile error name used as internal check" 'internal|UNDECLARED|0|0|0' 11 "dh: error 'UNDECLARED' is not an internal check (phase P)"
# the exit statuses come from the exits table (tb_exits -> E$(0,1), E$(0,2)), not from literals
cat > "$T/h_dx.bas" <<'EOF'
10 REM exits harness: tb_exits loaded, then the statuses in E$(0,1), E$(0,2) are overwritten
20 DIM E(299), E$(299,5), A$(2), F$(2), X(20), X$(20)
30 LET P$ = "dx"
40 CALL "tb_errors": P$, E(), E$(), 299, E0
50 CALL "tb_exits": P$, E(), E$(), E0, X(), X$(), 20, N
60 PRINT STR$(N) & " " & E$(0, 1) & " " & E$(0, 2)
70 LINPUT #0, L$
80 LET E$(0, 1) = "42"
90 LET E$(0, 2) = "43"
100 LET F$(1) = "f.sea"
110 IF L$ = "compile" THEN 140
120 CALL "dg_internal": P$, "TRUNCATED", E(), E$(), E0
130 STOP
140 LET A$(1) = "x"
150 CALL "dg_compile": P$, F$(), 1, 0, 1, 1, "UNDECLARED", A$(), 1, E(), E$(), E0
160 STOP
EOF
build dx "$T/h_dx.bas" errors exits
nx=$(awk '$1 == ".equiv" && $2 ~ /^SEA_EXIT_/ { n++ } END { print n }' "$SEA/include/errors.inc")
ei=$(awk '$1 == ".equiv" && $2 == "SEA_EXIT_PASS_INTERNAL," { print $3 }' "$SEA/include/errors.inc")
ec=$(awk '$1 == ".equiv" && $2 == "SEA_EXIT_PASS_COMPILE," { print $3 }' "$SEA/include/errors.inc")
printf '%s %s %s\n' "$nx" "$ei" "$ec" > "$T/dx.exp"
echo internal > "$T/dx.in"
runp "$T/dx" "$T/dx.in"
if [ "$rc" -eq 42 ] && [ "$(head -n 1 "$T/out")" = "$(cat "$T/dx.exp")" ]; then ok "diag: dg_internal stops with the PASS_INTERNAL status of the exits table (E\$(0,1) = $ei, overwritten to 42 -> status 42)"; else bad "diag: dg_internal takes its status from the exits table" "status $rc (wanted 42)" "stdout: $(head -c 120 "$T/out") / wanted: $(cat "$T/dx.exp")"; fi
echo compile > "$T/dx.in"
runp "$T/dx" "$T/dx.in"
if [ "$rc" -eq 43 ]; then ok "diag: dg_compile stops with the PASS_COMPILE status of the exits table (E\$(0,2) = $ec, overwritten to 43 -> status 43)"; else bad "diag: dg_compile takes its status from the exits table" "status $rc (wanted 43)"; fi
# the table-less paths keep the literals of the bootstrap exception: they must equal errors.inc
nb=$(grep -c '^[0-9]* STOP 11$' "$SEA/passes/lib/diag.bas")
nl=$(grep -c "^[0-9]* \(@[a-z_]*: \)\{0,1\}LET S = $ei\$" "$SEA/passes/lib/diag.bas")
nc=$(grep -c "^[0-9]* LET S = $ec\$" "$SEA/passes/lib/diag.bas")
ns=$(grep -c ' STOP [0-9]' "$SEA/passes/lib/diag.bas")
if [ "$ei" = 11 ] && [ "$ec" = 10 ] && [ "$nb" -eq 2 ] && [ "$nl" -eq 1 ] && [ "$nc" -eq 1 ] && [ "$ns" -eq 2 ]; then ok "diag.bas: the only literal statuses are dg_bug, dg_boot and the dg_exit fallback ($ei, $ec = SEA_EXIT_PASS_INTERNAL, _COMPILE of errors.inc)"; else bad "diag.bas: literal exit statuses" "internal=$ei compile=$ec STOP 11 lines=$nb fallback internal=$nl compile=$nc STOP literals=$ns"; fi



# ==============================================================================================
# 5. tab: every table loaded by tables.bas equals the contract file it was generated from
#    (DESIGN 2.6.2, 2.6.3, 3.9), the lookups, tb_cval, and the capacity error
# ==============================================================================================
cat > "$T/h_tab.bas" <<'EOF'
10 REM tables harness: loads every block and prints every row in a fixed format
20 DIM E(299), E$(299,5), R(99,3), R$(99,2), X(29), X$(29), C(299,4), C$(299), Y(99), Y$(99,5)
30 DIM N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
40 LET P$ = "th"
50 CALL "tb_errors": P$, E(), E$(), 299, E0
60 CALL "tb_errno": P$, E(), E$(), E0, R(), R$(), 99, N1
70 CALL "tb_exits": P$, E(), E$(), E0, X(), X$(), 29, N2
80 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, N3
90 CALL "tb_entries": P$, E(), E$(), E0, Y(), Y$(), 99, N4
100 LET Z(1) = 39
110 LET Z(2) = 299
120 LET Z(3) = 399
130 LET Z(4) = 1499
140 CALL "tb_records": P$, E(), E$(), E0, N(), N$(), W$(), Q(), Q$(), F(), F$(), Z()
150 FOR I = 1 TO E0
160 PRINT "E " & STR$(E(I)) & " " & E$(I, 1) & " " & E$(I, 2) & " " & E$(I, 3) & " " & E$(I, 4) & " " & E$(I, 5)
170 NEXT I
180 FOR I = 1 TO N1
190 PRINT "N " & STR$(R(I, 1)) & " " & R$(I, 1) & " " & STR$(R(I, 2)) & " " & STR$(R(I, 3)) & " " & R$(I, 2)
200 NEXT I
210 FOR I = 1 TO N2
220 PRINT "X " & STR$(X(I)) & " " & X$(I)
230 NEXT I
240 FOR I = 1 TO N3
250 PRINT "C " & C$(I) & " " & STR$(C(I, 1)) & "," & STR$(C(I, 2)) & "," & STR$(C(I, 3)) & "," & STR$(C(I, 4))
260 NEXT I
270 FOR I = 1 TO N4
280 PRINT "Y " & STR$(Y(I)) & " " & Y$(I, 1) & " " & Y$(I, 2) & " " & Y$(I, 3) & " " & Y$(I, 4) & " " & Y$(I, 5)
290 NEXT I
300 FOR I = 1 TO Z(5)
310 LET S$ = "EN " & N$(I) & " "
320 FOR K = 1 TO N(I, 2)
330 LET S$ = S$ & W$(N(I, 1) + K - 1) & ","
340 NEXT K
350 PRINT S$
360 NEXT I
370 FOR I = 1 TO Z(7)
380 LET S$ = "R " & STR$(Q(I, 1)) & " " & STR$(Q(I, 2)) & " " & Q$(I) & " "
390 FOR K = 1 TO Q(I, 5)
400 LET S$ = S$ & STR$(Q(I, 5 + K)) & ","
410 NEXT K
420 LET S$ = S$ & " |"
430 FOR K = Q(I, 3) TO Q(I, 3) + Q(I, 4) - 1
440 LET S$ = S$ & " " & F$(K) & ":" & STR$(F(K, 1)) & ":" & STR$(F(K, 2)) & ":" & STR$(F(K, 3))
450 NEXT K
460 PRINT S$
470 NEXT I
480 REM lookups
490 CALL "tb_enum": N$(), Z(5), "binop", H
500 CALL "tb_word": N(), W$(), H, "matmul", V
510 PRINT "binop words " & STR$(N(H, 2)) & " matmul at " & STR$(V)
520 CALL "tb_word": N(), W$(), H, "cat", V
530 PRINT "cat in binop " & STR$(V)
540 CALL "tb_enum": N$(), Z(5), "nosuchenum", H
550 PRINT "nosuchenum row " & STR$(H)
560 CALL "tb_find": C$(), N3, "FILE_VERSION", H
570 PRINT "FILE_VERSION row>0 " & STR$(SGN(H))
580 CALL "tb_cval": C(), C$(), N3, "FILE_VERSION", V, T
590 PRINT "FILE_VERSION " & STR$(V) & " status " & STR$(T)
600 CALL "tb_cval": C(), C$(), N3, "LIM_EXTENT", V, T
610 PRINT "LIM_EXTENT " & STR$(V - 2147 * 1000000) & " status " & STR$(T)
620 CALL "tb_cval": C(), C$(), N3, "NO_SUCH_CONSTANT", V, T
630 PRINT "NO_SUCH_CONSTANT " & STR$(V) & " status " & STR$(T)
640 REM tb_cval on limbs set here: 64-bit patterns, negative ones by two's complement
650 LET C$(1) = "K"
660 LET C(1, 1) = 65535
670 LET C(1, 2) = 65535
680 LET C(1, 3) = 65535
690 LET C(1, 4) = 65535
700 GOSUB 800
710 LET C(1, 3) = 50277
720 LET C(1, 4) = 13824
730 GOSUB 800
740 LET C(1, 1) = 31
750 LET C(1, 2) = 65535
760 LET C(1, 3) = 65535
770 LET C(1, 4) = 65535
775 GOSUB 800
776 LET C(1, 1) = 65504
777 LET C(1, 2) = 0
778 LET C(1, 3) = 0
779 LET C(1, 4) = 1
780 GOSUB 800
781 LET C(1, 1) = 32
782 LET C(1, 4) = 0
783 GOSUB 800
784 LET C(1, 1) = 32768
785 GOSUB 800
786 LET C(1, 1) = 0
787 LET C(1, 2) = 0
788 LET C(1, 3) = 15258
789 LET C(1, 4) = 51712
790 GOSUB 800
795 STOP
800 CALL "tb_cval": C(), C$(), 1, "K", V, T
810 LET H = INT(V / 16777216)
815 PRINT "limbs " & STR$(C(1, 1)) & "," & STR$(C(1, 2)) & "," & STR$(C(1, 3)) & "," & STR$(C(1, 4)) & " status " & STR$(T) & " value " & STR$(H) & "," & STR$(V - H * 16777216)
820 RETURN
EOF
build tab "$T/h_tab.bas" errors errno exits consts entries records
: > "$T/empty"

# expected output, from the contract files (an independent reading of them in awk)
{
    awk '
        /^\.macro SEA_ERROR_LIST m/ { on = 1; next }
        /^\.endm/ { on = 0 }
        on && /^    \\m / {
            s = $0; sub(/^    \\m /, "", s)
            for (k = 1; k <= 5; k++) { i = index(s, ", "); f[k] = substr(s, 1, i - 1); s = substr(s, i + 2) }
            sub(/^"/, "", s); sub(/"$/, "", s)
            out = ""; n = length(s)
            for (j = 1; j <= n; j++) { c = substr(s, j, 1); if (c == "\\") { j++; c = substr(s, j, 1) } out = out c }
            print "E " f[1] " " f[2] " " f[3] " " f[4] " " f[5] " " out
        }' "$SEA/include/errors.inc"
    awk '
        /^\.macro SEA_ERRNO_LIST m/ { on = 1; next }
        /^\.endm/ { on = 0 }
        on && /^    \\m / {
            s = $0; sub(/^    \\m /, "", s)
            for (k = 1; k <= 4; k++) { i = index(s, ", "); f[k] = substr(s, 1, i - 1); s = substr(s, i + 2) }
            sub(/^"/, "", s); sub(/"$/, "", s)
            print "N " f[1] " " f[2] " " f[3] " " f[4] " " s
        }' "$SEA/include/errors.inc"
    awk '$1 == ".equiv" && $2 ~ /^SEA_EXIT_[A-Z_]+,$/ { n = substr($2, 10); sub(/,$/, "", n); print "X " $3 " " n }' "$SEA/include/errors.inc"
    awk '
        function hex(s,   i, v) { v = 0; s = toupper(substr(s, 3)); for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789ABCDEF", substr(s, i, 1)) - 1; return v }
        function limbs(v,   neg, u, k, l, s) {
            neg = (v < 0); u = neg ? -v - 1 : v
            for (k = 4; k >= 1; k--) { l[k] = u % 65536; u = (u - l[k]) / 65536 }
            s = ""
            for (k = 1; k <= 4; k++) s = s (k > 1 ? "," : "") (neg ? 65535 - l[k] : l[k])
            return s
        }
        $1 == ".equiv" && $2 ~ /^SEA_[A-Za-z0-9_]+,$/ && $2 !~ /_INC,$/ {
            n = substr($2, 5); sub(/,$/, "", n)
            v = ($3 ~ /^0x/) ? hex($3) : $3 + 0
            print "C " n " " limbs(v)
        }' "$SEA/include/limits.inc" "$SEA/include/rt.inc"
    awk '
        /^\.macro SEA_ENTRY_LIST m/ { on = 1; next }
        /^\.endm/ { on = 0 }
        on && /^    \\m / {
            s = $0; sub(/^    \\m /, "", s)
            for (k = 1; k <= 5; k++) { i = index(s, ", "); f[k] = substr(s, 1, i - 1); s = substr(s, i + 2) }
            print "Y " f[1] " " f[2] " " f[3] " " f[4] " " f[5] " " s
        }' "$SEA/include/rt.inc"
    awk '
        BEGIN { nb = split("u i f s pos site fl ty lid fid cid iid blk lab slot reg ri rf rp rx ry rm", bt, " ") }
        function tcode(w,   i) { for (i = 1; i <= nb; i++) if (bt[i] == w) return i; return 100 + en[w] }
        $1 == "enum" { ne++; en[$2] = ne; s = "EN " $2 " "; for (i = 3; i <= NF; i++) s = s $i ","; print s; next }
        $1 == "head" || $1 == "rec" {
            if ($1 == "head") { set = 0; code = 0; op = $2; pops = "0"; f0 = 3 }
            else {
                set = ($2 == "A") ? 1 : ($2 == "H") ? 2 : ($2 == "H1") ? 3 : ($2 == "HF") ? 4 : ($2 == "L") ? 5 : ($2 == "LF") ? 6 : ($2 == "HL") ? 7 : -1
                code = $3; op = $4; pops = $5; f0 = 6
            }
            nf = 0; fl = ""
            for (i = f0; i <= NF; i++) {
                spec = $i; nf++
                p = index(spec, ":"); fname[nf] = substr(spec, 1, p - 1); rest = substr(spec, p + 1)
                rep = 0; q = index(rest, "*")
                if (q > 0) { cn = substr(rest, q + 1); rest = substr(rest, 1, q - 1); for (j = 1; j < nf; j++) if (fname[j] == cn) rep = j }
                opt = 0
                if (substr(rest, length(rest), 1) == "?") { opt = 1; rest = substr(rest, 1, length(rest) - 1) }
                fl = fl " " fname[nf] ":" tcode(rest) ":" opt ":" rep
            }
            np = split(pops, pt, "+"); terms = ""
            for (k = 1; k <= np; k++) {
                if (pt[k] ~ /^[0-9]+$/) t = pt[k] + 0
                else { t = 0; for (j = 1; j <= nf; j++) if (fname[j] == pt[k]) t = -j }
                terms = terms t ","
            }
            print "R " set " " code " " op " " terms " |" fl
        }' "$SEA/include/passes.txt"
    # the lookups and tb_cval; limbs for the crafted values are those set in the harness
    awk -v nw="$(awk '$1 == "enum" && $2 == "binop" { print NF - 2 }' "$SEA/include/passes.txt")" \
        -v mm="$(awk '$1 == "enum" && $2 == "binop" { for (i = 3; i <= NF; i++) if ($i == "matmul") print i - 2 }' "$SEA/include/passes.txt")" \
        -v fv="$(limitof FILE_VERSION)" 'BEGIN {
        print "binop words " nw " matmul at " mm
        print "cat in binop 0"
        print "nosuchenum row 0"
        print "FILE_VERSION row>0 1"
        print "FILE_VERSION " fv " status 0"
    }'
    echo "LIM_EXTENT $(( $(limitof LIM_EXTENT) - 2147000000 )) status 0"
    echo "NO_SUCH_CONSTANT 0 status 1"
    lv() { echo "limbs $1 status $2 value $(($3 / 16777216)),$(($3 - ($3 / 16777216) * 16777216))"; }
    lv 65535,65535,65535,65535 0 -1
    lv 65535,65535,50277,13824 0 -1000000000
    lv 31,65535,65535,65535 0 9007199254740991
    lv 65504,0,0,1 0 -9007199254740991
    lv 32,0,0,0 1 0
    lv 32768,0,0,0 1 0
    lv 0,0,15258,51712 0 1000000000
} > "$T/tab.exp"
runp "$T/tab" /dev/null
if [ "$rc" -eq 0 ] && [ ! -s "$T/err" ] && cmp -s "$T/out" "$T/tab.exp"; then
    ok "tab: errors, errno, exits, consts, entries, enums, records, lookups and tb_cval equal the contract files ($(wc -l < "$T/tab.exp" | tr -d ' ') rows)"
else
    bad "tab: tables differ from the contract files" "status $rc" "stderr: $(head -c 300 "$T/err")" "first difference: $(diff "$T/tab.exp" "$T/out" | head -4 | tr '\n' '|')"
fi

# a table that does not fit its capacity: BAD_DATA (DESIGN 2.2 step 6), status 11. The text of errors.inc
# comes out of the error table, except for tb_errors itself, which must print it without a table (dg_boot).
cat > "$T/h_boot.bas" <<'EOS'
10 REM capacity harness: standard input "1": tb_errors with room for 10 rows; "2": tb_errno with room for 3
20 DIM E(299), E$(299,5), R(99,3), R$(99,2)
30 LINPUT #0, M$
40 IF M$ = "1" THEN 100
50 CALL "tb_errors": "boot", E(), E$(), 299, E0
60 CALL "tb_errno": "boot", E(), E$(), E0, R(), R$(), 3, N1
70 PRINT "not reached"
80 STOP
100 CALL "tb_errors": "boot", E(), E$(), 10, E0
110 PRINT "not reached"
EOS
build boot "$T/h_boot.bas" errors errno
BD=$(errtext BAD_DATA)
echo 1 > "$T/b1.in"
echo 2 > "$T/b2.in"
printf 'boot: %s\n' "$BD" > "$T/b.err"
expect "boot: tb_errors with more rows than its capacity -> <pass>: BAD_DATA text of errors.inc, status 11" "$T/boot" "$T/b1.in" 11 /dev/null "$T/b.err"
expect "boot: tb_errno with more rows than its capacity -> BAD_DATA from the error table, status 11" "$T/boot" "$T/b2.in" 11 /dev/null "$T/b.err"

# ==============================================================================================
# 5b. layout: the struct layout rule of DESIGN 4.8 through passes/lib/layout.bas (2.6.3, L-h, L-k,
#     L-m): sizes, alignments, field offsets, reference offsets (rule 15 (g), rule 38's soff list),
#     R24's field-path test, the misuse statuses and the capacity of the field rows
# ==============================================================================================
# the rule's sizes (f64, i64, references 8; bool 1) are rt.inc's SEA_ESIZE_*: the module reads those
esz_ok=1
for e in "F64 8" "I64 8" "BOOL 1" "PTR 8"; do
    set -- $e
    v=$(awk -v n="SEA_ESIZE_$1," '$1 == ".equiv" && $2 == n { print $3; exit }' "$SEA/include/rt.inc")
    [ "$v" = "$2" ] || esz_ok=0
done
if [ $esz_ok -eq 1 ]; then ok "layout: rt.inc's SEA_ESIZE_F64/I64/BOOL/PTR are the sizes of the layout rule (8, 8, 1, 8; DESIGN 4.8)"; else bad "layout: rt.inc's SEA_ESIZE_* differ from the layout rule's sizes 8, 8, 1, 8 (DESIGN 4.8)"; fi

cat > "$T/h_lay.bas" <<'EOF'
10 REM layout harness: the first input line "I t9 m" calls ly_init, then one command per line:
11 REM D i (ly_dyn), X i e n (ly_fix), S i n (ly_st), F f (ly_fd), Q i (kind size align nref),
12 REM O (the open struct), L s i (ly_fld), R s (ly_ref k = 0 .. nref + 1), A s o f (ly_at)
20 DIM E(299), E$(299,5), C(299,4), C$(299), Q(60,6), F$(8), V(8)
30 LET P$ = "lyh"
40 CALL "tb_errors": P$, E(), E$(), 299, E0
50 CALL "tb_consts": P$, E(), E$(), E0, C(), C$(), 299, C0
60 IF END #0 THEN 990
70 LINPUT #0, L$
80 CALL "io_split": L$, F$(), 8, N
90 FOR I = 2 TO N
100 LET V(I) = VAL(F$(I))
110 NEXT I
120 LET K$ = F$(1)
130 IF K$ = "I" THEN 200
140 IF K$ = "D" THEN 220
150 IF K$ = "X" THEN 240
160 IF K$ = "S" THEN 260
170 IF K$ = "F" THEN 280
175 IF K$ = "Q" THEN 300
180 IF K$ = "O" THEN 320
185 IF K$ = "L" THEN 340
190 IF K$ = "R" THEN 360
195 IF K$ = "A" THEN 400
197 PRINT "BAD COMMAND " & L$
198 STOP 3
200 CALL "ly_init": Q(), C(), C$(), C0, V(2), V(3), P$
210 GOTO 60
220 CALL "ly_dyn": Q(), V(2)
230 GOTO 60
240 CALL "ly_fix": Q(), V(2), V(3), V(4), T
250 GOTO 290
260 CALL "ly_st": Q(), V(2), V(3), T
270 GOTO 290
280 CALL "ly_fd": Q(), V(2), T
290 PRINT L$ & ": T=" & STR$(T)
295 GOTO 60
300 LET I = V(2)
310 PRINT L$ & ": " & STR$(Q(I, 0)) & " " & STR$(Q(I, 1)) & " " & STR$(Q(I, 2)) & " " & STR$(Q(I, 3))
315 GOTO 60
320 PRINT L$ & ": " & STR$(Q(0, 4))
330 GOTO 60
340 CALL "ly_fld": Q(), V(2), V(3), F, O
350 PRINT L$ & ": F=" & STR$(F) & " O=" & STR$(O)
355 GOTO 60
360 LET R$ = L$ & ":"
370 FOR K = 0 TO Q(V(2), 3) + 1
375 CALL "ly_ref": Q(), V(2), K, O
380 LET R$ = R$ & " " & STR$(O)
385 NEXT K
390 PRINT R$
395 GOTO 60
400 CALL "ly_at": Q(), V(2), V(3), V(4), Y
410 PRINT L$ & ": Y=" & STR$(Y)
420 GOTO 60
990 STOP
EOF
cat "$T/h_lay.bas" "$SEA/passes/lib/io.bas" "$SEA/passes/lib/diag.bas" "$SEA/passes/lib/tables.bas" "$SEA/passes/lib/layout.bas" > "$T/lay.bas"
printf '%s\n' errors consts | (cd "$T/gd" && "$GENDATA" 89000) >> "$T/lay.bas" || { echo "lib_check: gendata failed for lay" >&2; exit 2; }
echo "99999 END" >> "$T/lay.bas"
"$BSK" "$T/lay.bas" -o "$T/lay" || { echo "lib_check: cannot compile lay" >&2; exit 2; }

# The types (ids 10-23 of a table of T9 = 40 rows, 20 field rows 41-60), each expected value by the
# rule of DESIGN 4.8 (fields in order, each at the next multiple of its alignment; alignment the
# largest field's, 1 if none; size rounded up to it; T[n] n elements inline with T's alignment):
#   10 f64[]                                    a reference: 8, align 8, 1 reference at 0
#   11 struct P { x: f64, b: bool, y: i64 }      x 0, b 8, y 16; size 24, align 8
#   12 struct M { b: bool, c: bool }             b 0, c 1; size 2, align 1
#   13 struct E { }                              size 0, align 1 (L-h)
#   14 struct R { b: bool, s: str, e: E, v: f64[], c: bool }
#                                                b 0, s 8, e 16 (size 0), v 16, c 24; size 25 -> 32;
#                                                references at 8 (s) and 16 (v)
#   15 str[3]                                    24, align 8, references 0 8 16
#   16 R[2]                                      64, align 8, references 8 16 40 48
#   17 bool[2,3]                                 6 elements: 6, align 1
#   18 struct N { m: M, q: bool[2,3], p: P, a: R[2], h: Figure }
#                                                m 0 (2), q 2 (6), p 8 (24), a 32 (64), h 96;
#                                                size 104, align 8; references 40 48 72 80 96
#   19 E[3]                                      0, align 1 (element size 0, L-h)
#   20 record { e: E, x: f64 }  (trec, L-m)       e 0, x 0; size 8, align 8
#   21 struct { f64, i64 } built after misuse   16, align 8
#   23 struct { f64 } in the last field row     8, align 8
cat > "$T/lay.in" <<'EOF'
I 40 60
Q 1
Q 2
Q 3
Q 4
Q 5
Q 6
Q 9
D 10
Q 10
S 11 3
O
F 4
F 2
F 3
O
Q 11
S 12 2
F 2
F 2
Q 12
S 13 0
O
Q 13
S 14 5
F 2
F 5
F 13
F 10
F 2
Q 14
X 15 5 3
Q 15
X 16 14 2
Q 16
X 17 2 6
Q 17
S 18 5
F 12
F 17
F 11
F 16
F 6
Q 18
X 19 13 3
Q 19
S 20 2
F 13
F 4
Q 20
L 11 0
L 11 1
L 11 2
L 14 1
L 14 2
L 14 3
L 14 4
L 18 0
L 18 1
L 18 2
L 18 3
L 18 4
L 20 1
R 5
R 10
R 11
R 13
R 14
R 15
R 16
R 18
R 19
A 18 8 11
A 18 8 4
A 18 16 2
A 18 24 3
A 18 24 4
A 18 0 12
A 18 0 2
A 18 1 2
A 18 2 17
A 18 3 2
A 18 32 16
A 18 40 5
A 18 96 6
A 18 104 6
A 11 8 2
A 14 16 13
A 14 16 10
A 20 0 13
A 20 0 4
A 4 0 4
F 4
X 21 1 2
X 21 40 2
S 21 2
O
F 1
S 22 1
F 21
X 22 21 2
F 4
F 3
O
Q 21
S 23 2
S 23 1
F 4
Q 23
EOF
cat > "$T/lay.exp" <<'EOF'
Q 1: 0 0 0 0
Q 2: 1 1 1 0
Q 3: 1 8 8 0
Q 4: 1 8 8 0
Q 5: 2 8 8 1
Q 6: 2 8 8 1
Q 9: 2 8 8 1
Q 10: 2 8 8 1
S 11 3: T=0
O: 11
F 4: T=0
F 2: T=0
F 3: T=0
O: 0
Q 11: 4 24 8 0
S 12 2: T=0
F 2: T=0
F 2: T=0
Q 12: 4 2 1 0
S 13 0: T=0
O: 0
Q 13: 4 0 1 0
S 14 5: T=0
F 2: T=0
F 5: T=0
F 13: T=0
F 10: T=0
F 2: T=0
Q 14: 4 32 8 2
X 15 5 3: T=0
Q 15: 3 24 8 3
X 16 14 2: T=0
Q 16: 3 64 8 4
X 17 2 6: T=0
Q 17: 3 6 1 0
S 18 5: T=0
F 12: T=0
F 17: T=0
F 11: T=0
F 16: T=0
F 6: T=0
Q 18: 4 104 8 5
X 19 13 3: T=0
Q 19: 3 0 1 0
S 20 2: T=0
F 13: T=0
F 4: T=0
Q 20: 4 8 8 0
L 11 0: F=4 O=0
L 11 1: F=2 O=8
L 11 2: F=3 O=16
L 14 1: F=5 O=8
L 14 2: F=13 O=16
L 14 3: F=10 O=16
L 14 4: F=2 O=24
L 18 0: F=12 O=0
L 18 1: F=17 O=2
L 18 2: F=11 O=8
L 18 3: F=16 O=32
L 18 4: F=6 O=96
L 20 1: F=4 O=0
R 5: -1 0 -1
R 10: -1 0 -1
R 11: -1 -1
R 13: -1 -1
R 14: -1 8 16 -1
R 15: -1 0 8 16 -1
R 16: -1 8 16 40 48 -1
R 18: -1 40 48 72 80 96 -1
R 19: -1 -1
A 18 8 11: Y=1
A 18 8 4: Y=1
A 18 16 2: Y=1
A 18 24 3: Y=1
A 18 24 4: Y=0
A 18 0 12: Y=1
A 18 0 2: Y=1
A 18 1 2: Y=1
A 18 2 17: Y=1
A 18 3 2: Y=0
A 18 32 16: Y=1
A 18 40 5: Y=0
A 18 96 6: Y=1
A 18 104 6: Y=0
A 11 8 2: Y=1
A 14 16 13: Y=1
A 14 16 10: Y=1
A 20 0 13: Y=1
A 20 0 4: Y=1
A 4 0 4: Y=0
F 4: T=1
X 21 1 2: T=1
X 21 40 2: T=1
S 21 2: T=0
O: 21
F 1: T=1
S 22 1: T=1
F 21: T=1
X 22 21 2: T=1
F 4: T=0
F 3: T=0
O: 0
Q 21: 4 16 8 0
S 23 2: T=1
S 23 1: T=0
F 4: T=0
Q 23: 4 8 8 0
EOF
expect "layout: sizes, alignments, field offsets, reference offsets and field paths of DESIGN 4.8 (empty structs L-h, records L-m, misuse, field-row capacity)" "$T/lay" "$T/lay.in" 0 "$T/lay.exp" /dev/null

# ly_init without field rows above the type rows: a misuse of the module (dg_bug), status 11
echo "I 40 40" > "$T/lay2.in"
printf 'lyh: ly_init: Q has no field rows, or a constant SEA_ESIZE_* is missing\n' > "$T/lay2.err"
expect "layout: ly_init with no field rows -> <pass>: ly_init: ..., status 11" "$T/lay" "$T/lay2.in" 11 /dev/null "$T/lay2.err"

# ==============================================================================================
# 5c. ralloc: the linear-scan allocator of DESIGN 4.9.2 through passes/lib/ralloc.bas (Decisions 59,
#     60, L-ac, L-an, L-aq): intervals, loop extension, call crossing, the scan with hints and the
#     spill choice, slots, the saves around calls, hidden loop registers (L-aq with a small R9),
#     the three-step parallel move with cycles. Each case is a hand-written walk of one function,
#     its expected locations derived by hand from 4.9.2 (positions 2k / 2k+1, parameters at 0).
# ==============================================================================================
cat > "$T/h_ra.bas" <<'EOF'
10 REM ralloc harness, one command per line: I r9 b9 z9 (ra_init), T p c n k s (ra_tab), F (ra_fn),
11 REM K r c (the caller's class), P r, R k r w, C k, H k r a b, O k b y i s, X k b, E m (ra_end),
12 REM L r... (locations), V r (start end, the module's columns 3 2), B b (ra_blk), U p (ra_used),
13 REM W (ra_rew), S k (ra_sv, ra_svi), M s e c (ra_mv), Q (ra_pm, ra_st), Y n (n moves), G r (D(r,0)),
14 REM Z k b (ra_else), A k r v (ra_avoid)
20 DIM D(111110,8), F$(20), V(20)
30 IF END #0 THEN 990
40 LINPUT #0, L$
50 CALL "io_split": L$, F$(), 20, N
60 FOR I = 2 TO N
70 LET V(I) = VAL(F$(I))
80 NEXT I
90 LET K = POS("ITFKPRCHOXELVBUWSMQYGZA", F$(1))
100 IF K = 0 THEN 980
110 ON K GOTO 200,210,220,230,240,250,260,270,280,290,300,320,360,380,400,420,440,480,500,540,560,570,580
200 CALL "ra_init": D(), V(2), V(3), V(4), T
205 PRINT "I T=" & STR$(T)
207 GOTO 30
210 CALL "ra_tab": D(), V(2), V(3), V(4), V(5), V(6)
215 GOTO 30
220 CALL "ra_fn": D()
225 GOTO 30
230 LET D(V(2), 0) = V(3)
235 GOTO 30
240 CALL "ra_par": D(), V(2)
245 GOTO 30
250 CALL "ra_ref": D(), V(2), V(3), V(4)
255 GOTO 30
260 CALL "ra_call": D(), V(2)
265 GOTO 30
270 CALL "ra_hint": D(), V(2), V(3), V(4), V(5)
275 GOTO 30
280 CALL "ra_open": D(), V(2), V(3), V(4), V(5), V(6)
285 GOTO 30
290 CALL "ra_close": D(), V(2), V(3)
295 GOTO 30
300 CALL "ra_end": D(), V(2), S, T
310 PRINT "E S8=" & STR$(S) & " T=" & STR$(T)
315 GOTO 30
320 LET R$ = "L"
330 FOR I = 2 TO N
340 LET R$ = R$ & " " & STR$(V(I)) & "=" & STR$(D(V(I), 8))
345 NEXT I
350 PRINT R$
355 GOTO 30
360 PRINT "V " & STR$(V(2)) & ": " & STR$(D(V(2), 3)) & " " & STR$(D(V(2), 2))
370 GOTO 30
380 CALL "ra_blk": D(), V(2), C, S, F
390 PRINT "B " & STR$(V(2)) & ": " & STR$(C) & " " & STR$(S) & " " & STR$(F)
395 GOTO 30
400 CALL "ra_used": D(), V(2), U
410 PRINT "U " & STR$(V(2)) & ": " & STR$(U)
415 GOTO 30
420 CALL "ra_rew": D()
425 GOTO 30
440 CALL "ra_sv": D(), V(2), M, T
450 LET R$ = "S " & STR$(V(2)) & ": N=" & STR$(M) & " T=" & STR$(T)
455 FOR I = 1 TO M
460 CALL "ra_svi": D(), I, P, S, R
465 LET R$ = R$ & " (" & STR$(P) & " " & STR$(S) & " " & STR$(R) & ")"
470 NEXT I
475 PRINT R$
477 GOTO 30
480 CALL "ra_mv": D(), V(2), V(3), V(4), T
485 IF T = 0 THEN 30
490 PRINT "M T=" & STR$(T)
495 GOTO 30
500 CALL "ra_pm": D(), M
505 PRINT "Q N=" & STR$(M)
510 FOR I = 1 TO M
515 CALL "ra_st": D(), I, S, E, C, J
520 PRINT "  " & STR$(S) & " " & STR$(E) & " " & STR$(C) & " " & STR$(J)
525 NEXT I
530 GOTO 30
540 FOR I = 1 TO V(2)
545 CALL "ra_mv": D(), I, -I, 1, T
550 NEXT I
553 PRINT "Y T=" & STR$(T)
555 GOTO 30
560 PRINT "G " & STR$(V(2)) & ": " & STR$(D(V(2), 0))
565 GOTO 30
570 CALL "ra_else": D(), V(2), V(3)
575 GOTO 30
580 CALL "ra_avoid": D(), V(2), V(3), V(4)
585 GOTO 30
980 PRINT "BAD COMMAND " & L$
985 STOP 3
990 STOP
EOF
cat "$T/h_ra.bas" "$SEA/passes/lib/io.bas" "$SEA/passes/lib/diag.bas" "$SEA/passes/lib/tables.bas" "$SEA/passes/lib/ralloc.bas" > "$T/ra.bas"
printf '%s\n' errors | (cd "$T/gd" && "$GENDATA" 89000) >> "$T/ra.bas" || { echo "lib_check: gendata failed for ra" >&2; exit 2; }
echo "99999 END" >> "$T/ra.bas"
"$BSK" "$T/ra.bas" -o "$T/ra" || { echo "lib_check: cannot compile ra" >&2; exit 2; }

# the limits ra_init is given come from limits.inc, as a code generator takes them from the consts table
R9=$(limitof LIM_LIR_REGS)
B9=$(limitof LIM_LIR_BLOCKS)
# the table every case uses unless it says otherwise: general registers 1 and 2 caller-saved, 3
# callee-saved (row "crossing no call" 1 2 3, row "crossing a call" 3 1 2, as arm64's x9.. then
# x19..), 4 caller-saved and last in both rows; floating point 10 caller-saved, 11 callee-saved
ratab() {
    printf 'I %s %s 111110\nT 1 1 1 2 0\nT 2 1 2 3 0\nT 3 1 3 1 1\nT 4 1 4 4 0\nT 10 2 1 2 0\nT 11 2 2 1 1\n' "$R9" "$B9"
}

# a. scan and hints. Records: 1 func r1 r2 r3 (i); 2 iadd i4 i3 i3; 3 iadd i5 i4 i1 (x86_64
#    commuting: hint r4, then r1); 4 iadd i6 i2 i5; 5 ret 1 i6; 6 endfunc. Intervals: r1 0-6, r2
#    0-8, r3 0-4, r4 5-6, r5 7-8, r6 9-10. r1 1, r2 2, r3 3 (registers 1 2 taken); r4 at 5: r3
#    expired, r1 not (6 >= 5): 3; r5 at 7: r1 and r4 expired, the hint r4's register 3 is free
#    (without it, 1 would be chosen); r6 at 9: everything expired, the hint r2's register 2 is free
#    (not 1). No slot. Then ra_sv at record 2, which is no call: r1 and r2 (caller-saved 1 and 2)
#    cross it (start <= 4, end > 5) with no save slot: T=1.
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
P 1
P 2
P 3
R 2 3 0
R 2 4 1
R 3 4 0
R 3 1 0
R 3 5 1
H 3 5 4 1
R 4 2 0
R 4 5 0
R 4 6 1
H 4 6 2 5
R 5 6 0
E 6
L 1 2 3 4 5 6
V 1
V 4
V 6
U 3
U 4
W
S 2
EOF
} > "$T/ra_a.in"
cat > "$T/ra_a.exp" <<'EOF'
I T=0
E S8=0 T=0
L 1=1 2=2 3=3 4=3 5=3 6=2
V 1: 0 6
V 4: 5 6
V 6: 9 10
U 3: 1
U 4: 0
S 2: N=2 T=1 (1 0 1) (2 0 2)
EOF
expect "ralloc: intervals, expiry before placement, the first free register of the row, the hint (DESIGN 4.9.2 'The scan'); ra_sv at an unreported call: T=1" "$T/ra" "$T/ra_a.in" 0 "$T/ra_a.exp" /dev/null

# a2. the avoided register (DESIGN 4.9.2 'The scan', Decision 77). Records: 1 func r1 r2 (i); 2 isub
#    i3 i1 i2 (x86_64, not commuting: hint r1, avoid r2); 3 iadd i4 i3 i1; 4 ret 1 i4; 5 endfunc.
#    Intervals: r1 0-6, r2 0-4, r3 5-6, r4 7-8. r1 1, r2 2; r3 at 5: r2 expired, the hint r1's
#    register 1 is not free (r1 ends at 6); free are 2 3 4 and 2 is r2's, avoided: 3 (without the
#    avoidance the first free one, 2). r4 at 7: everything expired, no hint: 1. With only the
#    registers 1 and 2 declared, r3's one free register is the avoided 2, which it takes (no
#    spill); there ra_avoid comes before ra_hint, and neither call clears the other's field.
{ ratab; cat <<'EOF2'
F
K 1 1
K 2 1
K 3 1
K 4 1
P 1
P 2
R 2 1 0
R 2 2 0
R 2 3 1
H 2 3 1 0
A 2 3 2
R 3 3 0
R 3 1 0
R 3 4 1
R 4 4 0
E 4
L 1 2 3 4
EOF2
} > "$T/ra_a2.in"
cat > "$T/ra_a2.exp" <<'EOF2'
I T=0
E S8=0 T=0
L 1=1 2=2 3=3 4=1
EOF2
expect "ralloc: ra_avoid, the destination of a non-commuting two-address instruction avoids its dying second operand's register when another is free (DESIGN 4.9.2 'The scan', Decision 77)" "$T/ra" "$T/ra_a2.in" 0 "$T/ra_a2.exp" /dev/null
{ printf 'I %s %s 111110\nT 1 1 1 1 0\nT 2 1 2 2 0\n' "$R9" "$B9"; cat <<'EOF2'
F
K 1 1
K 2 1
K 3 1
K 4 1
P 1
P 2
R 2 1 0
R 2 2 0
R 2 3 1
A 2 3 2
H 2 3 1 0
R 3 3 0
R 3 1 0
R 3 4 1
R 4 4 0
E 4
L 1 2 3 4
EOF2
} > "$T/ra_a3.in"
cat > "$T/ra_a3.exp" <<'EOF2'
I T=0
E S8=0 T=0
L 1=1 2=2 3=2 4=1
EOF2
expect "ralloc: ra_avoid, the avoided register taken when it is the only free one, no spill; ra_avoid before ra_hint keeps both (DESIGN 4.9.2 'The scan', Decision 77)" "$T/ra" "$T/ra_a3.in" 0 "$T/ra_a3.exp" /dev/null

# b. spills: the victim's loop depth, then its end, then its number; slots in order of first use.
#    Records: 1 func; 2-5 li i1 .. li i4 (writes 5 7 9 11); 6 do 1; 7 iadd i5 i1 i2 (14, 15); 8
#    exit 1; 9 enddo 1; 10 iadd i6 i3 i4 (20, 21); 11 ret 1 i6 (22); 12 endfunc. The do covers
#    13-19. r1 5-19 and r2 7-19 (defined before the loop and read in it: uncovered, extended), r5 15-15
#    (written in the loop and never read: not live at its top, not extended), r3 9-20, r4 11-20,
#    r6 21-22. Depths: r1 r2 r5 1, r3 r4 0. Three general registers here (4 is not declared). r1 1,
#    r2 2, r3 3; r4 at 11: none free, depth 0 are r3 r4, both end at 20, the higher number r4 is
#    spilled; r5 at 15: none free, r3 has the smallest depth: spilled, r5 takes 3; r6 at 21: 1.
#    Slots by first use: r3 (9) 1, r4 (11) 2.
{ printf 'I %s %s 111110\nT 1 1 1 2 0\nT 2 1 2 3 0\nT 3 1 3 1 1\n' "$R9" "$B9"; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
R 2 1 1
R 3 2 1
R 4 3 1
R 5 4 1
O 6 1 2 0 0
R 7 1 0
R 7 2 0
R 7 5 1
X 9 1
R 10 3 0
R 10 4 0
R 10 6 1
R 11 6 0
E 6
L 1 2 3 4 5 6
V 1
V 2
V 5
V 3
EOF
} > "$T/ra_b.in"
cat > "$T/ra_b.exp" <<'EOF'
I T=0
E S8=2 T=0
L 1=1 2=2 3=-1 4=-2 5=3 6=1
V 1: 5 19
V 2: 7 19
V 5: 15 15
V 3: 9 20
EOF
expect "ralloc: loop extension (a value read in the loop that was defined before it is extended; a value never read is not), spill choice by depth, end, number; spill slots in order of first use" "$T/ra" "$T/ra_b.in" 0 "$T/ra_b.exp" /dev/null

# c. a call inside a loop: crossing along the records and around the back edge, the call row,
#    save slots, ra_sv. Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 i2 i2 (reads 6, ind
#    7); 4 if 2 i1 (8); 5 mov i4 i3 (10, 11); 6 endif 2; 7 call g 0 0 (14, 15); 8 mov i5 i4 (16,
#    17); 9 endloop 1 (ind read 18 and written 19, the step r2 read 18); 10 ret 1 i1 (20); 11
#    endfunc. Loop 1 covers 7-19. r1 0-20, r2 5-19, r3 7-19, r4 7-19 (written inside the if and read
#    at 16 after its endif: the write's part has closed, so the read is uncovered: extended), r5 17-17, r6 the
#    hidden count 7-19; all but r5 cross the call (start <= 14, end > 15), all have depth 1. Three
#    general registers (as in b). Row "crossing a call": 3 1 2. r1 3, r2 1, r3 2; r4 at 7: none
#    free, all depth 1, r1 ends last
#    (20): spilled, r4 takes 3; r6 at 7: all end at 19, the highest number r6 is spilled; r5 at
#    17: r4 (19, the highest number among those ending last) is spilled, r5 takes 3. Slots by
#    first use: r1 (0) 1, r6 (7) 2, r4 (11) 3, then the save slots of r2 and r3 (in caller-saved
#    1 and 2, first call 7: 14) 4 and 5. ra_sv 7: 1 holds r2 (save slot 4), 2 holds r3 (5).
{ printf 'I %s %s 111110\nT 1 1 1 2 0\nT 2 1 2 3 0\nT 3 1 3 1 1\n' "$R9" "$B9"; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
P 1
R 2 2 1
R 3 2 0
R 3 3 1
O 3 1 1 3 2
R 4 1 0
O 4 2 3 0 0
R 5 3 0
R 5 4 1
H 5 4 3 0
X 6 2
C 7
R 8 4 0
R 8 5 1
H 8 5 4 0
X 9 1
R 10 1 0
E 5
L 1 2 3 4 5 6
V 4
V 2
V 6
G 6
B 1
W
S 7
EOF
} > "$T/ra_c.in"
cat > "$T/ra_c.exp" <<'EOF'
I T=0
E S8=5 T=0
L 1=-1 2=1 3=2 4=-3 5=3 6=-2
V 4: 7 19
V 2: 5 19
V 6: 7 19
G 6: 1
B 1: -2 0 0
S 7: N=2 T=0 (1 4 2) (2 5 3)
EOF
expect "ralloc: a call in a loop: crossing around the back edge, the call row, the hidden count register, save slots after spill slots by first use, ra_sv" "$T/ra" "$T/ra_c.in" 0 "$T/ra_c.exp" /dev/null

# d. the loop span (reading: the loop record's reads and its ind write are outside the loop):
#    start, last and a step read only by the loop record do not stay live through it. Records: 1
#    func r1 r2 (i); 2 li i3 (5); 3 loop 1 i4 i1 i2 i3 (reads 6, ind 7); 4 iadd i5 i4 i4 (8, 9); 5
#    endloop 1 (10, 11); 6 ret 0; 7 endfunc. r1 0-6, r2 0-6, r3 5-11 (the step, read again by the
#    closing sequence), r4 7-11, r6 (count) 7-11, r5 9-9. r1 1, r2 2, r3 3; at 7 r1 and r2 have
#    expired: r4 1, r6 2; r5 4. ra_blk: count in 2, no hidden step, ind not referenced after.
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
P 1
P 2
R 2 3 1
R 3 1 0
R 3 2 0
R 3 3 0
R 3 4 1
O 3 1 1 4 3
R 4 4 0
R 4 5 1
X 5 1
E 5
L 1 2 3 4 5 6
V 1
V 3
B 1
EOF
} > "$T/ra_d.in"
cat > "$T/ra_d.exp" <<'EOF'
I T=0
E S8=0 T=0
L 1=1 2=2 3=3 4=1 5=4 6=2
V 1: 0 6
V 3: 5 11
B 1: 2 0 0
EOF
expect "ralloc: the loop span 2o+1..2c+1: the loop record's operands are outside the loop, the entry move's destinations reuse their registers (reading 2)" "$T/ra" "$T/ra_d.in" 0 "$T/ra_d.exp" /dev/null

# e. the closing references (reading 3): ind, never read in the body, and the step register keep
#    their registers through the loop, so a value of the body cannot take them. Records: 1 func r1
#    (i); 2 li i2 (5); 3 li i3 (7); 4 loop 1 i4 i1 i3 i2 (8, ind 9); 5 li i5 (11); 6 endloop 1 (ind
#    read 12, written 13, step r2 read 12); 7 ret 0; 8 endfunc. r1 0-8, r2 5-13, r3 7-8, r4 9-13,
#    r6 (count) 9-13, r5 11-11. r1 1, r2 2, r3 3; at 9: r4 1, r6 3; r5 4 (not 1, 2 or 3).
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
P 1
R 2 2 1
R 3 3 1
R 4 1 0
R 4 3 0
R 4 2 0
R 4 4 1
O 4 1 1 4 2
R 5 5 1
X 6 1
E 5
L 1 2 3 4 5 6
V 4
V 2
B 1
EOF
} > "$T/ra_e.in"
cat > "$T/ra_e.exp" <<'EOF'
I T=0
E S8=0 T=0
L 1=1 2=2 3=3 4=1 5=4 6=3
V 4: 9 13
V 2: 5 13
B 1: 3 0 0
EOF
expect "ralloc: the closing sequence references ind and the step register at endloop (reading 3)" "$T/ra" "$T/ra_e.in" 0 "$T/ra_e.exp" /dev/null

# f. a call result loop-extended before its own call (reading 4), ind referenced after its loop.
#    Records: 1 func r1 (i); 2 do 1; 3 if 2 i1 (6); 4 call f 1 i2 0 (writes 9; first referenced
#    inside the if, read at 16 after the do: uncovered after it, so its interval starts at the do's 5); 5 endif 2; 6 exit 1; 7 enddo
#    1; 8 ret 1 i2 (16); 9 endfunc. r1 0-15 (read inside the do: extended to its end 15), r2 5-16;
#    both cross call 4 (start <= 8, end > 9). Row "crossing a call": r1 3, r2 1. r2's save slot 1
#    (first call 4). ra_sv 4 lists r2, the record's own result, which the caller skips.
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
P 1
O 2 1 2 0 0
R 3 1 0
O 3 2 3 0 0
C 4
R 4 2 1
X 5 2
X 7 1
R 8 2 0
E 2
L 1 2
V 1
V 2
W
S 4
EOF
} > "$T/ra_f.in"
cat > "$T/ra_f.exp" <<'EOF'
I T=0
E S8=1 T=0
L 1=3 2=1
V 1: 0 15
V 2: 5 16
S 4: N=1 T=0 (1 1 2)
EOF
expect "ralloc: a call result whose interval starts before its own call is listed by ra_sv with its register (the caller skips it, reading 4)" "$T/ra" "$T/ra_f.in" 0 "$T/ra_f.exp" /dev/null

# g. ind referenced after the loop: ra_blk's F = 1. Records: 1 func r1 (i); 2 loop 1 i2 i1 i1 i1
#    (4, ind 5); 3 endloop 1 (6, 7); 4 ret 1 i2 (8); 5 endfunc.
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
P 1
R 2 1 0
R 2 2 1
O 2 1 1 2 1
X 3 1
R 4 2 0
E 2
B 1
EOF
} > "$T/ra_g.in"
cat > "$T/ra_g.exp" <<'EOF'
I T=0
E S8=0 T=0
B 1: 3 0 1
EOF
expect "ralloc: ind referenced after endloop gives ra_blk F = 1 (the cbz form of 'Loop closing')" "$T/ra" "$T/ra_g.in" 0 "$T/ra_g.exp" /dev/null

# h. L-aq with R9 = 5: a hidden register numbered above R9 lives in a spill slot of its own.
#    Records: 1 func r1 r2 (i); 2 loop 1 i3 i1 i1 i2 (reads 4, ind 5); 3 mov i2 i3 (6, 7: the step
#    r2 is written inside loop 1, which therefore has a hidden step); 4 endloop 1 (ind 8, 9); 5
#    loop 2 i4 i2 i2 i2 (10, ind 11); 6 endloop 2 (12, 13); 7 ret 0; 8 endfunc. M = 4: loop 1's
#    count is r5, its step would be 6 > 5 (a slot), loop 2's count would be 7 (a slot); loop 2's
#    step r2 is not written inside it. r1 0-4, r2 0-13, r3 5-9, r5 5-9, r4 11-13: r1 1, r2 2, r3 1,
#    r5 3, r4 1. No spill, no call: the L-aq slots 1 (loop 1's step) and 2 (loop 2's count).
#    Then a new function: ra_fn clears every row used, the caller's class column included.
cat > "$T/ra_h.in" <<'EOF'
I 5 3 111110
T 1 1 1 2 0
T 2 1 2 3 0
T 3 1 3 1 1
T 4 1 4 4 0
F
K 1 1
K 2 1
K 3 1
K 4 1
P 1
P 2
R 2 1 0
R 2 2 0
R 2 3 1
O 2 1 1 3 2
R 3 3 0
R 3 2 1
X 4 1
R 5 2 0
R 5 4 1
O 5 2 1 4 2
X 6 2
E 4
L 1 2 3 4 5
B 1
B 2
G 5
F
G 5
G 4
EOF
cat > "$T/ra_h.exp" <<'EOF'
I T=0
E S8=2 T=0
L 1=1 2=2 3=1 4=1 5=3
B 1: 3 -1 0
B 2: -2 0 0
G 5: 1
G 5: 0
G 4: 0
EOF
expect "ralloc: L-aq: hidden count and step registers above R9 get spill slots of their own (ra_blk), ra_fn clears the rows" "$T/ra" "$T/ra_h.in" 0 "$T/ra_h.exp" /dev/null

# i. parallel moves (4.9.2 'Moves', L-an): memory destinations first by key (spill slots, stack
#    slots 1000+j, then the results area 2000+j: a ret's results beyond the registers, reading
#    9), then register moves with a cycle broken through the scratch (0), then memory and
#    immediate sources into registers; a move between equal locations is dropped. Then a chain with
#    a shared source, a 3-cycle in floating point, and the capacity of 320 moves.
cat > "$T/ra_i.in" <<'EOF'
I 99999 9999 111110
M 5 1 1
M 1 5 1
M 3002 2 1
M 2 2000 1
M 4 1001 1
M -2 -1 1
M 6 -3 1
M 7 7 1
Q
M 10 11 2
M 11 12 2
M 10 13 2
Q
M 10 11 2
M 11 12 2
M 12 10 2
Q
Q
Y 320
M 1 2 1
Q
EOF
{ cat <<'EOF'
I T=0
Q N=8
  -2 -1 1 6
  6 -3 1 7
  4 1001 1 5
  2 2000 1 4
  5 0 1 1
  1 5 1 2
  0 1 1 1
  3002 2 1 3
Q N=3
  11 12 2 2
  10 11 2 1
  10 13 2 3
Q N=4
  10 0 2 1
  12 10 2 3
  11 12 2 2
  0 11 2 1
Q N=0
Y T=0
M T=1
Q N=320
EOF
i=1; while [ $i -le 320 ]; do printf '  %d %d 1 %d\n' "$i" "-$i" "$i"; i=$((i + 1)); done; } > "$T/ra_i.exp"
expect "ralloc: parallel moves in three steps, cycles through the scratch, results-area destinations after stack slots (reading 9), 320 moves" "$T/ra" "$T/ra_i.in" 0 "$T/ra_i.exp" /dev/null

# j. misuse: a table too small for the limits; ra_end with a block still open
cat > "$T/ra_j.in" <<'EOF'
I 99999 9999 110000
I 99999 9999 110544
F
O 2 1 2 0 0
E 0
EOF
cat > "$T/ra_j.exp" <<'EOF'
I T=1
I T=0
E S8=0 T=1
EOF
expect "ralloc: ra_init with D too small for R9 + B9 + 546 rows, ra_end with a block open: T=1" "$T/ra" "$T/ra_j.in" 0 "$T/ra_j.exp" /dev/null

# k. a call's arguments that are also its results (tests/passes/ra5_pmove.lir's call fswap 2 f8 f9
#    2 f8 f9): read at 2K and written at 2K+1, so by the definition their intervals cross K (start
#    <= 2K, end > 2K+1), but no value is live across the call: no save slot, the "crossing no call"
#    row. ra_sv lists them with slot 0 and T=0, since the caller skips record K's own results.
#    Records: 1 func f1 f2; 2 call fswap 2 f1 f2 2 f1 f2 (4, 5); 3 fadd f3 f1 f2 (6, 7); 4 ret 1
#    f3 (8). Two caller-saved f registers 10 and 11: f1 0-6 10, f2 0-6 11, f3 7-8 10. Then a
#    register that is the result of two calls (2 and 3, call g 1 f1 1 f1 each), queried at both:
#    f1 0-8, listed at 2 and at 3, T=0 at both (an interval written by two or more calls is not
#    tracked further). Case a keeps T=1 for a record that was never reported as a call.
{ printf 'I %s %s 111110\nT 10 2 1 1 0\nT 11 2 2 2 0\n' "$R9" "$B9"; cat <<'EOF'
F
K 1 2
K 2 2
K 3 2
P 1
P 2
R 2 1 0
R 2 2 0
C 2
R 2 1 1
R 2 2 1
R 3 1 0
R 3 2 0
R 3 3 1
R 4 3 0
E 3
L 1 2 3
W
S 2
F
K 1 2
P 1
R 2 1 0
C 2
R 2 1 1
R 3 1 0
C 3
R 3 1 1
R 4 1 0
E 1
L 1
W
S 2
S 3
EOF
} > "$T/ra_k.in"
cat > "$T/ra_k.exp" <<'EOF'
I T=0
E S8=0 T=0
L 1=10 2=11 3=10
S 2: N=2 T=0 (10 0 1) (11 0 2)
E S8=0 T=0
L 1=10
S 2: N=1 T=0 (10 0 1)
S 3: N=1 T=0 (10 0 1)
EOF
expect "ralloc: arguments that are also results of their call (fswap): no save slot, listed by ra_sv with slot 0 and T=0" "$T/ra" "$T/ra_k.in" 0 "$T/ra_k.exp" /dev/null

# Decision 75 (L-bf, L-bg, L-bh; 4.9.2 "Positions and intervals"): an interval is extended over a
# loop only when its register may be live at the loop's top: some read inside the loop is uncovered
# in it, or some read after it is uncovered after it (then back over the outermost closed loop
# that contains the first reference). The parts are announced by ra_open, ra_else (the else of an
# if) and ra_close. The cases l-p use twelve general registers, so nothing is spilled and only
# the intervals (V r: start end) are compared.
ratab12() {
    printf 'I %s %s 111110\n' "$R9" "$B9"
    p=1; while [ $p -le 12 ]; do printf 'T %d 1 %d %d 0\n' $p $p $p; p=$((p + 1)); done
}

# l. temporaries of if parts are not extended; a loop-carried value read inside an if part is.
#    Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 r1 i2 (reads 6, ind 7); 4 if 2 i3 (8);
#    5 iadd i4 i3 i3 (10, 11); 6 iadd i2 i2 i4 (12, 13); 7 else 2; 8 iadd i5 i3 i3 (16, 17); 9
#    iadd i6 i5 i5 (18, 19); 10 endif 2; 11 endloop 1 (ind and the step r2 read 22, ind written
#    23); 12 ret 1 i2 (24). Loop 1 covers 7-23. r2: its read at 12 (and the closing one at 22) has
#    its latest write at record 2, before the loop: uncovered, extended: 5-24. r3 (ind): its
#    latest write is the loop record itself, which is outside the loop: 7-23. r4: written at 11 in
#    the if's first part and read at 12 in it: covered, 11-12. r5 17-18 likewise in the else
#    part, r6 19-19 never read. r1 0-6 (read only by the loop record), r7 the hidden count 7-23.
{ ratab12; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
P 1
R 2 2 1
R 3 2 0
R 3 1 0
R 3 3 1
O 3 1 1 3 2
R 4 3 0
O 4 2 3 0 0
R 5 3 0
R 5 4 1
R 6 2 0
R 6 4 0
R 6 2 1
Z 7 2
R 8 3 0
R 8 5 1
R 9 5 0
R 9 6 1
X 10 2
X 11 1
R 12 2 0
E 6
V 1
V 2
V 3
V 4
V 5
V 6
V 7
EOF
} > "$T/ra_l.in"
cat > "$T/ra_l.exp" <<'EOF'
I T=0
E S8=0 T=0
V 1: 0 6
V 2: 5 24
V 3: 7 23
V 4: 11 12
V 5: 17 18
V 6: 19 19
V 7: 7 23
EOF
expect "ralloc: Decision 75: temporaries of if parts are not extended, a loop-carried value read in an if part is" "$T/ra" "$T/ra_l.in" 0 "$T/ra_l.exp" /dev/null

# m. effective parts (L-bh): a value written in both parts of an if and read after it is covered;
#    one written only in the first part is not; nested ifs; a write in a loop read after it.
#    Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 r1 i2 (6, ind 7); 4 if 2 i3 (8); 5 mov
#    i4 i3 (10, 11); 6 mov i5 i3 (12, 13); 7 else 2; 8 mov i4 i2 (16, 17); 9 endif 2; 10 iadd
#    i6 i4 i5 (20, 21); 11 if 3 i6 (22); 12 if 4 i6 (24); 13 mov i7 i6 (26, 27); 14 else 4; 15 mov
#    i7 i3 (30, 31); 16 endif 4; 17 else 3; 18 mov i7 i2 (36, 37); 19 endif 3; 20 iadd i8 i7 i7
#    (40, 41); 21 endloop 1 (42, 43); 22 ret 1 i8 (44). Loop 1 covers 7-43.
#    r4: its else write (record 8) follows a write in the first part of if 2 whose effective part is
#    that part, so its effective part is the loop body, which contains the read at 20: covered,
#    11-20. r5: written only in the first part, which has closed at 20: uncovered, extended:
#    7-43. r7: the write at 15 (else of if 4, after record 13 in its first part) has as effective
#    part the first part of if 3, so the write at 18 (else of if 3) has the loop body: the read at
#    40 is covered, 27-40 (implementer reading: a write in a nested if's else part whose effective
#    part is B's first part "stood in B's first part"). r8: written at 41 in the loop and read at
#    44 after it: the loop body has closed, uncovered after the loop, which contains r8's first
#    reference: back to 7, 7-44. r6 21-26 (covered reads), r2 5-43, r3 7-43, r9 (count) 7-43.
{ ratab12; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
K 7 1
K 8 1
P 1
R 2 2 1
R 3 2 0
R 3 1 0
R 3 3 1
O 3 1 1 3 2
R 4 3 0
O 4 2 3 0 0
R 5 3 0
R 5 4 1
H 5 4 3 0
R 6 3 0
R 6 5 1
H 6 5 3 0
Z 7 2
R 8 2 0
R 8 4 1
H 8 4 2 0
X 9 2
R 10 4 0
R 10 5 0
R 10 6 1
R 11 6 0
O 11 3 3 0 0
R 12 6 0
O 12 4 3 0 0
R 13 6 0
R 13 7 1
H 13 7 6 0
Z 14 4
R 15 3 0
R 15 7 1
X 16 4
Z 17 3
R 18 2 0
R 18 7 1
X 19 3
R 20 7 0
R 20 8 1
X 21 1
R 22 8 0
E 8
V 1
V 2
V 3
V 4
V 5
V 6
V 7
V 8
V 9
EOF
} > "$T/ra_m.in"
cat > "$T/ra_m.exp" <<'EOF'
I T=0
E S8=0 T=0
V 1: 0 6
V 2: 5 43
V 3: 7 43
V 4: 11 20
V 5: 7 43
V 6: 21 26
V 7: 27 40
V 8: 7 44
V 9: 7 43
EOF
expect "ralloc: Decision 75, L-bh: a value written in both parts of an if is covered after it (nested ifs too), one written in the first part only is extended; a loop's value read after it goes back to the loop's start" "$T/ra" "$T/ra_m.in" 0 "$T/ra_m.exp" /dev/null

# n. sibling copies of a loop (T6/T9, L-bl, L-bg), next and exit. Records: 1 func r1 r2 (i); 2 li
#    i3 (5); 3 li i4 (7); 4 if 1 r1 (8); 5 li i5 (11); 6 loop 2 i6 i3 r2 i3 (12, ind 13); 7 iadd
#    i7 i5 i6 (14, 15); 8 iadd i4 i4 i7 (16, 17); 9 if 3 i7 (18); 10 next 2; 11 endif 3; 12 iadd
#    i8 i7 i7 (24, 25); 13 iadd i4 i4 i8 (26, 27); 14 endloop 2 (28, 29); 15 else 1; 16 li i9
#    (33); 17 loop 4 i10 i3 r2 i3 (34, ind 35); 18 iadd i11 i9 i10 (36, 37); 19 iadd i8 i11 i11
#    (38, 39); 20 if 5 i8 (40); 21 exit 4; 22 endif 5; 23 iadd i4 i4 i8 (46, 47); 24 endloop 4
#    (48, 49); 25 endif 1; 26 ret 1 i4 (52). Loop 2 covers 13-29, loop 4 35-49.
#    r3 (written before the copies, the step of both): 5-49. r4 (the accumulator, carried in both
#    copies, read after them): its read at 46 has its latest write at record 13 in loop 2's
#    closed body: uncovered in loop 4: 7-52. r5, r9 (each copy's pointer, set in its arm): 11-29,
#    33-49. r7 (copy 1's temporary, read after the next): 15-24; r11 (copy 2's): 37-38. r8, one
#    register written and read in both copies (not renamed): every read is covered, and the reads
#    in loop 4 are covered after loop 2 (latest write after its end, L-bg): its base interval
#    25-46, not extended over either loop. r2 0-34 (read by the loop records only), r6 13-29, r10
#    35-49, the counts r12 13-29 and r13 35-49.
{ ratab12; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
K 7 1
K 8 1
K 9 1
K 10 1
K 11 1
P 1
P 2
R 2 3 1
R 3 4 1
R 4 1 0
O 4 1 3 0 0
R 5 5 1
R 6 3 0
R 6 2 0
R 6 6 1
O 6 2 1 6 3
R 7 5 0
R 7 6 0
R 7 7 1
R 8 4 0
R 8 7 0
R 8 4 1
R 9 7 0
O 9 3 3 0 0
X 11 3
R 12 7 0
R 12 8 1
R 13 4 0
R 13 8 0
R 13 4 1
X 14 2
Z 15 1
R 16 9 1
R 17 3 0
R 17 2 0
R 17 10 1
O 17 4 1 10 3
R 18 9 0
R 18 10 0
R 18 11 1
R 19 11 0
R 19 8 1
R 20 8 0
O 20 5 3 0 0
X 22 5
R 23 4 0
R 23 8 0
R 23 4 1
X 24 4
X 25 1
R 26 4 0
E 11
V 2
V 3
V 4
V 5
V 6
V 7
V 8
V 9
V 10
V 11
V 12
V 13
EOF
} > "$T/ra_n.in"
cat > "$T/ra_n.exp" <<'EOF'
I T=0
E S8=0 T=0
V 2: 0 34
V 3: 5 49
V 4: 7 52
V 5: 11 29
V 6: 13 29
V 7: 15 24
V 8: 25 46
V 9: 33 49
V 10: 35 49
V 11: 37 38
V 12: 13 29
V 13: 35 49
EOF
expect "ralloc: Decision 75, L-bg: sibling copies of a loop: shared values extended, each copy's temporaries not, a register reused by both copies keeps its base interval; next and exit" "$T/ra" "$T/ra_n.in" 0 "$T/ra_n.exp" /dev/null

# o. nested loops (L-bf). Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 r1 i2 (6, ind 7);
#    4 iadd i4 i3 i3 (8, 9); 5 loop 2 i5 i2 r1 i2 (10, ind 11); 6 iadd i6 i4 i5 (12, 13); 7 iadd
#    i7 i6 i6 (14, 15); 8 if 3 i7 (16); 9 exit 2; 10 endif 3; 11 endloop 2 (22, 23); 12 iadd i8
#    i7 i4 (24, 25); 13 endloop 1 (26, 27); 14 ret 1 i8 (28). Loop 1 covers 7-27, loop 2 11-23.
#    r4, written in loop 1's body and read in loop 2: uncovered in loop 2 (written before it),
#    covered in loop 1: extended over loop 2 only, then read at 24: 9-24. r6, loop 2's temporary:
#    13-14 (not extended over the outer loop). r7, written in loop 2 and read at 24 after it: a
#    write inside a nested loop never covers a read after that loop (L-bf), so the read is
#    uncovered in loop 1 too: 7-27. r8, written at 25 in loop 1 and read after it: back over
#    loop 1, 7-28. r1 0-27 (loop 2's record reads it inside loop 1), r2 5-27, r3 7-27, r5 11-23,
#    the counts r9 7-27 and r10 11-23.
{ ratab12; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
K 7 1
K 8 1
P 1
R 2 2 1
R 3 2 0
R 3 1 0
R 3 3 1
O 3 1 1 3 2
R 4 3 0
R 4 4 1
R 5 2 0
R 5 1 0
R 5 5 1
O 5 2 1 5 2
R 6 4 0
R 6 5 0
R 6 6 1
R 7 6 0
R 7 7 1
R 8 7 0
O 8 3 3 0 0
X 10 3
X 11 2
R 12 7 0
R 12 4 0
R 12 8 1
X 13 1
R 14 8 0
E 8
V 1
V 2
V 3
V 4
V 5
V 6
V 7
V 8
V 9
V 10
EOF
} > "$T/ra_o.in"
cat > "$T/ra_o.exp" <<'EOF'
I T=0
E S8=0 T=0
V 1: 0 27
V 2: 5 27
V 3: 7 27
V 4: 9 24
V 5: 11 23
V 6: 13 14
V 7: 7 27
V 8: 7 28
V 9: 7 27
V 10: 11 23
EOF
expect "ralloc: Decision 75, L-bf: nested loops: a value of the outer body extended over the inner loop only, the inner loop's temporary not at all, an inner loop's value read after it uncovered in the outer loop" "$T/ra" "$T/ra_o.in" 0 "$T/ra_o.exp" /dev/null

# p. back-extension: over the outermost closed loop that contains the first reference and not the
#    read; a loop lying between them needs none; a write after a loop covers the reads after it.
#    Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 r1 i2 (6, ind 7); 4 loop 2 i4 i2 r1 i2 (8,
#    ind 9); 5 iadd i5 i4 i4 (10, 11); 6 endloop 2 (12, 13); 7 endloop 1 (14, 15); 8 loop 3 i6 i2
#    r1 i2 (16, ind 17); 9 mov i7 i6 (18, 19); 10 endloop 3 (20, 21); 11 mov i7 r1 (22, 23); 12
#    iadd i8 i5 i7 (24, 25); 13 ret 1 i8 (26). r5, first written in loop 2 inside loop 1, read at
#    24: uncovered after both, back over the outer one: 7-24 (loop 3 lies inside that interval).
#    r7, first written in loop 3, written again at 23 after it: the read at 24 is covered after
#    loop 3, 19-24. r1 0-22, r2 5-21, r3 7-15, r4 9-13, r6 17-21, r8 25-26, the counts r9 7-15,
#    r10 9-13, r11 17-21.
{ ratab12; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
K 6 1
K 7 1
K 8 1
P 1
R 2 2 1
R 3 2 0
R 3 1 0
R 3 3 1
O 3 1 1 3 2
R 4 2 0
R 4 1 0
R 4 4 1
O 4 2 1 4 2
R 5 4 0
R 5 5 1
X 6 2
X 7 1
R 8 2 0
R 8 1 0
R 8 6 1
O 8 3 1 6 2
R 9 6 0
R 9 7 1
H 9 7 6 0
X 10 3
R 11 1 0
R 11 7 1
H 11 7 1 0
R 12 5 0
R 12 7 0
R 12 8 1
R 13 8 0
E 8
V 1
V 2
V 3
V 4
V 5
V 6
V 7
V 8
V 9
V 10
V 11
EOF
} > "$T/ra_p.in"
cat > "$T/ra_p.exp" <<'EOF'
I T=0
E S8=0 T=0
V 1: 0 22
V 2: 5 21
V 3: 7 15
V 4: 9 13
V 5: 7 24
V 6: 17 21
V 7: 19 24
V 8: 25 26
V 9: 7 15
V 10: 9 13
V 11: 17 21
EOF
expect "ralloc: Decision 75: back over the outermost closed loop containing the first reference; a write after a loop covers the reads after it" "$T/ra" "$T/ra_p.in" 0 "$T/ra_p.exp" /dev/null

# q. call crossing is decided on the new intervals: an if part's temporaries in a loop with a call
#    do not cross it. Records: 1 func r1 (i); 2 li i2 (5); 3 loop 1 i3 i2 r1 i2 (6, ind 7); 4 if 2
#    i3 (8); 5 iadd i4 i3 i3 (10, 11); 6 iadd i5 i4 i4 (12, 13); 7 endif 2; 8 call g 0 0 (16, 17);
#    9 endloop 1 (18, 19); 10 ret 0. r1 0-6, r2 5-19, r3 7-19, r6 (count) 7-19 cross call 8; r4
#    11-12 and r5 13-13 do not. The standard table: r1 1 (row "crossing no call"); r2 3, r3 1, r6 2
#    (row "crossing a call" 3 1 2, r1 expired at 7); r4 4 (row "crossing no call", 1 2 3 taken),
#    r5 4 (r4 expired). Save slots of r3 (register 1) and r6 (2), both first at call 8: 1 and 2.
{ ratab; cat <<'EOF'
F
K 1 1
K 2 1
K 3 1
K 4 1
K 5 1
P 1
R 2 2 1
R 3 2 0
R 3 1 0
R 3 3 1
O 3 1 1 3 2
R 4 3 0
O 4 2 3 0 0
R 5 3 0
R 5 4 1
R 6 4 0
R 6 5 1
X 7 2
C 8
X 9 1
E 5
L 1 2 3 4 5 6
V 4
V 5
W
S 8
EOF
} > "$T/ra_q.in"
cat > "$T/ra_q.exp" <<'EOF'
I T=0
E S8=2 T=0
L 1=1 2=3 3=1 4=4 5=4 6=2
V 4: 11 12
V 5: 13 13
S 8: N=2 T=0 (1 1 3) (2 2 6)
EOF
expect "ralloc: Decision 75: call crossing on the new intervals: an if part's temporaries do not cross the loop's call" "$T/ra" "$T/ra_q.in" 0 "$T/ra_q.exp" /dev/null

# r. ra_else's precondition (L-bv, API.md): B must be the innermost open block, of kind if, with its
#    first part current; any other call is a caller bug reported by dg_bug (internal error, status 11,
#    "ralloc: <message>" on standard error, nothing more on standard output), before anything changes.
ra_else_bug() { # DESC NAME BLOCK  (the records of the case are in $T/ra_NAME.in)
    printf 'I T=0\n' > "$T/ra_$2.exp"
    printf 'ralloc: ra_else: block %s is not the innermost open if block with its first part current\n' "$3" > "$T/ra_$2.err"
    expect "$1" "$T/ra" "$T/ra_$2.in" 11 "$T/ra_$2.exp" "$T/ra_$2.err"
}
{ ratab; printf 'F\nO 3 1 1 3 2\nZ 7 1\n'; } > "$T/ra_r1.in"
ra_else_bug "ralloc: ra_else on a loop block is reported through dg_bug (status 11)" r1 1
{ ratab; printf 'F\nO 3 1 3 0 0\nO 4 2 3 0 0\nZ 7 1\n'; } > "$T/ra_r2.in"
ra_else_bug "ralloc: ra_else on an if block that is not the innermost open block is reported through dg_bug" r2 1
{ ratab; printf 'F\nO 3 1 3 0 0\nZ 7 1\nZ 8 1\n'; } > "$T/ra_r3.in"
ra_else_bug "ralloc: a second ra_else for the same if block is reported through dg_bug" r3 1
{ ratab; printf 'F\nZ 7 1\n'; } > "$T/ra_r4.in"
ra_else_bug "ralloc: ra_else with no open block is reported through dg_bug" r4 1

# ==============================================================================================
# 6. seaval: the dump examples of DESIGN 3.4, 3.5.8, 3.6.7 are valid; mutated copies are rejected
# ==============================================================================================
build seaval "$SEA/tools/seaval.bas" errors consts records

# the first fenced block after the line that contains ANCHOR (the examples are taken from the document)
doc_block() {
    awk -v a="$1" 'f == 0 && index($0, a) { f = 1; next } f == 1 && /^```/ { f = 2; next } f == 2 && /^```/ { exit } f == 2 { print }' "$DOC"
}
doc_block '`sea build --emit ast --no-prelude ex.sea`:' > "$T/ex/ast"
doc_block '`sea build --emit hir1 --no-prelude ex.sea`:' > "$T/ex/hir1"
doc_block '`sea build --emit res --no-prelude rs.sea`:' > "$T/ex/res"
doc_block '`sea build --emit hir --no-prelude ex.sea` differs only' > "$T/ex/hir.fn"
doc_block '`sea build --emit lir1 --no-prelude lx.sea`:' > "$T/ex/lir1"
for f in ast res hir1 hir.fn lir1; do
    [ -s "$T/ex/$f" ] || { echo "lib_check: example $f not found in $DOC" >&2; exit 2; }
done
# sea.hir = sea.hir1 up to the function "scale", then the dump of DESIGN 3.5.8 for that function:
# "(The records before fn 2 are those of the sea.hir1 dump above.)"
k=$(grep -n '^fn 2 scale' "$T/ex/hir1" | cut -d: -f1)
head -n $((k - 1)) "$T/ex/hir1" > "$T/ex/hir"
cat "$T/ex/hir.fn" >> "$T/ex/hir"
# "sea build --emit lir ... is identical" (DESIGN 3.6.7)
cp "$T/ex/lir1" "$T/ex/lir"

valid() { # DESC KIND FILE
    (echo "$2"; cat "$3") > "$T/v.in"
    expect "seaval accepts $1" "$T/seaval" "$T/v.in" 0 /dev/null /dev/null
}
valid "sea.ast of DESIGN 3.4 ($(wc -l < "$T/ex/ast" | tr -d ' ') records)" ast "$T/ex/ast"
valid "sea.res of DESIGN 3.4.1 ($(wc -l < "$T/ex/res" | tr -d ' ') records)" res "$T/ex/res"
valid "sea.hir1 of DESIGN 3.5.8 ($(wc -l < "$T/ex/hir1" | tr -d ' ') records)" hir1 "$T/ex/hir1"
valid "sea.hir of DESIGN 3.5.8 ($(wc -l < "$T/ex/hir" | tr -d ' ') records)" hir "$T/ex/hir"
valid "sea.lir1 of DESIGN 3.6.7" lir1 "$T/ex/lir1"
valid "sea.lir of DESIGN 3.6.7" lir "$T/ex/lir"
# a hand-written LIR file with a slot, blocks (do, if, else, exit, next), a runtime call, chk, and every kind of data record
cat > "$T/ex/lirx" <<'EOS'
#sea 1
#target arm64-macos
#file t.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 5
sa p2 s1
sti i1 p2 - 1 0
la p3 d1
la p4 d2
rcall sea_printf 0:3 0 2 p4 p2
la p5 d3
ldi i6 p5 i1 8 0
do 1
li i7 1
icmp eq i8 i7 i1
if 2 i8
exit 1
else 2
next 1
endif 2
enddo 1
chk i8 INT_OVERFLOW 0:4 0
ret 0
endfunc
func f fn 0:6:1 2 i1 f2 1 f
mov f3 f2
ret 1 f3
endfunc
str d1 hello%20world%0A
fmt d2 2
ftext hi
fconv l - 3 d i
dat d3 i64 2
dvi 5
dvi -1
#end
EOS
valid "a LIR file with slots, blocks, rcall, chk and every data record, as lir1" lir1 "$T/ex/lirx"
valid "the same as lir" lir "$T/ex/lirx"
# vector, mask and variant-flag instructions belong to sea.lir only (DESIGN 3.6.5)
cat > "$T/ex/lirv" <<'EOS'
#sea 1
#target x86_64-linux
#file t.sea
func v fn 0:1:1 1 p1 1 f
ldx x2 p1 - 1 0
xadd x3 x2 x2
xlane f4 x3 1
xcmp lt m5 x2 x3
xsel x6 m5 x2 x3
stx x6 p1 - 1 16
vfeat i7 avx2
if 1 i7
endif 1
ret 1 f4
endfunc
#end
EOS
valid "a sea.lir file with vector, mask and vfeat instructions" lir "$T/ex/lirv"

# a hand-written LIR file with the phase-4 records (DESIGN 3.6.2, 3.6.4, 3.6.5): retain, release, mcopy, slay, soff
cat > "$T/ex/lir4" <<'EOS'
#sea 1
#target arm64-macos
#file t.sea
func .main main 0:1:1 0 0
la p1 d1
li i2 1
li i3 2
li i4 1
rcall sea_arr_new_s 0:2 1 p5 4 p1 i2 i3 i4
retain p5
release p5
la p6 d2
la p7 d3
li i8 16
mcopy p6 p7 i8
la p9 d4
ret 0
endfunc
slay d1 24 2
soff 0
soff 16
slay d2 8 0
dat d3 i64 2
dvi 7
dvi -7
slay d4 40 3
soff 8
soff 16
soff 32
#end
EOS
valid "a LIR file with retain, release, mcopy, slay and soff records, as lir1" lir1 "$T/ex/lir4"
valid "the same as lir" lir "$T/ex/lir4"

# mutations: awk helpers (portable). del FILE REGEX removes the first matching line; rep FILE REGEX LINE replaces it.
mut_del() { awk -v p="$2" '$0 ~ p && !d { d = 1; next } { print }' "$1"; }
mut_rep() { awk -v p="$2" -v r="$3" '$0 ~ p && !d { d = 1; print r; next } { print }' "$1"; }
lineof() { awk -v p="$2" '$0 ~ p { print NR; exit }' "$1"; }
lastlineof() { awk -v p="$2" '$0 ~ p { n = NR } END { print n }' "$1"; }

rejects() { # DESC KIND FILE ERRNAME LINE-OR-0 WHAT
    (echo "$2"; cat "$3") > "$T/v.in"
    runp "$T/seaval" "$T/v.in"
    want=$(errtext "$4")
    last=$(tail -n 1 "$T/err")
    if [ "$5" = 0 ]; then pat="seaval: $6"; else pat="seaval: line $5: "; fi
    if [ "$rc" -eq 11 ] && [ ! -s "$T/out" ] && [ "$last" = "seaval: $want" ] && grep -qF -- "$pat" "$T/err" && { [ -z "$6" ] || [ "$5" = 0 ] || grep -qF -- "$6" "$T/err"; }; then
        ok "seaval rejects $1 (status 11, $(head -n 1 "$T/err" | cut -c1-90))"
    else
        bad "seaval rejects $1" "status $rc (wanted 11), stdout: $(head -c 100 "$T/out")" "wanted line: $pat / last line: seaval: $want" "stderr: $(head -c 400 "$T/err")"
    fi
}
mutf() { cat > "$T/mut/$1"; }   # mutf NAME < content

n=$(lineof "$T/ex/ast" '^#end$')
mut_del "$T/ex/ast" '^#end$' > "$T/mut/a1"
rejects "sea.ast without #end (truncated input)" ast "$T/mut/a1" TRUNCATED 0 "input ends after line $((n - 1))"
mut_del "$T/ex/ast" '^prog ' > "$T/mut/a2"
rejects "sea.ast without prog (nodes left at #end)" ast "$T/mut/a2" BAD_TREE "$(lineof "$T/mut/a2" '^#end$')" "left on the stack"
mut_rep "$T/ex/ast" '^prog ' 'prog 9' > "$T/mut/a3"
rejects "prog that pops more nodes than the stack holds" ast "$T/mut/a3" BAD_TREE "$(lineof "$T/ex/ast" '^prog ')" "pops 9 nodes"
mut_rep "$T/ex/ast" '^prog ' 'prog 3' > "$T/mut/a3b"
rejects "prog that leaves nodes on the stack" ast "$T/mut/a3b" BAD_TREE "$(lineof "$T/ex/ast" '^prog ')" "leaves nodes"
mut_rep "$T/ex/ast" '^float 0:5:25 ' 'flot 0:5:25 #4000000000000000' > "$T/mut/a4"
rejects "an unknown opcode" ast "$T/mut/a4" BAD_RECORD "$(lineof "$T/ex/ast" '^float 0:5:25 ')" "unknown opcode 'flot'"
mut_rep "$T/ex/ast" '^str 0:14:8 ' 'str 0:14:8 %25.3f%0a' > "$T/mut/a5"
rejects "a lower-case %-escape" ast "$T/mut/a5" BAD_RECORD "$(lineof "$T/ex/ast" '^str 0:14:8 ')" "field v"
mut_rep "$T/ex/ast" '^str 0:14:8 ' 'str 0:14:8 %25.3f%0' > "$T/mut/a6"
rejects "a truncated %-escape" ast "$T/mut/a6" BAD_RECORD "$(lineof "$T/ex/ast" '^str 0:14:8 ')" "field v"
mut_rep "$T/ex/ast" '^str 0:14:8 ' 'str 0:14:8 %25.3f%zz' > "$T/mut/a6b"
rejects "a %-escape with non-hex digits" ast "$T/mut/a6b" BAD_RECORD "$(lineof "$T/ex/ast" '^str 0:14:8 ')" "field v"
mut_rep "$T/ex/ast" '^str 0:14:8 ' 'str 0:14:8 %41' > "$T/mut/a6c"
rejects "an escape of a byte that is written as itself (%41)" ast "$T/mut/a6c" BAD_RECORD "$(lineof "$T/ex/ast" '^str 0:14:8 ')" "field v"
mut_rep "$T/ex/ast" '^int 0:8:16 ' 'int 0:8:16 x3' > "$T/mut/a7"
rejects "an i field that is not a number" ast "$T/mut/a7" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "field v"
mut_rep "$T/ex/ast" '^int 0:8:16 ' 'int 0:8:16 1234567890' > "$T/mut/a7b"
rejects "an i field of 10 digits (hex is required from 1E9)" ast "$T/mut/a7b" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "field v"
mut_rep "$T/ex/ast" '^float 0:5:25 ' 'float 0:5:25 4000000000000000' > "$T/mut/a7c"
rejects "an f field without the #" ast "$T/mut/a7c" BAD_RECORD "$(lineof "$T/ex/ast" '^float 0:5:25 ')" "field v"
mut_rep "$T/ex/ast" '^asg 0:11:5 add$' 'asg 0:11:5 plus' > "$T/mut/a8"
rejects "a word outside the enumeration (asgop)" ast "$T/mut/a8" BAD_RECORD "$(lineof "$T/ex/ast" '^asg 0:11:5 add$')" "enumeration asgop"
mut_rep "$T/ex/ast" '^param 0:5:10 p 0 0$' 'param 0:5:10 p 0' > "$T/mut/a9"
rejects "a record with a field missing" ast "$T/mut/a9" BAD_RECORD "$(lineof "$T/ex/ast" '^param 0:5:10 p 0 0$')" "too few fields"
mut_rep "$T/ex/ast" '^param 0:5:10 p 0 0$' 'param 0:5:10 p 0 0 0' > "$T/mut/a9b"
rejects "a record with a field too many" ast "$T/mut/a9b" BAD_RECORD "$(lineof "$T/ex/ast" '^param 0:5:10 p 0 0$')" "too many fields"
mut_rep "$T/ex/ast" '^int 0:8:16 ' 'int 5:8:16 3' > "$T/mut/a10"
rejects "a position in a file that has no #file record" ast "$T/mut/a10" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "names file 5"
mut_rep "$T/ex/ast" '^int 0:8:16 ' 'int 0:0:16 3' > "$T/mut/a10b"
rejects "a position with line 0" ast "$T/mut/a10b" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "field pos"
mut_rep "$T/ex/ast" '^int 0:8:16 ' 'int 0:8:16  3' > "$T/mut/a11"
rejects "two blanks in a row" ast "$T/mut/a11" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "blank"
mut_rep "$T/ex/ast" '^int 0:8:16 ' "$(printf 'int 0:8:16\t3')" > "$T/mut/a12"
rejects "a tab in a record" ast "$T/mut/a12" BAD_RECORD "$(lineof "$T/ex/ast" '^int 0:8:16 ')" "byte outside"
(cat "$T/ex/ast"; echo 'int 0:1:1 1') > "$T/mut/a13"
rejects "a record after #end" ast "$T/mut/a13" BAD_RECORD 0 "records follow #end"
(sed '$d' "$T/ex/ast"; echo 'int 0:1:1 1'; echo '#end') > "$T/mut/a14"
rejects "a record after prog" ast "$T/mut/a14" BAD_RECORD "$(lineof "$T/mut/a14" '^int 0:1:1 1$')" "after prog"
mut_rep "$T/ex/ast" '^#target ' '#target z80' > "$T/mut/a15"
rejects "an unknown target in the header" ast "$T/mut/a15" BAD_HEADER 0 "internal error: bad header"
mut_rep "$T/ex/ast" '^#sea ' '#sea 2' > "$T/mut/a16"
rejects "a wrong format version in the header" ast "$T/mut/a16" BAD_HEADER 0 "internal error: bad header"
mut_rep "$T/ex/ast" '^#file ' '#file a%zz' > "$T/mut/a17"
rejects "a bad %-escape in a #file path" ast "$T/mut/a17" BAD_HEADER 0 "internal error: bad header"
(echo '#sea 1'; echo '#file ex.sea'; echo '#target arm64-macos'; echo '#end') > "$T/mut/a18"
rejects "header records in the wrong order" ast "$T/mut/a18" BAD_HEADER 0 "internal error: bad header"
# sea.res (DESIGN 3.4.1): the records of codes 50-63 exist only in it; rerr and rtup are declarations
mut_rep "$T/ex/res" '^rtup 10 2 4 3$' 'rtup 11 2 4 3' > "$T/mut/r1"
rejects "an rtup whose id does not start at 10" res "$T/mut/r1" BAD_TREE "$(lineof "$T/ex/res" '^rtup ')" "rtup id 11 where 10"
mut_rep "$T/ex/res" '^rtup 10 2 4 3$' 'rtup 10 2 4 10' > "$T/mut/r2"
rejects "an rtup that names itself" res "$T/mut/r2" BAD_RECORD "$(lineof "$T/ex/res" '^rtup ')" "defined type id"
mut_rep "$T/ex/res" '^rtup 10 2 4 3$' 'rtup 10 1 4' > "$T/mut/r3"
rejects "an rtup with one component" res "$T/mut/r3" BAD_TREE "$(lineof "$T/ex/res" '^rtup ')" "fewer than 2"
(sed -n '1,3p' "$T/ex/res"; echo 'rerr 0:2:5 200 1 q'; sed -n '4,$p' "$T/ex/res") > "$T/mut/r4"
(echo res; cat "$T/mut/r4") > "$T/v.in"
expect "seaval accepts an rerr (code 200, one argument) before the rtup records" "$T/seaval" "$T/v.in" 0 /dev/null /dev/null
(sed -n '1,4p' "$T/ex/res"; echo 'rerr 0:2:5 200 1 q'; sed -n '5,$p' "$T/ex/res") > "$T/mut/r5"
rejects "an rerr after an rtup" res "$T/mut/r5" BAD_TREE "$(lineof "$T/mut/r5" '^rerr ')" "rerr is not the first"
(sed -n '1,3p' "$T/ex/res"; echo 'rerr 0:2:5 200 2 q r'; sed -n '4,$p' "$T/ex/res") > "$T/mut/r6"
rejects "an rerr whose k differs from the arguments of its code" res "$T/mut/r6" BAD_TREE "$(lineof "$T/mut/r6" '^rerr ')" "phase C2 with 2 arguments"
(sed -n '1,3p' "$T/ex/res"; echo 'rerr 0:2:5 100 0'; sed -n '4,$p' "$T/ex/res") > "$T/mut/r7"
rejects "an rerr with a code of another phase" res "$T/mut/r7" BAD_TREE "$(lineof "$T/mut/r7" '^rerr ')" "phase C2"
(sed '$d' "$T/ex/res" | sed '$d'; echo 'rtup 11 2 4 3'; echo 'prog 4'; echo '#end') > "$T/mut/r8"
rejects "an rtup after the tree began" res "$T/mut/r8" BAD_TREE "$(lineof "$T/mut/r8" '^rtup 11')" "after the tree began"
mut_rep "$T/ex/res" '^rname 0:3:17 x loc 1$' 'rname 0:3:17 x sideways 1' > "$T/mut/r9"
rejects "a word outside the enumeration (nkind)" res "$T/mut/r9" BAD_RECORD "$(lineof "$T/ex/res" '^rname 0:3:17 ')" "enumeration nkind"
mut_rep "$T/ex/res" '^rcni 0:1:1 N 0 1 6$' 'rcni 0:1:1 N 0 1 six' > "$T/mut/r10"
rejects "an rcni whose value is not a number" res "$T/mut/r10" BAD_RECORD "$(lineof "$T/ex/res" '^rcni ')" "field v"
mut_rep "$T/ex/res" '^rpname 0:3:9 k 2$' 'rpname 0:3:9 k 0' > "$T/mut/r11"
rejects "an rpname with the local number 0" res "$T/mut/r11" BAD_RECORD "$(lineof "$T/ex/res" '^rpname 0:3:9 ')" "not a local"
rejects "an rtup record in sea.ast (codes 50-63 are sea.res only)" ast "$T/ex/res" BAD_RECORD "$(lineof "$T/ex/res" '^rtup ')" "unknown opcode 'rtup' for format ast"
mut_del "$T/ex/res" '^rtup ' > "$T/mut/r13"
rejects "an rint record in sea.ast, not only rtup" ast "$T/mut/r13" BAD_RECORD "$(lineof "$T/mut/r13" '^rint ')" "unknown opcode 'rint' for format ast"
mut_rep "$T/ex/res" '^rfn 0:2:1 split 0 1 2 2 10 4$' 'rfn 0:2:1 split 0 1 2 2 11 4' > "$T/mut/r14"
rejects "an rfn result type that is not defined" res "$T/mut/r14" BAD_RECORD "$(lineof "$T/ex/res" '^rfn ')" "defined type id"
mut_rep "$T/ex/res" '^rfn 0:2:1 split 0 1 2 2 10 4$' 'rfn 0:2:1 split 0 1 2 2 0 0' > "$T/mut/r15"
(echo res; cat "$T/mut/r15") > "$T/v.in"
expect "seaval accepts the type 0 (a type with an error) in sea.res" "$T/seaval" "$T/v.in" 0 /dev/null /dev/null
mut_rep "$T/ex/hir1" '^cf 0:6:27 ' 'cf 0:6:27 4 #3FE0000000000000' > "$T/mut/h0"
rejects "a sea.hir1 file read as sea.ast (opcodes of another format)" ast "$T/ex/hir1" BAD_RECORD "$(lineof "$T/ex/hir1" '^tstruct ')" "unknown opcode 'tstruct' for format ast"

mut_rep "$T/ex/hir1" '^tvec 11 3$' 'tvec 12 3' > "$T/mut/h1"
rejects "a type id that skips one (tvec 12 after 10)" hir1 "$T/mut/h1" BAD_TREE "$(lineof "$T/ex/hir1" '^tvec 11 3$')" "type id 12"
mut_rep "$T/ex/hir1" '^lv 0:6:12 10 1$' 'lv 0:6:12 99 1' > "$T/mut/h2"
rejects "a ty reference to an undefined type" hir1 "$T/mut/h2" BAD_RECORD "$(lineof "$T/ex/hir1" '^lv 0:6:12 10 1$')" "defined type id"
mut_rep "$T/ex/hir1" '^lv 0:6:12 10 1$' 'lv 0:6:12 10 9' > "$T/mut/h3"
rejects "a local that the function does not have" hir1 "$T/mut/h3" BAD_RECORD "$(lineof "$T/ex/hir1" '^lv 0:6:12 10 1$')" "not a local"
mut_del "$T/ex/hir1" '^lv 0:6:18 4 2$' > "$T/mut/h4"
rejects "an operand missing (pops more than the stack holds)" hir1 "$T/mut/h4" BAD_TREE "$(lineof "$T/mut/h4" '^bin 0:6:12 4 mul$')" "pops 2 nodes but the stack holds 1"
mut_del "$T/ex/hir1" '^end$' > "$T/mut/h5"
rejects "a function without end" hir1 "$T/mut/h5" BAD_TREE "$(lineof "$T/mut/h5" '^fn 2 ')" "fn inside a function"
mut_del "$T/ex/hir1" '^fd n 3$' > "$T/mut/h6"
rejects "a tstruct with one fd record missing" hir1 "$T/mut/h6" BAD_TREE "$(lineof "$T/mut/h6" '^tvec ')" "fd record expected"
mut_del "$T/ex/hir1" '^par k 4 val$' > "$T/mut/h7"
rejects "a function with a par record missing" hir1 "$T/mut/h7" BAD_TREE "$(lineof "$T/mut/h7" '^lv 0:6:12 10 1$')" "par / loc"
mut_rep "$T/ex/hir1" '^powk 0:6:18 4 2$' 'inst 1 2 4 0' > "$T/mut/h8"
rejects "an inst record in sea.hir1" hir1 "$T/mut/h8" BAD_RECORD "$(lineof "$T/ex/hir1" '^powk 0:6:18 4 2$')" "unknown opcode 'inst' for format hir1"
mut_rep "$T/ex/hir1" '^bin 0:6:27 4 mul$' 'bin 0:6:27 4 plus' > "$T/mut/h9"
rejects "a word outside the enumeration (hbinop)" hir1 "$T/mut/h9" BAD_RECORD "$(lineof "$T/ex/hir1" '^bin 0:6:27 4 mul$')" "enumeration hbinop"
mut_del "$T/ex/hir1" '^block 0:5:37 1$' > "$T/mut/h10"
rejects "end that does not pop a block" hir1 "$T/mut/h10" BAD_TREE "$(lastlineof "$T/mut/h10" '^end$')" "must pop the function body"
mut_del "$T/ex/hir1" '^loc t 4 var 0:9:5$' > "$T/mut/h11"
rejects "a function with a loc record missing" hir1 "$T/mut/h11" BAD_TREE "$(lineof "$T/mut/h11" '^cf 0:8:22 ')" "par / loc"
mut_rep "$T/ex/hir1" '^fn 2 scale' 'fn 3 scale fn 4 2 0 0:5:1' > "$T/mut/h12"
rejects "functions not numbered from 1 in order" hir1 "$T/mut/h12" BAD_TREE "$(lineof "$T/ex/hir1" '^fn 2 scale')" "fn numbered 3"
(sed '/^fn 1 /,$d' "$T/ex/hir1"; echo 'ci 0:1:1 3 1'; sed -n '/^fn 1 /,$p' "$T/ex/hir1") > "$T/mut/h13"
rejects "a node outside a function in sea.hir" hir "$T/mut/h13" BAD_TREE "$(lineof "$T/mut/h13" '^ci 0:1:1 3 1$')" "outside a function"
mut_rep "$T/ex/hir1" '^cf 0:8:22 ' 'cf 0:8:22 4 #3FF8000000000000 x' > "$T/mut/h14"
rejects "an f64 constant record with a field too many" hir1 "$T/mut/h14" BAD_RECORD "$(lineof "$T/ex/hir1" '^cf 0:8:22 ')" "too many fields"
mut_rep "$T/ex/hir1" '^fconv ' 'fconv 0:14:8 1 zz - 3 f' > "$T/mut/h15"
rejects "a fl field with a bad flag" hir1 "$T/mut/h15" BAD_RECORD "$(lineof "$T/ex/hir1" '^fconv ')" "field fl"
mut_rep "$T/ex/hir1" '^fconv ' 'fconv 0:14:8 1 sp - 3 f' > "$T/mut/h16"
rejects "flags out of order (s before p)" hir1 "$T/mut/h16" BAD_RECORD "$(lineof "$T/ex/hir1" '^fconv ')" "field fl"

# sea.hirl (DESIGN 3.5.9, sets H HF HL): the committed golden of rule 30 is valid; mutated copies are rejected
HIRL=$SEA/tests/passes/arr_rule30.hirl
[ -s "$HIRL" ] || { echo "lib_check: $HIRL not found" >&2; exit 2; }
valid "sea.hirl golden tests/passes/arr_rule30.hirl ($(wc -l < "$HIRL" | tr -d ' ') records)" hirl "$HIRL"
rejects "a sea.hirl file read as sea.hir (an HL record under format hir)" hir "$HIRL" BAD_RECORD "$(lineof "$HIRL" '^tptr ')" "unknown opcode 'tptr' for format hir"
mut_rep "$HIRL" '^tmp ' 'tmp 0:7:6' > "$T/mut/hl1"
rejects "a tmp record with a missing field" hirl "$T/mut/hl1" BAD_RECORD "$(lineof "$HIRL" '^tmp ')" "too few fields"
mut_rep "$HIRL" '^wbin ' 'wbin 0:7:6 3 div' > "$T/mut/hl2"
rejects "a wbin with an operator outside enumeration wop" hirl "$T/mut/hl2" BAD_RECORD "$(lineof "$HIRL" '^wbin ')" "enumeration wop"
mut_rep "$HIRL" '^tptr ' 'tptr 11 12' > "$T/mut/hl3"
rejects "a tptr whose element type is not defined" hirl "$T/mut/hl3" BAD_RECORD "$(lineof "$HIRL" '^tptr ')" "defined type id"
mut_del "$HIRL" '^est ' > "$T/mut/hl4"
rejects "an est missing (nodes left on the stack at the end of the function)" hirl "$T/mut/hl4" BAD_TREE "$(lineof "$T/mut/hl4" '^end$')" "left on the stack"

mut_rep "$T/ex/lir1" '^li i4 4$' 'li i9 4' > "$T/mut/l1"
rejects "a register that skips a number" lir1 "$T/mut/l1" BAD_RECORD "$(lineof "$T/ex/lir1" '^li i4 4$')" "not the next register"
mut_rep "$T/ex/lir1" '^fadd f3 f3 f10$' 'fadd f3 i3 f10' > "$T/mut/l2"
rejects "a register used with two classes" lir1 "$T/mut/l2" BAD_RECORD "$(lineof "$T/ex/lir1" '^fadd f3 f3 f10$')" "register class"
mut_rep "$T/ex/lir1" '^itof f9 i8$' 'itof f9 f8' > "$T/mut/l3"
rejects "an operand of the wrong class (itof of an f)" lir1 "$T/mut/l3" BAD_RECORD "$(lineof "$T/ex/lir1" '^itof f9 i8$')" "register class"
mut_rep "$T/ex/lir1" '^endloop 2$' 'endloop 3' > "$T/mut/l4"
rejects "endloop of another block number" lir1 "$T/mut/l4" BAD_RECORD "$(lineof "$T/ex/lir1" '^endloop 2$')" "block 3"
mut_del "$T/ex/lir1" '^endloop 2$' > "$T/mut/l5a"
mut_del "$T/mut/l5a" '^endif 1$' > "$T/mut/l5"
rejects "a loop that is never closed" lir1 "$T/mut/l5" BAD_RECORD "$(lastlineof "$T/mut/l5" '^endfunc$' | head -1)" "endfunc with open blocks"
sed '$d' "$T/ex/lir1" > "$T/mut/l6"
rejects "sea.lir1 without #end (truncated input)" lir1 "$T/mut/l6" TRUNCATED 0 "input ends after line $(wc -l < "$T/mut/l6" | tr -d ' ')"
mut_del "$T/ex/lir1" '^endfunc$' > "$T/mut/l7"
rejects "a function without endfunc" lir1 "$T/mut/l7" BAD_RECORD "$(lineof "$T/mut/l7" '^func tri ')" "inside a function"
mut_rep "$T/ex/lir1" '^fadd f3 f3 f10$' 'xadd f3 f3 f10' > "$T/mut/l8"
rejects "a 2-lane vector instruction in sea.lir1" lir1 "$T/mut/l8" BAD_RECORD "$(lineof "$T/ex/lir1" '^fadd f3 f3 f10$')" "unknown opcode 'xadd'"
# lir1 numbers data labels by first reference: a defined label that nothing uses cannot occur (DESIGN 3.6.2)
ND=$(grep -c '^str d\|^fmt d\|^dat d' "$T/ex/lir1")
{ sed '$d' "$T/ex/lir1"; echo "str d$((ND + 1)) abc"; echo "#end"; } > "$T/mut/l9"
rejects "a lir1 data label that no instruction uses" lir1 "$T/mut/l9" BAD_RECORD "$(lineof "$T/mut/l9" '^#end$')" "is defined but no instruction uses it"
(echo lir; cat "$T/mut/l9") > "$T/v.in"
expect "seaval accepts the same unreferenced label as lir (no first-reference numbering)" "$T/seaval" "$T/v.in" 0 /dev/null /dev/null
(echo lir2; cat "$T/mut/l9") > "$T/v.in"
expect "seaval accepts the same unreferenced label as lir2 (T10 may delete the la that used it, L-bu)" "$T/seaval" "$T/v.in" 0 /dev/null /dev/null
# the format line is compared with its length (Baysick: trailing blanks are ignored by =)
for f in "lir1 " "lir1  " "ast " ; do
    (printf '%s\n' "$f"; cat "$T/ex/lir1") > "$T/v.in"
    printf 'seaval: the first input line must name the format: ast, res, hir1, hir, hirl, lir1 or lir\n' > "$T/fmt.err"
    runp "$T/seaval" "$T/v.in"
    if [ "$rc" -eq 11 ] && [ ! -s "$T/out" ] && grep -qF "the first input line must name the format" "$T/err"; then ok "seaval rejects the format line '$f' (trailing blank)"; else bad "seaval rejects the format line '$f'" "status $rc (wanted 11)" "stderr: $(head -c 200 "$T/err")"; fi
done
mut_rep "$T/ex/lir1" '^func tri fn 0:1:1 2 i1 f2 1 f$' 'func tri fn 0:1:1 2 i1 f2 1 q' > "$T/mut/l9"
rejects "a result class outside rcls" lir1 "$T/mut/l9" BAD_RECORD "$(lineof "$T/ex/lir1" '^func tri ')" "enumeration rcls"
mut_rep "$T/ex/lir1" '^rcount ' 'rcount i6 i7 i4 i1 i5 0 03' > "$T/mut/l10"
rejects "a site that is not F:L" lir1 "$T/mut/l10" BAD_RECORD "$(lineof "$T/ex/lir1" '^rcount ')" "field site"
mut_rep "$T/ex/lir1" '^if 1 i7$' 'if 2 i7' > "$T/mut/l11"
rejects "blocks not numbered from 1" lir1 "$T/mut/l11" BAD_RECORD "$(lineof "$T/ex/lir1" '^if 1 ')" "block 2 opened where 1"
mut_rep "$T/ex/lir1" '^icmp ' 'icmp zz i7 i4 i6' > "$T/mut/l11b"
mut_rep "$T/ex/lirx" '^icmp eq i8 i7 i1$' 'icmp zz i8 i7 i1' > "$T/mut/l11c"
rejects "a condition code outside cc" lir1 "$T/mut/l11c" BAD_RECORD "$(lineof "$T/ex/lirx" '^icmp ')" "enumeration cc"
mut_rep "$T/ex/lirx" '^exit 1$' 'exit 7' > "$T/mut/x1"
rejects "exit of a block that is not an open loop" lir1 "$T/mut/x1" BAD_RECORD "$(lineof "$T/ex/lirx" '^exit 1$')" "not an open loop or do"
mut_rep "$T/ex/lirx" '^sa p2 s1$' 'sa p2 s2' > "$T/mut/x2"
rejects "a slot that func did not declare" lir1 "$T/mut/x2" BAD_RECORD "$(lineof "$T/ex/lirx" '^sa p2 s1$')" "slot"
awk '/^slot s1 16 8$/ { next } /^li i1 5$/ { print; print "slot s1 16 8"; next } { print }' "$T/ex/lirx" > "$T/mut/x3"
rejects "a slot record after an instruction" lir1 "$T/mut/x3" BAD_RECORD "$(lineof "$T/mut/x3" '^slot ')" "not directly after func"
mut_rep "$T/ex/lirx" '^slot s1 16 8$' 'slot s1 16 6' > "$T/mut/x3b"
rejects "a slot alignment that is not a power of two" lir1 "$T/mut/x3b" BAD_RECORD "$(lineof "$T/ex/lirx" '^slot ')" "power of two"
mut_rep "$T/ex/lirx" '^slot s1 16 8$' 'slot s2 16 8' > "$T/mut/x3c"
rejects "slots not numbered from 1" lir1 "$T/mut/x3c" BAD_RECORD "$(lineof "$T/ex/lirx" '^slot ')" "where s1 was expected"
mut_rep "$T/ex/lirx" 'INT_OVERFLOW' 'chk i8 NO_SUCH_ERROR 0:4 0' > "$T/mut/x4"
rejects "chk naming an error that errors.inc does not have" lir1 "$T/mut/x4" BAD_RECORD "$(lineof "$T/ex/lirx" '^chk ')" "name of the error table"
mut_rep "$T/ex/lirx" 'INT_OVERFLOW' 'chk i8 UNDECLARED 0:4 0' > "$T/mut/x5"
rejects "chk naming a compile error" lir1 "$T/mut/x5" BAD_RECORD "$(lineof "$T/ex/lirx" '^chk ')" "run-time error"
mut_del "$T/ex/lirx" '^dvi -1$' > "$T/mut/x6"
rejects "a dat with a dvi record missing" lir1 "$T/mut/x6" BAD_RECORD "$(lineof "$T/mut/x6" '^#end$')" "sub-records"
mut_rep "$T/ex/lirx" '^dvi -1$' 'dvf #0000000000000000' > "$T/mut/x7"
rejects "a dvf record in an i64 dat" lir1 "$T/mut/x7" BAD_RECORD "$(lineof "$T/ex/lirx" '^dvi -1$')" "dvi records expected"
mut_del "$T/ex/lirx" '^fconv ' > "$T/mut/x8"
rejects "a fmt with an fconv record missing" lir1 "$T/mut/x8" BAD_RECORD "$(lineof "$T/mut/x8" '^dat ')" "ftext / fconv"
mut_rep "$T/ex/lirx" '^fmt d2 2$' 'fmt d5 2' > "$T/mut/x9"
rejects "a data label out of order" lir1 "$T/mut/x9" BAD_RECORD "$(lineof "$T/ex/lirx" '^fmt ')" "d5 where d2 was expected"
awk '/^dat d3 /,/^dvi -1$/ { next } { print }' "$T/ex/lirx" > "$T/mut/x10"
rejects "a label used but never defined" lir1 "$T/mut/x10" BAD_RECORD "$(lineof "$T/mut/x10" '^#end$')" "d3 is used but only 2 are defined"
awk '/^la p3 d1$/ { print "la p3 d2"; next } /^la p4 d2$/ { print "la p4 d1"; next } { print }' "$T/ex/lirx" > "$T/mut/x11"
rejects "labels not in order of first use (lir1)" lir1 "$T/mut/x11" BAD_RECORD "$(lineof "$T/mut/x11" '^la p3 d2$')" "first use"
awk '/^#end$/ { print "func g fn 0:7:1 0 0"; print "endfunc" } { print }' "$T/ex/lirx" > "$T/mut/x12"
rejects "a func after the data records" lir1 "$T/mut/x12" BAD_RECORD "$(lineof "$T/mut/x12" '^func g ')" "func inside a function"
mut_rep "$T/ex/lirx" '^else 2$' 'else 3' > "$T/mut/x13"
rejects "else of another block number" lir1 "$T/mut/x13" BAD_RECORD "$(lineof "$T/ex/lirx" '^else 2$')" "else without"
mut_rep "$T/ex/lirx" '^dvi -1$' 'dvi -0' > "$T/mut/x14"
rejects "the i value -0" lir1 "$T/mut/x14" BAD_RECORD "$(lineof "$T/ex/lirx" '^dvi -1$')" "field v"
mut_rep "$T/ex/lirx" '^li i1 5$' 'li p1 5' > "$T/mut/x15"
rejects "li with a destination of class p" lir1 "$T/mut/x15" BAD_RECORD "$(lineof "$T/ex/lirx" '^li i1 5$')" "register class"
mut_rep "$T/ex/lirx" '^mov f3 f2$' 'mov f3 i2' > "$T/mut/x16"
rejects "a register used with two classes across records" lir1 "$T/mut/x16" BAD_RECORD "$(lineof "$T/ex/lirx" '^mov f3 f2$')" "another class"
mut_rep "$T/ex/lirx" '^mov f3 f2$' 'mov x3 f2' > "$T/mut/x17"
rejects "vector instructions in sea.lir1 (ldx is a sea.lir record)" lir1 "$T/ex/lirv" BAD_RECORD "$(lineof "$T/ex/lirv" '^ldx ')" "unknown opcode 'ldx'"
rejects "a vector register class in sea.lir1" lir1 "$T/mut/x17" BAD_RECORD "$(lineof "$T/ex/lirx" '^mov f3 f2$')" "sea.lir1 does not use"
awk '/^ret 0$/ { print "ret 0"; print "li i11 1"; next } { print }' "$T/ex/lirx" > "$T/mut/x18"
rejects "a register that skips a number (the next after i8 is i9)" lir1 "$T/mut/x18" BAD_RECORD "$(lineof "$T/mut/x18" '^li i11 1$')" "not the next register"
awk '/^func f / { print "li i1 1" } { print }' "$T/ex/lirx" > "$T/mut/x19"
rejects "an instruction outside a function" lir1 "$T/mut/x19" BAD_RECORD "$(lineof "$T/mut/x19" '^li i1 1$')" "outside a function"
# phase-4 records (DESIGN 3.6.5 "Pass 3b from phase 4"): slay / soff / retain / release / mcopy
mut_rep "$T/ex/lir4" '^soff 16$' 'soff 0' > "$T/mut/p1"
rejects "soff not above the previous one" lir1 "$T/mut/p1" BAD_RECORD "$(lineof "$T/ex/lir4" '^soff 16$')" "not above the previous"
mut_rep "$T/ex/lir4" '^soff 0$' 'soff 4' > "$T/mut/p2"
rejects "soff that is not a multiple of 8" lir1 "$T/mut/p2" BAD_RECORD "$(lineof "$T/ex/lir4" '^soff 0$')" "not a multiple of 8"
mut_rep "$T/ex/lir4" '^soff 16$' 'soff 24' > "$T/mut/p3"
rejects "soff above the slay size - 8" lir1 "$T/mut/p3" BAD_RECORD "$(lineof "$T/ex/lir4" '^soff 16$')" "slay size - 8"
mut_del "$T/ex/lir4" '^soff 16$' > "$T/mut/p4"
rejects "a slay with an soff record missing" lir1 "$T/mut/p4" BAD_RECORD "$(lineof "$T/mut/p4" '^slay d2 ')" "inside a slay group"
mut_del "$T/ex/lir4" '^soff 32$' > "$T/mut/p5"
rejects "the last slay with an soff record missing" lir1 "$T/mut/p5" BAD_RECORD "$(lineof "$T/mut/p5" '^#end$')" "sub-records"
awk '{ print } /^soff 32$/ { print "soff 32" }' "$T/ex/lir4" > "$T/mut/p6"
rejects "an soff after the n soff records of its slay" lir1 "$T/mut/p6" BAD_RECORD "$(awk '/^soff 32$/ { n++ } n == 2 { print NR; exit }' "$T/mut/p6")" "outside"
awk '/^endfunc$/ { print; print "soff 0"; next } { print }' "$T/ex/lir4" > "$T/mut/p7"
rejects "an soff before any slay" lir1 "$T/mut/p7" BAD_RECORD "$(lineof "$T/mut/p7" '^soff 0$')" "outside"
mut_rep "$T/ex/lir4" '^slay d2 8 0$' 'slay d5 8 0' > "$T/mut/p8"
rejects "a slay label out of order" lir1 "$T/mut/p8" BAD_RECORD "$(lineof "$T/ex/lir4" '^slay d2 ')" "d5 where d2 was expected"
mut_rep "$T/ex/lir4" '^slay d1 24 2$' 'slay d1 24' > "$T/mut/p9"
rejects "a slay record without n" lir1 "$T/mut/p9" BAD_RECORD "$(lineof "$T/ex/lir4" '^slay d1 ')" "too few fields"
mut_rep "$T/ex/lir4" '^soff 16$' 'soff -8' > "$T/mut/p10"
rejects "a negative soff" lir1 "$T/mut/p10" BAD_RECORD "$(lineof "$T/ex/lir4" '^soff 16$')" "field v"
mut_rep "$T/ex/lir4" '^retain p5$' 'retain i5' > "$T/mut/p11"
rejects "retain of a register of class i" lir1 "$T/mut/p11" BAD_RECORD "$(lineof "$T/ex/lir4" '^retain ')" "register class"
mut_rep "$T/ex/lir4" '^release p5$' 'release f5' > "$T/mut/p12"
rejects "release of a register of class f" lir1 "$T/mut/p12" BAD_RECORD "$(lineof "$T/ex/lir4" '^release ')" "register class"
mut_rep "$T/ex/lir4" '^mcopy p6 p7 i8$' 'mcopy p6 p7 p8' > "$T/mut/p13"
rejects "mcopy with a count of class p" lir1 "$T/mut/p13" BAD_RECORD "$(lineof "$T/ex/lir4" '^mcopy ')" "register class"
mut_rep "$T/ex/lir4" '^mcopy p6 p7 i8$' 'mcopy p6 p7' > "$T/mut/p14"
rejects "mcopy without its count" lir1 "$T/mut/p14" BAD_RECORD "$(lineof "$T/ex/lir4" '^mcopy ')" "too few fields"
mut_rep "$T/ex/lir4" '^retain p5$' 'retain p5 p5' > "$T/mut/p15"
rejects "retain with two operands" lir1 "$T/mut/p15" BAD_RECORD "$(lineof "$T/ex/lir4" '^retain ')" "too many fields"

# sea.res type table of phase 4 (DESIGN 3.4.2): rtvec rtmat rtfvec rtfmat rtst rtfd; the original rtup becomes id 15
awk '/^rtup 10 2 4 3$/ { print "rtst 10 P 1 2"; print "rtfd x 4"; print "rtfd y 11"; print "rtvec 11 4"; print "rtmat 12 3"; print "rtfvec 13 4 3"; print "rtfmat 14 4 2 2"; print "rtup 15 2 4 3"; next } { print }' "$T/ex/res" > "$T/ex/res4"
valid "sea.res with the type table of phase 4 (rtst with its rtfd, rtvec, rtmat, rtfvec, rtfmat, rtup)" res "$T/ex/res4"
mut_rep "$T/ex/res4" '^rtst 10 P 1 2$' 'rtst 11 P 1 2' > "$T/mut/t1"
rejects "an rtst whose id does not start at 10" res "$T/mut/t1" BAD_TREE "$(lineof "$T/ex/res4" '^rtst ')" "rtst id 11 where 10"
mut_rep "$T/ex/res4" '^rtst 10 P 1 2$' 'rtst 10 P 2 2' > "$T/mut/t2"
rejects "an rtst whose sid does not match its id" res "$T/mut/t2" BAD_TREE "$(lineof "$T/ex/res4" '^rtst ')" "9 + s"
mut_del "$T/ex/res4" '^rtfd y 11$' > "$T/mut/t3"
rejects "an rtst with an rtfd record missing" res "$T/mut/t3" BAD_TREE "$(lineof "$T/mut/t3" '^rtvec ')" "fd record expected"
mut_del "$T/ex/res4" '^rtst ' > "$T/mut/t4"
rejects "an rtfd outside an rtst" res "$T/mut/t4" BAD_TREE "$(lineof "$T/mut/t4" '^rtfd x')" "outside an rtst"
mut_rep "$T/ex/res4" '^rtfd y 11$' 'rtfd y 99' > "$T/mut/t5"
rejects "an rtfd naming a type the table does not define" res "$T/mut/t5" BAD_TREE "$(lineof "$T/mut/t5" '^#end$')" "type table ends"
mut_rep "$T/ex/res4" '^rtvec 11 4$' 'rtvec 12 4' > "$T/mut/t6"
rejects "an rtvec whose id skips one" res "$T/mut/t6" BAD_TREE "$(lineof "$T/ex/res4" '^rtvec ')" "rtvec id 12 where 11"
mut_rep "$T/ex/res4" '^rtvec 11 4$' 'rtvec 11 99' > "$T/mut/t7"
rejects "an rtvec whose element type is not defined" res "$T/mut/t7" BAD_RECORD "$(lineof "$T/ex/res4" '^rtvec ')" "defined type id"
mut_rep "$T/ex/res4" '^rtfmat 14 4 2 2$' 'rtfmat 14 4 2' > "$T/mut/t8"
rejects "an rtfmat with a field missing" res "$T/mut/t8" BAD_RECORD "$(lineof "$T/ex/res4" '^rtfmat ')" "too few fields"
awk '/^prog / { print "rtvec 16 4" } { print }' "$T/ex/res4" > "$T/mut/t9"
rejects "a type table record after the tree began" res "$T/mut/t9" BAD_TREE "$(lineof "$T/mut/t9" '^rtvec 16 4$')" "after the tree began"
rejects "an rtvec record in sea.ast (codes 64-72 are sea.res only)" ast "$T/ex/res4" BAD_RECORD "$(lineof "$T/ex/res4" '^rtst ')" "unknown opcode"

(echo foo; cat "$T/ex/lirx") > "$T/v.in"
printf 'seaval: the first input line must name the format: ast, res, hir1, hir, hirl, lir1, lir2 or lir\n' > "$T/fmt.err"
expect "seaval: an unknown format name is reported (status 11)" "$T/seaval" "$T/v.in" 11 /dev/null "$T/fmt.err"

echo
if [ "$FAIL" -eq 0 ]; then
    echo "lib_check: all $PASS checks passed"
    exit 0
fi
echo "lib_check: $FAIL of $((PASS + FAIL)) checks FAILED"
exit 1
