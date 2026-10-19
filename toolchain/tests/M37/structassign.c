/* Whole-struct assignment, which UFS 1.13a is the first thing in this tree to
 * use: iget's checkalias arm copies a 64-byte `struct dinode` from the vnode
 * it is discarding into the aliased one it is keeping, and that struct IS the
 * on-disk format.  fcc emits a word-copy loop for it; nothing ran that loop
 * before this fixture, so a defect in it would have shown up as a device file
 * with the wrong mode and no reason to suspect the compiler.
 *
 * FOUR SHAPES, because they exercise different halves of the emitter:
 *   (a) plain object to object;
 *   (b) THROUGH POINTERS -- `d->m = s->m`, which is iget's actual spelling;
 *   (c) a struct with a NESTED struct, which the dinode has (icommon1 and
 *       icommon2 around the address array);
 *   (d) an ODD-SIZED struct, where a loop that moves WORDS has to stop
 *       without writing the byte past the end.
 *
 * Exit 42. */

struct inner {
    unsigned short  m;
    unsigned short  n;
};

struct outer {
    struct inner    hd;
    long            addr[7];
    unsigned short  tl;
};

struct odd {
    char            a;
    char            b;
    char            c;
};

struct outer  src;
struct outer  dst;
struct odd    osrc;
struct odd    odst;
char          fence;

struct outer *sp;
struct outer *dp;

int main(void)
{
    int i;

    /* ---- (a) and (c): object to object, with a nested struct ---------- */
    src.hd.m = 0x1234;
    src.hd.n = 0x5678;
    for (i = 0; i < 7; i++)
        src.addr[i] = 0x11110000L + (long)i;
    src.tl = 0xABCD;

    dst = src;

    if (dst.hd.m != 0x1234)             return 1;
    if (dst.hd.n != 0x5678)             return 2;
    for (i = 0; i < 7; i++)
        if (dst.addr[i] != 0x11110000L + (long)i) return 3;
    if (dst.tl != 0xABCD)               return 4;

    /* ...and the SOURCE is unchanged, which a loop running the wrong way
     * over overlapping storage would not leave true. */
    if (src.addr[0] != 0x11110000L)     return 5;
    if (src.tl != 0xABCD)               return 6;

    /* ---- (b) through pointers, which is iget's spelling --------------- */
    for (i = 0; i < 7; i++)
        dst.addr[i] = 0L;
    dst.hd.m = 0;
    dst.tl = 0;
    sp = &src;
    dp = &dst;
    *dp = *sp;
    if (dp->hd.m != 0x1234)             return 7;
    if (dp->addr[6] != 0x11110006L)     return 8;
    if (dp->tl != 0xABCD)               return 9;

    /* ---- (d) an ODD size: the byte after it must not move -------------- */
    fence = 0x5A;
    osrc.a = 1;
    osrc.b = 2;
    osrc.c = 3;
    odst.a = 0;
    odst.b = 0;
    odst.c = 0;
    odst = osrc;
    if (odst.a != 1)                    return 10;
    if (odst.b != 2)                    return 11;
    if (odst.c != 3)                    return 12;
    if (fence != 0x5A)                  return 13;

    return 42;
}
