/*
 * tests/math/math_check_y.c -- the 4-lane part of the elementary-function harness (Sea
 * DESIGN.md 2.12.8, L-fj). x86_64 only; compiled with -mavx2 and linked with math_check.c and
 * libsea.a. math_check.c calls mathy_vcall4 only after __builtin_cpu_supports("avx2") says the
 * CPU and the OS support AVX2, so no AVX2 instruction of this file runs before that check.
 *
 * mathy_vcall4(fn, a, b, r): calls sea_<fn>_y (fn is the index in math_check.c's FUNCS order:
 * 0 log, 1 exp, 2 sin, 3 cos, 4 pow, 5 hypot) on the four lanes a[0..3] (and b[0..3] for pow and
 * hypot) and stores the four result lanes in r[0..3].
 */
#include <immintrin.h>

__m256d sea_log_y(__m256d);
__m256d sea_exp_y(__m256d);
__m256d sea_sin_y(__m256d);
__m256d sea_cos_y(__m256d);
__m256d sea_pow_y(__m256d, __m256d);
__m256d sea_hypot_y(__m256d, __m256d);

void mathy_vcall4(int fn, const double *a, const double *b, double *r) {
    __m256d va = _mm256_loadu_pd(a), vb = _mm256_loadu_pd(b), vr;
    switch (fn) {
    case 0: vr = sea_log_y(va); break;
    case 1: vr = sea_exp_y(va); break;
    case 2: vr = sea_sin_y(va); break;
    case 3: vr = sea_cos_y(va); break;
    case 4: vr = sea_pow_y(va, vb); break;
    default: vr = sea_hypot_y(va, vb); break;
    }
    _mm256_storeu_pd(r, vr);
    /* leave the upper halves clean for the scalar code of the caller */
    _mm256_zeroupper();
}
