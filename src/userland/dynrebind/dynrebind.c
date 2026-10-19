/*
 * dynrebind -- shared libc SP5 spec 5.3's compare and repatch, reached on
 * purpose.  Run with no argument it checks errno through a code-segment
 * data site (`RBD ok' or `RBD FAIL'), then corrupts that site's word in
 * its own (shared) code and one byte of its bind record's first bank, and
 * execs itself with `again'.  The second run's binder must see the record
 * no longer match, patch the code segments again -- repairing the site --
 * and write a new record; the check passes only if it did.
 */
#include <stdio.h>
#include <errno.h>

extern unsigned char _dyn_tab[];
extern int execl();

/* Two functions, so the store and the load are each a real errno data site
 * (one function lets fcc compare the value still in A). */
static void
seterr()
{
    errno = 1234;
}

static int
geterr()
{
    return errno;
}

static int
check()
{
    seterr();
    return geterr() == 1234;
}

int
main(argc, argv)
int argc;
char **argv;
{
    unsigned char *tab, *q, *rec, *p;
    unsigned n, ilen, i;

    printf(check() ? "RBD ok\n" : "RBD FAIL\n");
    if (argc > 1)
        return 0;
    /* fcc addresses an extern array DBR-relative, so `_dyn_tab' alone would
     * read the DATA bank at the code label's offset.  A function designator
     * carries its code bank (a hidden long pointer), so the cell is reached
     * as check's bank : _dyn_tab's offset. */
    p = (unsigned char *)(((unsigned long)(unsigned char *)check & 0xFF0000L) |
                          ((unsigned)_dyn_tab & 0xFFFF));
    tab = (unsigned char *)(((unsigned long)p[2] << 16) | (p[0] | p[1] << 8));
    n = tab[0] | tab[1] << 8;
    q = tab + 4 + 4 * n;
    ilen = q[0] | q[1] << 8;
    rec = q + 2 + ilen;
    rec[2] ^= 0xFF;                     /* the first library's first bank */
    /* The first absolute store in seterr() is its errno data site: corrupt
     * its operand, so only a repatch makes the second run's check pass. */
    q = (unsigned char *)seterr;
    for (i = 0; i < 64; i++)
        if (q[i] == 0x8D) {             /* STA abs */
            q[i + 1] ^= 0x55;
            break;
        }
    execl(argv[0], argv[0], "again", (char *)0);
    printf("RBD FAIL exec\n");
    return 1;
}
