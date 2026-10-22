#!/bin/sh
# tests/driver_check.sh -- tests of the driver `sea` that need no real pass (docs/DESIGN.md 2.2,
# 6.2). POSIX sh. Builds nothing.
#
# The driver under test is driver/sea of the source tree (or $SEA), run with SEA_HOME pointing
# at a scratch installation directory holding errors.inc and limits.inc (copied from
# include/), a prelude, and fake passes: shell scripts that log their name and pass their
# input on (seaparse copies its standard input to sea.ast, the others copy the previous
# file; a pass fails as SEA_FAIL_PASS / SEA_FAIL_STATUS / SEA_FAIL_MSG say). On macOS a tiny
# assembly program stands in for the code generator so that the assemble, link and run steps
# are exercised, with dummy libsea.a and libbaysickrt.a archives.
#
# Expected values are derived from DESIGN.md 2.2, LANGUAGE.md 3.1 and 9.1, and from the exit
# statuses 0 success, 1 compile error, 2 usage or file error, 3 toolchain error, 4 internal
# error. They are written out here, not read from the driver or the contract files.
#
# usage: sh tests/driver_check.sh [-v] [PATTERN...]
# Exit status: 0 all passed, 1 a failure, 2 setup error.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DRIVER=${SEA:-$ROOT/driver/sea}
VERBOSE=0
if [ "${1:-}" = "-v" ]; then VERBOSE=1; shift; fi
PATTERNS="$*"
[ -x "$DRIVER" ] || { echo "driver_check.sh: driver '$DRIVER' not found or not executable" >&2; exit 2; }

T=$(mktemp -d "${TMPDIR:-/tmp}/sea-drv.XXXXXX") || exit 2
T=$(cd "$T" && pwd)
trap 'rm -rf "$T"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
HOME_=$T/home          # the scratch installation directory
W=$T/work              # working directory of the driver
TD=$T/tmp              # TMPDIR of the driver: must be empty after every run
mkdir -p "$HOME_" "$W" "$TD"
: > "$T/empty"
DARWIN=0; [ "$(uname -s)" = Darwin ] && DARWIN=1

PASS=0
FAIL=0
FAILED=""
CUR=
OK=1
begin() { # begin NAME : false if the pattern filter skips it
    CUR=$1; OK=1
    [ -z "$PATTERNS" ] && return 0
    set -f
    for p in $PATTERNS; do
        case "$1" in *"$p"*) set +f; return 0 ;; esac
    done
    set +f
    return 1
}
bad() { # bad REASON : the first failure of a case is reported
    if [ $OK = 1 ]; then FAIL=$((FAIL + 1)); FAILED="$FAILED $CUR"; echo "FAIL $CUR: $1"; fi
    OK=0
}
end() { [ $OK = 1 ] && PASS=$((PASS + 1)); return 0; }

# ---- the scratch installation -----------------------------------------------------------
mkpass() { # mkpass DIR NAME
    cat > "$1/$2" <<'PASSEOF'
#!/bin/sh
p=$(basename "$0")
echo "$p" >> "$SEA_LOG"
pwd >> "$SEA_LOG.cwd"
if [ "$SEA_FAIL_PASS" = "$p" ]; then printf '%s\n' "$SEA_FAIL_MSG" >&2; exit "$SEA_FAIL_STATUS"; fi
case $p in
seaparse) cat > sea.ast ;;
seaname) cp sea.ast sea.res ;;
seacheck) cp sea.res sea.hir1 ;;
seaexpand) cp sea.hir1 sea.hir ;;
sealower) cp sea.hir sea.lir1 ;;
seaopt) cp sea.lir1 sea.lir ;;
seagen_a64 | seagen_x64)
    if [ -n "$SEA_ASM" ]; then cp "$SEA_ASM" sea.s; else cp sea.lir sea.s; fi ;;
esac
exit 0
PASSEOF
    chmod +x "$1/$2"
}
install_fakes() { # install_fakes DIR : a complete scratch installation
    mkdir -p "$1"
    cp "$ROOT/include/errors.inc" "$ROOT/include/limits.inc" "$1/"
    printf '// fake prelude\n' > "$1/std.sea"
    for p in seaparse seaname seacheck seaexpand sealower seaopt seagen_a64 seagen_x64; do mkpass "$1" "$p"; done
}
install_fakes "$HOME_"
if [ $DARWIN = 1 ]; then
    cat > "$T/main.s" <<'ASMEOF'
    .globl _main
    .p2align 2
_main:
    ret
ASMEOF
    cat > "$T/dummy.s" <<'ASMEOF'
    .globl _sea_dummy
    .p2align 2
_sea_dummy:
    ret
ASMEOF
    as -arch arm64 -o "$T/dummy.o" "$T/dummy.s" || { echo "driver_check.sh: cannot assemble the dummy library" >&2; exit 2; }
    ar rcs "$HOME_/libsea.a" "$T/dummy.o" && ar rcs "$HOME_/libbaysickrt.a" "$T/dummy.o" || exit 2
fi

# drive ARGS... : run the driver in $W; sets st; output in $T/o, $T/e; log in $T/log
drive() {
    : > "$T/log"; rm -f "$T/log.cwd"
    (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" "$@") >"$T/o" 2>"$T/e" </dev/null
    st=$?
}
want_status() { [ "$st" = "$1" ] || bad "driver exit status $st, expected $1"; }
want_file() { # want_file ACTUAL EXPECTED LABEL
    if ! cmp -s "$1" "$2"; then
        bad "$3 differs"
        if [ $VERBOSE = 1 ]; then diff -u "$2" "$1" | sed 's/^/    /' | head -40; fi
    fi
}
want_err() { printf '%s\n' "$1" > "$T/want"; want_file "$T/e" "$T/want" "standard error"; }
want_out_empty() { want_file "$T/o" "$T/empty" "standard output"; }
want_log() { # want_log "pass pass ..."
    got=$(tr '\n' ' ' < "$T/log" | sed 's/ $//')
    [ "$got" = "$1" ] || bad "passes run: '$got', expected '$1'"
}
want_tmp_clean() { [ -z "$(ls -A "$TD")" ] || bad "temporary directory left behind: $(ls "$TD")"; }
first_line_is() { # first_line_is LINE : the first line of standard error
    [ "$(sed -n 1p "$T/e")" = "$1" ] || bad "first stderr line '$(sed -n 1p "$T/e")', expected '$1'"
}
bytes() { awk -v n="$1" 'BEGIN { for (i = 0; i < n; i++) printf "x" }'; } # bytes N : N 'x'

echo 'let x = 1' > "$W/p.sea"

# ---- usage errors (status 2) ----------------------------------------------------------------
if begin driver/no-arguments; then
    drive; want_status 2; want_out_empty; first_line_is 'sea: usage: sea build <file.sea> [-o out] [--target arm64-macos|x86_64-linux] [-S] [--emit ast|res|hir1|hir|lir1|lir] [--keep-temps] [--no-prelude]'; want_log ""; end; fi
if begin driver/unknown-command; then
    drive frob p.sea; want_status 2; first_line_is "sea: unknown command 'frob'"; end; fi
if begin driver/unknown-option; then
    drive build p.sea --bogus; want_status 2; want_out_empty; first_line_is "sea: unknown option '--bogus'"; want_log ""; end; fi
if begin driver/option-not-for-run; then
    drive run p.sea -S; want_status 2; first_line_is "sea: unknown option '-S'"; end; fi
if begin driver/missing-arg-o; then
    drive build p.sea -o; want_status 2; first_line_is "sea: missing argument for '-o'"; end; fi
if begin driver/missing-arg-target; then
    drive build p.sea --target; want_status 2; first_line_is "sea: missing argument for '--target'"; end; fi
if begin driver/missing-arg-emit; then
    drive build p.sea --emit; want_status 2; first_line_is "sea: missing argument for '--emit'"; end; fi
if begin driver/unknown-target; then
    drive build p.sea --target riscv64-linux; want_status 2; want_err "sea: unknown target 'riscv64-linux'"; want_log ""; end; fi
if begin driver/unknown-emit; then
    drive build p.sea --emit mir; want_status 2; want_err "sea: unknown emit kind 'mir'"; want_log ""; end; fi
if begin driver/emit-and-S; then
    drive build p.sea -S --emit ast; want_status 2; first_line_is "sea: -S and --emit cannot be combined"; want_log ""; end; fi
if begin driver/no-input-file; then
    drive build -S; want_status 2; first_line_is "sea: missing input file"; end; fi
if begin driver/two-input-files; then
    drive build p.sea q.sea; want_status 2; first_line_is "sea: unexpected argument 'q.sea'"; end; fi
if begin driver/run-needs-native-target; then
    drive run p.sea --target x86_64-linux; want_status 2; first_line_is "sea: unknown option '--target'"; end; fi
if begin driver/help; then
    drive --help; want_status 0; want_file "$T/e" "$T/empty" "standard error"
    [ "$(sed -n 1p "$T/o")" = 'usage: sea build <file.sea> [-o out] [--target arm64-macos|x86_64-linux] [-S] [--emit ast|res|hir1|hir|lir1|lir] [--keep-temps] [--no-prelude]' ] || bad "help text"; end; fi
if begin driver/version; then
    drive --version; want_status 0; want_file "$T/e" "$T/empty" "standard error"
    case $(cat "$T/o") in "sea "[0-9]*) ;; *) bad "version text '$(cat "$T/o")'" ;; esac; end; fi
if begin driver/source-tree-usage; then
    # no SEA_HOME: the driver finds errors.inc and limits.inc beside the source tree
    (cd "$W" && "$DRIVER" build) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 2; first_line_is "sea: missing input file"; end; fi

# ---- file errors (status 2) -------------------------------------------------------------------
if begin driver/missing-input; then
    drive build nofile.sea; want_status 2; want_out_empty; want_err "sea: cannot read 'nofile.sea': No such file or directory"; want_log ""; want_tmp_clean; end; fi
if begin driver/input-is-directory; then
    mkdir -p "$W/adir"; drive build adir; want_status 2; want_err "sea: cannot read 'adir': Is a directory"; end; fi
if begin driver/unwritable-output; then
    drive build p.sea -S -o nodir/out.s; want_status 2; want_err "sea: cannot write '$W/nodir/out.s'"; want_tmp_clean; end; fi

# ---- the line check (step 2): status 1, before any pass --------------------------------------
# A line of 4096 bytes after CR removal is allowed; 4097 is `line too long` at column 4097.
if begin driver/line-4096-ok; then
    { bytes 4096; printf '\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 0; want_log "seaparse seaname seacheck seaexpand sealower seaopt seagen_a64"; end; fi
if begin driver/line-4097; then
    { bytes 4097; printf '\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_out_empty; want_err 'l.sea:1:4097: error: line too long'; want_log ""; want_tmp_clean; end; fi
if begin driver/line-4097-third-line; then
    { printf 'let a = 1\n\n'; bytes 4097; printf '\nlet b = 2\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:3:4097: error: line too long'; want_log ""; end; fi
if begin driver/line-first-of-two-long; then
    { bytes 4100; printf '\n'; bytes 5000; printf '\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; end; fi
if begin driver/line-crlf-4096-ok; then
    { bytes 4096; printf '\r\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 0; end; fi
if begin driver/line-crlf-4097; then
    { bytes 4097; printf '\r\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; want_log ""; end; fi
if begin driver/line-two-cr-4096; then
    # only ONE CR is removed: 4096 bytes + CR CR LF leaves 4097 bytes
    { bytes 4096; printf '\r\r\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; end; fi
if begin driver/line-cr-at-eof-ok; then
    { printf 'let a = 1\n'; bytes 4096; printf '\r'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 0; end; fi
if begin driver/line-cr-at-eof-4097; then
    { printf 'let a = 1\n'; bytes 4097; printf '\r'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:2:4097: error: line too long'; end; fi
if begin driver/line-no-lf-4097; then
    { bytes 4097; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; end; fi
if begin driver/line-counts-bytes-not-characters; then
    # 2049 two-byte characters are 4098 bytes, in whatever locale the caller has
    { awk 'BEGIN { for (i = 0; i < 2049; i++) printf "\303\251" }'; printf '\n'; } > "$W/l.sea"
    (cd "$W" && LC_ALL=en_US.UTF-8 SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build -S -o "$T/o.s" l.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 1; want_err 'l.sea:1:4097: error: line too long'; end; fi
if begin driver/line-path-with-blanks; then
    mkdir -p "$W/sub dir"; { bytes 4097; printf '\n'; } > "$W/sub dir/my file.sea"
    drive build -S -o "$T/o.s" "sub dir/my file.sea"; want_status 1; want_err 'sub dir/my file.sea:1:4097: error: line too long'; end; fi
if begin driver/line-text-from-errors-inc; then
    # the text is read from the installed errors.inc, not written into the script
    mkdir -p "$T/home2"; install_fakes "$T/home2"
    sed 's/"line too long"/"zeile zu lang \\"x\\" \\\\"/' "$ROOT/include/errors.inc" > "$T/home2/errors.inc"
    { bytes 4097; printf '\n'; } > "$W/l.sea"
    (cd "$W" && SEA_HOME=$T/home2 TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build -S -o "$T/o.s" l.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 1; want_err 'l.sea:1:4097: error: zeile zu lang "x" \'; end; fi

# ---- missing pass executables (status 4, naming the executable) ------------------------------------
if begin driver/missing-pass; then
    mkdir -p "$T/home3"; cp "$HOME_/errors.inc" "$HOME_/limits.inc" "$HOME_/std.sea" "$T/home3/"
    (cd "$W" && SEA_HOME=$T/home3 TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 4; want_out_empty; want_err "sea: internal error: pass executable '$T/home3/seaparse' not found (run make)"; want_tmp_clean; end; fi
if begin driver/missing-later-pass; then
    mkdir -p "$T/home4"; install_fakes "$T/home4"; rm "$T/home4/sealower"
    : > "$T/log"
    (cd "$W" && SEA_HOME=$T/home4 TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build -S -o "$T/o.s" p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 4; want_err "sea: internal error: pass executable '$T/home4/sealower' not found (run make)"; want_log "seaparse seaname seacheck seaexpand"; want_tmp_clean; end; fi
if begin driver/emit-needs-only-its-passes; then
    mkdir -p "$T/home5"; install_fakes "$T/home5"; rm "$T/home5/seaname" "$T/home5/seacheck" "$T/home5/sealower"
    : > "$T/log"
    (cd "$W" && SEA_HOME=$T/home5 TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build --emit ast p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 0; want_log "seaparse"; end; fi
if begin driver/emit-res-needs-only-its-passes; then
    mkdir -p "$T/home5b"; install_fakes "$T/home5b"; rm "$T/home5b/seacheck" "$T/home5b/sealower"
    : > "$T/log"
    (cd "$W" && SEA_HOME=$T/home5b TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build --emit res p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 0; want_log "seaparse seaname"; end; fi
if begin driver/missing-std; then
    mkdir -p "$T/home6"; cp "$HOME_/errors.inc" "$HOME_/limits.inc" "$T/home6/"
    (cd "$W" && SEA_HOME=$T/home6 TMPDIR=$TD "$DRIVER" build p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 4; want_err "sea: cannot find '$T/home6/std.sea'"; end; fi

# ---- the pass sequence and the pass-1 input stream ---------------------------------------------------
printf 'let x = 1\r\n\n  y\nz' > "$W/s.sea"
if begin driver/pass-order; then
    drive build -S -o "$T/o.s" p.sea; want_status 0; want_out_empty; want_log "seaparse seaname seacheck seaexpand sealower seaopt seagen_a64"; want_tmp_clean; end; fi
for x in ast:seaparse res:"seaparse seaname" hir1:"seaparse seaname seacheck" hir:"seaparse seaname seacheck seaexpand" lir1:"seaparse seaname seacheck seaexpand sealower" lir:"seaparse seaname seacheck seaexpand sealower seaopt"; do
    k=${x%%:*}; passes=${x#*:}
    if begin driver/emit-$k-stops; then
        drive build --emit $k p.sea; want_status 0; want_log "$passes"; [ -s "$T/o" ] || bad "no dump on standard output"; want_tmp_clean; end; fi
done
if begin driver/stream-no-prelude; then
    drive build --emit ast --no-prelude s.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file s.sea\n|let x = 1\r\n|\n|  y\n|z\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-with-prelude; then
    drive build --emit ast s.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file %s/std.sea\n|// fake prelude\n#file s.sea\n|let x = 1\r\n|\n|  y\n|z\n#end\n' "$HOME_" > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-escaped-path; then
    mkdir -p "$W/sub dir"; printf 'a\n' > "$W/sub dir/p%q.sea"
    drive build --emit ast --no-prelude "sub dir/p%q.sea"; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file sub%%20dir/p%%25q.sea\n|a\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-non-ascii-path; then
    n=$(printf '\303\251.sea'); printf 'a\n' > "$W/$n"
    drive build --emit ast --no-prelude "$n"; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file %%C3%%A9.sea\n|a\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-empty-and-blank-lines; then
    printf '\n\n' > "$W/e.sea"
    drive build --emit ast --no-prelude e.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file e.sea\n|\n|\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-empty-file; then
    : > "$W/e.sea"
    drive build --emit ast --no-prelude e.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file e.sea\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-nul-bytes; then
    printf 'let x = 1 \000 garbage\nz\000\n' > "$W/n.sea"
    drive build --emit ast --no-prelude n.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file n.sea\n|let x = 1 \000 garbage\n|z\000\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; want_tmp_clean; end; fi
if begin driver/stream-nul-with-control-bytes; then
    # bytes 1 and 2 are used in the file, so the driver must pick another substitute
    printf 'a\001\002\000b\n' > "$W/n.sea"
    drive build --emit ast --no-prelude n.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file n.sea\n|a\001\002\000b\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/line-nul-on-long-line; then
    { bytes 10; printf '\000'; bytes 5000; printf '\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; want_log ""; end; fi
if begin driver/line-nul-counts-as-a-byte; then
    { bytes 4095; printf '\000\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 0; end; fi
if begin driver/line-nul-makes-4097; then
    { bytes 4096; printf '\000\n'; } > "$W/l.sea"
    drive build -S -o "$T/o.s" l.sea; want_status 1; want_err 'l.sea:1:4097: error: line too long'; end; fi
if begin driver/stream-final-cr-after-lf; then
    # "abc\n\r": the CR is "a CR at the very end of the file", not an empty last line
    printf 'abc\n\r' > "$W/c.sea"
    drive build --emit ast --no-prelude c.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file c.sea\n|abc\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/stream-file-is-one-cr; then
    printf '\r' > "$W/c.sea"
    drive build --emit ast --no-prelude c.sea; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file c.sea\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi

if begin driver/stream-target; then
    drive build --emit ast --no-prelude --target x86_64-linux p.sea; want_status 0
    printf '#sea 1\n#target x86_64-linux\n#file p.sea\n|let x = 1\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/passes-run-in-temp-directory; then
    drive build -S -o "$T/o.s" p.sea; want_status 0
    n=$(sed -n 1p "$T/log.cwd")
    case $n in "$TD"/sea.*) ;; *) bad "pass working directory '$n' is not below the temporary directory" ;; esac
    [ "$(sort -u "$T/log.cwd" | wc -l | tr -d ' ')" = 1 ] || bad "passes ran in different directories"; end; fi

# ---- the input is read once (DESIGN.md 2.2 "Input read once") -------------------------------------
if begin driver/input-name-like-awk-assignment; then
    printf 'let x = 1\n' > "$W/x=1.sea"
    drive build --emit ast --no-prelude "x=1.sea"; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file x=1.sea\n|let x = 1\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; want_tmp_clean; end; fi
if begin driver/input-name-like-awk-assignment-line-check; then
    { bytes 4097; printf '\n'; } > "$W/x=1.sea"
    drive build -S -o "$T/o.s" "x=1.sea"; want_status 1; want_err 'x=1.sea:1:4097: error: line too long'; want_log ""; end; fi
if begin driver/input-from-pipe; then
    : > "$T/log"
    printf 'a\nb' | (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build --emit ast --no-prelude /dev/stdin) >"$T/o" 2>"$T/e"; st=$?
    want_status 0
    printf '#sea 1\n#target arm64-macos\n#file /dev/stdin\n|a\n|b\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; want_tmp_clean; end; fi
if begin driver/input-from-pipe-line-check; then
    : > "$T/log"
    { printf 'let a = 1\n'; bytes 4097; printf '\n'; } | (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build -S -o "$T/o.s" /dev/stdin) >"$T/o" 2>"$T/e"; st=$?
    want_status 1; want_err '/dev/stdin:2:4097: error: line too long'; want_log ""; want_tmp_clean; end; fi
if begin driver/input-from-pipe-cr-and-nul; then
    : > "$T/log"
    printf 'a\000b\r\n\r' | (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build --emit ast --no-prelude /dev/stdin) >"$T/o" 2>"$T/e"; st=$?
    want_status 0
    printf '#sea 1\n#target arm64-macos\n#file /dev/stdin\n|a\000b\r\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; end; fi
if begin driver/input-from-named-pipe; then
    rm -f "$W/fifo"; mkfifo "$W/fifo" && { printf 'let x = 1\n' > "$W/fifo" & }
    drive build --emit ast --no-prelude fifo; want_status 0
    printf '#sea 1\n#target arm64-macos\n#file fifo\n|let x = 1\n#end\n' > "$T/want"
    want_file "$T/o" "$T/want" "pass-1 input stream"; wait; rm -f "$W/fifo"; end; fi
if begin driver/output-is-input-build; then
    cp "$W/p.sea" "$W/same.sea"
    drive build same.sea -o same.sea; want_status 2; want_out_empty; want_err "sea: output file '$W/same.sea' is the input file"; want_log ""; want_tmp_clean
    cmp -s "$W/p.sea" "$W/same.sea" || bad "the input file was changed"; end; fi
if begin driver/output-is-input-S; then
    cp "$W/p.sea" "$W/same.sea"
    drive build -S same.sea -o ./same.sea; want_status 2; want_out_empty; want_err "sea: output file '$W/./same.sea' is the input file"; want_log ""; want_tmp_clean
    cmp -s "$W/p.sea" "$W/same.sea" || bad "the input file was changed"; end; fi
if begin driver/output-is-input-emit; then
    cp "$W/p.sea" "$W/same.sea"
    drive build --emit ast same.sea -o "$W/same.sea"; want_status 2; want_err "sea: output file '$W/same.sea' is the input file"; want_log ""
    cmp -s "$W/p.sea" "$W/same.sea" || bad "the input file was changed"; end; fi
if begin driver/output-is-input-hard-link; then
    cp "$W/p.sea" "$W/orig.sea"; rm -f "$W/link.sea"; ln "$W/orig.sea" "$W/link.sea"
    drive build -S orig.sea -o link.sea; want_status 2; want_err "sea: output file '$W/link.sea' is the input file"; want_log ""; end; fi

if begin driver/S-default-output-is-input-symlink; then
    rm -f "$W/a.s" "$W/a.sea"; cp "$W/p.sea" "$W/a.sea"; ln -s a.sea "$W/a.s"
    drive build -S a.sea; want_status 2; want_out_empty; want_err "sea: output file '$W/a.s' is the input file"; want_log ""; want_tmp_clean
    cmp -s "$W/p.sea" "$W/a.sea" || bad "the input file was changed"; rm -f "$W/a.s" "$W/a.sea"; end; fi
if begin driver/S-default-output-is-input-hard-link; then
    rm -f "$W/a.s" "$W/a.sea"; cp "$W/p.sea" "$W/a.sea"; ln "$W/a.sea" "$W/a.s"
    drive build -S a.sea; want_status 2; want_err "sea: output file '$W/a.s' is the input file"; want_log ""
    cmp -s "$W/p.sea" "$W/a.sea" || bad "the input file was changed"; rm -f "$W/a.s" "$W/a.sea"; end; fi
if begin driver/x86-64-default-output-is-input-symlink; then
    rm -f "$W/a.s" "$W/a.sea"; cp "$W/p.sea" "$W/a.sea"; ln -s a.sea "$W/a.s"
    drive build --target x86_64-linux a.sea; want_status 2; want_err "sea: output file '$W/a.s' is the input file"; want_log ""
    cmp -s "$W/p.sea" "$W/a.sea" || bad "the input file was changed"; rm -f "$W/a.s" "$W/a.sea"; end; fi

# ---- outputs ------------------------------------------------------------------------------------------
if begin driver/emit-to-file; then
    rm -f "$W/d.txt"; drive build --emit hir1 --no-prelude -o d.txt p.sea; want_status 0; want_out_empty
    printf '#sea 1\n#target arm64-macos\n#file p.sea\n|let x = 1\n#end\n' > "$T/want"; want_file "$W/d.txt" "$T/want" "dump file"; end; fi
if begin driver/S-default-name; then
    rm -f "$W/p.s"; drive build -S p.sea; want_status 0; want_out_empty; [ -s "$W/p.s" ] || bad "p.s not written"; end; fi
if begin driver/S-name-without-extension; then
    cp "$W/p.sea" "$W/noext"; rm -f "$W/noext.out.s"; drive build -S noext; want_status 0; [ -s "$W/noext.out.s" ] || bad "noext.out.s not written"; end; fi
if begin driver/x86-64-target-writes-asm; then
    rm -f "$W/p.s"; drive build --target x86_64-linux p.sea; want_status 0
    want_log "seaparse seaname seacheck seaexpand sealower seaopt seagen_x64"; [ -s "$W/p.s" ] || bad "p.s not written"; end; fi
if begin driver/x86-64-target-o; then
    rm -f "$W/x.s"; drive build --target x86_64-linux p.sea -o x.s; want_status 0; [ -s "$W/x.s" ] || bad "x.s not written"; end; fi
if begin driver/keep-temps; then
    drive build -S -o "$T/o.s" --keep-temps p.sea; want_status 0
    d=$(sed -n 's/^sea: temporary files kept in //p' "$T/e")
    [ -n "$d" ] || bad "no 'temporary files kept' message"
    [ -d "$d" ] && [ -f "$d/sea.in" ] && [ -f "$d/sea.ast" ] || bad "kept directory '$d' lacks sea.in / sea.ast"
    rm -rf "$d"; end; fi

# ---- pass statuses ---------------------------------------------------------------------------------
fail_case() { # fail_case NAME PASS STATUS DRIVER-STATUS EXTRA-STDERR-LINE
    if begin "$1"; then
        : > "$T/log"
        (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_FAIL_PASS=$2 SEA_FAIL_STATUS=$3 SEA_FAIL_MSG='p.sea:1:5: error: MSG' "$DRIVER" build -S -o "$T/o.s" p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
        want_status "$4"; want_out_empty
        printf 'p.sea:1:5: error: MSG\n' > "$T/want"
        [ -n "$5" ] && printf '%s\n' "$5" >> "$T/want"
        want_file "$T/e" "$T/want" "standard error"
        want_tmp_clean
        end
    fi
}
fail_case driver/pass-compile-error-1 seaparse 10 1 ""
fail_case driver/pass-compile-error-seaname seaname 10 1 ""
fail_case driver/pass-compile-error-2 seacheck 10 1 ""
fail_case driver/pass-compile-error-last seagen_a64 10 1 ""
fail_case driver/pass-internal-11 seaexpand 11 4 "sea: internal error: seaexpand failed with exit status 11"
fail_case driver/pass-internal-11-seaname seaname 11 4 "sea: internal error: seaname failed with exit status 11"
fail_case driver/pass-baysick-error-1 sealower 1 4 "sea: internal error: sealower failed with exit status 1"
fail_case driver/pass-killed-137 seaopt 137 4 "sea: internal error: seaopt failed with exit status 137"
if begin driver/pass-error-stops-the-chain; then
    rm -f "$T/o.s"
    : > "$T/log"
    (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_FAIL_PASS=seacheck SEA_FAIL_STATUS=10 SEA_FAIL_MSG=m "$DRIVER" build -S -o "$T/o.s" p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_log "seaparse seaname seacheck"; [ -e "$T/o.s" ] && bad "an output was written"; rm -f "$T/o.s"; end; fi
if begin driver/pass-stdout-goes-to-stderr; then
    mkdir -p "$T/home7"; install_fakes "$T/home7"
    sed 's/^exit 0$/echo noise; exit 0/' "$T/home7/seacheck" > "$T/home7/seacheck.new" && mv "$T/home7/seacheck.new" "$T/home7/seacheck" && chmod +x "$T/home7/seacheck"
    (cd "$W" && SEA_HOME=$T/home7 TMPDIR=$TD SEA_LOG=$T/log "$DRIVER" build --emit hir1 p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
    want_status 0; printf 'noise\n' > "$T/want"; want_file "$T/e" "$T/want" "standard error"
    grep -q '^noise$' "$T/o" && bad "pass output reached the driver's standard output"; end; fi

# ---- assemble, link, run (macOS) ---------------------------------------------------------------------
if [ $DARWIN = 1 ]; then
    drive_asm() { # drive_asm ARGS... : like drive, with the fake generator emitting $T/main.s
        : > "$T/log"
        (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/main.s "$@") >"$T/o" 2>"$T/e" </dev/null
        st=$?
    }
    if begin driver/link-and-run; then
        rm -f "$W/p"; drive_asm "$DRIVER" build p.sea; want_status 0; want_out_empty; want_file "$T/e" "$T/empty" "standard error"
        want_tmp_clean
        if [ -x "$W/p" ]; then "$W/p" a b c; [ $? = 4 ] || bad "linked program returned $?, expected 4 (argc)"; else bad "executable p not written"; fi; end; fi
    if begin driver/link-o; then
        rm -f "$T/prog"; drive_asm "$DRIVER" build p.sea -o "$T/prog"; want_status 0
        [ -x "$T/prog" ] || bad "executable not written at -o"; end; fi
    if begin driver/link-ignores-bad-SDKROOT; then
        rm -f "$W/p"; : > "$T/log"
        (cd "$W" && SDKROOT=/nonexistent/sdk SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/main.s "$DRIVER" build p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
        want_status 0; [ -x "$W/p" ] || bad "executable not written"; end; fi
    if begin driver/run-status-and-arguments; then
        drive_asm "$DRIVER" run p.sea -- one two; want_status 3; want_out_empty; want_tmp_clean; end; fi
    if begin driver/run-from-pipe; then
        : > "$T/log"
        printf 'let x = 1\n' | (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/main.s "$DRIVER" run /dev/stdin -- one two) >"$T/o" 2>"$T/e"; st=$?
        want_status 3; want_out_empty; want_tmp_clean; end; fi
    if begin driver/run-symlink-named-like-default-output; then
        rm -f "$W/a" "$W/a.sea"; cp "$W/p.sea" "$W/a.sea"; ln -s a.sea "$W/a"
        drive_asm "$DRIVER" run a.sea -- one; want_status 2; want_out_empty; want_tmp_clean
        [ -h "$W/a" ] || bad "the symlink was removed"; rm -f "$W/a" "$W/a.sea"; end; fi
    if begin driver/build-default-output-is-input-symlink-refused; then
        rm -f "$W/a" "$W/a.sea"; cp "$W/p.sea" "$W/a.sea"; ln -s a.sea "$W/a"
        drive_asm "$DRIVER" build a.sea; want_status 2; want_out_empty; want_err "sea: output file '$W/a' is the input file"; want_log ""; want_tmp_clean
        [ -h "$W/a" ] || bad "the symlink was replaced"
        cmp -s "$W/p.sea" "$W/a.sea" || bad "the input file was changed"; rm -f "$W/a" "$W/a.sea"; end; fi
    if begin driver/build-o-from-pipe; then
        rm -f "$T/prog"; : > "$T/log"
        printf 'let x = 1\n' | (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/main.s "$DRIVER" build -o "$T/prog" /dev/stdin) >"$T/o" 2>"$T/e"; st=$?
        want_status 0; [ -x "$T/prog" ] || bad "executable not written"; end; fi
    if begin driver/run-no-arguments; then
        rm -f "$W/p"
        drive_asm "$DRIVER" run p.sea; want_status 1; [ -e "$W/p" ] && bad "sea run left an executable"; end; fi
    if begin driver/run-keeps-caller-directory; then
        # the program's exit status is access("cwd-marker", F_OK): 0 if the file is in its
        # working directory, 255 (-1) if not
        cat > "$T/cwd.s" <<'ASMEOF'
    .globl _main
    .p2align 2
_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, Lmarker@PAGE
    add x0, x0, Lmarker@PAGEOFF
    mov w1, #0
    bl _access
    ldp x29, x30, [sp], #16
    ret
    .section __TEXT,__cstring
Lmarker:
    .asciz "cwd-marker"
ASMEOF
        : > "$W/cwd-marker"
        : > "$T/log"
        (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/cwd.s "$DRIVER" run p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
        want_status 0
        rm -f "$W/cwd-marker"
        (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/cwd.s "$DRIVER" run p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
        want_status 255; end; fi
    if begin driver/link-unwritable-output; then
        drive_asm "$DRIVER" build p.sea -o nodir/prog; want_status 2; want_err "sea: cannot write '$W/nodir/prog'"; want_tmp_clean; end; fi
    if begin driver/missing-libsea; then
        mv "$HOME_/libsea.a" "$T/libsea.a.moved"
        drive_asm "$DRIVER" build p.sea; want_status 4; want_err "sea: cannot find runtime library '$HOME_/libsea.a'"; want_tmp_clean
        mv "$T/libsea.a.moved" "$HOME_/libsea.a"; end; fi
    if begin driver/missing-libbaysickrt; then
        mv "$HOME_/libbaysickrt.a" "$T/rt.moved"
        drive_asm "$DRIVER" build p.sea; want_status 4; want_err "sea: cannot find runtime library '$HOME_/libbaysickrt.a'"
        mv "$T/rt.moved" "$HOME_/libbaysickrt.a"; end; fi
    if begin driver/assembler-error; then
        printf 'this is not assembly\n' > "$T/bad.s"
        : > "$T/log"
        (cd "$W" && SEA_HOME=$HOME_ TMPDIR=$TD SEA_LOG=$T/log SEA_ASM=$T/bad.s "$DRIVER" build p.sea) >"$T/o" 2>"$T/e" </dev/null; st=$?
        want_status 3; tail -n 1 "$T/e" | grep -q "^sea: 'as' failed with exit status " || bad "last stderr line '$(tail -n 1 "$T/e")'"
        want_tmp_clean; end; fi
fi

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
