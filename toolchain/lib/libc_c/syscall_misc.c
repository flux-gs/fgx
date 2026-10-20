
/* isatty -- is the thing behind the descriptor a terminal.  The question is
 * the DEVICE's, and 2.11BSD's implementation is this and nothing else:
 *
 *      isatty(f)
 *      {
 *              struct sgttyb ttyb;
 *
 *              if (ioctl(f, TIOCGETP, &ttyb) < 0)
 *                      return(0);
 *              return(1);
 *      }
 *
 * -- vendor/2.11BSD/usr/lib/libc/gen/isatty.c.  The ioctl reaches the device
 * through `_Io_CdThenTty', which every descriptor road passes, so this answers
 * for a terminal reached any way it can be reached.
 */
int isatty(int fd)
{
    char ttyb[6];               /* struct sgttyb */

    if (gtty(fd, ttyb) < 0)
        return (0);
    return (1);
}

int close(int fd)
{
    int r = (int)__syscall(6, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* fsync(2) - force one file's data + metadata to disk NOW (SYS_FSYNC=97,
 * FGX train-3 F4).  Errors: EBADF, EIO (including a deferred write error
 * latched by a failed switch-away flush, reported here once). */
int fsync(int fd)
{
    int r = (int)__syscall(97, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* sync(2) - commit every open file's dirty state + the block bitmap
 * (SYS_SYNC=98).  BSD shape: cannot fail; per-file errors stay latched on
 * their FCBs for the owner's next write/fsync/close. */
void sync()
{
    __syscall(98, 0, 0, 0);
}

int dup(int fd)
{
    /* SYS_DUP: lowest free fd sharing fd's FCB. */
    int r = (int)__syscall(41, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int dup2(int oldfd, int newfd)
{
    /* SYS_DUP2: A=oldfd, X=newfd. */
    int r = (int)__syscall(89, oldfd, newfd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* yield/waitkey/pollkey/ticks -> lib/libfgx_c/libfgx.c (BSD-foundations P1). */

int nanosleep(int ticks)                      /* SYS_NANOSLEEP=83: 0 / -1 (EINTR) */
{
    int r = (int)__syscall(83, ticks, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* sleep(sec) — coarse second-granularity sleep on the 60 Hz tick.  Looped
 * per-second so a large count can't overflow the 16-bit tick arg, and an
 * EINTR wake just moves to the next second.  Returns 0. */
int sleep(int sec)
{
    while (sec > 0) { nanosleep(60); sec--; }
    return 0;
}

/* alarm(sec) — arm a SIGALRM after `sec` seconds (0 cancels).  SYS_ALARM=64,
 * seconds in A.lo (kernel caps at 255).  The kernel returns 0 (no "previous
 * remaining"), the shape BSD's alarm return takes.  2.11BSD sh's fork-retry
 * `sigchk(); alarm(10); pause()` and the shell timeout use it. */
int alarm(int sec)
{
    return (int)__syscall(64, sec, 0, 0);
}

/* getppid() — parent pid.  SYS_GETPPID=39 has been in the kernel all along;
 * only the libc side was missing, so unistd.h listed it among the gaps.  BSD's
 * getppid cannot fail, and neither can this: an orphan's parent is init. */
int getppid(void)
{
    return (int)__syscall(39, 0, 0, 0);
}

/* pause() — suspend until a signal.  FGX has no SYS_PAUSE; approximate with an
 * interruptible ~1s nanosleep (a pending SIGALRM wakes it EINTR) so sh's
 * `alarm(10); pause()` fork-retry throttles instead of tight-spinning.  Always
 * returns -1, as BSD pause does (it only returns via an interrupting signal). */
int pause(void)
{
    nanosleep(60);
    return -1;
}

/* umask(mask) - file-creation mask.  Sets the new value, returns the old, which
 * is the shape sh's `umask` builtin needs: it reads the current mask via the
 * set-and-restore idiom `umask(i = umask(0))`.
 *
 * WAS A STATIC IN THIS FILE, and the move to the kernel is the fix rather than
 * a tidy-up.  A libc static is per-IMAGE, so the mask did not survive exec and
 * did not cross fork -- and the kernel could not see it at all, which means
 * nothing could ever apply it.  BSD keeps it in the u-area for exactly those
 * three reasons.  It now lives there (SYS_UMASK), inherits with the rest of the
 * u-area at fork, and survives exec because no exec path touches it.
 *
 * The kernel masks to 07777, not the 0777 this static used: a mask naming the
 * setuid/setgid/sticky bits used to have them silently dropped. */
int umask(int mask)
{
    return (int)__syscall(104, (unsigned)mask, 0, 0);
}

/* times(buf) — process/child CPU times (user, sys, cuser, csys) on the 60 Hz
 * clock.  FGX has no per-process CPU accounting yet, so report zero (sh's
 * `times` builtin then prints 0m0s).  buf is a long[4] (sh's L_INT t[4]). */
int times(long *buf)
{
    buf[0] = buf[1] = buf[2] = buf[3] = 0;
    return 0;
}

/* bcmp(a,b,n) — BSD byte compare: 0 iff the n bytes are equal, else nonzero (no
 * ordering).  memcmp's 0/nonzero result satisfies that exactly. */
int bcmp(void *a, void *b, int n)
{
    return memcmp(a, b, n);
}

int pipe(int *fds)
{
    /* SYS_PIPE: X=&fd[0] offset, DBR=its bank; kernel stores fd[0]
     * (read end) and fd[1] (write end) through DBR. */
    unsigned long lp = (unsigned long)fds;
    int r = (int)__syscall_db(88, (unsigned)(lp >> 16), 0, (unsigned)lp, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
