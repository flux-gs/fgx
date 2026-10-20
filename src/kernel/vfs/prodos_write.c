/* FGX-Origin: original -- FGX code.  Its SHAPE is FGX's own ufs_write (the
 * uio loop) and netbsd-0-9's pcfs (a writable foreign volume behind vnodeops),
 * consulted and not ported; no BSD carried a ProDOS filesystem.  THE ON-DISK
 * RULES ARE ProDOS 8's, from its MLI source (MliSrc.aii): the allocator is
 * alc1blk, promotion is swapdown and topdown, and what a change writes back is
 * drevise.
 * prodos_write.c -- writing a ProDOS volume: the volume bitmap, the block map
 * that allocates, write(2), the directory revision a close makes, and
 * creating, removing and renaming files and directories, and truncating
 * files.  ProDOS FST P5a to P6.
 *
 * IT IS prodosw.mod, the write half, and reaches prodos.mod's node layer
 * through VT_PDCORE (src/modules/prodosw/prodos_import.s).  prodosw_init hands
 * this file's entry points, and a vector for them, to prodos.mod at load; see
 * prodos.h.
 *
 * EVERY WRITE IS SYNCHRONOUS AND ORDERED SO A CRASH LEAKS BUT NEVER SHARES.  A
 * block is marked in use in the bitmap, and that bitmap block written, before
 * anything names it; an index entry is written before the entry that reaches
 * the index; the directory entry is written last.  Interrupted anywhere, the
 * volume holds at worst a block the bitmap calls used and nothing references
 * -- what `cadius CHECKVOLUME' reports and ProDOS tolerates -- and never a
 * block two files own.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "uio.h"
#include "dir.h"
#include "namei.h"
#include "mount.h"
#include "vfsops.h"
#include "prodos.h"

extern int  bread();
extern void brelse();
extern int  bwrite();
extern int  uiomove();
extern void kc_panic();
extern long kern_ltime();   /* kern_time.c: the kernel clock, local */
extern int  pdget();
extern int  pd_fork();
extern int  pd_entsync();
extern struct pdnode *pd_twin();
extern int  pd_setwriteops();
extern void pd_rekey();
extern int  pd_bmap();
extern int  pd_unlock();
extern void vrele();


/* pd_bzero -- write zeros over a volume block. */
static int
pd_bzero(pmp, blk)
struct pdmount *pmp;
unsigned        blk;
{
    struct buf *bp;
    char       *p;
    int         i;
    int         error;

    error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    p = &bp->b_addr[PD_BUFOFF(blk)];
    for (i = 0; i < PD_BLKSIZE; i++)
        p[i] = 0;
    return (bwrite(bp));
}


/* pd_balloc -- a free block, marked in use and zeroed.
 *
 * alc1blk's SEARCH: the first bitmap byte with a bit set -- a set bit is a free
 * block -- and in it the leftmost set bit, which is the lowest block, cleared.
 * The MLI starts at the bitmap block it last allocated from; this starts at
 * the first every time, which finds the same kind of block (the lowest free)
 * at the cost of rescanning full map blocks on a volume past 4096 blocks.
 *
 * THE BLOCK IS ZEROED, for alc1blk's callers' reason: an index block's zero
 * entries are holes, and a data block a write only partly covers must read
 * zeros past it. */
static int
pd_balloc(pmp, blkp)
struct pdmount *pmp;
unsigned       *blkp;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       map;
    unsigned       nmaps;
    unsigned       blk;
    int            i;
    int            bit;
    int            error;

    nmaps = (unsigned)(((long)pmp->pm_totblks + 4095L) >> 12);
    for (map = 0; map < nmaps; map++) {
        blk = pmp->pm_bitmap + map;
        error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        for (i = 0; i < PD_BLKSIZE; i++) {
            if (b[i] == 0)
                continue;
            for (bit = 0; (b[i] & (0x80 >> bit)) == 0; bit++)
                ;
            *blkp = map * 4096u + (unsigned)i * 8u + (unsigned)bit;
            if (*blkp >= pmp->pm_totblks)
                break;
            b[i] &= ~(0x80 >> bit);
            error = bwrite(bp);
            if (error)
                return (error);
            pmp->pm_free--;
            return (pd_bzero(pmp, *blkp));
        }
        brelse(bp);
    }
    return (ENOSPC);
}


/* pd_setidx -- set entry i of the index block `iblk' to `val': the low byte in
 * the first half, the high byte in the second, as PD_IDXENT reads them. */
static int
pd_setidx(pmp, iblk, i, val)
struct pdmount *pmp;
unsigned        iblk;
int             i;
unsigned        val;
{
    struct buf    *bp;
    unsigned char *b;
    int            error;

    error = bread(pmp->pm_devvp, PD_BUFBLK(iblk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(iblk)];
    b[i]       = (unsigned char)val;
    b[256 + i] = (unsigned char)(val >> 8);
    return (bwrite(bp));
}


/* pd_getidx -- entry i of the index block `iblk'. */
static int
pd_getidx(pmp, iblk, i, valp)
struct pdmount *pmp;
unsigned        iblk;
int             i;
unsigned       *valp;
{
    struct buf *bp;
    int         error;

    error = bread(pmp->pm_devvp, PD_BUFBLK(iblk), &bp);
    if (error == 0)
        *valp = PD_IDXENT((unsigned char *)&bp->b_addr[PD_BUFOFF(iblk)], i);
    brelse(bp);
    return (error);
}


/* pd_bmapw -- the volume block for logical block `lbn', allocating it and any
 * index block on the way, and promoting the storage type first when `lbn' is
 * past what it can address.  *nallocp counts the blocks allocated; pd_fst and
 * pd_fkey change in core, and pd_revise writes them to the entry.
 *
 * PROMOTION IS swapdown's: a new index block is allocated, the old key block
 * becomes its entry 0, and the new block becomes the key -- a seedling's data
 * block becomes a sapling's first data block, a sapling's index a tree's first
 * sub-index.  The key block moves and the ENTRY does not, which is why a node
 * is keyed on its entry (prodos.h).  topdown does both levels at once for a
 * seedling written past 128 KB; here that is the two steps in turn.
 *
 * 32767 IS THE LAST BLOCK A TREE ADDRESSES that a three-byte EOF can reach:
 * 128 master entries of 256. */
static int
pd_bmapw(pd, lbn, blkp, nallocp)
struct pdnode *pd;
unsigned       lbn;
unsigned      *blkp;
int           *nallocp;
{
    struct pdmount *pmp;
    unsigned        nb;
    unsigned        sub;
    int             error;

    pmp = pd->pd_pmp;
    if (lbn > 32767u)
        return (EFBIG);

    if (pd->pd_fst == PD_ST_SEEDLING && lbn > 0) {
        error = pd_balloc(pmp, &nb);
        if (error)
            return (error);
        (*nallocp)++;
        if (pd->pd_fkey != 0) {
            error = pd_setidx(pmp, nb, 0, pd->pd_fkey);
            if (error)
                return (error);
        }
        pd->pd_fkey = nb;
        pd->pd_fst  = PD_ST_SAPLING;
    }
    if (pd->pd_fst == PD_ST_SAPLING && lbn > 255) {
        error = pd_balloc(pmp, &nb);
        if (error)
            return (error);
        (*nallocp)++;
        error = pd_setidx(pmp, nb, 0, pd->pd_fkey);
        if (error)
            return (error);
        pd->pd_fkey = nb;
        pd->pd_fst  = PD_ST_TREE;
    }

    if (pd->pd_fst == PD_ST_SEEDLING) {
        if (pd->pd_fkey == 0) {
            error = pd_balloc(pmp, &pd->pd_fkey);
            if (error)
                return (error);
            (*nallocp)++;
        }
        *blkp = pd->pd_fkey;
        return (0);
    }

    sub = pd->pd_fkey;
    if (pd->pd_fst == PD_ST_TREE) {
        error = pd_getidx(pmp, pd->pd_fkey, (int)(lbn >> 8), &sub);
        if (error)
            return (error);
        if (sub == 0) {
            error = pd_balloc(pmp, &sub);
            if (error)
                return (error);
            (*nallocp)++;
            error = pd_setidx(pmp, pd->pd_fkey, (int)(lbn >> 8), sub);
            if (error)
                return (error);
        }
    }
    error = pd_getidx(pmp, sub, (int)(lbn & 255), blkp);
    if (error || *blkp != 0)
        return (error);
    error = pd_balloc(pmp, blkp);
    if (error)
        return (error);
    (*nallocp)++;
    return (pd_setidx(pmp, sub, (int)(lbn & 255), *blkp));
}


/* pd_date -- `t' as a ProDOS date word and time word at `p', low bytes first;
 * all four bytes zero, "no date", for a time GS/OS's ProDOS FST would not
 * store: ProDOS.FST keeps 1940-2039 and makes anything else unknown, storing
 * 1940-1999 as 40-99 and 2000-2039 as 0-39.  The inverse of kern_epoch, with
 * its assumptions: leap years are `year & 3', and local time is the epoch. */
static void
pd_date(t, p)
long           t;
unsigned char *p;
{
    long     days;
    unsigned d;
    int      year;
    int      mon;
    int      mlen;

    p[0] = p[1] = p[2] = p[3] = 0;
    days = t / 86400L;
    t    = t % 86400L;
    for (year = 1970; ; year++) {
        mlen = ((year & 3) == 0) ? 366 : 365;
        if (days < (long)mlen)
            break;
        days = days - (long)mlen;
    }
    if (year > 2039)
        return;
    for (mon = 1; ; mon++) {
        if (mon == 2)
            mlen = ((year & 3) == 0) ? 29 : 28;
        else if (mon == 4 || mon == 6 || mon == 9 || mon == 11)
            mlen = 30;
        else
            mlen = 31;
        if (days < (long)mlen)
            break;
        days = days - (long)mlen;
    }
    d = (unsigned)(((year < 2000) ? year - 1900 : year - 2000) << 9) |
        (unsigned)(mon << 5) | (unsigned)(days + 1);
    p[0] = (unsigned char)d;
    p[1] = (unsigned char)(d >> 8);
    p[2] = (unsigned char)(t % 3600L / 60L);
    p[3] = (unsigned char)(t / 3600L);
}


/* pd_putent -- write the 39 bytes at `e' into slot `idx' of directory block
 * `blk'. */
static int
pd_putent(pmp, blk, idx, e)
struct pdmount *pmp;
unsigned        blk;
int             idx;
unsigned char  *e;
{
    struct buf *bp;
    char       *p;
    int         i;
    int         error;

    error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    p = &bp->b_addr[PD_BUFOFF(blk) + PD_ENTOFF(idx)];
    for (i = 0; i < PD_ENTLEN; i++)
        p[i] = e[i];
    return (bwrite(bp));
}


/* pd_revise -- write back what a write changed, drevise's first half.
 *
 * THE ENTRY TAKES the storage type and key block (either may have moved in a
 * promotion), blocks used, the EOF, the modification date and time when there
 * is a clock, and the backup bit, which drevise ORs into every entry a change
 * reaches ("mark entry as backupable").  A GS/OS extended file keeps its
 * storage type, key and EOF on the fork's mini-entry in the extended key block
 * (ProDOS Technical Note #25), which is written first; the entry's blocks used
 * counts every block the file owns, so it grows by the same amount.
 *
 * `nalloc' is the blocks the write allocated.  The rest of drevise -- the
 * modification time of every directory up to the volume's -- is pd_ripple's,
 * at close. */
static int
pd_revise(pd, nalloc)
struct pdnode *pd;
int            nalloc;
{
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned char  *e;
    unsigned char  *m;
    unsigned        blk;
    unsigned        used;
    long            now;
    int             error;

    pmp = pd->pd_pmp;
    e   = pd->pd_ent;

    if (PD_STORAGE(e) == PD_ST_EXTENDED) {
        blk = PD_GETW(&e[PD_E_KEYPTR]);
        error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        m = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk) + PD_X_DATA];
        used = PD_GETW(&m[3]) + (unsigned)nalloc;
        m[PD_M_STORAGE]   = (unsigned char)pd->pd_fst;
        m[PD_M_KEY]       = (unsigned char)pd->pd_fkey;
        m[PD_M_KEY + 1]   = (unsigned char)(pd->pd_fkey >> 8);
        m[3]              = (unsigned char)used;
        m[4]              = (unsigned char)(used >> 8);
        m[PD_M_EOF]       = (unsigned char)pd->pd_feof;
        m[PD_M_EOF + 1]   = (unsigned char)(pd->pd_feof >> 8);
        m[PD_M_EOF + 2]   = (unsigned char)(pd->pd_feof >> 16);
        error = bwrite(bp);
        if (error)
            return (error);
    } else {
        e[PD_E_STNL]      = (unsigned char)((pd->pd_fst << 4) | PD_NAMELEN(e));
        e[PD_E_KEYPTR]    = (unsigned char)pd->pd_fkey;
        e[PD_E_KEYPTR + 1] = (unsigned char)(pd->pd_fkey >> 8);
        e[PD_E_EOF]       = (unsigned char)pd->pd_feof;
        e[PD_E_EOF + 1]   = (unsigned char)(pd->pd_feof >> 8);
        e[PD_E_EOF + 2]   = (unsigned char)(pd->pd_feof >> 16);
    }
    used = PD_GETW(&e[PD_E_BLKSUSED]) + (unsigned)nalloc;
    e[PD_E_BLKSUSED]     = (unsigned char)used;
    e[PD_E_BLKSUSED + 1] = (unsigned char)(used >> 8);
    now = kern_ltime();
    if (now != 0L)
        pd_date(now, &e[PD_E_MODTIME]);
    e[PD_E_ACCESS] |= 0x20;

    /* AN UNLINKED FILE'S SLOT IS NOT ITS OWN -- a create may have taken it --
     * so its entry lives in core only, for pd_free to read. */
    if (pd->pd_refcnt != 0) {
        error = pd_putent(pmp, pd->pd_dirblk, pd->pd_diridx & ~PD_ADIDX, e);
        if (error)
            return (error);
        pd->pd_flag |= PDMOD;
    }
    return (pd_entsync(pd));
}


/* pd_write -- the VOP_WRITE slot.  ufs_write's loop, a ProDOS block at a time:
 * map the block under uio_offset, allocating and promoting as needed, read
 * it (half of its 1024-byte buffer belongs to the next ProDOS block), move the
 * run in, write it back.
 *
 * WHAT IS REFUSED: a directory (EISDIR, its bytes are the directory code's);
 * `._NAME' (EPERM -- the resource fork is not written here); a Pascal area
 * (ENOTSUP); and a write past a three-byte EOF, 16 MB (EFBIG, before a byte
 * moves).  A GS/OS extended file writes its data fork.
 *
 * A WRITE THAT FAILS PART-WAY keeps what it wrote and says so in the entry,
 * as ufs_write does: the blocks and the EOF they reach are revised even when
 * the error is returned. */
int
pd_write(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    struct pdnode *pd;
    struct buf    *bp;
    unsigned       blk;
    int            nalloc;
    int            on;
    int            n;
    int            error;
    int            rerror;

    if (uio->uio_rw != UIO_WRITE)
        kc_panic("pd_write mode");
    if (vp->v_type != VREG)
        return (EISDIR);
    pd = VTOPD(vp);
    if (pd->pd_diridx & PD_ADIDX)
        return (EPERM);
    error = pd_fork(pd);
    if (error)
        return (error);
    if (pd->pd_fst < PD_ST_SEEDLING || pd->pd_fst > PD_ST_TREE)
        return (ENOTSUP);
    if (ioflag & IO_APPEND)
        uio->uio_offset = pd->pd_feof;
    if (uio->uio_offset < 0L)
        return (EINVAL);
    if (uio->uio_resid == 0)
        return (0);
    if (uio->uio_offset + (off_t)uio->uio_resid > 0xFFFFFFL)
        return (EFBIG);

    nalloc = 0;
    while (uio->uio_resid > 0) {
        on = (int)(uio->uio_offset & (off_t)(PD_BLKSIZE - 1));
        n  = PD_BLKSIZE - on;
        if ((unsigned short)n > uio->uio_resid)
            n = (int)uio->uio_resid;
        error = pd_bmapw(pd, (unsigned)(uio->uio_offset >> 9), &blk, &nalloc);
        if (error)
            break;
        error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            break;
        }
        error = uiomove(&bp->b_addr[PD_BUFOFF(blk) + on], n, uio);
        if (error) {
            brelse(bp);
            break;
        }
        error = bwrite(bp);
        if (error)
            break;
        if (uio->uio_offset > pd->pd_feof)
            pd->pd_feof = uio->uio_offset;
    }
    rerror = pd_revise(pd, nalloc);
    return (error ? error : rerror);
}


/* pd_dirent -- the buffer holding subdirectory `dir''s entry in its parent,
 * and that entry, for the caller to change and bwrite or brelse.
 *
 * THE WAY UP IS THE HEADER's: `dir''s key block names the block and slot of
 * the directory's own entry (parent_pointer, parent_entry, prodos.h).  The
 * entry must be a subdirectory whose key_pointer is `dir', or the volume is
 * not as ProDOS 8 writes it and the answer is EIO. */
static int
pd_dirent(pmp, dir, bpp, epp)
struct pdmount  *pmp;
unsigned         dir;
struct buf     **bpp;
unsigned char  **epp;
{
    unsigned char *b;
    unsigned       blk;
    int            ent;
    int            error;

    error = bread(pmp->pm_devvp, PD_BUFBLK(dir), bpp);
    if (error) {
        brelse(*bpp);
        return (error);
    }
    b   = (unsigned char *)&(*bpp)->b_addr[PD_BUFOFF(dir) + PD_DB_ENTRIES];
    blk = PD_GETW(&b[PD_H_PARENTPTR]);
    ent = b[PD_H_PARENTENT];
    brelse(*bpp);
    if (ent < 1 || ent > PD_ENTPERBLK)
        return (EIO);
    error = bread(pmp->pm_devvp, PD_BUFBLK(blk), bpp);
    if (error) {
        brelse(*bpp);
        return (error);
    }
    b = (unsigned char *)&(*bpp)->b_addr[PD_BUFOFF(blk) + PD_ENTOFF(ent - 1)];
    if (PD_STORAGE(b) != PD_ST_SUBDIR || PD_GETW(&b[PD_E_KEYPTR]) != dir) {
        brelse(*bpp);
        return (EIO);
    }
    *epp = b;
    return (0);
}


/* pd_rippleup -- drevise's second half: directory `dir' and every directory
 * above it get the modification date and time in their entries in their
 * parents.  The volume directory has no entry and stops it. */
static int
pd_rippleup(pmp, dir)
struct pdmount *pmp;
unsigned        dir;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned char  when[4];
    unsigned       n;
    int            i;
    int            error;
    long           now;

    now = kern_ltime();
    if (now == 0L)
        return (0);
    pd_date(now, when);
    for (n = 0; dir != PD_VOLDIR_BLK && n < pmp->pm_totblks; n++) {
        error = pd_dirent(pmp, dir, &bp, &b);
        if (error)
            return (error);
        for (i = 0; i < 4; i++)
            b[PD_E_MODTIME + i] = when[i];
        dir = PD_GETW(&b[PD_E_HEADERPTR]);
        error = bwrite(bp);
        if (error)
            return (error);
    }
    return (0);
}


/* pd_ripple -- the ripple a written file owes, from the directory its entry
 * is in (header_pointer).  The MLI ripples when an open file is flushed; this
 * ripples when a written node is closed or goes inactive, once per PDMOD. */
int
pd_ripple(pd)
struct pdnode *pd;
{
    pd->pd_flag &= ~PDMOD;
    if (pd->pd_refcnt == 0)
        return (0);
    return (pd_rippleup(pd->pd_pmp, PD_GETW(&pd->pd_ent[PD_E_HEADERPTR])));
}


/* pd_fcount -- add `delta' to directory `dp''s header file_count, on disk and
 * in the node's copy of the header: credone's h_fcnt +1 for a create, and
 * destroy's zap_entry -1 for a removal. */
static int
pd_fcount(dp, delta)
struct pdnode *dp;
int            delta;
{
    struct buf    *bp;
    unsigned char *e;
    unsigned       n;
    int            i;
    int            error;

    error = bread(dp->pd_devvp, PD_BUFBLK(dp->pd_dirblk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    e = (unsigned char *)&bp->b_addr[PD_BUFOFF(dp->pd_dirblk) + PD_DB_ENTRIES];
    n = PD_GETW(&e[PD_H_FILECOUNT]) + (unsigned)delta;
    e[PD_H_FILECOUNT]     = (unsigned char)n;
    e[PD_H_FILECOUNT + 1] = (unsigned char)(n >> 8);
    for (i = 0; i < PD_ENTLEN; i++)
        dp->pd_ent[i] = e[i];
    return (bwrite(bp));
}


/* pd_slot -- where a new entry goes in directory `dp': the block and slot of
 * the first free entry, extending the directory by a block when it has none.
 *
 * A FREE ENTRY IS ONE WHOSE FIRST BYTE IS ZERO, looknam's test, and the key
 * block's slot 0 is the header and never free.  looknam stops reading blocks
 * once it has counted header file_count entries and then offers slot 1 of the
 * next block; reading the whole chain finds the same slot on any volume whose
 * file_count is right, and a free slot rather than an overwrite on one whose
 * count is low.
 *
 * EXTENSION IS xtndir's.  The volume directory cannot grow -- the MLI's
 * dirfull, ENOSPC here.  A subdirectory gets a new block, zeroed, whose
 * previous link is the last block, and the last block's next link is then
 * set to it; the directory's entry in its parent counts one more block used
 * and 512 more bytes of EOF (dinctbl).  The new block is written before
 * anything links it, so an interruption leaks it rather than chaining a
 * block with no back link. */
static int
pd_slot(dp, blkp, idxp)
struct pdnode *dp;
unsigned      *blkp;
int           *idxp;
{
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned char  *b;
    unsigned        blk;
    unsigned        last;
    unsigned        nb;
    unsigned        used;
    unsigned        n;
    int             idx;
    int             error;

    pmp = dp->pd_pmp;
    blk = dp->pd_dirblk;
    last = blk;
    for (n = 0; blk != 0 && n < pmp->pm_totblks; n++) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        for (idx = (blk == dp->pd_dirblk) ? 1 : 0; idx < PD_ENTPERBLK; idx++)
            if (b[PD_ENTOFF(idx)] == 0) {
                brelse(bp);
                *blkp = blk;
                *idxp = idx;
                return (0);
            }
        last = blk;
        blk = PD_GETW(&b[PD_DB_NEXT]);
        brelse(bp);
    }

    if (dp->pd_dirblk == PD_VOLDIR_BLK)
        return (ENOSPC);
    error = pd_balloc(pmp, &nb);
    if (error)
        return (error);
    error = bread(pmp->pm_devvp, PD_BUFBLK(nb), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(nb)];
    b[PD_DB_PREV]     = (unsigned char)last;
    b[PD_DB_PREV + 1] = (unsigned char)(last >> 8);
    error = bwrite(bp);
    if (error)
        return (error);
    error = bread(pmp->pm_devvp, PD_BUFBLK(last), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(last)];
    b[PD_DB_NEXT]     = (unsigned char)nb;
    b[PD_DB_NEXT + 1] = (unsigned char)(nb >> 8);
    error = bwrite(bp);
    if (error)
        return (error);

    error = pd_dirent(pmp, dp->pd_dirblk, &bp, &b);
    if (error)
        return (error);
    used = PD_GETW(&b[PD_E_BLKSUSED]) + 1;
    b[PD_E_BLKSUSED]     = (unsigned char)used;
    b[PD_E_BLKSUSED + 1] = (unsigned char)(used >> 8);
    used = PD_GETW(&b[PD_E_EOF + 1]) + 2;
    b[PD_E_EOF + 1] = (unsigned char)used;
    b[PD_E_EOF + 2] = (unsigned char)(used >> 8);
    error = bwrite(bp);
    if (error)
        return (error);
    *blkp = nb;
    *idxp = 0;
    return (0);
}


/* pd_putname -- storage type `st' and the name `nm' (`n' bytes) at `e', the
 * old name's bytes cleared first as the FST's move_new_name clears them.  The
 * name is stored in uppercase, as every ProDOS name is. */
static void
pd_putname(e, st, nm, n)
unsigned char *e;
int            st;
char          *nm;
int            n;
{
    int i;

    for (i = 0; i <= PD_NAMEMAX; i++)
        e[i] = 0;
    e[PD_E_STNL] = (unsigned char)((st << 4) | n);
    for (i = 0; i < n; i++)
        e[PD_E_NAME + i] = (unsigned char)PD_UPPER(nm[i]);
}


/* pd_setcase -- GS/OS's case word (Technical Note #8) for the name as given,
 * at an entry's version bytes: bit 15 valid, and a set bit from bit 14 down
 * for each lowercase character.  Valid even for an all-uppercase name, so it
 * lists as it was typed. */
static void
pd_setcase(e, nm, n)
unsigned char *e;
char          *nm;
int            n;
{
    unsigned cw;
    int      i;

    cw = 0x8000;
    for (i = 0; i < n; i++)
        if (nm[i] >= 'a' && nm[i] <= 'z')
            cw |= 0x4000 >> i;
    e[PD_E_VERSION] = (unsigned char)cw;
    e[PD_E_MINVER]  = (unsigned char)(cw >> 8);
}


/* pd_newent -- the bytes a new entry and a new directory's header begin
 * with, at `e': storage type and name, and the creation date and time. */
static void
pd_newent(e, st, nm, n, now)
unsigned char *e;
int            st;
char          *nm;
int            n;
long           now;
{
    int i;

    for (i = 0; i < PD_ENTLEN; i++)
        e[i] = 0;
    pd_putname(e, st, nm, n);
    if (now != 0L)
        pd_date(now, &e[PD_E_CREATE]);
}


/* THE RESERVED BYTES OF A NEW SUBDIRECTORY HEADER, +$10 to +$17, as the MLI
 * writes them: cmvpass copies eight bytes from `pass' ($75), which runs on
 * into `xdosver'. */
static unsigned char pd_hdrpass[8] = { 0x75, 0x00, 0x00, 0xC3, 0x27, 0x0D, 0x00, 0x00 };


/* pd_create -- the VOP_CREATE and VOP_MKDIR slots: a seedling file, or a
 * directory when va_type is VDIR.  ufs_create's contract: ni_dvp is read and
 * left for the caller to release, and on success ni_vp is the new node,
 * referenced and locked.
 *
 * THE ENTRY IS ProDOS 8's create (MliSrc.aii, creat1 through credone):
 *   - a key block always, alc1blk's and zeroed: a file's first data block, or
 *     a directory's key block holding its header;
 *   - blocks used 1, and EOF 0 for a file and 512 for a directory;
 *   - creation and modification date and time now, when there is a clock;
 *   - header_pointer the directory's key block;
 *   - file type $00 for a file, which is GS/OS's ProDOS FST's default
 *     (default_entry), and $0F for a directory, and auxiliary type 0.
 * THREE FIELDS ARE DECIDED HERE, where the MLI takes them from its caller:
 *   - access is destroy, rename and backup, and read and write from the
 *     owner's bits of the mode asked for: $E3 for 0644, the FST's default.
 *     The MLI's drevise and the FST's create_common both set backup;
 *   - +$1C is GS/OS's case word for the name as given (GS/OS Technical Note
 *     #8), valid ($8000) even when the name is all uppercase, so it lists as
 *     it was typed.  The FST leaves an all-uppercase name without one;
 *   - the version bytes it replaces are 0, which is xdosver's.
 *
 * A DIRECTORY's HEADER is the entry's first $1F bytes with storage type $E,
 * then cmvpass's reserved bytes, version 0, access $C3, $27 bytes per entry,
 * $0D entries per block, no files, and cmvparnt's parent_pointer and
 * parent_entry: the block and slot (from 1) of the new entry, and $27.
 *
 * THE ORDER IS pd_write's: the key block, then the entry, then the
 * directory's file_count (credone's h_fcnt), then the ripple.  A name that
 * does not fit ProDOS never gets here: pd_lookup refused it. */
int
pd_create(ndp, vap)
struct nameidata *ndp;
struct vattr     *vap;
{
    struct pdnode  *dp;
    struct pdnode  *pd;
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned char  *e;
    unsigned        blk;
    unsigned        key;
    unsigned        cw;
    long            now;
    int             idx;
    int             dir;
    int             n;
    int             i;
    int             error;

    dp  = VTOPD(ndp->ni_dvp);
    pmp = dp->pd_pmp;
    n   = (int)ndp->ni_namelen;
    dir = (vap->va_type == VDIR);

    error = pd_slot(dp, &blk, &idx);
    if (error)
        return (error);
    error = pd_balloc(pmp, &key);
    if (error)
        return (error);
    now = kern_ltime();

    if (dir) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(key), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        e = (unsigned char *)&bp->b_addr[PD_BUFOFF(key) + PD_DB_ENTRIES];
        pd_newent(e, PD_ST_SUBDIRHDR, ndp->ni_ptr, n, now);
        for (i = 0; i < 8; i++)
            e[0x10 + i] = pd_hdrpass[i];
        e[PD_E_ACCESS]        = 0xC3;
        e[PD_H_ENTRYLEN]      = PD_ENTLEN;
        e[PD_H_ENTPERBLK]     = PD_ENTPERBLK;
        e[PD_H_PARENTPTR]     = (unsigned char)blk;
        e[PD_H_PARENTPTR + 1] = (unsigned char)(blk >> 8);
        e[PD_H_PARENTENT]     = (unsigned char)(idx + 1);
        e[PD_H_PARENTENT + 1] = PD_ENTLEN;
        error = bwrite(bp);
        if (error)
            return (error);
    }

    error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    e = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk) + PD_ENTOFF(idx)];
    pd_newent(e, dir ? PD_ST_SUBDIR : PD_ST_SEEDLING, ndp->ni_ptr, n, now);
    e[PD_E_FILETYPE]    = dir ? 0x0F : 0x00;
    e[PD_E_KEYPTR]      = (unsigned char)key;
    e[PD_E_KEYPTR + 1]  = (unsigned char)(key >> 8);
    e[PD_E_BLKSUSED]    = 1;
    e[PD_E_EOF + 1]     = dir ? 2 : 0;
    pd_setcase(e, ndp->ni_ptr, n);
    e[PD_E_ACCESS]      = (unsigned char)(0xE0 |
                          ((vap->va_mode & 0400) ? 0x01 : 0) |
                          ((vap->va_mode & 0200) ? 0x02 : 0));
    for (i = 0; i < 4; i++)
        e[PD_E_MODTIME + i] = e[PD_E_CREATE + i];
    e[PD_E_HEADERPTR]     = (unsigned char)dp->pd_dirblk;
    e[PD_E_HEADERPTR + 1] = (unsigned char)(dp->pd_dirblk >> 8);
    error = bwrite(bp);
    if (error)
        return (error);

    error = pd_fcount(dp, 1);
    if (error)
        return (error);
    error = pd_rippleup(pmp, dp->pd_dirblk);
    if (error)
        return (error);

    error = pdget(pmp, dir ? key : blk, dir ? 0 : idx, &pd);
    if (error)
        return (error);
    ndp->ni_vp = PDTOV(pd);
    return (0);
}


/* pd_bfree -- mark block `blk' free in the volume bitmap: dealloc's bit, set
 * where alc1blk clears it. */
static int
pd_bfree(pmp, blk)
struct pdmount *pmp;
unsigned        blk;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       map;
    int            error;

    if (blk == 0 || blk >= pmp->pm_totblks)
        return (EIO);
    map = pmp->pm_bitmap + (blk >> 12);
    error = bread(pmp->pm_devvp, PD_BUFBLK(map), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(map)];
    b[(blk & 4095) >> 3] |= (unsigned char)(0x80 >> (blk & 7));
    pmp->pm_free++;
    return (bwrite(bp));
}


/* pd_freefork -- free a seedling, sapling or tree whose key block is `key'.
 * An index block -- a sapling's key, a tree's master and each sub-index --
 * gives back every block it names (a tree's are sub-indexes, freed the same
 * way), and is then written back FLIPPED and freed.  Both ProDOS 8 (dealblk,
 * swapme under delflag) and GS/OS's ProDOS FST (kill_tree, kill_sapling,
 * get_and_flip, write_flipped) swap each entry's low and high bytes in a
 * deleted index block before freeing it. */
static int
pd_freefork(pmp, st, key)
struct pdmount *pmp;
int             st;
unsigned        key;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       blk;
    int            i;
    int            c;
    int            error;

    if (key == 0)
        return (0);
    if (st == PD_ST_SEEDLING)
        return (pd_bfree(pmp, key));
    if (st != PD_ST_SAPLING && st != PD_ST_TREE)
        return (EIO);
    for (i = 0; i < 256; i++) {
        error = pd_getidx(pmp, key, i, &blk);
        if (error)
            return (error);
        if (blk == 0)
            continue;
        error = (st == PD_ST_TREE) ? pd_freefork(pmp, PD_ST_SAPLING, blk) :
                                     pd_bfree(pmp, blk);
        if (error)
            return (error);
    }
    error = bread(pmp->pm_devvp, PD_BUFBLK(key), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(key)];
    for (i = 0; i < 256; i++) {
        c = b[i];
        b[i] = b[256 + i];
        b[256 + i] = (unsigned char)c;
    }
    error = bwrite(bp);
    if (error)
        return (error);
    return (pd_bfree(pmp, key));
}


/* pd_free -- give back every block of a node whose entry pd_remove took away.
 * Called from pd_inactive once nothing uses the node.
 *   - a seedling, sapling or tree: pd_freefork;
 *   - a GS/OS extended file: both forks, then the extended key block, which is
 *     the FST's kill_resource (ProDOS 8's destroy refuses the type);
 *   - a directory: its header's first byte zeroed ("make it an invalid
 *     subdir", destroy's dsdir1a), then every block of its chain, dsdir2's
 *     walk.
 * The node's own copy of its entry loses its storage type after, so nothing
 * frees it twice. */
int
pd_free(pd)
struct pdnode *pd;
{
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned char  *b;
    unsigned char  *e;
    unsigned        blk;
    unsigned        next;
    unsigned        dk;
    unsigned        rk;
    unsigned        n;
    int             ds;
    int             rs;
    int             error;

    pmp = pd->pd_pmp;
    e   = pd->pd_ent;
    error = 0;
    if (PD_STORAGE(e) == PD_ST_SUBDIRHDR) {
        blk = pd->pd_dirblk;
        for (n = 0; blk != 0 && n < pmp->pm_totblks && error == 0; n++) {
            error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
            if (error) {
                brelse(bp);
                break;
            }
            b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
            next = PD_GETW(&b[PD_DB_NEXT]);
            if (blk == pd->pd_dirblk) {
                b[PD_DB_ENTRIES] = 0;
                error = bwrite(bp);
            } else
                brelse(bp);
            if (error == 0)
                error = pd_bfree(pmp, blk);
            blk = next;
        }
    } else if (PD_STORAGE(e) == PD_ST_EXTENDED) {
        blk = PD_GETW(&e[PD_E_KEYPTR]);
        error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        b  = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        ds = b[PD_X_DATA + PD_M_STORAGE] & 0x0F;
        dk = PD_GETW(&b[PD_X_DATA + PD_M_KEY]);
        rs = b[PD_X_RSRC + PD_M_STORAGE] & 0x0F;
        rk = PD_GETW(&b[PD_X_RSRC + PD_M_KEY]);
        brelse(bp);
        if ((error = pd_freefork(pmp, ds, dk)) == 0 &&
            (error = pd_freefork(pmp, rs, rk)) == 0)
            error = pd_bfree(pmp, blk);
    } else if (PD_STORAGE(e) != PD_ST_DELETED)
        error = pd_freefork(pmp, PD_STORAGE(e), PD_GETW(&e[PD_E_KEYPTR]));
    e[PD_E_STNL] = 0;
    return (error);
}


/* pd_unname -- take node `pd''s name out of directory `dp': pd_remove's
 * work, and what a rename does to a name it replaces.  The destroy bit and a
 * directory's emptiness are asked first; the node and its twin keep their
 * blocks until pd_inactive. */
static int
pd_unname(pd, dp)
struct pdnode *pd;
struct pdnode *dp;
{
    struct pdmount *pmp;
    struct pdnode  *tw;
    struct buf     *bp;
    unsigned char  *e;
    int             error;

    pmp = pd->pd_pmp;
    if (PDTOV(pd)->v_type == VDIR) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(pd->pd_dirblk), &bp);
        if (error == 0) {
            e = (unsigned char *)&bp->b_addr[PD_BUFOFF(pd->pd_dirblk) +
                                             PD_DB_ENTRIES];
            if (PD_GETW(&e[PD_H_FILECOUNT]) != 0)
                error = ENOTEMPTY;
        }
        brelse(bp);
        if (error == 0)
            error = pd_dirent(pmp, pd->pd_dirblk, &bp, &e);
    } else {
        error = bread(pmp->pm_devvp, PD_BUFBLK(pd->pd_dirblk), &bp);
        if (error)
            brelse(bp);
        else
            e = (unsigned char *)&bp->b_addr[PD_BUFOFF(pd->pd_dirblk) +
                                             PD_ENTOFF(pd->pd_diridx)];
    }
    if (error)
        return (error);
    if ((e[PD_E_ACCESS] & 0x80) == 0) {
        brelse(bp);
        return (EPERM);
    }
    e[PD_E_STNL] = 0;
    if ((error = bwrite(bp)) != 0)
        return (error);
    tw = pd_twin(pd);
    if (tw)
        tw->pd_refcnt = 0;
    pd->pd_refcnt = 0;
    if ((error = pd_fcount(dp, -1)) != 0)
        return (error);
    return (pd_rippleup(pmp, dp->pd_dirblk));
}


/* pd_remove -- the VOP_REMOVE and VOP_RMDIR slots.  ufs_remove's contract:
 * ni_vp is released here, exactly once, on every path, and ni_dvp is the
 * caller's.  vfs_unlink has refused a directory and vfs_rmdir anything else.
 *
 * IT TAKES THE NAME AWAY AND FREES NOTHING, as ufs_remove and pcfs_remove do:
 * the blocks go at pd_inactive when the last reference does, so a file
 * unlinked while it is open keeps working until it is closed.  What goes now
 * is destroy's zap_entry: the entry's first byte (storage type and name
 * length -- the name itself stays, as ProDOS 8 and GS/OS leave it), the
 * directory's file_count, and drevise's ripple.  pd_refcnt drops to 0 on the
 * node and its twin, which pdget then passes over.
 *
 * REFUSED, as ProDOS 8's destroy refuses:
 *   - a clear destroy bit ($80), EPERM (accserr);
 *   - a directory with files in it, ENOTEMPTY (dsdir1: file_count not 0);
 *   - `rmdir .', EINVAL, which is ufs_rmdir's own. */
int
pd_remove(ndp)
struct nameidata *ndp;
{
    struct vnode *vp;
    int           error;

    vp = ndp->ni_vp;
    error = (ndp->ni_dvp == vp) ? EINVAL :
            pd_unname(VTOPD(vp), VTOPD(ndp->ni_dvp));
    if (ndp->ni_dvp == vp)
        vrele(vp);
    else {
        pd_unlock(vp);          /* vput, which this module does not import */
        vrele(vp);
    }
    return (error);
}


/* THE ENTRY A RENAME MOVES, copied out of its block and written into its new
 * one.  Module BSS rather than 39 bytes of a 512-byte kernel stack; kernel C
 * runs to completion inside a system call, so nothing else fills it between. */
static unsigned char pd_mvent[PD_ENTLEN];


/* pd_rename -- the VOP_RENAME slot.  ufs_rename's contract: the caller owns
 * both ni_dvp, and fndp->ni_vp (unlocked) and tndp->ni_vp (locked, when there
 * is one) are released here exactly once each.
 *
 * WITHIN A DIRECTORY it is ProDOS 8's rename: the entry keeps its slot and
 * takes the new name (rname9), and a directory's header takes it too
 * (mvrotnam).  The node's key is unchanged.
 *
 * BETWEEN DIRECTORIES it is GS/OS's ProDOS FST change_path (move_file): a slot
 * is found in the new directory, extending it if need be; the old entry is
 * zeroed and its directory's file count and dates follow; the entry is written
 * into the new slot with the new name and header_pointer, and that
 * directory's count and dates follow; a directory's header takes its new
 * parent_pointer, parent_entry and name (fix_subdir).  The old entry goes
 * first, so an interruption leaks a file rather than naming its blocks
 * twice.  A FILE's node is keyed on its entry and is refiled under the new
 * slot (pd_rekey); a directory's is keyed on its own key block and stays.
 *
 * EVERY ENTRY WRITTEN takes the new name's case word and the backup bit.
 *
 * REFUSED:
 *   - `.', `..' or a directory's own name as the thing moved, EINVAL, and a
 *     directory moved beneath itself, EINVAL -- ufs_rename's and checkpath's;
 *   - a clear rename bit ($40), EPERM, unless only the directory changes: the
 *     MLI's accserr, narrowed as change_path narrows it;
 *   - a name that exists is replaced as rename(2) requires, which neither
 *     ProDOS does: it is removed first (pd_unname), so its destroy bit and a
 *     directory's emptiness decide, EPERM and ENOTEMPTY. */
int
pd_rename(fndp, tndp)
struct nameidata *fndp;
struct nameidata *tndp;
{
    struct pdnode  *pd;
    struct pdnode  *fdp;
    struct pdnode  *tdp;
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned char  *e;
    char           *nm;
    unsigned        sblk;
    unsigned        dblk;
    unsigned        key;
    int             sidx;
    int             didx;
    int             dir;
    int             n;
    int             i;
    int             error;

    pd  = VTOPD(fndp->ni_vp);
    fdp = VTOPD(fndp->ni_dvp);
    tdp = VTOPD(tndp->ni_dvp);
    pmp = pd->pd_pmp;
    nm  = tndp->ni_ptr;
    n   = (int)tndp->ni_namelen;
    dir = (fndp->ni_vp->v_type == VDIR);
    error = 0;

    if (dir && (fdp == pd || fndp->ni_isdotdot))
        error = EINVAL;
    for (key = tdp->pd_dirblk, i = 0;
         error == 0 && dir && tdp != fdp && key != PD_VOLDIR_BLK &&
         i < (int)pmp->pm_totblks; i++) {
        if (key == pd->pd_dirblk)
            error = EINVAL;
        else if ((error = pd_dirent(pmp, key, &bp, &e)) == 0) {
            key = PD_GETW(&e[PD_E_HEADERPTR]);
            brelse(bp);
        }
    }

    /* The entry and where it is: a file's key says, a directory's header. */
    if (dir) {
        sblk = PD_GETW(&pd->pd_ent[PD_H_PARENTPTR]);
        sidx = pd->pd_ent[PD_H_PARENTENT] - 1;
    } else {
        sblk = pd->pd_dirblk;
        sidx = pd->pd_diridx;
    }
    if (error == 0) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(sblk), &bp);
        e = (unsigned char *)&bp->b_addr[PD_BUFOFF(sblk) + PD_ENTOFF(sidx)];
        for (i = 0; error == 0 && i < PD_ENTLEN; i++)
            pd_mvent[i] = e[i];
        brelse(bp);
    }
    if (error == 0 && (pd_mvent[PD_E_ACCESS] & 0x40) == 0) {
        for (i = 0; i < n && pd_mvent[PD_E_NAME + i] == PD_UPPER(nm[i]); i++)
            ;
        if (i < n || PD_NAMELEN(pd_mvent) != n)
            error = EPERM;
    }
    if (error == 0 && tndp->ni_vp)
        error = pd_unname(VTOPD(tndp->ni_vp), tdp);

    dblk = sblk;
    didx = sidx;
    if (error == 0 && tdp != fdp && (error = pd_slot(tdp, &dblk, &didx)) == 0) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(sblk), &bp);
        if (error)
            brelse(bp);
        else {
            bp->b_addr[PD_BUFOFF(sblk) + PD_ENTOFF(sidx)] = 0;
            if ((error = bwrite(bp)) == 0 && (error = pd_fcount(fdp, -1)) == 0)
                error = pd_rippleup(pmp, fdp->pd_dirblk);
        }
    }

    if (error == 0) {
        pd_putname(pd_mvent, PD_STORAGE(pd_mvent), nm, n);
        pd_setcase(pd_mvent, nm, n);
        pd_mvent[PD_E_ACCESS] |= 0x20;
        pd_mvent[PD_E_HEADERPTR]     = (unsigned char)tdp->pd_dirblk;
        pd_mvent[PD_E_HEADERPTR + 1] = (unsigned char)(tdp->pd_dirblk >> 8);
        error = pd_putent(pmp, dblk, didx, pd_mvent);
        if (error == 0 && tdp != fdp)
            error = pd_fcount(tdp, 1);
        if (error == 0)
            error = pd_rippleup(pmp, tdp->pd_dirblk);
    }
    if (error == 0 && dir) {
        error = bread(pmp->pm_devvp, PD_BUFBLK(pd->pd_dirblk), &bp);
        if (error)
            brelse(bp);
        else {
            e = (unsigned char *)&bp->b_addr[PD_BUFOFF(pd->pd_dirblk) +
                                             PD_DB_ENTRIES];
            pd_putname(e, PD_ST_SUBDIRHDR, nm, n);
            e[PD_H_PARENTPTR]     = (unsigned char)dblk;
            e[PD_H_PARENTPTR + 1] = (unsigned char)(dblk >> 8);
            e[PD_H_PARENTENT]     = (unsigned char)(didx + 1);
            for (i = 0; i < PD_ENTLEN; i++)
                pd->pd_ent[i] = e[i];
            error = bwrite(bp);
        }
    } else if (error == 0) {
        for (i = 0; i < PD_ENTLEN; i++)
            pd->pd_ent[i] = pd_mvent[i];
        pd_rekey(pd, dblk, didx);
        (void)pd_entsync(pd);
    }

    vrele(fndp->ni_vp);
    if (tndp->ni_vp) {
        pd_unlock(tndp->ni_vp);
        vrele(tndp->ni_vp);
    }
    return (error);
}


/* pd_trimidx -- give back every block index block `iblk' names from entry
 * `from' on, each entry cleared (and written) before its block is freed. */
static int
pd_trimidx(pmp, iblk, from)
struct pdmount *pmp;
unsigned        iblk;
unsigned        from;
{
    unsigned blk;
    int      error;

    for (; from < 256; from++) {
        if ((error = pd_getidx(pmp, iblk, (int)from, &blk)) != 0)
            return (error);
        if (blk != 0 && ((error = pd_setidx(pmp, iblk, (int)from, 0)) != 0 ||
                         (error = pd_bfree(pmp, blk)) != 0))
            return (error);
    }
    return (0);
}


/* pd_trunc -- set a file's EOF to `len', ProDOS 8's set_eof.
 *
 * LONGER ALLOCATES NOTHING: the new bytes are holes until written.
 *
 * SHORTER IS detree's: every data block past the new end goes back (a tree's
 * wholly unused sub-indexes with theirs), each index entry cleared before its
 * block is freed; the bytes past the end in the last block kept are zeroed
 * (seedel2); and a tree that now fits one index becomes a sapling, and a
 * sapling that fits one block a seedling (shrink), its old key block freed
 * only after the entry stops naming it.  A tree whose first sub-index is a
 * hole stays a tree.  A seedling always keeps its key
 * block, as create gives it one, allocating one if that block was a hole.
 * Freed index blocks are not flipped: set_eof clears their entries rather
 * than swapping them (swapme without delflag). */
static int
pd_trunc(pd, len)
struct pdnode *pd;
long           len;
{
    struct pdmount *pmp;
    struct buf     *bp;
    unsigned        keep;
    unsigned        sub;
    unsigned        blk;
    unsigned        drop[2];
    long            free0;
    int             ndrop;
    int             i;
    int             error;

    pmp = pd->pd_pmp;
    if ((error = pd_fork(pd)) != 0)
        return (error);
    if (pd->pd_fst < PD_ST_SEEDLING || pd->pd_fst > PD_ST_TREE)
        return (ENOTSUP);
    if (len < 0L)
        return (EINVAL);
    if (len > 0xFFFFFFL)
        return (EFBIG);
    free0 = pmp->pm_free;
    ndrop = 0;
    if (len < pd->pd_feof) {
        keep = (unsigned)((len + 511L) >> 9);
        if (pd->pd_fst == PD_ST_SAPLING)
            error = pd_trimidx(pmp, pd->pd_fkey, keep);
        for (i = 0; pd->pd_fst == PD_ST_TREE && i < 128 && error == 0; i++) {
            if ((error = pd_getidx(pmp, pd->pd_fkey, i, &sub)) != 0 || sub == 0)
                continue;
            if (keep <= (unsigned)i << 8) {
                if ((error = pd_trimidx(pmp, sub, 0)) == 0 &&
                    (error = pd_setidx(pmp, pd->pd_fkey, i, 0)) == 0)
                    error = pd_bfree(pmp, sub);
            } else if (keep < ((unsigned)i + 1) << 8)
                error = pd_trimidx(pmp, sub, keep - ((unsigned)i << 8));
        }
        if (error == 0 && (len & 511L) != 0L &&
            (error = pd_bmap(pd, (unsigned)(len >> 9), &blk)) == 0 && blk) {
            if ((error = bread(pmp->pm_devvp, PD_BUFBLK(blk), &bp)) != 0)
                brelse(bp);
            else {
                for (i = (int)(len & 511L); i < PD_BLKSIZE; i++)
                    bp->b_addr[PD_BUFOFF(blk) + i] = 0;
                error = bwrite(bp);
            }
        }
        if (error == 0 && pd->pd_fst == PD_ST_TREE && keep <= 256 &&
            (error = pd_getidx(pmp, pd->pd_fkey, 0, &sub)) == 0 && sub != 0) {
            drop[ndrop++] = pd->pd_fkey;
            pd->pd_fkey = sub;
            pd->pd_fst  = PD_ST_SAPLING;
        }
        if (error == 0 && pd->pd_fst == PD_ST_SAPLING && keep <= 1) {
            blk = 0;
            if (pd->pd_fkey && (error = pd_getidx(pmp, pd->pd_fkey, 0, &blk)) == 0)
                drop[ndrop++] = pd->pd_fkey;
            pd->pd_fkey = blk;
            pd->pd_fst  = PD_ST_SEEDLING;
        }
        if (error == 0 && pd->pd_fst == PD_ST_SEEDLING && pd->pd_fkey == 0 &&
            (error = pd_balloc(pmp, &blk)) == 0)
            pd->pd_fkey = blk;
        if (error)
            return (error);
    }
    pd->pd_feof = len;
    error = pd_revise(pd, (int)(free0 - pmp->pm_free) - ndrop);
    for (i = 0; i < ndrop && error == 0; i++)
        error = pd_bfree(pmp, drop[i]);
    return (error);
}


/* pd_setattr -- the VOP_SETATTR slot, for a length only: truncate(2),
 * ftruncate(2) and open's O_TRUNC.  ProDOS keeps no owner, and the mode and
 * the times are not yet written back, so a request for any of them is
 * refused, as it was before this slot was filled.  `._NAME' is EPERM, a
 * directory EISDIR. */
int
pd_setattr(vp, vap, cred)
struct vnode *vp;
struct vattr *vap;
char         *cred;
{
    if (vap->va_size == (off_t)VA_UNSET)
        return (ENOTSUP);
    if (vp->v_type == VDIR)
        return (EISDIR);
    if (VTOPD(vp)->pd_diridx & PD_ADIDX)
        return (EPERM);
    return (pd_trunc(VTOPD(vp), vap->va_size));
}


/* pd_close -- the VOP_CLOSE slot: a node a write revised ripples its
 * directories' times now. */
int
pd_close(vp, fflag, cred)
struct vnode *vp;
int           fflag;
char         *cred;
{
    if (VTOPD(vp)->pd_flag & PDMOD)
        return (pd_ripple(VTOPD(vp)));
    return (0);
}


/* THE HANDOVER, prodos.h's struct pdwops, in its order. */
static struct pdwops pd_wtab = {
    pd_write, pd_close, pd_create, pd_remove, pd_rename, pd_setattr,
    pd_free, pd_ripple
};

/* The vector prodos.mod's nodes use once this module is loaded: empty here,
 * filled at load by pd_setwriteops. */
static struct vnodeops pd_wvops;

/* prodosw_init -- prodosw.mod's mod_init: the write half goes to prodos.mod. */
int
prodosw_init()
{
    return (pd_setwriteops(&pd_wtab, &pd_wvops));
}
