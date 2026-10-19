/* Audit: right shift (_fcc_shr16) + || short-circuit.
 * Right shift never MAME-tested; || never MAME-tested.
 * side() writes through ptr only if it runs — verifies non-evaluation. */

int side(int *p)
{
    *p = 99;
    return 1;
}

int main()
{
    int n;
    int touched;
    int s;

    n = 168;
    touched = 0;
    s = 0;

    /* 168 >> 2 == 42 */
    if ((n >> 2) == 42) s = s + 40;

    /* LHS true → RHS skipped → touched stays 0 */
    if (1 || side(&touched)) s = s + 1;
    if (touched == 0) s = s + 1;

    return s;     /* 40 + 1 + 1 = 42 */
}
