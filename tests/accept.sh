#!/bin/sh
# tests/accept.sh -- the phase-6 acceptance programs: the ports (docs/DESIGN.md 6.3). POSIX sh, Mac.
#
# For each ports/NAME.sea (NAME a workload name, with NAME.tokens and NAME.struct): in a fresh
# temporary directory T, `sea build -o T/run/NAME` (in ports/, with the prelude) under the compile
# timeout, then run T/run/NAME once in the working directory T/run with --export-reference
# --figures (phase 9, DESIGN.md 2.14.9 "Acceptance", L-kz: the report and JSON checks are those of
# a run without --figures, and the figure is built from the same values), SEA_HEAP_CHECK=1 and
# standard input /dev/null under a 120-second timeout; standard output goes to T/report.txt and
# standard error to T/stderr.txt. The status must be 0, standard error exactly
# `heap: 0 live objects` and LF, and T/run must hold exactly the executable, NAME.json, output/,
# output/NAME.svg and the port's fixtures, each fixture byte-identical to its source after the run.
#
# Fixtures (Decision 158 (a), DESIGN.md 2.16.9 "Where the log comes from", 6.3 "W8 acceptance"): the
# port's leading comment block (its first lines that start with `//`) may hold any number of lines
#     // fixture: PATH
# each naming one file by a PATH relative to the sea directory (components of letters, digits and
# `._+-`, separated by single `/`; no `.` or `..` component, not absolute). Before the run each
# fixture is copied into T/run under its base name. A missing fixture source (or one that is not a
# regular file), a malformed `// fixture:` line (any header line `//` [blanks] `fixture` [blanks] `:`
# not of the form above), the same line twice, two fixtures with the same base name, or a fixture
# whose base name is NAME.json, NAME or output is a setup error (exit 2), checked for every selected
# port before any port is built. Then
#     uv run --no-project --with numpy python <workloads>/reference_py/compare.py \
#         --candidate T/run NAME
#     uv run --no-project --with numpy python <workloads>/reference_py/compare_report.py \
#         NAME T/report.txt ports/NAME.tokens --candidate-json T/run/NAME.json
#     uv run --no-project python tests/plot_struct.py ports/NAME.struct T/run
# must all exit 0 (the last is 6.3 step 4: the figure's structure, from the MATLAB script; a
# missing ports/NAME.struct is a failure). <workloads> is sea/workloads (a directory of the sea repo).
#
# usage: sh tests/accept.sh [-v] [--save-out DIR] [PATTERN...]
#   -v              show the comparers' reports for failures
#   --save-out DIR  also copy the standard output of every passing case to DIR/NAME.out, its
#                   NAME.json to DIR/NAME.json and its output/NAME.svg to DIR/output/NAME.svg
#                   (used by tests/cross_pack.sh)
#   PATTERN         a substring of the test name (ports/NAME)
# Environment: BUILD (default build/), SEA (default $BUILD/sea), WORKLOADS (default
# sea/workloads), PORTS (the directory of the ports, default sea/ports; the test name stays
# ports/NAME and fixture paths stay relative to the sea directory), SEA_COMPILE_TIMEOUT (seconds
# per compilation, default 120), SEA_ACCEPT_TIMEOUT (seconds per run and per comparison, default 120).
# Output as tests/run.sh: `FAIL ports/NAME: <reason>`, `----`, `passed: P  failed: F`.
# Exit status: 0 all passed, 1 a failure, 2 setup error (no uv, no workloads directory, a bad
# fixture, ...).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD=${BUILD:-$ROOT/build}
case $BUILD in /*) ;; *) BUILD=$ROOT/$BUILD ;; esac
SEA=${SEA:-$BUILD/sea}
WORKLOADS=${WORKLOADS:-$ROOT/workloads}
PORTS=${PORTS:-$ROOT/ports}
case $PORTS in /*) ;; *) PORTS=$(pwd)/$PORTS ;; esac
TIMEOUT=${SEA_ACCEPT_TIMEOUT:-120}
CTIMEOUT=${SEA_COMPILE_TIMEOUT:-120}
VERBOSE=0
SAVE=
while [ $# -gt 0 ]; do
    case $1 in
    -v) VERBOSE=1; shift ;;
    --save-out)
        [ $# -ge 2 ] || { echo "accept.sh: missing argument for '--save-out'" >&2; exit 2; }
        SAVE=$2; shift 2 ;;
    --) shift; break ;;
    -*) echo "accept.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
PATTERNS="$*"

COMPARE=$WORKLOADS/reference_py/compare.py
COMPARE_REPORT=$WORKLOADS/reference_py/compare_report.py
[ -x "$SEA" ] || { echo "accept.sh: driver '$SEA' not found or not executable; run 'make' first" >&2; exit 2; }
command -v uv >/dev/null 2>&1 || { echo "accept.sh: uv not found (it runs compare.py)" >&2; exit 2; }
PLOT_STRUCT=$ROOT/tests/plot_struct.py
[ -f "$PLOT_STRUCT" ] || { echo "accept.sh: '$PLOT_STRUCT' not found" >&2; exit 2; }
[ -f "$COMPARE" ] || { echo "accept.sh: '$COMPARE' not found (is the sea/workloads directory there?)" >&2; exit 2; }
[ -f "$COMPARE_REPORT" ] || { echo "accept.sh: '$COMPARE_REPORT' not found" >&2; exit 2; }
[ -d "$PORTS" ] || { echo "accept.sh: ports directory '$PORTS' not found" >&2; exit 2; }

# port_fixtures SRC NAME : print the PATH of every `// fixture: PATH` line of SRC's leading comment
# block (its first lines that start with `//`), one per line, in order. A malformed fixture line,
# the same line twice, two fixtures with the same base name or a base name NAME.json, NAME or
# output is a setup error: the message goes to standard error and the status is 2.
port_fixtures() {
    awk -v f="$1" -v nm="$2" '
    function bad(msg) { print "accept.sh: " f ": line " FNR ": " msg > "/dev/stderr"; err = 1; exit }
    !/^\/\// { exit }
    /^\/\/[ \t]*fixture[ \t]*:/ {
        p = $0
        if (sub(/^\/\/ fixture: /, "", p) != 1 || p !~ /^[A-Za-z0-9._+-]+(\/[A-Za-z0-9._+-]+)*$/)
            bad("malformed fixture line '\''" $0 "'\'' (expected '\''// fixture: PATH'\'', PATH relative to the sea directory)")
        nc = split(p, comp, "/")
        for (i = 1; i <= nc; i++)
            if (comp[i] == "." || comp[i] == "..")
                bad("malformed fixture line '\''" $0 "'\'' (a '\''.'\'' or '\''..'\'' component in PATH)")
        if (p in seen) bad("fixture line '\''" $0 "'\'' repeated (first at line " seen[p] ")")
        b = comp[nc]
        if (b in base) bad("fixture '\''" p "'\'' has the same base name as fixture '\''" base[b] "'\''")
        if (b == nm || b == nm ".json" || b == "output")
            bad("fixture '\''" p "'\'' has the reserved base name '\''" b "'\'' (the run directory holds the executable " nm ", " nm ".json and output/)")
        seen[p] = FNR; base[b] = p
        print p
    }
    END { if (err) exit 2 }' "$1"
}

if [ -n "$SAVE" ]; then mkdir -p "$SAVE/output" || { echo "accept.sh: cannot create '$SAVE'" >&2; exit 2; }; fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-accept6.XXXXXX") || exit 2
trap 'rm -rf "$TMP"' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM

PASS=0
FAIL=0
FAILED=""
selected() {
    [ -z "$PATTERNS" ] && return 0
    set -f
    for p in $PATTERNS; do
        case "$1" in *"$p"*) set +f; return 0 ;; esac
    done
    set +f
    return 1
}
pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }

# Fixtures of every selected port, checked before any port is built (a bad fixture is a setup error)
for src in "$PORTS"/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    selected "ports/$nm" || continue
    fx=$(port_fixtures "$src" "$nm") || exit 2
    for p in $fx; do
        if [ ! -e "$ROOT/$p" ]; then
            echo "accept.sh: $src: fixture source '$p' not found (in $ROOT)" >&2; exit 2
        fi
        if [ ! -f "$ROOT/$p" ]; then
            echo "accept.sh: $src: fixture source '$p' is not a regular file" >&2; exit 2
        fi
    done
done

# run_limited SECONDS WORKDIR CMD... : stdin /dev/null; killed after SECONDS (status 137)
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

printf 'heap: 0 live objects\n' > "$TMP/heapline"

for src in "$PORTS"/*.sea; do
    [ -e "$src" ] || continue
    nm=$(basename "$src" .sea)
    name=ports/$nm
    selected "$name" || continue
    base=${src%.sea}
    if [ ! -f "$base.tokens" ]; then fail "$name" "missing $nm.tokens"; continue; fi
    if [ ! -f "$base.struct" ]; then fail "$name" "missing $nm.struct"; continue; fi
    d=$(mktemp -d "$TMP/case.XXXXXX") || exit 2
    mkdir "$d/run"
    # the port's fixtures (Decision 158 (a)), copied into T/run under their base names; the list is
    # the one the setup check above accepted
    fx=$(port_fixtures "$src" "$nm") || exit 2
    printf '%s\n' "$nm" "$nm.json" output "output/$nm.svg" > "$d/allowed"
    for p in $fx; do
        /bin/cp -f "$ROOT/$p" "$d/run/${p##*/}" || { echo "accept.sh: cannot copy fixture '$p' into the run directory" >&2; exit 2; }
        printf '%s\n' "${p##*/}" >> "$d/allowed"
    done
    run_limited "$CTIMEOUT" "$PORTS" "$SEA" build "$nm.sea" -o "$d/run/$nm" >"$d/c.out" 2>"$d/c.err"
    st=$?
    if [ $st -ne 0 ]; then
        fail "$name" "compile failed (status $st): $(head -3 "$d/c.err" | tr '\n' ' ')"; rm -rf "$d"; continue
    fi
    SEA_HEAP_CHECK=1; export SEA_HEAP_CHECK
    run_limited "$TIMEOUT" "$d/run" "$d/run/$nm" --export-reference --figures >"$d/report.txt" 2>"$d/stderr.txt"
    st=$?
    unset SEA_HEAP_CHECK
    ok=1
    [ $st -eq 0 ] || { fail "$name" "exit status $st, expected 0"; ok=0; }
    if [ $ok = 1 ] && ! cmp -s "$d/stderr.txt" "$TMP/heapline"; then
        fail "$name" "standard error is not exactly 'heap: 0 live objects': $(head -3 "$d/stderr.txt" | tr '\n' ' ')"; ok=0
    fi
    if [ $ok = 1 ]; then
        # every file and directory below T/run, by relative path: exactly the executable, NAME.json,
        # the directory output, output/NAME.svg and the base name of each fixture
        extra=$(cd "$d/run" && find . -mindepth 1 | sed 's|^\./||' \
            | grep -v -x -F -f "$d/allowed")
        if [ -n "$extra" ]; then fail "$name" "the program wrote unexpected files: $(echo "$extra" | tr '\n' ' ')"; ok=0; fi
    fi
    if [ $ok = 1 ]; then
        # each fixture byte-identical to its source after the run
        for p in $fx; do
            b=${p##*/}
            if [ ! -f "$d/run/$b" ]; then fail "$name" "fixture $b is missing or no longer a regular file after the run"; ok=0; break; fi
            if ! cmp -s "$ROOT/$p" "$d/run/$b"; then fail "$name" "the program changed fixture $b"; ok=0; break; fi
        done
    fi
    if [ $ok = 1 ] && [ ! -f "$d/run/$nm.json" ]; then fail "$name" "the program did not write $nm.json"; ok=0; fi
    if [ $ok = 1 ] && [ ! -f "$d/run/output/$nm.svg" ]; then fail "$name" "the program did not write output/$nm.svg"; ok=0; fi
    if [ $ok = 1 ]; then
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE" --candidate "$d/run" "$nm" >"$d/cmp.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "compare.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/cmp.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/cmp.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ]; then
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE_REPORT" "$nm" "$d/report.txt" "$base.tokens" \
            --candidate-json "$d/run/$nm.json" >"$d/rep.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "compare_report.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/rep.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/rep.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ]; then
        # 6.3 step 4 (2.14.9, L-kz): the figure's structure against ports/NAME.struct
        run_limited "$TIMEOUT" "$d" uv run --no-project python "$PLOT_STRUCT" "$base.struct" "$d/run" >"$d/st.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$name" "plot_struct.py exit status $st: $(head -3 "$d/st.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/st.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ] && [ -n "$SAVE" ]; then
        /bin/cp -f "$d/report.txt" "$SAVE/$nm.out" && /bin/cp -f "$d/run/$nm.json" "$SAVE/$nm.json" \
            && /bin/cp -f "$d/run/output/$nm.svg" "$SAVE/output/$nm.svg" \
            || { echo "accept.sh: cannot write to '$SAVE'" >&2; exit 2; }
    fi
    rm -rf "$d"
    [ $ok = 1 ] && pass
done

if [ -z "$PATTERNS" ] && [ $((PASS + FAIL)) -eq 0 ]; then
    echo "accept.sh: no port selected (no $PORTS/*.sea)" >&2
    exit 2
fi

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed tests:$FAILED"
    exit 1
fi
exit 0
