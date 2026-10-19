/* trunkfree - does shrinking a file return its blocks to the volume?
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * apple/fgx#68: ftruncate(2) sets a file's LENGTH correctly -- read(2), stat(2)
 * and a fresh open all agree, and a grow zero-fills -- but the blocks past a
 * shrunk EOF stayed attached to the file's index.  They come back on unlink, so
 * nothing leaks permanently, but `df' does not move when a large file is
 * truncated and a program that resets a log by truncating it to 0 holds the
 * whole allocation until the file is deleted.
 *
 * The oracle is the VOLUME's free-block count, read through getfsstat(2) -- the
 * same number df(1) prints.  Nothing else can see this: the file's length is
 * already correct, so stat(2) reports success either way, which is exactly why
 * the M37/ftrunc fixture says in its header that reclamation is deliberately
 * not asserted.
 *
 * A BASELINE IS TAKEN AFTER THE FILE IS CREATED AND SYNCED, not before, because
 * the directory entry and the index block cost blocks of their own and this is
 * a test about the DATA blocks a shrink should release.  What it asserts is
 * that truncating to 0 gives back what the writes took, within the one block
 * a seedling keeps.
 */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mount.h>
#include <errno.h>

int ftruncate(int fd, long length);

#define PATH   "/root/TRUNKF"
#define PATH2  "/root/TRUNKG"
#define KB     16                      /* 16 x 512 = 8 KB of file data */

static char blk[512];
static struct statfs fs[4];
static unsigned fsblk;                 /* the filesystem's OWN block size */

/* UNSIGNED, and that is not a detail: fcc's int is 16 bits and a 32 MB volume
 * has ~42,000 free blocks, so f_bfree read as a signed int is NEGATIVE.  The
 * first cut of this probe took a baseline of -23487, decided it had failed, and
 * returned before printing anything.  df(1) has the same wart and answers it
 * the same way -- see its u16(). */
static unsigned freeblocks()
{
    int n;

    n = getfsstat(fs, 4 * (int)sizeof(struct statfs), 0);
    if (n < 1) { printf("trunkfree: FAIL getfsstat n=%d\n", n); return 0; }
    return (unsigned)fs[0].f_bfree;
}

/* THE VOLUME'S BLOCK IS NOT 512 AND THIS PROBE USED TO ASSUME IT WAS.  It
 * writes KB buffers of 512 bytes and then required the volume to give up KB
 * blocks, which is true only where a filesystem block IS 512 -- ProDOS, which
 * this was written against.  A 2.11BSD filesystem here has FS_BLKSIZE 1024
 * (src/kernel/vfs/ufs_fs.h), so 8 KB of data is EIGHT blocks plus the single
 * indirect that addresses the ones past NDADDR = 4, and the volume correctly
 * gave up nine where the probe demanded sixteen.  It reported "the write did
 * not cost what it should" about a volume whose accounting was right.
 *
 * So the expectation comes from statfs's own f_bsize, which is the number df(1)
 * divides by and the one place the size is stated by the machine rather than by
 * this file.  Deriving it also means this probe keeps working if FS_BLKSIZE
 * ever moves, which is the point of asking rather than assuming. */
static unsigned dblocks(nbytes)
long nbytes;
{
    if (fsblk == 0) return 0;
    return (unsigned)((nbytes + (long)fsblk - 1L) / (long)fsblk);
}

/* Every byte of `path' must be `want', over nblk blocks.  Names the block and
 * the byte it found on failure -- "content differs" would leave the next reader
 * re-running it by hand to learn which end was corrupted. */
static int allbytes(path, want, nblk)
char *path;
int want;
int nblk;
{
    int fd, i, j, n;

    fd = open(path, O_RDONLY);
    if (fd < 0) { printf("trunkfree: FAIL verify-open %s\n", path); return 0; }
    for (i = 0; i < nblk; i++) {
        n = read(fd, blk, sizeof(blk));
        if (n != sizeof(blk)) {
            printf("trunkfree: FAIL short read %s block %d got %d\n", path, i, n);
            close(fd);
            return 0;
        }
        for (j = 0; j < sizeof(blk); j++) {
            if (blk[j] != want) {
                /* One physical line: fcc does not concatenate adjacent
                 * string literals (apple/fgx#158). */
                printf("trunkfree: FAIL %s blk %d byte %d is '%c' want '%c' -- BLOCKS ARE SHARED\n", path, i, j, blk[j], want);
                close(fd);
                return 0;
            }
        }
    }
    close(fd);
    return 1;
}

int main()
{
    int fd, i;
    unsigned before, after, grew, back, want;

    for (i = 0; i < sizeof(blk); i++) blk[i] = 'x';

    unlink(PATH);
    sync();
    before = freeblocks();
    if (before == 0) return 1;
    fsblk = (unsigned)fs[0].f_bsize;   /* freeblocks() just filled fs[0] */
    if (fsblk == 0) {
        printf("trunkfree: FAIL statfs reports a block size of 0\n");
        return 1;
    }

    fd = creat(PATH, 0644);
    if (fd < 0) { printf("trunkfree: FAIL creat\n"); return 1; }
    for (i = 0; i < KB; i++) {
        if (write(fd, blk, sizeof(blk)) != sizeof(blk)) {
            printf("trunkfree: FAIL write %d\n", i);
            return 1;
        }
    }
    close(fd);
    sync();

    grew = before - freeblocks();
    want = dblocks((long)KB * 512L);
    printf("trunkfree: %d bytes written, volume gave up %u of >=%u %u-byte\n",
           KB * 512, grew, want, fsblk);
    if (grew < want) {
        printf("trunkfree: FAIL the write did not cost what it should\n");
        return 1;
    }

    fd = open(PATH, O_RDWR);
    if (fd < 0) { printf("trunkfree: FAIL reopen\n"); return 1; }
    if (ftruncate(fd, 0L) != 0) {
        printf("trunkfree: FAIL ftruncate e=%d\n", errno);
        return 1;
    }
    close(fd);
    sync();

    after = freeblocks();
    back = after - (before - grew);
    printf("trunkfree: truncate to 0 returned %u of %u\n", back, grew);

    /* ONE BLOCK OF SLACK, because the directory entry stays until unlink and
     * the inode's own block is not the data's.  "All of it" is grew-1 rather
     * than grew for that reason and not because a block is retained -- a UFS
     * truncate to zero releases every data block AND the indirect. */
    if (back < grew - 1) {
        printf("trunkfree: FAIL shrink did not return the blocks\n");
        unlink(PATH);
        return 1;
    }

    /* ---- THE DANGEROUS HALF.  Returning the blocks is easy; returning them
     * while the file's index still points at them is the cross-linked-block
     * corruption the elvis /tmp bug produced, and a free-count check cannot
     * see it -- the count is right either way.
     *
     * So: claim the freed space with a SECOND file, fill it with a different
     * byte, and then read BOTH back.  If a block was freed while still
     * reachable through the truncated file's index, the two files now share
     * it and one of them reads the other's bytes. ---- */
    fd = open(PATH, O_WRONLY);
    if (fd < 0) { printf("trunkfree: FAIL reopen-write\n"); return 1; }
    for (i = 0; i < sizeof(blk); i++) blk[i] = 'A';
    for (i = 0; i < KB / 2; i++) {
        if (write(fd, blk, sizeof(blk)) != sizeof(blk)) {
            printf("trunkfree: FAIL rewrite %d\n", i); return 1;
        }
    }
    close(fd);

    fd = creat(PATH2, 0644);
    if (fd < 0) { printf("trunkfree: FAIL creat2\n"); return 1; }
    for (i = 0; i < sizeof(blk); i++) blk[i] = 'B';
    for (i = 0; i < KB / 2; i++) {
        if (write(fd, blk, sizeof(blk)) != sizeof(blk)) {
            printf("trunkfree: FAIL write2 %d\n", i); return 1;
        }
    }
    close(fd);
    sync();

    if (!allbytes(PATH,  'A', KB / 2)) { unlink(PATH); unlink(PATH2); return 1; }
    if (!allbytes(PATH2, 'B', KB / 2)) { unlink(PATH); unlink(PATH2); return 1; }

    unlink(PATH);
    unlink(PATH2);
    sync();
    printf("trunkfree: to-zero ok\n");

    /* ---- PARTIAL SHRINK, which is a different code path and the riskier one.
     * Truncating to zero frees the index block outright, so nothing is left
     * pointing at the released data.  A partial shrink KEEPS the index -- so
     * every slot it frees must also be ZEROED and the index rewritten, or the
     * file still names blocks the volume has given away.  That is the
     * cross-linked-block shape, and only this case reaches it. ---- */
    unlink(PATH);
    sync();
    before = freeblocks();

    fd = creat(PATH, 0644);
    if (fd < 0) { printf("trunkfree: FAIL creat3\n"); return 1; }
    for (i = 0; i < sizeof(blk); i++) blk[i] = 'C';
    for (i = 0; i < KB; i++) {
        if (write(fd, blk, sizeof(blk)) != sizeof(blk)) {
            printf("trunkfree: FAIL write3 %d\n", i); return 1;
        }
    }
    close(fd);
    sync();
    grew = before - freeblocks();

    fd = open(PATH, O_RDWR);
    if (fd < 0) { printf("trunkfree: FAIL reopen3\n"); return 1; }
    if (ftruncate(fd, (long)(KB / 2) * 512L) != 0) {
        printf("trunkfree: FAIL ftruncate-partial e=%d\n", errno);
        return 1;
    }
    close(fd);
    sync();

    back = freeblocks() - (before - grew);
    /* HALF THE DATA IN THE FILESYSTEM'S BLOCKS, not in 512-byte ones -- the
     * same correction as the write check above, and it was wrong here too:
     * this demanded KB/2 = 8 back where truncating 8 KB to 4 KB releases four
     * data blocks and the indirect that addressed them. */
    want = dblocks((long)KB * 512L) - dblocks((long)(KB / 2) * 512L);
    if (want > 0) want--;              /* the same one block of slack */
    printf("trunkfree: partial shrink returned %u of %u (>=%u)\n",
           back, grew, want);
    if (back < want) {
        printf("trunkfree: FAIL partial shrink kept the blocks\n");
        unlink(PATH); return 1;
    }

    /* The surviving half must still read as its own bytes... */
    if (!allbytes(PATH, 'C', KB / 2)) { unlink(PATH); return 1; }

    /* ...and the released half must be safely reusable by someone else. */
    fd = creat(PATH2, 0644);
    if (fd < 0) { printf("trunkfree: FAIL creat4\n"); return 1; }
    for (i = 0; i < sizeof(blk); i++) blk[i] = 'D';
    for (i = 0; i < KB / 2; i++) {
        if (write(fd, blk, sizeof(blk)) != sizeof(blk)) {
            printf("trunkfree: FAIL write4 %d\n", i); return 1;
        }
    }
    close(fd);
    sync();

    if (!allbytes(PATH,  'C', KB / 2)) { unlink(PATH); unlink(PATH2); return 1; }
    if (!allbytes(PATH2, 'D', KB / 2)) { unlink(PATH); unlink(PATH2); return 1; }

    /* ---- AND NOW GROW IT BACK, which is the only thing that can SEE a stale
     * index slot on a partial shrink.  Reading the truncated file cannot: its
     * EOF stops short of the released slots, so a slot still naming a freed
     * block is invisible until the file reaches that far again.  Growing walks
     * back over those slots -- and if they still point at blocks PATH2 now
     * owns, the zero-fill writes through them and PATH2's data is destroyed.
     *
     * So the assertion is on PATH2, after PATH has grown over the ground it
     * gave up.  Without this the probe passes with the zeroing removed, which
     * makes it no test of the thing it was written for. ---- */
    fd = open(PATH, O_RDWR);
    if (fd < 0) { printf("trunkfree: FAIL reopen4\n"); return 1; }
    if (ftruncate(fd, (long)KB * 512L) != 0) {
        printf("trunkfree: FAIL ftruncate-grow e=%d\n", errno);
        return 1;
    }
    close(fd);
    sync();

    if (!allbytes(PATH2, 'D', KB / 2)) {
        printf("trunkfree: (the grow wrote through a stale index slot)\n");
        unlink(PATH); unlink(PATH2); return 1;
    }

    unlink(PATH);
    unlink(PATH2);
    sync();
    printf("trunkfree: OK to-zero and partial shrink both return their blocks unshared\n");
    return 0;
}
