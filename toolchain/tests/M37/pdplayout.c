/* pdplayout.c -- 0.2 of the UFS migration campaign: LOCK fcc's PDP-11-identical
 * struct layout, because the 2.11BSD on-disk format is declared as C structs and
 * a silent alignment change would corrupt every volume FGX ever writes.
 *
 * These are not derived from headers.  Every number below was MEASURED on a live
 * 2.11BSD PDP-11/70 (kernel #18) on 2026-08-09 and is reproduced here so that
 * fcc drifting away from it is a RED FIXTURE rather than an unreadable disk.
 * The whole cross-mount goal -- an FGX volume mounting on a real 11/70 and back
 * -- rests on these offsets and nothing else enforces them.
 *
 * THE LOAD-BEARING FACT IS THAT A LONG IS 2-ALIGNED, NOT 4-ALIGNED.  fs_fsize
 * sits at offset 2 rather than 4, and struct fs packs contiguously to exactly
 * 446 with no interior padding anywhere.  Align longs to 4 and every one of
 * these sizes grows, silently, and volumes stop being mountable.
 *
 * Exit 42 = pass; every other code identifies the failing property.
 */

/* The 2.11BSD scalar types, at fcc widths: short 2, int 2, long 4, ptr 2 --
 * the same widths the PDP-11 has, which is why this port works at all. */
typedef unsigned short  ino_t;
typedef unsigned short  dev_t;
typedef unsigned short  uid_t;
typedef unsigned short  gid_t;
typedef long            daddr_t;
typedef long            time_t;
typedef long            off_t;

#define NADDR       7           /* 4 direct + 3 indirect */
#define NICFREE     50
#define NICINOD     100
#define MAXNAMLEN   63
#define MAXMNTLEN   12

/* h/inode.h -- the on-disk inode.  64 bytes, 16 to a 1024-byte block. */
struct icommon1 {
    unsigned short  ic_mode;
    unsigned short  ic_nlink;
    uid_t           ic_uid;
    gid_t           ic_gid;
    off_t           ic_size;
};

struct icommon2 {
    time_t          ic_atime;
    time_t          ic_mtime;
    time_t          ic_ctime;
};

struct dinode {
    struct icommon1 di_icom1;
    daddr_t         di_addr[NADDR];
    unsigned short  di_reserved[5];
    unsigned short  di_flags;
    struct icommon2 di_icom2;
};

/* h/dir.h -- 70 bytes, and the 6-byte header is what makes DIRSIZ round the
 * header and the name TOGETHER.  Reno's header is 8 and rounds them
 * separately, so this size is the incompatibility, not a detail. */
struct direct {
    ino_t           d_ino;
    unsigned short  d_reclen;
    unsigned short  d_namlen;
    char            d_name[MAXNAMLEN + 1];
};

/* h/fs.h -- the superblock.  446 bytes, no interior padding. */
struct fs {
    unsigned short  fs_isize;
    daddr_t         fs_fsize;
    short           fs_nfree;
    daddr_t         fs_free[NICFREE];
    short           fs_ninode;
    ino_t           fs_inode[NICINOD];
    char            fs_flock;
    char            fs_fmod;
    char            fs_ilock;
    char            fs_ronly;
    time_t          fs_time;
    daddr_t         fs_tfree;
    ino_t           fs_tinode;
    short           fs_step;
    short           fs_cyl;
    char            fs_fsmnt[MAXMNTLEN];
    ino_t           fs_lasti;
    ino_t           fs_nbehind;
    unsigned short  fs_flags;
};

/* The generic case the campaign measured first: a long lands at 2, and the
 * total is 24, both of which are the PDP-11 answers. */
struct probe {
    unsigned short  a;
    long            b;
    unsigned short  c;
    long            d;
    char            e[7];
    long            f;
};

struct dinode  gdi;
struct direct  gdir;
struct fs      gfs;
struct probe   gp;

/* offset of a member, as a byte count from the head of the object */
#define OFF(obj, mem)  ((int)((char *)&(obj).mem - (char *)&(obj)))

int main()
{
    long  v;
    char *cp;

    /* ---- scalar widths.  Everything else is built on these. ---- */
    if (sizeof(short) != 2)             return 1;
    if (sizeof(int) != 2)               return 2;
    if (sizeof(long) != 4)              return 3;
    if (sizeof(daddr_t) != 4)           return 4;
    if (sizeof(ino_t) != 2)             return 5;

    /* ---- the generic probe: a long is 2-aligned, not 4-aligned ---- */
    if (OFF(gp, b) != 2)                return 6;
    if (OFF(gp, c) != 6)                return 7;
    if (OFF(gp, d) != 8)                return 8;
    if (OFF(gp, e) != 12)               return 9;
    if (OFF(gp, f) != 20)               return 10;   /* char[7] then even-align */
    if (sizeof(struct probe) != 24)     return 11;

    /* ---- dinode: 64 bytes, and every offset the format contract names ---- */
    if (sizeof(struct dinode) != 64)    return 12;
    if (OFF(gdi, di_icom1.ic_mode)  !=  0) return 13;
    if (OFF(gdi, di_icom1.ic_nlink) !=  2) return 14;
    if (OFF(gdi, di_icom1.ic_uid)   !=  4) return 15;
    if (OFF(gdi, di_icom1.ic_gid)   !=  6) return 16;
    if (OFF(gdi, di_icom1.ic_size)  !=  8) return 17;
    if (OFF(gdi, di_addr)           != 12) return 18;
    if (OFF(gdi, di_reserved)       != 40) return 19;
    if (OFF(gdi, di_flags)          != 50) return 20;
    if (OFF(gdi, di_icom2.ic_atime) != 52) return 21;
    if (OFF(gdi, di_icom2.ic_ctime) != 60) return 22;

    /* ---- direct: a 6-byte header, name at 6, 70 total ---- */
    if (sizeof(struct direct) != 70)    return 23;
    if (OFF(gdir, d_reclen) != 2)       return 24;
    if (OFF(gdir, d_namlen) != 4)       return 25;
    if (OFF(gdir, d_name)   != 6)       return 26;

    /* ---- fs: fs_fsize at 2 is the one that proves longs are not 4-aligned ---- */
    if (sizeof(struct fs) != 446)       return 27;
    if (OFF(gfs, fs_fsize)  !=   2)     return 28;
    if (OFF(gfs, fs_nfree)  !=   6)     return 29;
    if (OFF(gfs, fs_free)   !=   8)     return 30;
    if (OFF(gfs, fs_ninode) != 208)     return 31;
    if (OFF(gfs, fs_inode)  != 210)     return 32;
    if (OFF(gfs, fs_flock)  != 410)     return 33;
    if (OFF(gfs, fs_time)   != 414)     return 34;
    if (OFF(gfs, fs_tfree)  != 418)     return 35;
    if (OFF(gfs, fs_tinode) != 422)     return 36;
    if (OFF(gfs, fs_fsmnt)  != 428)     return 37;
    if (OFF(gfs, fs_lasti)  != 440)     return 38;
    if (OFF(gfs, fs_flags)  != 444)     return 39;

    /* ---- array strides, since the free lists are indexed constantly ---- */
    if ((int)((char *)&gfs.fs_free[1] - (char *)&gfs.fs_free[0]) != 4)
        return 40;
    if ((int)((char *)&gfs.fs_inode[1] - (char *)&gfs.fs_inode[0]) != 2)
        return 41;
    if ((int)((char *)&gdi.di_addr[1] - (char *)&gdi.di_addr[0]) != 4)
        return 42 + 1;   /* not 42: 42 is the pass code */

    /* ---- BYTE ORDER: a 65816 long is NATIVE little-endian, so the half-swap
     * to PDP order is real work and not a no-op.  If this ever stops holding,
     * the accessors that convert on read and write are wrong in the other
     * direction and every volume is silently byte-swapped. ---- */
    v = 0x01020304L;
    cp = (char *)&v;
    if ((cp[0] & 0xFF) != 0x04)         return 44;
    if ((cp[1] & 0xFF) != 0x03)         return 45;
    if ((cp[2] & 0xFF) != 0x02)         return 46;
    if ((cp[3] & 0xFF) != 0x01)         return 47;

    return 42;
}
