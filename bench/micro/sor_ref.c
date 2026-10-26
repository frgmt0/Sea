/* sor_ref.c -- C reference of sor.sea (DESIGN.md 5.9): W4's scalar SOR in lexicographic order,
 * the same operations in the same order as tests/accept/w4_sor.sea, row-major T[j*nx+i], output
 * format as sor.sea. Built with `cc -O2 -ffp-contract=off`. A measuring tool, never part of Sea. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <time.h>

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

int main(void) {
    const double W = 0.30, H = 0.20, h = 0.00125, kCond = 167.0;
    const double Tbot0 = 40.0, Tbot1 = 65.0, Ttop = 20.0, Thole = 12.0;
    const double holeCx = 0.215, holeCy = 0.105, holeR = 0.018;
    const double srcX0 = 0.06, srcX1 = 0.11, srcY0 = 0.07, srcY1 = 0.12;
    const double qSrc = 2.5e7, tol = 1e-8;
    const int64_t maxIt = 20000;
    const double pi = 3.14159265358979323846;

    int64_t nx = (int64_t)round(W / h) + 1;
    int64_t ny = (int64_t)round(H / h) + 1;
    double *x = calloc((size_t)nx, sizeof(double));
    double *y = calloc((size_t)ny, sizeof(double));
    double *T = calloc((size_t)(nx * ny), sizeof(double));
    double *src = calloc((size_t)(nx * ny), sizeof(double));
    char *hole = calloc((size_t)(nx * ny), 1);
    char *fixed = calloc((size_t)(nx * ny), 1);
    if (!x || !y || !T || !src || !hole || !fixed) { fprintf(stderr, "sor_ref: out of memory\n"); return 2; }
    for (int64_t i = 0; i < nx; i++) x[i] = (double)i * h;
    for (int64_t j = 0; j < ny; j++) y[j] = (double)j * h;

    double holeR2 = holeR * holeR;
    double srcVal = h * h * qSrc / kCond;
    for (int64_t i = 0; i < nx; i++)
        for (int64_t j = 0; j < ny; j++) {
            double dx = x[i] - holeCx, dy = y[j] - holeCy;
            hole[j * nx + i] = dx * dx + dy * dy <= holeR2;
            if (x[i] >= srcX0 && x[i] <= srcX1 && y[j] >= srcY0 && y[j] <= srcY1) src[j * nx + i] = srcVal;
        }
    for (int64_t i = 0; i < nx; i++)
        for (int64_t j = 0; j < ny; j++)
            fixed[j * nx + i] = hole[j * nx + i] || j == 0 || j == ny - 1;

    for (int64_t k = 0; k < nx * ny; k++) T[k] = Ttop;
    for (int64_t i = 0; i < nx; i++) {
        T[i] = Tbot0 + (Tbot1 - Tbot0) * x[i] / W;
        T[(ny - 1) * nx + i] = Ttop;
    }
    for (int64_t i = 0; i < nx; i++)
        for (int64_t j = 0; j < ny; j++)
            if (hole[j * nx + i]) T[j * nx + i] = Thole;

    double rhoJ = (1.0 + cos(pi / (double)(ny - 1))) / 2.0;
    double omega = 2.0 / (1.0 + sqrt(1.0 - rhoJ * rhoJ));

    int64_t npts = 0;
    for (int64_t i = 0; i < nx; i++)
        for (int64_t j = 1; j < ny - 1; j++)
            if (!fixed[j * nx + i]) npts++;

    int64_t itSor = 0;
    double dMax = INFINITY;
    double t0 = now();
    while (dMax > tol && itSor < maxIt) {
        itSor++;
        dMax = 0.0;
        for (int64_t i = 0; i < nx; i++) {
            for (int64_t j = 1; j < ny - 1; j++) {
                if (fixed[j * nx + i]) continue;
                double tw = (i == 0) ? T[j * nx + 1] : T[j * nx + i - 1];
                double te = (i == nx - 1) ? T[j * nx + nx - 2] : T[j * nx + i + 1];
                double tgs = (tw + te + T[(j - 1) * nx + i] + T[(j + 1) * nx + i] + src[j * nx + i]) / 4.0;
                double tn = T[j * nx + i] + omega * (tgs - T[j * nx + i]);
                double d = fabs(tn - T[j * nx + i]);
                if (d > dMax) dMax = d;
                T[j * nx + i] = tn;
            }
        }
    }
    double secs = now() - t0;

    double Tmax = -INFINITY;
    for (int64_t i = 0; i < nx; i++)
        for (int64_t j = 0; j < ny; j++)
            if (!fixed[j * nx + i] && T[j * nx + i] > Tmax) Tmax = T[j * nx + i];

    printf("it_sor %lld\n", (long long)itSor);
    printf("T_max %.17g\n", Tmax);
    printf("npts %lld\n", (long long)npts);
    printf("seconds %.9f\n", secs);
    return 0;
}
