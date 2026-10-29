"""Judge a candidate text report against the MATLAB report reference/<name>.txt, with a token map.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/compare_report.py \\
        <name> <candidate.txt> <tokens-file> [--candidate-json <path>]
    uv run --no-project --with numpy python reference_py/compare_report.py --self-test

The reference report is reference/<name>.txt (written by run_all.m with diary) and the reference
JSON is reference/<name>.json; the rule tables are compare.RULES (not duplicated here).

Token map: one entry per line, fields separated by runs of blanks:

    <line regex>  <token number>  <rule>

* The regex is POSIX extended, matched at the START of the report line (so `^Rejects:` and
  `Rejects:` are the same). It may not contain blanks (fields are split on blanks): write
  `[[:space:]]` for a blank. POSIX bracket classes ([:digit:], [:alpha:], ...) are accepted.
* The token number counts blank-separated tokens of the line from 1. It must name a numeric
  token of the reference line.
* Blank lines and lines starting with `#` are comments.
* Rules: `exact` (identical numbers), `int n` (|a-b| <= n), `num atol rtol`
  (|a-b| <= atol + rtol*|a|, a = reference), `json <key>` (the rule of that key in
  compare.RULES[name]: for `num` the rtol scale is the largest magnitude of that key in the
  reference JSON; `int`, `exact`, `small` apply directly to the two token values;
  `argmax_tol`/`argmin_tol` pass when the reference token equals the MATLAB JSON value of the
  key, the candidate token equals the candidate JSON value of the key (--candidate-json is
  required) and the candidate JSON passes compare.py's own-extremum candidate rule).

Equivalence: same number of lines; the line matching `^Compute time: .* s$` is skipped on both
sides (it must be at the same line position on both sides); per line the same number of
blank-separated tokens; non-numeric tokens identical; numeric tokens pass their rule.

Token layers. Before a token is parsed as a number, one trailing `,` `;` or `:` is stripped,
then one trailing `)`, then one leading `(`. Each stripped character (or none) must be the same
on both sides, else the token fails. A core containing `..` is split there into two parts
(`0.30..12.00`); each part is judged as a numeric token of its own (a token-map entry naming the
token applies its rule to both parts). A token is numeric if every part parses as a number
(Python float syntax incl. inf/nan, and forms like `+3`). A `%` suffix is not stripped, so
`12.50%` and `P2.500` are non-numeric tokens and must be identical.

Default rule (numeric token or part with no map entry): equal as text, or |a - b| <= u, where u
is one unit in the last printed digit of the coarser of the two tokens: the unit of a token is
10^(e - d), e its printed exponent (0 if none), d its number of fractional mantissa digits. The
arithmetic is exact (decimal). 9.99e-05 vs 1.00e-04, 9.9999 vs 10 and 0.999 vs 1.000 pass;
1.5 vs 1.7 and 10 vs 12 fail. inf/nan pass only if equal as text.

Exit status: 0 equivalent, 1 not equivalent, 2 usage or token-map error.
"""

import json
import math
from decimal import Decimal
import os
import re
import sys

import compare

HERE = os.path.dirname(os.path.abspath(__file__))
REF_DIR = os.path.join(os.path.dirname(HERE), "reference")

COMPUTE_RE = re.compile(r"^Compute time: .* s$")
NUM_SYNTAX = re.compile(r"^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$")
SPECIAL_RE = re.compile(r"^[+-]?(inf|infinity|nan)$", re.IGNORECASE)
DEC_RE = re.compile(r"^([+-]?)(\d*)(?:\.(\d*))?([eE][+-]?\d+)?$")

POSIX_CLASSES = {
    "alpha": "a-zA-Z", "digit": "0-9", "alnum": "a-zA-Z0-9", "upper": "A-Z", "lower": "a-z",
    "space": r"\s", "blank": r" \t", "xdigit": "0-9a-fA-F", "word": r"\w",
    "punct": r"!-/:-@\[-`{-~", "print": r" -~", "graph": r"!-~", "cntrl": r"\x00-\x1f\x7f",
}


class MapError(Exception):
    """A token-map or usage problem that makes the judgement meaningless (exit status 2)."""


def posix_to_python(src):
    """Translate POSIX classes [:name:] into Python regex text, ONLY inside bracket
    expressions ([[:digit:]x] -> [0-9x]); [:digit:] alone is an ordinary bracket expression."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "\\" and i + 1 < n:           # escaped character outside brackets
            out.append(src[i:i + 2])
            i += 2
            continue
        if c != "[":
            out.append(c)
            i += 1
            continue
        out.append("[")                        # start of a bracket expression
        i += 1
        if i < n and src[i] == "^":
            out.append("^")
            i += 1
        if i < n and src[i] == "]":            # a leading ] is a literal member
            out.append("\\]")
            i += 1
        while i < n and src[i] != "]":
            m = re.match(r"\[:([a-z]+):\]", src[i:])
            if m:
                name = m.group(1)
                if name not in POSIX_CLASSES:
                    raise MapError("unknown POSIX class [:%s:] in regex %r" % (name, src))
                out.append(POSIX_CLASSES[name])
                i += m.end()
            else:
                out.append("\\[" if src[i] == "[" else src[i])
                i += 1
        if i < n:
            out.append("]")
            i += 1
    return "".join(out)


def parse_core(text):
    """A bare number text -> (float, text), else None."""
    if not text or "_" in text:
        return None
    if not (NUM_SYNTAX.match(text) or SPECIAL_RE.match(text)):
        return None
    try:
        return float(text), text
    except ValueError:
        return None


def parse_number(tok):
    """Token -> (layers, parts) when numeric, else None.

    layers = (trailing punctuation, closing paren, opening paren), each '' when absent: one
    trailing , ; : is stripped, then one trailing ), then one leading (. The core is split at
    '..' (exactly one) into two parts; parts is a list of (float, text), all must be numeric."""
    body, punct, close, opn = tok, "", "", ""
    if body and body[-1] in ",;:":
        body, punct = body[:-1], body[-1]
    if body and body[-1] == ")":
        body, close = body[:-1], ")"
    if body and body[0] == "(":
        body, opn = body[1:], "("
    texts = body.split("..") if body.count("..") == 1 and "..." not in body else [body]
    parts = [parse_core(t) for t in texts]
    if any(x is None for x in parts):
        return None
    return (punct, close, opn), parts


def parse_rule(fields, lineno, rules):
    """fields = [rule, args...] -> normalised rule tuple. Raises MapError."""
    where = "token map line %d" % lineno
    kind, args = fields[0], fields[1:]
    try:
        if kind == "exact" and not args:
            return ("exact",)
        if kind == "int" and len(args) == 1:
            n = float(args[0])
            if n < 0 or math.isnan(n):
                raise ValueError
            return ("int", n)
        if kind == "num" and len(args) == 2:
            a, r = float(args[0]), float(args[1])
            if a < 0 or r < 0 or math.isnan(a) or math.isnan(r):
                raise ValueError
            return ("num", a, r)
        if kind == "json" and len(args) == 1:
            if args[0] not in rules:
                raise MapError("%s: unknown json key %r" % (where, args[0]))
            return ("json", args[0])
    except ValueError:
        raise MapError("%s: bad argument for rule %s: %s" % (where, kind, " ".join(args)))
    if kind in ("exact", "int", "num", "json"):
        raise MapError("%s: wrong number of arguments for rule %s" % (where, kind))
    raise MapError("%s: unknown rule %r" % (where, kind))


def parse_map(text, rules):
    """Parse a token map. Returns a list of (regex_src, compiled, token_number, rule, lineno)."""
    entries = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.lstrip().startswith("#"):
            continue
        fields = line.split()
        if len(fields) < 3:
            raise MapError("token map line %d: expected <regex> <token number> <rule>: %r" % (
                lineno, raw))
        src = fields[0]
        try:
            tok = int(fields[1])
        except ValueError:
            raise MapError("token map line %d: token number is not an integer: %r" % (
                lineno, fields[1]))
        if tok < 1:
            raise MapError("token map line %d: token numbers start at 1" % lineno)
        rule = parse_rule(fields[2:], lineno, rules)
        try:
            comp = re.compile(posix_to_python(src))
        except re.error as exc:
            raise MapError("token map line %d: bad regex %r: %s" % (lineno, src, exc))
        entries.append((src, comp, tok, rule, lineno))
    return entries


def decimal_unit(text):
    """(exact Decimal value, unit of the last printed digit) of a finite number text."""
    m = DEC_RE.match(text)
    if not m:
        return None
    _sign, _int, frac, exp = m.groups()
    e = int(exp[1:]) if exp else 0
    d = len(frac or "")
    return Decimal(text), Decimal(10) ** (e - d)


def default_rule(ta, tb):
    """Default rule on two numeric token texts: equal as text, or |a-b| <= the unit of the last
    printed digit of the coarser token (exact decimal arithmetic). inf/nan: equal text only."""
    if ta == tb:
        return True
    if SPECIAL_RE.match(ta) or SPECIAL_RE.match(tb):
        return False
    da, db = decimal_unit(ta), decimal_unit(tb)
    if da is None or db is None:
        return False
    return abs(da[0] - db[0]) <= max(da[1], db[1])


def same_number(a, b):
    return a == b or (math.isnan(a) and math.isnan(b))


class Judge:
    """Holds the rule table and JSON of one workload and applies token rules."""

    def __init__(self, rules, ref_json, cand_json):
        self.rules = rules
        self.ref_json = ref_json          # dict or None
        self.cand_json = cand_json        # dict or None
        self._arg_cache = {}

    def _need_ref(self, key):
        if self.ref_json is None:
            raise MapError("rule 'json %s' needs the reference JSON, which is missing" % key)
        if key not in self.ref_json:
            raise MapError("rule 'json %s': key not in the reference JSON" % key)

    def scale(self, key):
        self._need_ref(key)
        vals = [abs(compare.as_float(x)) for x in compare.flatten(self.ref_json[key])]
        vals = [v for v in vals if not math.isnan(v)]
        return max(vals) if vals else 0.0

    def arg_ok(self, key):
        if key not in self._arg_cache:
            self._need_ref(key)
            if self.cand_json is None:
                raise MapError("rule 'json %s' needs --candidate-json" % key)
            self._arg_cache[key] = compare.check_arg_candidate(
                self.rules[key], key, self.ref_json, self.cand_json)
        return self._arg_cache[key]

    def validate_rule(self, rule):
        """Map-level checks of a rule that need the JSON files. Raises MapError."""
        if rule[0] != "json":
            return
        key = rule[1]
        self._need_ref(key)
        if self.rules[key][0] in ("argmax_tol", "argmin_tol") and self.cand_json is None:
            raise MapError("rule 'json %s' needs --candidate-json" % key)

    def judge(self, rule, a, b, ta, tb):
        """Apply a normalised rule to numbers a (reference) and b (candidate).
        Returns (ok, detail)."""
        kind = rule[0]
        if kind == "json":
            key = rule[1]
            r = self.rules[key]
            if r[0] in ("argmax_tol", "argmin_tol"):
                return self.judge_arg(key, a, b)
            if r[0] == "num":
                scale = self.scale(key)
                allowed = r[1] + r[2] * scale
                return abs(a - b) <= allowed or same_number(a, b), \
                    "json %s: |diff| %.3e, allowed %.3e" % (key, abs(a - b), allowed)
            if r[0] == "small":
                ok = (math.isfinite(a) and math.isfinite(b)
                      and abs(a) <= r[1] and abs(b) <= r[1])
                return ok, "json %s: small bound %g" % (key, r[1])
            if r[0] == "int":
                return abs(a - b) <= r[1] or same_number(a, b), "json %s: int %g" % (key, r[1])
            if r[0] == "exact":
                return same_number(a, b), "json %s: exact" % key
            raise MapError("rule json %s: unsupported rule kind %s" % (key, r[0]))
        if kind == "exact":
            return same_number(a, b), "exact"
        if kind == "int":
            return same_number(a, b) or abs(a - b) <= rule[1], "int %g" % rule[1]
        if kind == "num":
            allowed = rule[1] + rule[2] * abs(a)
            return same_number(a, b) or abs(a - b) <= allowed, \
                "|diff| %.3e, allowed %.3e" % (abs(a - b), allowed)
        raise MapError("internal: rule %r" % (rule,))

    def judge_arg(self, key, a, b):
        ok_c, detail = self.arg_ok(key)
        if not ok_c:
            return False, "json %s own-extremum rule: %s" % (key, detail)
        jm = compare.flatten(self.ref_json[key])
        jc = compare.flatten(self.cand_json[key])
        if len(jm) != 1 or len(jc) != 1:
            return False, "json %s is not a scalar" % key
        im, ic = compare.json_index(jm[0]), compare.json_index(jc[0])
        if im is None or ic is None:
            return False, "json %s is not an integer index" % key
        if a != im:
            return False, "reference token %g differs from the MATLAB JSON %s = %d" % (a, key, im)
        if b != ic:
            return False, "candidate token %g differs from the candidate JSON %s = %d" % (b, key, ic)
        return True, "json %s own-extremum rule: %s" % (key, detail)


def validate_map(ref_lines, entries, judge):
    """Check every map entry against every reference line (Compute-time lines included).
    Returns (assigned rules per line index, used flags). Raises MapError."""
    for e in entries:
        judge.validate_rule(e[3])
    used = [False] * len(entries)
    per_line = []
    for i, rl in enumerate(ref_lines):
        lno = i + 1
        rtoks = rl.split()
        assigned = {}
        for k, (src, comp, tok, rule, mline) in enumerate(entries):
            if not comp.match(rl):
                continue
            used[k] = True
            if tok > len(rtoks):
                raise MapError("token map line %d (%s): token %d, but reference line %d has "
                               "%d token(s): %r" % (mline, src, tok, lno, len(rtoks), rl))
            if parse_number(rtoks[tok - 1]) is None:
                raise MapError("token map line %d (%s): token %d of reference line %d is not "
                               "numeric: %r" % (mline, src, tok, lno, rtoks[tok - 1]))
            if tok in assigned and assigned[tok][0] != rule:
                raise MapError("token map lines %d and %d assign different rules to token %d "
                               "of reference line %d" % (assigned[tok][1], mline, tok, lno))
            assigned[tok] = (rule, mline)
        per_line.append(assigned)
    return per_line, used


def judge_reports(ref_text, cand_text, entries, judge):
    """Return the list of failure diagnostics. Raises MapError."""
    ref_lines = ref_text.splitlines()
    cand_lines = cand_text.splitlines()
    # The map is validated against the reference first: a broken map is exit 2 whatever the
    # candidate looks like.
    per_line, used = validate_map(ref_lines, entries, judge)
    for k, u in enumerate(used):
        if not u:
            print("warning: token map line %d (%s) matched no reference line" % (
                entries[k][4], entries[k][0]), file=sys.stderr)
    fails = []
    if len(ref_lines) != len(cand_lines):
        fails.append("line count: reference %d, candidate %d" % (len(ref_lines), len(cand_lines)))
        return fails
    ref_ct = [i for i, l in enumerate(ref_lines) if COMPUTE_RE.match(l)]
    cand_ct = [i for i, l in enumerate(cand_lines) if COMPUTE_RE.match(l)]
    if ref_ct != cand_ct:
        fails.append("'Compute time' line at reference line(s) %s but candidate line(s) %s" % (
            [i + 1 for i in ref_ct], [i + 1 for i in cand_ct]))
    skip = set(ref_ct) | set(cand_ct)
    for i, (rl, cl) in enumerate(zip(ref_lines, cand_lines)):
        if i in skip:
            continue
        lno = i + 1
        rtoks, ctoks = rl.split(), cl.split()
        assigned = per_line[i]
        if len(rtoks) != len(ctoks):
            fails.append("line %d: token count %d vs %d\n    ref: %s\n    cand: %s" % (
                lno, len(rtoks), len(ctoks), rl, cl))
            continue
        for t, (rt, ct) in enumerate(zip(rtoks, ctoks), 1):
            pr, pc = parse_number(rt), parse_number(ct)
            if pr is None and pc is None:
                if rt != ct:
                    fails.append("line %d token %d: %r vs %r (non-numeric tokens must be "
                                 "identical)" % (lno, t, rt, ct))
                continue
            if pr is None or pc is None:
                if rt != ct:
                    fails.append("line %d token %d: %r vs %r (numeric on one side only)" % (
                        lno, t, rt, ct))
                continue
            if pr[0] != pc[0]:
                fails.append("line %d token %d: %r vs %r (stripped punctuation or parentheses "
                             "differ: %r vs %r)" % (lno, t, rt, ct, pr[0], pc[0]))
                continue
            if len(pr[1]) != len(pc[1]):
                fails.append("line %d token %d: %r vs %r (range '..' on one side only)" % (
                    lno, t, rt, ct))
                continue
            for j, (xr, xc) in enumerate(zip(pr[1], pc[1])):
                where = "line %d token %d%s" % (lno, t, "" if len(pr[1]) == 1 else
                                                 (" part %d" % (j + 1)))
                if t in assigned:
                    ok, detail = judge.judge(assigned[t][0], xr[0], xc[0], xr[1], xc[1])
                else:
                    ok, detail = default_rule(xr[1], xc[1]), "default rule"
                if not ok:
                    fails.append("%s: %r vs %r (%s)" % (where, xr[1], xc[1], detail))
    return fails


def load_json(path):
    if path and os.path.exists(path):
        with open(path) as fh:
            return json.load(fh)
    return None


def run(name, cand_path, map_path, cand_json_path):
    if name not in compare.RULES:
        raise MapError("unknown workload %s" % name)
    ref_txt = os.path.join(REF_DIR, name + ".txt")
    for label, p in (("reference report", ref_txt), ("candidate report", cand_path),
                     ("token map", map_path)):
        if not os.path.exists(p):
            raise MapError("%s not found: %s" % (label, p))
    if cand_json_path is not None and not os.path.exists(cand_json_path):
        raise MapError("candidate JSON not found: %s" % cand_json_path)
    with open(map_path) as fh:
        entries = parse_map(fh.read(), compare.RULES[name])
    judge = Judge(compare.RULES[name], load_json(os.path.join(REF_DIR, name + ".json")),
                  load_json(cand_json_path))
    with open(ref_txt) as fh:
        ref_text = fh.read()
    with open(cand_path) as fh:
        cand_text = fh.read()
    return judge_reports(ref_text, cand_text, entries, judge)


# ------------------------------------------------------------------------------ self test

SELF_RULES = {
    "v": ("num", 0.0, 1e-3), "cnt": ("int", 2), "flag": ("exact",), "res": ("small", 1e-6),
    "arr": ("num", 0.0, 1e-9),
    "idx": ("argmax_tol", "arr", 1e-9),
}
SELF_REF_JSON = {"v": [1.0, -100.0, 50.0], "cnt": 10, "flag": 1, "res": 0.0,
                 "arr": [1.0, 5.0, 5.0 * (1 + 1e-12), 3.0], "idx": 2}


def self_test():
    bad = 0

    def case(label, ref, cand, mapping, want, cand_json="same", expect_map_error=False,
             ref_json="same"):
        nonlocal bad
        cj = SELF_REF_JSON if cand_json == "same" else cand_json
        rj = SELF_REF_JSON if ref_json == "same" else ref_json
        try:
            entries = parse_map(mapping, SELF_RULES)
            fails = judge_reports(ref, cand, entries, Judge(SELF_RULES, rj, cj))
            got = "pass" if not fails else "fail"
        except MapError:
            got = "map-error"
        wanted = "map-error" if expect_map_error else ("pass" if want else "fail")
        good = got == wanted
        bad += 0 if good else 1
        print("  %s %-62s -> %s (expected %s)" % ("ok  " if good else "FAIL", label, got, wanted))

    print("== report comparison self-test")
    R = "Total: 10 items\nValue 100.000 mm\nCompute time: 1.234 s\nEnd\n"
    case("identical", R, R, "", True)
    # default rule
    case("default: 0.999 vs 1.000 (carry) passes", "x 0.999\n", "x 1.000\n", "", True)
    case("default: 1.5 vs 1.50 passes (changed by the unit-of-coarser rule; was a fail)",
         "x 1.5\n", "x 1.50\n", "", True)
    case("default: last digit +1 passes", "x 3.14\n", "x 3.15\n", "", True)
    case("default: last digit +2 fails", "x 3.14\n", "x 3.16\n", "", False)
    case("default: same exponent, mantissa +1 passes", "x 1.23e-05\n", "x 1.24e-05\n", "", True)
    case("default: different exponent fails", "x 1.0e-05\n", "x 1.0e-04\n", "", False)
    case("default: negative sign carry -0.001 vs 0.000", "x -0.001\n", "x 0.000\n", "", True)
    case("default: -9.99 vs -10.00 passes", "x -9.99\n", "x -10.00\n", "", True)
    case("default: NaN vs NaN equal text", "x NaN\n", "x NaN\n", "", True)
    case("default: Inf vs NaN fails", "x Inf\n", "x NaN\n", "", False)
    case("default: +3 vs +3 passes", "x +3\n", "x +3\n", "", True)
    case("default: +3 vs 4 passes (last digit +1)", "x +3\n", "x 4\n", "", True)
    # default rule: exact decimal unit of the coarser token
    case("default: 9.99e-05 vs 1.00e-04 passes (exactly one unit)", "x 9.99e-05\n", "x 1.00e-04\n", "", True)
    case("default: 9.9999 vs 10 passes", "x 9.9999\n", "x 10\n", "", True)
    case("default: 1E+05 vs 1e+05 passes (exponent case)", "x 1E+05\n", "x 1e+05\n", "", True)
    case("default: 1.5 vs 1.7 fails", "x 1.5\n", "x 1.7\n", "", False)
    case("default: 10 vs 12 fails", "x 10\n", "x 12\n", "", False)
    case("default: exactly one unit passes (1.00 vs 1.01)", "x 1.00\n", "x 1.01\n", "", True)
    case("default: just over one unit fails (1.00 vs 1.0101)", "x 1.00\n", "x 1.0101\n", "", False)
    case("default: just over one unit fails, exponent (9.99e-05 vs 1.01e-04)",
         "x 9.99e-05\n", "x 1.01e-04\n", "", False)
    case("default: coarse side decides (1.0 vs 1.04 passes: unit 0.1)", "x 1.0\n", "x 1.04\n", "", True)
    case("default: coarse side decides (1.0 vs 1.2 fails)", "x 1.0\n", "x 1.2\n", "", False)
    case("default: mixed exponent/non-exponent (0.0001 vs 1.0e-04) passes", "x 0.0001\n",
         "x 1.0e-04\n", "", True)
    case("default: mixed exponent/non-exponent fails (0.0001 vs 2.5e-04)", "x 0.0001\n",
         "x 2.5e-04\n", "", False)
    case("default: exact boundary uses decimals not floats (0.3 vs 0.2)", "x 0.3\n", "x 0.2\n", "", True)
    case("default: Inf vs Inf equal text passes", "x Inf\n", "x Inf\n", "", True)
    case("default: Inf vs inf fails (text differs)", "x Inf\n", "x inf\n", "", False)
    # token layers
    case("layer: parenthesis same on both sides", "x (1.5 y\n", "x (1.5 y\n", "", True)
    case("layer: opening parenthesis on one side only", "x (1.5 y\n", "x 1.5 y\n", "", False)
    case("layer: closing parenthesis on one side only", "x 1.5) y\n", "x 1.5 y\n", "", False)
    case("layer: parentheses with number tolerance applied (0.999) vs (1.000)", "x (0.999)\n",
         "x (1.000)\n", "", True)
    case("layer: ) then , combined 1.2345), same", "x 1.2345),\n", "x 1.2346),\n", "", True)
    case("layer: ) then , combined, comma differs", "x 1.2345),\n", "x 1.2345);\n", "", False)
    case("layer: ) then , combined, paren missing on candidate", "x 1.2345),\n", "x 1.2345,\n", "", False)
    case("layer: ( and trailing comma (847.70, same", "x (847.70,\n", "x (847.70,\n", "", True)
    case("layer: rule applies to the stripped number", "x (10.00)\n", "x (10.02)\n",
         "^x 2 num 0.02 0\n", True)
    case("layer: rule fails on the stripped number", "x (10.00)\n", "x (10.05)\n",
         "^x 2 num 0.02 0\n", False)
    case("layer: P2.500 stays non-numeric (identical required)", "P2.500 1\n", "P2.500 1\n", "", True)
    case("layer: P2.500 vs P2.501 fails", "P2.500 1\n", "P2.501 1\n", "", False)
    case("layer: a map entry on a non-numeric P2.500 token is a map error", "P2.500 1\n",
         "P2.500 1\n", "^P 1 exact\n", False, expect_map_error=True)
    # '..' ranges
    case("range: 0.30..12.00 identical", "R 0.30..12.00 c\n", "R 0.30..12.00 c\n", "", True)
    case("range: default rule on both parts (0.30..12.00 vs 0.31..12.01)", "R 0.30..12.00\n",
         "R 0.31..12.01\n", "", True)
    case("range: second part fails by default", "R 0.30..12.00\n", "R 0.30..12.05\n", "", False)
    case("range: first part fails by default", "R 0.30..12.00\n", "R 0.35..12.00\n", "", False)
    case("range: rule applies to both parts (num 0.06 passes 0.05)", "R 0.30..12.00\n",
         "R 0.35..12.05\n", "^R 2 num 0.06 0\n", True)
    case("range: rule applies to both parts (second part outside)", "R 0.30..12.00\n",
         "R 0.35..12.10\n", "^R 2 num 0.06 0\n", False)
    case("range: exact rule on both parts", "R 1..2\n", "R 1..3\n", "^R 2 exact\n", False)
    case("range: range on one side only", "R 0.30..12.00\n", "R 0.30\n", "", False)
    case("range: combined with parentheses and comma (1.0..2.0),", "R (1.0..2.0),\n",
         "R (1.0..2.0),\n", "", True)
    case("range: non-numeric part makes the token non-numeric (identical required)", "R a..1\n",
         "R a..1\n", "", True)
    case("range: non-numeric part, text differs", "R a..1\n", "R a..2\n", "", False)
    case("range: map entry on a token whose part is non-numeric is a map error", "R a..1\n",
         "R a..1\n", "^R 2 exact\n", False, expect_map_error=True)
    # trailing punctuation
    case("trailing comma same on both sides", "a 1.5, b\n", "a 1.5, b\n", "", True)
    case("trailing punctuation differs (, vs ;)", "a 1.5, b\n", "a 1.5; b\n", "", False)
    case("trailing punctuation present on one side only", "a 1.5: b\n", "a 1.5 b\n", "", False)
    case("percent suffix is not stripped: 12.50% identical", "p 12.50%\n", "p 12.50%\n", "", True)
    case("percent suffix: 12.50% vs 12.51% fails (non-numeric)", "p 12.50%\n", "p 12.51%\n", "", False)
    # compute time
    case("Compute time values ignored", "a 1\nCompute time: 0.5 s\n", "a 1\nCompute time: 9.9 s\n", "", True)
    case("Compute time at different line positions", "a 1\nCompute time: 0.5 s\nb\n",
         "a 1\nb\nCompute time: 0.5 s\n", "", False)
    # structure
    case("line count mismatch", "a\nb\n", "a\n", "", False)
    case("token count mismatch", "a 1 2\n", "a 1\n", "", False)
    case("non-numeric token differs", "Name abc 1\n", "Name abd 1\n", "", False)
    case("numeric vs non-numeric", "a 1\n", "a x\n", "", False)
    # rules
    case("exact pass", "N: 5\n", "N: 5\n", "^N: 2 exact\n", True)
    case("exact fail", "N: 5\n", "N: 6\n", "^N: 2 exact\n", False)
    case("int within", "Rejects: 100\n", "Rejects: 102\n", "^Rejects: 2 int 2\n", True)
    case("int outside", "Rejects: 100\n", "Rejects: 103\n", "^Rejects: 2 int 2\n", False)
    case("num within (atol 0.02; the default rule would reject)", "Q 10.00\n", "Q 10.02\n",
         "^Q 2 num 0.02 0\n", True)
    case("num outside", "Q 10.00\n", "Q 10.03\n", "^Q 2 num 0.01 0\n", False)
    case("num rtol uses reference magnitude", "Q 1000\n", "Q 1004\n", "^Q 2 num 0 1e-2\n", True)
    case("json num uses largest magnitude of key (100); default rejects", "T 50.00\n",
         "T 50.09\n", "^T 2 json v\n", True)
    case("json num outside", "T 50.0\n", "T 50.2\n", "^T 2 json v\n", False)
    case("json int", "n 10\n", "n 12\n", "^n 2 json cnt\n", True)
    case("json int outside", "n 10\n", "n 13\n", "^n 2 json cnt\n", False)
    case("json exact", "f 1\n", "f 2\n", "^f 2 json flag\n", False)
    case("json small pass (1e-7 vs 5e-7, bound 1e-6; default rejects)", "r 0.0000001\n",
         "r 0.0000005\n", "^r 2 json res\n", True)
    case("json small fail", "r 0.0000001\n", "r 0.01\n", "^r 2 json res\n", False)
    case("regex with POSIX class", "k 12 x\n", "k 13 x\n", "^k[[:space:]][[:digit:]]+[[:space:]]x 2 exact\n", False)
    case("comments and blank lines in map", "N: 5\n", "N: 5\n", "# comment\n\n^N: 2 exact\n", True)
    # json argmax rule
    cj_ok = {"arr": [1.0, 5.0, 5.0 * (1 - 1e-12), 3.0], "idx": 2}
    case("json argmax: tokens match JSON, own extremum", "i 2\n", "i 2\n", "^i 2 json idx\n", True, cj_ok)
    cj_near = {"arr": [1.0, 5.0, 5.0 * (1 + 1e-12), 3.0], "idx": 3}
    case("json argmax: near-tie, candidate's own extremum is 3", "i 2\n", "i 3\n",
         "^i 2 json idx\n", True, cj_near)
    rj_far = {"arr": [1.0, 5.0, 3.0, 5.0 * (1 + 1e-12)], "idx": 2}
    cj_far = {"arr": [1.0, 5.0, 3.0, 5.0 * (1 + 1e-12)], "idx": 4}
    case("json argmax: near-tie 2 vs 4 passes (default rule rejects)", "i 2\n", "i 4\n",
         "^i 2 json idx\n", True, cj_far, ref_json=rj_far)
    case("json argmax: forgot +1 at 2 vs 3 near-tie (default rule would pass)", "i 2\n", "i 3\n",
         "^i 2 json idx\n", False, {"arr": [1.0, 5.0, 3.0, 5.0 * (1 + 1e-12)], "idx": 3},
         ref_json=rj_far)
    case("json argmax: key missing from --candidate-json is a failure, not a map error",
         "i 2\n", "i 2\n", "^i 2 json idx\n", False, {"arr": [1.0, 5.0, 4.0]})
    case("json argmax: null candidate JSON index fails without crashing", "i 2\n", "i 2\n",
         "^i 2 json idx\n", False, {"arr": [1.0, 5.0, 4.0], "idx": None})
    case("json argmax: fractional candidate JSON index fails", "i 2\n", "i 2\n",
         "^i 2 json idx\n", False, {"arr": [1.0, 5.0, 4.0], "idx": 2.7})
    case("json argmax: null MATLAB JSON index fails without crashing", "i 2\n", "i 2\n",
         "^i 2 json idx\n", False, cj_ok, ref_json={"arr": [1.0, 5.0, 4.0], "idx": None})
    case("json rule without the reference JSON -> map error", "n 10\n", "n 10\n",
         "^n 2 json cnt\n", False, ref_json=None, expect_map_error=True)
    cj_dup = {"arr": [1.0, 5.0, 5.0, 3.0], "idx": 3}
    case("json argmax: exact duplicate, must name the first (2)", "i 2\n", "i 3\n",
         "^i 2 json idx\n", False, cj_dup)
    cj_fwd = {"arr": [1.0, 5.0, 4.0, 3.0], "idx": 1}
    case("json argmax: forgot +1 (idx 1, candidate extremum at 2)", "i 2\n", "i 1\n", "^i 2 json idx\n",
         False, cj_fwd)
    case("json argmax: candidate token differs from candidate JSON", "i 2\n", "i 2\n", "^i 2 json idx\n",
         False, {"arr": [1.0, 5.0, 4.0, 3.0], "idx": 3})
    case("json argmax: reference token differs from MATLAB JSON", "i 3\n", "i 2\n", "^i 2 json idx\n",
         False, cj_ok)
    case("json argmax: --candidate-json missing -> map error", "i 2\n", "i 2\n", "^i 2 json idx\n",
         False, None, expect_map_error=True)
    # map errors
    case("map error is not hidden by a line-count mismatch", "a 1\nb 2\n", "a 1\n", "^a 5 exact\n",
         False, expect_map_error=True)
    case("map error is not hidden by a Compute-time position mismatch",
         "a 1\nCompute time: 1 s\n", "Compute time: 1 s\na 1\n", "^a 5 exact\n", False,
         expect_map_error=True)
    case("map is validated against Compute-time lines too", "Compute time: 0.5 s\n",
         "Compute time: 0.5 s\n", "^Compute 9 exact\n", False, expect_map_error=True)
    case("map error: malformed entry", "a 1\n", "a 1\n", "^a 2\n", False, expect_map_error=True)
    case("map error: unknown rule", "a 1\n", "a 1\n", "^a 2 fuzzy\n", False, expect_map_error=True)
    case("map error: unknown json key", "a 1\n", "a 1\n", "^a 2 json nope\n", False, expect_map_error=True)
    case("map error: conflicting rules on same token", "a 1\n", "a 1\n", "^a 2 exact\n^a 2 int 1\n",
         False, expect_map_error=True)
    case("map: identical duplicate rules are fine", "a 1\n", "a 1\n", "^a 2 exact\n^a 2 exact\n", True)
    case("map error: token number beyond the line", "a 1\n", "a 1\n", "^a 5 exact\n", False,
         expect_map_error=True)
    case("map error: token is non-numeric", "a 1\n", "a 1\n", "^a 1 exact\n", False,
         expect_map_error=True)
    case("map error: bad int argument", "a 1\n", "a 1\n", "^a 2 int x\n", False, expect_map_error=True)
    case("map error: token number not an integer", "a 1\n", "a 1\n", "^a b exact\n", False,
         expect_map_error=True)
    case("map error: unknown POSIX class", "a 1\n", "a 1\n", "^a[[:foo:]] 2 exact\n", False,
         expect_map_error=True)
    # POSIX classes are translated only inside bracket expressions
    for src, want in (("[[:digit:]x]", "[0-9x]"), ("^k[:digit:]", "^k[:digit:]"),
                      ("[^[:space:]]+", "[^\\s]+"), ("a[:foo:]", "a[:foo:]"),
                      ("\\[:digit:]", "\\[:digit:]")):
        got = posix_to_python(src)
        good = got == want
        bad += 0 if good else 1
        print("  %s posix_to_python(%r) = %r (expected %r)" % ("ok  " if good else "FAIL", src, got, want))
    try:
        posix_to_python("[[:foo:]]")
        good = False
    except MapError:
        good = True
    bad += 0 if good else 1
    print("  %s unknown class inside brackets raises MapError" % ("ok  " if good else "FAIL"))
    case("class outside brackets is an ordinary set: no translation, matches no line (warning only)",
         "k1 5\n", "k1 6\n", "^k[:digit:] 2 exact\n", True)
    # parse_number unit checks
    unit = [("(1.5)", True), ("1.2345),", True), ("0.30..12.00", True), ("1..2", True),
            ("(", False), ("..", False), ("1...2", False), ("P2.500", False), ("1.5))", False),
            ("1.5", True), ("+3", True), ("-inf", True), ("nan", True), ("1e5", True),
            ("1.5,", True), ("1.5,,", False), ("abc", False), ("12.5%", False), ("", False),
            ("-", False), ("1_0", False), (":", False), ("0x10", False)]
    for tok, want in unit:
        got = parse_number(tok) is not None
        good = got == want
        bad += 0 if good else 1
        print("  %s parse_number(%r) numeric=%s (expected %s)" % ("ok  " if good else "FAIL", tok, got, want))
    print("\n%s" % ("ALL REPORT SELF-TESTS PASS" if bad == 0 else "%d self-test(s) FAILED" % bad))
    return 0 if bad == 0 else 1


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    cand_json = None
    pos = []
    i = 0
    while i < len(argv):
        if argv[i] == "--candidate-json":
            if i + 1 >= len(argv):
                print("--candidate-json needs a path", file=sys.stderr)
                return 2
            cand_json = argv[i + 1]
            i += 2
            continue
        if argv[i].startswith("--"):
            print("unknown option %s" % argv[i], file=sys.stderr)
            return 2
        pos.append(argv[i])
        i += 1
    if len(pos) != 3:
        print(__doc__.split("\n\n")[0], file=sys.stderr)
        print("usage: compare_report.py <name> <candidate.txt> <tokens-file> "
              "[--candidate-json <path>] | --self-test", file=sys.stderr)
        return 2
    try:
        fails = run(pos[0], pos[1], pos[2], cand_json)
    except MapError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2
    for f in fails:
        print("FAIL " + f)
    print("%s: report %s" % (pos[0], "EQUIVALENT" if not fails else
                              "NOT equivalent (%d difference(s))" % len(fails)))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
