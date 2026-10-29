/* M37: parameters of a function whose frame is too big for `n,S' to reach
 * them are copied at entry into frame slots and used there (K&R A.10.1: "the
 * parameters are understood to be declared just after the beginning of the
 * compound statement constituting the function's body").  Each kind is read
 * and written across a call, inside the 300-byte frame; a function that takes
 * a parameter's address keeps it where the caller pushed it, so va_start
 * still reaches the next argument.  Returns 42. */
#include <stdarg.h>

struct io { int cnt; char *ptr; };

int touch(char *b, int n) { b[0] = (char)n; return b[0]; }

int kinds(c, i, l, s, p)
char c; int i; long l; char *s; struct io *p;
{
    char big[300];
    int r = 0;

    touch(big, 1);
    if (c != 'x' || i != -5 || l != 70000L) return 1;
    c++; i += 10; l += 1;
    touch(big, 2);
    if (c != 'y' || i != 5 || l != 70001L) return 2;
    while (*s) r += *s++;              /* "ab" */
    if (r != 'a' + 'b' || s[-1] != 'b') return 3;
    while (--p->cnt >= 0)
        r += *p->ptr++;               /* "cd" */
    if (r != 'a' + 'b' + 'c' + 'd' || p->cnt != -1) return 4;
    p = 0;
    touch(big, 3);
    return p == 0 ? 0 : 5;
}

int addr(int n, ...)
{
    char big[300];
    va_list ap;
    int v;

    touch(big, 4);
    va_start(ap, n);                   /* reaches past n: n stays in place */
    v = va_arg(ap, int);
    va_end(ap);
    return v + n;
}

int main()
{
    struct io f;
    char cd[3];
    int r;

    cd[0] = 'c'; cd[1] = 'd'; cd[2] = 0;
    f.cnt = 2; f.ptr = cd;
    r = kinds('x', -5, 70000L, "ab", &f);
    if (r) return r;
    if (f.ptr != cd + 2) return 6;
    if (addr(1, 36) != 37) return 7;
    return 42;
}
