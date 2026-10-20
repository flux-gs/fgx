/* trunctree - does shrinking a DOUBLE-INDIRECT file return its blocks?
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * apple/fgx#159, the half of apple/fgx#68 that trunkfree does not reach.  That
 * probe writes 8 KB -- eight filesystem blocks plus the single indirect that
 * addresses the four past NDADDR -- so `ufs_indirtrunc' runs at recursion
 * level 0 and only level 0.  apple/fgx#193 filed the gap in as many words:
 * "no UFS probe case reaches ufs_indirtrunc at recursion level 1 or 2 -- the
 * double- and triple-indirect truncate path.  Every existing case uses files
 * small enough to stay at level 0, which is exactly where a wrong row stride
 * multiplies to zero."
 *
 * THE FILE IS STAGED, NOT WRITTEN HERE.  /root/big300 is built by
 * tools/make_ufsboot.sh with `fgxfs mkfile --blocks 300'; 300 KB of writes
 * through the vnode path is minutes of guest time and the subject is the
 * TRUNCATE.  With NDADDR = 4 and NINDIR = 256 the single indirect covers
 * blocks 4..259, so block 260 is the first the DOUBLE indirect addresses and
 * a 300-block file owns 303: 300 data, one single indirect, one double, and
 * one sub-index under the double.
 *
 * THE ORACLE IS THE VOLUME'S FREE COUNT, through getfsstat(2) -- the number
 * df(1) prints, and the only thing that can see this.  The file's LENGTH is
 * correct either way: read(2) and stat(2) agree on a truncated file whether
 * or not its blocks came back.
 *
 * WHY IT ASKS FOR >= 302 AND NOT == 303.  The directory entry and the inode
 * are not data blocks and do not move; one block of slack is trunkfree's
 * convention for the same reason.  Asking for at least 302 still fails hard on
 * the shape this exists to catch: a walk that stops at level 0 returns 260 of
 * them and leaves 43 -- the whole double-indirect subtree -- attached to a file
 * that no longer names it.
 */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mount.h>
#include <errno.h>

int ftruncate(int fd, long length);

#define PATH   "/root/big300"
#define BLOCKS 300

static struct statfs fs[4];

/* UNSIGNED, for trunkfree's reason: fcc's int is 16 bits and a 32 MB volume
 * has more free blocks than one can hold, so f_bfree read as a signed int is
 * negative.  df(1) has the same wart and answers it the same way. */
static unsigned freeblocks()
{
    int n;

    n = getfsstat(fs, 4 * (int)sizeof(struct statfs), 0);
    if (n < 1) { printf("trunctree: FAIL getfsstat n=%d\n", n); return 0; }
    return (unsigned)fs[0].f_bfree;
}

int main()
{
    int      fd;
    unsigned before, after, back, want;
    unsigned fsblk, dblocks;

    before = freeblocks();
    if (before == 0) return 1;
    fsblk = (unsigned)fs[0].f_bsize;
    if (fsblk == 0) { printf("trunctree: FAIL block size 0\n"); return 1; }

    /* THE FILE MUST OWN A DOUBLE INDIRECT OR THIS PROVES NOTHING, so say so
     * from the geometry rather than trusting the build: 300 blocks of 1024 is
     * past NDADDR + NINDIR = 260.  A volume built with a different FS_BLKSIZE
     * would move that boundary, and a probe that carried on regardless would
     * be a level-0 test wearing this one's name. */
    dblocks = (unsigned)(((long)BLOCKS * 1024L + (long)fsblk - 1L) / (long)fsblk);
    if (dblocks <= 4 + 256) {
        printf("trunctree: FAIL %u blocks of %u does not reach the double "
               "indirect (needs > %d)\n", dblocks, fsblk, 4 + 256);
        return 1;
    }

    fd = open(PATH, O_RDWR);
    if (fd < 0) { printf("trunctree: FAIL open e=%d\n", errno); return 1; }
    if (ftruncate(fd, 0L) != 0) {
        printf("trunctree: FAIL ftruncate e=%d\n", errno);
        close(fd);
        return 1;
    }
    close(fd);
    sync();

    after = freeblocks();
    if (after == 0) return 1;
    back = after - before;

    /* 300 data + 1 single + 1 double + 1 sub-index, less one block of slack. */
    want = dblocks + 3;
    printf("trunctree: %u data block(s), volume returned %u of %u\n",
           dblocks, back, want);
    if (back + 1 < want) {
        printf("trunctree: FAIL the double-indirect subtree was not freed\n");
        return 1;
    }
    printf("trunctree: OK a double-indirect file gives its whole tree back\n");
    return 0;
}
