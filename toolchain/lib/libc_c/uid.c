/* getuid(2)/getgid(2) — SYS_GETUID=24, SYS_GETGID=47 (2.11BSD numbers; FGX
 * moved them off 21/22 on 2026-07-28 so mount/umount can have those).  Both
 * always succeed (the kernel returns SEC unconditionally), so there is no
 * errno path — same shape as sync() above.
 *
 * Still 0 in practice: the kernel reads the single-process _kProcUid/_kProcGid
 * globals.  The point of issuing the real syscall is that userland now reads
 * whatever the KERNEL says rather than a compile-time constant, so when
 * credentials move into the u-area every caller follows for free. */
int getuid(void)
{
    return (int)__syscall(24, 0, 0, 0);
}

int getgid(void)
{
    return (int)__syscall(47, 0, 0, 0);
}

/* geteuid/getegid: the SAME syscall as getuid/getgid, reading the Y return.
 * SYS_GETUID hands back real in A and effective in Y, which is exactly what
 * V7/2.11BSD's getuid(2) does (r0/r1) -- so there is no SYS_GETEUID number.
 *
 * Each must issue its own call rather than reading a cached __syscall_y():
 * that latch is a global overwritten by ANY intervening syscall, so a
 * getuid();geteuid() pair that shared one call would be correct only until
 * something ran between them. */
int geteuid(void)
{
    __syscall(24, 0, 0, 0);
    return (int)__syscall_y();
}

int getegid(void)
{
    __syscall(47, 0, 0, 0);
    return (int)__syscall_y();
}

/* set*id(2) -- SYS_SETUID=23, SYS_SETGID=25, SYS_SETEUID=26, SYS_SETEGID=27.
 * The kernel enforces the POSIX rule (root sets all three; non-root may move
 * only the effective id, and only to its real or saved-set id) and returns
 * EPERM otherwise; these are plain errno wrappers over that. */
int setuid(int uid)
{
    int r = (int)__syscall(23, uid, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int setgid(int gid)
{
    int r = (int)__syscall(25, gid, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int seteuid(int uid)
{
    int r = (int)__syscall(26, uid, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int setegid(int gid)
{
    int r = (int)__syscall(27, gid, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* getlogin(3)/setlogin(2) -- SYS_GETLOGIN=118, SYS_SETLOGIN=119.
 *
 * getlogin is 4.3BSD-Reno lib/libc/gen/getlogin.c and 2.11BSD's copy of it,
 * both of which are these same lines over the same `_getlogin' syscall:
 *
 *      if (_logname_valid == 0) {
 *              if (_getlogin(logname, sizeof(logname) - 1) < 0)
 *                      return ((char *)NULL);
 *              _logname_valid = 1;
 *      }
 *      return (*logname ? logname : (char *)NULL);
 *
 * THE CACHE IS UPSTREAM'S AND SO IS ITS ONE INVALIDATOR: `_logname_valid' is
 * commented "known to setlogin()" there, and setlogin below clears it.  Within
 * a process nothing else can change the name, and across an exec the whole
 * data segment is fresh, so there is no stale answer to worry about.
 *
 * THE BUFFER IS ONE BYTE LONGER THAN IS EVER ASKED FOR, which is what
 * terminates the string: the kernel hands back BYTES -- sixteen characters
 * fill u_login exactly and it is not NUL-terminated there -- and this static
 * starts life zeroed, so the byte past the longest possible name is already
 * the terminator.  Upstream depends on exactly this. */
int _logname_valid;             /* known to setlogin() */

static char _logname[MAXLOGNAME + 1];

char *getlogin(void)
{
    int n;

    if (_logname_valid == 0) {
        n = (int)__syscall(118, (unsigned)(unsigned long)_logname,
                           (unsigned)(sizeof(_logname) - 1), 0);
        if (__syscall_c() == 0) {
            errno = n;
            return ((char *)0);
        }
        _logname_valid = 1;
    }
    return (*_logname ? _logname : (char *)0);
}

int setlogin(char *name)
{
    int r = (int)__syscall(119, (unsigned)(unsigned long)name, 0, 0);

    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    _logname_valid = 0;         /* upstream's comment on the flag, honoured */
    return 0;
}
