/* FGX-Origin: original -- FGX code.  It CITES 2.11BSD's on-disk layout (which
 * ufs_fs.h registers) but contains none of the Regents' code; registering it
 * would assert their copyright over work they did not write.
 */
/* ufs_sb.c -- the 2.11BSD superblock, as BYTES.  UFS 1.11a.
 *
 * Decode, encode, validate.  Nothing here touches a device, a buffer, a vnode
 * or a mount: hand it a block of bytes and it tells you what the PDP-11 meant
 * by them.  That is the whole selection rule for what lives in this file.
 *
 * SPLIT OUT OF ufs_vfsops.c, AND THE REASON IS A TEST RATHER THAN TIDINESS.
 * toolchain/tests/M37/ufssb.c #includes a translation unit to exercise ONE
 * decoder against a superblock lifted off a real 2.11BSD volume -- there is no
 * other way to get host-side coverage of a format this port has to agree with.
 * While the decoder shared a file with the mount, every function added
 * anywhere in that file became a stub in the fixture and a 3,000-line golden
 * regeneration: bwrite at 1.10b, vrele at 1.8a, then iget and ufs_ihashinit at
 * 1.11a, four times in three deliverables.  ufs_vfsops.c's own note said the
 * fix "when it next bites" was this split.  It bit.
 *
 * The fixture now includes this file and needs no stubs at all, because
 * nothing here has an outward call.  That property is the point -- keep it,
 * and anything that wants a buffer belongs on the other side of the cut.
 *
 * WHY THE FORMAT IS 2.11BSD's AND THE ARCHITECTURE AROUND IT IS RENO's is
 * argued in ufs_fs.h, along with the field-name firewall every name here
 * obeys.  The on-disk offsets are that header's SB_*, and tools/fgxfs.py reads
 * the same numbers from the other side -- two implementations agreeing about a
 * format is the claim goal 2 of the campaign rests on.
 *
 * THERE IS NO UPSTREAM COUNTERPART TO THIS FILE, and that is worth stating
 * because it looks like there should be.  2.11BSD needs no decoder: its in-core
 * `struct fs` IS the disk bytes, so `getfs` (usr/sys/sys/ufs_subr.c:129) just
 * returns `&mp->m_filsys`.  Everything here exists because this machine's byte
 * order is not the PDP-11's.
 *
 * ufs_sbvalid DIVERGES DELIBERATELY, and it is the same function's two lines
 * that show it.  Upstream's only superblock sanity check is
 *
 *     if (fs->fs_nfree > NICFREE || fs->fs_ninode > NICINOD) {
 *             fserr(fs, "bad count");
 *             fs->fs_nfree = fs->fs_ninode = 0;
 *     }
 *
 * -- it REPAIRS a bad count on an already-mounted filesystem.  This refuses,
 * before the mount, because the campaign's refusal point is the mount and a bad
 * sb_isize is a number that later becomes a block address to WRITE.  Upstream's
 * clamp is still the right answer for the case it handles; it is just a
 * different question.
 */

#include "fsparam.h"
#include "ufs_fs.h"


/* PDP-11 32-BIT DECODE: high word first, little-endian within each word.
 *
 * 0x01020304 is stored as the bytes 02 01 04 03.  MEASURED on the real machine
 * (kernel #18, 2026-08-09) rather than inferred from a header, which matters
 * because getting it backwards produces values that are the right magnitude
 * and wrong -- a volume size of 4,096 read as 268,435,456, say, which looks
 * like a plausible disk rather than like an error.
 *
 * THE unsigned char CASTS ARE BELT AND BRACES, NOT A FIX -- fcc's char is
 * already UNSIGNED.  Measured, not assumed: `v = b[0]` with b[0] = 0x80 emits
 * `LDA: b,X / AND #$00FF` and yields 128, never -128.  The casts stay because
 * this is a byte-order decoder and every widening in it should say what it
 * means at the site rather than depend on a compiler-wide property, and
 * because C does not require char to be unsigned -- but nothing here is
 * DEFENDING against sign extension today, and a comment claiming otherwise
 * would be describing a hazard this compiler does not have. */
static long
sb_u32(b, off)
char *b;
int off;
{
    long hi;
    long lo;

    hi = (long)(((unsigned char)b[off]) | (((unsigned char)b[off + 1]) << 8));
    lo = (long)(((unsigned char)b[off + 2]) | (((unsigned char)b[off + 3]) << 8));
    return ((hi << 16) | lo);
}


/* A 16-bit field overlays a 65816 directly -- same width, same order -- so
 * this is a read rather than a conversion.  It exists so that every on-disk
 * access in this file goes through a named accessor and none reads the buffer
 * as if it were a local structure. */
static int
sb_u16(b, off)
char *b;
int off;
{
    return (((unsigned char)b[off]) | (((unsigned char)b[off + 1]) << 8));
}


/* The stores matching sb_u32/sb_u16, for the write-back path 1.10b needs.
 *
 * Written out rather than derived from the readers because a byte-order
 * routine that is "obviously the inverse" is exactly the one that gets a half
 * backwards: the round trip is what the probe asserts, and it can only assert
 * it if the two directions are independent code. */
static void
sb_p32(b, off, v)
char *b;
int off;
long v;
{
    int hi;
    int lo;

    /* SPLIT ONCE, THEN WORK IN WORDS, AND THE REASON IS CODE SIZE ON THIS
     * TARGET.  The obvious form -- four `(v >> n) & 0xFF` on the long itself
     * -- costs four 32-bit shifts, one of them by 24, and fcc emits those as
     * open-coded shift chains: it measured 455 lines of assembly for four
     * byte stores.  Reducing the long to two ints first leaves one 32-bit
     * shift and three 16-bit ones and cuts it to a fraction of that.
     *
     * This is not micro-optimisation for its own sake.  vfs.mod is one 64 KB
     * bank and the allocators had already pushed the probe build over it. */
    hi = (int)(v >> 16);
    lo = (int)v;
    b[off]     = (char)(hi & 0xFF);
    b[off + 1] = (char)((hi >> 8) & 0xFF);
    b[off + 2] = (char)(lo & 0xFF);
    b[off + 3] = (char)((lo >> 8) & 0xFF);
}


static void
sb_p16(b, off, v)
char *b;
int off;
int v;
{
    b[off]     = (char)(v & 0xFF);
    b[off + 1] = (char)((v >> 8) & 0xFF);
}


/* ufs_sbdecode -- fill an in-core superblock from one on-disk block.
 *
 * Takes the raw block rather than reading it, so the decode can be exercised
 * without a device and so the caller owns the buffer's lifetime. */
void
ufs_sbdecode(b, sb)
char *b;
struct ufs_sb *sb;
{
    int i;

    sb->sb_isize     = (unsigned short)sb_u16(b, SB_ISIZE);
    sb->sb_volblocks = sb_u32(b, SB_VOLBLOCKS);
    sb->sb_nfree     = (short)sb_u16(b, SB_NFREE);
    sb->sb_ninode    = (short)sb_u16(b, SB_NINODE);
    sb->sb_time      = sb_u32(b, SB_TIME);
    sb->sb_tfree     = sb_u32(b, SB_TFREE);
    sb->sb_tinode    = (unsigned short)sb_u16(b, SB_TINODE);
    sb->sb_step      = (short)sb_u16(b, SB_STEP);
    sb->sb_cyl       = (short)sb_u16(b, SB_CYL);
    sb->sb_lasti     = (ino_t)sb_u16(b, SB_LASTI);
    sb->sb_nbehind   = (ino_t)sb_u16(b, SB_NBEHIND);
    sb->sb_flags     = (unsigned short)sb_u16(b, SB_FLAGS);
    sb->sb_ronly     = b[SB_RONLY];
    sb->sb_fmod      = b[SB_FMOD];
    sb->sb_flock     = b[SB_FLOCK];
    sb->sb_ilock     = b[SB_ILOCK];

    /* The cached lists, carried since 1.10b.  Decoded WHOLE rather than up to
     * sb_nfree/sb_ninode: a count is a claim about the array, and decoding
     * only as far as the claim reaches means a corrupt count leaves the tail
     * holding whatever the last volume put there.  ufs_sbvalid bounds the
     * counts, but it runs after this. */
    for (i = 0; i < NICFREE; i++)
        sb->sb_free[i] = sb_u32(b, SB_FREE + 4 * i);
    for (i = 0; i < NICINOD; i++)
        sb->sb_inode[i] = (ino_t)sb_u16(b, SB_INODE + 2 * i);
}


/* ufs_sbencode -- the inverse, over a block that ALREADY HOLDS the superblock.
 *
 * IT UPDATES IN PLACE, AND THAT IS A CORRECTNESS REQUIREMENT RATHER THAN AN
 * OPTIMISATION.  2.11BSD's balloc writes the superblock back with
 *
 *     bp = getblk(ip->i_dev, SUPERB);  ...  *fps = *fs;
 *
 * -- getblk, not bread, because over there the in-core `struct fs` IS the
 * on-disk one and assigning it covers every byte.  Ours is a DECODED subset:
 * it does not carry fs_fsmnt, and a `struct fs` is "actually longer" than the
 * 446 bytes h/fs.h describes.  Encoding our fields into a getblk buffer would
 * therefore write our subset over whatever that buffer last held and destroy
 * the rest of the superblock -- the mount point name first.
 *
 * So the caller must hand this a buffer read from the disk, and the fields we
 * do not carry survive untouched. */
void
ufs_sbencode(sb, b)
struct ufs_sb *sb;
char *b;
{
    int i;

    sb_p16(b, SB_ISIZE, (int)sb->sb_isize);
    sb_p32(b, SB_VOLBLOCKS, sb->sb_volblocks);
    sb_p16(b, SB_NFREE, (int)sb->sb_nfree);
    sb_p16(b, SB_NINODE, (int)sb->sb_ninode);
    sb_p32(b, SB_TIME, sb->sb_time);
    sb_p32(b, SB_TFREE, sb->sb_tfree);
    sb_p16(b, SB_TINODE, (int)sb->sb_tinode);
    sb_p16(b, SB_STEP, (int)sb->sb_step);
    sb_p16(b, SB_CYL, (int)sb->sb_cyl);
    sb_p16(b, SB_LASTI, (int)sb->sb_lasti);
    sb_p16(b, SB_NBEHIND, (int)sb->sb_nbehind);
    sb_p16(b, SB_FLAGS, (int)sb->sb_flags);
    b[SB_RONLY] = sb->sb_ronly;
    b[SB_FMOD]  = sb->sb_fmod;
    b[SB_FLOCK] = sb->sb_flock;
    b[SB_ILOCK] = sb->sb_ilock;

    for (i = 0; i < NICFREE; i++)
        sb_p32(b, SB_FREE + 4 * i, sb->sb_free[i]);
    for (i = 0; i < NICINOD; i++)
        sb_p16(b, SB_INODE + 2 * i, (int)sb->sb_inode[i]);
}


/* ufs_dget32 -- one on-disk daddr_t, decoded.  Exported for ufs_bmap.c.
 *
 * IT LIVES HERE RATHER THAN THERE so the byte order has ONE definition.  bmap
 * needs to read indirect-block entries, which are the same PDP-11 longs as
 * everything else on the volume, and a second half-swap written next to its
 * caller is a second thing to get right and a second thing to forget when the
 * encoding is questioned.  Every on-disk 32-bit read in this port now goes
 * through sb_u32, and this is the public door to it. */
long
ufs_dget32(b, off)
char *b;
int off;
{
    return (sb_u32(b, off));
}


/* ufs_dput32 and ufs_dput16 -- the inverses, and the write path's only door to
 * byte order.  UFS 1.12a.
 *
 * THEY EXIST FOR THE SAME REASON ufs_dget32 DOES, which its comment states: so
 * the half-swap has ONE definition.  1.12a adds two callers that write on-disk
 * longs outside this file -- ufs_bmapx threading a block address into an
 * indirect block, and ufs_iencode writing a dinode back -- and each of them
 * open-coding the store would be a second encoder to keep in step with the
 * decoder above.
 *
 * THE ENCODE DIRECTION CANNOT BE TESTED BY A ROUND TRIP.  A half-swap written
 * backwards round-trips through its own decoder perfectly and produces a
 * volume no PDP-11 can read, which is why the superblock's encode is pinned by
 * BYTES in the probe rather than by reading back what it wrote.  These two go
 * through sb_p32/sb_p16, which are already pinned that way; nothing new is
 * being trusted here, which is the point of routing through them.
 */
void
ufs_dput32(b, off, v)
char *b;
int off;
long v;
{
    sb_p32(b, off, v);
}


void
ufs_dput16(b, off, v)
char *b;
int off;
int v;
{
    sb_p16(b, off, v);
}


/* ufs_dget16 -- one on-disk 16-bit field.  A short overlays this machine
 * directly, so this is a read rather than a conversion; it exists so that
 * ufs_inode.c's decode goes through named accessors for BOTH widths and no
 * reader has to remember which fields needed swapping. */
int
ufs_dget16(b, off)
char *b;
int off;
{
    return (sb_u16(b, off));
}


/* ufs_fblkdecode -- refill the superblock's cached free list from a chain
 * block, and ufs_fblkencode -- spill it into one.  See ufs_fs.h on why the
 * PDP-11's structure-assignment pun is not available here.
 *
 * NOTE WHAT IS NOT BOUNDED.  A chain block's count comes off the disk and can
 * say anything; these two copy the whole NICFREE array either way and let the
 * count travel with it, exactly as 2.11BSD's assignment does.  The caller is
 * where the count is judged -- ufs_balloc refuses an sb_nfree above NICFREE on
 * its next pass, which is 2.11BSD's "bad free count" arm. */
void
ufs_fblkdecode(b, sb)
char *b;
struct ufs_sb *sb;
{
    int i;

    sb->sb_nfree = (short)sb_u16(b, FBLK_NFREE);
    for (i = 0; i < NICFREE; i++)
        sb->sb_free[i] = sb_u32(b, FBLK_FREE + 4 * i);
}


void
ufs_fblkencode(sb, b)
struct ufs_sb *sb;
char *b;
{
    int i;

    sb_p16(b, FBLK_NFREE, (int)sb->sb_nfree);
    for (i = 0; i < NICFREE; i++)
        sb_p32(b, FBLK_FREE + 4 * i, sb->sb_free[i]);
}


/* ufs_sbvalid -- is this a filesystem, or is it eight hundred bytes of luck?
 *
 * A SUPERBLOCK HAS NO MAGIC NUMBER.  2.11BSD's has none and neither did V7's;
 * the format predates the idea.  So "is this a filesystem" cannot be answered
 * by a constant and must be answered by CONSISTENCY -- which is exactly what
 * tools/fgxfs.py's fsck phase 0 does, and these are its checks.  That is not a
 * coincidence to be tidied away later: the host tool and the kernel must agree
 * about what a valid volume is, or one of them will mount what the other calls
 * corrupt.
 *
 * WHY THIS MATTERS MORE HERE THAN IN THE TOOL.  fgxfs runs on a host, against
 * a file, and a wrong answer prints a message.  This runs before anything has
 * been mounted, on a machine with no memory protection, and a bad sb_isize is
 * a number that later becomes a block address to read and eventually to WRITE.
 * Refusing early is the only place refusing is cheap.
 *
 * `volblocks` is the size the DEVICE actually has, from the caller.  Passing 0
 * skips that comparison, which is what a caller does when it cannot know --
 * the check is worth having when it can.
 */
int
ufs_sbvalid(sb, volblocks)
struct ufs_sb *sb;
daddr_t volblocks;
{
    /* The i-list starts at block 2 (block 0 is the boot area, block 1 is this
     * superblock), so a filesystem has at least one i-list block and at least
     * one data block after it.  isize is the first block PAST the i-list, so
     * 2 < isize < volblocks is the whole shape of a volume in one line. */
    if (sb->sb_volblocks < (daddr_t)4)
        return (0);
    if ((daddr_t)sb->sb_isize <= (daddr_t)2)
        return (0);
    if ((daddr_t)sb->sb_isize >= sb->sb_volblocks)
        return (0);

    /* The superblock's cached lists cannot claim more entries than they hold.
     * A count past the end is how a corrupt volume gets a kernel to read an
     * address from beyond the structure it is standing in. */
    if (sb->sb_nfree < 0 || sb->sb_nfree > NICFREE)
        return (0);
    if (sb->sb_ninode < 0 || sb->sb_ninode > NICINOD)
        return (0);

    /* Free space cannot exceed the volume.  fgxfs's fsck makes the same check
     * and reports it as a count mismatch; here it is a refusal, because a
     * tfree larger than the volume means the free list will eventually hand
     * out a block address that is not on the disk. */
    if (sb->sb_tfree > sb->sb_volblocks)
        return (0);

    /* And if the caller knows the device's real size, the superblock must not
     * describe a volume larger than it -- the case fgxfs reports as
     * "superblock says N blocks, image holds M". */
    if (volblocks != (daddr_t)0 && sb->sb_volblocks > volblocks)
        return (0);
    return (1);
}
