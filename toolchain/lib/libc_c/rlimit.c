/* Resource limits.  The values live in the kernel's per-process u-area, so they
 * survive a fork and an exec; RLIMIT_DATA is enforced by the break path
 * (_Sys_Brk, the site Reno checks at kern_mman.c:342 and 2.11BSD acquired in
 * update #439), which is what makes tcsh's `limit datasize` do something.
 * RLIMIT_FSIZE's reader arrives with the UFS write path; the remaining slots
 * name machinery FGX does not have and are storage only -- include/kernel.s
 * lists which is which.
 *
 * These used to report a constant: getrlimit answered "unlimited" whatever had
 * been set, and setrlimit discarded its argument, so a shell could not read
 * back what it had just written. */
int getrlimit(int resource, struct rlimit *rlp)
{
    unsigned long lp = (unsigned long)rlp;
    int r = (int)__syscall_db(105, (unsigned)(lp >> 16),
                              (unsigned)resource, 0, (unsigned)lp);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int setrlimit(int resource, struct rlimit *rlp)
{
    unsigned long lp = (unsigned long)rlp;
    int r = (int)__syscall_db(106, (unsigned)(lp >> 16),
                              (unsigned)resource, 0, (unsigned)lp);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* scheduling priority: FGX's scheduler has no nice levels.  Report 0 (normal)
 * and accept a set without applying it. */
int getpriority(int which, int who)
{
    (void)which; (void)who;
    return 0;
}

int setpriority(int which, int who, int prio)
{
    (void)which; (void)who; (void)prio;
    return 0;
}

