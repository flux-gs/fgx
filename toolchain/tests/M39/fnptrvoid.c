/* M39 (frotz port): ANSI `(void)` param list in fn-ptr declarators, the
 * extern SIZELESS fn-ptr array reference, and the direct element-call
 * STATEMENT `tab[i]();` -- frotz process.c's whole opcode dispatch shape.
 * Old fcc died three ways: "void declarator must be 'void *p'" on the
 * (void), "fn-ptr array needs an explicit size or a non-empty initializer"
 * on the extern [], and "expected '='" on the discarded element call. */

extern void (*tab[]) (void);    /* reference decl: size at the definition */

static int hits;

static void f0 (void) { hits += 1; }
static void f1 (void) { hits += 40; }

void (*tab[2]) (void) = { f0, f1 };

int main(void)
{
    int i;
    hits = 0;
    tab[0] ();                  /* direct element call, result discarded */
    for (i = 1; i < 2; i++)
        tab[i] ();              /* computed index */
    (*tab[0]) ();               /* the classic deref spelling still works */
    return hits;                /* 1 + 40 + 1 = 42 */
}
