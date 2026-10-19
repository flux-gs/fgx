/* Global long* subscript with a VARIABLE (long) index — the compress htab[i]
 * pattern (i is code_int=long, computed at runtime).  glptrhi only used a
 * CONSTANT index (2), so it could not catch a variable-index scaling/bank bug
 * in the store or read.  compress does htab[i]=fcode / htab[i]==fcode with i
 * from a hash, and dies after a few iterations (wild write corrupts memory).
 * Exit 42. */
typedef long code_int;
long  storage[600];
long *htab;

int main(void)
{
    code_int i;
    long fcode;
    int k;

    htab = storage;
    for (k = 0; k < 600; k++)      /* variable-index store loop (subscript) */
        htab[k] = -1L;
    for (k = 0; k < 600; k++)       /* verify the clear via variable index   */
        if (htab[k] != -1L) return 1;

    i = 271;                        /* code_int (long) variable index         */
    fcode = 450661L;                /* nonzero high word (0x0006E065)         */
    htab[i] = fcode;                /* global long* store, VARIABLE long idx  */
    if (htab[i] != 450661L)   return 2;   /* read via same var index          */
    if (storage[271] != 450661L) return 3;/* read via constant index          */
    if (htab[i] == 450662L)   return 4;   /* long compare must see high word  */

    i = 0;
    htab[i] = 12345678L;            /* 0x00BC614E — index 0 edge             */
    if (storage[0] != 12345678L) return 5;
    return 42;
}
