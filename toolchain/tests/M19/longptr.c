/* A POINTER THAT GOES THROUGH A LONG COMES BACK WITH ITS OWN BANK -- the
 * explicit-cast spelling, in every place a pointer is stored.
 *
 * K&R A.6.6 (p.160): "A pointer may be converted to an integral type large
 * enough to hold it; the required size is implementation-dependent.  The
 * mapping function is also implementation-dependent."  FGX's mapping is
 * offset:bank, so converting the long back must read the bank from the high
 * word.  argv[0] lives on the bank-0 stack, not in the data bank, and bit 1
 * proves it: without that the checks below could not tell right from wrong.
 */
struct S { int a; char *p; };

char *G;
char *GA[3];
struct S GS;
int D;

char *ret(L) unsigned long L; { return (char *)L; }
int arg(char *q, char *p) { return q == p; }

int main(argc, argv)
    int argc;
    char **argv;
{
    char *p, *q, *la[3];
    struct S ls, *sp;
    unsigned long L;
    int acc;

    acc = 0;
    p = argv[0];
    L = (unsigned long)p;
    if ((L >> 16) != ((unsigned long)&D >> 16))
        acc += 1;
    q = (char *)L;
    if (q == p) acc += 2;
    G = (char *)L;
    if (G == p) acc += 4;
    la[1] = (char *)L;
    if (la[1] == p) acc += 8;
    GA[1] = (char *)L;
    if (GA[1] == p) acc += 16;
    GS.p = (char *)L;
    if (GS.p == p) acc += 32;
    sp = &ls;
    sp->p = (char *)L;
    if (sp->p == p) acc += 64;
    if (arg((char *)L, p) && ret(L) == p) acc += 128;
    return acc;
}
