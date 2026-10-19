/* ---- process / directory syscalls hoisted from per-tool stubs (Stage B1) --
 * Plain-named libc entries so the hand-asm *_stubs.s (jsh, ps, killtest, …)
 * can retire.  Each mirrors its old asm stub's register ABI (A=arg1, X=arg2,
 * Y=arg3) and return convention exactly; pointer args pass the DBR-bank offset,
 * same as the stubs did. */

/* wait(&s) IS waitpid(-1, &s, 0), and going through waitpid is what makes the
 * status store bank-correct.  The old body passed (unsigned)status to SYS_WAIT,
 * which DROPS the pointer's bank: the kernel then wrote the status at that
 * offset in the caller's DATA bank.  That worked only while every caller passed
 * a global.  bsh's await() (2.11BSD sh/service.c) does `INT w; ... wait(&w)` --
 * an fcc local, so &w is a BANK-0 hardware-stack address, the status landed in
 * the data bank instead, w stayed 0, and every `$?` read back 0.  waitpid()
 * passes X=0 so the kernel skips its own write and stores through the real far
 * pointer from C, which honors whatever bank the caller's object lives in. */
int wait(int *status)                     /* reap any child */
{
    return waitpid(-1, status, 0);
}

/* wait3(&status, options, &rusage) -- the BSD job-control reap.  Delegates to
 * waitpid() for the SAME reason wait() does, and it matters more here: tcsh's
 * sh.proc calls `wait3(&w, ...)` with a STACK-LOCAL `union wait w`, so &w is a
 * bank-0 hardware-stack address.  Handing that pointer to the kernel drops its
 * bank and the status lands at that offset in the caller's DATA bank instead --
 * the defect that made every bsh `$?` read 0 (fixed 6343b62f).  Going through
 * waitpid passes X=0, so the kernel skips its own write and the store happens in
 * C through the real far pointer, honouring whatever bank the caller's object
 * lives in.
 *
 * FGX keeps no per-process resource accounting, so *rusage is ZEROED rather
 * than filled.  Zeroing is deliberate: BSD callers read the struct
 * unconditionally, so leaving it untouched would hand them stack garbage.  A
 * caller that PRINTS it therefore reports zeros -- that is tcsh's `time`
 * builtin, which is not in the FGX tcsh build.  (getrusage(2) is declared in
 * sys/resource.h but has no implementation; a port calling it still fails to
 * link, which is the honest outcome until FGX has accounting to report.) */
int wait3(int *status, int options, struct rusage *rusage)
{
    if (rusage != (struct rusage *)0) {
        char *p = (char *)rusage;
        int   n = (int)sizeof(struct rusage);
        while (n-- > 0)
            *p++ = 0;
    }
    return waitpid(-1, status, options);
}

int setpgid(int pid, int pgid)            /* SYS_SETPGID=80 */
{
    int r = (int)__syscall(80, pid, pgid, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* getpgrp(pid) -- the 2.11BSD shape (getpgrp(2): "pgrp = getpgrp(pid)"), NOT
 * the POSIX no-argument form.  BSD ports call it with an argument -- tcsh's
 * tc.os.h defines `mygetpgrp() getpgrp(0)` -- and this is the port source of
 * truth, so libc follows it.  The mismatch was invisible while libc's
 * signatures were hand-listed; harvesting them from these sources surfaced it
 * as a hard arity error at tcsh's first call site.
 *
 * ANY LIVE PID, as BSD's does.  This used to accept pid == 0 (self) only and
 * report ESRCH for anything else, because SYS_GETPGRP ignored its argument and
 * always answered for the caller -- refusing was better than a wrong answer
 * dressed as a right one.  The kernel now does BSD's pfind-then-read
 * (kern_prot.c getpgrp()), so the restriction is gone and the wrapper is a
 * plain pass-through; ESRCH now comes from the kernel and means what it says. */
int getpgrp(int pid)                      /* SYS_GETPGRP=81 */
{
    return (int)__syscall(81, pid, 0, 0);
}

/* listdir/procs -> lib/libfgx_c/libfgx.c (BSD-foundations P1). */

/*----------------------------------------------------------------------------
 * THE MOUNT SURFACE: getfsstat(2), statfs(2), getmntinfo(3).  apple/fgx#329.
 *
 * `struct statfs' comes from <sys/mount.h> and is the KERNEL's declaration --
 * 4.3BSD-Reno's field order, 100 bytes, compared against src/kernel/vfs/mount.h
 * by tools/check_statfs_layout.py on every build.  It used to be a 58-byte
 * ProDOS volume record that shared only the name.
 *--------------------------------------------------------------------------*/

/* getfsstat(2).  `buf' may be null to ask only how many mounts there are,
 * which is how getmntinfo(3) below sizes its allocation -- see the kernel
 * side's note on why that arm is load-bearing.
 *
 * THE PROTOTYPE MATCHES THE HEADER NOW.  It was `char *buf' here against
 * `struct statfs *buf' in <sys/mount.h>: both four bytes, so nothing broke,
 * and fcc's --sigs cross-TU check (apple/fgx#327) is what makes an
 * inconsistency like that worth not having.
 *
 * AND IT REPORTS FAILURE.  The old body ended `if (__syscall_c() == 0) return
 * 0; /* the handler does not fail *``/' -- true of a handler that walked a
 * table in the same bank, false of one that crosses to the far bank and can
 * answer ENXIO.  Returning 0 for an error made "no filesystems" and "the call
 * failed" the same answer to df(1), and getmntinfo(3) tests `< 0'. */
int getfsstat(struct statfs *buf, int bufsize, int flags)
{
    unsigned long lp = (unsigned long)buf;
    int r = (int)__syscall_db(67, (unsigned)(lp >> 16), (unsigned)lp,
                              bufsize, flags);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* statfs(2).  THE PATH IS STAGED AND THE STRUCT LANDS IN SCRATCH, which is
 * stat(2)'s model in stat.c and is there for a reason this call rediscovered
 * the hard way.  That file's header states it outright:
 *
 *   "The path is staged into data-bank scratch (the fopen model) so both
 *    kernel pointers live in the single _Sys_CallerBank; the caller's `struct
 *    stat' may be a bank-0 HW-stack local (the historic vi hang), which the
 *    syscall cannot write directly."
 *
 * THE SYSCALL HAS ONE BANK FOR TWO POINTERS.  A first version passed the
 * caller's own pointers with __syscall_db and the buffer's bank, and df(1)'s
 * `struct statfs statfsbuf' is a STACK LOCAL -- so _Sys_CallerBank became the
 * hardware stack's bank and _Sys_CopyPathToBuf read the pathname from there.
 * `df /etc' answered ENOENT, which reads like a namei failure a long way from
 * the caller that caused it.  `df root_device' worked in the same run, which
 * is what isolated it: that path reaches statfs through getmntpt, and every
 * pointer involved happened to sit where the syscall was looking.
 *
 * A DIFFERENCE THAT ONLY SHOWS FOR SOME CALLERS IS THE WORST KIND, so this
 * follows the established pattern rather than inventing a third. */
int statfs(char *path, struct statfs *buf)
{
    register char *d;
    register char *s;
    register int   n;
    int r;

    strcpy(_libc_lstrBufB, path);          /* BufA takes the kernel's struct */
    r = (int)__syscall(114,
                       (unsigned)(unsigned long)_libc_lstrBufB,
                       (unsigned)(unsigned long)_libc_lstrBufA,
                       0);
    if (__syscall_c() == 0) { errno = r; return -1; }

    /* 100 bytes into 128 of scratch (libc_data.s:32).  Checked rather than
     * assumed, because the struct grows the day a field is added to the
     * kernel's copy and nothing else would notice. */
    d = (char *)buf;
    s = _libc_lstrBufA;
    n = (int)sizeof(struct statfs);
    while (n-- > 0)
        *d++ = *s++;
    return 0;
}


/* FGX console + diagnostic surface (border/setpal/fonts/dmesg/slotscan/
 * meminfo) -> lib/libfgx_c/libfgx.c (BSD-foundations P1). */

