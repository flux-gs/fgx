char *freopen(char *path, char *mode, char *fp)
{
    int i = ((unsigned)(unsigned long)fp
             - (unsigned)(unsigned long)&_libc_FILE_table[0]) >> 2;
    int *e = &_libc_FILE_table[i * 2];
    int fd, fl;

    fl = __lc_mode_flags(mode);
    if (fl < 0) { errno = 22; return (char *)0; }
    __lc_bdrop(i - _LC_FIRSTBUF);       /* the old file's bytes die with its fd */
    if (e[0] != -1) {
        __lc_wrelease(e[0]);            /* held OUTPUT belongs to the old file,
                                         * and must go out before its fd does */
        close(e[0]);
    }
    fd = open(path, fl, 0666);      /* "w" carries O_TRUNC; see __lc_mode_flags.
                                     * 0666 is BOTH ancestors' -- 2.11BSD and
                                     * 4.3BSD-Reno lib/libc/stdio/fopen.c:44 are
                                     * the same line, `open(file, oflags, 0666)'
                                     * -- and the umask is what narrows it. */
    if (fd < 0) {
        e[0] = -1;
        e[1] = 0;
        return (char *)0;
    }
    e[0] = fd;
    e[1] = __lc_mode_dir(mode);
    return __lc_fptr(i);
}
