/* Audit: bit fields read+write inside a single 16-bit container.
 * Pack [a:3 b:5 c:8] into one word; write each, read each, sum.
 * If RMW mask/shift codegen is wrong, sum diverges from 42. */

struct flags {
    unsigned a : 3;     /* low 3 bits, max 7 */
    unsigned b : 5;     /* next 5 bits, max 31 */
    unsigned c : 8;     /* high 8 bits, max 255 */
};

int main()
{
    struct flags f;
    int s;

    f.a = 5;
    f.b = 17;
    f.c = 200;

    /* Re-write one mid-field to test RMW preserves neighbours. */
    f.b = 4;

    s = f.a + f.b + f.c / 7;   /* 5 + 4 + (200/7)=28 = 37 */
    return s + 5;              /* 42 */
}
