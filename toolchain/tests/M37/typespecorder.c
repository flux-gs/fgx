/* C89 6.7.2: type specifiers may appear in any order.  fcc consumed
 * signed/unsigned only BEFORE the base, so `int signed` / `long unsigned`
 * (joe utils.h int_min's `int signed b`) died "expected ',' or ')'".
 * FGX-only oracle.  Value 42. */
int pick(signed int a, int signed b) { return a < b ? a : b; }   /* -> 20 */
unsigned int mask(int unsigned v) { return v & 0xFF; }           /* -> 18 */
long big(long unsigned n) { return (long)(n & 0xF); }            /* -> 4 */

int main(void)
{
    int r = 0;
    r += pick(20, 40);      /* 20 */
    r += (int)mask(0x112);  /* 0x12 = 18 */
    r += (int)big(0x24UL);  /* 4 */
    return r;               /* 42 */
}
