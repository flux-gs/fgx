/* A file-scope pointer initialised from a constant keeps the whole
 * constant.  K&R A.7.19: "Initializers must evaluate either to a constant or
 * to the address of a previously declared external or static object plus or
 * minus a constant."  `(char *)0xE12000L' is the first kind: its bank byte
 * is $E1 and it is not a data-bank address.  fcc emitted the offset and a
 * zero high word, so shr pointed at $00:2000.  Each test reads the pointer's
 * high word at run time, through a long, so a zero bank cannot pass.  Exits
 * 42 iff all three hold. */
char *shr = (char *)0xE12000L;
char *shr4 = (char *)0xE12000L + 4;
char *nul = (char *)0;

int
main()
{
    unsigned long a, b, c;
    int ok;

    ok = 0;
    a = (unsigned long)shr;
    b = (unsigned long)shr4;
    c = (unsigned long)nul;
    if ((a & 0xFFFFFFL) == 0xE12000L)
        ok += 14;
    if ((b & 0xFFFFFFL) == 0xE12004L)
        ok += 14;
    if (c == 0L)
        ok += 14;
    return ok;
}
