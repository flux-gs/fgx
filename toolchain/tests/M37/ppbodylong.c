/* A function-like macro whose body exceeds the old 256-byte #define capture
 * buffer.  It used to be SILENTLY TRUNCATED mid-token, leaving a garbled macro
 * that died later as "expected type" (joe screen.h's `outatr').  The capture
 * buffer is larger now and overflow fails loud.  FGX-only oracle.  Value 42. */
#define BIG(a, b, c, d, e, f) do {                                          \
        int _t1 = (a) + (b); int _t2 = (c) + (d); int _t3 = (e) + (f);      \
        int _u1 = _t1 * 1;   int _u2 = _t2 * 1;   int _u3 = _t3 * 1;        \
        acc = _u1 + _u2 + _u3 + (a) - (a) + (b) - (b) + (c) - (c);          \
    } while (0)

int acc;

int main(void)
{
    BIG(1, 2, 3, 4, 5, 6);   /* 3 + 7 + 11 = 21 */
    return acc + 21;         /* 42 */
}
