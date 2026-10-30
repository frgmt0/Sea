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
 *
 * Vector entries (DESIGN.md 2.12.8, L-fj). After the scalar pass the harness tests the vector
 * entries sea_<fn>_x (2 lanes: NEON float64x2_t on arm64, SSE2 __m128d on x86_64) and, on x86_64
 * when the CPU reports AVX2 at run time, sea_<fn>_y (4 lanes: __m256d; the vcall4 wrapper lives
 * in math_check_y.c, the second translation unit, compiled with -mavx2, so that no AVX2
 * instruction can run before the run-time check). Two parts per lane count L:
 *   (1) every committed vector case in every lane position 0..L-1, the other lanes filled with
 *       cases of the same file whose arguments are rare or special (zero, subnormal, infinity,
 *       NaN, |x| >= 2^23, 256 <= |x| < 1024); lane p is compared with the file's expected
 *       pattern, every other lane with the scalar entry; and
 *   (2) the seeded random differential test: for each function and each of four lane patterns
 *       (all lanes mixed; all lanes common; exactly one rare lane, the position rotating with
 *       the call index; all lanes rare) 2^24 vector calls whose operands come from a
 *       fixed-seed xorshift64* generator over all bit patterns and over the function's
 *       interesting ranges (|x| near 2^23 and 512, subnormals, +-0, +-inf, NaN payloads, the
 *       overflow and underflow thresholds); every result lane is compared bit for bit with the
 *       scalar entry. A mismatch prints `math <fn> <tag>: ...` with the inputs, the lane and
 *       both patterns; at most 8 per task (part 1 or one lane pattern) are printed, all are counted.
 * The output lines end in ` cases ok` when a part passes.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>

/* DESIGN.md 4.10.6: each file holds at most 10 000 cases, and the generator writes that many;
   a file with any other count is truncated or foreign. */
#define VEC_CASES 10000L

/* L-fj: random vector calls per function and lane pattern. */
#define RAND_CALLS (1UL << 24)
/* Mismatch lines printed per function and part (all are counted). */
#define MAX_REPORT 8
/* Size of the rare-input pool drawn from a vector file for the other lanes. */
#define POOL_MAX 4096

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

#if defined(__aarch64__)
#include <arm_neon.h>
float64x2_t sea_log_x(float64x2_t);
float64x2_t sea_exp_x(float64x2_t);
float64x2_t sea_sin_x(float64x2_t);
float64x2_t sea_cos_x(float64x2_t);
float64x2_t sea_pow_x(float64x2_t, float64x2_t);
float64x2_t sea_hypot_x(float64x2_t, float64x2_t);
#elif defined(__x86_64__)
#include <emmintrin.h>
__m128d sea_log_x(__m128d);
__m128d sea_exp_x(__m128d);
__m128d sea_sin_x(__m128d);
__m128d sea_cos_x(__m128d);
__m128d sea_pow_x(__m128d, __m128d);
__m128d sea_hypot_x(__m128d, __m128d);
/* math_check_y.c: the 4-lane wrapper (compiled with -mavx2) */
void mathy_vcall4(int fn, const double *a, const double *b, double *r);
#else
#error "math_check: unsupported architecture"
#endif

/* vcall_t: one vector call of function index fn (the FUNCS order) on L lanes: operands a (and b
   for pow, hypot), L doubles each; the L result lanes are stored in r. */
typedef void (*vcall_t)(int fn, const double *a, const double *b, double *r);

/* vcall2: the 2-lane entries through the platform's native vector type. */
static void vcall2(int fn, const double *a, const double *b, double *r) {
#if defined(__aarch64__)
    float64x2_t va = vld1q_f64(a), vb = vld1q_f64(b), vr;
    switch (fn) {
    case 0: vr = sea_log_x(va); break;
    case 1: vr = sea_exp_x(va); break;
    case 2: vr = sea_sin_x(va); break;
    case 3: vr = sea_cos_x(va); break;
    case 4: vr = sea_pow_x(va, vb); break;
    default: vr = sea_hypot_x(va, vb); break;
    }
    vst1q_f64(r, vr);
#else
    __m128d va = _mm_loadu_pd(a), vb = _mm_loadu_pd(b), vr;
    switch (fn) {
    case 0: vr = sea_log_x(va); break;
    case 1: vr = sea_exp_x(va); break;
    case 2: vr = sea_sin_x(va); break;
    case 3: vr = sea_cos_x(va); break;
    case 4: vr = sea_pow_x(va, vb); break;
    default: vr = sea_hypot_x(va, vb); break;
    }
    _mm_storeu_pd(r, vr);
#endif
}

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

#define NFUNCS ((int)(sizeof FUNCS / sizeof FUNCS[0]))

/* The cases of one .vec file, kept for the lane tests: argument patterns and expected pattern. */
static struct {
    uint64_t a[VEC_CASES], b[VEC_CASES], w[VEC_CASES];
} VS[6];

/* ---- the seeded generator (L-fj) -------------------------------------------------------- */

typedef struct { uint64_t s; } rng_t;

/* rng_next: xorshift64* (Vigna): the state never reaches 0 because the seed is nonzero. */
static uint64_t rng_next(rng_t *r) {
    uint64_t x = r->s;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    r->s = x;
    return x * 0x2545F4914F6CDD1DULL;
}

#define SIGN 0x8000000000000000ULL
#define EXPF 0x7FF0000000000000ULL
#define MANT 0x000FFFFFFFFFFFFFULL

/* rare_bits: one rare or special operand pattern: +-0, +-inf, quiet and signalling NaNs with
   random payloads, subnormals, |x| near 2^23 and 512 (+-8 ulps), |x| >= 2^23 up to 2^64 and
   up to the largest binade, +-1 (+-8 ulps), the exp overflow and underflow thresholds. */
static uint64_t rare_bits(rng_t *r) {
    uint64_t u = rng_next(r), v = rng_next(r);
    uint64_t sg = (u & 1) ? SIGN : 0, d = (u >> 8) & 15;
    switch ((u >> 1) % 14) {
    case 0: return sg;
    case 1: return sg | EXPF;
    case 2: return sg | EXPF | (1ULL << 51) | (v & MANT);
    case 3: return sg | EXPF | ((v & MANT & ~(1ULL << 51)) ? (v & MANT & ~(1ULL << 51)) : 1);
    case 4: return sg | ((v & MANT) ? (v & MANT) : 1);
    case 5: return sg | (1 + (v & 15));
    case 6: return sg | (0x4160000000000000ULL + d - 8);
    case 7: return sg | (0x4080000000000000ULL + d - 8);
    case 8: return sg | ((0x416ULL + (v >> 52) % 42) << 52) | (rng_next(r) & MANT);
    case 9: return sg | ((0x7C0ULL + (v >> 52) % 63) << 52) | (rng_next(r) & MANT);
    case 10: return sg | (0x3FF0000000000000ULL + d - 8);
    case 11: return sg | (0x40862E42FEFA39EFULL + d - 8);
    case 12: return sg | (0x40874910D52D3051ULL + d - 8);
    default: return sg | (0x7FEFFFFFFFFFFFFFULL - d);
    }
}

static double unit(rng_t *r) { return (double)(rng_next(r) >> 11) * (1.0 / 9007199254740992.0); }

/* common_bits: an operand from the function's common range (no rare path taken):
   log positive normals of exponent +-32; exp in (-500, 500); sin, cos in (-2^22, 2^22);
   pow a positive base of exponent +-16 and an exponent in (-30, 30); hypot either sign,
   exponent +-256. */
static uint64_t common_bits(int fn, int arg, rng_t *r) {
    double d;
    uint64_t m = rng_next(r);
    switch (fn) {
    case 0: return (0x3E0ULL + (m >> 52) % 65) << 52 | (rng_next(r) & MANT);
    case 1: d = unit(r) * 1000.0 - 500.0; return to_bits(d);
    case 2:
    case 3: d = unit(r) * 8388608.0 - 4194304.0; return to_bits(d);
    case 4:
        if (arg == 0) return (0x3F0ULL + (m >> 52) % 33) << 52 | (rng_next(r) & MANT);
        d = unit(r) * 60.0 - 30.0;
        return to_bits(d);
    default: return ((m & 1) ? SIGN : 0) | (0x2FFULL + (m >> 52) % 513) << 52 | (rng_next(r) & MANT);
    }
}

enum { CL_ALL = 0, CL_COMMON, CL_RARE, CL_MIXED };

/* gen_operand: class cl (all bit patterns, common, rare; mixed picks one of the three at random
   with probabilities 1/4, 1/4, 1/2). */
static uint64_t gen_operand(int fn, int arg, int cl, rng_t *r) {
    if (cl == CL_MIXED) {
        uint64_t c = rng_next(r) >> 60;
        cl = c < 4 ? CL_ALL : c < 8 ? CL_COMMON : CL_RARE;
    }
    if (cl == CL_ALL) return rng_next(r);
    if (cl == CL_COMMON) return common_bits(fn, arg, r);
    return rare_bits(r);
}

/* ---- comparison helpers ------------------------------------------------------------------- */

static double scalar(int fn, double a, double b) {
    volatile double va = a, vb = b;
    return FUNCS[fn].nargs == 1 ? FUNCS[fn].f1(va) : FUNCS[fn].f2(va, vb);
}

/* ---- tasks: the lane tests run on a pool of threads, output buffered per task ---------------- */

enum { PAT_MIXED = 0, PAT_COMMON, PAT_ONE_RARE, PAT_ALL_RARE, PAT_COUNT };
static const char *const PAT_NAME[PAT_COUNT] = {"mixed", "common", "one-rare", "all-rare"};

/* One unit of work: part 1 of (fn, L), or one lane pattern of part 2 of (fn, L). A task writes
   only its own record (its mismatch lines go to out); main prints the records in a fixed order
   after the join, so the output does not depend on the scheduling. */
typedef struct {
    int fn, L, rand, pat;   /* rand 0: part 1; rand 1: part 2, lane pattern pat */
    vcall_t vc;
    const char *tag;
    long bad, calls;
    size_t len;
    char out[4096];
} task_t;

/* t_report: counts a mismatch of task t and appends its line (the first MAX_REPORT only). */
static void t_report(task_t *t, const char *what, int lane, const double *a, const double *b,
                     uint64_t want, uint64_t got, unsigned long call) {
    t->bad++;
    if (t->bad > MAX_REPORT) return;
    int nargs = FUNCS[t->fn].nargs;
    char hdr[96];
    if (t->rand) snprintf(hdr, sizeof hdr, "%s random %s call %lu", t->tag, PAT_NAME[t->pat], call);
    else snprintf(hdr, sizeof hdr, "%s", t->tag);
    int n;
    if (nargs == 1)
        n = snprintf(t->out + t->len, sizeof t->out - t->len,
                     "math %s %s: %s lane %d: %016llX expected %016llX got %016llX\n",
                     FUNCS[t->fn].name, hdr, what, lane, (unsigned long long)to_bits(a[lane]),
                     (unsigned long long)want, (unsigned long long)got);
    else
        n = snprintf(t->out + t->len, sizeof t->out - t->len,
                     "math %s %s: %s lane %d: %016llX %016llX expected %016llX got %016llX\n",
                     FUNCS[t->fn].name, hdr, what, lane, (unsigned long long)to_bits(a[lane]),
                     (unsigned long long)to_bits(b[lane]), (unsigned long long)want,
                     (unsigned long long)got);
    if (n > 0 && t->len + (size_t)n < sizeof t->out) t->len += (size_t)n;
}

/* ---- part 1: every vector case in every lane position -------------------------------------- */

/* is_rare: the argument pattern is zero, subnormal, infinite or NaN, or |x| is in [256, 1024)
   or >= 2^23 (a rare path of 4.10.4 exists there). */
static int is_rare(uint64_t u) {
    uint64_t e = (u & EXPF) >> 52;
    return e == 0 || e == 0x7FF || (e >= 0x407 && e <= 0x408) || e >= 0x416;
}

/* run_vec: part 1 of task t. Every vector case of the file in every lane position, the other
   lanes filled from a pool of rare cases of the same file; lane p is compared with the file's
   expected pattern, the other lanes with their own case's expected pattern. */
static void run_vec(task_t *t) {
    uint32_t pool[POOL_MAX];
    int fn = t->fn, L = t->L, nargs = FUNCS[fn].nargs;
    uint32_t np = 0, total = 0;
    for (uint32_t i = 0; i < VEC_CASES; i++)
        if (is_rare(VS[fn].a[i]) || (nargs == 2 && is_rare(VS[fn].b[i]))) total++;
    /* stride over the rare cases so the pool spans the whole file */
    uint32_t stride = total > POOL_MAX ? (total + POOL_MAX - 1) / POOL_MAX : 1, seen = 0;
    for (uint32_t i = 0; i < VEC_CASES && np < POOL_MAX; i++)
        if (is_rare(VS[fn].a[i]) || (nargs == 2 && is_rare(VS[fn].b[i])))
            if (seen++ % stride == 0) pool[np++] = i;
    if (np == 0) {
        fprintf(stderr, "math_check: %s.vec holds no rare case\n", FUNCS[fn].name);
        exit(2);
    }
    for (uint32_t i = 0; i < VEC_CASES; i++) {
        for (int p = 0; p < L; p++) {
            double a[4], b[4], r[4];
            uint32_t c[4];
            for (int j = 0; j < L; j++) {
                c[j] = j == p ? i : pool[((uint64_t)i * 7 + (uint64_t)j * 13 + (uint64_t)p * 5 + 1) % np];
                a[j] = from_bits(VS[fn].a[c[j]]);
                b[j] = nargs == 2 ? from_bits(VS[fn].b[c[j]]) : 0.0;
            }
            t->vc(fn, a, b, r);
            t->calls++;
            for (int j = 0; j < L; j++) {
                uint64_t want = j == p ? VS[fn].w[i] : VS[fn].w[c[j]];
                uint64_t got = to_bits(r[j]);
                if (got != want) t_report(t, j == p ? "vector case" : "filler", j, a, b, want, got, 0);
            }
        }
    }
}

/* ---- part 2: the seeded random differential test ------------------------------------------- */

/* run_rand: part 2 of task t for lane pattern t->pat: RAND_CALLS vector calls, each result lane
   compared bit for bit with the scalar entry. */
static void run_rand(task_t *t) {
    int fn = t->fn, L = t->L, pat = t->pat, nargs = FUNCS[fn].nargs;
    /* a fixed seed per function, lane count and pattern */
    rng_t rg = {0x9E3779B97F4A7C15ULL ^ ((uint64_t)(fn + 1) << 40) ^ ((uint64_t)L << 32) ^
                ((uint64_t)(pat + 1) << 48)};
    for (int k = 0; k < 8; k++) rng_next(&rg);
    for (unsigned long n = 0; n < RAND_CALLS; n++) {
        double a[4], b[4], r[4];
        int rare_lane = (int)(n % (unsigned long)L);
        for (int j = 0; j < L; j++) {
            int cl = pat == PAT_MIXED ? CL_MIXED
                   : pat == PAT_COMMON ? CL_COMMON
                   : pat == PAT_ALL_RARE ? CL_RARE
                   : (j == rare_lane ? CL_RARE : CL_COMMON);
            a[j] = from_bits(gen_operand(fn, 0, cl, &rg));
            b[j] = nargs == 2 ? from_bits(gen_operand(fn, 1, cl, &rg)) : 0.0;
        }
        t->vc(fn, a, b, r);
        t->calls++;
        for (int j = 0; j < L; j++) {
            uint64_t want = to_bits(scalar(fn, a[j], b[j])), got = to_bits(r[j]);
            if (got != want) t_report(t, "scalar differs:", j, a, b, want, got, n);
        }
    }
}

/* ---- the thread pool ---------------------------------------------------------------------- */

static task_t *TASKS;
static int NTASKS, NEXT_TASK;
static pthread_mutex_t TASK_LOCK = PTHREAD_MUTEX_INITIALIZER;

/* worker: takes the last unclaimed task and runs it, until none is left. */
static void *worker(void *unused) {
    (void)unused;
    for (;;) {
        pthread_mutex_lock(&TASK_LOCK);
        int i = NEXT_TASK >= 0 ? NEXT_TASK-- : -1;
        pthread_mutex_unlock(&TASK_LOCK);
        if (i < 0) return 0;
        if (TASKS[i].rand) run_rand(&TASKS[i]);
        else run_vec(&TASKS[i]);
    }
}

/* run_tasks: runs tasks 0..n-1 on min(n, online CPUs, 16) threads; returns after the join. */
static void run_tasks(task_t *tasks, int n) {
    TASKS = tasks;
    NTASKS = n;
    NEXT_TASK = n - 1;   /* claimed from the end: the 4-lane tasks, the heaviest, start first */
    long cpus = sysconf(_SC_NPROCESSORS_ONLN);
    int nt = cpus < 1 ? 1 : cpus > 16 ? 16 : (int)cpus;
    if (nt > n) nt = n;
    pthread_t th[16];
    int started = 0;
    for (int i = 0; i < nt; i++)
        if (pthread_create(&th[started], 0, worker, 0) == 0) started++;
    if (started == 0) worker(0);   /* no thread could be created: run everything here */
    for (int i = 0; i < started; i++) pthread_join(th[i], 0);
}

/* print_group: the output of the PAT_COUNT + 1 tasks of one (function, lane count) group, in the
   fixed order: part 1's lines, then each pattern's mismatches, then the ok lines of the parts
   that passed. Returns 1 when anything mismatched. */
static int print_group(const task_t *g, const char *name, const char *tag) {
    int status = 0, rand_bad = 0;
    for (int i = 0; i <= PAT_COUNT; i++) {
        fwrite(g[i].out, 1, g[i].len, stdout);
        if (g[i].bad) status = 1;
        if (i > 0 && g[i].bad) rand_bad = 1;
        if (i == 0 && !g[i].bad) printf("math %s %s: %ld cases ok\n", name, tag, g[i].calls);
    }
    if (!rand_bad)
        printf("math %s %s random: %d patterns of %lu cases ok\n", name, tag, (int)PAT_COUNT, RAND_CALLS);
    return status;
}

int main(int argc, char **argv) {
    const char *dir = argc > 1 ? argv[1] : "tests/math";
    if (argc > 2) {
        fprintf(stderr, "usage: math_check [DIR]\n");
        return 2;
    }
    int status = 0;
    for (int k = 0; k < NFUNCS; k++) {
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
            if (cases < VEC_CASES) {
                VS[k].a[cases] = f[0];
                VS[k].b[cases] = nf == 3 ? f[1] : 0;
                VS[k].w[cases] = want;
            }
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
    fflush(stdout);

    /* the lane tests: tasks on a thread pool, printed in this fixed order after the join. Per
       function and lane count: task 0 is part 1, tasks 1..PAT_COUNT part 2's lane patterns. */
    int ngroups = NFUNCS;
#if defined(__x86_64__)
    int have_y = __builtin_cpu_supports("avx2");   /* the CPU and the OS support AVX2 */
    if (have_y) ngroups += NFUNCS;
#endif
    static task_t tasks[2 * 6 * (PAT_COUNT + 1)];
    for (int g = 0; g < ngroups; g++) {
        for (int i = 0; i <= PAT_COUNT; i++) {
            task_t *t = &tasks[g * (PAT_COUNT + 1) + i];
            t->fn = g % NFUNCS;
            t->L = g < NFUNCS ? 2 : 4;
            t->rand = i > 0;
            t->pat = i > 0 ? i - 1 : 0;
#if defined(__x86_64__)
            t->vc = g < NFUNCS ? vcall2 : mathy_vcall4;
#else
            t->vc = vcall2;
#endif
            t->tag = g < NFUNCS ? "x2" : "y4";
        }
    }
    run_tasks(tasks, ngroups * (PAT_COUNT + 1));
    for (int g = 0; g < ngroups; g++)
        if (print_group(&tasks[g * (PAT_COUNT + 1)], FUNCS[g % NFUNCS].name, g < NFUNCS ? "x2" : "y4"))
            status = 1;
#if defined(__x86_64__)
    if (!have_y) printf("math: AVX2 not reported by the CPU, 4-lane entries not run\n");
#endif
    return status;
}
