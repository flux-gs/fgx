/*
 * fractal_ref.c -- HOST reference oracle for the FGX 3200-color fractal.
 *
 * Purpose: an independent, portable-C implementation of the exact 8.24
 * fixed-point Mandelbrot/Julia iteration the FGX tool mirrors, so the
 * on-device iteration-buffer goldens are derived from this oracle rather
 * than self-recorded. (FGX policy: validate against a host C reference.)
 *
 * CRITICAL: the escape test and updates use 32-bit signed arithmetic to be
 * BIT-IDENTICAL to fcc's 32-bit `long` on the 65816. Only fix_mul uses a
 * 64-bit intermediate (matching the FGX 32x32->64 asm helper). Do NOT switch
 * the escape sum to 64-bit -- that would silently diverge from the device.
 *
 * Modes:
 *   --selftest              fix_mul vs double; rc=0 pass, rc=nfail on error
 *   --raw cr0 ci0 step w h maxit          Mandelbrot; raw WxH bytes to stdout
 *   --raw-julia cr0 ci0 step w h maxit jcr jci   Julia; raw bytes to stdout
 * cr0/ci0/step/jcr/jci are 8.24 fixed-point integers passed as decimal.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

/*
 * Fixed-point format Q(FBITS). FBITS=12 keeps the fixmul PRODUCT within signed
 * 32-bit: operands are |z|<=~2 before the escape break (largest transient ~9.5
 * for zi), so |a*b| <= ~90*2^24 < 2^31. This means `(a*b)>>FBITS` is a pure
 * 32-bit expression -- NO 64-bit intermediate, NO hand-asm multiply on the
 * 65816 (fcc's `long*long` gives exactly this low-32 product). Trade: ~12-bit
 * zoom depth. Deep zoom (8.24 + a 32x32->64 asm helper) is the upgrade path.
 */
#define FBITS 9
#define ESC   ((int32_t)4 << FBITS)   /* |z|^2 > 4.0 in Q12 */

static int32_t fix_mul(int32_t a, int32_t b) {
    return (int32_t)((a * b) >> FBITS);   /* 32-bit; product fits, see note */
}
static int32_t dtofix(double d) { return (int32_t)(d * (double)(1 << FBITS)); }

/* Component pre-check shared by every iteration: |zr| or |zi| beyond 4.0
 * escapes NOW. Semantically equivalent to the square-sum test (one square
 * alone would already exceed ESC), so counts are unchanged -- but it bounds
 * the state so the DEVICE's 16-bit squares/table indices can't overflow on
 * the cubic's large transients. Must stay in lockstep with mand_asm. */
#define PRECHK(zr, zi) ((zr) > 2048 || (zr) < -2048 || (zi) > 2048 || (zi) < -2048)

/* Mandelbrot: c = (cr,ci), z0 = 0. Returns escape iteration, capped at 255. */
static int mandel_iter(int32_t cr, int32_t ci, int maxit) {
    int32_t zr = 0, zi = 0;
    int n;
    for (n = 0; n < maxit; n++) {
        if (PRECHK(zr, zi)) break;
        int32_t zr2 = fix_mul(zr, zr);
        int32_t zi2 = fix_mul(zi, zi);
        if (zr2 + zi2 > ESC) break;          /* 32-bit signed, no overflow in range */
        int32_t nzr = zr2 - zi2 + cr;
        zi = (fix_mul(zr, zi) << 1) + ci;
        zr = nzr;
    }
    return n > 255 ? 255 : n;
}

/* Tricorn (Mandelbar): z <- conj(z)^2 + c: the cross term is negated. */
static int tricorn_iter(int32_t cr, int32_t ci, int maxit) {
    int32_t zr = 0, zi = 0;
    int n;
    for (n = 0; n < maxit; n++) {
        if (PRECHK(zr, zi)) break;
        int32_t zr2 = fix_mul(zr, zr);
        int32_t zi2 = fix_mul(zi, zi);
        if (zr2 + zi2 > ESC) break;
        int32_t nzr = zr2 - zi2 + cr;
        zi = -(fix_mul(zr, zi) << 1) + ci;
        zr = nzr;
    }
    return n > 255 ? 255 : n;
}

/* Burning Ship: z <- (|Re z| + i|Im z|)^2 + c: abs both parts, then square. */
static int ship_iter(int32_t cr, int32_t ci, int maxit) {
    int32_t zr = 0, zi = 0;
    int n;
    for (n = 0; n < maxit; n++) {
        if (PRECHK(zr, zi)) break;
        if (zr < 0) zr = -zr;
        if (zi < 0) zi = -zi;
        int32_t zr2 = fix_mul(zr, zr);
        int32_t zi2 = fix_mul(zi, zi);
        if (zr2 + zi2 > ESC) break;
        int32_t nzr = zr2 - zi2 + cr;
        zi = (fix_mul(zr, zi) << 1) + ci;
        zr = nzr;
    }
    return n > 255 ? 255 : n;
}

/* Cubic multibrot: z <- z^3 + c.
 * zr' = zr*(zr2 - 3*zi2) + cr, zi' = zi*(3*zr2 - zi2) + ci (Q9 muls). */
static int cubic_iter(int32_t cr, int32_t ci, int maxit) {
    int32_t zr = 0, zi = 0;
    int n;
    for (n = 0; n < maxit; n++) {
        if (PRECHK(zr, zi)) break;
        int32_t zr2 = fix_mul(zr, zr);
        int32_t zi2 = fix_mul(zi, zi);
        if (zr2 + zi2 > ESC) break;
        int32_t nzr = fix_mul(zr, zr2 - 3 * zi2) + cr;
        zi = fix_mul(zi, 3 * zr2 - zi2) + ci;
        zr = nzr;
    }
    return n > 255 ? 255 : n;
}

/*
 * Interior shortcut: main-cardioid + period-2-bulb membership test in Q9.
 * A point inside either region never escapes, so the iteration would return
 * maxit; the test lets the device skip maxit iterations for most of the set's
 * interior. It MUST be value-preserving vs the Q9 ITERATION (not just the true
 * set): --interior-diff proves zero mismatches over a window. CARD_MARGIN
 * shrinks the cardioid test so (a) the q>>9 rounding can't overclaim and
 * (b) near-boundary points where Q9 iteration noise could numerically escape
 * fall through to real iteration. All arithmetic is 32-bit signed and maps
 * 1:1 onto the device quarter-square table (x*x = T[2|x|] exactly; u*v =
 * T[|u+v|]-T[|u-v|]); the range gates keep every table index within n<=9728.
 */
#define CARD_MARGIN 4096   /* Q18 ~= 0.016; rounding bound is ~1551 */
#define BULB_MARGIN 512    /* Q18: Q9-iteration noise escapes within ~150 of the circle */

static int interior_check(int32_t cr, int32_t ci) {
    int32_t y = ci < 0 ? -ci : ci;
    int32_t a, q18, q, lhs, rhs;
    if (y > 358) return 0;                    /* above cardioid (|y|<=~0.65) and bulb */
    if (cr >= -640 && cr <= -384 && y <= 128) {
        a = cr + 512;                         /* bulb: (x+1)^2 + y^2 < 1/16, Q18 exact */
        if (a * a + y * y < 16384 - BULB_MARGIN) return 1;
    }
    if (cr >= -390 && cr <= 130) {
        a = cr - 128;                         /* cardioid: q=(x-1/4)^2+y^2 */
        q18 = a * a + y * y;                  /* Q18 exact, <= ~400K */
        q = q18 >> 9;                         /* Q9, <= ~774 */
        lhs = q * (q + a);                    /* Q18: inside if q*(q+a) < y^2/4 */
        rhs = (y * y) >> 2;
        if (lhs + CARD_MARGIN < rhs) return 1;
    }
    return 0;
}

/* Count mismatches between the shortcut and the real Q9 iteration over a
 * window: every shortcut-claimed pixel must iterate to exactly maxit. */
static int interior_diff(int32_t cr0, int32_t ci0, int32_t step,
                         int w, int h, int maxit) {
    int px, py, bad = 0, claimed = 0;
    int32_t ci = ci0;
    for (py = 0; py < h; py++, ci += step) {
        int32_t cr = cr0;
        for (px = 0; px < w; px++, cr += step) {
            if (interior_check(cr, ci)) {
                claimed++;
                int v = mandel_iter(cr, ci, maxit);
                if (v != (maxit > 255 ? 255 : maxit)) {
                    if (bad < 10)
                        printf("MISMATCH px=%d py=%d cr=%d ci=%d iter=%d\n",
                               px, py, cr, ci, v);
                    bad++;
                }
            }
        }
    }
    printf("INTDIFF claimed=%d bad=%d\n", claimed, bad);
    return bad != 0;
}

/* Julia: c = (jcr,jci) fixed, z0 = (cr,ci) the pixel coordinate. */
static int julia_iter(int32_t cr, int32_t ci, int32_t jcr, int32_t jci, int maxit) {
    int32_t zr = cr, zi = ci;
    int n;
    for (n = 0; n < maxit; n++) {
        if (PRECHK(zr, zi)) break;
        int32_t zr2 = fix_mul(zr, zr);
        int32_t zi2 = fix_mul(zi, zi);
        if (zr2 + zi2 > ESC) break;
        int32_t nzr = zr2 - zi2 + jcr;
        zi = (fix_mul(zr, zi) << 1) + jci;
        zr = nzr;
    }
    return n > 255 ? 255 : n;
}

static int selftest(void) {
    struct { double a, b; } cases[] = {
        {1.5, 2.0}, {-1.5, 2.0}, {0.25, 0.25}, {-0.1, -0.1},
        {1.999, 1.999}, {0.0, 3.0}, {-2.0, -2.0}, {0.5, -0.5}
    };
    int i, fails = 0, nc = (int)(sizeof(cases) / sizeof(cases[0]));
    for (i = 0; i < nc; i++) {
        int32_t got = fix_mul(dtofix(cases[i].a), dtofix(cases[i].b));
        double want = cases[i].a * cases[i].b;
        double err = fabs((double)got / (double)(1 << FBITS) - want);
        if (err > 1.0 / 64.0) {   /* ~2e-3: a few Q12 LSBs (truncating >>12) */
            printf("FAIL %g*%g got %g want %g\n", cases[i].a, cases[i].b,
                   (double)got / (double)(1 << FBITS), want);
            fails++;
        }
    }
    if (!fails) fprintf(stderr, "selftest: %d/%d ok\n", nc, nc);
    return fails;
}

static void emit(int julia, int32_t cr0, int32_t ci0, int32_t step,
                 int w, int h, int maxit, int32_t jcr, int32_t jci) {
    int px, py;
    int32_t ci = ci0;
    for (py = 0; py < h; py++, ci += step) {
        int32_t cr = cr0;
        for (px = 0; px < w; px++, cr += step) {
            int v = julia ? julia_iter(cr, ci, jcr, jci, maxit)
                          : mandel_iter(cr, ci, maxit);
            putchar((unsigned char)v);
        }
    }
}

/* djb2 checksum over the streamed iteration bytes -- MUST be bit-identical to
 * the FGX fractal --sum path (32-bit long, h = h*33 + byte). Printed as %ld so
 * the on-device screen_contains golden matches exactly. */
static void checksum(int32_t cr0, int32_t ci0, int32_t step,
                     int w, int h, int maxit) {
    int px, py;
    int32_t ci = ci0;
    int32_t sum = 5381;
    for (py = 0; py < h; py++, ci += step) {
        int32_t cr = cr0;
        for (px = 0; px < w; px++, cr += step) {
            int v = mandel_iter(cr, ci, maxit);
            sum = ((sum << 5) + sum) + v;   /* sum*33 + v, 32-bit wrap */
        }
    }
    printf("ITSUM=%ld\n", (long)sum);
}

/* Mode-aware checksum: mode 1 julia (uses jcr/jci), 2 tricorn, 3 ship,
 * 4 cubic. Same djb2 stream as checksum(). */
static void checksum_mode(int mode, int32_t cr0, int32_t ci0, int32_t step,
                          int w, int h, int maxit, int32_t jcr, int32_t jci) {
    int px, py, v;
    int32_t ci = ci0;
    int32_t sum = 5381;
    for (py = 0; py < h; py++, ci += step) {
        int32_t cr = cr0;
        for (px = 0; px < w; px++, cr += step) {
            switch (mode) {
            case 1:  v = julia_iter(cr, ci, jcr, jci, maxit); break;
            case 2:  v = tricorn_iter(cr, ci, maxit); break;
            case 3:  v = ship_iter(cr, ci, maxit); break;
            case 4:  v = cubic_iter(cr, ci, maxit); break;
            default: v = mandel_iter(cr, ci, maxit); break;
            }
            sum = ((sum << 5) + sum) + v;
        }
    }
    printf("ITSUM=%ld\n", (long)sum);
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--selftest")) return selftest();
    if (argc == 8 && !strcmp(argv[1], "--sum-tri")) {
        checksum_mode(2, atol(argv[2]), atol(argv[3]), atol(argv[4]),
                      atoi(argv[5]), atoi(argv[6]), atoi(argv[7]), 0, 0);
        return 0;
    }
    if (argc == 8 && !strcmp(argv[1], "--sum-ship")) {
        checksum_mode(3, atol(argv[2]), atol(argv[3]), atol(argv[4]),
                      atoi(argv[5]), atoi(argv[6]), atoi(argv[7]), 0, 0);
        return 0;
    }
    if (argc == 8 && !strcmp(argv[1], "--sum-cubic")) {
        checksum_mode(4, atol(argv[2]), atol(argv[3]), atol(argv[4]),
                      atoi(argv[5]), atoi(argv[6]), atoi(argv[7]), 0, 0);
        return 0;
    }
    if (argc == 10 && !strcmp(argv[1], "--sum-julia")) {
        checksum_mode(1, atol(argv[2]), atol(argv[3]), atol(argv[4]),
                      atoi(argv[5]), atoi(argv[6]), atoi(argv[7]),
                      atol(argv[8]), atol(argv[9]));
        return 0;
    }
    if (argc == 8 && !strcmp(argv[1], "--raw")) {
        emit(0, (int32_t)atol(argv[2]), (int32_t)atol(argv[3]),
             (int32_t)atol(argv[4]), atoi(argv[5]), atoi(argv[6]),
             atoi(argv[7]), 0, 0);
        return 0;
    }
    if (argc == 8 && !strcmp(argv[1], "--sum")) {
        checksum((int32_t)atol(argv[2]), (int32_t)atol(argv[3]),
                 (int32_t)atol(argv[4]), atoi(argv[5]), atoi(argv[6]),
                 atoi(argv[7]));
        return 0;
    }
    if (argc == 8 && !strcmp(argv[1], "--interior-diff")) {
        return interior_diff((int32_t)atol(argv[2]), (int32_t)atol(argv[3]),
                             (int32_t)atol(argv[4]), atoi(argv[5]),
                             atoi(argv[6]), atoi(argv[7]));
    }
    if (argc == 10 && !strcmp(argv[1], "--raw-julia")) {
        emit(1, (int32_t)atol(argv[2]), (int32_t)atol(argv[3]),
             (int32_t)atol(argv[4]), atoi(argv[5]), atoi(argv[6]),
             atoi(argv[7]), (int32_t)atol(argv[8]), (int32_t)atol(argv[9]));
        return 0;
    }
    fprintf(stderr,
        "usage: %s --selftest\n"
        "       %s --raw cr0 ci0 step w h maxit\n"
        "       %s --raw-julia cr0 ci0 step w h maxit jcr jci\n",
        argv[0], argv[0], argv[0]);
    return 2;
}
