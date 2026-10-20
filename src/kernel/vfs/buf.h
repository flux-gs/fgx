/* buf.h -- the buffer header, from 2.11BSD's own sys/buf.h (1.4, 1996/9/13),
 * read off the live PDP-11/70 rather than reconstructed.
 *
 * THE HEADER DOES NOT EMBED ITS DATA.  b_addr points at the buffer, as it does
 * on the PDP-11, and that is the single most important structural fact in the
 * VFS budget: NBUF headers are a few hundred bytes and can be placed anywhere,
 * while the NBUF * FS_BLKSIZE they describe lives in its own arena.  A
 * Reno-style embedded buffer would have put the payload inside the table and
 * made the pool unsizeable on this machine.
 *
 * Three deliberate changes from 2.11BSD:
 *
 *   b_xmem   DROPPED.  It is the PDP-11's high-order UNIBUS address -- the top
 *            bits of a physical address that does not fit a 16-bit pointer.
 *            An fcc pointer already carries its bank, so b_addr covers what
 *            b_xmem existed to cover.  A pad keeps 2-alignment.
 *   b_vp     ADDED.  Reno's buffer cache is vnode-keyed, and that back-pointer
 *            is the whole reason it beats the legacy (dev, blk) cache: it can
 *            find every buffer belonging to a file, which is what makes fsync
 *            and truncate possible at all.
 *   b_flags  stays SHORT, not Reno's long.  The 2.11BSD flag set tops out at
 *            B_RAMREMAP (0x8000) and fits.
 *
 * Pinned by toolchain/tests/M37/vfslayout.c, which includes this header.
 */
#ifndef _BUF_H_
#define _BUF_H_

#include "fsparam.h"

struct buf {
    short           b_flags;
    struct buf     *b_forw;         /* hash chain (2 way street) */
    struct buf     *b_back;
    struct buf     *av_forw;        /* free list position if not BUSY */
    struct buf     *av_back;
    unsigned short  b_bcount;       /* transfer count */
    char            b_error;        /* returned after I/O */
    char            b_pad;          /* was b_xmem; see above */
    dev_t           b_dev;          /* major+minor device */
    char           *b_addr;         /* Reno/2.11: b_un.b_addr */
    daddr_t         b_lblkno;       /* LOGICAL block # -- the cache key */
    daddr_t         b_blkno;        /* PHYSICAL block # on device */
    unsigned short  b_resid;        /* not transferred after error */
    struct vnode   *b_vp;           /* vnode this buffer belongs to */
    /* The vnode's clean-or-dirty list.  b_blockb is Reno's pointer-to-pointer
     * back-link -- the ADDRESS OF the pointer that references this buffer,
     * which is either a previous buffer's b_blockf or the vnode's
     * v_cleanblkhd/v_dirtyblkhd itself.  One store therefore unlinks a buffer
     * whether it sits at the head of the list or in the middle, and a buffer
     * moves between the two lists without either head being a special case.
     *
     * These are what makes b_vp worth having.  A back-pointer alone says which
     * file a buffer belongs to; only the list lets the code go the other way
     * and enumerate every buffer of a given file, which is what fsync,
     * truncate, and invalidate-on-reclaim are. */
    struct buf     *b_blockf;       /* vnode block list forward */
    struct buf    **b_blockb;       /* vnode block list back */
};

/* WHY BOTH BLOCK NUMBERS.  The cache is keyed by (b_vp, b_lblkno) -- a block's
 * offset WITHIN ITS FILE -- because that is what a caller asks for and what
 * survives the file growing.  b_blkno is where that block currently lives on
 * the device, which VOP_BMAP fills in and which changes when a file is
 * extended or a fragment is reallocated.  2.11BSD collapses the two because
 * its cache is device-keyed; Reno separates them because its cache is
 * vnode-keyed, and vnode-keyed is the whole reason this replaces the legacy
 * (dev, blk) cache -- it can find every buffer belonging to a file, which is
 * what makes fsync and truncate possible at all.
 *
 * WHAT IS DELIBERATELY ABSENT: b_bufsize, and with it Reno's brealloc/bfree.
 * Reno buffers are variable-size and allocated on demand out of the VM system,
 * which FGX does not have.  2.11BSD's are fixed at one filesystem block and so
 * are these -- FS_BLKSIZE, from a static arena -- which is why b_bcount is the
 * only count here and why the BQ_EMPTY free list does not exist: a buffer
 * always has its block of memory, so there is no such thing as an empty one.
 */

/* b_flags, from 2.11BSD.  Only the ones the port actually uses are carried;
 * the PDP-11 bus flags (B_MAP, B_UBAREMAP, B_RAMREMAP) have no meaning here.
 *
 * THE WIDTH IS A BOUNDARY, AND IT IS 2.11BSD'S NUMBERING THAT MAKES IT SAFE.
 * 2.11BSD's whole set fits sixteen bits (it tops out at B_RAMREMAP, 0x8000)
 * and the three flags dropped above are its top three, so nothing carried here
 * reaches 0x4000.  RENO'S SET DOES NOT FIT: it is a long, and B_INVAL alone is
 * 0x010000, with B_CALL, B_RAW and B_NOCACHE above that.  So a later import of
 * a Reno vfs_bio arm that tests one of those -- biodone's B_CALL callback is
 * the obvious one, and it was deliberately not ported -- needs this field
 * widened first, and cannot simply add the constant.
 *
 * toolchain/tests/M37/vfslayout.c round-trips the widest flag through the real
 * field, so adding one above the width fails the build rather than reading
 * back as zero. */
#define B_WRITE     0x0000          /* non-read pseudo-flag */
#define B_READ      0x0001          /* read when I/O occurs */
#define B_DONE      0x0002          /* transaction finished */
#define B_ERROR     0x0004          /* transaction aborted */
#define B_BUSY      0x0008          /* not on av_forw/back list */
#define B_PHYS      0x0010          /* physical IO */
#define B_WANTED    0x0040          /* issue wakeup when BUSY goes off */
#define B_AGE       0x0080          /* delayed write for correct aging */
#define B_ASYNC     0x0100          /* don't wait for I/O completion */
#define B_DELWRI    0x0200          /* write at exit of avail list */
#define B_INVAL     0x0800          /* does not contain valid info */
#define B_LOCKED    0x2000          /* locked in core (not reusable) */

/* NOT a b_flags bit.  B_SYNC is an ARGUMENT to vflushbuf, asking it to wait
 * until the data is on the disk rather than merely issued.  Reno gives it 0x2
 * -- the same number as B_DONE -- and it is kept because the two namespaces
 * never meet and a call copied out of a Reno listing has to mean what it says
 * there. */
#define B_SYNC      0x0002

#endif /* _BUF_H_ */
