/* D-2 follow-up: K&R float/double parameters.  K&R function DEFINITIONS
 * already work (the G43 type-decl-block path); this closes the one gap — a
 * float/double param in that block (the override loop omitted TOK_FLOAT_KW).
 * An old-style float parameter receives a double and narrows it on entry
 * (K&R A.7.3.2, A.10.1).  Mixed float+int and a `double' param.  Returns
 * 42. */

int scale(x, n)
float x; int n;
{
    return (int)(x * n);
}

int dpar(d)
double d;
{
    return (int)(d + d);
}

int main(void)
{
    if (scale(2.5, 4)  != 10) return 1;   /* 2.5 * 4  = 10.0   */
    if (scale(0.5, 84) != 42) return 2;   /* 0.5 * 84 = 42.0   */
    if (dpar(3.0)      != 6)  return 3;   /* 3.0 + 3.0 = 6.0   */
    return 42;
}
