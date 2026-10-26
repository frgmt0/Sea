/* lcg_ref.c -- C reference of lcg.sea (DESIGN.md 5.9): the Park-Miller LCG fill, 11 000 000 steps
 * from seed 7 340 117, same operation order, output format as lcg.sea. Built with
 * `cc -O2 -ffp-contract=off`. A measuring tool, never part of Sea. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

/* lcg_fill: n uniforms in (0,1); s is the state, updated in place */
static double *lcg_fill(int64_t *s, int64_t n) {
    double *u = calloc((size_t)n, sizeof(double));
    if (!u) { fprintf(stderr, "lcg_ref: out of memory\n"); exit(2); }
    int64_t st = *s;
    for (int64_t i = 0; i < n; i++) {
        st = 16807 * st % 2147483647;
        u[i] = (double)st / 2147483647.0;
    }
    *s = st;
    return u;
}

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

int main(void) {
    const int64_t nStep = 11000000;
    int64_t s = 7340117;
    double t0 = now();
    double *u = lcg_fill(&s, nStep);
    double secs = now() - t0;
    printf("lcg_final %lld\n", (long long)s);
    printf("u_last %.17g\n", u[nStep - 1]);
    printf("seconds %.9f\n", secs);
    free(u);
    return 0;
}
