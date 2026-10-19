/* A POINTER THAT GOES THROUGH A LONG COMES BACK WITH ITS OWN BANK -- the
 * spelling without a cast, which fcc accepts and time(1) used.
 *
 * K&R A.6.6 (p.160) says such conversions "must be specified by an explicit
 * type-conversion operator, or cast"; fcc takes the assignment anyway, so it
 * must do what the cast does, not what an int does.  Every context here stored
 * the data bank or a stale one (exit 41): a local, a global, a global array
 * element, a field through a pointer, an argument and a return value.
 * argv[0] is on the bank-0 stack; bit 1 proves the banks differ.
 */
struct S { int a; char *p; };

char *G;
char *GA[3];
struct S GS;
int D;

char *ret(L) unsigned long L; { return L; }
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
    q = L;
    if (q == p) acc += 2;
    G = L;
    if (G == p) acc += 4;
    la[1] = L;
    if (la[1] == p) acc += 8;
    GA[1] = L;
    if (GA[1] == p) acc += 16;
    GS.p = L;
    if (GS.p == p) acc += 32;
    sp = &ls;
    sp->p = L;
    if (sp->p == p) acc += 64;
    if (arg(L, p) && ret(L) == p) acc += 128;
    return acc;
}
