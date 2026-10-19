/* Audit: *p++ rvalue + lvalue (K&R copy idiom).  If post-inc codegen
 * confuses pointer/byte stride, or *p++ writes the wrong location,
 * dst[] sum diverges from 42. */

int main()
{
    char src[5];
    char dst[5];
    char *s;
    char *d;

    src[0] = 7;
    src[1] = 14;
    src[2] = 21;
    src[3] = 0;
    src[4] = 99;       /* sentinel beyond NUL */

    dst[0] = 0;
    dst[1] = 0;
    dst[2] = 0;
    dst[3] = 0;
    dst[4] = 0;

    s = src;
    d = dst;
    while (*s) {
        *d++ = *s++;   /* both r and w post-inc */
    }
    *d = 0;            /* terminate */

    return dst[0] + dst[1] + dst[2];   /* 7 + 14 + 21 = 42 */
}
