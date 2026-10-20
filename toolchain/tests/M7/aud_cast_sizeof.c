/* Audit: (char)int narrowing + sizeof(int) compile-time constant.
 * If cast doesn't AND #$00FF, return is 0x102A=4138 mod 256→42 only by
 * luck; if sizeof(int) returns 0 or wrong, multiplication zeroes. */

int main()
{
    int i;
    int n;
    int sz;

    i  = 4138;         /* 0x102A — high byte 0x10, low byte 0x2A = 42 */
    n  = (char)i;      /* must narrow to 0x2A = 42 */
    sz = sizeof(int);  /* must be 2 */

    /* n * sz / 2 == 42 only if n==42 AND sz==2 */
    return n * sz / 2;
}
