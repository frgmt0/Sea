#!/bin/sh
# tests/cross_accept.sh -- judge the deferred port runs of a cross run on the Mac (POSIX sh;
# docs/DESIGN.md 2.13.9 item 4, Decision 127). Called by tests/cross.sh; needs uv as tests/accept.sh.
#
# usage: sh tests/cross_accept.sh [-v] BUNDLE_DIR KEPT_B64 REPORT
#   -v          show the comparers' reports for failures
#   BUNDLE_DIR  the bundle tests/cross_pack.sh made for the run (its cases/ports/NAME.meta, NAME.out
#               and NAME.expect/NAME.json are the Mac's packed results)
#   KEPT_B64    the base64 text of the tar of the host's kept runs (ports/NAME.VARIANT.out and
#               .json); an empty file when the host kept nothing
#   REPORT      the host's text report: each line `DEFER ports/NAME (VARIANT)` is one deferred run
#
# Environment: WORKLOADS (default sea/workloads), SEA_ACCEPT_TIMEOUT (seconds per comparison,
# default 120).
#
# The kept files are unpacked (base64 -D, tar) into a private temporary directory. For each
# deferred run, in a fresh directory T with T/run/NAME.json the kept JSON and T/report.txt the kept
# standard output:
#     uv run --no-project --with numpy python <workloads>/reference_py/compare.py --candidate T/run NAME
#     uv run --no-project --with numpy python <workloads>/reference_py/compare_report.py \
#         NAME T/report.txt ports/NAME.tokens --candidate-json T/run/NAME.json
# exactly as tests/accept.sh calls them, must both exit 0. When the bundle's NAME.meta line is
# `compare=accept except=K1,K2,...`, also: every JSON key but K1, K2, ... is byte-identical to the
# packed NAME.expect/NAME.json (same keys in the same order; numbers compared as their printed
# text), and every line of the kept output without its `Compute time` line (the host's
# filter=compute-time) is byte-identical to the same line of the packed NAME.out, except the lines
# of NAME.out that the regex of a token-map entry naming K1, K2, ... (rule `json K`) matches. A
# deferred run whose kept files are missing fails.
#
# Output: `PASS ports/NAME (VARIANT)` or `FAIL ports/NAME (VARIANT): <first difference>` per run,
# then `----` and `passed: P  failed: F`.
# Exit status: 0 every run passed, 1 a failure, 2 setup error (no uv, no workloads, unreadable
# arguments, a base64 or tar failure, a DEFER line for a port the bundle does not mark, a kept file
# no DEFER line names, a bad token map).

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORKLOADS=${WORKLOADS:-$ROOT/workloads}
TIMEOUT=${SEA_ACCEPT_TIMEOUT:-120}
VERBOSE=0
while [ $# -gt 0 ]; do
    case $1 in
    -v) VERBOSE=1; shift ;;
    --) shift; break ;;
    -*) echo "cross_accept.sh: unknown option '$1'" >&2; exit 2 ;;
    *) break ;;
    esac
done
setup_fail() { echo "cross_accept.sh: $1" >&2; exit 2; }
[ $# -eq 3 ] || setup_fail "usage: sh tests/cross_accept.sh [-v] BUNDLE_DIR KEPT_B64 REPORT"
BUNDLE=$1; KEPTB64=$2; REPORT=$3
[ -d "$BUNDLE/cases/ports" ] || setup_fail "'$BUNDLE' holds no cases/ports directory"
[ -f "$KEPTB64" ] || setup_fail "'$KEPTB64' not found"
[ -f "$REPORT" ] || setup_fail "'$REPORT' not found"
COMPARE=$WORKLOADS/reference_py/compare.py
COMPARE_REPORT=$WORKLOADS/reference_py/compare_report.py
command -v uv >/dev/null 2>&1 || setup_fail "uv not found (it runs compare.py)"
[ -f "$COMPARE" ] || setup_fail "'$COMPARE' not found (is the sea/workloads directory there?)"
[ -f "$COMPARE_REPORT" ] || setup_fail "'$COMPARE_REPORT' not found"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/sea-crossacc.XXXXXX") || setup_fail "cannot create temporary directory"
trap 'rm -rf "$TMP"' EXIT
# dash/busybox sh skip the EXIT trap on fatal signals: clean up explicitly there.
trap 'rm -rf "$TMP"; exit 2' HUP INT TERM PIPE

# unpack the kept runs
mkdir "$TMP/kept" || setup_fail "cannot create $TMP/kept"
if [ -s "$KEPTB64" ]; then
    base64 -D < "$KEPTB64" > "$TMP/kept.tar" 2>"$TMP/b64.err" || setup_fail "base64 -D failed: $(head -2 "$TMP/b64.err" | tr '\n' ' ')"
    tar -C "$TMP/kept" -xf "$TMP/kept.tar" 2>"$TMP/tar.err" || setup_fail "cannot unpack the kept files: $(head -2 "$TMP/tar.err" | tr '\n' ' ')"
fi

# the deferred runs, one `NAME VARIANT` per line
sed -n 's/^DEFER ports\/\([A-Za-z0-9_]*\) (\([A-Za-z0-9_]*\))$/\1 \2/p' "$REPORT" > "$TMP/runs"

# every kept file must belong to a deferred run
(cd "$TMP/kept" && find . -type f | sed 's|^\./||' | sort) > "$TMP/files"
while IFS= read -r f; do
    case $f in
    ports/*.out) r=${f#ports/}; r=${r%.out} ;;
    ports/*.json) r=${f#ports/}; r=${r%.json} ;;
    *) setup_fail "unexpected kept file '$f'" ;;
    esac
    grep -q -x -F "${r%.*} ${r##*.}" "$TMP/runs" || setup_fail "kept file '$f' belongs to no DEFER line of the host"
done < "$TMP/files"

# the identity check of an `except=` run (Python; the token map is read by compare_report.py's own
# parser and its regex dialect). argv: reference_py NAME TOKENS KEPT_OUT KEPT_JSON PACKED_OUT
# PACKED_JSON KEYS. Exit 0 identical, 1 different (the first difference on stdout), 2 error.
cat > "$TMP/ident.py" <<'PYEOF'
import json, re, sys
sys.path.insert(0, sys.argv[1])
import compare, compare_report
name, tokens, kout, kjson, pout, pjson, keys = sys.argv[2:9]
excl = set(keys.split(","))
try:
    with open(tokens) as fh:
        entries = compare_report.parse_map(fh.read(), compare.RULES[name])
except (compare_report.MapError, KeyError) as exc:
    print("token map: %s" % exc)
    sys.exit(2)
named = [e[1] for e in entries if e[3][0] == "json" and e[3][1] in excl]

def load(path):
    with open(path) as fh:
        return json.load(fh, object_pairs_hook=list, parse_float=str, parse_int=str,
                         parse_constant=str)

def first_diff(a, b, path):
    if isinstance(a, list) and isinstance(b, list):
        for i, (x, y) in enumerate(zip(a, b)):
            d = first_diff(x, y, "%s[%d]" % (path, i))
            if d:
                return d
        if len(a) != len(b):
            return "%s: length %d vs %d" % (path, len(a), len(b))
        return None
    if a != b:
        return "%s: %s vs %s" % (path, json.dumps(a)[:60], json.dumps(b)[:60])
    return None

kj, pj = load(kjson), load(pjson)
kk = [p for p in kj if p[0] not in excl]
pk = [p for p in pj if p[0] not in excl]
if [p[0] for p in kk] != [p[0] for p in pk]:
    print("JSON keys differ from the Mac's: %s vs %s" % ([p[0] for p in kk], [p[0] for p in pk]))
    sys.exit(1)
for (k, a), (_, b) in zip(kk, pk):
    d = first_diff(a, b, k)
    if d:
        print("JSON key %s (host vs Mac)" % d)
        sys.exit(1)
ct = re.compile(r"^Compute time: .* s$")
with open(kout, "rb") as fh:
    kl = [l for l in fh.read().split(b"\n") if not ct.match(l.decode("utf-8", "replace"))]
with open(pout, "rb") as fh:
    pl = fh.read().split(b"\n")
if len(kl) != len(pl):
    print("output: %d lines vs %d in the Mac's NAME.out" % (len(kl) - 1, len(pl) - 1))
    sys.exit(1)
for i, (a, b) in enumerate(zip(kl, pl), 1):
    if a == b:
        continue
    if any(r.match(b.decode("utf-8", "replace")) for r in named):
        continue
    print("output line %d: %r vs %r (host vs Mac)" % (i, a.decode("utf-8", "replace")[:80],
                                                    b.decode("utf-8", "replace")[:80]))
    sys.exit(1)
sys.exit(0)
PYEOF

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

PASS=0
FAIL=0
FAILED=""
fail() { FAIL=$((FAIL + 1)); FAILED="$FAILED $1"; echo "FAIL $1: $2"; }

while read -r nm var; do
    label="ports/$nm ($var)"
    pb=$BUNDLE/cases/ports/$nm
    mode=$(sed -n 's/^compare=//p' "$pb.meta" 2>/dev/null | head -1)
    case $mode in
    accept) keys= ;;
    "accept except="*) keys=${mode#accept except=} ;;
    *) setup_fail "the host deferred ports/$nm, which the bundle's $nm.meta does not mark compare=accept" ;;
    esac
    tokens=$ROOT/ports/$nm.tokens
    [ -f "$tokens" ] || setup_fail "missing ports/$nm.tokens"
    ko=$TMP/kept/ports/$nm.$var.out
    kj=$TMP/kept/ports/$nm.$var.json
    if [ ! -f "$ko" ] || [ ! -f "$kj" ]; then fail "$label" "no kept files (ports/$nm.$var.out and .json)"; continue; fi
    d=$(mktemp -d "$TMP/case.XXXXXX") || setup_fail "cannot create a case directory"
    mkdir "$d/run" && /bin/cp -f "$kj" "$d/run/$nm.json" && /bin/cp -f "$ko" "$d/report.txt" \
        || setup_fail "cannot prepare $d"
    ok=1
    run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE" --candidate "$d/run" "$nm" >"$d/cmp.out" 2>&1
    st=$?
    if [ $st -ne 0 ]; then
        fail "$label" "compare.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/cmp.out" | tr '\n' ' ')"
        if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/cmp.out" | head -60; fi
        ok=0
    fi
    if [ $ok = 1 ]; then
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$COMPARE_REPORT" "$nm" "$d/report.txt" "$tokens" \
            --candidate-json "$d/run/$nm.json" >"$d/rep.out" 2>&1
        st=$?
        if [ $st -ne 0 ]; then
            fail "$label" "compare_report.py exit status $st: $(grep -m3 -i 'fail\|error' "$d/rep.out" | tr '\n' ' ')"
            if [ "$VERBOSE" = 1 ]; then sed 's/^/    /' "$d/rep.out" | head -60; fi
            ok=0
        fi
    fi
    if [ $ok = 1 ] && [ -n "$keys" ]; then
        [ -f "$pb.out" ] && [ -f "$pb.expect/$nm.json" ] || setup_fail "the bundle lacks $nm.out or $nm.expect/$nm.json"
        run_limited "$TIMEOUT" "$d" uv run --no-project --with numpy python "$TMP/ident.py" "$WORKLOADS/reference_py" "$nm" \
            "$tokens" "$ko" "$kj" "$pb.out" "$pb.expect/$nm.json" "$keys" >"$d/id.out" 2>&1
        st=$?
        case $st in
        0) ;;
        1) fail "$label" "not identical outside $keys: $(head -1 "$d/id.out")"; ok=0 ;;
        *) setup_fail "the identity check of $label failed (status $st): $(head -3 "$d/id.out" | tr '\n' ' ')" ;;
        esac
    fi
    rm -rf "$d"
    if [ $ok = 1 ]; then PASS=$((PASS + 1)); echo "PASS $label"; fi
done < "$TMP/runs"

echo "----"
echo "passed: $PASS  failed: $FAIL"
if [ $FAIL -ne 0 ]; then
    echo "failed runs:$FAILED"
    exit 1
fi
exit 0
