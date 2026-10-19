/* ---- utimes (SYS_UTIME=93) -------------------------------------------------
 * Set a file's access and modification times.  BOTH of them, as epoch
 * seconds, which is the change: this used to convert tv[1].tv_sec through
 * gmtime() into ProDOS's two packed 16-bit words and DROP tv[0] entirely,
 * because a ProDOS directory entry has a mod date and nothing else.  A
 * 2.11BSD inode has i_atime and i_mtime and ufs_setattr has honoured both
 * since UFS 1.12b, so the conversion is not moved -- it is gone
 * (apple/fgx#343).
 *
 * THE ARGUMENTS GO THROUGH SCRATCH, which is stat(2)'s model and is why the
 * syscall's ABI changed with it.  Two 32-bit times do not fit in X and Y; the
 * pair that did fit was the packed ProDOS date and time.  So the path is
 * staged in _libc_lstrBufB and the two time_t in _libc_lstrBufA, both in the
 * data bank, and one _Sys_CallerBank serves both pointers -- the caller's own
 * `struct timeval' may be a bank-0 hardware-stack local, which the syscall
 * cannot read directly.  stat.c's header states that trap in full.
 *
 * NULL tv MEANS NOW, for both fields, which is what touch(1) with no -t does
 * and what BSD's utimes documents.  tv_usec is ignored: the inode stores
 * whole seconds.  tar(1) uses this to restore mtimes on extract. */
int utimes(char *path, struct timeval *tv)
{
    long *t = (long *)_libc_lstrBufA;
    long  now;
    int   r;

    if (tv) {
        t[0] = tv[0].tv_sec;
        t[1] = tv[1].tv_sec;
    } else {
        now  = time((long *)0);
        t[0] = now;
        t[1] = now;
    }
    strcpy(_libc_lstrBufB, path);
    r = (int)__syscall(93,
                       (unsigned)(unsigned long)_libc_lstrBufB,
                       (unsigned)(unsigned long)_libc_lstrBufA,
                       0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
