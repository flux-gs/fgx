/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/tty_subr.c
 *   Ported from usr/sys/sys/tty_subr.c and usr/sys/sys/init_main.c (cinit),
 *   2.11BSD.
 *   Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* tty_subr.c -- the character-list queues.  The tty bank's first tenant.
 *
 * Upstream's nine routines, unchanged in structure: getc, q_to_b, ndqb,
 * ndflush, putc, b_to_q, nextc, unputc, catq.  cinit() comes from
 * init_main.c, where upstream keeps it; it belongs with the pool it builds and
 * FGX has no init_main.
 *
 * NOT PORTED, and neither is a decision of ours: getw() and putw() sit inside
 * upstream's own `#ifdef unneeded`, and lookc()/the three-argument nextc() are
 * inside `#ifdef UCB_CLIST` -- the PDP-11 split I/D variant that maps the pool
 * into segment 5 with mapseg5().  FGX has no MMU and no segment registers, so
 * every UCB_CLIST arm is removed rather than stubbed.
 *
 *============================================================================
 * THE CROUND TRICK SURVIVES THE PORT, AND IT SURVIVES BY A PROPERTY OF THIS
 * BANK.  Upstream finds a block's base from any pointer into it with
 *
 *      bp = (struct cblock *)((int)bp & ~CROUND);
 *
 * On a PDP-11 that is free: int and char* are both 16 bits.  Here a pointer is
 * FOUR bytes -- a 16-bit offset plus a bank -- so the cast to int drops the
 * bank and the cast back has to invent one.  fcc's rule for that
 * (_fcc_bank_for_int, apple/fgx#12) stamps DBR on any nonzero value, and every
 * entry into this bank's C sets DBR to this bank.  The pool is a global HERE.
 * So the bank it invents is the bank the block is in, and the round trip is
 * exact.
 *
 * THAT IS A FACT ABOUT WHERE THE POOL LIVES, NOT ABOUT THE CODE.  Move cfree
 * to the kernel heap -- a different bank -- and all six of these casts start
 * returning this bank's offset in the wrong bank, silently, with no compiler
 * or assembler able to see it.  If the pool ever has to move, the masks have
 * to stop going through int.
 *
 * The masks that only TEST or SUBTRACT (`& CROUND`, `end - q->c_cf`) are safe
 * either way: both operands are in one bank and the bank cancels.
 *
 *============================================================================
 * sizeof(struct cblock) IS 32 ON BOTH MACHINES, and that is what the masks
 * need.  CBSIZE is 28 here against upstream's 30, because it is defined as
 * CBLOCK minus the size of the link and the link is a 4-byte pointer.  Nothing
 * in this file writes 30, 28 or 32 as a literal.
 */

#include "ttyparam.h"
#include "clist.h"
#include "tty.h"

/* The pool.  A C global, so it lands in this translation unit's data segment
 * and is zero at load -- cinit() rebuilds the free chain over it regardless,
 * because "zero at load" is a property of the image and not of the bank (see
 * ttybank.s: nothing zeroes this bank's DUM statics).
 *
 * One block of the pool is given up to alignment, upstream's way; see cinit. */
struct cblock  cfree[NCLIST];
struct cblock *cfreelist;
int            cfreecount;
int            nclist = NCLIST;
char           cwaiting;

/* The C-to-kernel direction of the seam (src/kernel/tty/kc_sys.s).  Upstream
 * calls wakeup() directly; here the kernel's wakeup is core-bank assembly and
 * a cross-bank call has to go through an RTL shim. */
extern void kc_wakeup();

/* clist_copy -- move `n` bytes, SOURCE FIRST.
 *
 * Upstream writes bcopy(); kernel C links no libkern, and this tree's other
 * ports open-code the same loop (ufs_lookup.c's ufs_dircopy names the reason
 * at length).  The argument order is bcopy's deliberately, because these call
 * sites are read against upstream's.
 *
 * FORWARD, AND NEITHER CALLER NEEDS MORE: q_to_b copies out of the pool into a
 * caller's buffer and b_to_q copies in.  The two regions are never the same
 * storage, so overlap does not arise. */
static void
clist_copy(src, dst, n)
char *src;
char *dst;
int   n;
{
    int i;

    for (i = 0; i < n; i++)
        dst[i] = src[i];
}

/*
 * Initialize clist by freeing all character blocks.  (Once-only routine.)
 *
 * From 2.11BSD's init_main.c.  THE ROUNDING IS UPSTREAM'S AND IT IS WHY
 * NOTHING HAS TO ALIGN cfree: the pool's base is pushed up to the next CBLOCK
 * boundary and the chain starts there, so at most one block is lost and every
 * block on the chain satisfies the CROUND masks by construction.
 */
cinit()
{
    register int ccp;
    register struct cblock *cp;

    ccp = (int)cfree;
    ccp = (ccp + CROUND) & ~CROUND;
    for (cp = (struct cblock *)ccp; cp <= &cfree[nclist - 1]; cp++) {
        cp->c_next = cfreelist;
        cfreelist = cp;
        cfreecount += CBSIZE;
    }
}

/*
 * Character list get/put
 */
getc(p)
    register struct clist *p;
{
    register struct cblock *bp;
    register int c, s;

    s = spltty();
    if (p->c_cc <= 0) {
        c = -1;
        p->c_cc = 0;
        p->c_cf = p->c_cl = NULL;
    } else {
        c = *p->c_cf++ & 0377;
        if (--p->c_cc<=0) {
            bp = (struct cblock *)(p->c_cf-1);
            bp = (struct cblock *)((int)bp & ~CROUND);
            p->c_cf = NULL;
            p->c_cl = NULL;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            if (cwaiting) {
                kc_wakeup(&cwaiting);
                cwaiting = 0;
            }
        } else if (((int)p->c_cf & CROUND) == 0){
            bp = (struct cblock *)(p->c_cf);
            bp--;
            p->c_cf = bp->c_next->c_info;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            if (cwaiting) {
                kc_wakeup(&cwaiting);
                cwaiting = 0;
            }
        }
    }
    splx(s);
    return (c);
}

/*
 * copy clist to buffer.
 * return number of bytes moved.
 */
q_to_b(q, cp, cc)
    register struct clist *q;
    char *cp;
{
    register struct cblock *bp;
    register nc;
    int s;
    char *acp;

    if (cc <= 0)
        return (0);
    s = spltty();
    if (q->c_cc <= 0) {
        q->c_cc = 0;
        q->c_cf = q->c_cl = NULL;
        splx(s);
        return (0);
    }
    acp = cp;

    while (cc) {
        nc = sizeof (struct cblock) - ((int)q->c_cf & CROUND);
        nc = MIN(nc, cc);
        nc = MIN(nc, q->c_cc);
        clist_copy(q->c_cf, cp, nc);
        q->c_cf += nc;
        q->c_cc -= nc;
        cc -= nc;
        cp += nc;
        if (q->c_cc <= 0) {
            bp = (struct cblock *)(q->c_cf - 1);
            bp = (struct cblock *)((int)bp & ~CROUND);
            q->c_cf = q->c_cl = NULL;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            if (cwaiting) {
                kc_wakeup(&cwaiting);
                cwaiting = 0;
            }
            break;
        }
        if (((int)q->c_cf & CROUND) == 0) {
            bp = (struct cblock *)(q->c_cf);
            bp--;
            q->c_cf = bp->c_next->c_info;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            if (cwaiting) {
                kc_wakeup(&cwaiting);
                cwaiting = 0;
            }
        }
    }
    splx(s);
    return (cp-acp);
}

/*
 * Return count of contiguous characters
 * in clist starting at q->c_cf.
 * Stop counting if flag&character is non-null.
 */
ndqb(q, flag)
    register struct clist *q;
{
    int cc;
    int s;

    s = spltty();
    if (q->c_cc <= 0) {
        cc = -q->c_cc;
        goto out;
    }
    cc = ((int)q->c_cf + CBSIZE) & ~CROUND;
    cc -= (int)q->c_cf;
    if (q->c_cc < cc)
        cc = q->c_cc;
    if (flag) {
        register char *p, *end;

        p = q->c_cf;
        end = p;
        end += cc;
        while (p < end) {
            if (*p & flag) {
                cc = (int)p;
                cc -= (int)q->c_cf;
                break;
            }
            p++;
        }
    }
out:
    splx(s);
    return (cc);
}

/*
 * Flush cc bytes from q.
 */
ndflush(q, cc)
    register struct clist *q;
    register cc;
{
    register struct cblock *bp;
    char *end;
    int rem, s;

    s = spltty();
    if (q->c_cc <= 0)
        goto out;
    while (cc>0 && q->c_cc) {
        bp = (struct cblock *)((int)q->c_cf & ~CROUND);
        if ((int)bp == (((int)q->c_cl-1) & ~CROUND)) {
            end = q->c_cl;
        } else {
            end = (char *)((int)bp + sizeof (struct cblock));
        }
        rem = end - q->c_cf;
        if (cc >= rem) {
            cc -= rem;
            q->c_cc -= rem;
            q->c_cf = bp->c_next->c_info;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            if (cwaiting) {
                kc_wakeup(&cwaiting);
                cwaiting = 0;
            }
        } else {
            q->c_cc -= cc;
            q->c_cf += cc;
            if (q->c_cc <= 0) {
                bp->c_next = cfreelist;
                cfreelist = bp;
                cfreecount += CBSIZE;
                if (cwaiting) {
                    kc_wakeup(&cwaiting);
                    cwaiting = 0;
                }
            }
            break;
        }
    }
    if (q->c_cc <= 0) {
        q->c_cf = q->c_cl = NULL;
        q->c_cc = 0;
    }
out:
    splx(s);
}

putc(c, p)
    register struct clist *p;
{
    register struct cblock *bp;
    register char *cp;
    register s;

    s = spltty();
    if ((cp = p->c_cl) == NULL || p->c_cc < 0 ) {
        if ((bp = cfreelist) == NULL) {
            splx(s);
            return (-1);
        }
        cfreelist = bp->c_next;
        cfreecount -= CBSIZE;
        bp->c_next = NULL;
        p->c_cf = cp = bp->c_info;
    } else if (((int)cp & CROUND) == 0) {
        bp = (struct cblock *)cp - 1;
        if ((bp->c_next = cfreelist) == NULL) {
            splx(s);
            return (-1);
        }
        bp = bp->c_next;
        cfreelist = bp->c_next;
        cfreecount -= CBSIZE;
        bp->c_next = NULL;
        cp = bp->c_info;
    }
    *cp++ = c;
    p->c_cc++;
    p->c_cl = cp;
    splx(s);
    return (0);
}

/*
 * copy buffer to clist.
 * return number of bytes not transfered.
 */
b_to_q(cp, cc, q)
    register char *cp;
    struct clist *q;
    register int cc;
{
    register char *cq;
    register struct cblock *bp;
    register s, nc;
    int acc;

    if (cc <= 0)
        return (0);
    acc = cc;
    s = spltty();
    if ((cq = q->c_cl) == NULL || q->c_cc < 0) {
        if ((bp = cfreelist) == NULL)
            goto out;
        cfreelist = bp->c_next;
        cfreecount -= CBSIZE;
        bp->c_next = NULL;
        q->c_cf = cq = bp->c_info;
    }

    while (cc) {
        if (((int)cq & CROUND) == 0) {
            bp = (struct cblock *)cq - 1;
            if ((bp->c_next = cfreelist) == NULL)
                goto out;
            bp = bp->c_next;
            cfreelist = bp->c_next;
            cfreecount -= CBSIZE;
            bp->c_next = NULL;
            cq = bp->c_info;
        }
        nc = MIN(cc, sizeof (struct cblock) - ((int)cq & CROUND));
        clist_copy(cp, cq, nc);
        cp += nc;
        cq += nc;
        cc -= nc;
    }
out:
    q->c_cl = cq;
    q->c_cc += acc - cc;
    splx(s);
    return (cc);
}

/*
 * Given a non-NULL pointer into the list (like c_cf which
 * always points to a real character if non-NULL) return the pointer
 * to the next character in the list or return NULL if no more chars.
 *
 * Callers must not allow getc's to happen between nextc's so that the
 * pointer becomes invalid.  Note that interrupts are NOT masked.
 */
char *
nextc(p, cp)
    register struct clist *p;
    register char *cp;
{
    register char *rcp;

    if (p->c_cc && ++cp != p->c_cl) {
        if (((int)cp & CROUND) == 0)
            rcp = ((struct cblock *)cp)[-1].c_next->c_info;
        else
            rcp = cp;
    }
    else
        rcp = (char *)NULL;
    return (rcp);
}

/*
 * Remove the last character in the list and return it.
 */
unputc(p)
    register struct clist *p;
{
    register struct cblock *bp;
    register int c, s;
    struct cblock *obp;

    s = spltty();
    if (p->c_cc <= 0)
        c = -1;
    else {
        c = *--p->c_cl;
        if (--p->c_cc <= 0) {
            bp = (struct cblock *)p->c_cl;
            bp = (struct cblock *)((int)bp & ~CROUND);
            p->c_cl = p->c_cf = NULL;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
        } else if (((int)p->c_cl & CROUND) == sizeof(bp->c_next)) {
            p->c_cl = (char *)((int)p->c_cl & ~CROUND);
            bp = (struct cblock *)p->c_cf;
            bp = (struct cblock *)((int)bp & ~CROUND);
            while (bp->c_next != (struct cblock *)p->c_cl)
                bp = bp->c_next;
            obp = bp;
            p->c_cl = (char *)(bp + 1);
            bp = bp->c_next;
            bp->c_next = cfreelist;
            cfreelist = bp;
            cfreecount += CBSIZE;
            obp->c_next = NULL;
        }
    }
    splx(s);
    return (c);
}

/*
 * Put the chars in the from que
 * on the end of the to que.
 *
 * THE STACK BUFFER IS UPSTREAM'S SIZE, and on this ABI that is 112 bytes
 * (CBSIZE is 28 here, not 30).  It is the largest automatic in the tty bank;
 * the per-pid kernel stacks it will run on are measured by the stack
 * high-water report, which is why this is called out rather than trimmed.
 */
catq(from, to)
    register struct clist *from, *to;
{
    /* bbuf IS 16 BYTES, NOT UPSTREAM'S CBSIZE*4 (112) -- apple/fgx#230.
     *
     * It is a LOCAL, so it sits on the calling task's 512-byte kernel stack
     * (FGX_KSTK_SIZE), and fcc reserves the whole frame ON ENTRY -- so it costs
     * 112 bytes even on the `to->c_cc == 0' path that returns without touching
     * it.  The tty bank compiles with fcc's stack guard OFF, so an overflow
     * does not trap; it scribbles a neighbouring task's stack and presents as
     * corrupted text from a call that reported success.  That is the same
     * hazard OBUFSIZ hit in tty.c at stage 3, and `catq' sits one call deeper
     * still once `ttyinput' has a caller.
     *
     * THE SIZE IS FREE TO CHOOSE: this buffer serves only the branch that
     * MERGES two non-empty queues, and a smaller one simply loops more times.
     * 16 matches the margin OBUFSIZ was given.
     *
     * REDUCED AHEAD OF ITS CALLER, deliberately: nothing reaches this branch
     * until the input side moves, and leaving a known 112-byte frame in the
     * path that increment has to walk would be leaving a mine for it. */
    char bbuf[16];
    register c;
    int s;

    s = spltty();
    if (to->c_cc == 0) {
        *to = *from;
        from->c_cc = 0;
        from->c_cf = NULL;
        from->c_cl = NULL;
        splx(s);
        return;
    }
    splx(s);
    while (from->c_cc > 0) {
        c = q_to_b(from, bbuf, sizeof bbuf);
        (void) b_to_q(bbuf, c, to);
    }
}
