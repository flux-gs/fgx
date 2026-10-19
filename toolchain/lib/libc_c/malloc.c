/* ---- malloc family: sbrk-backed, first-fit, BSD shape ---------------------
 * The heap is the tail of the process DATA segment, grown by sbrk(2) from
 * `end` — exactly BSD, and exactly what the kernel already provides:
 * _Sys_Brk (process.s) keeps the break in the task's own data bank, so
 * snapshot-fork's pair-0 copy carries the heap with the image.
 *
 * This REPLACES the previous SYS_MALLOC32 kernel-arena backing, which was a
 * correctness bug, not just a style one: the shared kernel arena is
 * deliberately NOT part of fork's mutable set (process.s:1233-1237), so a
 * fork child's heap writes leaked into the parent while its data-bank writes
 * were rolled back at exec.  tcsh hit exactly that — its child's pflushall()
 * zeroed the parent's live job ring, leaving no member with
 * p_pid == p_jobid, and pendjob/pprint spun forever after any pipeline
 * (issue #4).  Every forking port had the same landmine under it.
 *
 * BSD semantics kept deliberately: when the break cannot grow, malloc fails
 * with ENOMEM rather than escaping to kernel memory.  The ceiling is the
 * data bank's free span [end, $FFFE) — ~36 KB for tcsh, ~51 KB for bsh.
 *
 * LARGE requests (>= $F000, or anything over 64 KB) cannot come from the break
 * at all — the break lives inside one bank — so they go to SYS_MALLOC32, which
 * hands back a DEDICATED bank-aligned MM block at bank:0000 spanning as many
 * banks as the request needs.  That is the 4.4BSD shape, not a workaround:
 * 2.11BSD had no large path (64 KB of data space; ed.c spools to /tmp instead),
 * 4.2/4.3BSD on a flat VAX never needed one, and 4.4BSD's malloc services large
 * requests from a separate anonymous mmap rather than from the contiguous
 * break — with fork COPYING those mappings.  _Kmalloc_Big's dedicated block is
 * that mapping in all but name, and since 2026-08-02 fork copies it too (the
 * kind-4 rows carry an owner pid; see _Fork_Snapshot).  Routing it back here
 * restores what #11 broke: the heap ceiling fell to a single data bank and
 * malloc(80000L) started failing outright.
 *
 * free() tells the two apart by SHAPE: a big block is bank-aligned at OFFSET 0,
 * and the sbrk heap can never produce offset 0 (its break starts at `end', and
 * a payload pointer is a further _MHDR past its header).  That is the same test
 * the kernel's _Sys_Free uses.
 *
 * Free list: singly linked, ADDRESS-ORDERED, with forward+backward coalesce
 * on free so adjacent frees merge instead of fragmenting.  Blocks carry a
 * 6-byte header (far next + total size).  Sizes are rounded even — the
 * PDP-11/2.11BSD word-alignment convention fcc already follows.
 *
 * Pointer comparisons use the 16-bit OFFSET only (via unsigned long -> unsigned):
 * the whole heap lives in one bank, so offsets order it correctly, and this
 * avoids leaning on far-pointer relational codegen. */

struct _mblk {
    struct _mblk *m_next;               /* next FREE block, address-ordered */
    unsigned      m_size;               /* TOTAL bytes, header included */
};

static struct _mblk *_mfreelist;        /* per-process (libc statics live in
                                         * the program's data segment) */

#define _MHDR   ((unsigned)sizeof(struct _mblk))
#define _MOFF(p) ((unsigned)(unsigned long)(p))     /* 16-bit heap offset */

/* Grow the break by `need` bytes and return the old break, or NULL.
 *
 * ONE CALL COVERS THE WHOLE RANGE.  sbrk(2)'s increment is an unsigned addend
 * that libc adds to the break before the kernel validates the sum -- BSD's
 * shape, `add curbrk,r0' (2.11BSD pdp/sys/sbrk.s) -- so a request with bit 15
 * set is a grow like any other.  This used to split anything over 0x7FFE into
 * two calls and roll the first back on failure, because the increment was
 * signed and reached the kernel as a SHRINK.
 *
 * `p == 0' and an offset of 0xFFFF are the two failure shapes: NULL for a
 * refusal that came back as a null far pointer, and 0xFFFF for sbrk's
 * (char *)-1.  Plain sbrk since #13 restored its POSIX -1 -- malloc's whole
 * contract is returning NULL when the heap is out, and it no longer needs a
 * private back door to get a checkable failure out of the break. */
static char *_mgrow(unsigned need)
{
    char *p;
    unsigned cur = _MOFF(sbrk(0));

    /* A grow that passes the end of the bank WRAPS: sbrk adds in 16 bits and
     * the kernel takes the sum for a shrink, which it allows above the floor.
     * Refuse it here, as upstream does before it asks -- 2.11BSD
     * usr/lib/libc/gen/malloc.c:141, `if (q+temp+GRANULE < q) return(NULL);'.
     * The caller's arithmetic is where BSD puts this (proc.c, update #58). */
    if ((unsigned)(cur + need) < cur)
        return (char *)0;
    p = sbrk((int)need);
    return (p == (char *)0 || _MOFF(p) == 0xFFFF) ? (char *)0 : p;
}

/* A dedicated MM block: SYS_MALLOC32 (#96) takes A = size lo16, X = size hi16
 * and returns the base bank in A with the offset (always 0) in Y. */
static void *_malloc_big(unsigned long size)
{
    unsigned bank = __syscall(96, (unsigned)size, (unsigned)(size >> 16), 0);
    if (__syscall_c() == 0) {
        errno = (int)(bank & 0xFF);         /* ENOMEM from the kernel */
        return (void *)0;
    }
    return (void *)(((unsigned long)(bank & 0xFF) << 16)
                    | (unsigned long)__syscall_y());
}

void *malloc(unsigned long size)
{
    struct _mblk *p, *prev, *tail;
    unsigned need, rest;

    if (size == 0) {
        errno = ENOMEM;
        return (void *)0;
    }
    if (size >= 0xF000UL)                   /* past one bank of break: MM block */
        return _malloc_big(size);
    need = ((unsigned)size + 1) & 0xFFFE;   /* even payload */
    need += _MHDR;

    prev = (struct _mblk *)0;
    for (p = _mfreelist; p != (struct _mblk *)0; p = p->m_next) {
        if (p->m_size >= need) {
            rest = p->m_size - need;
            if (rest >= _MHDR + 2) {        /* split; tail stays free */
                tail = (struct _mblk *)((char *)p + need);
                tail->m_size = rest;
                tail->m_next = p->m_next;
                p->m_size = need;
                if (prev != (struct _mblk *)0)
                    prev->m_next = tail;
                else
                    _mfreelist = tail;
            } else {                        /* take the whole block */
                if (prev != (struct _mblk *)0)
                    prev->m_next = p->m_next;
                else
                    _mfreelist = p->m_next;
            }
            return (void *)((char *)p + _MHDR);
        }
        prev = p;
    }

    p = (struct _mblk *)_mgrow(need);       /* grow the break */
    if (p == (struct _mblk *)0) {
        errno = ENOMEM;
        return (void *)0;
    }
    p->m_size = need;
    p->m_next = (struct _mblk *)0;
    return (void *)((char *)p + _MHDR);
}

void free(void *ptr)
{
    struct _mblk *b, *p, *prev;
    unsigned long lp;

    if (ptr == (void *)0)
        return;
    lp = (unsigned long)ptr;
    if ((unsigned)lp == 0) {
        /* Offset 0 = a dedicated MM block.  SYS_FREE (#63) takes A.lo = bank,
         * X = offset; the kernel disposes the whole block and tombstones its
         * row.  It honours the free only from the block's OWNER, so a fork
         * child freeing a block it inherited in place is a no-op -- which is
         * the same rollback the child's data-bank writes get. */
        __syscall(63, (unsigned)(lp >> 16) & 0xFF, 0, 0);
        return;
    }
    b = (struct _mblk *)((char *)ptr - _MHDR);

    prev = (struct _mblk *)0;
    p = _mfreelist;
    while (p != (struct _mblk *)0 && _MOFF(p) < _MOFF(b)) {
        prev = p;
        p = p->m_next;
    }
    b->m_next = p;
    if (prev != (struct _mblk *)0)
        prev->m_next = b;
    else
        _mfreelist = b;

    /* coalesce forward, then backward */
    if (p != (struct _mblk *)0 && _MOFF(b) + b->m_size == _MOFF(p)) {
        b->m_size += p->m_size;
        b->m_next = p->m_next;
    }
    if (prev != (struct _mblk *)0 && _MOFF(prev) + prev->m_size == _MOFF(b)) {
        prev->m_size += b->m_size;
        prev->m_next = b->m_next;
    }
}

void *realloc(void *old, unsigned long size)
{
    struct _mblk *b;
    void *nu;
    unsigned oldpay;

    if (old == (void *)0)
        return malloc(size);
    /* No big-block realloc, in EITHER direction, and the refusal is the whole
     * feature: a dedicated MM block carries no length libc can read, so a grow
     * would copy from past the end of the old block, and handing an offset-0
     * pointer to the sbrk-heap path below would take a phantom header six bytes
     * BEFORE the block.  (That second one is a real hole this closes -- the
     * pre-#4 allocator refused only on the new size and passed an offset-0 old
     * pointer straight to SYS_REALLOC.)  No caller needs it: the growth path
     * that matters runs through the ordinary heap.  Fail closed, as documented
     * in stdlib.h. */
    if (size >= 0xF000UL || (unsigned)(unsigned long)old == 0) {
        errno = ENOMEM;
        return (void *)0;
    }
    nu = malloc(size);
    if (nu == (void *)0)
        return (void *)0;
    b = (struct _mblk *)((char *)old - _MHDR);
    oldpay = b->m_size - _MHDR;             /* header carries the old length,
                                             * so realloc no longer has the
                                             * arena version's blind spot */
    memcpy(nu, old, (int)(oldpay < (unsigned)size ? oldpay : (unsigned)size));
    free(old);
    return nu;
}

