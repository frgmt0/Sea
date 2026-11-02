/*
 * tests/la/la_check.c -- conformance test of Sea's linear-algebra runtime entries against
 * libsea.a and libbaysickrt.a (Sea DESIGN.md 2.13.8, "tests/la/la_check.c"; 2.13.2, 2.13.5,
 * 2.13.6; normative there). The entries of sub-phase 8b:
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
 * The entries of sub-phase 8c (DESIGN.md 2.13.5, 2.13.6; LANGUAGE.md 10.8):
 *
 *   LU, LU_SOLVE, CHOL, CHOL_SOLVE, SOLVE (54-58, class R through _bsk_kern_gemm_sub). For every
 *   n = 1 .. 200 (so SEA_LA_NB - 1, NB, NB + 1 and up to seven panels are crossed) and m = 1 (B a
 *   vector), 7 and 64 (B a matrix), with seeded inputs: a general matrix (uniform in [-1, 1)) for
 *   LU and a symmetric diagonally dominant one with a positive diagonal (positive definite by
 *   Gershgorin) for CHOL; every X must meet the backward-error rule of 2.13.8,
 *       ||A X[:,c] - B[:,c]||inf <= 64 n eps (||A||inf ||X[:,c]||inf + ||B[:,c]||inf)
 *   for every column c (eps = 2^-52; the residual is computed here in binary64, its own error
 *   about n eps ||A|| ||X||, well inside the factor 64). SOLVE is compared bit for bit with the
 *   path 2.13.6 prescribes ("exactly what solve(chol(A), B) or solve(lu(A), B) would give"): the
 *   positive definite matrix against CHOL_SOLVE(CHOL(A)); a general matrix, a symmetric one with
 *   a negative diagonal element, and two symmetric matrices with a positive diagonal whose
 *   Cholesky fails (at pivot 1, "early", and at the last pivot, "late", so the LU restarts from a
 *   fresh copy after up to seven Cholesky panels) against LU_SOLVE(LU(A)); the m of a SOLVE case
 *   cycles through 1, 7, 64 with n. Each factorization and each solve is made twice and must be
 *   identical (class R is deterministic for a target and variant, LANGUAGE.md 6.8); CHOL of a copy
 *   whose strict lower triangle is NaN must give the identical handle (L-im). Exact data (A =
 *   P L U from a unit lower L with entries in {0, +-1/2, +-1/4}, an integer U with power-of-two
 *   diagonal and a random permutation P; A = R'R from an integer R with power-of-two diagonal; B =
 *   A X for an integer X), where every elimination step, every partial sum and every pivot choice
 *   is exact in every order: the handle's factor must equal L\U (or R) and its interchanges the
 *   ones P implies, bit for bit, and X must come back exactly; being exact, these results are the
 *   same under every variant. The handle (DESIGN.md 2.13.6 "Handles", L-is: SEA_OBJ_HDR + 48 bytes
 *   of fields, n at 16, ||A||_1 at 24, the first zero pivot at 32 (-1 if none), 40 .. 63 zero, the
 *   factor at 64 with ld n, then an Lu's n u32 interchanges) is read directly: its count, tag,
 *   fields, ||A||_1 bit for bit against dlange's rule (2.13.6 "LU"), a Chol's strict lower
 *   triangle +0. Empty orders and B with no column give empty results (L-ik).
 *
 *   RCOND (59). Bit for bit against a C transcription of 2.13.6's steps (ref_rcond) applied to the
 *   handle's own factors, for every Lu made here (RCOND makes no Baysick call, so once the factors
 *   are given the result is the same under every variant). The transcription includes the user's
 *   rule of 8c: after every solve of steps 1-3, s = sum |x| in index order, and s = +Inf or NaN
 *   gives rcond 0 at once; step 4 gives 0 for est +Inf, NaN or 0. Special values in Decision 129's
 *   order (order 0 +Inf; ||A||_1 NaN NaN; a zero pivot 0; ||A||_1 +Inf 0; diag(1, 2^-1070), whose
 *   L^-T U^-T solve overflows, 0), the identity at every order 1 .. 80, and matrices on which the
 *   estimator finds ||A^-1||_1 (diagonal matrices with power-of-two entries; upper bidiagonal
 *   D - N with power-of-two entries, N >= 0, so A^-1 >= 0 and the first L^-T U^-T solve returns its
 *   column sums), where the result must also be within 4 n eps of the true (1/||A^-1||_1)/||A||_1
 *   (step 3's rounded t may exceed the exact estimate by a few ulps, 2.13.6).
 *
 *   EIG_SYM, EIG_SYM_GEN (60, 61; no Baysick call in EIG_SYM; EIG_SYM_GEN calls one only through
 *   sea_la_potrf for n > SEA_LA_NB). Every n = 0 .. 50 with seeded inputs against a C cyclic-Jacobi
 *   reference (ref_jacobi: rotations to an off-diagonal norm below 1e-3 eps ||A||_F, so its error
 *   is a few eps ||A||_F): EIG_SYM within 64 n eps ||A||_F of the sorted reference, element by
 *   element. EIG_SYM_GEN against Jacobi on the explicitly reduced C = R^-T K R^-1 (R = chol(M)
 *   here, unblocked; C symmetrized) within 64 n eps sqrt(n + 1) (||C||_F + ||K||_F / n): the two
 *   reductions differ by rounding, which perturbs C by about n eps ||K|| ||M^-1|| through the
 *   triangular solves (||M^-1||_2 <= 1/n for the diagonally dominant M used, its diagonal >= n + 1
 *   above off-diagonal row sums < n) and by about n eps kappa(R) ||C|| through the error of R
 *   (kappa(R) = sqrt(kappa(M)) <= sqrt(n + 1) for that M). Exact cases: a diagonal A gives its
 *   sorted diagonal and diagonal K with a power-of-four diagonal M gives the sorted K[i,i] /
 *   M[i,i], bit for bit; a ±Inf or NaN element gives n NaN (L-ip, L-iy, including the overflowing
 *   reduction K = 1e300 I, M = 1e-300 I). Every result is checked ascending, made twice
 *   (identical), and compared across variants (identical bits, NaN-ness for a NaN): EIG_SYM at
 *   every n, EIG_SYM_GEN for n <= SEA_LA_NB (no kernel call, L-it) and on its exact cases.
 *
 * Every case also checks that the arguments are unchanged and that the live-object count
 * (_sea_live, rt_mem.s) is back to its value at the start of the case once its results and
 * handles are freed (a handle counts as one object, L-is).
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
void *sea_lu(void *a, int64_t site);
void *sea_chol(void *a, int64_t site);
void *sea_lu_solve(void *f, void *b, int64_t site);
void *sea_chol_solve(void *f, void *b, int64_t site);
void *sea_solve(void *a, void *b, int64_t site);
double sea_rcond(void *f, int64_t site);
void *sea_eig_sym(void *a, int64_t site);
void *sea_eig_sym_gen(void *k, void *m, int64_t site);
extern uint64_t sea_variant;
extern uint64_t sea_live; /* rt_mem.s: live arrays, strings and handles (private to the runtime) */

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
static uint64_t g_live0;   /* sea_live at the start of the current case */

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
    g_live0 = sea_live;
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
    if (sea_live != g_live0)
        failf("live-object count %llu after the case, %llu before (a leak or a double free)",
              (unsigned long long)sea_live, (unsigned long long)g_live0);
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

/* ==== Sub-phase 8c: factorizations, solves, rcond, eigenvalues ============================== */
#define EPS 0x1p-52 /* binary64's machine epsilon, 2^-52 */
#define LA_MAX_N 200 /* every order 1 .. LA_MAX_N for the factorizations and solves */
#define EIG_MAX_N 50 /* every order 0 .. EIG_MAX_N for the eigenvalues */
#define RC_MAX_N 80 /* identity and diagonal rcond orders 1 .. RC_MAX_N */

/* The handle layout (DESIGN.md 2.13.6 "Handles", L-is). It is private to the runtimes (no
 * contract name exists for these offsets), so they are written here from that paragraph:
 * SEA_OBJ_HDR + 48 bytes of fields (n at 16, ||A||_1 at 24, the first zero pivot at 32, the rest
 * zero), then at 64 the n x n factor column-major with ld n, then an Lu's n pivots as u32. */
#define LAH_N (SEA_OBJ_HDR + 0)
#define LAH_ANORM (SEA_OBJ_HDR + 8)
#define LAH_ZP (SEA_OBJ_HDR + 16)
#define LAH_REST (SEA_OBJ_HDR + 24)
#define LAH_F (SEA_OBJ_HDR + 48)

static uint64_t lah_n(const void *h) { return HDR_U64(h, LAH_N); }
static double lah_anorm(const void *h) { return double_of(HDR_U64(h, LAH_ANORM)); }
static int64_t lah_zp(const void *h) { return (int64_t)HDR_U64(h, LAH_ZP); }
static const double *lah_f(const void *h) { return (const double *)((const char *)h + LAH_F); }
static const uint32_t *lah_piv(const void *h, uint64_t n) {
    return (const uint32_t *)((const char *)h + LAH_F + 8 * n * n);
}
static size_t lah_bytes(int tag, uint64_t n) {
    return LAH_F + 8 * n * n + (tag == SEA_TAG_LU ? 4 * n : 0);
}

static const uint64_t LA_MS[3] = {1, 7, 64}; /* the right-hand-side counts of 2.13.8 */

/* A value uniform in [-1, 1) with 52 random bits. */
static double rnd_unit(void) { return (double)(rng_next() >> 11) * 0x1p-52 - 1.0; }

/* arr_from: a fresh Sea array holding r x c column-major values (a vector when vec) */
static void *arr_from(const double *d, uint64_t r, uint64_t c, int vec) {
    void *p = vec ? new_vec(r) : new_mat(r, c);
    if (r && c) memcpy(ARR_DATA(p), d, r * c * sizeof *d);
    return p;
}

/* ---- Matrices -------------------------------------------------------------------------------- */
static void gen_general(double *a, uint64_t n) {
    for (uint64_t i = 0; i < n * n; i++) a[i] = rnd_unit();
}

/* symmetric, off-diagonal uniform in [-1, 1), diagonal n + 1 + u (u in [0, 1)): every row's
 * off-diagonal magnitudes sum to less than n - 1 < its diagonal, so A is positive definite with
 * every eigenvalue above 2 (Gershgorin) and ||A^-1||_2 < 1/2 */
static void gen_spd(double *a, uint64_t n) {
    for (uint64_t j = 0; j < n; j++) {
        for (uint64_t i = 0; i < j; i++) a[i + j * n] = a[j + i * n] = rnd_unit();
        a[j + j * n] = (double)(n + 1) + (rnd_unit() + 1.0) / 2;
    }
}

static void gen_rhs(double *b, uint64_t n, uint64_t m) {
    for (uint64_t i = 0; i < n * m; i++) b[i] = rnd_unit();
}

/* ---- Checks ---------------------------------------------------------------------------------- */
/* dlange's 1-norm as 2.13.6 "LU" states it: s_j in row order, the larger or a NaN wins */
static double ref_anorm1(const double *a, uint64_t n) {
    double nm = 0.0;
    for (uint64_t j = 0; j < n; j++) {
        double s = fabs(a[j * n]);
        for (uint64_t i = 1; i < n; i++) s = s + fabs(a[i + j * n]);
        if (j == 0 || s > nm || isnan(s)) nm = s;
    }
    return nm;
}

/* check_handle: a new handle (count 1) of this tag and order, the reserved fields zero, a Chol's
 * zero-pivot field -1 and its strict lower triangle +0 (an Lu's zero pivot is the caller's) */
static int check_handle(const void *h, int tag, uint64_t n) {
    if (!h) {
        failf("null handle");
        return 0;
    }
    int ok = 1;
    if (HDR_U64(h, SEA_OBJ_RC) != 1) { failf("handle count %llu, expected 1", (unsigned long long)HDR_U64(h, SEA_OBJ_RC)); ok = 0; }
    if (HDR_U8(h, SEA_OBJ_TAG) != tag) { failf("handle tag %u, expected %d", HDR_U8(h, SEA_OBJ_TAG), tag); ok = 0; }
    if (lah_n(h) != n) { failf("handle order %llu, expected %llu", (unsigned long long)lah_n(h), (unsigned long long)n); return 0; }
    for (int off = LAH_REST; off < LAH_F; off += 8)
        if (HDR_U64(h, off) != 0) { failf("handle field at %d is %016llx, expected 0", off, (unsigned long long)HDR_U64(h, off)); ok = 0; }
    if (tag == SEA_TAG_CHOL) {
        if (lah_zp(h) != -1) { failf("Chol zero-pivot field %lld, expected -1", (long long)lah_zp(h)); ok = 0; }
        const double *f = lah_f(h);
        for (uint64_t j = 0; j < n; j++)
            for (uint64_t i = j + 1; i < n; i++)
                if (bits_of(f[i + j * n]) != 0) {
                    failf("Chol R[%llu,%llu] below the diagonal is %016llx, expected +0", (unsigned long long)i,
                          (unsigned long long)j, (unsigned long long)bits_of(f[i + j * n]));
                    return 0;
                }
    }
    return ok;
}

/* same_handle: two handles made from the same input are identical after the common header */
static void same_handle(const char *what, const void *h1, const void *h2, int tag, uint64_t n) {
    if (memcmp((const char *)h1 + SEA_OBJ_HDR, (const char *)h2 + SEA_OBJ_HDR, lah_bytes(tag, n) - SEA_OBJ_HDR) != 0)
        failf("%s: the two handles differ", what);
}

/* check_lu_fields: an Lu of an input with no zero pivot: ||A||_1 bit for bit (dlange's rule),
 * no zero pivot recorded, every interchange piv[k] in [k, n) */
static void check_lu_fields(const void *h, const double *a, uint64_t n) {
    double want = ref_anorm1(a, n);
    if (!same_class_e(want, lah_anorm(h)))
        failf("||A||_1 field %016llx, expected %016llx", (unsigned long long)bits_of(lah_anorm(h)),
              (unsigned long long)bits_of(want));
    if (lah_zp(h) != -1) failf("zero pivot %lld recorded, expected none", (long long)lah_zp(h));
    const uint32_t *piv = lah_piv(h, n);
    for (uint64_t k = 0; k < n; k++)
        if (piv[k] < k || piv[k] >= n) {
            failf("piv[%llu] = %u, outside [%llu, %llu)", (unsigned long long)k, piv[k], (unsigned long long)k,
                  (unsigned long long)n);
            return;
        }
}

/* same_data: two results of the same call (or of two paths 2.13.6 makes equal) are identical */
static void same_data(const char *what, const void *p, const void *q, uint64_t count) {
    const double *pd = ARR_DATA(p), *qd = ARR_DATA(q);
    for (uint64_t i = 0; i < count; i++)
        if (bits_of(pd[i]) != bits_of(qd[i])) {
            failf("%s: element %llu is %016llx, then %016llx", what, (unsigned long long)i,
                  (unsigned long long)bits_of(pd[i]), (unsigned long long)bits_of(qd[i]));
            return;
        }
}

/* check_bwd: the backward-error rule of 2.13.8 for every column of X (A n x n, X and B n x m) */
static void check_bwd(const char *what, const double *a, uint64_t n, const double *x, const double *b, uint64_t m) {
    double anorm = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        double s = 0.0;
        for (uint64_t j = 0; j < n; j++) s += fabs(a[i + j * n]);
        if (s > anorm) anorm = s;
    }
    double *r = xmalloc(n * sizeof *r);
    for (uint64_t c = 0; c < m; c++) {
        const double *xc = x + c * n, *bc = b + c * n;
        double xmax = 0.0, bmax = 0.0, rmax = 0.0;
        for (uint64_t i = 0; i < n; i++) {
            r[i] = bc[i];
            if (!(fabs(xc[i]) <= xmax)) xmax = fabs(xc[i]); /* a NaN propagates into xmax */
            if (fabs(bc[i]) > bmax) bmax = fabs(bc[i]);
        }
        for (uint64_t j = 0; j < n; j++) {
            double xj = xc[j];
            const double *aj = a + j * n;
            for (uint64_t i = 0; i < n; i++) r[i] -= aj[i] * xj;
        }
        for (uint64_t i = 0; i < n; i++)
            if (!(fabs(r[i]) <= rmax)) rmax = fabs(r[i]);
        double bound = 64.0 * (double)n * EPS * (anorm * xmax + bmax);
        if (!(rmax <= bound)) {
            failf("%s: column %llu residual %.3e exceeds 64 n eps (|A| |x| + |b|) = %.3e", what,
                  (unsigned long long)c, rmax, bound);
            break;
        }
    }
    free(r);
}

/* ---- RCOND, transcribed from DESIGN.md 2.13.6 "RCOND" (with the user's guard of 8c) --------- */
/* x <- U^-1 L^-1 x: L forward (unit), then U backward; f column-major with ld n */
static void rc_s1(const double *f, uint64_t n, double *x) {
    for (uint64_t k = 0; k < n; k++)
        for (uint64_t i = k + 1; i < n; i++) x[i] = x[i] - f[i + k * n] * x[k];
    for (uint64_t k = n; k-- > 0;) {
        x[k] = x[k] / f[k + k * n];
        for (uint64_t i = 0; i < k; i++) x[i] = x[i] - f[i + k * n] * x[k];
    }
}

/* x <- L^-T U^-T x: U' forward, then L' backward (unit), the subtractions in index order */
static void rc_s2(const double *f, uint64_t n, double *x) {
    for (uint64_t k = 0; k < n; k++) {
        double s = x[k];
        for (uint64_t i = 0; i < k; i++) s = s - f[i + k * n] * x[i];
        x[k] = s / f[k + k * n];
    }
    for (uint64_t k = n; k-- > 0;) {
        double s = x[k];
        for (uint64_t i = k + 1; i < n; i++) s = s - f[i + k * n] * x[i];
        x[k] = s;
    }
}

/* sum |x| in index order, from +0 */
static double rc_asum(const double *x, uint64_t n) {
    double s = 0.0;
    for (uint64_t i = 0; i < n; i++) s = s + fabs(x[i]);
    return s;
}

/* sgn: +1 for v >= 0 (so -0 gives +1), else -1 (so NaN gives -1): dlacn2's
 * `IF( X(I).GE.ZERO ) THEN X(I) = ONE ELSE X(I) = -ONE` */
static double rc_sgn(double v) { return v >= 0.0 ? 1.0 : -1.0; }

/* the first index of largest |x[i]| (idamax: start at 0, move only to a strictly greater one) */
static uint64_t rc_imax(const double *x, uint64_t n) {
    uint64_t j = 0;
    double m = fabs(x[0]);
    for (uint64_t i = 1; i < n; i++)
        if (fabs(x[i]) > m) {
            m = fabs(x[i]);
            j = i;
        }
    return j;
}

/* ref_rcond: 2.13.6's steps on the handle's own n, ||A||_1, zero pivot and factor. The guard (the
 * user's decision of 8c): after every solve of steps 1-3, s = sum |x| in index order; s = +Inf or
 * NaN gives 0 at once. Step 4: 0 when est is +Inf, NaN or 0, else (1 / est) / ||A||_1. */
static double ref_rcond(const void *h) {
    uint64_t n = lah_n(h);
    double anorm = lah_anorm(h);
    if (n == 0) return INFINITY;
    if (isnan(anorm)) return NAN;
    if (lah_zp(h) >= 0) return 0.0;
    if (anorm == 0.0 || anorm == INFINITY) return 0.0;
    const double *f = lah_f(h);
    double *x = xmalloc(n * sizeof *x), *xi = xmalloc(n * sizeof *xi);
    double est, estold, s, res;
    uint64_t j, jlast;
    int iter;
    /* 1. */
    double v = 1.0 / (double)n;
    for (uint64_t i = 0; i < n; i++) x[i] = v;
    rc_s1(f, n, x);
    s = rc_asum(x, n);
    if (!(s < INFINITY)) goto guard;
    est = s; /* for n = 1, |x[0]| */
    if (n == 1) goto step4;
    for (uint64_t i = 0; i < n; i++) x[i] = xi[i] = rc_sgn(x[i]);
    rc_s2(f, n, x);
    if (!(rc_asum(x, n) < INFINITY)) goto guard;
    j = rc_imax(x, n);
    iter = 2;
step2:
    /* 2. */
    for (uint64_t i = 0; i < n; i++) x[i] = 0.0;
    x[j] = 1.0;
    rc_s1(f, n, x);
    estold = est;
    s = rc_asum(x, n);
    if (!(s < INFINITY)) goto guard;
    est = s;
    {
        int same = 1;
        for (uint64_t i = 0; i < n; i++)
            if (rc_sgn(x[i]) != xi[i]) {
                same = 0;
                break;
            }
        if (same) goto step3;
    }
    if (est <= estold) goto step3;
    for (uint64_t i = 0; i < n; i++) x[i] = xi[i] = rc_sgn(x[i]);
    rc_s2(f, n, x);
    if (!(rc_asum(x, n) < INFINITY)) goto guard;
    jlast = j;
    j = rc_imax(x, n);
    if (x[jlast] != fabs(x[j]) && iter < SEA_RCOND_ITMAX) {
        iter = iter + 1;
        goto step2;
    }
step3:
    /* 3. */
    for (uint64_t i = 0; i < n; i++) {
        double t = 1.0 + (double)i / (double)(n - 1);
        x[i] = (i & 1) ? -t : t;
    }
    rc_s1(f, n, x);
    s = rc_asum(x, n);
    if (!(s < INFINITY)) goto guard;
    {
        double t = 2.0 * (s / (double)(3 * n));
        if (t > est) est = t;
    }
step4:
    /* 4. */
    if (isnan(est) || est == INFINITY || est == 0.0) res = 0.0;
    else res = (1.0 / est) / anorm;
    free(x);
    free(xi);
    return res;
guard:
    free(x);
    free(xi);
    return 0.0;
}

/* check_rcond: sea_rcond(F) twice, both bit for bit equal to ref_rcond(F) (NaN-ness for a NaN);
 * returns the runtime's value */
static double check_rcond(void *h) {
    double want = ref_rcond(h);
    double got = sea_rcond(h, SITE), again = sea_rcond(h, SITE);
    if (!same_class_e(want, got))
        failf("rcond %016llx (%.17g), transcription %016llx (%.17g)", (unsigned long long)bits_of(got), got,
              (unsigned long long)bits_of(want), want);
    if (bits_of(got) != bits_of(again))
        failf("rcond twice: %016llx then %016llx", (unsigned long long)bits_of(got), (unsigned long long)bits_of(again));
    return got;
}

/* ---- Across variants ------------------------------------------------------------------------- */
/* The first variant run records the results named here; every later one must give the same bits
 * (NaN-ness for a NaN). Every variant runs the same case sequence with the same seeds. */
static uint64_t *g_xv;
static size_t g_xv_len, g_xv_cap, g_xv_pos;
static int g_xv_have; /* a variant has recorded */

static void xv_bits(const char *what, const double *p, uint64_t n) {
    if (!g_xv_have) {
        if (g_xv_len + n > g_xv_cap) {
            size_t cap = g_xv_cap ? g_xv_cap : 4096;
            while (cap < g_xv_len + n) cap *= 2;
            uint64_t *nb = realloc(g_xv, cap * sizeof *nb);
            if (!nb) {
                fprintf(stderr, "la_check: out of memory\n");
                exit(2);
            }
            g_xv = nb;
            g_xv_cap = cap;
        }
        for (uint64_t i = 0; i < n; i++) g_xv[g_xv_len++] = bits_of(p[i]);
        return;
    }
    if (g_xv_pos + n > g_xv_len) {
        failf("%s: more recorded results than under the first variant", what);
        return;
    }
    for (uint64_t i = 0; i < n; i++)
        if (!same_class_e(double_of(g_xv[g_xv_pos + i]), p[i])) {
            failf("%s: element %llu is %016llx, %016llx under the first variant", what, (unsigned long long)i,
                  (unsigned long long)bits_of(p[i]), (unsigned long long)g_xv[g_xv_pos + i]);
            break;
        }
    g_xv_pos += n;
}

/* ---- LU, LU_SOLVE, SOLVE on a general matrix ------------------------------------------------- */
static void run_lu_general(uint64_t n, uint64_t seed) {
    begin_case("lu general n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a);
    gen_general(a, n);
    /* a 1 x 1 matrix is symmetric: a negative element keeps SOLVE on its LU path (Decision 123) */
    if (n == 1) a[0] = -fabs(a[0]) - 0.25;
    void *A = arr_from(a, n, n, 0);
    uint64_t *sa = snapshot(a, n * n);
    void *F = sea_lu(A, SITE), *F2 = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n) && check_handle(F2, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        same_handle("lu twice", F, F2, SEA_TAG_LU, n);
        check_rcond(F);
        for (int t = 0; t < 3; t++) {
            uint64_t m = LA_MS[t];
            double *b = xmalloc(n * m * sizeof *b);
            gen_rhs(b, n, m);
            void *B = arr_from(b, n, m, m == 1);
            uint64_t *sb = snapshot(b, n * m);
            void *X = sea_lu_solve(F, B, SITE), *X2 = sea_lu_solve(F, B, SITE);
            if (check_header(X, m == 1 ? 1 : 2, n, m) && check_header(X2, m == 1 ? 1 : 2, n, m)) {
                same_data("lu_solve twice", X, X2, n * m);
                check_bwd("lu_solve", a, n, ARR_DATA(X), b, m);
                if (m == LA_MS[n % 3]) { /* SOLVE's general path, m cycling with n */
                    void *S = sea_solve(A, B, SITE);
                    if (check_header(S, m == 1 ? 1 : 2, n, m)) same_data("solve (general) vs lu_solve(lu)", S, X, n * m);
                    if (S) sea_free(S);
                }
            }
            unchanged("B", b, sb, n * m);
            if (X) sea_free(X);
            if (X2) sea_free(X2);
            sea_free(B);
            free(b);
            free(sb);
        }
    }
    unchanged("A", a, sa, n * n);
    if (F) sea_free(F);
    if (F2) sea_free(F2);
    sea_free(A);
    free(a);
    free(sa);
    end_case();
}

/* ---- CHOL, CHOL_SOLVE, SOLVE's Cholesky path -------------------------------------------------- */
static void run_chol(uint64_t n, uint64_t seed) {
    begin_case("chol n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a), *au = xmalloc(n * n * sizeof *au);
    gen_spd(a, n);
    /* the same upper triangle with NaN below the diagonal: CHOL reads only the upper (L-im) */
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) au[i + j * n] = i > j ? NAN : a[i + j * n];
    void *A = arr_from(a, n, n, 0), *AU = arr_from(au, n, n, 0);
    uint64_t *sa = snapshot(a, n * n);
    void *C = sea_chol(A, SITE), *C2 = sea_chol(A, SITE), *CU = sea_chol(AU, SITE);
    if (check_handle(C, SEA_TAG_CHOL, n) && check_handle(C2, SEA_TAG_CHOL, n) && check_handle(CU, SEA_TAG_CHOL, n)) {
        same_handle("chol twice", C, C2, SEA_TAG_CHOL, n);
        same_handle("chol of the upper triangle only", C, CU, SEA_TAG_CHOL, n);
        for (int t = 0; t < 3; t++) {
            uint64_t m = LA_MS[t];
            double *b = xmalloc(n * m * sizeof *b);
            gen_rhs(b, n, m);
            void *B = arr_from(b, n, m, m == 1);
            uint64_t *sb = snapshot(b, n * m);
            void *X = sea_chol_solve(C, B, SITE), *X2 = sea_chol_solve(C, B, SITE);
            if (check_header(X, m == 1 ? 1 : 2, n, m) && check_header(X2, m == 1 ? 1 : 2, n, m)) {
                same_data("chol_solve twice", X, X2, n * m);
                check_bwd("chol_solve", a, n, ARR_DATA(X), b, m);
                if (m == LA_MS[n % 3]) { /* SOLVE's Cholesky path */
                    void *S = sea_solve(A, B, SITE);
                    if (check_header(S, m == 1 ? 1 : 2, n, m)) same_data("solve (Cholesky) vs chol_solve(chol)", S, X, n * m);
                    if (S) sea_free(S);
                }
            }
            unchanged("B", b, sb, n * m);
            if (X) sea_free(X);
            if (X2) sea_free(X2);
            sea_free(B);
            free(b);
            free(sb);
        }
    }
    unchanged("A", a, sa, n * n);
    if (C) sea_free(C);
    if (C2) sea_free(C2);
    if (CU) sea_free(CU);
    sea_free(A);
    sea_free(AU);
    free(a);
    free(au);
    free(sa);
    end_case();
}

/* ---- SOLVE's LU paths on symmetric matrices --------------------------------------------------- */
enum { PATH_NEGDIAG, PATH_EARLY, PATH_LATE };
static const char *const PATH_NAME[] = {"negative diagonal", "Cholesky fails early", "Cholesky fails late"};

/* From gen_spd's A (diagonal > n + 1, off-diagonal magnitudes < 1):
 *   negdiag: A[n-1,n-1] = -1, so SOLVE goes to LU without a Cholesky attempt;
 *   early:   A[1,1] = 1e-3 and A[0,1] = A[1,0] = 2n + 10: the pivot of row 1 is 1e-3 - (2n + 10)^2 /
 *            A[0,0] < 0 (A[0,0] < n + 2), so the Cholesky attempt fails at pivot 1;
 *   late:    A[n-1,n-1] = 1e-3 and A[0,n-1] = A[n-1,0] = 2n + 10: the last pivot is 1e-3 - v'B^-1 v
 *            with B the leading block (positive definite, largest eigenvalue < 2n + 2 by
 *            Gershgorin) and |v| >= 2n + 10, so v'B^-1 v > (2n + 10)^2 / (2n + 2) > 1e-3 and the
 *            attempt fails at the last pivot, after every earlier panel.
 * Each keeps a symmetric matrix with a positive diagonal in the two failing forms (n >= 2). */
static void run_lu_path(uint64_t n, int path, uint64_t seed) {
    begin_case("solve %s n=%llu", PATH_NAME[path], (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a);
    gen_spd(a, n);
    double big = (double)(2 * n + 10);
    if (path == PATH_NEGDIAG) {
        a[(n - 1) + (n - 1) * n] = -1.0;
    } else {
        uint64_t q = path == PATH_EARLY ? 1 : n - 1;
        a[q + q * n] = 1e-3;
        a[0 + q * n] = a[q + 0 * n] = big;
    }
    uint64_t m = LA_MS[n % 3];
    double *b = xmalloc(n * m * sizeof *b);
    gen_rhs(b, n, m);
    void *A = arr_from(a, n, n, 0), *B = arr_from(b, n, m, m == 1);
    uint64_t *sa = snapshot(a, n * n), *sb = snapshot(b, n * m);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        check_rcond(F);
        void *X = sea_lu_solve(F, B, SITE);
        void *S = sea_solve(A, B, SITE), *S2 = sea_solve(A, B, SITE);
        if (check_header(X, m == 1 ? 1 : 2, n, m) && check_header(S, m == 1 ? 1 : 2, n, m) &&
            check_header(S2, m == 1 ? 1 : 2, n, m)) {
            check_bwd("lu_solve", a, n, ARR_DATA(X), b, m);
            same_data("solve twice", S, S2, n * m);
            same_data("solve (LU path) vs lu_solve(lu)", S, X, n * m);
        }
        if (X) sea_free(X);
        if (S) sea_free(S);
        if (S2) sea_free(S2);
    }
    unchanged("A", a, sa, n * n);
    unchanged("B", b, sb, n * m);
    if (F) sea_free(F);
    sea_free(A);
    sea_free(B);
    free(a);
    free(b);
    free(sa);
    free(sb);
    end_case();
}

/* ---- Exact LU: A = P L U ------------------------------------------------------------------------ */
/* L unit lower with entries in {0, +-1/2, +-1/4}, U upper with integers in [-4, 4] above a
 * diagonal of +-2^e (e in 0 .. 3), A[p[i], :] = (L U)[i, :] for a random permutation p, B = A X
 * for an integer X in [-8, 8]. Every value met is a multiple of 1/4 below 2^20 in magnitude (|L U|
 * <= n * 1/2 * 8, the partial sums alike), so each elimination step, partial sum, multiplier
 * (l u / u = l) and solve step is exact in every order and variant, with or without FMA. At step k
 * the candidates of the pivot column are L[i,k] U[k,k] for the unpivoted rows of L U, with |L[i,k]|
 * <= 1/2 < 1 = L[k,k], so the pivot is the row holding (L U)[k, :] and nothing else. */
static void run_lu_exact(uint64_t n, uint64_t seed) {
    static const double LVAL[5] = {0.0, 0.5, -0.5, 0.25, -0.25};
    begin_case("lu exact n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *l = xmalloc(n * n * sizeof *l), *u = xmalloc(n * n * sizeof *u), *a = xmalloc(n * n * sizeof *a);
    uint64_t *p = xmalloc(n * sizeof *p), *cur = xmalloc(n * sizeof *cur);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) {
            l[i + j * n] = i > j ? LVAL[(rng_next() >> 33) % 5] : (i == j ? 1.0 : 0.0);
            if (i < j) u[i + j * n] = rnd_int(-4, 4);
            else if (i == j) u[i + j * n] = ldexp((rng_next() >> 63) ? -1.0 : 1.0, (int)((rng_next() >> 33) % 4));
            else u[i + j * n] = 0.0;
        }
    for (uint64_t i = 0; i < n; i++) p[i] = i;
    for (uint64_t i = n; i > 1; i--) { /* Fisher-Yates */
        uint64_t k = (rng_next() >> 33) % i, t = p[i - 1];
        p[i - 1] = p[k];
        p[k] = t;
    }
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) {
            double s = 0.0;
            for (uint64_t k = 0; k <= i && k <= j; k++) s += l[i + k * n] * u[k + j * n];
            a[p[i] + j * n] = s;
        }
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        const double *f = lah_f(F);
        int bad = 0;
        for (uint64_t j = 0; j < n && !bad; j++)
            for (uint64_t i = 0; i < n; i++) {
                double want = i > j ? l[i + j * n] : u[i + j * n];
                /* by value: an exact zero's sign depends on the order (class R) */
                if (!(f[i + j * n] == want)) {
                    failf("F[%llu,%llu] = %.17g, expected %.17g", (unsigned long long)i, (unsigned long long)j,
                          f[i + j * n], want);
                    bad = 1;
                    break;
                }
            }
        /* the interchanges P implies: cur[q] is the row of L U at position q */
        for (uint64_t i = 0; i < n; i++) cur[p[i]] = i;
        const uint32_t *piv = lah_piv(F, n);
        for (uint64_t k = 0; k < n; k++) {
            uint64_t q = k;
            while (cur[q] != k) q++;
            if (piv[k] != q) {
                failf("piv[%llu] = %u, expected %llu", (unsigned long long)k, piv[k], (unsigned long long)q);
                break;
            }
            uint64_t t = cur[k];
            cur[k] = cur[q];
            cur[q] = t;
        }
        check_rcond(F);
        for (int t = 0; t < 2; t++) {
            uint64_t m = t ? 7 : 1;
            double *x = xmalloc(n * m * sizeof *x), *b = xmalloc(n * m * sizeof *b);
            for (uint64_t i = 0; i < n * m; i++) x[i] = rnd_int(-8, 8);
            for (uint64_t c = 0; c < m; c++)
                for (uint64_t i = 0; i < n; i++) {
                    double s = 0.0;
                    for (uint64_t j = 0; j < n; j++) s += a[i + j * n] * x[j + c * n];
                    b[i + c * n] = s;
                }
            void *B = arr_from(b, n, m, m == 1);
            void *X = sea_lu_solve(F, B, SITE);
            if (check_header(X, m == 1 ? 1 : 2, n, m)) {
                const double *xd = ARR_DATA(X);
                for (uint64_t i = 0; i < n * m; i++)
                    if (!(xd[i] == x[i])) {
                        failf("m=%llu: x[%llu] = %.17g, expected %.17g", (unsigned long long)m, (unsigned long long)i,
                              xd[i], x[i]);
                        break;
                    }
            }
            if (X) sea_free(X);
            sea_free(B);
            free(x);
            free(b);
        }
        sea_free(F);
    }
    sea_free(A);
    free(l);
    free(u);
    free(a);
    free(p);
    free(cur);
    end_case();
}

/* ---- Exact CHOL: A = R'R ------------------------------------------------------------------------ */
/* R upper with integers in [-2, 2] above a diagonal of 2^e (e in 0 .. 2), B = A X for an integer
 * X in [-8, 8]: every partial sum is an integer below 2^24 in magnitude, every pivot R[j,j]^2 a
 * power of four (its square root exact) and every division by R[j,j] exact, in every order. */
static void run_chol_exact(uint64_t n, uint64_t seed) {
    begin_case("chol exact n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *r = xmalloc(n * n * sizeof *r), *a = xmalloc(n * n * sizeof *a);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++)
            r[i + j * n] = i < j ? rnd_int(-2, 2) : (i == j ? ldexp(1.0, (int)((rng_next() >> 33) % 3)) : 0.0);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) {
            double s = 0.0;
            for (uint64_t k = 0; k <= i && k <= j; k++) s += r[k + i * n] * r[k + j * n];
            a[i + j * n] = s;
        }
    void *A = arr_from(a, n, n, 0);
    void *C = sea_chol(A, SITE);
    if (check_handle(C, SEA_TAG_CHOL, n)) {
        const double *f = lah_f(C);
        for (uint64_t j = 0; j < n; j++)
            for (uint64_t i = 0; i <= j; i++)
                if (!(f[i + j * n] == r[i + j * n])) {
                    failf("R[%llu,%llu] = %.17g, expected %.17g", (unsigned long long)i, (unsigned long long)j,
                          f[i + j * n], r[i + j * n]);
                    j = n;
                    break;
                }
        for (int t = 0; t < 2; t++) {
            uint64_t m = t ? 7 : 1;
            double *x = xmalloc(n * m * sizeof *x), *b = xmalloc(n * m * sizeof *b);
            for (uint64_t i = 0; i < n * m; i++) x[i] = rnd_int(-8, 8);
            for (uint64_t c = 0; c < m; c++)
                for (uint64_t i = 0; i < n; i++) {
                    double s = 0.0;
                    for (uint64_t j = 0; j < n; j++) s += a[i + j * n] * x[j + c * n];
                    b[i + c * n] = s;
                }
            void *B = arr_from(b, n, m, m == 1);
            void *X = sea_chol_solve(C, B, SITE), *S = sea_solve(A, B, SITE);
            if (check_header(X, m == 1 ? 1 : 2, n, m) && check_header(S, m == 1 ? 1 : 2, n, m)) {
                const double *xd = ARR_DATA(X);
                for (uint64_t i = 0; i < n * m; i++)
                    if (!(xd[i] == x[i])) {
                        failf("m=%llu: x[%llu] = %.17g, expected %.17g", (unsigned long long)m, (unsigned long long)i,
                              xd[i], x[i]);
                        break;
                    }
                same_data("solve (Cholesky) vs chol_solve(chol)", S, X, n * m);
            }
            if (X) sea_free(X);
            if (S) sea_free(S);
            sea_free(B);
            free(x);
            free(b);
        }
        sea_free(C);
    }
    sea_free(A);
    free(r);
    free(a);
    end_case();
}

/* ---- Empty orders and right-hand sides (L-ik) ------------------------------------------------- */
static void run_la_empty(void) {
    begin_case("empty orders and right-hand sides");
    void *A0 = new_mat(0, 0), *b0 = new_vec(0), *B03 = new_mat(0, 3);
    void *F0 = sea_lu(A0, SITE), *C0 = sea_chol(A0, SITE);
    if (check_handle(F0, SEA_TAG_LU, 0) && check_handle(C0, SEA_TAG_CHOL, 0)) {
        if (lah_zp(F0) != -1) failf("lu of 0x0: zero pivot %lld", (long long)lah_zp(F0));
        if (bits_of(lah_anorm(F0)) != 0) failf("lu of 0x0: ||A||_1 %016llx, expected +0", (unsigned long long)bits_of(lah_anorm(F0)));
        double rc = check_rcond(F0);
        if (!(rc == INFINITY)) failf("rcond of order 0 is %.17g, expected Inf", rc);
        void *r1 = sea_lu_solve(F0, b0, SITE), *r2 = sea_lu_solve(F0, B03, SITE);
        void *r3 = sea_chol_solve(C0, b0, SITE), *r4 = sea_solve(A0, B03, SITE), *r5 = sea_solve(A0, b0, SITE);
        check_header(r1, 1, 0, 1);
        check_header(r2, 2, 0, 3);
        check_header(r3, 1, 0, 1);
        check_header(r4, 2, 0, 3);
        check_header(r5, 1, 0, 1);
        void *rs[5] = {r1, r2, r3, r4, r5};
        for (int i = 0; i < 5; i++)
            if (rs[i]) sea_free(rs[i]);
    }
    if (F0) sea_free(F0);
    if (C0) sea_free(C0);
    /* m = 0: a B with no column gives the n x 0 result after the checks */
    static const double A2[4] = {4.0, 1.0, 1.0, 3.0};
    void *A = arr_from(A2, 2, 2, 0), *B20 = new_mat(2, 0);
    void *F = sea_lu(A, SITE), *C = sea_chol(A, SITE);
    if (check_handle(F, SEA_TAG_LU, 2) && check_handle(C, SEA_TAG_CHOL, 2)) {
        void *r1 = sea_lu_solve(F, B20, SITE), *r2 = sea_chol_solve(C, B20, SITE), *r3 = sea_solve(A, B20, SITE);
        check_header(r1, 2, 2, 0);
        check_header(r2, 2, 2, 0);
        check_header(r3, 2, 2, 0);
        if (r1) sea_free(r1);
        if (r2) sea_free(r2);
        if (r3) sea_free(r3);
    }
    if (F) sea_free(F);
    if (C) sea_free(C);
    sea_free(A);
    sea_free(B20);
    sea_free(A0);
    sea_free(b0);
    sea_free(B03);
    end_case();
}

/* ---- RCOND: special values, identity, exact estimates ------------------------------------------ */
/* one Lu of a given n x n matrix, its zero-pivot field, and rcond against the transcription and
 * the value the spec gives (want_nan: NaN expected) */
static void run_rcond_value(const char *label, const double *a, uint64_t n, int64_t want_zp, double want, int want_nan) {
    begin_case("rcond %s", label);
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        if (lah_zp(F) != want_zp) failf("zero pivot %lld, expected %lld", (long long)lah_zp(F), (long long)want_zp);
        double got = check_rcond(F);
        if (want_nan ? !isnan(got) : bits_of(got) != bits_of(want))
            failf("rcond %.17g, expected %.17g", got, want_nan ? NAN : want);
        sea_free(F);
    }
    sea_free(A);
    end_case();
}

static void run_rcond_specials(void) {
    static const double NANZP[4] = {0.0, NAN, 1.0, 1.0};      /* [0, 1; NaN, 1]: NaN, before the zero pivot */
    static const double SINGM[4] = {1.0, 2.0, 2.0, 4.0};       /* [1, 2; 2, 4]: zero pivot at 1 */
    static const double ZERO[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0}; /* ||A||_1 = 0 and a zero pivot at 0 */
    static const double INFN[4] = {INFINITY, 0.0, 0.0, 1.0};  /* ||A||_1 = +Inf, no zero pivot */
    double tiny[4] = {1.0, 0.0, 0.0, ldexp(1.0, -1070)};      /* the L^-T U^-T solve overflows */
    run_rcond_value("[0, 1; NaN, 1]", NANZP, 2, 0, 0.0, 1);
    run_rcond_value("[1, 2; 2, 4]", SINGM, 2, 1, 0.0, 0);
    run_rcond_value("zeros(3, 3)", ZERO, 3, 0, 0.0, 0);
    run_rcond_value("[Inf, 0; 0, 1]", INFN, 2, -1, 0.0, 0);
    run_rcond_value("diag(1, 2^-1070)", tiny, 2, -1, 0.0, 0);
}

/* the result is within 4 n eps of the true value exact (the estimate finds ||A^-1||_1; only step
 * 3's rounded t can exceed it, by a few ulps) */
static void check_rcond_near(double got, double exact, uint64_t n) {
    if (!(fabs(got - exact) <= 4.0 * (double)n * EPS * exact))
        failf("rcond %.17g, the exact value %.17g (not within 4 n eps)", got, exact);
}

static void run_rcond_identity(uint64_t n) {
    begin_case("rcond identity n=%llu", (unsigned long long)n);
    double *a = xmalloc(n * n * sizeof *a);
    for (uint64_t i = 0; i < n * n; i++) a[i] = (i % (n + 1)) == 0 ? 1.0 : 0.0;
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        check_rcond_near(check_rcond(F), 1.0, n);
        sea_free(F);
    }
    sea_free(A);
    free(a);
    end_case();
}

/* diagonal, entries +-2^e (e in -4 .. 4): ||A^-1||_1 = 1/min|d|, ||A||_1 = max|d|, both powers of
 * two, so the exact rcond min|d| / max|d| is a power of two */
static void run_rcond_diag(uint64_t n, uint64_t seed) {
    begin_case("rcond diagonal n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a), dmin = INFINITY, dmax = 0.0;
    for (uint64_t i = 0; i < n * n; i++) a[i] = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        double d = ldexp((rng_next() >> 63) ? -1.0 : 1.0, (int)((rng_next() >> 33) % 9) - 4);
        a[i + i * n] = d;
        if (fabs(d) < dmin) dmin = fabs(d);
        if (fabs(d) > dmax) dmax = fabs(d);
    }
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        check_rcond_near(check_rcond(F), dmin / dmax, n);
        sea_free(F);
    }
    sea_free(A);
    free(a);
    end_case();
}

/* upper bidiagonal A = D - N: d_i in {1, 2}, A[i,i+1] = -n_i with n_i in {1/2, 1}. LU leaves it as
 * it is (no interchange: the column below the diagonal is zero), A^-1 >= 0 (A^-1[i,j] =
 * prod_{k=i}^{j-1} (n_k / d_k) / d_j, a power of two not below 2^-39 for n <= 20), so the first
 * L^-T U^-T solve returns A^-1's column sums, the estimate is the largest, exactly ||A^-1||_1
 * (every column sum here is exact: powers of two within 2^-39 .. 1), and rcond is (1 / ||A^-1||_1)
 * / ||A||_1 up to step 3's t. */
static void run_rcond_bidiag(uint64_t n, uint64_t seed) {
    begin_case("rcond bidiagonal n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a), *inv = xmalloc(n * n * sizeof *inv);
    for (uint64_t i = 0; i < n * n; i++) a[i] = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        a[i + i * n] = (rng_next() >> 63) ? 2.0 : 1.0;
        if (i + 1 < n) a[i + (i + 1) * n] = (rng_next() >> 63) ? -1.0 : -0.5;
    }
    double ninv = 0.0, anorm = 0.0;
    for (uint64_t j = 0; j < n; j++) {
        /* column j of A^-1 by back substitution, exact */
        for (uint64_t i = n; i-- > 0;) {
            double s = i == j ? 1.0 : 0.0;
            if (i + 1 < n) s -= a[i + (i + 1) * n] * inv[(i + 1) + j * n];
            inv[i + j * n] = s / a[i + i * n];
        }
        double cs = 0.0, as = 0.0;
        for (uint64_t i = 0; i < n; i++) {
            cs += inv[i + j * n];
            as += fabs(a[i + j * n]);
        }
        if (cs > ninv) ninv = cs;
        if (as > anorm) anorm = as;
    }
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        check_lu_fields(F, a, n);
        check_rcond_near(check_rcond(F), (1.0 / ninv) / anorm, n);
        sea_free(F);
    }
    sea_free(A);
    free(a);
    free(inv);
    end_case();
}

/* Matrices on which the estimator iterates, ties in |x| occur or exact zeros appear in its
 * iterates (the random sweep's well-conditioned matrices mostly stop after one step 2), each only
 * against the transcription:
 *   0  upper triangular, diagonal +-1, entries above it uniform in [-2, 2) (ill-conditioned);
 *   1  general with entries of mixed magnitude (rnd_inexact: 2^-6 .. 2^7, either sign);
 *   2  general with integer entries in [-2, 2] (exact iterates, ties, zeros; may be singular);
 *   3  upper triangular, 1 on the diagonal and -1 above it (||A^-1||_1 = 2^(n-1));
 *   4  sparse: integers in [-3, 3] in about one element in four, 1 on the diagonal. */
static void run_rcond_hard(uint64_t n, int kind, uint64_t seed) {
    begin_case("rcond kind %d n=%llu", kind, (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) {
            double v;
            switch (kind) {
            case 0: v = i < j ? 2.0 * rnd_unit() : (i == j ? ((rng_next() >> 63) ? -1.0 : 1.0) : 0.0); break;
            case 1: v = rnd_inexact(); break;
            case 2: v = rnd_int(-2, 2); break;
            case 3: v = i < j ? -1.0 : (i == j ? 1.0 : 0.0); break;
            default: v = i == j ? 1.0 : ((rng_next() >> 62) == 0 ? rnd_int(-3, 3) : 0.0); break;
            }
            a[i + j * n] = v;
        }
    void *A = arr_from(a, n, n, 0);
    void *F = sea_lu(A, SITE);
    if (check_handle(F, SEA_TAG_LU, n)) {
        double want = ref_anorm1(a, n);
        if (!same_class_e(want, lah_anorm(F)))
            failf("||A||_1 field %016llx, expected %016llx", (unsigned long long)bits_of(lah_anorm(F)),
                  (unsigned long long)bits_of(want));
        check_rcond(F);
        sea_free(F);
    }
    sea_free(A);
    free(a);
    end_case();
}

/* ---- Eigenvalues -------------------------------------------------------------------------------- */
/* ref_jacobi: the eigenvalues of the symmetric n x n matrix a (overwritten), ascending in w, by
 * cyclic Jacobi rotations (Rutishauser's formulas) until the off-diagonal norm is below
 * 1e-3 eps ||A||_F (at most 100 sweeps; it converges quadratically, in well under 20) */
static void ref_jacobi(double *a, uint64_t n, double *w) {
    double fro = 0.0;
    for (uint64_t i = 0; i < n * n; i++) fro += a[i] * a[i];
    fro = sqrt(fro);
    double thresh = 1e-3 * EPS * fro;
    for (int sweep = 0; sweep < 100; sweep++) {
        double off = 0.0;
        for (uint64_t q = 0; q < n; q++)
            for (uint64_t p = 0; p < q; p++) off += a[p + q * n] * a[p + q * n];
        if (sqrt(off) <= thresh) break;
        for (uint64_t q = 1; q < n; q++)
            for (uint64_t p = 0; p < q; p++) {
                double apq = a[p + q * n];
                if (apq == 0.0) continue;
                double app = a[p + p * n], aqq = a[q + q * n];
                double theta = (aqq - app) / (2.0 * apq), t;
                if (fabs(theta) > 1e150) t = 0.5 / theta;
                else t = (theta >= 0.0 ? 1.0 : -1.0) / (fabs(theta) + sqrt(theta * theta + 1.0));
                double c = 1.0 / sqrt(t * t + 1.0), s = t * c;
                for (uint64_t k = 0; k < n; k++) {
                    if (k == p || k == q) continue;
                    double akp = a[k + p * n], akq = a[k + q * n];
                    a[k + p * n] = a[p + k * n] = c * akp - s * akq;
                    a[k + q * n] = a[q + k * n] = s * akp + c * akq;
                }
                a[p + p * n] = app - t * apq;
                a[q + q * n] = aqq + t * apq;
                a[p + q * n] = a[q + p * n] = 0.0;
            }
    }
    for (uint64_t i = 0; i < n; i++) w[i] = a[i + i * n];
    for (uint64_t i = 1; i < n; i++) /* insertion sort, ascending */
        for (uint64_t k = i; k > 0 && w[k - 1] > w[k]; k--) {
            double t = w[k];
            w[k] = w[k - 1];
            w[k - 1] = t;
        }
}

static double fro_norm(const double *a, uint64_t n) {
    double s = 0.0;
    for (uint64_t i = 0; i < n * n; i++) s += a[i] * a[i];
    return sqrt(s);
}

/* check_eig: a vector of n values, twice identical, ascending; against w within tol (w NULL: no
 * reference); exact: bit for bit equal values (by ==) */
static void check_eig(const char *what, void *E, void *E2, uint64_t n, const double *w, double tol, int exact) {
    if (!check_header(E, 1, n, 1) || !check_header(E2, 1, n, 1)) return;
    same_data(what, E, E2, n);
    const double *e = ARR_DATA(E);
    for (uint64_t i = 1; i < n; i++)
        if (!(e[i - 1] <= e[i])) {
            failf("%s: not ascending at %llu: %.17g then %.17g", what, (unsigned long long)i, e[i - 1], e[i]);
            break;
        }
    if (!w) return;
    for (uint64_t i = 0; i < n; i++)
        if (exact ? !(e[i] == w[i]) : !(fabs(e[i] - w[i]) <= tol)) {
            failf("%s: value %llu is %.17g, reference %.17g (tolerance %.3e)", what, (unsigned long long)i, e[i], w[i],
                  exact ? 0.0 : tol);
            break;
        }
}

/* every value NaN (L-ip, L-iy) */
static void check_all_nan(const char *what, void *E, uint64_t n) {
    if (!check_header(E, 1, n, 1)) return;
    const double *e = ARR_DATA(E);
    for (uint64_t i = 0; i < n; i++)
        if (!isnan(e[i])) {
            failf("%s: value %llu is %.17g, expected NaN", what, (unsigned long long)i, e[i]);
            return;
        }
}

static void run_eig_sym(uint64_t n, uint64_t seed) {
    begin_case("eig_sym n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a), *ac = xmalloc(n * n * sizeof *ac), *w = xmalloc(n * sizeof *w);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i <= j; i++) a[i + j * n] = a[j + i * n] = rnd_unit();
    memcpy(ac, a, n * n * sizeof *a);
    ref_jacobi(ac, n, w);
    void *A = arr_from(a, n, n, 0);
    uint64_t *sa = snapshot(a, n * n);
    void *E = sea_eig_sym(A, SITE), *E2 = sea_eig_sym(A, SITE);
    check_eig("eig_sym", E, E2, n, w, 64.0 * (double)n * EPS * fro_norm(a, n), 0);
    if (E) xv_bits("eig_sym across variants", ARR_DATA(E), n);
    unchanged("A", a, sa, n * n);
    if (E) sea_free(E);
    if (E2) sea_free(E2);
    sea_free(A);
    free(a);
    free(ac);
    free(w);
    free(sa);
    end_case();
}

/* a diagonal matrix (integers in +-[1, 9], repeats allowed; some off-diagonal pairs +0 / -0,
 * symmetric by Decision 123): its diagonal sorted, exactly */
static void run_eig_sym_diag(uint64_t n, uint64_t seed) {
    begin_case("eig_sym diagonal n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *a = xmalloc(n * n * sizeof *a), *w = xmalloc(n * sizeof *w);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < n; i++) a[i + j * n] = (i > j && (rng_next() >> 63)) ? -0.0 : 0.0;
    for (uint64_t i = 0; i < n; i++) {
        double d = rnd_int(1, 9) * ((rng_next() >> 63) ? -1.0 : 1.0);
        a[i + i * n] = w[i] = d;
    }
    for (uint64_t i = 1; i < n; i++)
        for (uint64_t k = i; k > 0 && w[k - 1] > w[k]; k--) {
            double t = w[k];
            w[k] = w[k - 1];
            w[k - 1] = t;
        }
    void *A = arr_from(a, n, n, 0);
    void *E = sea_eig_sym(A, SITE), *E2 = sea_eig_sym(A, SITE);
    check_eig("eig_sym diagonal", E, E2, n, w, 0.0, 1);
    if (E) xv_bits("eig_sym diagonal across variants", ARR_DATA(E), n);
    if (E) sea_free(E);
    if (E2) sea_free(E2);
    sea_free(A);
    free(a);
    free(w);
    end_case();
}

static void run_eig_sym_nonfinite(void) {
    begin_case("eig_sym non-finite");
    static const double AINF[9] = {1, 2, 0, 2, INFINITY, 3, 0, 3, 1};
    static const double ANAN[9] = {1, 2, NAN, 2, 5, 3, NAN, 3, 1}; /* a symmetric NaN pair */
    void *A1 = arr_from(AINF, 3, 3, 0), *A2 = arr_from(ANAN, 3, 3, 0);
    void *E1 = sea_eig_sym(A1, SITE), *E2 = sea_eig_sym(A2, SITE);
    check_all_nan("eig_sym with Inf", E1, 3);
    check_all_nan("eig_sym with NaN", E2, 3);
    if (E1) sea_free(E1);
    if (E2) sea_free(E2);
    sea_free(A1);
    sea_free(A2);
    end_case();
}

/* ref_reduce: C = R^-T K R^-1 with R = chol(M) (unblocked, upper), then symmetrized */
static void ref_reduce(const double *k, const double *m, uint64_t n, double *c) {
    double *r = xmalloc(n * n * sizeof *r), *z = xmalloc(n * n * sizeof *z);
    for (uint64_t i = 0; i < n * n; i++) r[i] = 0.0;
    for (uint64_t j = 0; j < n; j++) {
        double d = m[j + j * n];
        for (uint64_t kk = 0; kk < j; kk++) d -= r[kk + j * n] * r[kk + j * n];
        r[j + j * n] = sqrt(d);
        for (uint64_t col = j + 1; col < n; col++) {
            double s = m[j + col * n];
            for (uint64_t kk = 0; kk < j; kk++) s -= r[kk + j * n] * r[kk + col * n];
            r[j + col * n] = s / r[j + j * n];
        }
    }
    for (uint64_t col = 0; col < n; col++) /* Z = R^-T K */
        for (uint64_t j = 0; j < n; j++) {
            double s = k[j + col * n];
            for (uint64_t kk = 0; kk < j; kk++) s -= r[kk + j * n] * z[kk + col * n];
            z[j + col * n] = s / r[j + j * n];
        }
    for (uint64_t row = 0; row < n; row++) /* C = Z R^-1 */
        for (uint64_t j = 0; j < n; j++) {
            double s = z[row + j * n];
            for (uint64_t kk = 0; kk < j; kk++) s -= r[kk + j * n] * c[row + kk * n];
            c[row + j * n] = s / r[j + j * n];
        }
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i < j; i++) c[i + j * n] = c[j + i * n] = (c[i + j * n] + c[j + i * n]) / 2;
    free(r);
    free(z);
}

static void run_eig_gen(uint64_t n, uint64_t seed) {
    begin_case("eig_sym_gen n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *k = xmalloc(n * n * sizeof *k), *m = xmalloc(n * n * sizeof *m), *c = xmalloc(n * n * sizeof *c);
    double *w = xmalloc(n * sizeof *w);
    for (uint64_t j = 0; j < n; j++)
        for (uint64_t i = 0; i <= j; i++) k[i + j * n] = k[j + i * n] = rnd_unit();
    gen_spd(m, n);
    ref_reduce(k, m, n, c);
    double tol = 64.0 * (double)n * EPS * sqrt((double)n + 1.0) * (fro_norm(c, n) + (n ? fro_norm(k, n) / (double)n : 0.0));
    ref_jacobi(c, n, w);
    void *K = arr_from(k, n, n, 0), *M = arr_from(m, n, n, 0);
    uint64_t *sk = snapshot(k, n * n), *sm = snapshot(m, n * n);
    void *E = sea_eig_sym_gen(K, M, SITE), *E2 = sea_eig_sym_gen(K, M, SITE);
    check_eig("eig_sym_gen", E, E2, n, w, tol, 0);
    if (E && n <= SEA_LA_NB) xv_bits("eig_sym_gen across variants", ARR_DATA(E), n);
    unchanged("K", k, sk, n * n);
    unchanged("M", m, sm, n * n);
    if (E) sea_free(E);
    if (E2) sea_free(E2);
    sea_free(K);
    sea_free(M);
    free(k);
    free(m);
    free(c);
    free(w);
    free(sk);
    free(sm);
    end_case();
}

/* diagonal K (integers in +-[1, 9]) and diagonal M = 4^e (e in -2 .. 2): R = 2^e, Z = K / R and
 * C = Z / R are exact, and the eigenvalues are the sorted K[i,i] / M[i,i], exactly */
static void run_eig_gen_exact(uint64_t n, uint64_t seed) {
    begin_case("eig_sym_gen exact n=%llu", (unsigned long long)n);
    rng_seed(seed);
    double *k = xmalloc(n * n * sizeof *k), *m = xmalloc(n * n * sizeof *m), *w = xmalloc(n * sizeof *w);
    for (uint64_t i = 0; i < n * n; i++) k[i] = m[i] = 0.0;
    for (uint64_t i = 0; i < n; i++) {
        k[i + i * n] = rnd_int(1, 9) * ((rng_next() >> 63) ? -1.0 : 1.0);
        m[i + i * n] = ldexp(1.0, 2 * ((int)((rng_next() >> 33) % 5) - 2));
        w[i] = k[i + i * n] / m[i + i * n];
    }
    for (uint64_t i = 1; i < n; i++)
        for (uint64_t q = i; q > 0 && w[q - 1] > w[q]; q--) {
            double t = w[q];
            w[q] = w[q - 1];
            w[q - 1] = t;
        }
    void *K = arr_from(k, n, n, 0), *M = arr_from(m, n, n, 0);
    void *E = sea_eig_sym_gen(K, M, SITE), *E2 = sea_eig_sym_gen(K, M, SITE);
    check_eig("eig_sym_gen exact", E, E2, n, w, 0.0, 1);
    if (E) xv_bits("eig_sym_gen exact across variants", ARR_DATA(E), n);
    if (E) sea_free(E);
    if (E2) sea_free(E2);
    sea_free(K);
    sea_free(M);
    free(k);
    free(m);
    free(w);
    end_case();
}

/* L-iy's three cases: +Inf on M's diagonal, NaN in K, and finite K and M whose reduction overflows */
static void run_eig_gen_nonfinite(void) {
    begin_case("eig_sym_gen non-finite");
    static const double K1[4] = {2, 1, 1, 2}, M1[4] = {INFINITY, 0, 0, 1};
    static const double K2[4] = {2, NAN, NAN, 2}, M2[4] = {1, 0, 0, 1};
    static const double K3[4] = {1e300, 0, 0, 1e300}, M3[4] = {1e-300, 0, 0, 1e-300};
    const double *ks[3] = {K1, K2, K3}, *ms[3] = {M1, M2, M3};
    static const char *const what[3] = {"Inf on M's diagonal", "NaN in K", "overflowing reduction"};
    for (int t = 0; t < 3; t++) {
        void *K = arr_from(ks[t], 2, 2, 0), *M = arr_from(ms[t], 2, 2, 0);
        void *E = sea_eig_sym_gen(K, M, SITE);
        check_all_nan(what[t], E, 2);
        if (E) sea_free(E);
        sea_free(K);
        sea_free(M);
    }
    end_case();
}

static const uint64_t EXACT_N[] = {1, 2, 3, 5, 8, 31, 32, 33, 63, 64, 65, 70, 100, 129, 200};
#define NEXACT (sizeof EXACT_N / sizeof EXACT_N[0])

/* run_8c: every 8c case once, under the current variant */
static uint64_t run_8c(uint64_t seed) {
    run_la_empty();
    for (uint64_t n = 1; n <= LA_MAX_N; n++) {
        run_lu_general(n, seed++);
        run_chol(n, seed++);
        run_lu_path(n, PATH_NEGDIAG, seed++);
        if (n >= 2) {
            run_lu_path(n, PATH_EARLY, seed++);
            run_lu_path(n, PATH_LATE, seed++);
        }
    }
    for (size_t t = 0; t < NEXACT; t++) {
        run_lu_exact(EXACT_N[t], seed++);
        run_chol_exact(EXACT_N[t], seed++);
    }
    run_rcond_specials();
    for (uint64_t n = 1; n <= RC_MAX_N; n++) {
        run_rcond_identity(n);
        run_rcond_diag(n, seed++);
    }
    for (uint64_t n = 2; n <= 20; n++) run_rcond_bidiag(n, seed++);
    for (int kind = 0; kind < 5; kind++)
        for (uint64_t n = 1; n <= 64; n++)
            for (int rep = 0; rep < 4; rep++) run_rcond_hard(n, kind, seed++);
    /* many small integer matrices: on these the tie rule of "the first index of largest |x[i]|"
     * and the test est <= estold decide the result in a few cases in a thousand */
    for (int kind = 2; kind <= 4; kind += 2)
        for (uint64_t n = 2; n <= 10; n++)
            for (int rep = 0; rep < 1000; rep++) run_rcond_hard(n, kind, seed++);
    for (uint64_t n = 0; n <= EIG_MAX_N; n++) {
        run_eig_sym(n, seed++);
        run_eig_sym_diag(n, seed++);
        run_eig_gen(n, seed++);
        run_eig_gen_exact(n, seed++);
    }
    run_eig_sym_nonfinite();
    run_eig_gen_nonfinite();
    return seed;
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
        g_xv_pos = 0;
        seed = run_8c(seed);
        if (g_xv_have && g_xv_pos != g_xv_len) {
            fprintf(stderr, "la_check: %s: %zu cross-variant results, %zu under the first variant\n", g_vname,
                    g_xv_pos, g_xv_len);
            g_failures++;
        }
        g_xv_have = 1;
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
