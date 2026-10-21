/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.4BSD-Lite2 sys/isofs/cd9660/cd9660_rrip.c
 *   The Rock Ridge Interchange Protocol: cd9660_rrip_loop and its handlers
 *   for PX, TF, NM, SL, CL, PL, RE, CE and ST, and cd9660_rrip_offset's SP/ER
 *   check, in one walker over a record's System Use fields.  FGX deltas:
 *   the handlers are a switch rather than a table of function pointers, and
 *   the analysis is three entry points sharing it (attributes, name, link);
 *   a continuation area is read into a second assembled block, under the lock
 *   the first is held by; ER accepts RRIP 1.12's IEEE_P1282 and IEEE_1282 as
 *   well as RRIP 1.09's RRIP_1991A, which is all Lite2 knew; a name or link
 *   too long for FGX falls back to the ISO 9660 name, Lite2's own fallback
 *   for one too long for its buffer; and a PN device is not carried, FGX
 *   having no special files on a mounted volume.
 *   Original work:
 *   Copyright (c) 1993, 1994 The Regents of the University of California.
 *   All rights reserved.  This code is derived from software contributed to
 *   Berkeley by Pace Willisson (pace@blitz.com).  The Rock Ridge Extension
 *   Support code is derived from software contributed to Berkeley by Atsushi
 *   Murai (amurai@spec.co.jp).
 */
/* isofs_rrip.c -- Rock Ridge: POSIX names, modes, owners, times and
 * symbolic links on an ISO 9660 volume, from the System Use fields after
 * each directory record's name (IEEE P1281 SUSP, P1282 RRIP).
 *
 * A FIELD IS TWO SIGNATURE BYTES, A LENGTH AND A VERSION, then its data.  The
 * fields run from after the name -- padded to an even offset, and past the
 * SP field's skip count -- to the record's end, and a CE field continues them
 * in a block of their own.  Every field used here is version 1; any other is
 * stepped over, as Lite2 steps over it.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "mount.h"
#include "isofs.h"

extern int  bread();
extern void brelse();
extern long kern_epoch();
extern long iso_date();
int         iso_bcmp();

/* The continuation area's block, assembled as iso_getblk assembles one.  The
 * caller holds iso_blk's lock, which covers this too. */
static unsigned char iso_ceblk[ISO_SECSIZE];

/* What a walk is after, and what it found. */
#define RR_ATTR         0x01    /* PX */
#define RR_TIME         0x02    /* TF */
#define RR_NAME         0x04    /* NM */
#define RR_LINK         0x08    /* SL */
#define RR_CLINK        0x10    /* CL */
#define RR_PLINK        0x20    /* PL */
#define RR_RELDIR       0x40    /* RE */
#define RR_ER           0x80    /* ER naming Rock Ridge */

struct rrwalk {
    int             w_want;     /* RR_* still wanted */
    int             w_got;      /* RR_* found */
    struct isoattr *w_ia;       /* RR_ATTR, RR_TIME */
    char           *w_out;      /* RR_NAME, RR_LINK */
    int             w_max;
    int             w_len;
    int             w_cont;     /* the last NM or SL component continues */
    int             w_bad;      /* it overflowed: use the ISO name */
    long            w_loc;      /* RR_CLINK, RR_PLINK: the extent */
    long            w_celoc;    /* a CE field: the continuation's block, */
    long            w_ceoff;    /*   offset in it */
    long            w_celen;    /*   and length; 0 for none */
};


/* rr_append -- `n' bytes at `p' onto the walk's output, or mark it bad. */
static void
rr_append(w, p, n)
struct rrwalk *w;
char          *p;
int            n;
{
    int i;

    if (w->w_bad || w->w_len + n > w->w_max) {
        w->w_bad = 1;
        return;
    }
    for (i = 0; i < n; i++)
        w->w_out[w->w_len + i] = p[i];
    w->w_len += n;
}


/* rr_tf -- a TF field's modification time: Lite2's cd9660_rrip_tstamp,
 * which skips the creation stamp when one is recorded.  The 17-byte form is
 * decimal digits and a zone byte (cd9660_tstamp_conv17). */
static long
rr_tf(f, n)
unsigned char *f;
int            n;
{
    unsigned char d[7];
    unsigned char *t;
    int            sz;
    int            i;
    int            v;

    t  = &f[5];
    sz = (f[4] & 0x80) ? 17 : 7;
    if (f[4] & 0x01)
        t += sz;                /* the creation stamp */
    if ((f[4] & 0x02) == 0 || (t - f) + sz > n)
        return (-1L);           /* no modification stamp */
    if (sz == 7)
        return (iso_date(t));
    for (i = 0, v = 0; i < 4; i++)
        v = v * 10 + (t[i] - '0');
    d[0] = (unsigned char)(v - 1900);
    for (i = 0; i < 5; i++)
        d[1 + i] = (unsigned char)((t[4 + 2 * i] - '0') * 10 +
                                   (t[5 + 2 * i] - '0'));
    d[6] = t[16];
    return (iso_date(d));
}


/* rr_field -- one System Use field.  0 to go on, 1 to stop. */
static int
rr_field(imp, w, f, n)
struct isomount *imp;
struct rrwalk   *w;
unsigned char   *f;
int              n;
{
    unsigned char *c;
    unsigned char *ce;
    int            fl;
    int            m;

    if (f[3] != 1)
        return (0);
    if (f[0] == 'S' && f[1] == 'T')
        return (1);
    if (f[0] == 'C' && f[1] == 'E' && n >= 28) {
        w->w_celoc = isonum_733(&f[4]);
        w->w_ceoff = isonum_733(&f[12]);
        w->w_celen = isonum_733(&f[20]);
        return (0);
    }
    if ((w->w_want & RR_ATTR) && f[0] == 'P' && f[1] == 'X' && n >= 36) {
        w->w_ia->ia_mode  = (unsigned short)isonum_733(&f[4]);
        w->w_ia->ia_nlink = (short)isonum_733(&f[12]);
        w->w_ia->ia_uid   = (uid_t)isonum_733(&f[20]);
        w->w_ia->ia_gid   = (gid_t)isonum_733(&f[28]);
        w->w_got  |= RR_ATTR;
        w->w_want &= ~RR_ATTR;
    } else if ((w->w_want & RR_TIME) && f[0] == 'T' && f[1] == 'F' &&
               n >= 5) {
        w->w_ia->ia_mtime = rr_tf(f, n);
        if (w->w_ia->ia_mtime < 0L)
            w->w_ia->ia_mtime = 0L;
        w->w_got  |= RR_TIME;
        w->w_want &= ~RR_TIME;
    } else if ((w->w_want & RR_NAME) && f[0] == 'N' && f[1] == 'M' &&
               n >= 5) {
        /* cd9660_rrip_altname.  `.' and `..' (flags 2, 4) are never a
         * file's name, and the host-name flag names no file here either. */
        fl = f[4];
        if (fl & 0x06)
            w->w_bad = 1;
        else if ((fl & 0x20) == 0)
            rr_append(w, (char *)&f[5], n - 5);
        else
            w->w_bad = 1;
        w->w_got |= RR_NAME;
        if ((fl & 0x01) == 0)
            w->w_want &= ~RR_NAME;
    } else if ((w->w_want & RR_LINK) && f[0] == 'S' && f[1] == 'L' &&
               n >= 5) {
        /* cd9660_rrip_slink: components, each a flag byte, a length and
         * the bytes; a `/' between components unless the last continued. */
        for (c = &f[5], ce = f + n; c + 2 <= ce; c += 2 + c[1]) {
            if (!w->w_cont && w->w_len > 0)
                rr_append(w, "/", 1);
            w->w_cont = 0;
            m = c[0];
            if (m & 0x02)
                rr_append(w, ".", 1);
            else if (m & 0x04)
                rr_append(w, "..", 2);
            else if (m & 0x08) {
                w->w_len = 0;
                rr_append(w, "/", 1);
                w->w_cont = 1;  /* the root's `/' is its own separator */
            } else if (m & 0x10) {
                w->w_len = 0;   /* the mount point: link from the volume */
                m = 0;
                while (imp->im_mountp->mnt_stat.f_mntonname[m])
                    m++;
                rr_append(w, imp->im_mountp->mnt_stat.f_mntonname, m);
            } else if (m & 0x20) {
                w->w_bad = 1;   /* a host name names nothing here */
            } else {
                rr_append(w, (char *)&c[2], c[1]);
                if (m & 0x01)
                    w->w_cont = 1;
            }
        }
        w->w_got |= RR_LINK;
        if ((f[4] & 0x01) == 0)
            w->w_want &= ~RR_LINK;
    } else if ((w->w_want & (RR_CLINK | RR_PLINK)) && f[1] == 'L' &&
               (f[0] == 'C' || f[0] == 'P') && n >= 12) {
        w->w_loc  = isonum_733(&f[4]);
        w->w_got |= (f[0] == 'C') ? RR_CLINK : RR_PLINK;
    } else if ((w->w_want & RR_RELDIR) && f[0] == 'R' && f[1] == 'E') {
        w->w_got |= RR_RELDIR;
    } else if ((w->w_want & RR_ER) && f[0] == 'E' && f[1] == 'R' && n >= 8) {
        /* cd9660_rrip_extref, and RRIP 1.12's two identifiers. */
        m = f[4];
        if (8 + m <= n &&
            ((m == 10 && iso_bcmp(&f[8], "RRIP_1991A", 10) == 0) ||
             (m == 10 && iso_bcmp(&f[8], "IEEE_P1282", 10) == 0) ||
             (m == 9 && iso_bcmp(&f[8], "IEEE_1282", 9) == 0)))
            w->w_got |= RR_ER;
    }
    return (0);
}


int
iso_bcmp(a, b, n)
unsigned char *a;
char          *b;
int            n;
{
    while (n-- > 0)
        if (*a++ != (unsigned char)*b++)
            return (1);
    return (0);
}


/* rr_walk -- every System Use field of the record at `rp', then of each
 * continuation area: cd9660_rrip_loop.  `skip' is the SP field's skip count.
 *
 * A CONTINUATION AREA IS READ INTO iso_ceblk, whole, and must lie inside one
 * logical block and the volume -- Lite2's checks; a field that runs past its
 * area ends the walk, as one that claims less than its own header does. */
static void
rr_walk(imp, rp, skip, w)
struct isomount *imp;
unsigned char   *rp;
int              skip;
struct rrwalk   *w;
{
    struct buf    *bp;
    unsigned char *p;
    unsigned char *end;
    long           a;
    int            nl;
    int            n;
    int            hops;
    int            on;
    int            k;
    int            done;

    nl  = isonum_711(&rp[ISO_DR_NAMELEN]);
    p   = &rp[ISO_DR_NAME + nl + ((nl & 1) ? 0 : 1) + skip];
    end = &rp[isonum_711(&rp[ISO_DR_LEN])];
    for (hops = 0; hops < 8; hops++) {
        w->w_celen = 0L;
        while (p + 4 <= end) {
            n = p[2];
            if (n < 4 || p + n > end)
                break;
            if (rr_field(imp, w, p, n))
                break;
            if (w->w_want == 0)
                return;
            p += n;
        }
        if (w->w_celen == 0L || w->w_celoc >= imp->im_volsize ||
            w->w_ceoff + w->w_celen > (long)imp->im_bsize)
            return;
        /* The continuation area's block, by 1 KB buffers. */
        a = ISO_BYTE(imp, w->w_celoc);
        for (done = 0; done < imp->im_bsize; done += k) {
            on = (int)((a + (long)done) & (long)(FS_BLKSIZE - 1));
            k  = FS_BLKSIZE - on;
            if (k > imp->im_bsize - done)
                k = imp->im_bsize - done;
            if (bread(imp->im_devvp, (a + (long)done) >> 10, &bp)) {
                brelse(bp);
                return;
            }
            for (n = 0; n < k; n++)
                iso_ceblk[done + n] = bp->b_addr[on + n];
            brelse(bp);
        }
        p   = &iso_ceblk[(int)w->w_ceoff];
        end = p + (int)w->w_celen;
    }
}


/* rr_skipfor -- the SP skip that applies to `rp': rr_skip0 for the root's
 * own "." record, where SP itself is, and rr_skip for every other. */
static int
rr_skipfor(imp, rp)
struct isomount *imp;
unsigned char   *rp;
{
    if (isonum_711(&rp[ISO_DR_NAMELEN]) == 1 && rp[ISO_DR_NAME] == 0 &&
        isonum_733(&rp[ISO_DR_EXTENT]) == imp->im_rootext)
        return (imp->im_rrskip0);
    return (imp->im_rrskip);
}


/* iso_rroffset -- whether the volume is Rock Ridge: cd9660_rrip_offset.  The
 * root directory's "." record must open its System Use area with SP (check
 * bytes $BE $EF), or do so 15 bytes in, where a CD-ROM XA record's own
 * system-use data comes first; and somewhere in that area an ER field must
 * name Rock Ridge -- Lite2 insists on it, and so does this.  Sets im_rr. */
void
iso_rroffset(imp, rootdot)
struct isomount *imp;
unsigned char   *rootdot;
{
    struct rrwalk  w;
    unsigned char *p;

    imp->im_rr      = 0;
    imp->im_rrskip0 = 0;
    p = &rootdot[ISO_DR_NAME + 1];
    if (!(p[0] == 'S' && p[1] == 'P' && p[2] == 7 && p[3] == 1 &&
          p[4] == 0xBE && p[5] == 0xEF)) {
        imp->im_rrskip0 = 15;
        p += 15;
        if (!(p[0] == 'S' && p[1] == 'P' && p[2] == 7 && p[3] == 1 &&
              p[4] == 0xBE && p[5] == 0xEF))
            return;
    }
    w.w_want = RR_ER;
    w.w_got  = 0;
    rr_walk(imp, rootdot, imp->im_rrskip0, &w);
    if (w.w_got & RR_ER) {
        imp->im_rr     = 1;
        imp->im_rrskip = p[6];
    }
}


/* iso_rrattr -- PX and TF over the defaults iso_parse set; cd9660_rrip_
 * analyze.  A file with no PX keeps them -- Lite2 complains, "this is a
 * required field!", and does the same. */
void
iso_rrattr(imp, rp, ia)
struct isomount *imp;
unsigned char   *rp;
struct isoattr  *ia;
{
    struct rrwalk w;

    w.w_want = RR_ATTR | RR_TIME;
    w.w_got  = 0;
    w.w_ia   = ia;
    rr_walk(imp, rp, rr_skipfor(imp, rp), &w);
}


/* iso_rrname -- the record's Rock Ridge name into `out' (MAXNAMLEN bytes,
 * not terminated): its length, 0 when it has none or it does not fit, or -1
 * for a directory Rock Ridge relocated, whose entry here is not its name.
 * *clp is a CL field's extent -- the directory a placeholder entry stands for
 * -- or -1.  cd9660_rrip_getname. */
int
iso_rrname(imp, rp, out, clp)
struct isomount *imp;
unsigned char   *rp;
char            *out;
long            *clp;
{
    struct rrwalk w;

    w.w_want = RR_NAME | RR_CLINK | RR_RELDIR;
    w.w_got  = 0;
    w.w_out  = out;
    w.w_max  = MAXNAMLEN;
    w.w_len  = 0;
    w.w_bad  = 0;
    w.w_loc  = -1L;
    rr_walk(imp, rp, rr_skipfor(imp, rp), &w);
    *clp = (w.w_got & RR_CLINK) ? w.w_loc : -1L;
    if (w.w_got & RR_RELDIR)
        return (-1);
    if (w.w_bad || (w.w_got & RR_NAME) == 0)
        return (0);
    return (w.w_len);
}


/* iso_rrparent -- a ".." record's PL field: the extent of the parent a
 * relocated directory really has, or -1. */
long
iso_rrparent(imp, rp)
struct isomount *imp;
unsigned char   *rp;
{
    struct rrwalk w;

    w.w_want = RR_PLINK;
    w.w_got  = 0;
    w.w_loc  = -1L;
    rr_walk(imp, rp, rr_skipfor(imp, rp), &w);
    return ((w.w_got & RR_PLINK) ? w.w_loc : -1L);
}


/* iso_rrlink -- a symbolic link's target into `out', `max' bytes: its
 * length, or 0.  cd9660_rrip_getsymname. */
int
iso_rrlink(imp, rp, out, max)
struct isomount *imp;
unsigned char   *rp;
char            *out;
int              max;
{
    struct rrwalk w;

    w.w_want = RR_LINK;
    w.w_got  = 0;
    w.w_out  = out;
    w.w_max  = max;
    w.w_len  = 0;
    w.w_cont = 1;               /* Lite2: "don't start with a slash" */
    w.w_bad  = 0;
    rr_walk(imp, rp, rr_skipfor(imp, rp), &w);
    if (w.w_bad || (w.w_got & RR_LINK) == 0)
        return (0);
    return (w.w_len);
}
