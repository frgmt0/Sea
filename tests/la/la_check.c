/*
 * tests/la/la_check.c -- conformance test of Sea's linear-algebra runtime entries against
 * libsea.a and libbaysickrt.a (Sea DESIGN.md 2.13.8, "tests/la/la_check.c"; 2.13.2, 2.13.5,
 * 2.13.6; normative there). This part covers the entries of sub-phase 8b:
 *
 *   GEMV    (52, sea_gemv,   class E): y[i] = A[i,0]*x[0], then y[i] = y[i] + A[i,j]*x[j] for
 *           j = 1 .. k-1 ascending, each product and sum rounded separately (the first term is the
 *           product itself, never 0 + A[i,0]*x[0]); +0 for k = 0 (DESIGN.md 2.13.2);
 *   VECMAT  (53, sea_vecmat, class E): y[j] = the pinned 8-lane sum of LANGUAGE.md 10.5 over the
 *           rounded products x[kk]*A[kk,j], kk ascending: accumulators a[0..8] start at -0.0,
 *           a[kk % 8] = a[kk % 8] + x[kk]*A[kk,j], result ((a0 + a1) + (a2 + a3)) + ((a4 + a5) +
 *           (a6 + a7)); +0 for k = 0;
 *   MATMUL  (51, sea_matmul, class R): compared only on exact data (small integers, so every
 *           product and partial sum is exact in every order and variant, DESIGN.md 2.13.8), and,
 *           on inexact data, only with itself (two calls give the same bits: class R is
 *           deterministic for a target and variant, LANGUAGE.md 6.8).
 *
 * The expected values of GEMV and VECMAT come from a C transcription of the pinned orders below
 * (ref_gemv, ref_vecmat), compiled with -ffp-contract=off (no FMA) and without fast-math (no
 * reassociation), so each C operation is exactly one binary64 operation; never from the runtime.
 * Every r and k from 0 to 33 (GEMV) and every k and c from 0 to 33 (VECMAT) is tested with seeded
 * random inputs in three data modes (inexact finite values of mixed magnitude; one element in four
 * special; every element special), the special values being +-0, +-inf, NaNs with payloads (quiet
 * and signalling, either sign), subnormals, the largest finite value and values whose products
 * overflow or underflow; plus a few long shapes (W3's 16001 x 60 road product among them). A result
 * is compared bit for bit, except that a NaN result need only be a NaN: LANGUAGE.md 6.5 makes a
 * NaN's sign and payload unobservable and lets the targets produce different NaN bits for the same
 * operation (which operand's payload an fmul/mulpd propagates depends on operand order), so the
 * class-E guarantee is every bit of every non-NaN value and NaN-ness. Every check also verifies
 * the result's header (count 1, SEA_TAG_ARRAY, f64, rank, extents) and that the arguments are
 * unchanged, bit for bit.
 *
 * Variants (DESIGN.md 2.13.5 "Variants", L-iu, 4.4): the test selects every usable variant itself,
 * as Baysick's tests/kern does and as the runtime's main does: _bsk_kern_init, then for each name
 * of _bsk_kern_variants() _bsk_kern_use(name) and _sea_variant set as main sets it (arm64:
 * SEA_VAR_NEON; x86_64: SEA_VAR_AVX2 for "avx2", else SEA_VAR_SSE2), and every case runs under
 * every variant. Class-E results must equal the transcription in each, so they are identical
 * across variants; exact MATMUL data is identical across variants because it is exact.
 *
 * Linking: this file defines main and its own one-record error-site table _sea_sites (a run-time
 * error would report "la_check.c:1: error: ..."; no case here makes one: the error paths are the
 * runtime tests' tests/rt/<target>/rt_la_*), so libsea.a's rt_main.o is not pulled in; that needs
 * _sea_variant in rt_kern.o (L-iu). Built by `make test-la` (Mac, xcrun cc) and by the cross run's
 * once-only case la/la_check (Linux, gcc), with -I the directory of the generated sea_consts.h
 * (tests/la/gen_consts.sh, L-jd); every value with a name in a contract file comes from there.
 *
 * Output: one summary line on stdout; each failed check on stderr (at most MAX_LINES per case and
 * variant, then a count). Exit status: 0 every check passed; 1 a check failed; 2 setup error (no
 * usable variant, out of memory).
 */
#include <math.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sea_consts.h"

/* ---- Runtime interface (DESIGN.md 4.8; C names, Mach-O adds the leading underscore) ------- */
void *sea_arr_new_u(int64_t ek, int64_t rank, int64_t rows, int64_t cols, int64_t site);
void sea_free(void *obj);
void *sea_matmul(void *a, void *b, int64_t site);
void *sea_gemv(void *a, void *x, int64_t site);
void *sea_vecmat(void *x, void *a, int64_t site);
extern uint64_t sea_variant;

/* Baysick's kernel selection (Baysick DESIGN.md 6.6.1, 6.6.3) */
void bsk_kern_init(void);
int64_t bsk_kern_use(const char *name);
const char *bsk_kern_name(void);
const char *const *bsk_kern_variants(void);

/* ---- The error-site table this program provides (DESIGN.md 4.8, "Error-site table") ------- */
struct static_str {
    uint64_t rc;
    uint64_t tag; /* u8 SEA_TAG_STR, bytes 9..15 zero (little-endian) */
    uint64_t len;
    char bytes[16];
};
_Static_assert(offsetof(struct static_str, rc) == SEA_STR_RC, "SEA_STR_RC");
_Static_assert(offsetof(struct static_str, len) == SEA_STR_LEN, "SEA_STR_LEN");
_Static_assert(offsetof(struct static_str, bytes) == SEA_STR_BYTES, "SEA_STR_BYTES");

struct site_rec {
    const struct static_str *file;
    uint64_t line;
};
_Static_assert(offsetof(struct site_rec, file) == SEA_SITE_FILE, "SEA_SITE_FILE");
_Static_assert(offsetof(struct site_rec, line) == SEA_SITE_LINE, "SEA_SITE_LINE");
_Static_assert(sizeof(struct site_rec) == SEA_SITE_SIZE, "SEA_SITE_SIZE");

static const struct static_str site_file = {SEA_RC_STATIC, SEA_TAG_STR, 10, "la_check.c"};
const struct site_rec sea_sites[1] = {{&site_file, 1}};
#define SITE 0

/* ---- Array header access (DESIGN.md 4.1, 4.8) -------------------------------------------- */
#define HDR_U64(p, off) (*(const uint64_t *)((const char *)(p) + (off)))
#define HDR_U8(p, off) (*(const uint8_t *)((const char *)(p) + (off)))
#define ARR_DATA(p) (*(double *const *)((const char *)(p) + SEA_ARR_DATA))

/* ---- Settings ------------------------------------------------------------------------------ */
#define MAX_LINES 6
#define MAX_VARIANTS 16
#define MAX_EXT 33 /* every r and k (GEMV), k and c (VECMAT) from 0 to MAX_EXT */

static const char *g_variants[MAX_VARIANTS];
static int g_nvariants;
static const char *g_vname = "";
static long g_checks;
static long g_failures;
static int g_lines;        /* failure lines printed for the current case */
static char g_case[160];   /* label of the current case */

static void *xmalloc(size_t n) {
    void *p = malloc(n ? n : 1);
    if (!p) {
        fprintf(stderr, "la_check: out of memory (%zu bytes)\n", n);
        exit(2);
    }
    return p;
}

static uint64_t bits_of(double x) {
    uint64_t u;
    memcpy(&u, &x, sizeof u);
    return u;
}

static double double_of(uint64_t u) {
    double x;
    memcpy(&x, &u, sizeof x);
    return x;
}

static void begin_case(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void begin_case(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_case, sizeof g_case, fmt, ap);
    va_end(ap);
    g_lines = 0;
    g_checks++;
}

static void failf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void failf(const char *fmt, ...) {
    g_failures++;
    if (++g_lines > MAX_LINES) return;
    fprintf(stderr, "la_check: %s %s: ", g_vname, g_case);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fputc('\n', stderr);
}

static void end_case(void) {
    if (g_lines > MAX_LINES)
        fprintf(stderr, "la_check: %s %s: ... %d more failed checks not shown\n", g_vname, g_case,
                g_lines - MAX_LINES);
}

/* ---- Inputs: the BENCH.md generator (Baysick's tests/kern) -------------------------------- */
static uint64_t g_rng;
static uint64_t rng_next(void) {
    g_rng = 6364136223846793005ull * g_rng + 1442695040888963407ull;
    return g_rng;
}
static void rng_seed(uint64_t s) {
    g_rng = s * 0x9E3779B97F4A7C15ull + 1;
    rng_next();
}

/* A finite value of mixed magnitude with 52 random mantissa bits: (1 + f) * 2^e, e in -6 .. 6,
 * either sign (so products and sums are inexact and the order of the sums matters). */
static double rnd_inexact(void) {
    uint64_t r = rng_next();
    uint64_t mant = r >> 12;
    int e = (int)((rng_next() >> 40) % 13) - 6;
    uint64_t sign = (r & 0x800ull) ? 0x8000000000000000ull : 0;
    return double_of(sign | ((uint64_t)(1023 + e) << 52) | mant);
}

static const uint64_t SPECIALS[] = {
    0x0000000000000000ull, /* +0 */
    0x8000000000000000ull, /* -0 */
    0x7FF0000000000000ull, /* +inf */
    0xFFF0000000000000ull, /* -inf */
    0x7FF8000000000000ull, /* quiet NaN */
    0x7FF800000000BEEFull, /* quiet NaN with a payload */
    0xFFF8000000C0FFEEull, /* negative quiet NaN with a payload */
    0x7FF0000000000001ull, /* signalling NaN */
    0x0000000000000001ull, /* smallest subnormal */
    0x800FFFFFFFFFFFFFull, /* largest negative subnormal */
    0x0008000000000000ull, /* a subnormal */
    0x7FEFFFFFFFFFFFFFull, /* largest finite */
    0xFFEFFFFFFFFFFFFFull, /* most negative finite */
    0x7E37E43C8800759Cull, /* 1e300: products overflow */
    0x01A56E1FC2F8F359ull, /* 1e-300: products underflow to subnormal or 0 */
    0x3FF0000000000000ull, /* 1 */
    0xBFF0000000000000ull, /* -1 */
};
#define NSPECIAL (sizeof SPECIALS / sizeof SPECIALS[0])

/* mode 0: inexact finite values; mode 1: one element in four special; mode 2: all special */
static double rnd_value(int mode) {
    if (mode == 2 || (mode == 1 && (rng_next() >> 62) == 0))
        return double_of(SPECIALS[(rng_next() >> 33) % NSPECIAL]);
    return rnd_inexact();
}

/* An integer in [lo, hi], as a double. */
static double rnd_int(int lo, int hi) {
    return (double)(lo + (int)((rng_next() >> 33) % (uint64_t)(hi - lo + 1)));
}

/* ---- Sea arrays ------------------------------------------------------------------------------ */
/* new_vec / new_mat: a fresh f64 array from the runtime (sea_arr_new_u, entry 20) */
static void *new_vec(uint64_t n) {
    void *p = sea_arr_new_u(SEA_EK_F64, 1, (int64_t)n, 1, SITE);
    if (!p) {
        fprintf(stderr, "la_check: sea_arr_new_u returned null\n");
        exit(2);
    }
    return p;
}
static void *new_mat(uint64_t r, uint64_t c) {
    void *p = sea_arr_new_u(SEA_EK_F64, 2, (int64_t)r, (int64_t)c, SITE);
    if (!p) {
        fprintf(stderr, "la_check: sea_arr_new_u returned null\n");
        exit(2);
    }
    return p;
}

/* check_header: the result of an entry is a new array (count 1) of f64 with this rank and shape */
static int check_header(const void *p, int rank, uint64_t rows, uint64_t cols) {
    if (!p) {
        failf("null result");
        return 0;
    }
    int ok = 1;
    if (HDR_U64(p, SEA_OBJ_RC) != 1) { failf("result count %llu, expected 1", (unsigned long long)HDR_U64(p, SEA_OBJ_RC)); ok = 0; }
    if (HDR_U8(p, SEA_OBJ_TAG) != SEA_TAG_ARRAY) { failf("result tag %u", HDR_U8(p, SEA_OBJ_TAG)); ok = 0; }
    if (HDR_U8(p, SEA_ARR_EK) != SEA_EK_F64) { failf("result element kind %u", HDR_U8(p, SEA_ARR_EK)); ok = 0; }
    if (HDR_U8(p, SEA_ARR_RANK) != rank) { failf("result rank %u, expected %d", HDR_U8(p, SEA_ARR_RANK), rank); ok = 0; }
    if (HDR_U64(p, SEA_ARR_ROWS) != rows || HDR_U64(p, SEA_ARR_COLS) != cols) {
        failf("result shape %llux%llu, expected %llux%llu", (unsigned long long)HDR_U64(p, SEA_ARR_ROWS),
              (unsigned long long)HDR_U64(p, SEA_ARR_COLS), (unsigned long long)rows, (unsigned long long)cols);
        ok = 0;
    }
    return ok;
}

/* same_class_e: every bit of a non-NaN value; NaN-ness of a NaN (see the header) */
static int same_class_e(double want, double got) {
    if (isnan(want)) return isnan(got);
    return bits_of(want) == bits_of(got);
}

/* snapshot / unchanged: the arguments are borrowed and must not be written */
static uint64_t *snapshot(const double *d, size_t n) {
    uint64_t *s = xmalloc(n * sizeof *s);
    for (size_t i = 0; i < n; i++) s[i] = bits_of(d[i]);
    return s;
}
static void unchanged(const char *what, const double *d, const uint64_t *s, size_t n) {
    for (size_t i = 0; i < n; i++)
        if (bits_of(d[i]) != s[i]) {
            failf("argument %s element %zu changed", what, i);
            return;
        }
}

/* ---- The pinned orders, transcribed (DESIGN.md 2.13.2, LANGUAGE.md 10.5, 10.8) -------------- */
/* A is column-major r x k (A[i,j] at a[i + j*r]) */
static void ref_gemv(const double *a, const double *x, double *y, uint64_t r, uint64_t k) {
    for (uint64_t i = 0; i < r; i++) {
        if (k == 0) {
            y[i] = 0.0; /* +0 */
            continue;
        }
        double s = a[i] * x[0];
        for (uint64_t j = 1; j < k; j++) {
            double p = a[i + j * r] * x[j];
            s = s + p;
        }
        y[i] = s;
    }
}

/* A is column-major k x c */
static void ref_vecmat(const double *x, const double *a, double *y, uint64_t k, uint64_t c) {
    for (uint64_t j = 0; j < c; j++) {
        if (k == 0) {
            y[j] = 0.0; /* +0: the empty sum */
            continue;
        }
        double acc[8];
        for (int l = 0; l < 8; l++) acc[l] = -0.0;
        for (uint64_t kk = 0; kk < k; kk++) {
            double p = x[kk] * a[kk + j * k];
            acc[kk % 8] = acc[kk % 8] + p;
        }
        double s01 = acc[0] + acc[1], s23 = acc[2] + acc[3];
        double s45 = acc[4] + acc[5], s67 = acc[6] + acc[7];
        double lo = s01 + s23, hi = s45 + s67;
        y[j] = lo + hi;
    }
}

/* ---- GEMV ------------------------------------------------------------------------------------ */
static void run_gemv(uint64_t r, uint64_t k, int mode, uint64_t seed) {
    begin_case("gemv %llux%llu @ %llu mode %d", (unsigned long long)r, (unsigned long long)k,
               (unsigned long long)k, mode);
    rng_seed(seed);
    void *A = new_mat(r, k), *x = new_vec(k);
    double *ad = ARR_DATA(A), *xd = ARR_DATA(x);
    for (uint64_t i = 0; i < r * k; i++) ad[i] = rnd_value(mode);
    for (uint64_t i = 0; i < k; i++) xd[i] = rnd_value(mode);
    uint64_t *sa = snapshot(ad, r * k), *sx = snapshot(xd, k);
    double *want = xmalloc(r * sizeof *want);
    ref_gemv(ad, xd, want, r, k);
    void *y = sea_gemv(A, x, SITE);
    if (check_header(y, 1, r, 1)) {
        const double *yd = ARR_DATA(y);
        for (uint64_t i = 0; i < r; i++)
            if (!same_class_e(want[i], yd[i]))
                failf("y[%llu] = %016llx, expected %016llx", (unsigned long long)i,
                      (unsigned long long)bits_of(yd[i]), (unsigned long long)bits_of(want[i]));
    }
    unchanged("A", ad, sa, r * k);
    unchanged("x", xd, sx, k);
    if (y) sea_free(y);
    sea_free(A);
    sea_free(x);
    free(sa);
    free(sx);
    free(want);
    end_case();
}

/* ---- VECMAT ---------------------------------------------------------------------------------- */
static void run_vecmat(uint64_t k, uint64_t c, int mode, uint64_t seed) {
    begin_case("vecmat %llu @ %llux%llu mode %d", (unsigned long long)k, (unsigned long long)k,
               (unsigned long long)c, mode);
    rng_seed(seed);
    void *x = new_vec(k), *A = new_mat(k, c);
    double *xd = ARR_DATA(x), *ad = ARR_DATA(A);
    for (uint64_t i = 0; i < k; i++) xd[i] = rnd_value(mode);
    for (uint64_t i = 0; i < k * c; i++) ad[i] = rnd_value(mode);
    uint64_t *sa = snapshot(ad, k * c), *sx = snapshot(xd, k);
    double *want = xmalloc(c * sizeof *want);
    ref_vecmat(xd, ad, want, k, c);
    void *y = sea_vecmat(x, A, SITE);
    if (check_header(y, 1, c, 1)) {
        const double *yd = ARR_DATA(y);
        for (uint64_t j = 0; j < c; j++)
            if (!same_class_e(want[j], yd[j]))
                failf("y[%llu] = %016llx, expected %016llx", (unsigned long long)j,
                      (unsigned long long)bits_of(yd[j]), (unsigned long long)bits_of(want[j]));
    }
    unchanged("x", xd, sx, k);
    unchanged("A", ad, sa, k * c);
    if (y) sea_free(y);
    sea_free(x);
    sea_free(A);
    free(sa);
    free(sx);
    free(want);
    end_case();
}

/* ---- MATMUL ---------------------------------------------------------------------------------- */
/* exact: integers in [-8, 8], so every product (|p| <= 64) and every partial sum (|s| <= 64 k,
 * k <= 2^20) is an exact integer in every order; the expected product is computed in int64.
 * inexact: rnd_inexact values; the entry is called twice and the two results must be identical. */
static void run_matmul(const char *label, uint64_t r, uint64_t k, uint64_t c, int exact, uint64_t seed) {
    begin_case("matmul %s %llux%llu @ %llux%llu %s", label, (unsigned long long)r, (unsigned long long)k,
               (unsigned long long)k, (unsigned long long)c, exact ? "exact" : "inexact");
    rng_seed(seed);
    void *A = new_mat(r, k), *B = new_mat(k, c);
    double *ad = ARR_DATA(A), *bd = ARR_DATA(B);
    for (uint64_t i = 0; i < r * k; i++) ad[i] = exact ? rnd_int(-8, 8) : rnd_inexact();
    for (uint64_t i = 0; i < k * c; i++) bd[i] = exact ? rnd_int(-8, 8) : rnd_inexact();
    uint64_t *sa = snapshot(ad, r * k), *sb = snapshot(bd, k * c);
    void *C = sea_matmul(A, B, SITE);
    if (check_header(C, 2, r, c)) {
        const double *cd = ARR_DATA(C);
        if (exact) {
            for (uint64_t j = 0; j < c; j++)
                for (uint64_t i = 0; i < r; i++) {
                    int64_t s = 0;
                    for (uint64_t kk = 0; kk < k; kk++)
                        s += (int64_t)ad[i + kk * r] * (int64_t)bd[kk + j * k];
                    /* k = 0: the zero matrix of +0, bit for bit (DESIGN.md 2.13.2, "Empty
                     * operands": no kernel is called). k > 0 with an exact zero sum: the sign of
                     * a zero sum depends on the order and on the accumulator's start (class R),
                     * so only the value 0 is required. */
                    double want = (double)s;
                    double got = cd[i + j * r];
                    if (s == 0 && k > 0) {
                        if (!(got == 0.0))
                            failf("C[%llu,%llu] = %.17g, expected 0", (unsigned long long)i, (unsigned long long)j, got);
                    } else {
                        if (bits_of(got) != bits_of(want))
                            failf("C[%llu,%llu] = %016llx, expected %016llx", (unsigned long long)i,
                                  (unsigned long long)j, (unsigned long long)bits_of(got),
                                  (unsigned long long)bits_of(want));
                    }
                }
        } else {
            void *C2 = sea_matmul(A, B, SITE);
            if (check_header(C2, 2, r, c)) {
                const double *c2 = ARR_DATA(C2);
                for (uint64_t i = 0; i < r * c; i++)
                    if (bits_of(cd[i]) != bits_of(c2[i])) {
                        failf("two calls differ at linear index %llu: %016llx then %016llx",
                              (unsigned long long)i, (unsigned long long)bits_of(cd[i]),
                              (unsigned long long)bits_of(c2[i]));
                        break;
                    }
            }
            if (C2) sea_free(C2);
        }
    }
    unchanged("A", ad, sa, r * k);
    unchanged("B", bd, sb, k * c);
    if (C) sea_free(C);
    sea_free(A);
    sea_free(B);
    free(sa);
    free(sb);
    end_case();
}

/* ---- Variants ------------------------------------------------------------------------------ */
static int use_variant(const char *name) {
    if (bsk_kern_use(name) != 0) {
        fprintf(stderr, "la_check: _bsk_kern_use(\"%s\") failed for a listed variant\n", name);
        g_failures++;
        return 0;
    }
    if (strcmp(bsk_kern_name(), name) != 0) {
        fprintf(stderr, "la_check: _bsk_kern_name() is \"%s\" after _bsk_kern_use(\"%s\")\n",
                bsk_kern_name(), name);
        g_failures++;
        return 0;
    }
#if defined(__aarch64__)
    sea_variant = SEA_VAR_NEON;
#elif defined(__x86_64__)
    sea_variant = strcmp(name, "avx2") == 0 ? SEA_VAR_AVX2 : SEA_VAR_SSE2;
#else
#error "la_check: unsupported architecture"
#endif
    g_vname = name;
    return 1;
}

static const uint64_t MM_GRID[] = {0, 1, 2, 3, 4, 5, 7, 8, 9, 13, 16, 17, 31, 32, 33};
#define NGRID (sizeof MM_GRID / sizeof MM_GRID[0])

static const struct {
    const char *label;
    uint64_t r, k, c;
} MM_BIG[] = {
    {"la_mm_exact", 70, 40, 65}, {"nb-1", 31, 31, 31},  {"nb+1", 33, 33, 33},  {"tall", 300, 7, 5},
    {"wide", 5, 7, 300},         {"deep", 9, 1000, 6},  {"sq", 128, 128, 128}, {"odd", 129, 257, 67},
};
#define NBIG (sizeof MM_BIG / sizeof MM_BIG[0])

static const struct {
    uint64_t r, k;
} MV_LONG[] = {{16001, 60}, {1000, 3}, {7, 1000}, {257, 255}};
#define NLONG (sizeof MV_LONG / sizeof MV_LONG[0])

int main(void) {
    bsk_kern_init();
    const char *const *vl = bsk_kern_variants();
    for (; vl && *vl && g_nvariants < MAX_VARIANTS; vl++) g_variants[g_nvariants++] = *vl;
    if (g_nvariants == 0) {
        fprintf(stderr, "la_check: _bsk_kern_variants() lists no usable variant\n");
        return 2;
    }
    for (int v = 0; v < g_nvariants; v++) {
        if (!use_variant(g_variants[v])) continue;
        uint64_t seed = 1; /* the same inputs under every variant */
        for (int mode = 0; mode < 3; mode++)
            for (uint64_t r = 0; r <= MAX_EXT; r++)
                for (uint64_t k = 0; k <= MAX_EXT; k++) run_gemv(r, k, mode, seed++);
        for (int mode = 0; mode < 3; mode++)
            for (uint64_t k = 0; k <= MAX_EXT; k++)
                for (uint64_t c = 0; c <= MAX_EXT; c++) run_vecmat(k, c, mode, seed++);
        for (size_t t = 0; t < NLONG; t++)
            for (int mode = 0; mode < 2; mode++) {
                run_gemv(MV_LONG[t].r, MV_LONG[t].k, mode, seed++);
                run_vecmat(MV_LONG[t].k, MV_LONG[t].r, mode, seed++);
            }
        for (size_t a = 0; a < NGRID; a++)
            for (size_t b = 0; b < NGRID; b++)
                for (size_t d = 0; d < NGRID; d++) run_matmul("grid", MM_GRID[a], MM_GRID[b], MM_GRID[d], 1, seed++);
        for (size_t t = 0; t < NBIG; t++) {
            run_matmul(MM_BIG[t].label, MM_BIG[t].r, MM_BIG[t].k, MM_BIG[t].c, 1, seed++);
            run_matmul(MM_BIG[t].label, MM_BIG[t].r, MM_BIG[t].k, MM_BIG[t].c, 0, seed++);
        }
    }
    if (g_failures) {
        fprintf(stderr, "la_check: %ld failed checks in %ld cases\n", g_failures, g_checks);
        return 1;
    }
    printf("la_check: %ld cases ok under %d variants (", g_checks, g_nvariants);
    for (int v = 0; v < g_nvariants; v++) printf("%s%s", v ? " " : "", g_variants[v]);
    printf("); SEA_LA_NB %d\n", (int)SEA_LA_NB);
    return 0;
}
