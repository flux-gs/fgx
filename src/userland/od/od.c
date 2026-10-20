/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD od(1)
 *   Ported from od(1), 2.11BSD (od.c 5.12, Berkeley, 5/14/84).
 *   Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * od -- octal, hex, decimal, character, float dump of a file.
 *
 * usage: od [-abcdDeFfhHiIlLoOpPvxX] [-s[n]] [-w[n]] [file] [[+]offset[.][b] [label]]
 *
 *   a  ASCII named bytes      b  byte octal        c  char (octal escapes)
 *   d  u short decimal        D  u long decimal    e,F double   f  float
 *   h,x u short hex           H,X u long hex        i  short signed dec
 *   I,l,L long signed dec     o,B u short octal (default)        O  u long octal
 *   p/P  even/odd parity (with -a)   s[n] strings   v  show all (no '*')
 *   w[n] bytes per line
 *
 * Faithful port of 2.11BSD od.c; behaviour and option set are unchanged.
 * FGX / fcc adaptations (no user-visible feature loss):
 *  - char classification comes from <ctype.h> instead of od's private
 *    _ctype[256] table.
 *  - reads through a local input FILE* `in` instead of freopen()-onto-stdin
 *    (no freopen in libc); stdin when no file operand.
 *  - the conv_vec dispatch table (struct dfmt with a function-pointer member)
 *    is built at runtime in init_formats() — fcc has no static initializer for
 *    a struct field of function-pointer type; and each indirect call copies
 *    the field into a local fn-ptr first (fcc parses `fp=d->df_put; fp(...)`
 *    but not `d->df_put(...)`).
 *  - +offset seeks via fseek when the input is a real file, else read-skips
 *    (dumbseek) — replaces canseek()/fstat()/isatty().
 *  - fcc double == float == 32-bit IEEE single, so -e/-F dump 4-byte objects
 *    (df_size = sizeof(double) = 4) and print float precision.
 */
#include <stdio.h>
#include <ctype.h>

int   memcmp(char *a, char *b, int n);
int   strlen(char *s);
void  exit(int code);
int   fillbuf(char *buf, int max, FILE *fp);

#define NO        0
#define YES       1
#define EVEN     -1
#define ODD       1
#define UNSIGNED  0
#define SIGNED    1
#define PADDR     1
#define MIN_SLEN  3
#define BIG_DBUF  32
#define DBUF_SIZE 1024
#define MAXINTLEN 32

struct dfmt {
    int   df_field;    /* external field width for one object */
    int   df_size;     /* size (bytes) of object */
    int   df_radix;    /* conversion radix */
    int   df_signed;   /* signed? */
    int   df_paddr;    /* address on each line? */
    int   df_putid;    /* index into put_table[] (fcc binds fn-ptrs only in an
                        * array initializer, not a struct field) */
    int   df_pad;      /* leading spaces before each object (column alignment).
                        * fcc's printf/sprintf mishandle a RUNTIME format
                        * pointer, so od emits `padsp(df_pad)` + fputs(str)
                        * instead of BSD's printf(d->df_fmt="…spaces…%s", str). */
};

int a_put(char *cc, struct dfmt *d);
int b_put(char *b, struct dfmt *d);
int c_put(char *cc, struct dfmt *d);
int s_put(char *n, struct dfmt *d);
int us_put(char *n, struct dfmt *d);
int l_put(char *n, struct dfmt *d);
int f_put(char *f, struct dfmt *d);
int d_put(char *f, struct dfmt *d);
int st_put(char *cc, struct dfmt *d);

/* The conversion dispatch — an initialized array of function pointers (the one
 * fcc-supported fn-ptr binding); dfmt.df_putid indexes it. */
#define P_A  0
#define P_B  1
#define P_C  2
#define P_US 3
#define P_L  4
#define P_S  5
#define P_F  6
#define P_D  7
#define P_ST 8
int (*put_table[])() = {
    a_put, b_put, c_put, us_put, l_put, s_put, f_put, d_put, st_put
};

/* The thirteen conversion descriptors (filled by init_formats). */
struct dfmt ascii, byte, cchar, u_s_oct, u_s_dec, u_s_hex;
struct dfmt u_l_oct, u_l_dec, u_l_hex, s_s_dec, s_l_dec, flt, dble, string;

struct dfmt *conv_vec[32];   /* the conversions requested */

char  usage[] = "usage: od [-abcdfhilopsvwxD] [file] [[+]offset[.][b] [label]]";
char  dbuf[DBUF_SIZE];
char  lastdbuf[DBUF_SIZE];
int   addr_base = 8;         /* default address radix is octal */
long  addr = 0;              /* current file offset */
long  label = -1;            /* current label; -1 = off */
int   dbuf_size = 16;        /* file bytes per display line */
int   _parity = NO;
char *_digit = "0123456789abcdef";

FILE *in;                    /* input stream */
int   in_is_file = 0;        /* +offset: fseek vs read-skip */

char  _icv_buf[33];          /* MAXINTLEN + 1 (fcc array dims must be literal) */
long  _mask = 0x7fffffff;

char *icvt(long value, int radix, int sgn, int ndigits);
char *scvt(int c, struct dfmt *d);
char *underline(char *s);
long  get_addr(char *s);
void  put_addr(long a, long l, int c);
void  line(int n);
void  offset(long a);
void  dumbseek(long off);
int   parity(int word);

/* od emits '\n'; libc translates LF->CR for the console. */
int putch(int c)
{
    fputc(c, stdout);
    return c;
}

int puts(char *s)
{
    fputs(s, stdout);
    fputc('\n', stdout);
    return 0;
}

/* ASCII control-byte names for -a (indices 0..33: 0..037, sp, del). */
char *asc_name[34] = {
    "nul", "soh", "stx", "etx", "eot", "enq", "ack", "bel",
    " bs", " ht", " nl", " vt", " ff", " cr", " so", " si",
    "dle", "dc1", "dc2", "dc3", "dc4", "nak", "syn", "etb",
    "can", " em", "sub", "esc", " fs", " gs", " rs", " us",
    " sp", "del"
};

void set_dfmt(struct dfmt *d, int field, int size, int radix,
              int sgn, int paddr, int putid)
{
    d->df_field  = field;
    d->df_size   = size;
    d->df_radix  = radix;
    d->df_signed = sgn;
    d->df_paddr  = paddr;
    d->df_putid  = putid;
    d->df_pad    = 0;
}

/* emit n spaces (column alignment; replaces BSD's leading-space printf fmt). */
void padsp(int n)
{
    while (n-- > 0)
        putch(' ');
}

/* one column: df_pad leading spaces then the object string s (replaces
 * BSD's printf(d->df_fmt, s) — fcc mishandles a runtime format pointer). */
void emit_field(struct dfmt *d, char *s)
{
    padsp(d->df_pad);
    fputs(s, stdout);
}

void init_formats(void)
{
    set_dfmt(&ascii,    3, 1, 10, 0,        PADDR, P_A);
    set_dfmt(&byte,     3, 1,  8, UNSIGNED, PADDR, P_B);
    set_dfmt(&cchar,    3, 1,  8, UNSIGNED, PADDR, P_C);
    set_dfmt(&u_s_oct,  6, 2,  8, UNSIGNED, PADDR, P_US);
    set_dfmt(&u_s_dec,  5, 2, 10, UNSIGNED, PADDR, P_US);
    set_dfmt(&u_s_hex,  4, 2, 16, UNSIGNED, PADDR, P_US);
    set_dfmt(&u_l_oct, 11, 4,  8, UNSIGNED, PADDR, P_L);
    set_dfmt(&u_l_dec, 10, 4, 10, UNSIGNED, PADDR, P_L);
    set_dfmt(&u_l_hex,  8, 4, 16, UNSIGNED, PADDR, P_L);
    set_dfmt(&s_s_dec,  6, 2, 10, SIGNED,   PADDR, P_S);
    set_dfmt(&s_l_dec, 11, 4, 10, SIGNED,   PADDR, P_L);
    set_dfmt(&flt,     14, 4, 10, SIGNED,   PADDR, P_F);
    set_dfmt(&dble,    21, 4, 10, SIGNED,   PADDR, P_D);  /* double==float */
    set_dfmt(&string,   0, 0,  8, 0,        NO,    P_ST);
}

int main(int argc, char **argv)
{
    char *p;
    char *l;
    int   n, same;
    struct dfmt  *d;
    struct dfmt **cv;
    int   showall = NO;
    int   field, llen, nelm;
    int   max_llen = 0;

    init_formats();
    addr = 0;            /* set here, not via global init (fcc negative/long */
    label = -1;          /* global initializers are unreliable) */
    d  = &u_s_oct;
    cv = conv_vec;

    argv++;
    argc--;

    if (argc > 0) {
        p = *argv;
        if (*p == '-') {
            while (*++p != '\0') {
                switch (*p) {
                case 'a': d = &ascii;   break;
                case 'b': d = &byte;    break;
                case 'c': d = &cchar;   break;
                case 'd': d = &u_s_dec; break;
                case 'D': d = &u_l_dec; break;
                case 'e':
                case 'F': d = &dble;    break;
                case 'f': d = &flt;     break;
                case 'h':
                case 'x': d = &u_s_hex; break;
                case 'H':
                case 'X': d = &u_l_hex; break;
                case 'i': d = &s_s_dec; break;
                case 'I':
                case 'l':
                case 'L': d = &s_l_dec; break;
                case 'o':
                case 'B': d = &u_s_oct; break;
                case 'O': d = &u_l_oct; break;
                case 'p': _parity = EVEN; continue;
                case 'P': _parity = ODD;  continue;
                case 's':
                    d = &string;
                    *(cv++) = d;
                    while (isdigit(p[1]))
                        d->df_size = (10 * d->df_size) + (*++p - '0');
                    if (d->df_size <= 0)
                        d->df_size = MIN_SLEN;
                    showall = YES;
                    continue;
                case 'w':
                    dbuf_size = 0;
                    while (isdigit(p[1]))
                        dbuf_size = (10 * dbuf_size) + (*++p - '0');
                    if (dbuf_size == 0)
                        dbuf_size = BIG_DBUF;
                    continue;
                case 'v':
                    showall = YES;
                    continue;
                default:
                    printf("od: bad flag -%c\n", *p);
                    puts(usage);
                    exit(1);
                }
                *(cv++) = d;
            }
            argc--;
            argv++;
        }
    }

    /* nothing requested -> default unsigned-short octal. */
    if (cv == conv_vec)
        *(cv++) = &u_s_oct;
    *cv = 0;

    if (dbuf_size <= 0 || dbuf_size > DBUF_SIZE)
        dbuf_size = 16;

    /* uniform-width display fields across all requested conversions. */
    for (cv = conv_vec; (d = *cv) != 0; cv++) {
        nelm = (dbuf_size + d->df_size - 1) / d->df_size;
        llen = nelm * (d->df_field + 1);
        if (llen > max_llen)
            max_llen = llen;
    }
    for (cv = conv_vec; (d = *cv) != 0; cv++) {
        if (d->df_field) {
            nelm  = (dbuf_size + d->df_size - 1) / d->df_size;
            field = max_llen / nelm;
            d->df_pad = field - d->df_field;   /* leading spaces per object */
        }
    }

    /* input file? */
    in = stdin;
    in_is_file = 0;
    if (argc > 0 && **argv != '+') {
        in = fopen(*argv, "r");
        if (in == NULL) {
            perror(*argv);
            exit(1);
        }
        in_is_file = 1;
        argv++;
        argc--;
    }

    /* optional [+]offset [label] */
    if (argc > 0) {
        addr = get_addr(*argv);
        offset(addr);
        argv++;
        argc--;
        if (argc > 0)
            label = get_addr(*argv);
    }

    /* main dump loop */
    same = -1;
    while ((n = fillbuf(dbuf, dbuf_size, in)) > 0) {
        if (same >= 0 && memcmp(dbuf, lastdbuf, dbuf_size) == 0 && !showall) {
            if (same == 0) {
                printf("*\n");
                same = 1;
            }
        } else {
            line(n);
            same = 0;
            p = dbuf;
            l = lastdbuf;
            for (nelm = 0; nelm < dbuf_size; nelm++) {
                *l++ = *p;
                *p++ = '\0';
            }
        }
        addr += n;
        if (label >= 0)
            label += n;
    }

    /* flush string mode + emit final address line */
    n = 0;
    for (cv = conv_vec; *cv; cv++) {
        d = *cv;
        if (d->df_paddr) {
            if (n++ == 0)
                put_addr(addr, label, '\n');
        } else {
            int (*put)();
            put = put_table[d->df_putid];
            put(0, d);
        }
    }
    return 0;
}

void put_addr(long a, long l, int c)
{
    fputs(icvt(a, addr_base, UNSIGNED, 7), stdout);
    if (l >= 0)
        printf(" (%s)", icvt(l, addr_base, UNSIGNED, 7));
    putch(c);
}

void line(int n)
{
    int i, first;
    struct dfmt  *c;
    struct dfmt **cv = conv_vec;
    int (*put)();

    first = YES;
    while ((c = *cv++) != 0) {
        if (c->df_paddr) {
            if (first) {
                put_addr(addr, label, ' ');
                first = NO;
            } else {
                putch('\t');
                if (label >= 0)
                    fputs("\t  ", stdout);
            }
        }
        put = put_table[c->df_putid];
        i = 0;
        while (i < n)
            i += put(dbuf + i, c);
        if (c->df_paddr)
            putch('\n');
    }
}

int s_put(char *np, struct dfmt *d)
{
    short *n = (short *)np;
    emit_field(d, icvt((long)*n, d->df_radix, d->df_signed, d->df_field));
    return d->df_size;
}

int us_put(char *np, struct dfmt *d)
{
    unsigned short *n = (unsigned short *)np;
    emit_field(d, icvt((long)*n, d->df_radix, d->df_signed, d->df_field));
    return d->df_size;
}

int l_put(char *np, struct dfmt *d)
{
    long *n = (long *)np;
    emit_field(d, icvt(*n, d->df_radix, d->df_signed, d->df_field));
    return d->df_size;
}

int d_put(char *fp, struct dfmt *d)
{
    double *f = (double *)fp;
    char fbuf[24];
    sprintf(fbuf, "%21.14e", *f);
    emit_field(d, fbuf);
    return d->df_size;
}

int f_put(char *fp, struct dfmt *d)
{
    float *f = (float *)fp;
    char fbuf[16];
    sprintf(fbuf, "%14.7e", *f);
    emit_field(d, fbuf);
    return d->df_size;
}

int a_put(char *cc, struct dfmt *d)
{
    int c = *cc;
    char s[4];
    int pbit;

    pbit = parity((int)c & 0377);
    c &= 0177;
    s[0] = ' '; s[1] = ' '; s[2] = ' '; s[3] = '\0';
    if (isgraph(c)) {
        s[2] = c;
        if (pbit == _parity)
            emit_field(d, underline(s));
        else
            emit_field(d, s);
    } else {
        if (c == 0177)
            c = ' ' + 1;            /* maps DEL -> "del" slot (index 33) */
        if (pbit == _parity)
            emit_field(d, underline(asc_name[c]));
        else
            emit_field(d, asc_name[c]);
    }
    return 1;
}

int parity(int word)
{
    int p = 0;
    int w = word;

    if (w)
        do {
            p ^= 1;
            w &= (~(-w));        /* clear lowest set bit */
        } while (w);
    return p ? ODD : EVEN;
}

char ulbuf[16];

char *underline(char *s)
{
    char *u = ulbuf;
    while (*s) {
        if (*s != ' ') {
            *u++ = '_';
            *u++ = '\b';
        }
        *u++ = *s++;
    }
    *u = '\0';
    return ulbuf;
}

int b_put(char *b, struct dfmt *d)
{
    emit_field(d, icvt((long)*b & 0377, d->df_radix, d->df_signed, d->df_field));
    return 1;
}

int c_put(char *cc, struct dfmt *d)
{
    char *s;
    int   n;
    int   c = *cc & 0377;

    s = scvt(c, d);
    for (n = d->df_field - strlen(s); n > 0; n--)
        putch(' ');
    emit_field(d, s);
    return 1;
}

char scbuf[2];

char *scvt(int c, struct dfmt *d)
{
    switch (c) {
    case '\0': return "\\0";
    case '\b': return "\\b";
    case '\f': return "\\f";
    case '\n': return "\\n";
    case '\r': return "\\r";
    case '\t': return "\\t";
    default:
        if (isprint(c)) {
            scbuf[0] = c;
            scbuf[1] = '\0';
            return scbuf;
        }
        return icvt((long)c, d->df_radix, d->df_signed, d->df_field);
    }
}

/*
 * string mode (-s): a string is bytes that are printable/named, ending at NUL.
 */
#define CNULL    '\0'
#define S_EMPTY  0
#define S_FILL   1
#define S_CONT   2
#define SBUFSIZE 1024

char str_buf[SBUFSIZE];
int  str_mode = S_EMPTY;
char *str_ptr;
long str_addr;
long str_label;

void put_sbuf(int c, struct dfmt *d);
void pr_sbuf(struct dfmt *d, int end);

int st_put(char *cc, struct dfmt *d)
{
    int c;

    if (cc == 0) {
        pr_sbuf(d, YES);
        return 1;
    }
    c = (*cc & 0377);
    if (str_mode & S_FILL) {
        if (isascii(c) && (isprint(c) || c == ' '))
            put_sbuf(c, d);
        else {
            *str_ptr = CNULL;
            if (c == 0)
                pr_sbuf(d, YES);
            str_mode = S_EMPTY;
        }
    } else if (isascii(c) && (isprint(c) || c == ' ')) {
        str_mode = S_FILL;
        str_addr = addr + (cc - dbuf);
        str_label = label;
        if (str_label >= 0)
            str_label += (cc - dbuf);
        str_ptr = str_buf;
        put_sbuf(c, d);
    }
    return 1;
}

void put_sbuf(int c, struct dfmt *d)
{
    *str_ptr++ = c;
    if (str_ptr >= (str_buf + SBUFSIZE)) {
        pr_sbuf(d, NO);
        str_ptr = str_buf;
        str_mode |= S_CONT;
    }
}

void pr_sbuf(struct dfmt *d, int end)
{
    char *p = str_buf;

    if (str_mode == S_EMPTY ||
        (!(str_mode & S_CONT) && (str_ptr - str_buf) < d->df_size))
        return;
    if (!(str_mode & S_CONT))
        put_addr(str_addr, str_label, ' ');
    while (p < str_ptr)
        fputs(scvt(*p++, d), stdout);
    if (end)
        putch('\n');
}

/*
 * integer -> ascii, right-justified in ndigits (BSD icvt; simulates
 * unsigned-long div/mod with signed ops for value < 0 unsigned).
 */
char *icvt(long value, int radix, int sgn, int ndigits)
{
    long val = value;
    long rad = radix;
    char *b = &_icv_buf[MAXINTLEN];
    char *d = _digit;
    long tmp1, tmp2, rem, kludge;
    int  sign;

    if (val == 0) {
        *--b = '0';
        sign = 0;
        goto done;
    }
    if (sgn && (sign = (val < 0)) != 0) {
        tmp1 = val / rad;
        *--b = d[(tmp1 * rad) - val];
        val = -tmp1;
    } else {
        sign = 0;
        if (val < 0) {
            kludge = _mask - (rad - 1);
            val &= _mask;
            tmp1 = kludge / rad;
            tmp2 = val / rad;
            rem  = (kludge - (tmp1 * rad)) + (val - (tmp2 * rad));
            val  = ++tmp1 + tmp2;
            tmp1 = rem / rad;
            val += tmp1;
            *--b = d[rem - (tmp1 * rad)];
        }
    }
    while (val) {
        tmp1 = val / rad;
        *--b = d[val - (tmp1 * rad)];
        val = tmp1;
    }
done:
    if (sign)
        *--b = '-';
    tmp1 = ndigits - (&_icv_buf[MAXINTLEN] - b);
    tmp2 = sgn ? ' ' : '0';
    while (tmp1 > 0) {
        *--b = tmp2;
        tmp1--;
    }
    return b;
}

long get_addr(char *s)
{
    char *p;
    long  a;
    int   d;

    if (*s == '+')
        s++;
    if (*s == 'x') {
        s++;
        addr_base = 16;
    } else if (*s == '0' && s[1] == 'x') {
        s += 2;
        addr_base = 16;
    } else if (*s == '0')
        addr_base = 8;
    p = s;
    while (*p) {
        if (*p++ == '.')
            addr_base = 10;
    }
    for (a = 0; *s; s++) {
        d = *s;
        if (isdigit(d))
            a = a * addr_base + d - '0';
        else if (isxdigit(d) && addr_base == 16)
            a = a * addr_base + (d | 0x20) + 10 - 'a';
        else
            break;
    }
    if (*s == '.')
        s++;
    if (*s == 'b')
        a *= 512;
    if (*s == 'B')
        a *= 1024;
    return a;
}

void offset(long a)
{
    if (in_is_file) {
        fseek(in, a, SEEK_SET);
    } else {
        dumbseek(a);
    }
}

void dumbseek(long off)
{
    int c;
    while (off > 0) {
        c = fgetc(in);
        if (c < 0) {
            fprintf(stderr, "EOF\n");
            exit(1);
        }
        off--;
    }
}

/* Read up to `max` bytes into buf via fgetc (the proven FGX stdio read path;
 * the fread shim is unreliable — see uname.c).  Returns byte count (0 at EOF). */
int fillbuf(char *buf, int max, FILE *fp)
{
    int c, k;
    k = 0;
    while (k < max) {
        c = fgetc(fp);
        if (c < 0)
            break;
        buf[k++] = c;
    }
    return k;
}
