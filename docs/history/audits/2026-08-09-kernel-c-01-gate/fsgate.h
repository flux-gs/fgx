/* fsgate.h -- just enough of a BSD kernel to COMPILE the gate subjects.
 *
 * The 0.1 gate measures what fcc makes of real filesystem code.  It does not
 * link and does not run, so this header supplies the shapes the sources need
 * and nothing else: sizes and field offsets matter (they drive the addressing
 * fcc emits), bodies do not.
 *
 * Sizes are 2.11BSD's, which is the on-disk format the campaign adopts:
 * 16-bit ino_t, 32-bit daddr_t, 4 direct + 3 indirect, DEV_BSIZE 1024.
 */
typedef long  daddr_t;
typedef unsigned short ino_t;
typedef unsigned short dev_t;
typedef long  off_t;
typedef long  time_t;

#define NADDR    7          /* 4 direct + 3 indirect */
#define NSHIFT   8          /* 256 daddr_t per 1024-byte block */
#define NMASK    0377
#define NINDIR   256
#define EFBIG    27
#define B_READ   1
#define B_SYNC   2
#define B_CLRBUF 4
#define B_ERROR  8
#define MNT_ASYNC 0100
#define IUPD     02
#define ICHG     010
#define NULL     0

struct fs {
    short  fs_flags;
    daddr_t fs_size;
};

struct inode {
    struct inode *i_chain;
    dev_t   i_dev;
    ino_t   i_number;
    short   i_flag;
    short   i_count;
    short   i_mode;
    short   i_nlink;
    short   i_uid;
    short   i_gid;
    off_t   i_size;
    daddr_t i_addr[NADDR];
    struct fs *i_fs;
};

struct buf {
    struct buf *b_forw;
    short   b_flags;
    daddr_t b_blkno;
    short   b_resid;
    char   *b_addr;
};

struct user { int u_error; };
extern struct user u;
extern daddr_t rablock;

extern struct buf *balloc();
extern struct buf *bread();
extern void brelse();
extern void bwrite();
extern void bdwrite();

/* 2.11BSD: DEV_BSIZE 1024 over 512-byte sectors, so fsbtodb is <<1. */
#define dbtofsb(b) ((daddr_t)((b) >> 1))
