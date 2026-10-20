/*
 * _lib_init -- give this process its own copy of each block of one
 * library.
 *
 * A library's statics outside its core live in per-member blocks (shared
 * libc SP2 spec, section 4).  Code reaches member m's statics through the
 * core cell _<lib>_blk_<m>, which must hold the address of THIS process's
 * block.  `tab' is the library's block table: per member four words, the
 * cell's address, a far pointer to the member's template (offset, then
 * bank) and the block's size; a zero word ends it.  `bits' is the
 * program's reachability bitmap for the library -- row i is built when bit
 * i & 7 of byte i >> 3 is set -- or NULL, every row (a static link's table
 * holds only the members it reaches).  A template holds every static's
 * initial bytes and zeros for the rest, which is K&R A.8.7's rule, "A
 * static object not explicitly initialized is initialized as if it (or
 * its members) were assigned the constant 0", so copying it is the whole
 * initialisation.
 *
 * The blocks go at the top of the heap's room, just below HEAP_LIM, and
 * HEAP_LIM comes down to the lowest of them: sbrk stops there, and fork
 * carries [HEAP_LIM, $FFFF] with the data below the break
 * (include/kernel.s), so a child gets its own copy.  crt0's _crt0_inits
 * calls this once per library, in load order.  Everything here is in the
 * process's data bank, the one `tab' is in.  `copy' is the MVN copier in
 * the program's segment 0 (crt0_lib.s's _lib_copy): libc's code bank is
 * shared, so no routine in it can carry this process's bank in an MVN.
 *
 * No BSD counterpart: 2.11BSD links libc statically and its data is the
 * program's.
 */
extern int write();
extern void _exit();

static int
wanted(bits, i)
unsigned char *bits;
unsigned i;
{
    return bits == (unsigned char *)0 || (bits[i >> 3] & (1 << (i & 7)));
}

void
_lib_init(tab, bits, copy)
unsigned *tab;
unsigned char *bits;
int (*copy)();
{
    unsigned *t, *lim;
    unsigned long bank;
    unsigned top, need, i;
    char *blk, *tmpl;

    bank = (unsigned long)(char *)tab & 0xFF0000L;
    lim = (unsigned *)(bank | 0xFFF8L);                 /* HEAP_LIM */
    need = 0;
    for (t = tab, i = 0; t[0]; t += 4, i++)
        if (wanted(bits, i))
            need += t[3];
    if (need == 0)
        return;
    top = *lim;
    if (need > top - *(unsigned *)(bank | 0xFFFEL)) {   /* HEAP_BRK */
        write(2, "libc: no room for its data\n", 27);
        _exit(1);
    }
    for (t = tab, i = 0; t[0]; t += 4, i++) {
        if (!wanted(bits, i))
            continue;
        top -= t[3];
        blk = (char *)(bank | top);
        tmpl = (char *)(((unsigned long)t[2] << 16) | t[1]);
        (*copy)(blk, tmpl, t[3]);
        *(unsigned *)(bank | t[0]) = top;
    }
    *lim = top;
}
