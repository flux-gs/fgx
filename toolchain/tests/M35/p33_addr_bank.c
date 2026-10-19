/* M35/P3-3: &local bank.  A pointer to a local is passed to a callee that
 * dereferences it.  Today &local carries the soft-stack bank; after the flip
 * it must carry bank 0 (the hardware stack).  The callee stores/loads through
 * the far pointer, so a wrong bank writes into the void — invisible only if
 * the soft-stack bank happens to equal DBR (it doesn't in multi-bank).
 *
 * Portable C: clang returns 42. */
void
setto(int *p, int v)
{
    *p = v;
}

int
getfrom(int *p)
{
    return *p;
}

int
main(void)
{
    int loc;
    int arr[3];
    int *p;

    setto(&loc, 777);
    if (loc != 777)          return 1;
    if (getfrom(&loc) != 777) return 2;

    setto(&arr[1], 555);
    if (arr[1] != 555)        return 3;

    p = &loc;
    *p = 888;
    if (loc != 888)          return 4;

    /* address arithmetic on &local */
    p = &arr[0];
    *(p + 2) = 999;
    if (arr[2] != 999)        return 5;

    return 42;
}
