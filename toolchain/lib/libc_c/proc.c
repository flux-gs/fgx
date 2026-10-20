/* ---- misc wrappers + first PURE-C conversions (C4 batch 5) -------------- */

int kill(int pid, int sig)
{
    int r = (int)__syscall(37, pid, sig, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int waitpid(int pid, int *status, int options)
{
    /* X=0 tells the kernel to skip its own status write; the store
     * happens here in C — only when a child was reaped AND the ptr is
     * non-NULL (POSIX leaves *status untouched on WNOHANG-nothing). */
    int r = (int)__syscall(82, pid, 0, options);
    if (__syscall_c() == 0) { errno = r; return -1; }
    if (r != 0 && status != (int *)0)
        *status = (int)__syscall_y();
    return r;
}

/* ---- fork train (FGX kernel-fork campaign) --------------------------------
 * fork(2)/brk(2)/sbrk over SYS_FORK=2 and SYS_BRK=17.  vfork(2) is HAND-ASM
 * in libc.s: its child borrows the parent's stack, so the wrapper must be
 * frameless and stash the caller's RTL address in libc data (the same reason
 * BSD libc implemented vfork.s in assembly).  ENOSYS from the kernel until
 * the fork-train kernel stages land — wrappers ship first (toolchain-first
 * ordering). */

int fork()
{
    /* Snapshot fork: parent's mutable banks are saved and restored by the
     * kernel, so an ordinary C frame is fine here (unlike vfork).  Parent:
     * A = child pid; child: A = 0. */
    int pid = (int)__syscall(2, 0, 0, 0);
    if (__syscall_c() == 0) { errno = pid; return -1; }
    return pid;
}

/* SYS_BRK=17 ABI (fork train Stage S): A = the NEW break offset, Y = the
 * bank it is in; returns C=1 + A = OLD break offset + Y = the task's sbrk
 * bank; C=0 + A = errno (ENOMEM below `end' or past the one-bank ceiling,
 * EINVAL for a bank that is not this task's).  The argument is ABSOLUTE, as
 * BSD's syscall has always been -- sbrk's addition happens here. */

void _exit();                   /* defined below; declared here because abort()
                                 * calls it long before that.  An implicit
                                 * declaration is assumed int-returning, which
                                 * is the shape that produced the
                                 * signal()-returns-int bug (2026-07-26) */

/* sbrk(2) -- POSIX: (char *)-1 + errno on refusal, and it RETURNS.
 *
 * It used to _exit(136) instead, and the reason given was that "the vendored
 * source is pristine by policy and cannot be taught to check".  That was wrong
 * on the facts, which is why this is back (apple/fgx#13):
 *
 *   - 2.11BSD ALREADY checks.  `fault.c:30` is
 *         IF setbrk(brkincr) == -1 THEN error(nospace); FI
 *     so the test, the message and the recovery are all upstream.  What FGX
 *     lacks is the write-fault that DELIVERS that signal, so on this OS the
 *     handler is unreachable code rather than absent code.  The fix is to route
 *     BSD's own response to the call site FGX can actually reach (stak.c
 *     locstak), not to redefine sbrk out from under it.
 *   - the tree already had a documented vendor exception (service.c, listed
 *     in src/userland/sh/README.md), so "cannot be taught" was not a real
 *     constraint.
 *   - and there are no unchecked callers left: sh's setbrk now checks, csh's
 *     alloc11.c always did (`char *sbrk();` + `if((INT)q == -1)`), and dd.c
 *     always did.
 *
 * What this buys: an interactive shell that runs out of memory prints
 * `sh: no space` and returns to its prompt instead of dying, which is the BSD
 * behavior; and malloc no longer needs a private back door to get a -1.
 *
 * TASK_EXIT_HEAPFULL (136) survives as a CALLER'S choice -- the kernel still
 * names that death `heap exhausted: killed pid $NN` -- but libc no longer makes
 * it for you.  /testbin/heapkill is a program that opts into it.
 */
/* THE HEAP DESCRIPTOR IS FGX'S `minbrk' AND `curbrk'.  BSD's libc gets both
 * from the linker and caches the break, because the syscall has no query:
 *
 *     minbrk: _end
 *     curbrk: _end
 *
 * -- 2.11BSD usr/lib/libc/pdp/sys/sbrk.s, and word for word 4.3BSD-Reno
 * lib/libc/hp300/sys/sbrk.s, which differs only in register width.  FGX has no
 * `end' symbol to link against, but it does not need one: the kernel PUBLISHES
 * both numbers in the process's own data bank, HEAP_BASE ($FFFA) being `end'
 * and HEAP_BRK ($FFFE) the live break, seeded by the loader and maintained by
 * SYS_BRK -- "four words at the very top of the bank make it SELF-DESCRIBING"
 * (include/kernel.s).  Reading them is better than caching, not a concession:
 * a cache would have to be re-seeded after every fork and exec, and a read
 * cannot go stale.
 *
 * The bank comes from the address of a libc static, which is in the process's
 * data segment by construction. */
static int _brkanchor;

static unsigned long _heapbank()
{
    return (unsigned long)(char *)&_brkanchor & 0xFF0000L;
}

static unsigned _heapword(unsigned long off)
{
    return *(unsigned *)(_heapbank() | off);
}

/* THE INCREMENT IS AN UNSIGNED 16-BIT ADDEND, WHICH IS WHAT BSD'S IS, and the
 * whole of sbrk is that addition:
 *
 *     mov     2(sp),r0        / grab increment
 *     beq     1f              / (bop out early if zero)
 *     add     curbrk,r0       / calculate and pass break address
 *
 * -- 2.11BSD sbrk.s; Reno's hp300 sbrk.s is `movl curbrk,d0 / addl d0,sp@(4)'.
 * The sum wraps in the machine's word and the KERNEL validates the result, so
 * a single grow reaches the whole address space -- which is why upstream's own
 * fsck(8) can ask for `MAXDATA - sbrk(0) - sizeof(int)', some 34 KB on a
 * 16-bit machine, in one call.
 *
 * NOTHING DISTINGUISHES A WRAPPED GROW FROM A SHRINK, and that is upstream's
 * position rather than an omission here.  2.11BSD update #58 is this bug in
 * the wild -- "a negative increment to sbrk() was being calculated when the
 * text size was greater than 32kb.  This released part of the program's .bss
 * segment back to the system causing a segmentation violation" -- and the fix
 * was to make the CALLER's arithmetic unsigned (int -> unsigned int in
 * lib/libc/pdp/csu/mon.c), not to add a guard here.  sbrk.s was never touched
 * again; its last revision, 2.6 in 1995, only refactored the error return.
 *
 * What FGX does not copy is upstream's response to a break below the floor.
 * There the kernel CLAMPS (`if (n < 0) n = 0', kern_mman.c in both trees), so
 * a wrapped grow silently empties the heap; here it is refused with ENOMEM,
 * which is a return value every caller in the tree already tests. */
char *sbrk(int incr)
{
    unsigned cur = _heapword(0xFFFEL);          /* curbrk */
    unsigned nsiz;
    unsigned old;

    if (incr == 0)
        return (char *)(_heapbank() | (unsigned long)cur);

    nsiz = cur + (unsigned)incr;                /* `add curbrk,r0' */
    old = (unsigned)__syscall(17, nsiz, 0, (unsigned)(_heapbank() >> 16));
    if (__syscall_c() == 0) { errno = (int)old; return (char *)-1; }
    return (char *)(((unsigned long)__syscall_y() << 16) | (unsigned long)old);
}

/* brk(2) CLAMPS UP TO minbrk, which is upstream's, in both trees:
 *
 *     cmp     2(sp),minbrk    / break request too low?
 *     bhis    1f
 *     mov     minbrk,2(sp)    / yes, knock the request up to minbrk
 *
 * -- 2.11BSD brk.s; Reno's is the same three instructions in m68k.  It is what
 * makes the kernel's floor unreachable through the documented path, which is
 * in turn why refusing there rather than clamping costs no correct caller
 * anything. */
int brk(char *addr)
{
    unsigned long lp = (unsigned long)addr;
    unsigned      off = (unsigned)lp;
    unsigned      min = _heapword(0xFFFAL);     /* minbrk == `end' */
    int           r;

    if (off < min)
        off = min;
    r = (int)__syscall(17, off, 0, (unsigned)(lp >> 16));
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}


/* reboot(2).  2.11BSD's number is 55 and SYS_BORDER holds it here, so the
 * syscall is FGX-local 116 -- loader.s says so where it is defined.
 *
 * IT DOES NOT RETURN WHEN IT WORKS, so the only code path back is a refusal,
 * and upstream's reboot(8) is written that way: `reboot(howto); perror(myname);
 * kill(1, SIGHUP); exit(EX_OSERR);' -- everything after the call is the
 * failure case. */
int reboot(howto)
int howto;
{
    int r = (int)__syscall(116, (unsigned)howto, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
