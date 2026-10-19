/* B-6 deferred: 4-byte long/float POINTER deref + store (was 16-bit only;
 * PRE-EXISTING, affects od/hd float-via-pointer dumps).  Covers scalar deref
 * read/write and the indexed-read path through a long-ptr and a float-ptr.
 * Returns 42 iff all correct. */
long  gl;
float gf;
long  la[3];
float fa[3];

int main(void)
{
    long  *lp;
    float *fp;

    gl = 100000L;
    lp = &gl;
    if (*lp != 100000L)          return 1;   /* scalar long deref read   */
    *lp = 70000L;
    if (gl != 70000L)            return 2;   /* scalar long deref store  */

    gf = 2.5;
    fp = &gf;
    if ((int)(*fp) != 2)         return 3;   /* scalar float deref read  */
    if ((int)(*fp + 40.0) != 42) return 4;   /* deref'd float in arith   */
    *fp = 9.0;
    if ((int)gf != 9)            return 5;   /* scalar float deref store */

    lp = la;
    *lp = 80000L;                            /* 4-byte ptr store */
    if (lp[0] != 80000L)         return 6;   /* indexed long read (4-byte) */

    fp = fa;
    *fp = 42.0;
    if ((int)fp[0] != 42)        return 7;   /* indexed float read (4-byte) */

    return 42;
}
