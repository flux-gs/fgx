/* FGX-Origin: original -- FGX code.  It CITES 2.11BSD's on-disk inode layout
 * (which inode.h registers) but contains none of the Regents' code.
 */
/* ufs_dinode.c -- the on-disk inode, as BYTES.  UFS 2.1.
 *
 * ufs_idecode and ufs_iencode, moved out of ufs_inode.c.  They obey ufs_sb.c's
 * selection rule exactly -- hand it a block of bytes and it tells you what the
 * PDP-11 meant by them, with no outward call -- and the move is the on-target
 * fsck's doing: src/userland/fsck needs the SAME dinode field list the kernel
 * uses, and the alternative was a second copy of it.  ufs_iencode's comment
 * below states the hazard in its own words ("the two lists must stay
 * identical"), which is an argument for one list rather than for diligence
 * about two.
 *
 * A FILE OF ITS OWN RATHER THAN AN ADDITION TO ufs_sb.c, and ufs_sb.c's header
 * is what says why: toolchain/tests/M37/ufssb.c #includes that translation
 * unit whole, so anything added to it regenerates that fixture's goldens.  Its
 * note records four such regenerations across three deliverables and the split
 * that ended them.  Landing this codec there would have been the fifth.
 */

#include "fsparam.h"
#include "ufs_fs.h"
#include "inode.h"

extern long         ufs_dget32();
extern int          ufs_dget16();
extern void         ufs_dput32();
extern void         ufs_dput16();


/* ufs_idecode -- one on-disk inode into its in-core form.
 *
 * THE LAYOUT IS THE FORMAT CONTRACT and is not this code's to choose: 64 bytes,
 * measured on a live PDP-11 and pinned independently by
 * toolchain/tests/M37/pdplayout.c.  tools/fgxfs.py's Dinode reads the same
 * offsets from the other side.
 *
 *      0  mode      2  nlink     4  uid       6  gid
 *      8  size     12  addr[7]  40  reserved[5]
 *     50  flags    52  atime    56  mtime     60  ctime
 *
 * Sixteen-bit fields overlay this machine directly; every 32-bit one needs the
 * half-swap, which is why they go through ufs_dget32 rather than being read as
 * longs.  Same argument as the superblock and the indirect blocks: one
 * definition of the byte order, in ufs_vfsops.c, and everything else asks it.
 */
void
ufs_idecode(b, dp)
char          *b;
struct dinode *dp;
{
    int i;

    dp->di_icom1.ic_mode  = (unsigned short)ufs_dget16(b, 0);
    dp->di_icom1.ic_nlink = (unsigned short)ufs_dget16(b, 2);
    dp->di_icom1.ic_uid   = (uid_t)ufs_dget16(b, 4);
    dp->di_icom1.ic_gid   = (gid_t)ufs_dget16(b, 6);
    dp->di_icom1.ic_size  = ufs_dget32(b, 8);
    for (i = 0; i < NADDR; i++)
        dp->di_addr[i] = ufs_dget32(b, 12 + 4 * i);
    for (i = 0; i < 5; i++)
        dp->di_reserved[i] = (unsigned short)ufs_dget16(b, 40 + 2 * i);
    dp->di_flags          = (unsigned short)ufs_dget16(b, 50);
    dp->di_icom2.ic_atime = ufs_dget32(b, 52);
    dp->di_icom2.ic_mtime = ufs_dget32(b, 56);
    dp->di_icom2.ic_ctime = ufs_dget32(b, 60);
}


/* ufs_iencode -- one in-core dinode, back into its on-disk 64 bytes.  The
 * inverse of ufs_idecode above, and UFS 1.12a's half of it.
 *
 * UPSTREAM DOES THIS WITH THREE ASSIGNMENTS AND A bcopy -- 2.11BSD's iupdat is
 * `dp->di_ic1 = tip->i_ic1; dp->di_flags = tip->i_flags; dp->di_ic2 =
 * tip->i_ic2; bcopy(ip->i_addr, dp->di_addr, NADDR * sizeof (daddr_t))`
 * (usr/sys/sys/ufs_inode.c), and Reno's is the single `*dp = ip->i_din`
 * (ufs/ufs_inode.c:361).  BOTH ARE STRUCTURE ASSIGNMENTS ONTO THE BUFFER, and
 * both are correct there for the same reason ufs_bmap's `bap[i]` is: on a
 * PDP-11 and a VAX the in-core form IS the on-disk form.  It is not here.  A
 * struct copy onto the buffer would write every 32-bit field with its halves
 * in this machine's order, and the volume would stop being one a PDP-11 can
 * read -- which is goal 2 of the campaign, and the reason the decode above is
 * field by field as well.
 *
 * SO THE FIELD LIST IS THE CONTRACT, and it is ufs_idecode's list read
 * backwards.  Anything decoded and not encoded is a field that survives a read
 * and is lost on the next write; the two lists must stay identical, which is
 * why they sit next to each other rather than in the file that needs each one.
 * di_reserved is carried for exactly that reason -- nothing in this port reads
 * it, and dropping it from the encode would zero five words of somebody else's
 * volume on the first write.
 */
void
ufs_iencode(dp, b)
struct dinode *dp;
char          *b;
{
    int i;

    ufs_dput16(b, 0, (int)dp->di_icom1.ic_mode);
    ufs_dput16(b, 2, (int)dp->di_icom1.ic_nlink);
    ufs_dput16(b, 4, (int)dp->di_icom1.ic_uid);
    ufs_dput16(b, 6, (int)dp->di_icom1.ic_gid);
    ufs_dput32(b, 8, dp->di_icom1.ic_size);
    for (i = 0; i < NADDR; i++)
        ufs_dput32(b, 12 + 4 * i, dp->di_addr[i]);
    for (i = 0; i < 5; i++)
        ufs_dput16(b, 40 + 2 * i, (int)dp->di_reserved[i]);
    ufs_dput16(b, 50, (int)dp->di_flags);
    ufs_dput32(b, 52, dp->di_icom2.ic_atime);
    ufs_dput32(b, 56, dp->di_icom2.ic_mtime);
    ufs_dput32(b, 60, dp->di_icom2.ic_ctime);
}
