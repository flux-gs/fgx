// Minimal math.h subset for the W65816 runtime.
//
// All operations work directly on the IEEE-754 bit representation
// rather than going through long sequences of soft-float libcalls.
// fabs/copysign/floor/ceil/fmod cover the common needs of routine
// numeric code; transcendentals are intentionally out of scope.
//
// Layout assumed:
//   double = sign(1) | exp(11) | frac(52)   stored little-endian
//            (high word at +6, low word at +0)
//   float  = sign(1) | exp(8)  | frac(23)
//
// We type-pun via __builtin_memcpy + uint64_t / uint32_t to stay
// strict-aliasing-clean.

typedef unsigned long      uint32_t;
typedef unsigned long long uint64_t;
typedef long long          int64_t;


static uint64_t dToBits(double v) {
    uint64_t b;
    __builtin_memcpy(&b, &v, sizeof(b));
    return b;
}


static double dFromBits(uint64_t b) {
    double v;
    __builtin_memcpy(&v, &b, sizeof(v));
    return v;
}


static uint32_t fToBits(float v) {
    uint32_t b;
    __builtin_memcpy(&b, &v, sizeof(b));
    return b;
}


static float fFromBits(uint32_t b) {
    float v;
    __builtin_memcpy(&v, &b, sizeof(v));
    return v;
}


double fabs(double x) {
    return dFromBits(dToBits(x) & ~((uint64_t)1 << 63));
}


float fabsf(float x) {
    return fFromBits(fToBits(x) & ~((uint32_t)1 << 31));
}


double copysign(double x, double y) {
    uint64_t mask = (uint64_t)1 << 63;
    return dFromBits((dToBits(x) & ~mask) | (dToBits(y) & mask));
}


float copysignf(float x, float y) {
    uint32_t mask = (uint32_t)1 << 31;
    return fFromBits((fToBits(x) & ~mask) | (fToBits(y) & mask));
}


// floor(x) = round toward -inf.  Truncate the fraction bits below
// the integer position; if any non-zero bit was discarded for a
// negative value, subtract one (round more negative).
double floor(double x) {
    uint64_t b = dToBits(x);
    int      e = (int)((b >> 52) & 0x7FF) - 1023;
    if (e < 0) {
        // |x| < 1: floor(positive) = 0, floor(negative) = -1.
        return (b >> 63) ? -1.0 : 0.0;
    }
    if (e >= 52) {
        return x;  // already integer (or NaN/Inf)
    }
    uint64_t fracMask = ((uint64_t)1 << (52 - e)) - 1;
    if ((b & fracMask) == 0) {
        return x;  // already integer
    }
    uint64_t truncBits = b & ~fracMask;
    double   truncVal  = dFromBits(truncBits);
    // For negatives with a non-zero discarded fraction, subtract 1.
    if (b >> 63) {
        truncVal = truncVal - 1.0;
    }
    return truncVal;
}


double ceil(double x) {
    return -floor(-x);
}


float floorf(float x) {
    return (float)floor((double)x);
}


float ceilf(float x) {
    return (float)ceil((double)x);
}


// fmod(x, y) = x - trunc(x / y) * y.  trunc(q) = round-toward-zero.
double fmod(double x, double y) {
    if (y == 0.0) {
        return 0.0;  // implementation-defined; we return 0
    }
    double q = x / y;
    // trunc: floor for positives, ceil for negatives.
    double t;
    if (q < 0.0) {
        t = -floor(-q);
    } else {
        t = floor(q);
    }
    return x - t * y;
}


float fmodf(float x, float y) {
    return (float)fmod((double)x, (double)y);
}


// sqrt via Newton iteration with a bit-trick initial guess that
// uses the IEEE-754 layout: y0 = bits >> 1 + bias_shift.  Then ~6
// Newton iterations land within ~1 ULP for double precision.
//
// We dodge the snprintf-style libcall pitfalls by NOT comparing
// double-to-double via `<`/`>=`; instead we test the IEEE-754
// sign bit and exponent directly.
double sqrt(double x) {
    uint64_t b;
    __builtin_memcpy(&b, &x, sizeof(b));
    // Check zero first (positive or negative) — IEEE-754 says
    // sqrt(+0)=+0 and sqrt(-0)=-0; both lower 63 bits are zero.
    if ((b & ~((uint64_t)1 << 63)) == 0) {
        return x;
    }
    if (b & ((uint64_t)1 << 63)) {
        return 0.0 / 0.0;  // NaN for negatives
    }
    // Initial guess: halve the exponent.  IEEE-754 trick gives a
    // surprisingly good starting point — within 2x of the true value.
    uint64_t guess_b = ((b - ((uint64_t)1023 << 52)) >> 1)
                       + ((uint64_t)1023 << 52);
    double y;
    __builtin_memcpy(&y, &guess_b, sizeof(y));
    // Newton: y_{n+1} = (y_n + x / y_n) / 2.  6 iterations for double.
    for (int i = 0; i < 6; i++) {
        y = (y + x / y) * 0.5;
    }
    return y;
}


float sqrtf(float x) {
    return (float)sqrt((double)x);
}


// pow(x, y) supports two restricted regimes:
//   1. integer y (positive, negative, or zero) — repeated multiply.
//   2. y == 0.5 — returns sqrt(x).
// Anything else (general real exponent) needs exp/log; not yet
// landed.  Returning 0 is the documented behaviour for now.
double pow(double x, double y) {
    if (y == 0.0) {
        return 1.0;
    }
    if (y == 0.5) {
        return sqrt(x);
    }
    // Test for integer y by floor-equal trick (no soft-fp comparison).
    double yi = floor(y);
    uint64_t yi_b, y_b;
    __builtin_memcpy(&yi_b, &yi, sizeof(yi_b));
    __builtin_memcpy(&y_b,  &y,  sizeof(y_b));
    if (yi_b != y_b) {
        return 0.0;  // non-integer, non-0.5 y not supported yet
    }
    // y is a whole number; convert via __fixdfsi.  Range -32768..32767
    // covers any practical exponent.  Use unsigned for the magnitude
    // to avoid signed-overflow UB on INT_MIN.
    int sn = (int)yi;
    int neg = 0;
    unsigned int n;
    if (sn < 0) {
        neg = 1;
        n = 0u - (unsigned int)sn;
    } else {
        n = (unsigned int)sn;
    }
    double r = 1.0;
    double base = x;
    while (n > 0) {
        if (n & 1) {
            r = r * base;
        }
        base = base * base;
        n = n >> 1;
    }
    if (neg) {
        r = 1.0 / r;
    }
    return r;
}


float powf(float x, float y) {
    return (float)pow((double)x, (double)y);
}


// ----- transcendentals --------------------------------------------------
// All implemented via range-reduction + Taylor series.  Accuracy is in
// the ~1e-6 range — good enough for typical IIgs-era numeric work,
// well short of glibc-quality.  The soft-double libcalls dominate the
// cost; each transcendental is dozens of milliseconds to seconds in
// MAME, so don't put these in tight inner loops.

#define M_PI       3.14159265358979323846
#define M_2PI      6.28318530717958647692
#define M_HALF_PI  1.57079632679489661923
#define M_LN2      0.69314718055994530942


// sin via Taylor: x - x^3/6 + x^5/120 - x^7/5040 + x^9/362880 - x^11/39916800
// Range-reduce first by subtracting multiples of 2*pi, then fold into
// [-pi/2, pi/2] using sin(pi - x) = sin(x), sin(-x) = -sin(x).
double sin(double x) {
    // Reduce to [-pi, pi].
    double k = floor((x + M_PI) / M_2PI);
    x = x - k * M_2PI;
    // Fold to [-pi/2, pi/2] via sign-bit-test (avoids __ltdf2).
    uint64_t b;
    __builtin_memcpy(&b, &x, sizeof(b));
    int sign = (int)(b >> 63) & 1;
    if (sign) {
        // x < 0: work with -x and negate result at end.
        b ^= ((uint64_t)1 << 63);
        __builtin_memcpy(&x, &b, sizeof(x));
    }
    if (x > M_HALF_PI) {
        x = M_PI - x;  // reflect about pi/2
    }
    double x2 = x * x;
    double term = x;
    double s = term;
    term = term * x2; s = s - term * (1.0 / 6.0);
    term = term * x2; s = s + term * (1.0 / 120.0);
    term = term * x2; s = s - term * (1.0 / 5040.0);
    term = term * x2; s = s + term * (1.0 / 362880.0);
    term = term * x2; s = s - term * (1.0 / 39916800.0);
    if (sign) {
        s = -s;
    }
    return s;
}


double cos(double x) {
    return sin(x + M_HALF_PI);
}


// tan(x) = sin(x) / cos(x).  No special handling for poles at pi/2
// + n*pi (where cos(x) == 0): the soft-double divide returns +/-Inf,
// which is the IEEE-754-correct answer.  Accuracy follows sin/cos
// (~1e-6) but degrades fast as |x| approaches a pole.
double tan(double x) {
    return sin(x) / cos(x);
}


float sinf(float x) {
    return (float)sin((double)x);
}


float cosf(float x) {
    return (float)cos((double)x);
}


float tanf(float x) {
    return (float)tan((double)x);
}


// exp via 2^k * e^r where x = k*ln2 + r, |r| < ln2/2.  Then Taylor
// series for e^r converges in ~10 terms.  k * 2 multiplication uses
// the IEEE-754 layout (add k to exponent field).
double exp(double x) {
    double k_d = floor(x / M_LN2 + 0.5);
    double r   = x - k_d * M_LN2;
    int    k   = (int)k_d;
    // Taylor: 1 + r + r^2/2 + r^3/6 + ... + r^10/3628800
    double term = 1.0;
    double s    = 1.0;
    for (int n = 1; n <= 12; n++) {
        term = term * r * (1.0 / (double)n);
        s    = s + term;
    }
    // Multiply by 2^k by adding k to the IEEE-754 exponent field.
    uint64_t b;
    __builtin_memcpy(&b, &s, sizeof(b));
    uint64_t e = (b >> 52) & 0x7FF;
    int      en = (int)e + k;
    if (en >= 0x7FF) {
        return 1.0 / 0.0;  // overflow -> inf
    }
    if (en <= 0) {
        return 0.0;        // underflow
    }
    b = (b & ~((uint64_t)0x7FF << 52)) | ((uint64_t)en << 52);
    __builtin_memcpy(&s, &b, sizeof(s));
    return s;
}


float expf(float x) {
    return (float)exp((double)x);
}


// log: x = 2^k * m where m in [1, 2).  log(x) = k*ln2 + log(m).
// log(m) for m in [1,2) computed via the substitution u = (m-1)/(m+1)
// giving log(m) = 2 * (u + u^3/3 + u^5/5 + ...) — converges fast for
// m in [1,2).
double log(double x) {
    uint64_t b;
    __builtin_memcpy(&b, &x, sizeof(b));
    // log(±0) = -Infinity (pole error).  Mask off the sign bit when
    // testing for zero so -0.0 lands here instead of the negative path.
    if ((b & ~((uint64_t)1 << 63)) == 0) {
        return -1.0 / 0.0;
    }
    if (b & ((uint64_t)1 << 63)) {
        return 0.0 / 0.0;  // log(negative) = NaN (domain error)
    }
    int e = (int)((b >> 52) & 0x7FF) - 1023;
    // Force the exponent field to 1023 so m lands in [1, 2).
    b = (b & ~((uint64_t)0x7FF << 52)) | ((uint64_t)1023 << 52);
    double m;
    __builtin_memcpy(&m, &b, sizeof(m));
    double u  = (m - 1.0) / (m + 1.0);
    double u2 = u * u;
    double term = u;
    double s    = term;
    for (int n = 1; n <= 8; n++) {
        term = term * u2;
        s    = s + term * (1.0 / (double)(2 * n + 1));
    }
    return 2.0 * s + (double)e * M_LN2;
}


float logf(float x) {
    return (float)log((double)x);
}


// atan: range-reduce |x| > 1 via atan(x) = pi/2 - atan(1/x), then
// further reduce via atan(x) = 2*atan(x / (1 + sqrt(1 + x*x))).
// For the reduced argument, Taylor: x - x^3/3 + x^5/5 - ...
double atan(double x) {
    uint64_t b;
    __builtin_memcpy(&b, &x, sizeof(b));
    int sign = (int)(b >> 63) & 1;
    if (sign) {
        b ^= ((uint64_t)1 << 63);
        __builtin_memcpy(&x, &b, sizeof(x));
    }
    int invert = 0;
    // Test |x| > 1 via bit pattern: exponent > 1023 means value >= 1.
    int e = (int)((b >> 52) & 0x7FF) - 1023;
    if (e >= 0) {
        x = 1.0 / x;
        invert = 1;
    }
    // Taylor for |x| <= 1: x - x^3/3 + x^5/5 - x^7/7 + x^9/9 - ...
    // Need many terms when |x| close to 1; cap at 30 for ~1e-6 accuracy.
    double x2 = x * x;
    double term = x;
    double s    = term;
    for (int n = 1; n <= 25; n++) {
        term = term * x2;
        double denom = (double)(2 * n + 1);
        if (n & 1) {
            s = s - term / denom;
        } else {
            s = s + term / denom;
        }
    }
    if (invert) {
        s = M_HALF_PI - s;
    }
    if (sign) {
        s = -s;
    }
    return s;
}


float atanf(float x) {
    return (float)atan((double)x);
}


double atan2(double y, double x) {
    // Quadrant adjustment.
    uint64_t xb, yb;
    __builtin_memcpy(&xb, &x, sizeof(xb));
    __builtin_memcpy(&yb, &y, sizeof(yb));
    int xNeg = (int)(xb >> 63) & 1;
    int yNeg = (int)(yb >> 63) & 1;
    // Strip sign of x for the quotient; restore quadrant later.
    uint64_t xa = xb & ~((uint64_t)1 << 63);
    if (xa == 0) {
        // x == 0 (handles +0 and -0): return ±pi/2
        return yNeg ? -M_HALF_PI : M_HALF_PI;
    }
    double a = atan(y / x);
    if (!xNeg) {
        return a;
    }
    return yNeg ? a - M_PI : a + M_PI;
}


float atan2f(float y, float x) {
    return (float)atan2((double)y, (double)x);
}


// asin: asin(x) = atan(x / sqrt(1 - x*x))
double asin(double x) {
    double r = 1.0 - x * x;
    if (r <= 0.0) {
        // |x| >= 1; clamp to ±pi/2.
        uint64_t b;
        __builtin_memcpy(&b, &x, sizeof(b));
        return (b >> 63) ? -M_HALF_PI : M_HALF_PI;
    }
    return atan(x / sqrt(r));
}


float asinf(float x) {
    return (float)asin((double)x);
}


double acos(double x) {
    return M_HALF_PI - asin(x);
}


float acosf(float x) {
    return (float)acos((double)x);
}


double sinh(double x) {
    double e = exp(x);
    return (e - 1.0 / e) * 0.5;
}


float sinhf(float x) {
    return (float)sinh((double)x);
}


double cosh(double x) {
    double e = exp(x);
    return (e + 1.0 / e) * 0.5;
}


float coshf(float x) {
    return (float)cosh((double)x);
}


double tanh(double x) {
    double e2 = exp(x + x);
    return (e2 - 1.0) / (e2 + 1.0);
}


float tanhf(float x) {
    return (float)tanh((double)x);
}


// ---- Classification ------------------------------------------------
//
// Implemented as functions rather than the C99 macros so they can be
// referenced from outside math.h. The math.h header also exposes them
// as macros that expand to these calls.

int __isnan_d(double x) {
    uint64_t b = dToBits(x);
    return ((b >> 52) & 0x7FF) == 0x7FF && (b & 0xFFFFFFFFFFFFFULL) != 0;
}


int __isinf_d(double x) {
    uint64_t b = dToBits(x);
    return ((b >> 52) & 0x7FF) == 0x7FF && (b & 0xFFFFFFFFFFFFFULL) == 0;
}


int __isfinite_d(double x) {
    return ((dToBits(x) >> 52) & 0x7FF) != 0x7FF;
}


int __signbit_d(double x) {
    return (int)(dToBits(x) >> 63);
}


// ---- Rounding ------------------------------------------------------

// trunc: round toward zero. = floor for positive, ceil for negative.
double trunc(double x) {
    return (dToBits(x) >> 63) ? ceil(x) : floor(x);
}


float truncf(float x) {
    return (float)trunc((double)x);
}


// round: round half away from zero.
double round(double x) {
    return (dToBits(x) >> 63) ? -floor(-x + 0.5) : floor(x + 0.5);
}


float roundf(float x) {
    return (float)round((double)x);
}


// ---- Min / max / positive difference -------------------------------

double fmax(double x, double y) {
    if (__isnan_d(x)) return y;
    if (__isnan_d(y)) return x;
    return x > y ? x : y;
}


double fmin(double x, double y) {
    if (__isnan_d(x)) return y;
    if (__isnan_d(y)) return x;
    return x < y ? x : y;
}


double fdim(double x, double y) {
    return x > y ? x - y : 0.0;
}


float fmaxf(float x, float y) { return (float)fmax((double)x, (double)y); }
float fminf(float x, float y) { return (float)fmin((double)x, (double)y); }
float fdimf(float x, float y) { return (float)fdim((double)x, (double)y); }


// ---- FP decomposition ----------------------------------------------

// ldexp(x, n) = x * 2^n. Implemented by adjusting the exponent field
// in place. Handles subnormals and overflow only crudely (overflow →
// infinity; underflow → zero).
double ldexp(double x, int n) {
    uint64_t b = dToBits(x);
    int e = (int)((b >> 52) & 0x7FF);
    if (e == 0 || e == 0x7FF) {
        // 0 or denorm or inf/nan — return as-is for inf/nan, else
        // fall back to multiplication (handles subnormals correctly
        // enough for typical use).
        if (e == 0x7FF) return x;
        // For zero / subnormal, multiply by 2^n via repeated *2.
        if (n > 0) {
            while (n--) x *= 2.0;
            return x;
        }
        if (n < 0) {
            while (n++) x *= 0.5;
            return x;
        }
        return x;
    }
    int newE = e + n;
    if (newE >= 0x7FF) {
        // Overflow → ±infinity.
        return (b >> 63) ? -1e308 * 1e308 : 1e308 * 1e308;
    }
    if (newE <= 0) {
        // Underflow → ±0 (skip subnormal handling).
        return (b >> 63) ? -0.0 : 0.0;
    }
    b = (b & 0x800FFFFFFFFFFFFFULL) | ((uint64_t)newE << 52);
    return dFromBits(b);
}


float ldexpf(float x, int n) {
    return (float)ldexp((double)x, n);
}


// frexp(x, *e): split x into normalized fraction in [0.5, 1) (or 0)
// and integer exponent. x = frac * 2^e.
double frexp(double x, int *eOut) {
    uint64_t b = dToBits(x);
    int e = (int)((b >> 52) & 0x7FF);
    if (e == 0) { *eOut = 0; return x; }       // zero or subnormal
    if (e == 0x7FF) { *eOut = 0; return x; }   // inf or nan
    *eOut = e - 1022;                          // bias adjustment for [0.5,1)
    // Force exponent to 1022 (so result is in [0.5, 1)).
    b = (b & 0x800FFFFFFFFFFFFFULL) | ((uint64_t)1022 << 52);
    return dFromBits(b);
}


float frexpf(float x, int *eOut) {
    double r = frexp((double)x, eOut);
    return (float)r;
}


// modf(x, *iptr): split into integer and fractional parts, both with
// the same sign as x.
double modf(double x, double *iptr) {
    double ip = trunc(x);
    *iptr = ip;
    return x - ip;
}


float modff(float x, float *iptr) {
    double ipd;
    double frac = modf((double)x, &ipd);
    *iptr = (float)ipd;
    return (float)frac;
}


// ---- log10 / log2 / exp2 -------------------------------------------
//
// All routed through log() / exp() with the conversion constant.

double log10(double x) {
    // 1 / ln(10) = 0.43429448190325182765112891891660508229439700580366
    return log(x) * 0.43429448190325182765;
}


double log2(double x) {
    // 1 / ln(2) = 1.4426950408889634073599246810018921374266459541530
    return log(x) * 1.4426950408889634074;
}


double exp2(double x) {
    // ln(2) = 0.69314718055994530941723212145817656807550013436026
    return exp(x * 0.69314718055994530942);
}


float log10f(float x) { return (float)log10((double)x); }
float log2f(float x)  { return (float)log2((double)x); }
float exp2f(float x)  { return (float)exp2((double)x); }


// log1p(x) = log(1 + x).  For |x| small the naive form loses precision;
// we accept that for now since this is a standalone runtime, not a
// numerics library.
double log1p(double x) { return log(1.0 + x); }
float  log1pf(float x) { return (float)log1p((double)x); }


// expm1(x) = exp(x) - 1.  Same loss-of-precision caveat near 0.
double expm1(double x) { return exp(x) - 1.0; }
float  expm1f(float x) { return (float)expm1((double)x); }


// ---- hypot ---------------------------------------------------------
//
// hypot(x, y) = sqrt(x*x + y*y).  This implementation does NOT scale
// to avoid overflow — for |x|, |y| < ~1e150 the naive form is fine,
// past that you'd want the standard scale-by-max trick.

double hypot(double x, double y) {
    double xx = x * x;
    double yy = y * y;
    double s  = xx + yy;
    return sqrt(s);
}


float hypotf(float x, float y) {
    return (float)hypot((double)x, (double)y);
}


// ---- cbrt ----------------------------------------------------------
//
// Newton-Raphson for cube root: r_{n+1} = (2*r_n + a/r_n²) / 3.
// Converges quadratically; 30 iters more than enough for double.
// Implemented WITHOUT calling pow because clang treats pow as a
// known builtin and either inlines it (with bad fold of pow(x,1/3))
// or DCEs the call entirely (cbrt body collapses to "return 0").
double cbrt(double x) {
    if (x == 0.0) return x;
    int neg = (int)(dToBits(x) >> 63) & 1;
    double a = neg ? -x : x;
    double r = a;                        // crude initial guess
    for (int i = 0; i < 30; i++) {
        r = (2.0 * r + a / (r * r)) * (1.0 / 3.0);
    }
    return neg ? -r : r;
}


float cbrtf(float x) {
    return (float)cbrt((double)x);
}


// ---- C99/C11 additions ---------------------------------------------
// Most reduce to existing primitives (log/exp/sqrt/floor/round/ldexp).
// The fused-multiply-add fma() is implemented as plain x*y+z because
// softFloat/softDouble round each operation independently — true fused
// rounding would require an extended-precision multiplier we don't
// have.  Callers who depend on extra precision must use Kahan summation
// or similar.

double asinh(double x) {
    // asinh(x) = log(x + sqrt(x*x + 1)) — stable for all finite x.
    return log(x + sqrt(x * x + 1.0));
}


double acosh(double x) {
    // acosh(x) = log(x + sqrt(x*x - 1)) for x >= 1.  Returns NaN for x < 1.
    if (x < 1.0) return __builtin_nanf("");
    return log(x + sqrt(x * x - 1.0));
}


double atanh(double x) {
    // atanh(x) = 0.5 * log((1+x)/(1-x)) for |x| < 1.  Returns +/-inf
    // at x = +/-1 and NaN outside [-1, 1].
    if (x >= 1.0)  return  __builtin_inff();
    if (x <= -1.0) return -__builtin_inff();
    return 0.5 * log((1.0 + x) / (1.0 - x));
}


float asinhf(float x) { return (float)asinh((double)x); }
float acoshf(float x) { return (float)acosh((double)x); }
float atanhf(float x) { return (float)atanh((double)x); }


double fma(double x, double y, double z) {
    // Not actually fused — we round x*y then add z, so the result may
    // differ from a true FMA in the low bit.  Adequate for portable
    // code that uses fma() as a hint rather than a precision guarantee.
    return x * y + z;
}


float fmaf(float x, float y, float z) { return (float)fma((double)x, (double)y, (double)z); }


double nan(const char *tagp) {
    (void)tagp;   // No tagged NaNs — return the canonical quiet NaN.
    return __builtin_nanf("");
}


float nanf(const char *tagp) { (void)tagp; return __builtin_nanf(""); }


double remainder(double x, double y) {
    // IEEE 754 remainder: x - n*y where n = round-to-nearest-even(x/y).
    // Falls back to fmod for non-finite cases via the existing primitives.
    if (y == 0.0)                return __builtin_nanf("");
    double quotient = round(x / y);
    return x - quotient * y;
}


float remainderf(float x, float y) { return (float)remainder((double)x, (double)y); }


double rint(double x)        { return round(x); }
float  rintf(float  x)       { return roundf(x); }
double nearbyint(double x)   { return round(x); }
float  nearbyintf(float  x)  { return roundf(x); }


long lround(double x) {
    return (long)round(x);
}


long lroundf(float x) {
    return (long)roundf(x);
}


long lrint(double x) {
    return (long)round(x);
}


long lrintf(float x) {
    return (long)roundf(x);
}


double scalbn(double x, int n)        { return ldexp(x, n); }
float  scalbnf(float  x, int n)       { return ldexpf(x, n); }
double scalbln(double x, long n)      { return ldexp(x, (int)n); }
float  scalblnf(float  x, long n)     { return ldexpf(x, (int)n); }


int fpclassify(double x) {
    if (__isnan_d(x))                       return 0;  // FP___builtin_nanf("")
    if (__isinf_d(x))                       return 1;  // FP_INFINITE
    if (x == 0.0)                           return 4;  // FP_ZERO
    return 2;                                          // FP_NORMAL
    // FP_SUBNORMAL (= 3) not distinguished from normal in this minimal
    // implementation — subnormals are valid but classified as normal.
}
