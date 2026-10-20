/* lib/libfgx_c/libfgx.c -- the FGX platform library (libfgx).
 *
 * It is compiled three ways: --libso for libfgx.so, --sections in program
 * mode for static links, and --pile for pile links.
 *
 * BSD-foundations P1 (2026-07-16): libc is pure BSD names only; every
 * FGX-specific entry lives here, prototyped in <fgx.h>.  The pile build
 * follows libc_c.c's pile rules (docs: 2026-07-10-fgx-t5c-libc-in-c.md):
 * near calls only, zero reloc rows, no CALLEE_ENTER -- DBR stays the
 * caller's data bank.
 * libfgx calls into libc (strcpy, getenv); libc makes no calls into
 * libfgx.
 * Failure contract (mirrors SYSCALL_ERR/_ERRSW): on the kernel's fail
 * carry the syscall's A return IS the errno code.
 */
#include <errno.h>
#include <string.h>

extern char *getenv(char *name);

/* libc's argv/envp staging, CALLED and not copied.  THE DIRECTION IS THE
 * POINT: libc is pure BSD names and must not depend on this library, so the
 * shared machinery lives there and libfgx reaches up into it.  An earlier cut
 * had it the other way -- the stager here, libc's execve calling down -- which
 * inverted the layering to work around a linker artifact (libc's members are
 * selected per binary, libfgx is always linked).  A build problem is not a
 * reason to make the BSD library depend on the platform one.
 *
 * None of this staging is BSD, and it exists only because SYS_EXECVE and
 * SYS_POSIX_SPAWN* take an ARG-BLOCK since apple/fgx#303 -- argv then envp, a
 * far pointer each, in a caller frame -- so there is no staging left to share
 * with libc and no table to keep in anyone's data bank. */

/* fcc_runtime_data.s staging cell (see libc_c.c: dedicated cells, NOT
 * _fcc_* scratch -- fcc codegen may clobber scratch between the C store
 * and the use). */
extern char *__asm_p0;

extern char **environ;

/* ---- cooperative scheduling / keyboard ----------------------------------- */

int yield(void)
{
    __syscall(79, 0, 0, 0);
    return 0;
}

int waitkey(void)
{
    /* SYS_GETKEY blocks for a key; low byte is the key.  Named waitkey (not
     * getkey) on purpose: `getkey` is the universal curses/editor name for the
     * *mapped-key* wrapper, so a libc symbol named getkey collides with any
     * such port (elvis defines a strong getkey(int)), and link-time weak/strong
     * binds the port's machine-layer raw-read call to the app's getkey instead
     * -- an unbounded ttyread->getkey->...->ttyread recursion.  waitkey is the
     * blocking sibling of pollkey; no port defines it.
     *
     * IT REPORTS FAILURE NOW, and did not before.  SYS_GETKEY answers C=0 with
     * an errno -- ENOTTY when the caller has no controlling terminal, EINTR
     * when a signal beat the key -- and masking that to a byte hands the caller
     * $19 or $04, which are perfectly good keys.  Every other wrapper in this
     * file already tests the carry; this one did not, and T6 increment 4b made
     * the ENOTTY arm reachable far more often by routing the read through the
     * caller's terminal rather than a shared ring. */
    int r = (int)__syscall(50, 0, 0, 0);
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    return r & 0xFF;
}

int pollkey(void)
{
    int r = (int)__syscall(66, 0, 0, 0);
    if (__syscall_c() == 0)
        return -1;                  /* ring empty (no errno) */
    return r & 0xFF;
}

long ticks(void)
{
    /* SYS_TICKS writes 4 bytes at A(offset) in the caller's DBR -- land
     * them in the __asm_p0 staging cell.  H1-time widened the return to
     * the FULL 60 Hz counter (time(1) needs deltas past the 18-minute
     * lo16 wrap); int-proto callers (dhclient) still read A's low word. */
    __syscall(52, (unsigned)(unsigned long)&__asm_p0, 0, 0);
    return (long)__asm_p0;
}

/* ---- FGX console + diagnostic surface (H2 rewrites) ----------------------
 * One-line wrappers over the FGX-native console syscalls, so color(1)/
 * font(1)/vmstat(1)/uptime(1) are pure C.  Buffer args follow the
 * caller-DBR contract (file-scope data-bank buffers). */

int border(int idx)
{
    __syscall(55, idx, 0, 0);            /* never fails */
    return 0;
}

int setpal(int role, int rgb12)
{
    int r = (int)__syscall(56, role, rgb12, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int meminfo(int subcmd, char *buf, int max)
{
    int r = (int)__syscall(61, subcmd, (unsigned)(unsigned long)buf, max);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;                            /* bytes written */
}

int fontload(char *path)
{
    int r = (int)__syscall(57, (unsigned)(unsigned long)path, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int fontrevert(void)
{
    __syscall(58, 0, 0, 0);              /* never fails */
    return 0;
}

/* SYS_SCREEN_CTL.  mode 1 claims the physical screen (console rendering
 * suspended so the caller owns SHR directly), 0 releases and repaints, 2
 * claims and starts the 3200-colour scanline engine, 3 stops it.  The
 * kernel auto-releases on task death, so a claim cannot outlive its owner.
 * Always succeeds; the return is 0. */
int screen_ctl(int mode)
{
    __syscall(101, mode, 0, 0);
    return 0;
}

int fontname(char *buf, int max)
{
    return (int)__syscall(59, (unsigned)(unsigned long)buf, max, 0);
}

/* dmesg (H1): SYS_DMESG(60) copies up to max bytes of the kernel log
 * ring into a caller-DBR buffer (A=offset, X=max -> A=bytes copied).
 * Buffer must be data-bank (file-scope), same contract as slotscan. */
int dmesg(char *buf, int max)
{
    return (int)__syscall(60, (unsigned)(unsigned long)buf, max, 0);
}

int slotscan(char *buf, int max)
{
    unsigned long lp = (unsigned long)buf;
    return (int)__syscall_db(90, (unsigned)(lp >> 16), (unsigned)lp, max, 0);
}

int procs(char *buf, int max)             /* SYS_PROCS=87: no error return */
{
    return (int)__syscall(87, (unsigned)buf, max, 0);
}

int listdir(char *path, char *buf, int size)   /* SYS_LISTDIR=49 */
{
    int r = (int)__syscall(49, (unsigned)path, (unsigned)buf, size);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;                             /* bytes/records written */
}

/* ---- interface control (libc-breakup task 3) ------------------------------
 * ifctl is FGX's own device call (SYS_IFCONFIG=70) -- an FGX ifnet table
 * lookup/store, not a BSD libc entry point (2.11BSD's ifconfig(8) talks
 * straight to ioctl(2); there is no library-level wrapper to match).
 * Moved out of libc_c/sockopt.c, where it landed next to setsockopt during
 * the T5-C conversion.
 *
 * Param order MUST match the callers' prototype `ifctl(op, ifr)`
 * (dhclient, ifconfig).  The T5-C conversion transcribed the retired asm
 * shim's STACK slots (ifr shallow, op deep) as `(ifr, op)` -- reversed at
 * the C level -- and the live-DHCP gate (needs vmnet) wasn't run on that
 * train: every interface lookup got a garbage record pointer ("no network
 * interface", 2026-07-11 regression). */
int ifctl(int op, char *ifr)
{
    unsigned long lp = (unsigned long)ifr;
    int r = (int)__syscall_db(70, (unsigned)(lp >> 16), (unsigned)lp, op, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* ---- spawn family (C4 batch 8) -------------------------------------------
 * SYS_POSIX_SPAWN reads path/argv/envp through the SINGLE caller bank
 * (T6 wart), so the path is staged into the data-bank scratch buffer
 * exactly like the hand shim did -- in C that staging is one strcpy. */

/* The spawn family's own path cell, written only between its strcpy and the
 * syscall: a scratch buffer shared with libc's path calls could be rewritten
 * in that window by any other call that stages a path. */
static char __fgx_spawn_path[80];

/* THE SPAWN FAMILY TAKES char ** AND HANDS THE KERNEL A CALLER FRAME, which
 * is BSD's shape throughout.  4.3BSD-Reno has no spawn at all -- `execve(char
 * *fname, char **argp, char **envp)' (kern/kern_exec.c:69) is the whole
 * interface -- so there is no upstream spelling of spawnv to match; what these
 * follow is execve's ARGUMENT CONVENTION, which upstream reads out of the
 * caller's own frame (`struct execa *uap = (struct execa *)u.u_ap',
 * 2.11BSD usr/sys/sys/kern_exec.c:48).
 *
 * blk is that frame.  It used to be the caller writing `gav[n] = (int)p' -- a
 * cast that silently required p to live in the caller's data bank, true for a
 * string literal and false for anything else; spawnx even declared `char **'
 * while narrowing it with `(unsigned)argv', so a correct-looking call compiled
 * into a wrong one and the compiler had nothing to say (apple/fgx#302).  Then
 * it was a shared table in libc's data bank (apple/fgx#303, first half).  Now
 * nothing is staged: every pointer carries its own bank and the block is a
 * stack local.
 *
 * `path' IS STILL COPIED, and is the last narrow argument here -- the kernel
 * reads it as an offset in the caller's data bank.  apple/fgx#304. */

int spawnv(char *path, char **argv)
{
    char **blk[2];
    unsigned long b;
    int r;

    strcpy(__fgx_spawn_path, path);
    blk[0] = argv;
    /* the current environment, as 2.11BSD's execv passes it
     * (pdp/sys/execv.s, `mov _environ,-(sp)') */
    blk[1] = environ;
    b = (unsigned long)&blk[0];
    r = (int)__syscall(43,
                       (unsigned)(unsigned long)__fgx_spawn_path,
                       (unsigned)b,
                       (unsigned)(b >> 16));
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;                                  /* child pid (zombie) */
}

/* spawnvp (H1-time): execvp's $PATH walk over the spawn surface -- a bare
 * name is probed along PATH (getenv, else the jsh default) until a spawn
 * sticks; names containing '/' go straight through.  Lives here, not in
 * tools: $PATH resolution was jsh-private before this. */
static char __fgx_vp_path[80];

int spawnvp(char *file, char **argv)
{
    char *pp, *q;
    int i, r;

    for (q = file; *q; q++)
        if (*q == '/')
            return spawnv(file, argv);
    pp = getenv("PATH");
    if (pp == 0)
        pp = "/bin:/sbin:/usr/fgx/bin:/testbin";
    while (*pp) {
        i = 0;
        while (*pp && *pp != ':' && i < 64)
            __fgx_vp_path[i++] = *pp++;
        if (*pp == ':')
            pp++;
        if (i == 0)
            continue;
        __fgx_vp_path[i++] = '/';
        for (q = file; *q && i < 78; q++)
            __fgx_vp_path[i++] = *q;
        __fgx_vp_path[i] = 0;
        r = spawnv(__fgx_vp_path, argv);
        if (r >= 0)
            return r;
        if (errno != ENOENT)
            return -1;
    }
    errno = ENOENT;
    return -1;
}

int spawnve(char *path, char **argv, char **envp)
{
    char **blk[2];
    unsigned long b;
    int r;

    strcpy(__fgx_spawn_path, path);
    blk[0] = argv;
    blk[1] = envp;
    b = (unsigned long)&blk[0];
    r = (int)__syscall(43,
                       (unsigned)(unsigned long)__fgx_spawn_path,
                       (unsigned)b,
                       (unsigned)(b >> 16));
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* spawnx -- SYS_POSIX_SPAWNX=44.  `file_actions' stays a narrowed pointer and
 * is the half of this widening still outstanding: its OPEN entries DO embed
 * own-bank path pointers (include/loader.s:312), so a path outside this bank
 * still cannot be named through it.  Split out as apple/fgx#304 to keep the
 * argv/envp change provable on its own. */
int spawnx(char *path, char **argv, void *file_actions)
{
    char **blk[2];
    int r;

    strcpy(__fgx_spawn_path, path);
    blk[0] = argv;
    blk[1] = (char **)0;                       /* SPAWNX takes no envp */
    /* No bank argument: Y carries file_actions, so SYS_POSIX_SPAWNX reads the
     * block at bank 0 -- true by construction, blk being a stack local. */
    r = (int)__syscall(44,
                       (unsigned)(unsigned long)__fgx_spawn_path,
                       (unsigned)(unsigned long)&blk[0],
                       (unsigned)file_actions);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;                             /* child pid */
}

/* mm_alloc -- SYS_MM_ALLOC=68: a Memory-Manager block via _NewHandle,
 * locked+fixed, MAY span banks (no attrNoCross), so it is the answer for
 * data bigger than the 64 KB data bank -- frotz's Z-machine story file is
 * the first customer.  Returns the HANDLE (bank:offset as a long; 0 on
 * failure with errno=ENOMEM) and writes the dereferenced 24-bit block
 * base to *base.  The base is what you compute with -- fcc's
 * (char *)(long) cast carries all 24 bits -- and the handle is what
 * mm_free takes, so both come back. */
long mm_alloc(unsigned long size, unsigned long *base)
{
    unsigned r;
    long h;

    r = (unsigned)__syscall(68, (unsigned)size,
                            (unsigned)(size >> 16), 0);
    if (__syscall_c() == 0) { errno = r; return 0; }
    h = ((long)(r & 0xFF) << 16) | (long)__syscall_y();
    *base = *(unsigned long *)h;          /* deref the master pointer */
    return h;
}

/* mm_free -- SYS_MM_FREE=69 (_DisposeHandle).  Takes mm_alloc's handle. */
int mm_free(long handle)
{
    __syscall(69, (unsigned)(handle >> 16),
              (unsigned)handle, 0);
    return 0;
}
