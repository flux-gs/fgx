/* FGX-Origin: original -- FGX code.  Its SHAPE is netbsd-0-9's
 * sys/isofs/isofs_lookup.c and isofs_vnops.c (a read-only foreign format
 * behind vnodeops) and FGX's own ufs_lookup.c and ufs_vnops.c (the lookup and
 * readdir contracts), consulted and not ported; no BSD carried a ProDOS
 * filesystem.  The on-disk layout is what ProDOS 8's MLI (MliSrc.aii) writes;
 * prodos.h notes the field "Beneath Apple ProDOS" describes more narrowly.
 * prodos_vnops.c -- reading a ProDOS volume: lookup, read, readdir.
 * ProDOS FST P3.
 *
 * NAMES ARE ProDOS's, FOLDED ON THE WAY IN.  A name on disk is uppercase A-Z
 * 0-9 and `.', a letter first, at most 15 bytes.  lookup folds a-z to A-Z and
 * refuses anything else with EINVAL, which is the retired FGX resolver's rule
 * and GS/OS's ("Neither ProDOS 8 nor the ProDOS FST are case sensitive when
 * searching for filenames", GS/OS Technical Note #8).  readdir hands a name
 * up in the display case GS/OS recorded for it, or lowercase where none was
 * recorded; either way it is a name lookup finds.  THE LEADING-DOT MAPPING the
 * retired resolver also had (".profile" as "DOT.PROFILE") IS NOT CARRIED: it
 * existed so ProDOS could hold a Unix home directory, and a mounted foreign
 * volume is not asked to.
 *
 * A GS/OS EXTENDED FILE IS TWO NAMES, macOS's answer on a filesystem with no
 * extended attributes: NAME reads its data fork, and `._NAME' is an
 * AppleDouble file of its Finder info and resource fork (prodos.h says what
 * the bytes are).  No ProDOS name begins with `.', so `._NAME' can never be
 * a name on the volume, and tar and cp carry the pair as two files.
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
extern int  uiomove();
extern void vref();
extern void kc_panic();
extern int  pdget();
extern int  pd_lock();
extern int  pd_unlock();
extern int  pd_access();
extern long kern_epoch();

/* A hole reads as zeros, moved from here.  Module BSS, for vfs_dirblk's
 * reason: 512 bytes is the whole of a kernel stack. */
static char pd_zeroblk[PD_BLKSIZE];
/* readdir's landing ground, likewise.  It is filled and moved inside one
 * readdir with no sleep between -- bread is synchronous (vfs_bio.c) -- so two
 * callers cannot interleave in it. */
static char pd_dirbuf[DIRBLKSIZ];
/* A directory block, copied out so readdir holds no buffer while it reads an
 * extended key block; and a `._NAME''s header, filled and moved in one read.
 * Neither crosses a sleep between filling and use. */
static unsigned char pd_dblk[PD_BLKSIZE];
static unsigned char pd_adbuf[PD_ADHDRLEN];

/* THE GS/OS HFS FST's PRODOS-TO-HFS TYPE TABLE (hfs.fst.main,
 * conversion_table): ProDOS type, aux type, then the HFS type and creator it
 * becomes.  pd_adhdr applies it as the FST does. */
static unsigned char pd_hfstab[] = {
    0xB3, 0x00, 'P', 'S', '1', '6', 'p', 'd', 'o', 's',
    0xFF, 0x00, 'P', 'S', 'Y', 'S', 'p', 'd', 'o', 's',
    0x00, 0x00, 'B', 'I', 'N', 'A', 'p', 'd', 'o', 's',
    0x04, 0x00, 'T', 'E', 'X', 'T', 'p', 'd', 'o', 's',
    0xD7, 0x00, 'M', 'I', 'D', 'I', 'p', 'd', 'o', 's',
    0xD8, 0x00, 'A', 'I', 'F', 'F', 'p', 'd', 'o', 's',
    0xD8, 0x01, 'A', 'I', 'F', 'C', 'p', 'd', 'o', 's',
    0xE0, 0x05, 'd', 'I', 'm', 'g', 'd', 'C', 'p', 'y'
};
#define PD_HFSROW       10


/* pd_dirwalk -- follow a directory's chain `k' links from its key block.
 * *blkp is the block reached, 0 if the chain ended first; *np is how many
 * blocks were passed, which with k past the end is the chain's length.
 * Bounded by the volume's block count, so a chain a corrupt volume loops
 * ends rather than hangs. */
int
pd_dirwalk(pd, k, blkp, np)
struct pdnode *pd;
unsigned       k;
unsigned      *blkp;
unsigned      *np;
{
    struct buf *bp;
    unsigned    blk;
    unsigned    n;
    int         error;

    blk = pd->pd_dirblk;
    for (n = 0; n < k && blk != 0 && n < pd->pd_pmp->pm_totblks; n++) {
        error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        blk = PD_GETW(&bp->b_addr[PD_BUFOFF(blk) + PD_DB_NEXT]);
        brelse(bp);
    }
    *blkp = blk;
    *np = n;
    return (0);
}


/* pd_parent -- the key block of a directory's parent.
 *
 * NO HEADER STORES IT.  parent_pointer is the block holding this directory's
 * ENTRY (prodos.h), so: if that block is a key block -- its previous-block
 * link is zero, which ProDOS writes only in a key block -- it is the answer;
 * otherwise it is a continuation block, and the entry at parent_entry within
 * it carries header_pointer, which every entry holds and which names its
 * directory's key block.  Taking the prev test first also reads a pointer
 * written to Beneath Apple ProDOS's description, which is always a key block,
 * without consulting parent_entry, whose numbering the book gives one lower.
 *
 * The volume directory is its own parent, as UFS's root is; namei steps over
 * a mount root before it asks. */
static int
pd_parent(dp, keyp)
struct pdnode *dp;
unsigned      *keyp;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       blk;
    int            ent;
    int            error;

    *keyp = dp->pd_dirblk;
    if (dp->pd_dirblk == PD_VOLDIR_BLK)
        return (0);
    blk = PD_GETW(&dp->pd_ent[PD_H_PARENTPTR]);
    ent = dp->pd_ent[PD_H_PARENTENT];
    error = bread(dp->pd_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
    if (PD_GETW(&b[PD_DB_PREV]) == 0)
        *keyp = blk;
    else if (ent >= 1 && ent <= PD_ENTPERBLK)
        *keyp = PD_GETW(&b[PD_ENTOFF(ent - 1) + PD_E_HEADERPTR]);
    else
        error = EIO;
    brelse(bp);
    return (error);
}


/* pd_stamp -- a ProDOS date and time as seconds since the epoch, 0 for none.
 * `p' is a date word then a time word, each low byte first.  The date is
 * YYYYYYYM MMMDDDDD and the time's high byte the hour, low byte the minute
 * ("Beneath Apple ProDOS" p. 6-32).  THE YEAR IS READ AS GS/OS's ProDOS FST
 * READS IT: 0-39 are 2000-2039 and anything from 40 up is 1900 plus it --
 * `cmp #40' / `bcs @store_it' / `adc #100', with no upper bound (ProDOS.FST,
 * where it converts a directory date for GetFileInfo).  That is Technical Note
 * #28's 1940-2039 for 0-99, and it also reads the 100-127 the note calls
 * invalid, which volumes carry: a 2019 file stored as year 119.  A zero date
 * is "no date", as it is to the MLI. */
long
pd_stamp(p)
unsigned char *p;
{
    unsigned d;
    unsigned t;
    int      y;

    d = PD_GETW(p);
    t = PD_GETW(&p[2]);
    y = (int)(d >> 9);
    if (d == 0 || (t >> 8) > 23 || (t & 0xFF) > 59)
        return (0L);
    return (kern_epoch((y < 40) ? 2000 + y : 1900 + y, (int)((d >> 5) & 15),
                       (int)(d & 31), (int)(t >> 8), (int)(t & 0xFF), 0));
}


/* pd_dirstamp -- a directory's modification time.  ITS HEADER HAS NONE -- only
 * a creation stamp, at the file entry's creation offset -- so it is read from
 * the directory's entry in its parent, the one parent_pointer and
 * parent_entry name (prodos.h).  The entry's key_pointer must name this
 * directory, which also accepts the book's parent_entry, one lower.  The
 * volume directory has no entry anywhere, and neither does a directory whose
 * pointers are wrong: those answer their header's creation stamp. */
long
pd_dirstamp(dp)
struct pdnode *dp;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       blk;
    long           t;
    int            ent;
    int            i;

    t = pd_stamp(&dp->pd_ent[PD_E_CREATE]);
    if (dp->pd_dirblk == PD_VOLDIR_BLK)
        return (t);
    blk = PD_GETW(&dp->pd_ent[PD_H_PARENTPTR]);
    ent = dp->pd_ent[PD_H_PARENTENT];
    if (bread(dp->pd_devvp, PD_BUFBLK(blk), &bp) == 0) {
        b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        for (i = ent - 1; i <= ent; i++)
            if (i >= 0 && i < PD_ENTPERBLK &&
                PD_STORAGE(&b[PD_ENTOFF(i)]) == PD_ST_SUBDIR &&
                PD_GETW(&b[PD_ENTOFF(i) + PD_E_KEYPTR]) == dp->pd_dirblk) {
                t = pd_stamp(&b[PD_ENTOFF(i) + PD_E_MODTIME]);
                break;
            }
    }
    brelse(bp);
    return (t);
}


/* pd_dirscan -- find a name in a directory: its canonical key, or ENOENT.
 *
 * `nm' HAS BEEN VALIDATED, so it is 1-15 bytes and compares against the
 * on-disk uppercase after folding.  Headers ($E, $F) and empty slots are
 * never a match, which is what lets every block be scanned from slot 0.
 *
 * A SEPARATE FRAME FROM pd_lookup ON PURPOSE: the scan's locals are gone
 * before pdget's read runs, and lookup is the deepest kernel stack there is. */
static int
pd_dirscan(dp, nm, n, keyp, idxp)
struct pdnode *dp;
char          *nm;
int            n;
unsigned      *keyp;
int           *idxp;
{
    struct buf    *bp;
    unsigned char *e;
    unsigned       blk;
    unsigned       nblk;
    int            idx;
    int            i;
    int            st;
    int            error;

    blk = dp->pd_dirblk;
    for (nblk = 0; blk != 0 && nblk < dp->pd_pmp->pm_totblks; nblk++) {
        error = bread(dp->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        for (idx = 0; idx < PD_ENTPERBLK; idx++) {
            e = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk) + PD_ENTOFF(idx)];
            st = PD_STORAGE(e);
            if (st == PD_ST_DELETED || st >= PD_ST_SUBDIRHDR ||
                PD_NAMELEN(e) != n)
                continue;
            for (i = 0; i < n; i++)
                if (e[PD_E_NAME + i] != PD_UPPER(nm[i]))
                    break;
            if (i < n)
                continue;
            /* A SUBDIRECTORY IS KEYED ON ITS OWN HEADER, pcfs's canonical
             * form: the entry here is one of several ways to reach it. */
            if (st == PD_ST_SUBDIR) {
                *keyp = PD_GETW(&e[PD_E_KEYPTR]);
                *idxp = 0;
            } else {
                *keyp = blk;
                *idxp = idx;
            }
            brelse(bp);
            return (0);
        }
        e = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        blk = PD_GETW(&e[PD_DB_NEXT]);
        brelse(bp);
    }
    return (ENOENT);
}


/* pd_lookup -- the VOP_LOOKUP slot.  ufs_lookup's contract, which is Reno's:
 * ni_dvp set first and whatever happens; ni_vp comes back referenced and
 * LOCKED; the directory is unlocked on success unless LOCKPARENT asked for it
 * on the last component; and a failure leaves it LOCKED, for lookup()'s `bad'
 * arm to release.
 *
 * A READ-ONLY MOUNT NEEDS NOTHING HERE.  lookup() refuses a create on a miss
 * and a delete or rename on a hit when the mount is MNT_RDONLY (vfs_lookup.c,
 * Reno's two gates), so every operation searches the way LOOKUP does -- which
 * is also why a miss keeps the directory locked whatever the operation.
 *
 * A DELETE THAT FINDS ITS NAME asks VWRITE of the directory, and before the
 * self-reference arm, which is ufs_lookup's order (Reno ufs/ufs_lookup.c:396,
 * "write access to directory required to delete files").  A delete of
 * `._NAME' is EPERM: the resource fork goes only with its file.
 *
 * A RENAME TARGET is both: a miss is a create's, and a hit asks VWRITE when
 * the walk wants the parent (Reno :440, `flag == RENAME && wantparent', with
 * wantparent LOCKPARENT or WANTPARENT, :101), and renaming onto the
 * directory itself is EISDIR (:447).  A rename to `._NAME' is EPERM.
 *
 * A CREATE THAT MISSES ON THE LAST COMPONENT is ufs_lookup's: a directory
 * whose entry is gone takes no name (ENOENT), writing the directory is the
 * right to name something in it (VWRITE, Reno ufs/ufs_lookup.c:321), and the
 * miss answers ENOENT with the directory UNLOCKED unless LOCKPARENT asked for
 * it -- lookup() reports the name free and nothing downstream unlocks it.
 * pd_create finds the slot itself, so nothing is recorded in ni_offset.  A
 * create of `._NAME', hit or miss, is EPERM: the resource fork is never
 * created or written.
 *
 * NO NAME CACHE.  A ProDOS directory is a few blocks already in the buffer
 * cache; cache_enter can come with P5, which has to purge it. */
int
pd_lookup(dvp, ndp)
struct vnode     *dvp;
struct nameidata *ndp;
{
    struct pdnode *dp;
    struct pdnode *pd;
    char          *nm;
    unsigned       key;
    int            idx;
    int            ad;
    int            del;
    int            op;
    int            n;
    int            i;
    int            error;

    ndp->ni_dvp = dvp;
    ndp->ni_vp  = (struct vnode *)0;
    if (dvp->v_type != VDIR)
        return (ENOTDIR);
    error = pd_access(dvp, VEXEC, (char *)0);
    if (error)
        return (error);

    dp = VTOPD(dvp);
    nm = ndp->ni_ptr;
    n  = (int)ndp->ni_namelen;

    op  = (*ndp->ni_next == '\0') ? (ndp->ni_nameiop & OPMASK) : LOOKUP;
    del = (op == DELETE ||
           (op == RENAME && (ndp->ni_nameiop & (LOCKPARENT | WANTPARENT))));

    if (n == 1 && nm[0] == '.') {
        if (del && (error = pd_access(dvp, VWRITE, (char *)0)) != 0)
            return (error);
        if (op == RENAME)
            return (EISDIR);
        vref(dvp);
        ndp->ni_vp = dvp;
        return (0);
    }

    if (n == 2 && nm[0] == '.' && nm[1] == '.') {
        error = pd_parent(dp, &key);
        if (error)
            return (error);
        idx = 0;
    } else {
        /* `._NAME' IS NAME's RESOURCE FORK: the same entry, flagged, which
         * pdget refuses unless the entry is an extended file. */
        ad = 0;
        if (n > 2 && nm[0] == '.' && nm[1] == '_') {
            if (op == CREATE || op == RENAME)
                return (EPERM);
            ad = PD_ADIDX;
            nm += 2;
            n  -= 2;
        }
        /* THE RETIRED RESOLVER'S RULE: fold, then A-Z 0-9 and `.', a letter
         * first, at most PD_NAMEMAX, and EINVAL for a name that breaks it --
         * a name no ProDOS volume can hold. */
        if (n > PD_NAMEMAX)
            return (EINVAL);
        for (i = 0; i < n; i++) {
            idx = PD_UPPER(nm[i]);
            if (!((idx >= 'A' && idx <= 'Z') ||
                  (i > 0 && ((idx >= '0' && idx <= '9') || idx == '.'))))
                return (EINVAL);
        }
        error = pd_dirscan(dp, nm, n, &key, &idx);
        if (error == ENOENT && (op == CREATE || op == RENAME)) {
            if (dp->pd_refcnt == 0)
                return (ENOENT);
            error = pd_access(dvp, VWRITE, (char *)0);
            if (error)
                return (error);
            if ((ndp->ni_nameiop & LOCKPARENT) == 0)
                pd_unlock(dvp);
            return (ENOENT);
        }
        if (error)
            return (error);
        if (del && ad)
            return (EPERM);
        idx |= ad;
    }
    if (del && (error = pd_access(dvp, VWRITE, (char *)0)) != 0)
        return (error);

    /* THE DIRECTORY ITSELF, which only "." names on a sound volume -- and
     * `..' at the volume directory, and an entry a corrupt volume points back
     * at its own header.  Locking it again would be pd_lock's panic. */
    if (idx == 0 && key == dp->pd_dirblk) {
        if (op == RENAME)
            return (EISDIR);
        vref(dvp);
        ndp->ni_vp = dvp;
        return (0);
    }

    /* UPWARD, THE PARENT GOES FIRST: holding a directory while locking its
     * parent is the directory deadlock, ufs_lookup's ".." arm. */
    if (n == 2 && nm[0] == '.') {
        pd_unlock(dvp);
        error = pdget(dp->pd_pmp, key, idx, &pd);
        if (error) {
            pd_lock(dvp);
            return (error);
        }
        ndp->ni_vp = PDTOV(pd);
        if ((ndp->ni_nameiop & LOCKPARENT) && *ndp->ni_next == '\0')
            pd_lock(dvp);
        return (0);
    }

    error = pdget(dp->pd_pmp, key, idx, &pd);
    if (error)
        return (error);
    ndp->ni_vp = PDTOV(pd);
    if ((ndp->ni_nameiop & LOCKPARENT) == 0 || *ndp->ni_next != '\0')
        pd_unlock(dvp);
    return (0);
}


/* pd_fork -- read an extended file's fork into pd_fst/pd_fkey/pd_feof: the
 * data fork for NAME, the resource fork for `._NAME'.  Every other node was
 * filled by pdget; this one waits for the first stat or read, so a lookup
 * that goes no further costs no block. */
int
pd_fork(pd)
struct pdnode *pd;
{
    struct buf    *bp;
    unsigned char *m;
    unsigned       blk;
    int            error;

    if (pd->pd_fst >= 0)
        return (0);
    blk = PD_GETW(&pd->pd_ent[PD_E_KEYPTR]);
    error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    m = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk) +
        ((pd->pd_diridx & PD_ADIDX) ? PD_X_RSRC : PD_X_DATA)];
    pd->pd_fst  = m[PD_M_STORAGE] & 0x0F;
    pd->pd_fkey = PD_GETW(&m[PD_M_KEY]);
    pd->pd_feof = (long)PD_GETW(&m[PD_M_EOF]) | ((long)m[PD_M_EOF + 2] << 16);
    brelse(bp);
    return (0);
}


/* pd_adhdr -- fill pd_adbuf with `._NAME''s first PD_ADHDRLEN bytes: the
 * AppleDouble header, big-endian as RFC 1740 requires, and 32 bytes of Finder
 * info.  pd_fork has run.
 *
 * THE FINDER INFO IS THE VOLUME's WHEN IT HAS ANY, from the extended key
 * block's entries, either of which may be missing.  Without the first, its
 * type and creator are what GS/OS's HFS FST makes of the ProDOS type: creator
 * `pdos'; type $B3 with aux $DBxx, or anything the table does not name, is `p'
 * followed by the type and the aux type high byte first; $B3 and $FF match
 * the table with their aux type taken as 0. */
static int
pd_adhdr(pd)
struct pdnode *pd;
{
    struct buf    *bp;
    unsigned char *x;
    unsigned char *d;
    unsigned       blk;
    unsigned       aux;
    int            t;
    int            i;
    int            j;
    int            have;
    int            error;

    blk = PD_GETW(&pd->pd_ent[PD_E_KEYPTR]);
    error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    x = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
    d = pd_adbuf;
    for (i = 0; i < PD_ADHDRLEN; i++)
        d[i] = 0;
    d[1]  = 0x05;               /* magic $00051607 */
    d[2]  = 0x16;
    d[3]  = 0x07;
    d[5]  = 0x02;               /* version $00020000 */
    d[25] = 2;                  /* entries */
    d[29] = 9;                  /* Finder Info, at 50 for 32 */
    d[33] = 50;
    d[37] = 32;
    d[41] = 2;                  /* Resource Fork, at 82 for its EOF */
    d[45] = PD_ADHDRLEN;
    d[47] = (unsigned char)(pd->pd_feof >> 16);
    d[48] = (unsigned char)(pd->pd_feof >> 8);
    d[49] = (unsigned char)pd->pd_feof;

    have = 0;
    for (i = PD_X_FINFO; i <= PD_X_FINFO + PD_X_FINFOLEN; i += PD_X_FINFOLEN) {
        t = x[i + 1];
        if (x[i] != PD_X_FINFOLEN || (t != 1 && t != 2))
            continue;
        for (j = 0; j < 16; j++)
            d[50 + (t - 1) * 16 + j] = x[i + 2 + j];
        if (t == 1)
            have = 1;
    }
    brelse(bp);
    if (have)
        return (0);

    t   = pd->pd_ent[PD_E_FILETYPE];
    aux = PD_GETW(&pd->pd_ent[PD_E_AUXTYPE]);
    d[54] = 'p';
    d[55] = 'd';
    d[56] = 'o';
    d[57] = 's';
    if (!(t == 0xB3 && (aux & 0xFF00) == 0xDB00)) {
        if (t == 0xB3 || t == 0xFF)
            aux = 0;
        for (i = 0; i < sizeof pd_hfstab; i += PD_HFSROW)
            if (pd_hfstab[i] == t && pd_hfstab[i + 1] == aux) {
                for (j = 0; j < 8; j++)
                    d[50 + j] = pd_hfstab[i + 2 + j];
                return (0);
            }
    }
    d[50] = 'p';
    d[51] = (unsigned char)t;
    d[52] = (unsigned char)(aux >> 8);
    d[53] = (unsigned char)aux;
    return (0);
}


/* pd_bmap -- the volume block holding a file's logical block `lbn', 0 for a
 * hole.  THE STORAGE TYPE DECIDES THE SHAPE, never the block number: a
 * seedling is its key block, a sapling's key block is one index, a tree's is a
 * master index of sub-indexes.  A block past what the shape can address is a
 * hole, as a zero index entry is.  The shape is pd_fst's and the key pd_fkey's,
 * so a fork maps as a file does. */
int
pd_bmap(pd, lbn, blkp)
struct pdnode *pd;
unsigned       lbn;
unsigned      *blkp;
{
    struct buf    *bp;
    unsigned char *b;
    unsigned       blk;
    int            st;
    int            i;
    int            error;

    blk = pd->pd_fkey;
    st  = pd->pd_fst;
    if (st == PD_ST_SEEDLING) {
        *blkp = (lbn == 0) ? blk : 0;
        return (0);
    }
    if (st == PD_ST_SAPLING && lbn > 255) {
        *blkp = 0;
        return (0);
    }
    /* A TREE READS TWICE, and the first read is the master index. */
    for (i = (st == PD_ST_TREE) ? 2 : 1; i > 0 && blk != 0; i--) {
        error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        blk = PD_IDXENT(b, (i == 2) ? (int)(lbn >> 8) : (int)(lbn & 255));
        brelse(bp);
    }
    *blkp = blk;
    return (0);
}


/* pd_read -- the VOP_READ slot.  ufs_read's loop, a ProDOS block at a time:
 * each turn maps the block under uio_offset, moves the run from `on' to the
 * block's end or the file's, and goes round.
 *
 * THE CLAMP IS TO EOF, which is three bytes on disk and exact.  `diff' is a
 * long for ufs_read's reason: a 16-bit difference would wrap past 32 KB.
 *
 * ONLY SEEDLING, SAPLING AND TREE BYTES ARE READ -- a file's own, or the fork
 * pd_fork found.  A Pascal area ($4) answers ENOTSUP, here where every read
 * arrives.  A directory answers EISDIR: its bytes are readdir's to translate.
 *
 * `._NAME' IS ITS HEADER, THEN ITS FORK: the first PD_ADHDRLEN bytes come from
 * pd_adhdr and the rest from the resource fork, `base' bytes along. */
int
pd_read(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    struct pdnode *pd;
    struct buf    *bp;
    off_t          diff;
    off_t          off;
    unsigned       blk;
    int            base;
    int            on;
    int            n;
    int            error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("pd_read mode");
    if (vp->v_type != VREG)
        return (EISDIR);
    pd = VTOPD(vp);
    error = pd_fork(pd);
    if (error)
        return (error);
    if (pd->pd_fst < PD_ST_SEEDLING || pd->pd_fst > PD_ST_TREE)
        return (ENOTSUP);
    if (uio->uio_offset < 0L)
        return (EINVAL);

    base = 0;
    if (pd->pd_diridx & PD_ADIDX) {
        base = PD_ADHDRLEN;
        if (uio->uio_offset < (off_t)base && uio->uio_resid > 0) {
            error = pd_adhdr(pd);
            if (error)
                return (error);
            on = (int)uio->uio_offset;
            n  = base - on;
            if ((unsigned short)n > uio->uio_resid)
                n = (int)uio->uio_resid;
            error = uiomove((char *)&pd_adbuf[on], n, uio);
        }
    }

    while (error == 0 && uio->uio_resid > 0) {
        off  = uio->uio_offset - (off_t)base;
        diff = pd->pd_feof - off;
        if (diff <= 0L)
            break;
        on = (int)(off & (off_t)(PD_BLKSIZE - 1));
        n  = PD_BLKSIZE - on;
        if ((unsigned short)n > uio->uio_resid)
            n = (int)uio->uio_resid;
        if (diff < (off_t)n)
            n = (int)diff;
        error = pd_bmap(pd, (unsigned)(off >> 9), &blk);
        if (error)
            break;
        if (blk == 0) {
            error = uiomove(pd_zeroblk, n, uio);
            continue;
        }
        error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            break;
        }
        error = uiomove(&bp->b_addr[PD_BUFOFF(blk) + on], n, uio);
        brelse(bp);
    }
    return (error);
}


/* pd_direct -- append one struct direct to pd_dirbuf at `off', prefixed by
 * "._" when `ad', the prefix's length, is 2; the new offset.  The buffer was
 * zeroed, so the name's NUL and the padding to DIRSIZ are already there.
 *
 * THE CASE IS `cmask''s, GS/OS Technical Note #8's word at +$1C: when bit 15 is
 * set, bits 14 down to 0 flag characters 1 to 15, set meaning lowercase
 * ("Desk.Accs" is $B9C0); when it is clear GS/OS recorded no case and the
 * whole name is lowercased. */
static int
pd_direct(off, ino, nm, n, ad, cmask)
int            off;
unsigned       ino;
unsigned char *nm;
int            n;
int            ad;
unsigned       cmask;
{
    struct direct *d;
    char          *cp;
    int            i;
    int            c;

    d  = (struct direct *)&pd_dirbuf[off];
    cp = (char *)d + DIRHDRSIZ;
    if (ad) {
        cp[0] = '.';
        cp[1] = '_';
        cp += 2;
    }
    d->d_ino    = (ino_t)ino;
    d->d_namlen = (unsigned short)(n + ad);
    d->d_reclen = (unsigned short)DIRSIZ(n + ad);
    for (i = 0; i < n; i++) {
        c = nm[i];
        if (c >= 'A' && c <= 'Z' &&
            ((cmask & 0x8000) == 0 || (cmask & (0x4000 >> i)) != 0))
            c += 'a' - 'A';
        cp[i] = c;
    }
    return (off + DIRSIZ(n + ad));
}


/* pd_rsrckey -- the resource fork's key block of the extended file whose
 * extended key block is `blk': what `._NAME' is numbered by. */
static int
pd_rsrckey(pd, blk, keyp)
struct pdnode *pd;
unsigned       blk;
unsigned      *keyp;
{
    struct buf *bp;
    int         error;

    error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
    if (error == 0)
        *keyp = PD_GETW(&bp->b_addr[PD_BUFOFF(blk) + PD_X_RSRC + PD_M_KEY]);
    brelse(bp);
    return (error);
}


/* pd_readdir -- the VOP_READDIR slot.
 *
 * ProDOS HAS NO UNIX DIRECTORY TO HAND UP, so one is built: block k of the
 * ProDOS chain is Unix directory blocks 2k and 2k+1, rendered as DIRBLKSIZ
 * bytes of struct direct each -- slots 0-6 in the first, 7-12 in the second.
 * That keeps ufs_readdir's interface exactly -- offsets are multiples of
 * DIRBLKSIZ, a request is rounded down to them and one smaller than a block
 * is EINVAL -- and half a ProDOS block always fits one: seven entries and
 * their seven `._NAME's at DIRSIZ(17) = 24 are 336 bytes, plus "." and "..".
 * A whole block would not.
 *
 * "." AND ".." LEAD BLOCK 0, where the header would be, because they are not
 * on disk; their numbers are this directory's key block and its parent's,
 * which is what stat reports for each -- getwd matches on it.  Every live
 * entry follows, numbered by its key_pointer as pd_getattr numbers it, and an
 * extended file's `._NAME' after it, numbered by its resource fork's key
 * block, which costs a read of the extended key block.  The last record's
 * d_reclen runs to the block's end, dir.h's invariant, and a block with
 * nothing live is one free record.
 *
 * eofflag IS SET WHEN THE BLOCK MOVED WAS THE CHAIN'S LAST HALF, or when the
 * offset is past it. */
int
pd_readdir(vp, uio, cred, eofflagp)
struct vnode *vp;
struct uio   *uio;
char         *cred;
int          *eofflagp;
{
    struct pdnode *pd;
    struct buf    *bp;
    unsigned char *b;
    unsigned char *e;
    unsigned       blk;
    unsigned       k;
    unsigned       u;
    unsigned       par;
    unsigned       rk;
    int            lost;
    int            off;
    int            last;
    int            idx;
    int            st;
    int            error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("pd_readdir mode");
    if (vp->v_type != VDIR)
        return (ENOTDIR);
    lost = (int)(uio->uio_resid & (DIRBLKSIZ - 1));
    if (uio->uio_resid < DIRBLKSIZ ||
        (uio->uio_offset & (off_t)(DIRBLKSIZ - 1)) != 0L)
        return (EINVAL);
    uio->uio_resid        -= (unsigned short)lost;
    uio->uio_iov->iov_len  = uio->uio_resid;

    pd = VTOPD(vp);
    *eofflagp = 0;
    error = 0;
    while (uio->uio_resid >= DIRBLKSIZ) {
        u = (unsigned)(uio->uio_offset >> 9);
        error = pd_dirwalk(pd, u >> 1, &blk, &k);
        if (error)
            break;
        if (blk == 0) {
            *eofflagp = 1;
            break;
        }
        for (off = 0; off < DIRBLKSIZ; off++)
            pd_dirbuf[off] = 0;
        off  = 0;
        last = 0;
        if (u == 0) {
            error = pd_parent(pd, &par);
            if (error)
                break;
            off  = pd_direct(off, blk, (unsigned char *)".", 1, 0, 0);
            last = off;
            off  = pd_direct(off, par, (unsigned char *)"..", 2, 0, 0);
        }
        error = bread(pd->pd_devvp, PD_BUFBLK(blk), &bp);
        if (error) {
            brelse(bp);
            break;
        }
        b = (unsigned char *)&bp->b_addr[PD_BUFOFF(blk)];
        for (idx = 0; idx < PD_BLKSIZE; idx++)
            pd_dblk[idx] = b[idx];
        brelse(bp);
        for (idx = (u & 1) ? 7 : 0; idx < ((u & 1) ? PD_ENTPERBLK : 7); idx++) {
            e  = &pd_dblk[PD_ENTOFF(idx)];
            st = PD_STORAGE(e);
            if (st == PD_ST_DELETED || st >= PD_ST_SUBDIRHDR)
                continue;
            last = off;
            off  = pd_direct(off, PD_GETW(&e[PD_E_KEYPTR]),
                             &e[PD_E_NAME], PD_NAMELEN(e), 0,
                             PD_GETW(&e[PD_E_VERSION]));
            if (st != PD_ST_EXTENDED)
                continue;
            error = pd_rsrckey(pd, PD_GETW(&e[PD_E_KEYPTR]), &rk);
            if (error)
                break;
            last = off;
            off  = pd_direct(off, rk, &e[PD_E_NAME], PD_NAMELEN(e), 2,
                             PD_GETW(&e[PD_E_VERSION]));
        }
        if (error)
            break;
        if ((u & 1) && PD_GETW(&pd_dblk[PD_DB_NEXT]) == 0)
            *eofflagp = 1;
        ((struct direct *)&pd_dirbuf[last])->d_reclen =
            (unsigned short)(DIRBLKSIZ - last);

        error = uiomove(pd_dirbuf, DIRBLKSIZ, uio);
        if (error || *eofflagp)
            break;
    }
    uio->uio_resid += (unsigned short)lost;
    return (error);
}
