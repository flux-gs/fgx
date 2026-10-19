/* ttyparam.h -- the scalar types, pool sizes and interrupt-level primitives
 * the FGX tty layer needs.
 *
 * 2.11BSD's sys/param.h and sys/types.h, reduced to what tty_subr.c and tty.c
 * use.  The VFS has the same file for the same reason (src/kernel/vfs/
 * fsparam.h); the two are separate because they live in separate banks and
 * neither should acquire the other's constants by accident.
 *
 * fcc widths, MEASURED rather than assumed: short 2, int 2, long 4, and
 * POINTERS 4.  Everything the clist code derives from sizeof is derived, never
 * written as a literal, because a pointer here is twice a PDP-11's.
 */
#ifndef _TTYPARAM_H_
#define _TTYPARAM_H_

#ifndef NULL
#define NULL    0
#endif

/* PER-TYPE GUARDS ON THE TWO THAT OVERLAP.  src/kernel/tty/ttyparam.h and
 * src/kernel/vfs/fsparam.h each declare the scalar types their own bank needs,
 * and dev_t and off_t are in both -- so a file that needs a tty AND a uio
 * (tty_probe, and ttread when it lands) got `expected typedef name' on the
 * second declaration and could not include both.  Guarding the two that
 * overlap costs four lines and lets either header come first; merging the two
 * headers, or making one include the other, would put a bank's types in the
 * other bank's build for one caller. */
#ifndef _FGX_HAVE_DEV_T
#define _FGX_HAVE_DEV_T
typedef unsigned short  dev_t;
#endif
#ifndef _FGX_HAVE_OFF_T
#define _FGX_HAVE_OFF_T
typedef long            off_t;
#endif
typedef char           *caddr_t;
typedef unsigned char   u_char;
typedef unsigned short  u_short;

/* THE ERRNOS THE TTY LAYER USES, restated here for the reason
 * src/kernel/vfs/fsparam.h restates its own: kernel C links no libc and cannot
 * include <errno.h>.  tools/check_kernelc_errno.py compares every entry below
 * against toolchain/include/errno.h on every build, so a copy that drifts
 * fails rather than returning someone else's error.
 */
#define EPERM           1       /* operation not permitted */
#define EIO             5       /* I/O error */
#define ENXIO           6       /* no such device -- ttioctl's TIOCSETD refusal
                                 * of a discipline number past nldisp */
#define EAGAIN          11      /* resource temporarily unavailable */
#define EACCES          13      /* permission denied -- TIOCSTI from a
                                 * non-owner on someone else's terminal */
#define EFAULT          14      /* bad address -- ureadc's refusal of a USER
                                 * pointer, the same one uiomove makes */
#define EWOULDBLOCK     EAGAIN  /* ttwrite's IO_NDELAY answer; BSD's alias */
#define EBUSY           16      /* device busy */
#define ENODEV          19      /* no such device */
#define ENOTTY          25      /* inappropriate ioctl for device */
#define EINTR           4       /* interrupted system call -- ttwrite's
                                 * background gate; see the note there on why
                                 * it answers this rather than retrying */

/* CBLOCK is the size of a clist block, must be power of 2 (param.h:73-76).
 *
 * CBSIZE COMES OUT SMALLER HERE THAN UPSTREAM, and the arithmetic is upstream's
 * unchanged: a cblock is one link plus the rest, and the link is a pointer.  On
 * the PDP-11 that is 2 bytes and CBSIZE is 30; on fcc it is 4 and CBSIZE is 28.
 * sizeof(struct cblock) stays 32 either way, which is the property every
 * CROUND mask in tty_subr.c depends on -- so the block size is what is pinned,
 * and the payload is what gives.
 */
#define CBLOCK  32
#define CBSIZE  (CBLOCK - sizeof(struct cblock *))      /* data chars/clist */
#define CROUND  (CBLOCK - 1)                            /* clist rounding */

/* NCLIST -- how many cblocks exist, for all lines together.
 *
 * 32 blocks is 1,024 bytes, which is the number that makes the eventual swap
 * memory-neutral: today's _ttyTable is DS 5*302 = 1,510 bytes, 1,280 of it five
 * FIXED 256-byte TTY_CanonBuf.  A shared pool of 1,024 covers the same five
 * lines and does not reserve the worst case per line.
 *
 * SIZED 2026-08-26, AND UPSTREAM'S FORMULA IS NOT THE ANSWER HERE.  2.11BSD
 * `usr/sys/conf/param.c:54' is
 *
 *      #define NCLIST (20 + 8 * MAXUSERS)
 *      #if NCLIST > (8192 / 32)        -- 8K / sizeof (struct cblock)
 *
 * and the SAME FILE sizes NPROC as `(10 + 7 * MAXUSERS)'.  FGX's NPROC is 12,
 * which solves to MAXUSERS below one; at MAXUSERS 1 upstream would give NPROC
 * 17 and NCLIST 28, so the old 32 was already MORE generous than upstream's
 * smallest configuration, and the formula alone says do not grow.
 *
 * WHAT A MISS COSTS, AND THE FIRST WRITING OF THIS COMMENT GOT IT WRONG.  It
 * said a pool miss costs a PDP-11 a clock tick and FGX a second.  It costs both
 * of them up to a second, and that is BSD's own design rather than a
 * divergence: `lbolt' is woken by `schedcpu', whose header says "Recompute
 * process priorities, once a second" and which re-arms itself with
 * `timeout(schedcpu, (caddr_t)0, hz)' (kern_synch.c:31-72).  FGX's period is
 * the same number from the same reasoning -- LBOLT_TICKS 60 against a 60 Hz
 * VBL (include/kernel.s:1474).
 *
 * So the reason to be generous is NOT that FGX pays more per miss.  It is that
 * a miss is expensive on any system, so the pool wants to be big enough that
 * exhaustion is rare -- and upstream sizes BELOW the sum of the watermarks on
 * purpose (GENERIC's 52 blocks are 1,456 bytes against one EXTB line's hiwat of
 * 2,000), accepting stutter under load on a machine with sixteen terminals.
 * FGX has five lines and 32 bytes a block against a bank with headroom, so the
 * trade upstream had to make is one this machine can decline.
 *
 * WHAT IS GENUINELY FGX'S IS THE TAIL, not the second, AND IT IS NARROWER THAN
 * IT SOUNDS.  2.11BSD writes `++runrun' beside the wake -- its own comment
 * there is "swtch at least once a second" -- to force a reschedule.  Model A
 * has no such flag, so a task that reaches NO syscall boundary reaches neither
 * drain site and the wake arrives late.
 *
 * BUT AN ORDINARY COMPUTE LOOP IS NOT SUCH A TASK.  P2' has fcc emit
 * `JSR _fcc_safepoint' at every loop back-edge; the safepoint reads the yield
 * mirror and, when the quantum has set it, issues SYS_YIELD -- a real syscall,
 * whose exit runs `_Sys_CheckSignal', which is where `_Lbolt_Wake' lives.  The
 * quantum sets the mirror every QUANTUM_TICKS (4 VBLs), so a spinning C program
 * crosses the boundary about fifteen times a second and the wake is prompt.
 *
 * WHAT IS LEFT IS THREE NAMED CASES: hand-written assembly loops, code built
 * `-fno-safepoints' (kernel C, which Model A never preempts anyway), and
 * `goto'-formed loops, which receive no safepoint -- parse_stmt.c emits at
 * S_WHILE, S_DO and the `for' arm and nowhere else.  That last one is a
 * TOOLCHAIN gap with a fix in the toolchain, not an argument for a different
 * preemption model.  `_Lbolt_Wake's header in sched.s states the divergence;
 * this file only inherits it.
 *
 * MEASURED, not projected.  Six frame-sampled reads of the free chain through
 * a vi-over-pty session found the pool ENTIRELY UNUSED -- 64 of 64 free at
 * every sample -- because `tty_oproc' drains `t_outq' inside `ttstart' and the
 * pty rings hold what would otherwise be queued.  So today's usage cannot size
 * anything: the demand T4 moves into this pool is NEW demand.  The numbers it
 * was sized against instead:
 *
 *      one pty at hiwat, B9600      650 bytes    24 blocks
 *      both ptys at hiwat         1,300 bytes    47 blocks
 *      parity with today's rings    256 bytes    10 blocks (2 x PTY_RING_SZ)
 *
 * 64 holds both ptys at their watermark with room over, and it costs 32 bytes
 * a block in EVERY config -- the binding constraint being the tightest probe
 * half, not the shipping bank.  Measured across the four halves: 48 leaves
 * ttyprobe2 with 2,168 free, 64 leaves 1,656, and 96 leaves 632, which is the
 * neighbourhood where this campaign has already watched a half stop being able
 * to take a case.
 *
 * The failure mode stays visible rather than silent (putc returns -1 and the
 * caller waits), and `clist_probe' case 64 asserts that every block the pool
 * was sized for actually reached the chain -- cases 3-5 pass just as well on
 * half a pool.
 */
#define NCLIST  64

/* Baud-rate CODES, `usr/sys/h/ttydev.h'.  Only the one FGX seeds is here: no
 * FGX line has a baud rate, so `t_ispeed'/`t_ospeed' are a nominal value that
 * `stty' prints and `ttwrite' indexes the watermark tables with.  Upstream's
 * pty open uses EXTB (15); FGX has stored B9600 since the core kept the sgttyb
 * image, and stage 2d moved the field rather than the value. */
#define B9600   13      /* ttydev.h:31 */

/* MIN, used by q_to_b and b_to_q.  2.11BSD has it in param.h. */
#define MIN(a,b)        (((a) < (b)) ? (a) : (b))

/*
 * spltty()/splx() -- UPSTREAM'S INTERRUPT-PRIORITY BRACKET, AND IT IS EMPTY
 * HERE.  This is a divergence, and it is a divergence with an expiry date.
 *
 * Upstream raises to tty level around every clist mutation because a device
 * interrupt can call putc() while a syscall is inside getc().  FGX cannot have
 * that race today for a structural reason: kernel C runs on FGX_DP_KERNELC,
 * which include/kernelc.s documents as "a SINGLETON: kernel C ... runs to
 * completion inside a syscall, which is what makes one register file safe.  Two
 * C contexts live at once would share it and corrupt each other."  So there is
 * exactly one C context at a time, and nothing calls these from an interrupt.
 *
 * THAT STOPPED BEING TRUE AT T6 INCREMENT 1 (apple/fgx#108), which gave
 * interrupt-time C a register file of its own -- so this is increment 2, and
 * the promise the paragraph above made is kept: the call sites did not move,
 * only what they mean.  Seventy of them, all upstream's, all no-ops until now.
 *
 * THE BODIES ARE IN src/kernel/tty/kc_sys.s and the primitive is the 65816's I
 * flag, which is what THIS KERNEL'S SCHEDULER ALREADY CALLS spl -- sched.s's
 * `_sleep' asks its callers to "re-test ... under SEI (spl)".  So this is not a
 * mechanism bolted on beside the existing one; it is the existing one, named.
 * Read kc_spltty's header for what it returns and why a sleep inside a region
 * is upstream's shape rather than a hazard.
 *
 * AN UNBALANCED PAIR IS NOW A HANG, not a lost optimisation: nothing lowers the
 * mask on the way out, and the heartbeat IS the VBL.  `ttyunblock' had exactly
 * that shape, carried verbatim from upstream where it is a dead store.
 * tools/check_spl_balance.py holds the rule.
 */
extern int kc_spltty();
extern void kc_splx();

#define spltty()        kc_spltty()
#define splx(s)         kc_splx(s)

#endif /* _TTYPARAM_H_ */
