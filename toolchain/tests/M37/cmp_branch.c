/* cmp_branch.c -- a comparison feeding a branch is its own branch.
 *
 * fcc used to call _fcc_lts16 / _fcc_gts16 / _fcc_eq16 / _fcc_ne16 to turn the
 * flags into a 0 or a 1, `CMP #0` to turn that back into flags, and only then
 * branch.  Those four were 2.04% of a five-exec profile.  The fused path emits
 * the compare and branches on its flags.
 *
 * WHAT DISCRIMINATES: the SIGNED arm corrects the sign with N XOR V, and the
 * cases that need it are the ones where LHS-RHS OVERFLOWS -- INT_MIN against a
 * positive, INT_MAX against a negative.  A fused compare that dropped the
 * correction still answers every small case correctly and fails exactly those.
 *
 * `>` and `<=` are emitted as `<` and `>=` with the operands swapped, so both
 * orders of every relation are driven.  The unsigned arm is driven with values
 * above 0x7FFF, where unsigned and signed disagree.
 *
 * Operands are globals so nothing constant-folds.  Exit 42. */

int a, b;
unsigned int ua, ub;
int hits;

int lt(void) { return a <  b ? 1 : 0; }
int gt(void) { return a >  b ? 1 : 0; }
int le(void) { return a <= b ? 1 : 0; }
int ge(void) { return a >= b ? 1 : 0; }
int eq(void) { return a == b ? 1 : 0; }
int ne(void) { return a != b ? 1 : 0; }

int ult(void) { return ua <  ub ? 1 : 0; }
int ugt(void) { return ua >  ub ? 1 : 0; }
int ule(void) { return ua <= ub ? 1 : 0; }
int uge(void) { return ua >= ub ? 1 : 0; }

/* every relation at once, as a bitmask, so one call checks all six */
int allrel(void)
{
    int m;
    m = 0;
    if (a <  b) m += 1;
    if (a >  b) m += 2;
    if (a <= b) m += 4;
    if (a >= b) m += 8;
    if (a == b) m += 16;
    if (a != b) m += 32;
    return m;
}

int uallrel(void)
{
    int m;
    m = 0;
    if (ua <  ub) m += 1;
    if (ua >  ub) m += 2;
    if (ua <= ub) m += 4;
    if (ua >= ub) m += 8;
    return m;
}

int main()
{
    int n, i, c;

    n = 0;

    /* ---- ordinary signed, LHS < RHS ---- */
    a = 3; b = 7;
    if (allrel() == 1 + 4 + 32) n += 1;

    /* ---- ordinary signed, LHS > RHS ---- */
    a = 7; b = 3;
    if (allrel() == 2 + 8 + 32) n += 2;

    /* ---- equal ---- */
    a = 5; b = 5;
    if (allrel() == 4 + 8 + 16) n += 4;

    /* ---- THE OVERFLOW CASES, which is what N XOR V is for ---- */
    a = -32768; b = 1;            /* a-b overflows */
    if (allrel() == 1 + 4 + 32) n += 8;
    a = 32767; b = -1;            /* a-b overflows the other way */
    if (allrel() == 2 + 8 + 32) n += 16;
    a = -1; b = 32767;
    if (allrel() == 1 + 4 + 32) n += 32;
    a = 1; b = -32768;
    if (allrel() == 2 + 8 + 32) n += 64;

    /* ---- both negative ---- */
    a = -7; b = -3;
    if (allrel() == 1 + 4 + 32) n += 128;

    /* ---- unsigned, above 0x7FFF where it disagrees with signed ---- */
    ua = 0x8000; ub = 1;
    if (uallrel() == 2 + 8) n += 256;     /* signed would say 0x8000 < 1 */
    ua = 1; ub = 0xFFFF;
    if (uallrel() == 1 + 4) n += 512;
    ua = 0xFFFF; ub = 0xFFFF;
    if (uallrel() == 4 + 8) n += 1024;

    /* ---- the single-relation functions, both directions ---- */
    a = 2; b = 9;
    if (lt() && !gt() && le() && !ge() && !eq() && ne()) n += 2048;
    ua = 9; ub = 2;
    if (!ult() && ugt() && !ule() && uge()) n += 4096;

    /* ---- && / || short-circuit, which take the fused branch too ---- */
    a = 1; b = 2;
    hits = 0;
    if (a < b || a > b) hits += 1;        /* first arm true: second not run */
    if (a < b && b < 3) hits += 2;
    if (a > b && b < 3) hits += 4;        /* first arm false */
    if (hits == 3) n += 8192;

    /* ---- a loop condition, and a do-while ---- */
    c = 0;
    for (i = 0; i < 10; i++) c++;
    a = 0;
    do { a++; } while (a < 4);
    if (c == 10 && a == 4) n += 16384;

    return n == 32767 ? 42 : n;
}
