/* divs_pow2.c -- SIGNED division by a power-of-two constant, inlined.
 *
 * fcc used to inline /2^k only for an UNSIGNED dividend; a signed one fell to
 * _fcc_divs16, which was 2.51% of a five-exec profile and 1.6% of it in one
 * expression -- ufs_lookup.c's `(off / DIRBLKSIZ) * DIRBLKSIZ`, inside the
 * directory scan.
 *
 * THE WHOLE RISK IS THE NEGATIVE DIVIDEND.  An arithmetic shift FLOORS, and
 * _fcc_divs16 truncates TOWARD ZERO, so an unbiased shift would make `x / 512`
 * mean one thing when 512 is a literal and another when it is not.  K&R 2nd ed
 * A.7.6 (p.166) permits either -- it requires only that (a/b)*b + a%b == a and
 * that |a%b| < |b| -- so the constraint is agreement with the helper, not the
 * standard.  Every negative case below discriminates the two: floor and
 * truncate differ for every dividend that is not an exact multiple.
 *
 * Values are read out of globals so the front end cannot constant-fold the
 * division away and test nothing.  Exit 42. */

int a, b, c, d;

int main()
{
    int n;

    n = 0;

    /* positives: floor and truncate agree, so these only prove the shift */
    a = 1024;  if (a / 512 == 2)   n += 1;
    a = 1535;  if (a / 512 == 2)   n += 2;
    a = 511;   if (a / 512 == 0)   n += 4;

    /* negatives: floor gives -1, -3, -1; truncate gives 0, -2, 0 */
    b = -1;    if (b / 512 == 0)   n += 8;
    b = -1024; if (b / 512 == -2)  n += 16;
    b = -1025; if (b / 512 == -2)  n += 32;
    b = -511;  if (b / 512 == 0)   n += 64;
    b = -512;  if (b / 512 == -1)  n += 128;
    b = -513;  if (b / 512 == -1)  n += 256;

    /* k = 2, the smallest shift, where an off-by-one bias is most visible */
    c = -3;    if (c / 2 == -1)    n += 512;
    c = -1;    if (c / 2 == 0)     n += 1024;
    c = 3;     if (c / 2 == 1)     n += 2048;

    /* the extremes of the 16-bit range */
    d = 32767;  if (d / 2 == 16383)   n += 4096;
    d = -32768; if (d / 2 == -16384)  n += 8192;

    /* a NON-power-of-two signed constant still divides signed -- opening the
     * gate routed this to the const-libcall node, which had the unsigned
     * helper hardcoded */
    b = -100;  if (b / 10 == -10)  n += 16384;

    return n == 32767 ? 42 : n;
}
