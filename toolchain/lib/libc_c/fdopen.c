/* fdopen(3): wrap an ALREADY-OPEN descriptor in a FILE.
 *
 * Ported from 2.11BSD stdio/fdopen.c.  "The mode has to be repeated because
 * you can't query its status" is upstream's own comment: a descriptor cannot
 * be asked what it was opened for, so the mode is taken on trust: its letter,
 * and a '+' for an update stream.  Nothing here re-opens anything, so a mode that
 * disagrees with the fd is the caller's error and shows up as EBADF on the
 * first transfer.
 *
 * "a" SEEKS TO THE END.  Upstream's 'a' arm is `lseek(fd, (off_t)0, L_XTND)'
 * falling into 'w'; a descriptor handed in here need not be O_APPEND, and "a"
 * means append whatever it was opened as.  "r" and "w" keep the offset the fd
 * already has -- upstream does not seek on either.
 */
char *fdopen(int fd, char *mode)
{
    int i;

    if (fd < 0) { errno = 9; return (char *)0; }           /* EBADF */
    if (__lc_mode_flags(mode) < 0) { errno = 22; return (char *)0; } /* EINVAL */
    for (i = 3; i < 8; i++)
        if (_libc_FILE_table[i * 2] == -1)
            break;
    if (i == 8) { errno = 23; return (char *)0; }          /* ENFILE */
    if (mode[0] == 'a')
        lseek(fd, 0L, SEEK_END);
    _libc_FILE_table[i * 2]     = fd;
    _libc_FILE_table[i * 2 + 1] = __lc_mode_dir(mode);
    __lc_bdrop(i - _LC_FIRSTBUF);       /* a reused slot must not inherit the
                                         * previous file's held bytes */
    return __lc_fptr(i);
}
