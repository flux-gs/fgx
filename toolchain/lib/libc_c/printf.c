/* ---- printf family (C5 — the finale) -------------------------------------
 * Real variadic C over <stdarg.h>; callers push right-to-left on the bank-0
 * hardware stack.
 *
 * The conversion semantics are a faithful transcription of that engine —
 * they are what the pinned fixtures (M34/pfsign G-PF2, M28/f_*) verify
 * against host printf:
 *   %s %c %d %u %o %x %X %f %e %g %% + flags '-'/'0', width, .precision
 *   (each literal-accumulated mod 256 like the engine; '*' consumes an arg),
 *   'l' -> 32-bit d/u/o/x, and 'll' (C99) or 'q' (4.4BSD's quad) -> 64-bit.
 *   %D %U %O are 2.11BSD's long forms of %d %u %o (doprnt.s swtab:
 *   `long; 'D', loct; 'O', lunsigned; 'U'), which its sources still use;
 *   %X stays ANSI's upper-case hex rather than the swtab's long hex.
 *   %d/%u/%o/%x are 16-bit (fcc int); precision applies
 *   to %s only; %c ignores width; unknown spec emits '%'+char.  (%o added for
 *   tar(1)'s octal headers.)
 *   G-PF2 sign order: zero-pad -> sign first (-00042); space-pad -> sign
 *   after the pad (   -42); left-justify pads with spaces only.
 *   Floats: sign emitted first with width decremented, magnitude staged and
 *   width-padded; %f/%e emit digit-by-digit ((long)/(int) casts are the
 *   engine's ftol/ftoi) after adding 5 at the first dropped place, which is
 *   2.11BSD cvt()'s round-half-up done in the value; %g generates P+1 digits
 *   and rounds the digit string the same way, picks %f form iff -4 <= X < P,
 *   strips trailing zeros.
 * snprintf is REAL now (the old binding aliased it to sprintf, size
 * ignored): at most sz-1 chars + NUL, returns the would-be length. */

static int      __lc_pf_mode;        /* 0 = fd, 1 = buffer */
static int      __lc_pf_fd;
static char    *__lc_pf_out;         /* buffer mode: dest (caller's bank) */
static unsigned __lc_pf_lim;         /* buffer mode: max chars excl NUL */
static unsigned __lc_pf_n;           /* chars produced (return value) */
static int      __lc_pf_fill;        /* fd mode: bytes staged in fdbuf */
static char     __lc_pf_fdbuf[64];
/* The staged conversion (digits, mantissa).  48 holds any integer; fltpr's
 * %f of a large double runs to fcvt's 78 digits plus the fraction. */
#ifdef FGX_AR_HAVE_fltpr
#define __LC_PF_GBUF 128
#else
#define __LC_PF_GBUF 48
#endif
static char     __lc_pf_gbuf[__LC_PF_GBUF];
static int      __lc_pf_glen;
#ifdef FGX_AR_HAVE_fltpr
void __lc_pf_float();                /* fltpr.c: %e, %f, %g */
#endif

static void __lc_pfc(int c)
{
    if (__lc_pf_mode) {
        if (__lc_pf_n < __lc_pf_lim)
            __lc_pf_out[__lc_pf_n] = c;
    } else {
        __lc_pf_fdbuf[__lc_pf_fill] = c;
        __lc_pf_fill++;
        if (__lc_pf_fill == 64) {
            /* Into the shared per-fd queue, not write(2): putchar and fputc
             * buffer there, and a program mixing them with printf on one
             * stream would otherwise see the two orders interleave.  od, uniq,
             * ul and fold all mix them. */
            (void)__lc_wwrite(__lc_pf_fd, __lc_pf_fdbuf, 64);
            __lc_pf_fill = 0;
        }
    }
    __lc_pf_n++;
}

static void __lc_pf_flush(void)
{
    if (__lc_pf_mode == 0 && __lc_pf_fill > 0) {
        (void)__lc_wwrite(__lc_pf_fd, __lc_pf_fdbuf, __lc_pf_fill);
        __lc_pf_fill = 0;
    }
}

static void __lc_gput(int c)
{
    if (__lc_pf_glen < __LC_PF_GBUF) {
        __lc_pf_gbuf[__lc_pf_glen] = c;
        __lc_pf_glen++;
    }
}

/* emit the staged gbuf with width-pad; neg = deferred '-' (G-PF2 order;
 * the caller already decremented width for it) */
static void __lc_pf_padout(int width, int zeropad, int leftjust, int neg)
{
    int i, pad;

    pad = width - __lc_pf_glen;
    if (pad < 0)
        pad = 0;
    if (leftjust) {
        if (neg) __lc_pfc('-');
        for (i = 0; i < __lc_pf_glen; i++) __lc_pfc(__lc_pf_gbuf[i] & 0xFF);
        while (pad-- > 0) __lc_pfc(' ');
        return;
    }
    if (zeropad) {
        if (neg) __lc_pfc('-');
        while (pad-- > 0) __lc_pfc('0');
        for (i = 0; i < __lc_pf_glen; i++) __lc_pfc(__lc_pf_gbuf[i] & 0xFF);
        return;
    }
    while (pad-- > 0) __lc_pfc(' ');
    if (neg) __lc_pfc('-');
    for (i = 0; i < __lc_pf_glen; i++) __lc_pfc(__lc_pf_gbuf[i] & 0xFF);
}

/* One %e, %f or %g conversion with no floating point printer: a `?', as
 * vendor/2.11BSD/usr/lib/libc/pdp/stdio/ffltpr.s's "Simply output a "?"".
 * The caller has stepped over the double.  Not static: the static links'
 * ffltpr (toolchain/lib/ffltpr.c) stands in for fltpr's __lc_pf_float by
 * calling it. */
void __lc_pf_q(int width, int zeropad, int leftjust)
{
    __lc_pf_glen = 0;
    __lc_gput('?');
    __lc_pf_padout(width, zeropad, leftjust, 0);
}

/* A 32-bit divide is a 32-iteration restoring loop; a 16-bit one is sixteen.
 * Every %d arrives here widened to unsigned long whatever it held, so an
 * ordinary int spent all of its digits in the long loop for nothing.  Peel the
 * high digits in 32-bit ONLY while the value still needs 32 bits, then finish
 * in 16.  A value under 65536 -- which is every int, and most longs anyone
 * prints -- never enters the long loop at all. */
static void __lc_pf_udec(unsigned long v)
{
    char     t[10];
    int      i;
    unsigned w;

    i = 0;
    while (v > 65535L) {
        t[i] = '0' + (int)(v % 10);
        i++;
        v = v / 10;
    }
    w = (unsigned)v;
    for (;;) {
        t[i] = '0' + (int)(w % 10);
        i++;
        w = w / 10;
        if (w == 0)
            break;
    }
    while (i-- > 0)
        __lc_gput(t[i] & 0xFF);
}

static void __lc_pf_uhex(unsigned long v, int upper)
{
    char t[8];
    int  i, d;

    i = 0;
    for (;;) {
        d = (int)(v & 15);
        if (d < 10)     t[i] = '0' + d;
        else if (upper) t[i] = 'A' + d - 10;
        else            t[i] = 'a' + d - 10;
        i++;
        v = v >> 4;
        if (v == 0)
            break;
    }
    while (i-- > 0)
        __lc_gput(t[i] & 0xFF);
}
static void __lc_pf_uoct(unsigned long v)
{
    char t[12];                          /* 2^32 = 037777777777 (11 digits) */
    int  i;

    i = 0;
    for (;;) {
        t[i] = '0' + (int)(v & 7);
        i++;
        v = v >> 3;
        if (v == 0)
            break;
    }
    while (i-- > 0)
        __lc_gput(t[i] & 0xFF);
}

/* A 64-bit value as four 16-bit words, w[0] lowest, divided in place by base
 * (8, 10 or 16); the remainder is returned.  Each step divides a value below
 * base * 65536, so it stays in 32 bits: code in this pile cannot reach the
 * long long runtime, which is a far-called archive. */
static int __lc_pf_qdiv(unsigned *w, int base)
{
    unsigned long cur, r;
    int i;

    r = 0;
    for (i = 3; i >= 0; i--) {
        cur = (r << 16) | w[i];
        w[i] = (unsigned)(cur / base);
        r = cur % base;
    }
    return (int)r;
}

static void __lc_pf_uq(unsigned *w, int base, int upper)
{
    char t[22];                          /* 2^64 - 1 is 22 octal digits */
    int  i, d;

    i = 0;
    do {
        d = __lc_pf_qdiv(w, base);
        if (d < 10)     t[i] = '0' + d;
        else if (upper) t[i] = 'A' + d - 10;
        else            t[i] = 'a' + d - 10;
        i++;
    } while (w[0] | w[1] | w[2] | w[3]);
    while (i-- > 0)
        __lc_gput(t[i] & 0xFF);
}

static int __lc_vpf(char *fmt, char *ap)
{
    int c, width, prec, hasprec, zeropad, leftjust, islong, neg;
    int i, d, len, pad;
    long lv;
    unsigned long uv;
    unsigned qw[4];
    char *s;

    while ((c = *fmt & 0xFF) != 0) {
        fmt++;
        if (c != '%') {
            __lc_pfc(c);
            continue;
        }
        zeropad = 0; leftjust = 0;
        for (;;) {
            c = *fmt & 0xFF;
            if (c == '-')      { leftjust = 1; fmt++; }
            else if (c == '0') { zeropad = 1;  fmt++; }
            else break;
        }
        width = 0;
        if (c == '*') {
            width = va_arg(ap, int);
            fmt++;
        } else {
            while (c >= '0' && c <= '9') {
                width = (width * 10 + (c - '0')) & 0xFF;   /* engine masks */
                fmt++;
                c = *fmt & 0xFF;
            }
        }
        prec = 0; hasprec = 0;
        if ((*fmt & 0xFF) == '.') {
            fmt++;
            hasprec = 1;
            c = *fmt & 0xFF;
            if (c == '*') {
                prec = va_arg(ap, int);
                fmt++;
            } else {
                while (c >= '0' && c <= '9') {
                    prec = (prec * 10 + (c - '0')) & 0xFF;
                    fmt++;
                    c = *fmt & 0xFF;
                }
            }
        }
        islong = 0;
        if ((*fmt & 0xFF) == 'l') {
            islong = 1;
            fmt++;
            if ((*fmt & 0xFF) == 'l') {
                islong = 2;
                fmt++;
            }
        } else if ((*fmt & 0xFF) == 'q') {
            islong = 2;
            fmt++;
        }
        c = *fmt & 0xFF;
        if (c == 0) {                    /* trailing '%': emit it, stop */
            __lc_pfc('%');
            break;
        }
        fmt++;
        if (c == 'D' || c == 'U' || c == 'O') {
            islong = 1;                  /* the long form: %ld %lu %lo */
            c += 'a' - 'A';
        }

        if (c == '%') {
            __lc_pfc('%');
            continue;
        }
        if (c == 'c') {
            __lc_pfc(va_arg(ap, int) & 0xFF);      /* width ignored (engine) */
            continue;
        }
        if (c == 's') {
            s = va_arg(ap, char *);
            len = 0;
            while (s[len] != 0)
                len++;
            if (hasprec && prec < len)
                len = prec;
            pad = width - len;
            if (pad < 0)
                pad = 0;
            if (leftjust) {
                for (i = 0; i < len; i++) __lc_pfc(s[i] & 0xFF);
                while (pad-- > 0) __lc_pfc(' ');
            } else {
                while (pad-- > 0) __lc_pfc(' ');   /* spaces even under '0' */
                for (i = 0; i < len; i++) __lc_pfc(s[i] & 0xFF);
            }
            continue;
        }
        if (islong == 2 && (c == 'd' || c == 'u' || c == 'x' || c == 'X' ||
                            c == 'o')) {
            /* The eight bytes lowest word first, as the caller pushed them;
             * a negative %lld is negated in place, as a long is below. */
            for (i = 0; i < 4; i++)
                qw[i] = va_arg(ap, unsigned);
            neg = 0;
            if (c == 'd' && (qw[3] & 0x8000)) {
                neg = 1;
                for (i = 0; i < 4; i++)
                    qw[i] = ~qw[i];
                for (i = 0; i < 4; i++)
                    if (++qw[i] != 0)
                        break;
                if (width)
                    width--;
            }
            __lc_pf_glen = 0;
            __lc_pf_uq(qw, (c == 'o') ? 8 : (c == 'x' || c == 'X') ? 16 : 10,
                       c == 'X');
            __lc_pf_padout(width, zeropad, leftjust, neg);
            continue;
        }
        if (c == 'd') {
            if (islong) lv = va_arg(ap, long);
            else        lv = (long)va_arg(ap, int);
            neg = 0;
            if (lv < 0) {
                neg = 1;
                lv = -lv;                          /* LONG_MIN wraps: ok */
                if (width)
                    width--;
            }
            __lc_pf_glen = 0;
            __lc_pf_udec((unsigned long)lv);
            __lc_pf_padout(width, zeropad, leftjust, neg);
            continue;
        }
        if (c == 'u') {
            if (islong) uv = va_arg(ap, unsigned long);
            else        uv = (unsigned long)va_arg(ap, unsigned);
            __lc_pf_glen = 0;
            __lc_pf_udec(uv);
            __lc_pf_padout(width, zeropad, leftjust, 0);
            continue;
        }
        if (c == 'x' || c == 'X') {
            if (islong) uv = va_arg(ap, unsigned long);
            else        uv = (unsigned long)va_arg(ap, unsigned);
            __lc_pf_glen = 0;
            __lc_pf_uhex(uv, c == 'X');
            __lc_pf_padout(width, zeropad, leftjust, 0);
            continue;
        }
        if (c == 'o') {
            if (islong) uv = va_arg(ap, unsigned long);
            else        uv = (unsigned long)va_arg(ap, unsigned);
            __lc_pf_glen = 0;
            __lc_pf_uoct(uv);
            __lc_pf_padout(width, zeropad, leftjust, 0);
            continue;
        }
        if (c == 'f' || c == 'F' || c == 'e' || c == 'E' ||
            c == 'g' || c == 'G') {
#ifdef FGX_AR_HAVE_fltpr
            __lc_pf_float(c, va_arg(ap, double), width, prec, hasprec,
                          zeropad, leftjust);
#else
            (void)va_arg(ap, double);
            __lc_pf_q(width, zeropad, leftjust);
#endif
            continue;
        }
        __lc_pfc('%');                   /* unknown spec: verbatim */
        __lc_pfc(c);
    }
    return (int)__lc_pf_n;
}

int printf(char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    __lc_pf_mode = 0; __lc_pf_fd = 1;
    __lc_pf_fill = 0; __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    __lc_pf_flush();
    va_end(ap);
    return r;
}

int fprintf(char *fp, char *fmt, ...)
{
    va_list ap;
    int r;
    int *e = __lc_fent(fp);

    va_start(ap, fmt);
    __lc_pf_mode = 0; __lc_pf_fd = e[0];
    __lc_pf_fill = 0; __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    __lc_pf_flush();
    va_end(ap);
    return r;
}

int sprintf(char *buf, char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = 0xFFFF; __lc_pf_n = 0;    /* unbounded (sprintf contract) */
    r = __lc_vpf(fmt, ap);
    buf[__lc_pf_n] = 0;
    va_end(ap);
    return r;
}

/* vfprintf/vprintf: fprintf and printf over a caller-built va_list.  Each is
 * its variadic sibling above with the va_start/va_end pair removed -- the
 * engine has always been __lc_vpf, which takes the list; only the wrappers
 * were missing.  err(3) is what wanted them (verr/vwarn call vfprintf), and
 * they are the half of the printf family every BSD source assumes. */
int vfprintf(char *fp, char *fmt, char *ap)
{
    int r;
    int *e = __lc_fent(fp);

    __lc_pf_mode = 0; __lc_pf_fd = e[0];
    __lc_pf_fill = 0; __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    __lc_pf_flush();
    return r;
}

int vprintf(char *fmt, char *ap)
{
    int r;

    __lc_pf_mode = 0; __lc_pf_fd = 1;
    __lc_pf_fill = 0; __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    __lc_pf_flush();
    return r;
}

/* vsprintf: sprintf over a caller-built va_list (curses printw/_sprintw —
 * the 4.3BSD `&args` idiom is byte-identical to our va_list under the
 * uniform R-to-L stack ABI). */
int vsprintf(char *buf, char *fmt, char *ap)
{
    int r;

    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = 0xFFFF; __lc_pf_n = 0;    /* unbounded (sprintf contract) */
    r = __lc_vpf(fmt, ap);
    buf[__lc_pf_n] = 0;
    return r;
}

int snprintf(char *buf, int sz, char *fmt, ...)
{
    va_list ap;
    int r;

    va_start(ap, fmt);
    __lc_pf_mode = 1; __lc_pf_out = buf;
    __lc_pf_lim = (sz > 0) ? (unsigned)(sz - 1) : 0;
    __lc_pf_n = 0;
    r = __lc_vpf(fmt, ap);
    if (sz > 0)
        buf[(__lc_pf_n < __lc_pf_lim) ? __lc_pf_n : __lc_pf_lim] = 0;
    va_end(ap);
    return r;
}

