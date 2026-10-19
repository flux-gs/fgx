/* ---- stat surface (C4 batch 11) ------------------------------------------
 * SYS_STAT AND SYS_FSTAT FILL `struct stat' ITSELF NOW (the STX_ cutover,
 * 2026-09-05).  They used to fill the kernel's NATIVE 15-byte ProDOS-shaped
 * image -- a mode BYTE whose whole vocabulary was $80/$40/$20, a 3-byte size,
 * and a raw ProDOS bit-packed date and time -- and this file unpacked it: a
 * mode synthesised from three values, a size zero-extended by hand, and
 * CALENDAR ARITHMETIC to turn ProDOS's packed date into a Unix epoch.  All of
 * that is gone.  The kernel writes the layout sys/stat.h declares, and the
 * only thing left to do with it is copy it out of the scratch buffer.
 *
 * THE COPY STAYS, AND IT IS NOT CEREMONY.  The path is staged into data-bank
 * scratch (the fopen model) so both kernel pointers live in the single
 * _Sys_CallerBank; the caller's `struct stat' may be a bank-0 HW-stack local
 * (the historic vi hang), which the syscall cannot write directly.  So the
 * kernel fills _libc_lstrBufA and this moves it where the caller asked. */

/* Move the kernel's struct out of scratch into the caller's.  Factored out of
 * stat() so fstat(2) shares it verbatim, which is what it was for before. */
static void __lc_stat_copy(struct stat *st)
{
    register char *d = (char *)st;
    register char *s = _libc_lstrBufA;
    register int   n = (int)sizeof(struct stat);

    while (n-- > 0)
        *d++ = *s++;
}

int stat(char *path, struct stat *st)
{
    int r;

    strcpy(_libc_lstrBufB, path);          /* BufA holds the native image */
    r = (int)__syscall(18,
                       (unsigned)(unsigned long)_libc_lstrBufB,
                       (unsigned)(unsigned long)_libc_lstrBufA,
                       0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    __lc_stat_copy(st);
    return 0;
}

/* fstat(2) over SYS_FSTAT=28.  The kernel fills the same struct from the FCB
 * rather than by walking a path -- which is the point: a pipe, or a file
 * renamed after opening, still has a valid fd.  Fields the FCB cannot know come
 * back ZERO from the kernel (st_ino, st_blocks and the three times, which live
 * in the directory entry), so those read 0 here rather than being invented.
 * st_size is actually MORE current than stat(2)'s: FCB_Eof counts writes not
 * yet flushed to the catalog. */
int fstat(int fd, struct stat *st)
{
    int r;

    r = (int)__syscall(28, fd,
                       (unsigned)(unsigned long)_libc_lstrBufA,
                       0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    __lc_stat_copy(st);
    return 0;
}

/* lstat(2) over SYS_LSTAT=112-1.  stat(2)'s twin: the kernel fills the same
 * struct from the same buffer, having asked namei NOT to follow a final
 * symlink.  Everything here is stat's. */
int lstat(char *path, struct stat *st)
{
    int r;

    strcpy(_libc_lstrBufB, path);
    r = (int)__syscall(111,
                       (unsigned)(unsigned long)_libc_lstrBufB,
                       (unsigned)(unsigned long)_libc_lstrBufA,
                       0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    __lc_stat_copy(st);
    return 0;
}

/* access(2).  A REAL SYSCALL as of UFS 2.6 (apple/fgx#320, #324).
 *
 * It was an existence probe -- `(void)mode; return stat(...)' -- and the note
 * here said it would stay one until something ENFORCED the mode bits.  That
 * landed: ufs_access is real, vn_open and the path walk call it, and this now
 * issues SYS_ACCESS (33, 2.11BSD's own number) rather than guessing.
 *
 * THE KERNEL ANSWERS FOR THE REAL IDS, not the effective ones, which is the
 * whole reason access(2) exists as a syscall rather than a stat plus
 * arithmetic here: a setuid program asks what the PERSON running it may do.
 * libc cannot do that swap; `_Sys_Access' does it around the check, as
 * 2.11BSD's saccess() does.
 *
 * mode == F_OK still asks only whether the name resolves. */
int access(char *path, int mode)
{
    int r;

    r = (int)__syscall(33, (unsigned)(unsigned long)path, (unsigned)mode, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

