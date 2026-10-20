/* compress cl_hash()'s EXACT unrolled pointer-walk clear (local count_int*
 * htab_p, *(htab_p-16)=m1 ... 16-wide do-while + remainder), run on a htab
 * flanked by GUARD sentinels.  If fcc's codegen for the pointer walk under- or
 * over-writes by even one element it corrupts an adjacent heap header — a
 * layout-sensitive crash in the real compress.  Exit 42. */
typedef long count_int;
long arr[5006];             /* [0]=guard, [1..5003]=htab, [5004..5005]=guard */
count_int *htab;

int cl_hash_idiom(hsize)
    register count_int hsize;
{
    register count_int *htab_p = htab + hsize;
    register long i;
    register long m1 = -1;

    i = hsize - 16;
    do {
        *(htab_p-16) = m1; *(htab_p-15) = m1; *(htab_p-14) = m1; *(htab_p-13) = m1;
        *(htab_p-12) = m1; *(htab_p-11) = m1; *(htab_p-10) = m1; *(htab_p-9)  = m1;
        *(htab_p-8)  = m1; *(htab_p-7)  = m1; *(htab_p-6)  = m1; *(htab_p-5)  = m1;
        *(htab_p-4)  = m1; *(htab_p-3)  = m1; *(htab_p-2)  = m1; *(htab_p-1)  = m1;
        htab_p -= 16;
    } while ((i -= 16) >= 0);
    for (i += 16; i > 0; i--)
        *--htab_p = m1;
    return 0;
}

int main(void)
{
    int k;
    for (k = 0; k < 5006; k++) arr[k] = 0x55555555L;
    htab = arr + 1;                     /* htab[0..5002] = arr[1..5003] */
    cl_hash_idiom(5003L);
    if (arr[0] != 0x55555555L)    return 1;   /* UNDERFLOW guard (htab[-1]) */
    if (arr[5004] != 0x55555555L) return 2;   /* OVERFLOW guard  (htab[5003]) */
    if (arr[5005] != 0x55555555L) return 3;
    for (k = 0; k < 5003; k++)
        if (arr[1 + k] != -1L)   return 4;    /* every htab slot cleared    */
    return 42;
}
