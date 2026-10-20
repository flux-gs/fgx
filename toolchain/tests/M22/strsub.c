/* M22: subscripting a STRING LITERAL directly — "..."[i].  A string literal
 * is a char[] that decays to char*, so it is subscriptable.  elvis curses.c
 * builds its SGR color strings via "04261537"[attrbyte & 0x07]; fcc previously
 * rejected the trailing '[' ("expected ')'") because the string-literal primary
 * returned before any postfix handling.  Exercises a variable index, a constant
 * index, and an expression index over a couple of literals.  Returns 42. */
int idx;

int main()
{
    int c3, c0;

    idx = 3;
    c3 = "04261537"[idx];             /* variable index   -> '6' (0x36) */
    c0 = "04261537"[0];               /* constant index   -> '0' (0x30) */
    if (c3 != '6')                 return 1;
    if (c0 != '0')                 return 2;
    if ("ABCD"[2] != 'C')          return 3;   /* another literal, const idx */
    if ("wxyz"[idx] != 'z')        return 4;   /* idx=3 -> 'z' */
    if ("04261537"[idx + 1] != '1') return 5;  /* expression index (4) -> '1' */
    return 42;
}
