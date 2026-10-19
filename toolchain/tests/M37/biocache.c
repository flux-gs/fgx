/* biocache.c -- UFS 1.3a: exercise the buffer cache's pool, hash chains and
 * free lists on real hardware.
 *
 * WHY A FIXTURE AND NOT A BOOT PROBE.  This slice is pure data-structure code:
 * circular doubly-linked lists, a hash, and a reclaim policy.  None of it needs
 * a disk, a vnode layer or a kernel, and all of it is exactly the kind of code
 * that is wrong in ways a boot test cannot see -- a list that unlinks the wrong
 * neighbour still boots.  Running it as a fixture puts it under the existing
 * runtime harness, on the real 65816, where fcc's pointer handling is also
 * under test.
 *
 * It INCLUDES the implementation rather than linking it, which is how a unit
 * test reaches static list primitives.  The stubs below stand in for the
 * kernel's sleep/wakeup/panic; nothing here can reach them, and the fixture
 * PROVES that rather than assuming it -- a stub that fires sets a flag and the
 * final check fails.  That matters: sleep() firing would mean the pool ran dry
 * under a workload sized not to, and a stub that silently returned would turn
 * that into a pass.
 *
 * Exit 42 = pass; any other code identifies the failing property.
 */

static int stub_slept  = 0;
static int stub_panic  = 0;

/* The kernel supplies these; here they are stubs that COUNT rather than
 * ignore, so "it never slept" is asserted rather than assumed.  They are
 * kc_-prefixed in the source for a reason worth knowing: libc owns the name
 * `sleep`, and this fixture links libc, so a kernel routine called sleep()
 * collides at assembly time with a duplicate-label error.  Kernel C links no
 * libc and would never have hit it -- testing kernel code in userland is what
 * exposed the name clash, and the seam's kc_ prefix is the fix. */
void kc_sleep(chan)  char *chan; { stub_slept++; }
/* Forward: bio_strategy needs biodone, which lives in the file we include. */
void biodone();
void kc_wakeup(chan) char *chan; { }
void kc_panic(msg)   char *msg;  { stub_panic++; }

/* The headers first, so the fake disk below can see struct buf.  vfs_bio.c
 * includes them too; the guards make that a no-op. */
#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/buf.h"

/* A fake disk.  One byte per block is enough to prove the cache moved the
 * right block in the right direction; the point is the CALL COUNTS, not the
 * bytes.  Strategy is synchronous and calls biodone before returning, which is
 * the contract the real one has on synchronous SmartPort PIO. */
#define FAKEBLKS  64
static char fake_disk[FAKEBLKS];
static int  fake_reads  = 0;
static int  fake_writes = 0;

void
bio_strategy(bp)
    struct buf *bp;
{
    int b;

    b = (int)bp->b_blkno;
    if (b < 0 || b >= FAKEBLKS) { bp->b_flags |= B_ERROR; bp->b_error = EIO; biodone(bp); return; }
    if (bp->b_flags & B_READ) { fake_reads++;  bp->b_addr[0] = fake_disk[b]; }
    else                      { fake_writes++; fake_disk[b] = bp->b_addr[0]; }
    biodone(bp);
}

/* THE VNODE'S OPS VECTOR, and as of the VOP_STRATEGY seam not optional.
 * bread and bwrite issue VOP_STRATEGY rather than calling bio_strategy by
 * name, so a vnode handed to this cache must carry a vector whose strategy
 * slot reaches a disk.  The slot's POSITION is what is relied on: it is the
 * 30th, and a vector built by hand with one entry missing would dispatch
 * something else entirely and still run. */
static int fake_nop()      { return 0; }
static int fake_strategy(bp)
    struct buf *bp;
{
    bio_strategy(bp);
    return (0);
}

struct vnodeops fakeops = {
    fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop,
    fake_nop,
    fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop,
    fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop, fake_nop,
    fake_nop,
    fake_nop, fake_nop, fake_nop, fake_nop, fake_nop,
    fake_nop, fake_strategy,
    fake_nop, fake_nop
};

#include "../../../src/kernel/vfs/vfs_bio.c"

/* The arena, which vfs_bio.c deliberately does NOT declare -- the kernel hands
 * bufinit heap in a bank of its own, and this fixture hands it a static array.
 * That split is the point: 16 KB of zero-initialised storage has no reason to
 * live in whichever bank the code lands in. */
char fixarena[NBUF * FS_BLKSIZE];

/* Vnodes, faked.  The cache only reads v_type and v_holdcnt, so a real vnode
 * layer is not needed to test the pool -- and using one would couple this to
 * work that has not landed. */
struct vnode vn[3];

/* List walks, BOUNDED.  A corrupted circular list makes the obvious loop spin
 * forever, and a test that hangs is worse than one that fails: it reports
 * nothing, and it stalls whatever harness is running it.  Any walk longer than
 * the pool is a broken list by definition, so these stop and say so.  This is
 * not defensive padding -- the first list-corrupting mutation tried against
 * this fixture hung it, which is how the limit got here. */
#define WALK_MAX  (NBUF + 4)
#define WALK_BAD  (-1)

/* How many buffers sit on a given free list; WALK_BAD if the list is broken. */
static int
flistlen(q)
    int q;
{
    register struct buf *dp;
    register struct buf *bp;
    register int n;

    n = 0;
    dp = &bfreelist[q];
    if (dp->av_forw->av_back != dp)
        return (WALK_BAD);
    for (bp = dp->av_forw; bp != dp; bp = bp->av_forw) {
        /* Every forward link must be mirrored by its neighbour's back link.
         * A half-spliced removal breaks this long before it breaks the
         * forward walk, and this fixture once found that out the hard way. */
        if (bp->av_forw->av_back != bp)
            return (WALK_BAD);
        if (++n > WALK_MAX)
            return (WALK_BAD);
    }
    return (n);
}

/* How many buffers sit on a given hash chain; WALK_BAD if the chain is broken. */
static int
hashlen(h)
    int h;
{
    register struct buf *dp;
    register struct buf *bp;
    register int n;

    n = 0;
    dp = &bufhash[h];
    if (dp->b_forw->b_back != dp)
        return (WALK_BAD);
    for (bp = dp->b_forw; bp != dp; bp = bp->b_forw) {
        if (bp->b_forw->b_back != bp)
            return (WALK_BAD);
        if (++n > WALK_MAX)
            return (WALK_BAD);
    }
    return (n);
}

static int
totalfree()
{
    return (flistlen(BQ_LOCKED) + flistlen(BQ_LRU) + flistlen(BQ_AGE));
}

/* How many buffers hang off one of a vnode's block lists, WALK_BAD if the list
 * is broken.  Bounded for the same reason the others are.
 *
 * It checks the BACK-LINKS as it goes, and that is the whole reason this
 * exists rather than a bare forward count.  b_blockb holds the address of the
 * pointer that references a buffer, so a forward walk is still perfectly
 * traversable after a wrong back-link -- and stays that way until something
 * unlinks a middle element and writes through the stale pointer, which is one
 * buffer's worth of another file's data, silently.  The identity that has to
 * hold at every node is *bp->b_blockb == bp. */
static int
blklen(headp)
    struct buf **headp;
{
    register struct buf *bp;
    register int n;

    n = 0;
    for (bp = *headp; bp; bp = bp->b_blockf) {
        if (bp->b_blockb == 0)
            return (WALK_BAD);
        if (*bp->b_blockb != bp)
            return (WALK_BAD);
        if (++n > WALK_MAX)
            return (WALK_BAD);
    }
    return (n);
}

/* Reset the fake vnodes.  bufinit re-initialises the POOL, and deliberately
 * does not reach into vnodes it has never been given -- so a vnode still
 * holding list heads from an earlier section of this fixture would have them
 * carried into the next one. */
static void
vnreset()
{
    register int i;

    for (i = 0; i < 3; i++) {
        vn[i].v_type = 1;
        vn[i].v_op = &fakeops;
        vn[i].v_flag = 0;
        vn[i].v_holdcnt = 0;
        vn[i].v_numoutput = 0;
        vn[i].v_cleanblkhd = 0;
        vn[i].v_dirtyblkhd = 0;
    }
}

int main()
{
    struct buf *a;
    struct buf *b;
    struct buf *c;
    int i;
    int n;

    for (i = 0; i < 3; i++) {
        vn[i].v_type = 1;
        vn[i].v_op = &fakeops;
        vn[i].v_holdcnt = 0;
    }

    bufinit(fixarena);

    /* ---- after init: every buffer free, none hashed, all with storage ---- */
    if (totalfree() != NBUF)                    return 1;
    if (flistlen(BQ_AGE) != NBUF)               return 2;
    for (i = 0; i < BUFHASHSZ; i++)
        if (hashlen(i) != 0)                    return 3;
    for (i = 0; i < NBUF; i++) {
        if (buf[i].b_addr != &fixarena[i * FS_BLKSIZE]) return 4;
        if ((buf[i].b_flags & B_INVAL) == 0)    return 5;
    }

    /* ---- getblk on a cold cache claims a buffer off the free list ---- */
    a = getblk(&vn[0], (daddr_t)100);
    if (a == 0)                                 return 6;
    if ((a->b_flags & B_BUSY) == 0)             return 7;
    if (a->b_vp != &vn[0])                      return 8;
    if (a->b_lblkno != (daddr_t)100)            return 9;
    if (totalfree() != NBUF - 1)                return 10;
    if (vn[0].v_holdcnt != 1)                   return 11;

    /* A claimed buffer must be findable by key, and must NOT be reported
     * resident while it is still invalid. */
    if (a->b_flags & B_INVAL)                   return 12;
    if (!incore(&vn[0], (daddr_t)100))          return 13;
    if (incore(&vn[0], (daddr_t)101))           return 14;
    if (incore(&vn[1], (daddr_t)100))           return 15;   /* different vnode */

    /* ---- release, then re-get: the SAME buffer must come back ---- */
    brelse(a);
    if (a->b_flags & B_BUSY)                    return 16;
    if (totalfree() != NBUF)                    return 17;
    b = getblk(&vn[0], (daddr_t)100);
    if (b != a)                                 return 18;   /* cache hit */
    if (vn[0].v_holdcnt != 1)                   return 19;   /* not re-held */

    /* ---- a different key gets a different buffer ---- */
    c = getblk(&vn[0], (daddr_t)101);
    if (c == b)                                 return 20;
    if (totalfree() != NBUF - 2)                return 21;
    brelse(b);
    brelse(c);

    /* ---- two vnodes SHARING A HASH BUCKET must not be confused ----
     *
     * The obvious form of this test -- block 7 on two different vnodes -- does
     * NOT work, and quietly passes even when getblk ignores b_vp entirely.
     * The hash mixes the vnode in, so two vnodes at the same block land in
     * DIFFERENT buckets and the lookup never walks past the other one's
     * buffer.  The key check is only load-bearing for entries that share a
     * chain, so the test has to put them there.
     *
     * The colliding block number is FOUND, not hardcoded: it depends on the
     * hash function and on sizeof(struct vnode), and a literal would stop
     * testing anything the day either changed. */
    n = -1;
    for (i = 0; i < BUFHASHSZ * 4; i++) {
        if (bufhashof(&vn[1], (daddr_t)i) == bufhashof(&vn[0], (daddr_t)7)) {
            n = i;
            break;
        }
    }
    if (n < 0)                                  return 38;   /* no collision found */

    a = getblk(&vn[0], (daddr_t)7);
    b = getblk(&vn[1], (daddr_t)n);
    if (a == b)                                 return 22;   /* same buffer! */
    if (a->b_vp == b->b_vp)                     return 23;
    if (!incore(&vn[0], (daddr_t)7))            return 24;
    if (!incore(&vn[1], (daddr_t)n))            return 25;
    /* ...and neither key may resolve to the other's vnode. */
    if (incore(&vn[1], (daddr_t)7) && n != 7)   return 39;
    brelse(a);
    brelse(b);

    /* ---- invalidation drops the key AND the vnode ---- */
    a = getblk(&vn[2], (daddr_t)55);
    if (vn[2].v_holdcnt != 1)                   return 26;
    a->b_flags |= B_INVAL;
    brelse(a);
    if (incore(&vn[2], (daddr_t)55))            return 27;
    if (a->b_vp != 0)                           return 28;
    if (vn[2].v_holdcnt != 0)                   return 29;
    /* ...and it goes to the HEAD of BQ_AGE, so it is reused before anything
     * still carrying useful contents. */
    if (bfreelist[BQ_AGE].av_forw != a)         return 30;

    /* ---- exhaust the pool exactly, then confirm the lists are consistent --
     * NBUF distinct keys claim every buffer.  This is the arm that would make
     * sleep() fire if the reclaim policy leaked a buffer, which is why the
     * stub counts rather than ignores. */
    for (i = 0; i < NBUF; i++) {
        if (getblk(&vn[0], (daddr_t)(200 + i)) == 0) return 31;
    }
    if (totalfree() != 0)                       return 32;
    if (stub_slept != 0)                        return 33;

    /* Every claimed buffer is on a hash chain, and the chains hold exactly the
     * NBUF buffers we claimed -- no duplicates, none lost. */
    n = 0;
    for (i = 0; i < BUFHASHSZ; i++) {
        if (hashlen(i) == WALK_BAD)             return 40;   /* broken chain */
        n += hashlen(i);
    }
    if (n != NBUF)                              return 34;

    /* ---- release them all; the pool comes back whole ---- */
    for (i = 0; i < NBUF; i++)
        brelse(&buf[i]);
    if (totalfree() != NBUF)                    return 35;

    /* Nothing above should have needed the kernel. */
    if (stub_slept != 0)                        return 36;
    if (stub_panic != 0)                        return 37;

    /* ================= the I/O path ================= */
    bufinit(fixarena);
    for (i = 0; i < FAKEBLKS; i++) fake_disk[i] = (char)(i + 1);
    fake_reads = 0; fake_writes = 0;

    /* ---- a read MISS goes to the disk and brings back the right block ---- */
    if (bread(&vn[0], (daddr_t)5, &a) != 0)     return 45;
    if (fake_reads != 1)                        return 46;
    if (a->b_addr[0] != (char)6)                return 47;   /* disk[5] == 6 */
    if ((a->b_flags & B_DONE) == 0)             return 48;
    brelse(a);

    /* ---- a read HIT does NOT go to the disk.  This is the entire point of
     * having a cache, and it is the assertion most likely to rot into a
     * tautology, so it counts calls rather than trusting flags. ---- */
    if (bread(&vn[0], (daddr_t)5, &b) != 0)     return 49;
    if (b != a)                                 return 50;
    if (fake_reads != 1)                        return 51;   /* still 1 */
    brelse(b);

    /* ---- bwrite reaches the disk and releases the buffer ---- */
    if (bread(&vn[0], (daddr_t)6, &a) != 0)     return 52;
    a->b_addr[0] = (char)99;
    if (bwrite(a) != 0)                         return 53;
    if (fake_writes != 1)                       return 54;
    if (fake_disk[6] != (char)99)               return 55;
    if (a->b_flags & B_BUSY)                    return 56;   /* released */

    /* ---- bdwrite does NOT reach the disk yet ---- */
    if (bread(&vn[0], (daddr_t)7, &a) != 0)     return 57;
    a->b_addr[0] = (char)77;
    bdwrite(a);
    if (fake_writes != 1)                       return 58;   /* still 1 */
    if ((a->b_flags & B_DELWRI) == 0)           return 59;

    /* ...and a bread of that block is a HIT on the pending bytes, not a
     * re-read that would DISCARD the write. */
    if (bread(&vn[0], (daddr_t)7, &b) != 0)     return 61;
    if (b != a)                                 return 62;
    if (b->b_addr[0] != (char)77)               return 63;
    if (fake_disk[7] != (char)8)                return 64;   /* disk untouched */
    brelse(b);

    /* ---- reclaiming a delayed-write buffer FLUSHES it ---- */
    for (i = 0; i < NBUF; i++)
        if (bread(&vn[1], (daddr_t)(20 + i), &c) == 0) brelse(c);
    if (fake_writes != 2)                       return 65;   /* the flush */
    if (fake_disk[7] != (char)77)               return 66;   /* it landed */

    /* ---- an INVALIDATED delayed write must NOT be flushed ---- */
    bufinit(fixarena);
    fake_writes = 0;
    fake_disk[9] = (char)9;
    if (bread(&vn[2], (daddr_t)9, &a) != 0)     return 67;
    a->b_addr[0] = (char)55;
    bdwrite(a);
    a = getblk(&vn[2], (daddr_t)9);              /* reclaim it, still DELWRI */
    a->b_flags |= B_INVAL;
    brelse(a);
    if (a->b_flags & B_DELWRI)                  return 68;   /* dropped */
    for (i = 0; i < NBUF; i++)
        if (bread(&vn[1], (daddr_t)(30 + i), &c) == 0) brelse(c);
    if (fake_writes != 0)                       return 69;   /* nothing written */
    if (fake_disk[9] != (char)9)                return 70;   /* disk untouched */

    /* ---- a recycled buffer must not carry the previous owner's device ----
     *
     * Nothing sets b_dev to a real device yet -- device vnodes arrive with
     * specfs in 1.5 -- so the stale case cannot occur naturally and this
     * FORCES it: dirty the field, release, then claim the buffer under a new
     * key and require bgetvp to have overwritten it.  Without this the fix is
     * untested until the day it matters, which is the day it is hardest to
     * debug: a buffer issued against another file's device. */
    bufinit(fixarena);
    a = getblk(&vn[0], (daddr_t)11);
    a->b_dev = 0x1234;                           /* pretend a previous owner */
    a->b_flags |= B_INVAL;                       /* force a full recycle */
    brelse(a);
    b = getblk(&vn[1], (daddr_t)12);
    if (b != a)                                 return 73;   /* same buffer back */
    if (b->b_dev != NODEV)                      return 74;   /* stale device! */

    /* ================= the vnode's block lists (UFS 1.4b, #84) =============
     *
     * Everything above tests the cache as a POOL: does a key find its buffer.
     * This tests it as an INDEX -- given a vnode, can the code find every
     * buffer belonging to it -- which is the property fsync, truncate and
     * vclean are built on and the one that has no other way of being checked.
     *
     * A boot test cannot see any of this.  A wrong back-link leaves the
     * forward walk intact, so the machine boots, the files read correctly, and
     * the damage appears later as one buffer of the wrong file's contents. */

    bufinit(fixarena);
    vnreset();
    fake_reads = 0;
    fake_writes = 0;

    /* ---- a claimed buffer joins its vnode's CLEAN list ---- */
    a = getblk(&vn[0], (daddr_t)1);
    if (blklen(&vn[0].v_cleanblkhd) != 1)       return 75;
    if (blklen(&vn[0].v_dirtyblkhd) != 0)       return 76;
    if (vn[0].v_cleanblkhd != a)                return 77;
    if (a->b_blockb != &vn[0].v_cleanblkhd)     return 78;

    /* Releasing a valid buffer must NOT detach it: it is still cached, and a
     * cache whose index forgets its entries on release is not a cache. */
    brelse(a);
    if (blklen(&vn[0].v_cleanblkhd) != 1)       return 79;
    if (a->b_vp != &vn[0])                      return 80;

    /* ---- lists are PER VNODE, not global ---- */
    b = getblk(&vn[1], (daddr_t)2);
    brelse(b);
    if (blklen(&vn[0].v_cleanblkhd) != 1)       return 81;
    if (blklen(&vn[1].v_cleanblkhd) != 1)       return 82;

    /* ---- bdwrite moves a buffer to the DIRTY list, and only there ---- */
    a = getblk(&vn[0], (daddr_t)1);
    a->b_addr[0] = (char)0x5A;
    bdwrite(a);
    if (blklen(&vn[0].v_cleanblkhd) != 0)       return 83;
    if (blklen(&vn[0].v_dirtyblkhd) != 1)       return 84;
    if (fake_writes != 0)                       return 85;   /* still delayed */

    /* A second bdwrite on the same buffer must leave it where it is.  The
     * membership test is the one that catches a reassign-unconditionally bug:
     * unlink-then-insert on an already-dirty buffer restores the same list and
     * looks correct here, so the length is checked on BOTH lists. */
    a = getblk(&vn[0], (daddr_t)1);
    bdwrite(a);
    if (blklen(&vn[0].v_dirtyblkhd) != 1)       return 86;
    if (blklen(&vn[0].v_cleanblkhd) != 0)       return 87;

    /* ---- bwrite moves it back ---- */
    a = getblk(&vn[0], (daddr_t)1);
    if (bwrite(a) != 0)                         return 88;
    if (fake_writes != 1)                       return 89;
    if (fake_disk[1] != (char)0x5A)             return 90;
    if (blklen(&vn[0].v_dirtyblkhd) != 0)       return 91;
    if (blklen(&vn[0].v_cleanblkhd) != 1)       return 92;
    if (vn[0].v_numoutput != 0)                 return 93;   /* retired */

    /* ---- MIDDLE-OF-LIST removal ----
     *
     * Three buffers on one vnode, then invalidate the middle one.  A head-only
     * unlink passes the length check and corrupts the back-link of the
     * survivor, which is why blklen verifies *b_blockb == bp at every node
     * rather than counting.  The list is built head-first, so the buffer
     * claimed SECOND is the middle one. */
    bufinit(fixarena);
    vnreset();
    a = getblk(&vn[0], (daddr_t)3);  brelse(a);
    b = getblk(&vn[0], (daddr_t)4);  brelse(b);
    c = getblk(&vn[0], (daddr_t)5);  brelse(c);
    if (blklen(&vn[0].v_cleanblkhd) != 3)       return 94;
    if (vn[0].v_cleanblkhd != c)                return 95;   /* head-first */
    b = getblk(&vn[0], (daddr_t)4);
    b->b_flags |= B_INVAL;
    brelse(b);                                  /* -> brelvp -> bufremvn */
    if (blklen(&vn[0].v_cleanblkhd) != 2)       return 96;
    if (vn[0].v_cleanblkhd != c)                return 97;   /* head kept */
    if (b->b_vp != 0)                           return 98;
    if (b->b_blockb != 0)                       return 99;
    /* ...and the survivors are still reachable BY KEY, which is what a
     * cross-linked list breaks. */
    if (!incore(&vn[0], (daddr_t)3))            return 100;
    if (!incore(&vn[0], (daddr_t)5))            return 101;

    /* ---- vflushbuf writes every dirty buffer of one vnode, and only one ---- */
    bufinit(fixarena);
    vnreset();
    fake_writes = 0;
    a = getblk(&vn[0], (daddr_t)6);  a->b_addr[0] = (char)0x11;  bdwrite(a);
    b = getblk(&vn[0], (daddr_t)7);  b->b_addr[0] = (char)0x22;  bdwrite(b);
    c = getblk(&vn[1], (daddr_t)8);  c->b_addr[0] = (char)0x33;  bdwrite(c);
    if (blklen(&vn[0].v_dirtyblkhd) != 2)       return 102;
    vflushbuf(&vn[0], B_SYNC);
    if (fake_writes != 2)                       return 103;   /* not vn[1]'s */
    if (fake_disk[6] != (char)0x11)             return 104;
    if (fake_disk[7] != (char)0x22)             return 105;
    if (fake_disk[8] == (char)0x33)             return 106;   /* untouched */
    if (blklen(&vn[0].v_dirtyblkhd) != 0)       return 107;
    if (blklen(&vn[0].v_cleanblkhd) != 2)       return 108;
    if (blklen(&vn[1].v_dirtyblkhd) != 1)       return 109;
    if (vn[0].v_numoutput != 0)                 return 110;

    /* ---- vinvalbuf(vp, 1) SAVES: the pending write reaches the disk ---- */
    bufinit(fixarena);
    vnreset();
    fake_writes = 0;
    a = getblk(&vn[0], (daddr_t)9);  a->b_addr[0] = (char)0x44;  bdwrite(a);
    b = getblk(&vn[0], (daddr_t)10); brelse(b);                  /* clean */
    n = vinvalbuf(&vn[0], 1);
    if (n != 1)                                 return 111;   /* one dirty */
    if (fake_writes != 1)                       return 112;
    if (fake_disk[9] != (char)0x44)             return 113;
    if (blklen(&vn[0].v_dirtyblkhd) != 0)       return 114;
    if (blklen(&vn[0].v_cleanblkhd) != 0)       return 115;
    if (vn[0].v_holdcnt != 0)                   return 116;   /* all released */
    if (totalfree() != NBUF)                    return 117;

    /* ---- vinvalbuf(vp, 0) DISCARDS, and the discard must be real ----
     *
     * THIS IS THE HAZARD THE FUNCTION EXISTS FOR.  A vnode about to be
     * reclaimed is about to become a DIFFERENT file, and the cache is keyed by
     * (b_vp, b_lblkno) -- so a buffer left chained to it answers the new
     * file's lookups with the old file's bytes.  The check is not that the
     * lists are empty, it is that the next read of that key GOES TO THE DISK
     * and returns what the disk holds. */
    bufinit(fixarena);
    vnreset();
    fake_disk[11] = (char)0x77;                  /* what the disk really holds */
    fake_reads = 0;
    fake_writes = 0;
    a = getblk(&vn[0], (daddr_t)11);
    a->b_addr[0] = (char)0x88;                   /* what the old file wrote */
    bdwrite(a);
    n = vinvalbuf(&vn[0], 0);
    if (n != 0)                                 return 118;   /* nothing saved */
    if (fake_writes != 0)                       return 119;   /* discarded */
    if (fake_disk[11] != (char)0x77)            return 120;   /* disk intact */
    if (blklen(&vn[0].v_cleanblkhd) != 0)       return 121;
    if (blklen(&vn[0].v_dirtyblkhd) != 0)       return 122;
    if (bread(&vn[0], (daddr_t)11, &c) != 0)    return 123;
    if (fake_reads != 1)                        return 124;   /* went to disk */
    if (c->b_addr[0] != (char)0x77)             return 125;   /* NOT the stale byte */
    brelse(c);

    /* biowait must never actually wait: strategy is synchronous, so B_DONE is
     * set before it is called.  If this ever fires, the sleep is BELOW Blk_*
     * and the legacy layer's singletons are no longer safe. */
    if (stub_slept != 0)                        return 71;
    if (stub_panic != 0)                        return 72;

    return 42;
}
