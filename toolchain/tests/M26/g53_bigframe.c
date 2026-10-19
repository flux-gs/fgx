/* G53: a 300-byte local array declared ahead of the scalars (a,b,i).  fcc
 * places scalars below aggregates, so the scalars stay on near `n,S` slots and
 * only the array, past offset 255, is addressed through _fcc_fp.  The far
 * scalar path is g53_scalarfar.  No params, so this isolates the local case
 * (params -> g53_param).  Returns 42. */
int bigframe(void)
{
    char buf[300];
    int a;
    int b;
    int i;
    for (i = 0; i < 300; i++)
        buf[i] = (char)(i & 0x7F);
    a = buf[50];          /* 50 */
    b = buf[140] & 0x7F;  /* 140 & 0x7F = 12 */
    return a - b + 4;     /* 50 - 12 + 4 = 42 */
}

int main()
{
    return bigframe();
}
