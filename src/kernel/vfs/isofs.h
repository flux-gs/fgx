/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: netbsd-0-9 sys/isofs/iso.h, sys/isofs/isofs_node.h;
 *   4.4BSD-Lite2 sys/isofs/cd9660/iso.h
 *   The on-disk layout is iso.h's, in both trees; the in-core node and mount
 *   are netbsd-0-9's, with Lite2's node numbering (isodirino).
 *   Original work:
 *   Copyright (c) 1994 The Regents of the University of California.
 *   All rights reserved.  This code is derived from software
 *   contributed to Berkeley by Pace Willisson (pace@blitz.com).
 */
/* isofs.h -- an ISO 9660 volume, on disk and in core.
 *
 *----------------------------------------------------------------------------
 * THE ON-DISK STRUCTURES ARE BYTE OFFSETS, NOT STRUCTS.  iso.h declares them
 * as structs of char arrays sized by ISODCL(from, to), and the directory
 * record ends in a zero-length name[] that K&R C has no spelling for.  The
 * offsets below are those structs' fields, from 0 where ISODCL counts from 1.
 * Multi-byte numbers are ISO 9660's: 711 one byte, 723 a 16-bit both-endian
 * pair (the little-endian half first), 733 a 32-bit both-endian pair; the
 * little-endian half is the one read.
 *
 * EVERY BLOCK NUMBER, SIZE AND OFFSET IS A long.  The upstream code holds them
 * in int, which is 32 bits there and 16 here: an extent past sector 32767, a
 * file past 32 KB or a byte address past 64 KB would wrap silently.
 *----------------------------------------------------------------------------
 */
#ifndef _ISOFS_H_
#define _ISOFS_H_

/* A volume descriptor: one 2048-byte sector from sector 16 on, whatever the
 * volume's logical block size (ISO 9660 8.1). */
#define ISO_VD_SECTOR       16L
#define ISO_SECSIZE         2048
#define ISO_VD_TYPE         0       /* 711 */
#define ISO_VD_ID           1       /* "CD001", 5 bytes */
#define ISO_VD_PRIMARY      1
#define ISO_VD_END          255
#define ISO_PVD_VOLID       40      /* 32 d-characters */
#define ISO_PVD_VOLSIZE     80      /* 733, in logical blocks */
#define ISO_PVD_LBSIZE      128     /* 723 */
#define ISO_PVD_ROOTDR      156     /* the root's directory record, 34 bytes */
#define ISO_ROOTDR_LEN      34

/* A directory record (ISO 9660 9.1).  ISO_DR_SIZE is the fixed part, before
 * the name -- iso.h's ISO_DIRECTORY_RECORD_SIZE.  A record never crosses a
 * logical block; a zero length byte means the rest of the block is unused. */
#define ISO_DR_LEN          0       /* 711 */
#define ISO_DR_EXTATTR      1       /* 711: extended attribute record blocks */
#define ISO_DR_EXTENT       2       /* 733 */
#define ISO_DR_SIZE_        10      /* 733, data length in bytes */
#define ISO_DR_DATE         18      /* 7 bytes: year-1900 month day h m s tz */
#define ISO_DR_FLAGS        25
#define ISO_DR_UNIT         26      /* 711: file unit size (interleaving) */
#define ISO_DR_GAP          27      /* 711: interleave gap */
#define ISO_DR_NAMELEN      32      /* 711 */
#define ISO_DR_NAME         33
#define ISO_DR_SIZE         33

#define ISO_FL_DIR          0x02
#define ISO_FL_ASSOC        0x04    /* an associated file, Lite2's `=NAME' */

#define isonum_711(p)       ((int)((unsigned char *)(p))[0])
#define isonum_723(p)       ((int)((unsigned char *)(p))[0] | \
                             ((int)((unsigned char *)(p))[1] << 8))
#define isonum_733(p)       ((long)((unsigned char *)(p))[0] | \
                             ((long)((unsigned char *)(p))[1] << 8) | \
                             ((long)((unsigned char *)(p))[2] << 16) | \
                             ((long)((unsigned char *)(p))[3] << 24))

/* The attributes a node is made from: parsed out of a directory record while
 * the record's buffer is held, so the record itself never travels.
 * netbsd-0-9's iso_iget took a pointer into the directory buffer -- and its
 * `..' arm passed one after brelse had released it (isofs_lookup.c). */
struct isoattr {
    long            ia_extent;      /* first logical block of the data */
    long            ia_size;        /* bytes */
    long            ia_mtime;       /* seconds since the epoch */
    unsigned short  ia_mode;        /* permission bits */
    uid_t           ia_uid;
    gid_t           ia_gid;
    short           ia_nlink;
    char            ia_flags;       /* ISO_FL_* */
    char            ia_interleaved; /* file unit size or gap set */
};

/*============================================================================
 * THE IN-CORE NODE.
 *
 * ITS NUMBER IS Lite2's isodirino (cd9660_node.c) and NOT netbsd-0-9's
 * extent.  A directory is numbered by the byte address of its data, which is
 * where its own "." record is, so its entry in its parent, its "." and every
 * child's ".." all name the same node.  A file is numbered by the byte
 * address of its directory record.  netbsd-0-9 numbered both by the extent,
 * and every empty file -- extent 0, or the same extent as another -- became
 * one node.  The number is 32 bits; stat and readdir fold it to ino_t's 16
 * (isofs_ino16), and the fold can alias on a volume past 2 MB, which only
 * matters to getwd's matching of a name against a number.
 *
 * IT LIVES IN THE VNODE'S PRIVATE AREA, as struct inode does; isofs_init
 * refuses to run if it outgrows VN_MAXPRIVATE, netbsd-0-9's own check.
 *============================================================================
 */
struct isonode {
    struct isonode *i_chain[2];     /* hash chain, MUST be first */
    struct vnode   *i_vnode;
    struct vnode   *i_devvp;
    unsigned short  i_flag;
    short           i_lockholder;   /* pid holding ILOCKED, or 0 */
    dev_t           i_dev;
    long            i_number;       /* isodirino: the key */
    struct isomount *i_mnt;
    struct isoattr  i_attr;
};

#define ILOCKED             0x0001
#define IWANT               0x0002

#define VTOI(vp)            ((struct isonode *)(vp)->v_data)
#define ITOV(ip)            ((ip)->i_vnode)

/* One mounted volume.  A static pool of VFS_NMOUNT in isofs_vfsops.c, as
 * prodos's is: module C has no allocator. */
struct isomount {
    struct mount   *im_mountp;      /* null = free slot */
    struct vnode   *im_devvp;
    dev_t           im_dev;
    int             im_bsize;       /* logical block size */
    int             im_bshift;      /* log2 of it */
    long            im_volsize;     /* logical blocks */
    long            im_rootext;     /* the root directory's extent... */
    long            im_rootsize;    /* ...and size */
    char            im_rr;          /* Rock Ridge: iso_rroffset found it */
    unsigned char   im_rrskip;      /* SP's skip, for every record... */
    unsigned char   im_rrskip0;     /* ...and where SP was, in the root's "." */
};

#define VFSTOISO(mp)        ((struct isomount *)(mp)->mnt_data)

/* A logical block's byte address on the volume. */
#define ISO_BYTE(imp, lbn)  ((long)(lbn) << (imp)->im_bshift)

#endif /* _ISOFS_H_ */
