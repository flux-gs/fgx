/* sizeof_const: sizeof of an EXPRESSION operand in a CONSTANT expression --
 * global initializers and array dimensions.  fcc's const-expr evaluator only
 * accepted `sizeof(type)`; it now shares the runtime operand parser, so every
 * form works in const context, matching tcsh's
 * `int nbfunc = sizeof bfunc / sizeof *bfunc;` (sh.init) and
 * `Char orhsb[sizeof(rhsb) / sizeof(Char)];` (sh.lex).  -> 42. */
int   bfunc[10];                       /* sizeof bfunc == 20, sizeof *bfunc == 2 */
char  rhsb[8];                         /* sizeof(rhsb) == 8 */

/* global initializer: const-expr sizeof of array / deref-of-array */
int nb = sizeof bfunc / sizeof *bfunc; /* 20 / 2 == 10 */

/* array dimension: const-expr sizeof(array) and sizeof(type) */
char orhsb[sizeof(rhsb) / sizeof(char)];   /* [8 / 1] == [8] */

int
main()
{
    int d;
    d = sizeof orhsb;          /* runtime path: 8 */
    return nb + d + 24;        /* 10 + 8 + 24 == 42 */
}
