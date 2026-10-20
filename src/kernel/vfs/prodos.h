/* FGX-Origin: original -- FGX code.  No BSD ever carried a ProDOS filesystem;
 * the in-core node takes its SHAPE from netbsd-0-9's pcfs denode (advisory
 * only) and the on-disk layout from ProDOS itself, as FGX's retired ProDOS
 * code recorded it.
 * prodos.h -- a ProDOS volume, on disk and in core.  ProDOS FST P2.
 *
 *----------------------------------------------------------------------------
 * A PRODOS BLOCK IS HALF A BUFFER.  The buffer cache holds FS_BLKSIZE (1024)
 * bytes per buffer and bio_strategy fills one from device blocks 2k and 2k+1;
 * a ProDOS block is one 512-byte device block.  So ProDOS block n lives in
 * buffer n >> 1 at byte offset (n & 1) * 512, and PD_BUFBLK/PD_BUFOFF are the
 * only arithmetic that knows it.  A volume with an ODD block count has a last
 * block whose buffer runs one device block past the end of the volume, so
 * that one block reads EIO; every size cadius and ProDOS's own formatters
 * write is even.
 *----------------------------------------------------------------------------
 */
#ifndef _PRODOS_H_
#define _PRODOS_H_

#define PD_BLKSIZE          512
#define PD_BUFBLK(n)        ((daddr_t)((unsigned)(n) >> 1))
#define PD_BUFOFF(n)        (((unsigned)(n) & 1) * PD_BLKSIZE)

/* A DIRECTORY BLOCK: two link words, then 13 entries of 39 bytes.  The volume
 * directory's key block is 2, and slot 0 of any directory's key block is its
 * header rather than a file.  entry_length and entries_per_block are recorded
 * in every header and are $27 and $0D on every volume ProDOS writes; mount
 * refuses a volume that says otherwise rather than reading it wrongly. */
#define PD_VOLDIR_BLK       2
#define PD_DB_PREV          0
#define PD_DB_NEXT          2
#define PD_DB_ENTRIES       4
#define PD_ENTLEN           39
#define PD_ENTPERBLK        13
#define PD_ENTOFF(idx)      (PD_DB_ENTRIES + (idx) * PD_ENTLEN)

/* Offsets within a 39-byte entry -- a file entry, a subdirectory header or
 * the volume header, which share the first byte and the name.  Checked
 * against "Beneath Apple ProDOS" pp. 4-8 to 4-11, whose tables count from the
 * start of the BLOCK: an entry-relative offset here is theirs minus 4 for the
 * header and theirs as written for a file entry.  Multi-byte fields are
 * low byte first. */
#define PD_E_STNL           0x00    /* storage type << 4 | name length */
#define PD_E_NAME           0x01    /* 15 bytes */
#define PD_E_FILETYPE       0x10
#define PD_E_KEYPTR         0x11    /* file entries only */
#define PD_E_BLKSUSED       0x13
#define PD_E_EOF            0x15    /* 3 bytes */
#define PD_E_CREATE         0x18    /* date word, time word */
#define PD_E_VERSION        0x1C    /* with MINVER: GS/OS's case word */
#define PD_E_MINVER         0x1D
#define PD_E_ACCESS         0x1E
#define PD_E_AUXTYPE        0x1F
#define PD_E_MODTIME        0x21
#define PD_E_HEADERPTR      0x25    /* the parent directory's key block */

/* ...and the header-only fields, same entry, different meaning from 0x14. */
#define PD_H_ENTRYLEN       0x1F
#define PD_H_ENTPERBLK      0x20
#define PD_H_FILECOUNT      0x21
#define PD_VH_BITMAP        0x23    /* volume header: bit_map_pointer */
#define PD_VH_TOTBLKS       0x25    /* volume header: total_blocks */

/* A SUBDIRECTORY HEADER'S WAY BACK.  parent_pointer is the block HOLDING this
 * directory's entry, and parent_entry is that entry's slot in it counted from
 * 1, so a key block's header slot is 1.  That is what ProDOS 8 writes: its
 * create copies d_entblk, "address of block which contains this entry", and
 * d_entnum, "entry number within block", into the new header -- not d_head,
 * the directory's key block (MliSrc.aii, cmvparnt).  GS/OS's ProDOS FST
 * refuses a subdirectory whose parent_pointer is not the block its entry was
 * found in (ProDOS.FST, verify_dir), and cadius writes it the same way.
 *
 * "Beneath Apple ProDOS" p. 4-30 describes parent_pointer as the parent's key
 * block and numbers entries with the header as 0.  The pointer agrees with
 * the MLI while the entry is in the parent's key block -- any parent of twelve
 * entries or fewer, and the book's own example -- and differs once the entry
 * is in a continuation block; the book's entry number is one lower
 * throughout. */
#define PD_H_PARENTPTR      0x23
#define PD_H_PARENTENT      0x25

/* Storage types, the high nibble of PD_E_STNL. */
#define PD_ST_DELETED       0x0
#define PD_ST_SEEDLING      0x1
#define PD_ST_SAPLING       0x2
#define PD_ST_TREE          0x3
#define PD_ST_PASCAL        0x4
#define PD_ST_EXTENDED      0x5
#define PD_ST_SUBDIR        0xD
#define PD_ST_SUBDIRHDR     0xE
#define PD_ST_VOLHDR        0xF

/* A GS/OS EXTENDED FILE ($5), as ProDOS Technical Note #25 lays it out.
 * key_pointer names an EXTENDED KEY BLOCK holding a mini-entry per fork --
 * the data fork's at +$000, the resource fork's at +$100 -- each a storage
 * type in the low nibble, the fork's key block, its blocks used and a
 * three-byte EOF; so each fork is a seedling, sapling or tree of its own.
 * After the data fork's mini-entry come up to two 18-byte Finder info
 * entries, at +8 and +26: a size byte ($12), a type byte (1 for the first 16
 * bytes of HFS Finder info, 2 for the second 16) and the 16 bytes.  "If one
 * of the entries is missing, it should be considered to be all zeroes." */
#define PD_X_DATA           0x000
#define PD_X_RSRC           0x100
#define PD_M_STORAGE        0
#define PD_M_KEY            1
#define PD_M_EOF            5
#define PD_X_FINFO          8
#define PD_X_FINFOLEN       18

/* THE RESOURCE FORK IS `._NAME', AN AppleDouble FILE, as macOS presents one
 * on a filesystem without extended attributes and netatalk's `ea = sys'
 * stores one (xnu bsd/vfs/vfs_xattr.c, "._" AppleDouble Header File): the
 * RFC 1740 header -- magic $00051607, version $00020000, 16 bytes of zero
 * filler, 2 entries -- then Finder Info (entry 9, 32 bytes, first) and the
 * Resource Fork (entry 2, last).  Header and Finder info are PD_ADHDRLEN
 * bytes; the fork follows.  NAME itself is the data fork.
 *
 * A `._NAME' node is keyed on its entry's location with PD_ADIDX set in the
 * index, which a slot number (0-12) never has. */
#define PD_ADIDX            0x10
#define PD_ADHDRLEN         82

#define PD_STORAGE(e)       (((e)[PD_E_STNL] >> 4) & 0x0F)
#define PD_NAMELEN(e)       ((e)[PD_E_STNL] & 0x0F)
#define PD_NAMEMAX          15
#define PD_GETW(p)          ((unsigned)(p)[0] | ((unsigned)(p)[1] << 8))
#define PD_UPPER(c)         (((c) >= 'a' && (c) <= 'z') ? (c) - ('a' - 'A') : (c))

/* An INDEX BLOCK -- a sapling's key block, a tree's master index and each of
 * its sub-indexes -- holds 256 block numbers split by byte: the low bytes in
 * the first half, the high bytes in the second.  A zero entry is a hole. */
#define PD_IDXENT(b, i)     ((unsigned)(b)[i] | ((unsigned)(b)[256 + (i)] << 8))

/*============================================================================
 * THE IN-CORE NODE.
 *
 * THE KEY IS A DIRECTORY-ENTRY LOCATION, AND WHICH ONE IS pcfs's CANONICAL
 * FORM.  A FILE is keyed on (the directory block holding its entry, the
 * entry's index 0-12 in that block).  A DIRECTORY is keyed on (its OWN key
 * block, 0) -- its header slot -- and the volume root on (2, 0).  pcfs's deget
 * converts a directory the same way and for the same reason: more than one
 * thing leads to a directory (its entry in the parent, and every child's
 * header_pointer, which names the parent's key block), so only the directory's
 * own location is reachable from all of them.  A directory's key block never
 * moves -- a directory grows by linking blocks, not by promotion.
 *
 * AND NOT THE KEY BLOCK FOR A FILE, which is the obvious answer and the wrong
 * one on a filesystem that writes: seedling -> sapling -> tree promotion
 * allocates a new key block and rewrites key_pointer, so a key-block identity
 * would change the first time a file grew past 512 bytes.  The entry does not
 * move.  See docs/history/plans/2026-09-13-prodos-fst-design.md section 4.
 *
 * THE INODE NUMBER IS NOT THE KEY.  The key needs 20 bits and ino_t has 16;
 * pd_getattr numbers a node by its key block instead.
 *
 * IT LIVES IN THE VNODE'S PRIVATE AREA, as struct inode does, so there is no
 * node pool and getnewvnode supplies both.  prodos_init refuses to run if this
 * outgrows VN_MAXPRIVATE, which is pcfs_init's own check.
 *
 * pd_refcnt IS pcfs's de_refcnt, and it is NOT a use count -- the vnode keeps
 * that.  It is 1 while a directory entry names this node and drops to 0 when
 * the entry is removed, so a later lookup that lands on the same slot cannot
 * find an unlinked-but-open file.  pd_remove sets it; the blocks go at
 * pd_inactive, when the last reference does.
 *============================================================================
 */
struct pdnode {
    struct pdnode  *pd_chain[2];    /* hash chain, MUST be first */
    struct vnode   *pd_vnode;
    struct vnode   *pd_devvp;
    unsigned short  pd_flag;
    short           pd_lockholder;  /* pid holding PDLOCKED, or 0 */
    dev_t           pd_dev;
    unsigned short  pd_dirblk;
    short           pd_diridx;
    short           pd_refcnt;
    struct pdmount *pd_pmp;
    unsigned char   pd_ent[PD_ENTLEN];  /* the entry, byte for byte */
    short           pd_fst;         /* the bytes read: storage type, -1 = unread */
    unsigned short  pd_fkey;        /*   their key block */
    long            pd_feof;        /*   their EOF */
};

#define PDLOCKED            0x0001
#define PDWANT              0x0002
#define PDMOD               0x0004  /* written; pd_ripple owes its directories */

#define VTOPD(vp)           ((struct pdnode *)(vp)->v_data)
#define PDTOV(pd)           ((pd)->pd_vnode)

/* One mounted volume.  A static pool of VFS_NMOUNT in prodos_vfsops.c, for
 * the reason ufs_mpool is one: module C has no allocator. */
struct pdmount {
    struct mount   *pm_mountp;      /* null = free slot */
    struct vnode   *pm_devvp;
    dev_t           pm_dev;
    unsigned short  pm_totblks;     /* total_blocks */
    unsigned short  pm_bitmap;      /* bit_map_pointer */
    long            pm_free;        /* free blocks, counted at mount */
};

#define VFSTOPD(mp)         ((struct pdmount *)(mp)->mnt_data)

/* THE WRITE HALF, prodosw.mod, which prodos_write.c compiles into.  prodos.mod
 * reads a volume on its own; loading prodosw.mod hands these over through
 * pd_setwriteops, with a vector of its own for them to fill, and new nodes and
 * pd_inactive call them from then on.  Until then every slot that would change
 * a volume answers ENOTSUP and a writable mount is refused with EROFS.  Two modules because one bank does not
 * hold both halves; the dependency runs one way, from the write half into
 * this one (VT_PDCORE). */
struct pdwops {
    int (*w_write)();
    int (*w_close)();
    int (*w_create)();
    int (*w_remove)();
    int (*w_rename)();
    int (*w_setattr)();
    int (*w_free)();
    int (*w_ripple)();
};

#endif /* _PRODOS_H_ */
