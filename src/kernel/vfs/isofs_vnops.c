/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: netbsd-0-9 sys/isofs/isofs_lookup.c, sys/isofs/isofs_vnops.c,
 *   sys/isofs/isofs_util.c; 4.4BSD-Lite2 sys/isofs/cd9660/cd9660_util.c,
 *   sys/isofs/cd9660/cd9660_node.c
 *   isofs_lookup, isofs_read and isofs_readdir in FGX's VFS terms
 *   (prodos_vnops.c's shape), with Lite2's isofncmp/isofntrans names, its
 *   isodirino numbering and its cd9660_tstamp_conv7 dates.  FGX deltas are
 *   stated where they are made: records are scanned out of a logical block
 *   assembled from 1 KB buffers; the `..' record is parsed before its buffer
 *   is released; a directory renders into fixed DIRBLKSIZ blocks rather than
 *   variable-length runs; the date's zone offset is signed.
 *   Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.  This code is derived
 *   from software contributed to Berkeley by Pace Willisson
 *   (pace@blitz.com).  The Rock Ridge Extension Support code is derived from
 *   software contributed to Berkeley by Atsushi Murai (amurai@spec.co.jp).
 */
/* isofs_vnops.c -- reading an ISO 9660 volume: lookup, read, readdir.
 *
 * NAMES ARE TRANSLATED AS Lite2 TRANSLATES THEM: an ISO 9660 name is upper
 * case with a `;version' suffix, and it is handed up lower case without the
 * version or the `.' before it ("README.TXT;1" is readme.txt).  lookup matches
 * either case and an optional `;version' (isofncmp).  An associated file --
 * the flag a Macintosh hybrid sets on a resource fork -- is `=NAME', Lite2's
 * ASSOCCHAR.  Rock Ridge names, when the volume has them, are taken as they
 * are (isofs_rrip.c).
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "uio.h"
#include "dir.h"
#include "namei.h"
#include "mount.h"
#include "vfsops.h"
#include "isofs.h"

extern int      bread();
extern void     brelse();
extern int      uiomove();
extern void     vref();
extern void     kc_sleep();
extern void     kc_wakeup();
extern void     kc_panic();
extern int      iso_iget();
extern int      iso_lock();
extern int      iso_unlock();
extern int      iso_access();
extern unsigned iso_ino16();
extern long     kern_epoch();

#define ASSOCCHAR       '='

/* A DIRECTORY IS READ A LOGICAL BLOCK AT A TIME, ASSEMBLED HERE.  The buffer
 * cache holds 1 KB buffers and a record may straddle two of them, so a block
 * is copied out whole before it is scanned.  Module BSS: 2 KB is four kernel
 * stacks.  iso_bufget/iso_bufrel serialise it -- a bread to fill the second
 * half can wait on a busy buffer, and another caller must not refill it
 * meanwhile.  Nothing holding it takes a node lock: a node is made after the
 * record it came from has been parsed and the buffer released. */
static unsigned char iso_blk[ISO_SECSIZE];
static char          iso_blkbusy;
static char          iso_blkwant;
/* readdir's landing ground, filled and moved under the same lock. */
static char          iso_dirbuf[DIRBLKSIZ];

static void
iso_bufget()
{
    while (iso_blkbusy) {
        iso_blkwant = 1;
        kc_sleep(&iso_blkbusy);
    }
    iso_blkbusy = 1;
}

static void
iso_bufrel()
{
    iso_blkbusy = 0;
    if (iso_blkwant) {
        iso_blkwant = 0;
        kc_wakeup(&iso_blkbusy);
    }
}

/* iso_getblk -- logical block `lbn' into iso_blk.  The caller holds it. */
static int
iso_getblk(imp, lbn)
struct isomount *imp;
long             lbn;
{
    struct buf *bp;
    long        a;
    int         done;
    int         on;
    int         n;
    int         i;
    int         error;

    a = ISO_BYTE(imp, lbn);
    for (done = 0; done < imp->im_bsize; done += n) {
        on = (int)((a + (long)done) & (long)(FS_BLKSIZE - 1));
        n  = FS_BLKSIZE - on;
        if (n > imp->im_bsize - done)
            n = imp->im_bsize - done;
        error = bread(imp->im_devvp, (a + (long)done) >> 10, &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        for (i = 0; i < n; i++)
            iso_blk[done + i] = bp->b_addr[on + i];
        brelse(bp);
    }
    return (0);
}


/* iso_date -- a 7-byte recording date (ISO 9660 9.1.5) as seconds since the
 * epoch, 0 for none.  Lite2's cd9660_tstamp_conv7: before 1970 is no date,
 * and the zone offset, in 15-minute steps from GMT, is applied only inside
 * -48..52 ("timezone offset is unreliable on some disks").  FGX DELTA: the
 * offset is SIGNED (ISO 9660's 712 number); Lite2 reads it through u_char,
 * so a zone west of Greenwich was never applied. */
long
iso_date(p)
unsigned char *p;
{
    long t;
    int  tz;

    if (p[0] < 70 || p[1] < 1 || p[1] > 12 || p[2] < 1)
        return (0L);
    t  = kern_epoch(1900 + (int)p[0], (int)p[1], (int)p[2],
                    (int)p[3], (int)p[4], (int)p[5]);
    tz = (p[6] & 0x80) ? (int)p[6] - 256 : (int)p[6];
    if (tz >= -48 && tz <= 52)
        t -= (long)tz * 15L * 60L;
    return (t);
}


/* iso_dirino -- Lite2's isodirino: a directory record's node number when it
 * names a directory, the byte address of its data. */
long
iso_dirino(imp, rp)
struct isomount *imp;
unsigned char   *rp;
{
    return (ISO_BYTE(imp, isonum_733(&rp[ISO_DR_EXTENT]) +
                          (long)isonum_711(&rp[ISO_DR_EXTATTR])));
}


/* iso_parse -- the attributes of the record at `rp'.  Without Rock Ridge
 * every node is root's, mode 0555, as Lite2's cd9660_defattr has it: an ISO
 * 9660 volume records no owner or permission, and a program on it must be
 * runnable. */
void
iso_parse(imp, rp, ia)
struct isomount *imp;
unsigned char   *rp;
struct isoattr  *ia;
{
    ia->ia_extent = isonum_733(&rp[ISO_DR_EXTENT]) +
                    (long)isonum_711(&rp[ISO_DR_EXTATTR]);
    ia->ia_size   = isonum_733(&rp[ISO_DR_SIZE_]);
    ia->ia_flags  = rp[ISO_DR_FLAGS];
    ia->ia_interleaved = (rp[ISO_DR_UNIT] != 0 || rp[ISO_DR_GAP] != 0);
    ia->ia_mtime  = iso_date(&rp[ISO_DR_DATE]);
    ia->ia_mode   = 0555;
    ia->ia_uid    = 0;
    ia->ia_gid    = 0;
    ia->ia_nlink  = (ia->ia_flags & ISO_FL_DIR) ? 2 : 1;
}


/* isofncmp -- Lite2's (cd9660_util.c), returning 0 when the user's name
 * `fn' names the ISO 9660 name `isofn': either case, and a `;version' given
 * or not -- and given, it must be the record's.  A name with no `;' matches
 * one recorded as "NAME." or "NAME.;1", which is how a name with no
 * extension is written. */
static int
isofncmp(fn, fnlen, isofn, isolen)
unsigned char *fn;
int            fnlen;
unsigned char *isofn;
int            isolen;
{
    int  i;
    int  j;
    int  c;

    while (--fnlen >= 0) {
        if (--isolen < 0)
            return (*fn);
        if ((c = *isofn++) == ';') {
            switch (*fn++) {
            default:
                return (*--fn);
            case 0:
                return (0);
            case ';':
                break;
            }
            for (i = 0; --fnlen >= 0; i = i * 10 + *fn++ - '0')
                if (*fn < '0' || *fn > '9')
                    return (-1);
            for (j = 0; --isolen >= 0; j = j * 10 + *isofn++ - '0')
                ;
            return (i - j);
        }
        if (c != *fn) {
            if (c >= 'A' && c <= 'Z') {
                if (c + ('a' - 'A') != *fn) {
                    if (*fn >= 'a' && *fn <= 'z')
                        return (*fn - ('a' - 'A') - c);
                    return (*fn - c);
                }
            } else
                return (*fn - c);
        }
        fn++;
    }
    if (isolen > 0) {
        switch (*isofn) {
        default:
            return (-1);
        case '.':
            if (isofn[1] != ';')
                return (-1);
            /* FALLTHROUGH */
        case ';':
            return (0);
        }
    }
    return (0);
}


/* isofntrans -- Lite2's: the name readdir hands up for an ISO 9660 name,
 * lower case and without `;version' or the `.' before it, `=' first for an
 * associated file.  `out' holds MAXNAMLEN + 1; the result is its length. */
static int
isofntrans(in, inlen, out, assoc)
unsigned char *in;
int            inlen;
char          *out;
int            assoc;
{
    int n;
    int c;

    n = 0;
    if (assoc)
        out[n++] = ASSOCCHAR;
    for (; inlen > 0 && n < MAXNAMLEN; inlen--) {
        c = *in++;
        if (c >= 'A' && c <= 'Z')
            c += 'a' - 'A';
        else if (c == '.' && inlen > 1 && *in == ';')
            break;
        else if (c == ';')
            break;
        out[n++] = c;
    }
    return (n);
}


/* iso_dirsize -- a directory's length as readdir renders it: every
 * ISO_RDWIN bytes on the volume are one DIRBLKSIZ block (iso_readdir). */
#define ISO_RDWIN       128
long
iso_dirsize(ip)
struct isonode *ip;
{
    return ((ip->i_attr.ia_size + (long)(ISO_RDWIN - 1)) / (long)ISO_RDWIN *
            (long)DIRBLKSIZ);
}


/* iso_dirscan -- find `nm' in directory `dp': its node number and its
 * attributes, or ENOENT.  isofs_lookup's search loop, in its own frame so its
 * locals are gone before iso_iget runs (lookup is the deepest kernel stack
 * there is).
 *
 * A RECORD THAT RUNS PAST ITS BLOCK, or is shorter than its fixed part and
 * its name, ends the search, upstream's "illegal entry, stop" -- as an error
 * here rather than a miss, because the directory is not what it claims. */
static int
iso_dirscan(dp, nm, n, inop, ia)
struct isonode *dp;
char           *nm;
int             n;
long           *inop;
struct isoattr *ia;
{
    struct isomount *imp;
    unsigned char   *rp;
    long             lbn;
    long             nblk;
    int              off;
    int              len;
    int              nl;
    int              assoc;
    int              error;

    imp   = dp->i_mnt;
    assoc = (n > 1 && nm[0] == ASSOCCHAR);
    if (assoc) {
        nm++;
        n--;
    }
    nblk  = (dp->i_attr.ia_size + (long)(imp->im_bsize - 1)) >>
            imp->im_bshift;
    error = ENOENT;
    iso_bufget();
    for (lbn = 0; lbn < nblk && error == ENOENT; lbn++) {
        error = iso_getblk(imp, dp->i_attr.ia_extent + lbn);
        if (error)
            break;
        error = ENOENT;
        for (off = 0; off < imp->im_bsize; off += len) {
            rp  = &iso_blk[off];
            len = isonum_711(&rp[ISO_DR_LEN]);
            if (len == 0)
                break;          /* the rest of the block is unused */
            nl = isonum_711(&rp[ISO_DR_NAMELEN]);
            if (len < ISO_DR_SIZE + nl || off + len > imp->im_bsize) {
                error = EIO;
                break;
            }
            /* "." and ".." are records 0 and 1, the bytes 0 and 1. */
            if (nl == 1 && (rp[ISO_DR_NAME] == 0 || rp[ISO_DR_NAME] == 1))
                continue;
            if (((rp[ISO_DR_FLAGS] & ISO_FL_ASSOC) != 0) != assoc)
                continue;
            if (isofncmp((unsigned char *)nm, n, &rp[ISO_DR_NAME], nl) != 0)
                continue;
            iso_parse(imp, rp, ia);
            if (ia->ia_flags & ISO_FL_DIR)
                *inop = iso_dirino(imp, rp);
            else
                *inop = ISO_BYTE(imp, dp->i_attr.ia_extent + lbn) + (long)off;
            error = 0;
            break;
        }
    }
    iso_bufrel();
    return (error);
}


/* iso_dotdot -- a directory's parent: the second record of its first block,
 * whose extent and size are the parent's (ISO 9660 6.8.2.2).  The root's
 * names the root. */
static int
iso_dotdot(dp, inop, ia)
struct isonode *dp;
long           *inop;
struct isoattr *ia;
{
    struct isomount *imp;
    unsigned char   *rp;
    int              len;
    int              error;

    imp = dp->i_mnt;
    iso_bufget();
    error = iso_getblk(imp, dp->i_attr.ia_extent);
    if (error == 0) {
        len = isonum_711(&iso_blk[ISO_DR_LEN]);
        rp  = &iso_blk[len];
        if (len < ISO_DR_SIZE + 1 || len + ISO_DR_SIZE + 1 > imp->im_bsize ||
            isonum_711(&rp[ISO_DR_NAMELEN]) != 1 || rp[ISO_DR_NAME] != 1) {
            error = EIO;
        } else {
            iso_parse(imp, rp, ia);
            ia->ia_flags |= ISO_FL_DIR;
            *inop = iso_dirino(imp, rp);
        }
    }
    iso_bufrel();
    return (error);
}


/* iso_lookup -- the VOP_LOOKUP slot.  ufs_lookup's contract, which is Reno's
 * and pd_lookup's: ni_dvp set first and whatever happens; ni_vp comes back
 * referenced and LOCKED; the directory is unlocked on success unless
 * LOCKPARENT asked for it on the last component; and a failure leaves it
 * LOCKED, for lookup()'s `bad' arm to release.
 *
 * A READ-ONLY MOUNT NEEDS NOTHING MORE.  lookup() refuses a create on a miss
 * and a delete or rename on a hit when the mount is MNT_RDONLY (vfs_lookup.c,
 * Reno's two gates), and an ISO 9660 mount is always that.
 *
 * NO NAME CACHE, as netbsd-0-9 has one and pd_lookup has none: a hit leaves
 * the directory's blocks in the buffer cache, which is most of the saving. */
int
iso_lookup(dvp, ndp)
struct vnode     *dvp;
struct nameidata *ndp;
{
    struct isonode *dp;
    struct isonode *ip;
    struct isoattr  ia;
    char           *nm;
    long            ino;
    int             n;
    int             error;

    ndp->ni_dvp = dvp;
    ndp->ni_vp  = (struct vnode *)0;
    if (dvp->v_type != VDIR)
        return (ENOTDIR);
    error = iso_access(dvp, VEXEC, (char *)0);
    if (error)
        return (error);

    dp = VTOI(dvp);
    nm = ndp->ni_ptr;
    n  = (int)ndp->ni_namelen;

    if (n == 1 && nm[0] == '.') {
        vref(dvp);
        ndp->ni_vp = dvp;
        return (0);
    }
    if (n == 2 && nm[0] == '.' && nm[1] == '.')
        error = iso_dotdot(dp, &ino, &ia);
    else
        error = iso_dirscan(dp, nm, n, &ino, &ia);
    if (error)
        return (error);

    /* THE DIRECTORY ITSELF -- `..' at the root, or a corrupt volume's entry
     * naming its own directory.  Locking it again would be iso_lock's panic. */
    if (ino == dp->i_number) {
        vref(dvp);
        ndp->ni_vp = dvp;
        return (0);
    }

    /* UPWARD, THE PARENT GOES FIRST: holding a directory while locking its
     * parent is the directory deadlock, ufs_lookup's ".." arm. */
    if (n == 2 && nm[0] == '.' && nm[1] == '.') {
        iso_unlock(dvp);
        error = iso_iget(dp->i_mnt, ino, &ia, &ip);
        if (error) {
            iso_lock(dvp);
            return (error);
        }
        ndp->ni_vp = ITOV(ip);
        if ((ndp->ni_nameiop & LOCKPARENT) && *ndp->ni_next == '\0')
            iso_lock(dvp);
        return (0);
    }

    error = iso_iget(dp->i_mnt, ino, &ia, &ip);
    if (error)
        return (error);
    ndp->ni_vp = ITOV(ip);
    if ((ndp->ni_nameiop & LOCKPARENT) == 0 || *ndp->ni_next != '\0')
        iso_unlock(dvp);
    return (0);
}


/* iso_read -- the VOP_READ slot.  isofs_read's loop: each turn reads the
 * buffer under uio_offset and moves the run to the buffer's end or the
 * file's.  A file is one extent, so its byte `off' is the volume's byte
 * extent + off.
 *
 * `diff' IS A long for ufs_read's reason: a 16-bit difference would wrap past
 * 32 KB.
 *
 * AN INTERLEAVED FILE IS REFUSED with EIO rather than read as if it were not:
 * its data alternates with gaps (ISO 9660 6.4.4), and netbsd-0-9 read the
 * gaps as data.  No disc mastered since the early 1990s interleaves. */
int
iso_read(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    struct isonode *ip;
    struct buf     *bp;
    long            a;
    off_t           diff;
    int             on;
    int             n;
    int             error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("iso_read mode");
    if (vp->v_type == VDIR)
        return (EISDIR);
    ip = VTOI(vp);
    if (ip->i_attr.ia_interleaved)
        return (EIO);
    if (uio->uio_offset < 0L)
        return (EINVAL);

    error = 0;
    while (error == 0 && uio->uio_resid > 0) {
        diff = ip->i_attr.ia_size - uio->uio_offset;
        if (diff <= 0L)
            break;
        a  = ISO_BYTE(ip->i_mnt, ip->i_attr.ia_extent) + uio->uio_offset;
        on = (int)(a & (long)(FS_BLKSIZE - 1));
        n  = FS_BLKSIZE - on;
        if ((unsigned short)n > uio->uio_resid)
            n = (int)uio->uio_resid;
        if (diff < (off_t)n)
            n = (int)diff;
        error = bread(ip->i_devvp, a >> 10, &bp);
        if (error) {
            brelse(bp);
            break;
        }
        error = uiomove(&bp->b_addr[on], n, uio);
        brelse(bp);
    }
    return (error);
}


/* iso_direct -- append one struct direct to iso_dirbuf at `off'; the new
 * offset.  The buffer was zeroed, so the name's NUL and the padding to
 * DIRSIZ are already there. */
static int
iso_direct(off, ino, nm, n)
int       off;
unsigned  ino;
char     *nm;
int       n;
{
    struct direct *d;
    char          *cp;
    int            i;

    d  = (struct direct *)&iso_dirbuf[off];
    cp = (char *)d + DIRHDRSIZ;
    d->d_ino    = (ino_t)ino;
    d->d_namlen = (unsigned short)n;
    d->d_reclen = (unsigned short)DIRSIZ(n);
    for (i = 0; i < n; i++)
        cp[i] = nm[i];
    return (off + DIRSIZ(n));
}


/* iso_readdir -- the VOP_READDIR slot.
 *
 * ufs_readdir's interface, which FGX's getdirentries relies on: offsets are
 * multiples of DIRBLKSIZ, a request is rounded down to them and one smaller
 * than a block is EINVAL.  netbsd-0-9 moved variable-length entries and left
 * uio_offset at the next ISO record, which that interface cannot hold.
 *
 * SO EVERY ISO_RDWIN BYTES OF THE DIRECTORY ARE ONE BLOCK: block u renders
 * the records that START in bytes u*ISO_RDWIN .. +ISO_RDWIN-1, found by
 * scanning their logical block from its start (records are sequential, and a
 * record never crosses a block).  The window is small enough that what starts
 * in it always fits: a record is at least 34 bytes, so at most four start in
 * 128, and four entries at DIRSIZ(MAXNAMLEN) plus "." and ".." are under
 * DIRBLKSIZ.  Most rendered blocks are mostly free record; that is the
 * price of offsets that mean something.
 *
 * "." AND ".." ARE THE DIRECTORY'S FIRST TWO RECORDS, names 0 and 1, numbered
 * as lookup numbers them -- getwd matches on it.  The last record's d_reclen
 * runs to the block's end, dir.h's invariant, and a window with nothing in it
 * is one free record. */
int
iso_readdir(vp, uio, cred, eofflagp)
struct vnode *vp;
struct uio   *uio;
char         *cred;
int          *eofflagp;
{
    struct isonode  *ip;
    struct isomount *imp;
    unsigned char   *rp;
    char             nm[MAXNAMLEN + 1];
    long             lo;
    long             ino;
    int              boff;
    int              off;
    int              len;
    int              nl;
    int              dout;
    int              last;
    int              lost;
    int              n;
    int              error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("iso_readdir mode");
    if (vp->v_type != VDIR)
        return (ENOTDIR);
    lost = (int)(uio->uio_resid & (DIRBLKSIZ - 1));
    if (uio->uio_resid < DIRBLKSIZ ||
        (uio->uio_offset & (off_t)(DIRBLKSIZ - 1)) != 0L)
        return (EINVAL);
    uio->uio_resid        -= (unsigned short)lost;
    uio->uio_iov->iov_len  = uio->uio_resid;

    ip  = VTOI(vp);
    imp = ip->i_mnt;
    *eofflagp = 0;
    error = 0;
    iso_bufget();
    while (uio->uio_resid >= DIRBLKSIZ) {
        lo = (uio->uio_offset / (off_t)DIRBLKSIZ) * (long)ISO_RDWIN;
        if (lo >= ip->i_attr.ia_size) {
            *eofflagp = 1;
            break;
        }
        error = iso_getblk(imp, ip->i_attr.ia_extent + (lo >> imp->im_bshift));
        if (error)
            break;
        boff = (int)(lo & (long)(imp->im_bsize - 1));
        for (off = 0; off < DIRBLKSIZ; off++)
            iso_dirbuf[off] = 0;
        dout = 0;
        last = 0;
        for (off = 0; off < boff + ISO_RDWIN && off < imp->im_bsize;
             off += len) {
            rp  = &iso_blk[off];
            len = isonum_711(&rp[ISO_DR_LEN]);
            if (len == 0)
                break;
            nl = isonum_711(&rp[ISO_DR_NAMELEN]);
            if (len < ISO_DR_SIZE + nl || off + len > imp->im_bsize) {
                error = EIO;
                break;
            }
            if (off < boff)
                continue;
            if (nl == 1 && rp[ISO_DR_NAME] == 0) {
                ino   = ip->i_number;
                nm[0] = '.';
                n     = 1;
            } else if (nl == 1 && rp[ISO_DR_NAME] == 1) {
                ino   = iso_dirino(imp, rp);
                nm[0] = '.';
                nm[1] = '.';
                n     = 2;
            } else {
                if (rp[ISO_DR_FLAGS] & ISO_FL_DIR)
                    ino = iso_dirino(imp, rp);
                else
                    ino = ISO_BYTE(imp, ip->i_attr.ia_extent) + lo -
                          (long)boff + (long)off;
                n = isofntrans(&rp[ISO_DR_NAME], nl, nm,
                               (rp[ISO_DR_FLAGS] & ISO_FL_ASSOC) != 0);
            }
            last = dout;
            dout = iso_direct(dout, iso_ino16(ino), nm, n);
        }
        if (error)
            break;
        ((struct direct *)&iso_dirbuf[last])->d_reclen =
            (unsigned short)(DIRBLKSIZ - last);
        error = uiomove(iso_dirbuf, DIRBLKSIZ, uio);
        if (error)
            break;
        if (lo + (long)ISO_RDWIN >= ip->i_attr.ia_size) {
            *eofflagp = 1;
            break;
        }
    }
    iso_bufrel();
    uio->uio_resid += (unsigned short)lost;
    return (error);
}


/* iso_readlink -- a Rock Ridge symbolic link's target.  Without Rock Ridge
 * nothing is a link, and VOP_READLINK is only asked of one. */
int
iso_readlink(vp, uio, cred)
struct vnode *vp;
struct uio   *uio;
char         *cred;
{
    return (EINVAL);
}
