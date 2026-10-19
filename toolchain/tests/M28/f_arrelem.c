/* B-6 deferred: 4-byte long/float ARRAY-element store + read (was 16-bit;
 * affects long arrays too).  Covers global long/float arrays, constant and
 * variable index, store + read, and a read used in arithmetic.  Returns 42. */
long  la[3];
float fa[4];

int main(void)
{
    int i;

    la[0] = 100000L;
    la[2] = 70000L;
    if (la[0] != 100000L)        return 1;   /* global long elem store+read */
    if (la[2] != 70000L)         return 2;

    fa[0] = 1.5;
    fa[1] = 42.0;
    fa[2] = 9.0;
    if ((int)fa[1] != 42)        return 3;   /* global float elem store+read */
    if ((int)(fa[0] * 2.0) != 3) return 4;   /* read'd float in arithmetic */

    i = 2;
    if (la[i] != 70000L)         return 5;   /* variable-index long read */
    if ((int)fa[i] != 9)         return 6;   /* variable-index float read */

    return 42;
}
