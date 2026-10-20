/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/clist.h
 *   Ported from usr/sys/h/clist.h, 2.11BSD.
 *   Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* clist.h -- the raw block a clist is made of.
 *
 * Upstream verbatim apart from the UCB_CLIST arm, which is the PDP-11 split
 * I/D variant that maps the clist pool into segment 5 with mapseg5(): FGX has
 * no MMU and no segment registers, so the #else branch is the whole file.
 *
 * THE BLOCK IS 32 BYTES AND THAT IS LOAD-BEARING.  tty_subr.c finds a block's
 * base from a pointer into it with `(int)p & ~CROUND`, so the size must be a
 * power of two and blocks must be aligned to it.  cinit() does the aligning,
 * upstream's way -- see tty_subr.c.
 */
#ifndef _CLIST_H_
#define _CLIST_H_

struct cblock {
    struct cblock *c_next;
    char           c_info[CBSIZE];
};

extern struct cblock  cfree[];      /* the pool itself */
extern struct cblock *cfreelist;    /* head of the free chain */
extern int            cfreecount;   /* free BYTES, not blocks (upstream) */
extern int            nclist;
extern char           cwaiting;     /* someone slept waiting for a block */

/* THE POINTER-RETURNING PRIMITIVES MUST BE DECLARED BEFORE THEY ARE CALLED.
 * K&R gives an undeclared function type int, and fcc warns that "a far-pointer
 * return loses its bank" for exactly this shape -- nextc walks from one cblock
 * into the next and hands back a pointer into it, so an int-typed call site
 * would truncate the answer rather than fail.  tty_subr.c:417 defines it as
 * `char *'; this is the declaration that makes a caller agree. */
extern char          *nextc();       /* next char in the list, or NULL */

/* THE INT-RETURNING PRIMITIVES ARE DECLARED FOR THE WARNING'S SAKE, not for
 * correctness: every one is a K&R definition with no return type, so the
 * implicit int a call site would assume is already right and the generated
 * code is identical either way.  They are here because the comment above only
 * works if the warning MEANS something -- five benign "implicit declaration"
 * lines drown the one that is telling you a far pointer just lost its bank.
 * That is the whole reason nextc is declared, and it is worth as little as
 * this to keep the channel clear. */
extern int            getc();        /* first char, or -1 if empty */
extern int            putc();        /* 0 on success, -1 if no block */
extern int            b_to_q();      /* chars NOT copied */
extern int            unputc();      /* last char removed, or -1 */
extern int            catq();        /* append `from' to `to' */
extern int            ndqb();        /* size of a CONTIGUOUS run at the head */
extern void           ndflush();     /* drop n bytes from the head */

#endif /* _CLIST_H_ */
