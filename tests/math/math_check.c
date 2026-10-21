/*
 * tests/math/math_check.c -- runtime harness of the elementary functions (Sea DESIGN.md 4.10.6).
 *
 * A test tool, never part of Sea. Built with `xcrun cc` on the Mac and `gcc` on Linux and linked
 * with libsea.a (no other Sea file): it reads <DIR>/<fn>.vec for fn in log exp sin cos pow hypot,
 * calls the scalar entry sea_<fn> through its C prototype (DESIGN.md 4.10.1) for every case and
 * compares the result's bit pattern with the expected one, every bit, NaN included.
 *
 *   usage: math_check [DIR]        DIR holds the .vec files (default: tests/math)
 *
 * A .vec line is the argument patterns and the expected result pattern, each 16 upper-case
 * hexadecimal digits, separated by one space (two fields for log exp sin cos, three for pow and
 * hypot), then LF. Blank lines and lines starting with '#' are ignored.
 *
 * Output: `math <fn>: <n> cases ok` per file, or each mismatch as
 * `math <fn>: <args> expected <e> got <g>` (patterns, no 0x). Exit status: 0 all cases matched,
 * 1 a mismatch, 2 a setup problem (missing or malformed file).
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* DESIGN.md 4.10.6: each file holds at most 10 000 cases, and the generator writes that many;
   a file with any other count is truncated or foreign. */
#define VEC_CASES 10000L

double sea_log(double);
double sea_exp(double);
double sea_sin(double);
double sea_cos(double);
double sea_pow(double, double);
double sea_hypot(double, double);

typedef double (*fn1_t)(double);
typedef double (*fn2_t)(double, double);

static const struct {
    const char *name;
    int nargs;
    fn1_t f1;
    fn2_t f2;
} FUNCS[] = {
    {"log", 1, sea_log, 0},   {"exp", 1, sea_exp, 0},       {"sin", 1, sea_sin, 0},
    {"cos", 1, sea_cos, 0},   {"pow", 2, 0, sea_pow},       {"hypot", 2, 0, sea_hypot},
};

static double from_bits(uint64_t u) {
    double d;
    memcpy(&d, &u, sizeof d);
    return d;
}

static uint64_t to_bits(double d) {
    uint64_t u;
    memcpy(&u, &d, sizeof u);
    return u;
}

/* parse_hex16: exactly 16 upper-case hex digits at s; returns 1 and stores the value */
static int parse_hex16(const char *s, uint64_t *out) {
    uint64_t v = 0;
    for (int i = 0; i < 16; i++) {
        char c = s[i];
        int d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
        else return 0;
        v = (v << 4) | (uint64_t)d;
    }
    *out = v;
    return 1;
}

int main(int argc, char **argv) {
    const char *dir = argc > 1 ? argv[1] : "tests/math";
    if (argc > 2) {
        fprintf(stderr, "usage: math_check [DIR]\n");
        return 2;
    }
    int status = 0;
    for (size_t k = 0; k < sizeof FUNCS / sizeof FUNCS[0]; k++) {
        char path[4096];
        snprintf(path, sizeof path, "%s/%s.vec", dir, FUNCS[k].name);
        FILE *fp = fopen(path, "r");
        if (!fp) {
            fprintf(stderr, "math_check: cannot open %s\n", path);
            return 2;
        }
        char line[256];
        long lineno = 0, cases = 0, bad = 0;
        while (fgets(line, sizeof line, fp)) {
            lineno++;
            size_t len = strlen(line);
            if (len == 0 || line[len - 1] != '\n') {
                fprintf(stderr, "math_check: %s:%ld: line too long or missing LF\n", path, lineno);
                return 2;
            }
            line[--len] = '\0';
            if (len == 0 || line[0] == '#') continue;
            int nf = FUNCS[k].nargs + 1;
            if (len != (size_t)nf * 17 - 1) {
                fprintf(stderr, "math_check: %s:%ld: malformed line\n", path, lineno);
                return 2;
            }
            uint64_t f[3];
            for (int i = 0; i < nf; i++) {
                if (!parse_hex16(line + i * 17, &f[i]) || (i < nf - 1 && line[i * 17 + 16] != ' ')) {
                    fprintf(stderr, "math_check: %s:%ld: malformed line\n", path, lineno);
                    return 2;
                }
            }
            /* volatile argument copies keep the compiler from folding the call */
            volatile double a = from_bits(f[0]), b = nf == 3 ? from_bits(f[1]) : 0.0;
            double r = FUNCS[k].nargs == 1 ? FUNCS[k].f1(a) : FUNCS[k].f2(a, b);
            uint64_t want = f[nf - 1], got = to_bits(r);
            cases++;
            if (got != want) {
                bad++;
                if (nf == 2)
                    printf("math %s: %016llX expected %016llX got %016llX\n", FUNCS[k].name,
                           (unsigned long long)f[0], (unsigned long long)want, (unsigned long long)got);
                else
                    printf("math %s: %016llX %016llX expected %016llX got %016llX\n", FUNCS[k].name,
                           (unsigned long long)f[0], (unsigned long long)f[1], (unsigned long long)want,
                           (unsigned long long)got);
            }
        }
        fclose(fp);
        if (cases != VEC_CASES) {
            fprintf(stderr, "math_check: %s holds %ld cases, expected %ld\n", path, cases, VEC_CASES);
            return 2;
        }
        if (bad == 0) printf("math %s: %ld cases ok\n", FUNCS[k].name, cases);
        else status = 1;
    }
    return status;
}
