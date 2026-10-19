/* FGX-Origin: original -- FGX code.  It CITES BSD (see below) but contains
 * none of it; registering it would assert the Regents' copyright over work
 * they did not write.
 * ufs_probe.c -- the on-machine self-test for the FILESYSTEM AS BLOCKS: the
 * 2.11BSD superblock (UFS 1.10a), the block and inode allocators (1.10b) and
 * bmap's descent (1.10c).
 *
 * THE FILESYSTEM AS FILES IS ufs_vnprobe.c, split out at 1.12a for the bank
 * reason below happening a fourth time -- everything that needs a struct
 * mount lives there now: iget and the inode hash, VOP_GETATTR/READ/LOOKUP/
 * READDIR and 1.12a's VOP_WRITE.  Its header carries the measurements.  The
 * two gates are MUTUALLY EXCLUSIVE (kernel.ufsprobe, kernel.ufsvnprobe) and
 * the case numbers do not overlap, so a code still names one property across
 * both.  Nothing else about how a probe works is repeated there.
 *
 * SPLIT OUT OF vfs_probe.c AT 1.10b, AND THE REASON IS THE BANK RATHER THAN
 * THE SUBJECT -- which is the third time this module has had to do it, after
 * the file-table gate at 1.7b.  The allocators cost about 5.9 KB of
 * shipping code, and vfs.mod is one 64 KB bank: with them linked, vfs_probe's
 * cache-wiring cases plus these left 410 bytes free before this file was
 * assembled at all.  Merlin says so in one line -- "Object code size > 64 KB"
 * -- and the ERR guard at the end of vfs.s says it more usefully.
 *
 * The subjects are separable in any case, which is what makes the split clean
 * rather than merely necessary.  vfs_probe asks whether the BUFFER CACHE is
 * wired: does a bread reach a device block, does a write land in the right
 * bank, does one filesystem block become two device transfers.  This asks
 * whether the code that reads a FILESYSTEM agrees with an independent
 * implementation of the same format about what is on the volume.  A failure in
 * one says nothing about the other.
 *
 * EVERY NUMBER BELOW DESCRIBES ONE PARTICULAR VOLUME, and that volume is built
 * by build.ninja's `ufsscratch` rule -- today `mkfs --size 4096` followed by
 * `mkfile /big --blocks 300`.  THE RULE AND THIS FILE ARE A CONTRACT: change
 * the size, the inode density or the file, and every constant here has to be
 * re-derived with tools/fgxfs.py.  That is not a weakness of the design, it is
 * the design -- these are the OTHER implementation's answers, and an assertion
 * the probe could compute for itself would prove nothing.  Adding /big at 1.10c
 * moved twenty of them, and the cost of that is the price of the evidence.
 *
 * THE ORACLE IS tools/fgxfs.py, AND THAT IS THE POINT OF THE WHOLE FILE.
 * disk/ufsscratch.po is built at build time by `fgxfs mkfs --size 4096`
 * (build.ninja), from a host tool that follows 2.11BSD's own mkfs step for
 * step and shares no source with this kernel.  Every constant below was read
 * off that volume with fgxfs and transcribed.  So a green here is two
 * implementations agreeing about a format, which is the claim goal 2 of the
 * campaign rests on -- an FGX volume that a PDP-11 will mount.  One
 * implementation agreeing with itself would be worth nothing.
 *
 * Return 0 = pass; each nonzero value names one failing property.
 *
 *----------------------------------------------------------------------------
 * IT WRITES, AND IT PUTS THE SUPERBLOCK BACK.
 *
 * The 1.10b cases hand out real blocks off the volume's free list and let
 * ufs_balloc write the superblock back, so unlike everything 1.10a did they
 * change the volume.  disk/ufsscratch.po is handed to MAME by path with no
 * per-run copy (run.py's extra_hards), and ninja will not rebuild an output
 * that is newer than its inputs, so a superblock left modified would fail the
 * NEXT boot's case 403 and keep failing.  The block is therefore saved
 * verbatim before the allocator section and restored after it, INCLUDING ON
 * FAILURE.
 *
 * The target is identified by its own superblock before anything is written --
 * never by device index, which is not a promise about which image answers
 * where.  Device 0, the boot disk, is never a candidate; vfs.s picks the
 * device and this file re-checks it.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"
#include "buf.h"        /* bp->b_addr: 1.10c reads a raw i-list block */
#include "ufs_fs.h"
#include "mount.h"
#include "vfsops.h"
#include "ufsmount.h"
#include "inode.h"
#include "uio.h"        /* 1.11b: ufs_read takes a uio */
#include "dir.h"        /* 1.11c: the on-disk directory entry */
#include "namei.h"      /* 1.11c: VOP_LOOKUP takes a nameidata */

extern int          bdevvp();
extern int          ufs_sbread();
extern int          ufs_sbvalid();
extern int          ufs_sbupdate();
extern void         ufs_sbdecode();
extern void         ufs_sbencode();
extern int          ufs_balloc();
extern int          ufs_bfree();
extern int          ufs_ialloc();
extern int          ufs_bmap();
extern long         kern_time();
extern long         ufs_dget32();
extern void         ufs_ifree();
extern void         vrele();
extern int          bread();
extern void         brelse();
extern int          kc_blkio();

#define DEV_BLKSIZE     512
#define PROBE_READ      1
#define PROBE_WRITE     0

/* One 512-byte scratch for the RAW oracle reads. */
static char probebuf[DEV_BLKSIZE];

/* An all-zero superblock image, for the "this is not a filesystem" case and
 * for the byte-level encode check.  STATIC because 446 bytes is a large stack
 * frame for kernel C and this runs on the boot path -- written as an automatic
 * once, and the machine came up with a blank screen. */
static char sbbogus[SB_ONDISK_SIZE];

/* The decoded superblock.  STATIC for the same reason as sbbogus, and it only
 * became true at 1.10b: at 1.10a `struct ufs_sb` was 28 bytes and this was an
 * automatic.  Carrying the cached free lists took it to roughly 460. */
static struct ufs_sb probesb;

/* The allocator's working copy.  A SECOND one rather than reusing probesb,
 * because the validator cases deliberately wreck probesb -- they end by
 * decoding an all-zero block into it -- and the allocator needs a superblock
 * that describes the volume. */
static struct ufs_sb allocsb;


/* THE ORACLE'S ANSWER, AS DATA.  The block addresses `fgxfs` hands out from
 * disk/ufsscratch.po, in order, read off the host and transcribed.  Entry 28
 * is the chain block; everything after it can only be known by reading that
 * block off the disk.  See 7c. */
static ino_t allocseq[33] = {
    343, 345, 347, 349, 351, 353, 355, 357, 359, 361, 363, 365, 367,
    369, 371, 373, 375, 377, 379, 381, 383, 385, 387, 389, 391,
    393,                                /* the chain block: the cache empties */
    395, 397, 399, 400, 402, 404, 406   /* ...and these came off the platter */
};

/* Raw device access, bypassing the cache entirely: this is the oracle. */
static int
rawio(dev, dblk, isread)
    int     dev;
    daddr_t dblk;
    int     isread;
{
    return (kc_blkio(dev, (int)(dblk >> 16), (int)dblk, probebuf, isread));
}


/* ---- THE ALLOCATOR PROBE (UFS 1.10b) -----------------------------------
 *
 * A FUNCTION RATHER THAN A BLOCK INSIDE vfs_probe, and not for tidiness: its
 * caller must put the superblock back whatever happens here, so every failure
 * has to return rather than escape.
 *
 * WHERE THE EXPECTED NUMBERS COME FROM.  Every constant below was read off
 * disk/ufsscratch.po with `tools/fgxfs.py` on the host -- an independent
 * implementation of the same allocator, which is the entire reason 1.10 was
 * done before 1.8.  The block sequence 70, 72, 74 ... is not arbitrary and not
 * this code's opinion of itself: it is the INTERLEAVED ROTATIONAL PATTERN that
 * `mkfs` built walking the volume backwards with step 2 and cyl 100, and any
 * allocator that pops the cache in the wrong direction produces a different
 * sequence immediately.
 *
 * THE CASE THAT CARRIES THE WEIGHT IS THE REFILL, and it is worth saying why
 * the twenty-nine pops before it are not padding.  The superblock caches
 * exactly 29 addresses on this volume.  The 29th pop empties the cache, and
 * the address it returns -- block 93 -- is the CHAIN BLOCK holding the next
 * fifty.  So the 30th allocation can only return 95 if this code actually
 * read block 93 off the disk and decoded it out of PDP-11 byte order.  There
 * is no way to know 95 otherwise: it is nowhere in the superblock, nowhere in
 * this file, and nowhere in the kernel.  Everything before that case exists to
 * reach it in the state the format demands.
 */
static int
allocprobe(dev, devvp, fsblk)
    int           dev;
    struct vnode *devvp;
    daddr_t       fsblk;
{
    daddr_t bno;
    int     i;
    ino_t   ino;

    /* ---- 7a. THE ENCODE DIRECTION, PINNED BY BYTES ----------------------
     * 1.10a asserts the DECODE against known bytes.  The encode is new at
     * 1.10b and needs the same treatment rather than being trusted as "the
     * obvious inverse" -- a half-swap written backwards round-trips perfectly
     * against its own decoder and produces a volume no PDP-11 can read.  So
     * this checks the BYTES, not a round trip.
     *
     * allocsb is scribbled on here and loaded properly straight after. */
    for (i = 0; i < SB_ONDISK_SIZE; i++)
        sbbogus[i] = (char)0;
    allocsb.sb_volblocks = 0x01020304L;
    allocsb.sb_isize     = 0x1234;
    ufs_sbencode(&allocsb, sbbogus);
    if (sbbogus[SB_VOLBLOCKS + 0] != (char)0x02 ||
        sbbogus[SB_VOLBLOCKS + 1] != (char)0x01 ||
        sbbogus[SB_VOLBLOCKS + 2] != (char)0x04 ||
        sbbogus[SB_VOLBLOCKS + 3] != (char)0x03)
        return (510);
    if (sbbogus[SB_ISIZE + 0] != (char)0x34 ||
        sbbogus[SB_ISIZE + 1] != (char)0x12)
        return (511);

    if (ufs_sbread(devvp, &allocsb, (daddr_t)0) != 0)
        return (512);

    /* ---- 7b. badblock REFUSES, AND REFUSES WITHOUT SIDE EFFECTS ---------
     * An address below sb_isize is inside the i-list; one at or past
     * sb_volblocks is off the end of the disk.  Either accepted onto the free
     * list is eventually handed out as a data block, so the refusal matters
     * more than the message.
     *
     * The counts are re-checked afterwards because a refusal that had already
     * pushed the address, or already bumped tfree, would still return EINVAL
     * and look correct. */
    if (ufs_bfree(devvp, &allocsb, (daddr_t)0) != EINVAL)
        return (513);
    if (ufs_bfree(devvp, &allocsb, (daddr_t)65) != EINVAL)
        return (514);        /* the last i-list block: isize is 66 */
    if (ufs_bfree(devvp, &allocsb, (daddr_t)4096) != EINVAL)
        return (515);        /* one past the end */
    if (allocsb.sb_nfree != 26 || allocsb.sb_tfree != (daddr_t)3725)
        return (516);        /* a refusal moved the counts */

    /* ---- 7c. THE WHOLE ALLOCATION SEQUENCE, AGAINST THE ORACLE'S ------
     *
     * Thirty-three allocations, checked one by one against the addresses
     * tools/fgxfs.py hands out from the same volume.  A TABLE rather than
     * thirty-three inline comparisons, and the reason is the bank: written
     * out, this section cost about 1.8 KB of a module bank with none to
     * spare, where the table costs 66 bytes and a loop.  It also reads far
     * better -- the expected sequence is now something you can look at.
     *
     * WHAT THE SEQUENCE IS.  mkfs built the free list walking the volume
     * BACKWARDS in an interleaved rotational pattern (step 2, cyl 100), so
     * the cache holds it in that order and allocation pops from the top:
     * 70, 72 ... 98, then the pattern restarts at 67 and runs 69, 71 ... 93.
     * An allocator popping the wrong end produces a different sequence on its
     * very first call.
     *
     * INDEX 28 IS THE ONE THAT MATTERS.  It empties the cache, and the
     * address it returns -- 93 -- IS the chain block holding the next fifty.
     * So entries 29 onward (95, 97, 99, 100) can only be right if ufs_balloc
     * read block 93 off the disk and decoded it out of PDP-11 byte order.
     * Those numbers are nowhere in the superblock, nowhere in this file and
     * nowhere in the kernel; the only place they exist is on the platter.
     *
     * ino_t rather than daddr_t for the table because every value fits in
     * sixteen bits and the comparison widens; a long table would be twice the
     * size for no extra reach.
     */
    for (i = 0; i < 33; i++) {
        if (ufs_balloc(devvp, &allocsb, &bno) != 0)
            return (517);
        if (bno != (daddr_t)allocseq[i])
            return (518);

        /* The counts, checked at the three points where they say something
         * distinct: after the first eight (ordinary pops), at the edge of the
         * cache, and immediately after the refill. */
        if (i == 7 && (allocsb.sb_nfree != 18 ||
                       allocsb.sb_tfree != (daddr_t)3717))
            return (519);        /* tfree must follow every allocation */
        if (i == 24 && allocsb.sb_nfree != 1)
            return (520);        /* one address left: the chain block */
        if (i == 25 && allocsb.sb_nfree != NICFREE)
            return (521);        /* the chain block did not refill the cache */
    }

    /* ---- 7f. THE SUPERBLOCK REACHED THE DISK ----------------------------
     * ufs_balloc writes it back during the refill, and 2.11BSD's comment says
     * why: blocks have already been handed out of the batch that read
     * replaced, so a free-list head still pointing at the old chain is a list
     * whose front is gone.  Checked with a RAW read -- the oracle is the layer
     * below, as everywhere else in this file, because bread would answer out
     * of the cache and prove nothing about what is on the platter.
     *
     * Filesystem block 1 is device block 2.  The count is a 16-bit field, so
     * it overlays this machine directly.
     *
     * THE DISK SAYS 50 AND THE IN-CORE COPY SAYS 43, AND THAT IS THE CORRECT
     * ANSWER rather than a rounding of it.  The write happens inside the
     * refill arm, with the cache just refilled; the seven allocations after it
     * came straight off the cache and touched no disk.  So the on-disk head
     * legitimately lags, which is what sb_fmod records.  Asserting 46 here
     * would demand a write per allocation and go red against correct code. */
    if (rawio(dev, (daddr_t)2, PROBE_READ) != 0)
        return (531);
    if (probebuf[SB_NFREE] != (char)NICFREE || probebuf[SB_NFREE + 1] != (char)0)
        return (532);

    /* ---- 7g. THE SPILL, AND ITS BYTES ON THE PLATTER ---------------------
     * Freeing with a full cache turns the block being freed into the container
     * for the current fifty.  Set the cache up by hand rather than freeing
     * fifty real blocks: the state is what is under test, not the route to it.
     *
     * THE TARGET IS THE CALLER'S SCRATCH BLOCK, not a literal.  vfs.s picks a
     * filesystem block well past the metadata and hands it to both probes for
     * exactly this purpose; writing a chain block there leaves the volume's
     * own chain untouched.  Taking it as a parameter is also what stops this
     * case quietly addressing a block the caller did not sanction. */
    allocsb.sb_nfree = NICFREE;
    for (i = 0; i < NICFREE; i++)
        allocsb.sb_free[i] = (daddr_t)(200 + i);
    if (ufs_bfree(devvp, &allocsb, fsblk) != 0)
        return (533);
    if (allocsb.sb_nfree != 1 || allocsb.sb_free[0] != fsblk)
        return (534);        /* the spill must reset the cache to hold it */

    if (rawio(dev, fsblk * (daddr_t)2, PROBE_READ) != 0)
        return (535);
    if (probebuf[FBLK_NFREE] != (char)NICFREE ||
        probebuf[FBLK_NFREE + 1] != (char)0)
        return (536);
    /* Entry 49 is 249 == 0x000000F9.  High word FIRST, little-endian within
     * each word: 00 00 F9 00.  A little-endian long would be F9 00 00 00 and a
     * big-endian one 00 00 00 F9, so both are caught here. */
    if (probebuf[FBLK_FREE + 4 * 49 + 0] != (char)0x00 ||
        probebuf[FBLK_FREE + 4 * 49 + 1] != (char)0x00 ||
        probebuf[FBLK_FREE + 4 * 49 + 2] != (char)0xF9 ||
        probebuf[FBLK_FREE + 4 * 49 + 3] != (char)0x00)
        return (537);

    /* ---- 7h. THE ROUND TRIP THROUGH THE PLATTER --------------------------
     * Allocate again: the cache holds one address, the block just spilled
     * onto, so this pops it and
     * refills from the block just written.  The addresses come back through
     * ufs_fblkencode, a disk write, a disk read and ufs_fblkdecode -- the two
     * halves are separate code and only agree here if both are right. */
    if (ufs_balloc(devvp, &allocsb, &bno) != 0 || bno != fsblk)
        return (538);
    if (allocsb.sb_nfree != NICFREE)
        return (539);
    if (ufs_balloc(devvp, &allocsb, &bno) != 0 || bno != (daddr_t)249)
        return (540);
    if (ufs_balloc(devvp, &allocsb, &bno) != 0 || bno != (daddr_t)248)
        return (541);

    /* ---- 7i. ialloc HAS TO SCAN, BECAUSE mkfs LEAVES THE CACHE EMPTY -----
     * fs_ninode is 0 on a fresh volume -- mkfs never fills it, and says so in
     * tools/fgxfs.py's ialloc.  So the very first inode allocation walks the
     * i-list, and the numbers below are that walk's result.
     *
     * 103 IS THE FIRST INODE HANDED OUT, WHICH LOOKS WRONG AND IS NOT.  The
     * scan fills the cache ASCENDING from inode 4 (1, 2 and 3 are taken: the
     * bad-block hack, the root, and lost+found) and stops at 100 entries, so
     * the cache holds 4..103.  ialloc pops from the TOP.  An implementation
     * that handed out 4 would be popping the wrong end and would still look
     * entirely reasonable. */
    if (ufs_ialloc(devvp, &allocsb, &ino) != 0)
        return (542);
    if (ino != (ino_t)104)
        return (543);
    if (allocsb.sb_ninode != NICINOD - 1)
        return (544);
    if (allocsb.sb_tinode != 1019)
        return (545);
    /* Where the scan stopped: the first inode of the last block it read.  It
     * is what makes the NEXT scan circular rather than starting over. */
    if (allocsb.sb_lasti != (ino_t)97)
        return (546);
    if (ufs_ialloc(devvp, &allocsb, &ino) != 0 || ino != (ino_t)103)
        return (547);
    if (ufs_ialloc(devvp, &allocsb, &ino) != 0 || ino != (ino_t)102)
        return (548);

    /* ---- 7j. ifree, INCLUDING THE TWO ARMS THAT THROW THE NUMBER AWAY ----
     * An inode handed back goes on the cache and comes straight back out. */
    ufs_ifree(&allocsb, (ino_t)500);
    if (allocsb.sb_tinode != 1018)
        return (549);
    if (ufs_ialloc(devvp, &allocsb, &ino) != 0 || ino != (ino_t)500)
        return (550);

    /* A scan in progress: the number is DROPPED and only the count moves.
     * Dropping it is correct -- the inode is still free on disk and the next
     * scan finds it -- but losing the count would leak it forever. */
    allocsb.sb_ilock = 1;
    i = allocsb.sb_ninode;
    ufs_ifree(&allocsb, (ino_t)501);
    if (allocsb.sb_ninode != i)
        return (551);
    if (allocsb.sb_tinode != 1018)
        return (552);
    allocsb.sb_ilock = 0;

    /* A full cache: dropped again, and if the number is BELOW the scan's
     * restart point it is counted as one the next circular scan will miss.
     * Enough of those send the scan back to the top. */
    allocsb.sb_ninode = NICINOD;
    allocsb.sb_lasti  = (ino_t)97;
    allocsb.sb_nbehind = 0;
    ufs_ifree(&allocsb, (ino_t)5);
    if (allocsb.sb_nbehind != (ino_t)1)
        return (553);
    if (allocsb.sb_ninode != NICINOD)
        return (554);
    /* ...and one ABOVE it is not counted: the next scan reaches it anyway. */
    ufs_ifree(&allocsb, (ino_t)900);
    if (allocsb.sb_nbehind != (ino_t)1)
        return (555);

    /* ---- 7k. THE REFUSALS, LAST, BECAUSE THEY POISON THE COUNTS ----------
     * ufs_balloc zeroes both counts on the way out so the next call fails at
     * once instead of re-walking a list already known to be bad.  That makes
     * every arm here destructive to the in-core copy, which is why they run
     * after everything else. */
    allocsb.sb_nfree = 0;
    if (ufs_balloc(devvp, &allocsb, &bno) != ENOSPC)
        return (556);
    if (allocsb.sb_tfree != (daddr_t)0)
        return (557);

    /* A count larger than the array it indexes -- upstream's "bad free count".
     * Refused BEFORE the subscript, which is the only place refusing helps. */
    allocsb.sb_nfree = NICFREE + 1;
    if (ufs_balloc(devvp, &allocsb, &bno) != ENOSPC)
        return (558);

    /* The terminator.  mkfs writes a zero at the bottom of the chain, and
     * reaching it means the volume is genuinely full rather than corrupt. */
    allocsb.sb_nfree = 1;
    allocsb.sb_free[0] = (daddr_t)0;
    if (ufs_balloc(devvp, &allocsb, &bno) != ENOSPC)
        return (559);

    /* And ialloc's: an empty cache with no i-list left to scan. */
    allocsb.sb_ninode = 0;
    allocsb.sb_isize  = 2;
    allocsb.sb_nbehind = 0;
    if (ufs_ialloc(devvp, &allocsb, &ino) != ENOSPC)
        return (560);

    /* ---- 7h. THE SUPERBLOCK CARRIES A TIMESTAMP (apple/fgx#167 proper) ---
     *
     * 2.11BSD's balloc stamps fs_time beside the fs_fmod clear
     * (usr/sys/sys/ufs_alloc.c:78-79) and this port did the first line only.
     * The refill in 7c is the path that calls ufs_sbupdate, so allocsb's
     * in-core copy has been through it by the time this runs.  The ENOSPC
     * cases above wreck sb_nfree and sb_isize deliberately and leave sb_time
     * alone, which is why this can sit at the end.
     *
     * IT MOVED HERE FROM readguard AT 1.12a, when the probe was split across
     * two gates.  It asserts on allocsb, which only this function drives; over
     * in ufs_vnprobe.c that precondition would be in a file the build does not
     * contain, and a case that cannot be reached honestly is worse than no
     * case.  It describes the ALLOCATOR in any event.
     *
     * ZERO IS THE DISCRIMINATING START.  disk/ufsscratch.po is built by
     * `fgxfs mkfs` with sb_time 0 -- deliberately, so the artifact is
     * byte-identical between builds and ninja can prune it -- so a stamped
     * superblock cannot be confused with the volume's own value.  That is the
     * one thing this test needed and got for free.
     *
     * A CLOCK THAT CANNOT BE READ SKIPS IT, because kern_time returns 0 for an
     * unset or impossible RTC and ufs_sbupdate then leaves the stamp alone
     * rather than dating the volume to 1970.  1577836800 is 2020-01-01: any
     * real clock is past it and a half-written long is not.
     */
    if (kern_time() != 0L) {
        if (allocsb.sb_time == 0L)
            return (815);
        if (allocsb.sb_time < 1577836800L)
            return (816);
    }

    return (0);
}

int
ufs_probe(dev, fsblk)
    int     dev;
    daddr_t fsblk;
{
    struct vnode *devvp;
    struct buf   *bp;
    int           rc;

    /* ---- IDENTIFY THE VOLUME BEFORE WRITING A SINGLE BYTE ---------------
     *
     * The same check vfs_probe makes, and made for the same reason rather than
     * copied for symmetry: this file writes too, and a device index is not
     * proof of which image answers.  An uninitialised device table reads as an
     * online disk, and the emulator is free to map an attached image somewhere
     * other than where the numbering suggests -- both happened, and the
     * earlier version wrote to whatever answered at index 1.
     *
     * The bytes are the superblock's leading fields: sb_isize 0x0042 (66) and
     * the low word of sb_volblocks 0x1000 (4096).  A volume that does not
     * identify is left completely alone.
     */
    if (rawio(dev, (daddr_t)2, PROBE_READ) != 0)
        return (60);            /* cannot even read the candidate */
    if (probebuf[0] != (char)0x42 || probebuf[1] != (char)0x00 ||
        probebuf[4] != (char)0x00 || probebuf[5] != (char)0x10)
        return (61);            /* NOT the scratch volume -- nothing written */

    /* The device vnode.  Every read below goes through VOP_STRATEGY on a vnode
     * whose ops vector came from specfs, so a vector that did not resolve or a
     * device number that did not survive checkalias fails here, on the boot
     * path, against a real disk -- a context the fcc fixtures cannot reach at
     * all (apple/fgx#88). */
    if (bdevvp(dev, &devvp) != 0)
        return (62);

    /* ---- 6. THE SUPERBLOCK OF A REAL FILESYSTEM (UFS 1.10a) -------------
     *
     * These cases read the superblock the volume actually carries and check it
     * against the numbers an INDEPENDENT IMPLEMENTATION put there -- see this
     * file's header on why that, rather than internal consistency, is what
     * makes a green here mean anything.
     *
     * THE CONSTANTS BELOW ARE THAT TOOL'S OUTPUT, not this code's expectation
     * of itself -- read back with `fgxfs` on the host and transcribed.  If the
     * volume is ever rebuilt with different parameters they change together,
     * and a mismatch here means the two implementations disagree about the
     * format, which is precisely the claim goal 2 of the campaign rests on.
     *
     * THE CASE NUMBERS MOVED TO 400+ AT 1.10b, AND THEY HAD TO -- the split
     * into this file came after and does not make it moot, because 60 and 61
     * are still the volume-identification codes above.  1.10a numbered this
     * section 40-60 while it lived in vfs_probe.c, colliding with three codes
     * already in use there: 51 and 52 were the RAW write and read failures,
     * and 60 "cannot read the candidate volume".  The probe contract is that a
     * code names ONE failing property -- the whole reason these are codes and
     * not a boolean -- and for one release three of them named two.  A red
     * reporting 52 would have sent the next person to the raw block path when
     * the validator was what refused.  Codes print whole as a 16-bit decimal
     * (vfs.s), so the range costs nothing.
     */
    {
        int j;

        if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
            return (400);
        if (probesb.sb_volblocks != (daddr_t)4096)
            return (401);
        if (probesb.sb_isize != 66)
            return (402);
        if (probesb.sb_nfree != 26)
            return (403);
        if (probesb.sb_ninode != 0)
            return (404);
        if (probesb.sb_tfree != (daddr_t)3725)
            return (405);
        if (probesb.sb_tinode != 1020)
            return (406);
        if (probesb.sb_step != 2 || probesb.sb_cyl != 100)
            return (407);

        /* sb_time IS ZERO ON THIS VOLUME, ON PURPOSE.  `fgxfs mkfs` defaults
         * mtime to 0 and build.ninja passes no timestamp, so the artifact is
         * byte-identical every build -- which is what lets ninja prune it and
         * the gate's staleness checks mean anything.  Asserted exactly rather
         * than loosely, because "a plausible timestamp" was the first version
         * of this line and it went red: the probe was right and the
         * expectation was wrong. */
        if (probesb.sb_time != 0L)
            return (408);

    }

    /* ---- 7. THE ALLOCATORS (UFS 1.10b) ---------------------------------
     *
     * IT MUTATES THE VOLUME, WHICH NOTHING ABOVE THIS POINT DOES.  The cases
     * above only read.  These hand out real blocks off the volume's free list
     * and let ufs_balloc write the superblock back.
     *
     * A SUPERBLOCK LEFT MODIFIED WOULD NOT JUST FAIL THE NEXT BOOT, IT WOULD
     * KEEP FAILING.  Case 403 asserts sb_nfree == 29; disk/ufsscratch.po is
     * handed to MAME by path with no per-run copy (run.py's extra_hards); and
     * ninja will not rebuild an output that is newer than its inputs, which a
     * volume the probe just wrote to certainly is.  So the restore below is
     * not tidiness -- without it a single run poisons the image until someone
     * deletes it by hand.
     *
     * THE RESTORE IS probesb, AND THAT IS WHY THE VALIDATOR CASES MOVED BELOW
     * THIS ONE.  They wreck probesb deliberately -- the last of them decodes
     * an all-zero block into it -- so while they ran first, putting the
     * superblock back meant keeping a verbatim 1024-byte copy of the block.
     * Reordering makes probesb itself the pristine copy and costs nothing:
     * every write to that block goes through ufs_sbupdate, which is
     * read-modify-write, so the bytes this port does not decode were never
     * disturbed and do not need restoring.  The kilobyte it saves is the
     * difference between this file fitting its bank and not.
     *
     * ON FAILURE TOO, which is the whole reason allocprobe is a function
     * rather than a block: a case that returns early still has to leave the
     * volume as it found it.
     */
    {
        rc = allocprobe(dev, devvp, fsblk);
        if (ufs_sbupdate(devvp, &probesb) != 0)
            return (501);
        if (rc != 0)
            return (rc);
    }

    /* ---- 9. bmap: LOGICAL BLOCK TO PHYSICAL BLOCK (UFS 1.10c) ----------
     *
     * THE VOLUME CARRIES A REAL MULTI-LEVEL FILE FOR THIS.  build.ninja's
     * ufsscratch rule runs `fgxfs mkfile /big --blocks 300` after mkfs, so the
     * scratch volume holds a 300-block file whose blocks reach through the
     * direct addresses, a single indirect block and into a double indirect --
     * built by the other implementation, which is what makes the numbers below
     * evidence rather than this code's opinion of itself.
     *
     * 300 blocks is chosen, not arbitrary: 4 direct + 256 single indirect gets
     * to logical block 259, so 300 is the smallest round size that reaches the
     * DOUBLE indirect and exercises a two-level walk.
     */
    {
        static daddr_t bmaddr[NADDR];
        daddr_t        got;
        int            k;

        /* Inode 4 is /big.  itod(4) is block 2 and itoo(4) is slot 3, so its
         * dinode starts at 3 * 64 and di_addr twelve bytes into that -- the
         * offset pinned by toolchain/tests/M37/pdplayout.c against a live
         * PDP-11.  There is no iget until 1.11, so the probe reads the raw
         * i-list block and decodes the seven addresses itself, which is
         * exactly the array 1.11 will hand ufs_bmap from a decoded inode. */
        if (bread(devvp, (daddr_t)2, &bp) != 0) {
            brelse(bp);
            return (600);
        }
        for (k = 0; k < NADDR; k++)
            bmaddr[k] = ufs_dget32(bp->b_addr, 3 * UFS_DINODESIZE + 12 + 4 * k);
        brelse(bp);

        /* What mkfile built: four direct, a single indirect at 78, a double at
         * 358, and no triple.  A wrong dinode offset shows up here rather than
         * as a wrong block number three cases later. */
        if (bmaddr[0] != (daddr_t)70 || bmaddr[1] != (daddr_t)72 ||
            bmaddr[2] != (daddr_t)74 || bmaddr[3] != (daddr_t)76)
            return (601);
        if (bmaddr[4] != (daddr_t)78 || bmaddr[5] != (daddr_t)358 ||
            bmaddr[6] != (daddr_t)0)
            return (602);

        /* 9a. THE DIRECT BLOCKS, which cost no disk read at all. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)0, &got) != 0 || got != (daddr_t)70)
            return (603);
        if (ufs_bmap(devvp, bmaddr, (daddr_t)3, &got) != 0 || got != (daddr_t)76)
            return (604);

        /* 9b. THE SINGLE INDIRECT.  Logical block 4 is the first address that
         * is not in the inode: answering it means reading block 78 off the
         * disk and decoding entry 0 out of PDP-11 byte order.  80 appears
         * nowhere in the inode and nowhere in this file's inputs. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)4, &got) != 0 || got != (daddr_t)80)
            return (605);
        if (ufs_bmap(devvp, bmaddr, (daddr_t)5, &got) != 0 || got != (daddr_t)82)
            return (606);
        /* ...and its LAST entry, index 255, which is where an off-by-one in
         * the mask or the shift stops being invisible. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)259, &got) != 0 || got != (daddr_t)356)
            return (607);

        /* 9c. THE DOUBLE INDIRECT, two reads deep.  Logical block 260 is the
         * first one past the single indirect's reach, so getting here at all
         * means the level arithmetic subtracted 256 and moved to addr[5]. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)260, &got) != 0 || got != (daddr_t)362)
            return (608);
        if (ufs_bmap(devvp, bmaddr, (daddr_t)261, &got) != 0 || got != (daddr_t)364)
            return (609);
        if (ufs_bmap(devvp, bmaddr, (daddr_t)299, &got) != 0 || got != (daddr_t)341)
            return (610);

        /* 9d. PAST THE END OF THE FILE IS A HOLE, NOT AN ERROR, and -1 is how
         * Reno says so.  THE ORACLE DISAGREES WITH THE KERNEL HERE ON PURPOSE:
         * tools/fgxfs.py's bmap returns 0 for an unallocated block, because a
         * host tool has no caller that needs to tell a hole from block zero.
         * 2.11BSD overloads its single return the same way -- 0 for an error,
         * -1 for a hole -- and Reno splits them, which is the contract this
         * port took.  Asserted explicitly so the divergence is a decision on
         * the record rather than something discovered at 1.11. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)300, &got) != 0)
            return (611);
        if (got != (daddr_t)-1)
            return (612);

        /* 9e. THE REFUSALS.  A negative block, and one past everything three
         * levels of indirection can address: 4 + 256 + 65536 + 16777216 means
         * 16843011 is the last block a 2.11BSD file can have. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)-1, &got) != EFBIG)
            return (613);
        if (ufs_bmap(devvp, bmaddr, (daddr_t)16843012L, &got) != EFBIG)
            return (614);
        /* ...and the last VALID one is not refused.  addr[6] is zero on this
         * file, so it reports a hole rather than reading anything -- which is
         * the point: the boundary is in the arithmetic, not on the disk. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)16843011L, &got) != 0)
            return (615);
        if (got != (daddr_t)-1)
            return (616);

        /* ---- 9f. THE TRIPLE INDIRECT, SYNTHESISED --------------------------
         *
         * NO FILE ON THIS VOLUME CAN REACH IT.  The triple indirect starts at
         * logical block 65796, which is a 64 MB file on a 4 MB disk.  So the
         * chain is built by hand in three blocks the probe owns, and the walk
         * is asked to follow it.
         *
         * WITHOUT THIS, LEVEL 3 IS UNTESTED -- and the level arithmetic is the
         * part of bmap most likely to be wrong, because every level looks like
         * the one above it.  The indices are deliberately DIFFERENT at each
         * level (1, then 2, then 3) so that a walk which used the wrong shift,
         * or read the levels in the wrong order, lands on a zero entry and
         * reports a hole rather than accidentally agreeing.  MUTATION-VERIFIED:
         * zeroing the MIDDLE level's entry turns this red with case 624, so
         * the walk genuinely reads all three blocks.
         *
         * Logical block 131847: subtract 4 direct, 256 single and 65536
         * double, leaving 66051 = 1 * 65536 + 2 * 256 + 3.
         *
         * THE BYTES ARE WRITTEN BY HAND, NOT WITH ufs_sbencode.  Building the
         * fixture with the encoder that shares its byte order with the decoder
         * under test would let one consistent mistake pass both ways.  These
         * are the PDP-11 bytes for a small long, spelled out: high word first
         * and zero, then the low word little-endian.
         */
        for (k = 0; k < DEV_BLKSIZE; k++)
            probebuf[k] = (char)0;

        /* Level 1 at block 1010, entry 1 -> 1011. */
        probebuf[4 * 1 + 2] = (char)(1011 & 0xFF);
        probebuf[4 * 1 + 3] = (char)((1011 >> 8) & 0xFF);
        if (rawio(dev, (daddr_t)2020, PROBE_WRITE) != 0)
            return (617);
        probebuf[4 * 1 + 2] = (char)0;
        probebuf[4 * 1 + 3] = (char)0;

        /* Level 2 at block 1011, entry 2 -> 1012. */
        probebuf[4 * 2 + 2] = (char)(1012 & 0xFF);
        probebuf[4 * 2 + 3] = (char)((1012 >> 8) & 0xFF);
        if (rawio(dev, (daddr_t)2022, PROBE_WRITE) != 0)
            return (618);
        probebuf[4 * 2 + 2] = (char)0;
        probebuf[4 * 2 + 3] = (char)0;

        /* Level 3 at block 1012, entry 3 -> 1013, the data block. */
        probebuf[4 * 3 + 2] = (char)(1013 & 0xFF);
        probebuf[4 * 3 + 3] = (char)((1013 >> 8) & 0xFF);
        if (rawio(dev, (daddr_t)2024, PROBE_WRITE) != 0)
            return (619);
        probebuf[4 * 3 + 2] = (char)0;
        probebuf[4 * 3 + 3] = (char)0;

        /* The SECOND half of each block, so entries 128..255 read as zero
         * rather than as whatever was on the platter.  A wrong index should
         * report a hole, not a number. */
        if (rawio(dev, (daddr_t)2021, PROBE_WRITE) != 0)
            return (620);
        if (rawio(dev, (daddr_t)2023, PROBE_WRITE) != 0)
            return (621);
        if (rawio(dev, (daddr_t)2025, PROBE_WRITE) != 0)
            return (622);

        /* THE BLOCKS ARE fsblk+10..+13 AND NOT fsblk ITSELF, AND THAT COST A
         * DEBUGGING SESSION.  The first version built the chain on block 1000
         * -- the block section 7g spills a chain block onto -- and ufs_bmap
         * returned EIO.
         *
         * THE RAW WRITES ABOVE GO UNDERNEATH THE BUFFER CACHE AND DO NOT
         * INVALIDATE IT.  7g wrote block 1000 THROUGH the cache, so a buffer
         * for it was still resident; bread handed that back instead of the
         * zeros on the platter, the walk read entry 1 of a fifty-entry free
         * list, and followed it into whatever that block held until an address
         * landed off the volume.  MEASURED, not deduced: a temporary case read
         * block 1000 back after the raw writes and found nfree = 50 sitting in
         * the first two bytes, which is the chain block and not this section's
         * work.
         *
         * So these blocks are ones nothing else in this probe has touched.
         * That is the whole fix, and it is better than invalidating the buffer
         * would have been -- the point of the raw writes is to put bytes on the
         * platter that the code under test must go and fetch, and a probe that
         * has to defeat the cache to do it is a probe testing the cache. */
        bmaddr[6] = (daddr_t)1010;
        if (ufs_bmap(devvp, bmaddr, (daddr_t)131847L, &got) != 0)
            return (623);
        if (got != (daddr_t)1013)
            return (624);

        /* And one index off in the deepest level is a hole, which proves the
         * three entries above were found by ARITHMETIC and not by landing on
         * the only non-zero word in the block. */
        if (ufs_bmap(devvp, bmaddr, (daddr_t)131848L, &got) != 0)
            return (625);
        if (got != (daddr_t)-1)
            return (626);
        bmaddr[6] = (daddr_t)0;
    }

    /* ---- 8. THE BYTE-LEVEL CODEC TESTS AND THE VALIDATOR'S REFUSALS -----
     *
     * LAST, AND THE ORDER IS LOAD-BEARING RATHER THAN NARRATIVE.  Everything
     * here works by WRECKING probesb -- feeding it bytes that are not a
     * superblock, then setting fields to values a filesystem cannot have --
     * and section 7 needs probesb intact to put the volume back with.  While
     * these ran first, the restore had to keep a verbatim 1024-byte copy of
     * the superblock block; moving them here deleted that buffer.
     *
     * None of it touches the disk.  The validator's rejection paths are all
     * reachable from a structure this file fills in, which is what makes them
     * testable at all -- a validator whose failure arms need a corrupt volume
     * to reach is a validator nobody has run.
     */
    {
        int j;

        /* THE HALF-SWAP IS ALSO TESTED DIRECTLY, and the reason is narrower
         * than it first looks.  An earlier version of this comment claimed the
         * volume could not test byte order at all, because every long on it --
         * volblocks 4096, tfree 3725, time 0 -- has a zero high word.  That
         * reasoning is WRONG and the mutation proved it: a zero high word
         * means a swap moves the NON-zero low word up, so 4096 becomes
         * 0x10000000 and case 401 fires.  Only a long whose halves are EQUAL
         * survives a swap, which on this volume is sb_time alone.
         *
         * What the volume genuinely cannot do is pin the ENCODING -- it
         * detects one wrong variant, not which right one is meant.  So the
         * exact bytes are asserted here: the
         * on-disk bytes 02 01 04 03 are the PDP-11 encoding of 0x01020304
         * (high word first, little-endian within each word), measured on the
         * real machine.  A decoder that read it as one little-endian long
         * gives 0x03040102; one that read it big-endian gives 0x02010403.
         * Both are caught. */
        for (j = 0; j < SB_ONDISK_SIZE; j++)
            sbbogus[j] = (char)0;
        sbbogus[SB_VOLBLOCKS + 0] = (char)0x02;
        sbbogus[SB_VOLBLOCKS + 1] = (char)0x01;
        sbbogus[SB_VOLBLOCKS + 2] = (char)0x04;
        sbbogus[SB_VOLBLOCKS + 3] = (char)0x03;
        sbbogus[SB_ISIZE + 0]     = (char)0x34;
        sbbogus[SB_ISIZE + 1]     = (char)0x12;
        ufs_sbdecode(sbbogus, &probesb);
        if (probesb.sb_volblocks != 0x01020304L)
            return (418);
        if (probesb.sb_isize != 0x1234)
            return (419);
        /* A TRIPWIRE, NOT A TEST OF THIS CODE, and labelled as one so nobody
         * counts it as coverage.  fcc's char is UNSIGNED -- `v = b[0]` with
         * 0x80 emits `AND #$00FF` and yields 128 -- so the decoder's unsigned
         * casts are no-ops and dropping one does NOT break the decode, which
         * was mutation-tested and confirmed: the arm stayed green.  This case
         * fires only if fcc's char ever becomes signed, which would silently
         * poison every high byte read here. */
        sbbogus[SB_VOLBLOCKS + 0] = (char)0x80;
        sbbogus[SB_VOLBLOCKS + 1] = (char)0x00;
        sbbogus[SB_VOLBLOCKS + 2] = (char)0x00;
        sbbogus[SB_VOLBLOCKS + 3] = (char)0x80;
        ufs_sbdecode(sbbogus, &probesb);
        if (probesb.sb_volblocks != 0x00808000L)
            return (420);

        /* Re-read the real superblock: the cases below need it back.  Its own
         * code rather than 400's, because the first read having worked and the
         * second having failed is a completely different story from the volume
         * being unreadable -- it would mean the decode cases in between
         * corrupted something. */
        if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
            return (421);

        /* ---- the validator's refusals, which have no volume to corrupt ----
         * Pure computation over a structure this probe fills in, so every
         * rejection path is reachable without writing a bad superblock to a
         * disk.  A validator whose failure arms are unreachable is a validator
         * nobody has run. */
        if (!ufs_sbvalid(&probesb, (daddr_t)0))
            return (409);
        if (!ufs_sbvalid(&probesb, (daddr_t)4096))
            return (410);         /* the device's real size: must still pass */
        if (ufs_sbvalid(&probesb, (daddr_t)100))
            return (411);         /* ...but not a device smaller than it claims */

        j = probesb.sb_isize;
        probesb.sb_isize = 2;
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (412);         /* an i-list ending at the superblock */
        probesb.sb_isize = 5000;
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (413);         /* ...or running past the volume */
        probesb.sb_isize = (unsigned short)j;

        probesb.sb_nfree = NICFREE + 1;
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (414);         /* more cached blocks than the cache holds */
        probesb.sb_nfree = 26;
        probesb.sb_ninode = NICINOD + 1;
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (415);
        probesb.sb_ninode = 0;

        probesb.sb_tfree = (daddr_t)9999;
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (416);         /* more free blocks than blocks */
        probesb.sb_tfree = (daddr_t)3725;

        /* AN ALL-ZERO BLOCK IS NOT A FILESYSTEM, which is the case that
         * matters most: an unformatted or wrong-slot device reads as zeros,
         * and a validator that accepted them would mount anything. */
        for (j = 0; j < SB_ONDISK_SIZE; j++)
            sbbogus[j] = (char)0;
        ufs_sbdecode(sbbogus, &probesb);
        if (ufs_sbvalid(&probesb, (daddr_t)0))
            return (417);
    }

    vrele(devvp);
    return (0);
}
