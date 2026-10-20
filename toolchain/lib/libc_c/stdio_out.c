extern void __lc_stdio_flush();      /* stdio_hook.c */

static int __lc_putc1(int *e, int c)
{
    if (__lc_wputc(e[0], c) != 0) { e[1] |= _IOERR; return -1; }
    return c & 0xFF;
}

int fputc(int c, char *fp)
{
    return __lc_putc1(__lc_fent(fp), c);
}

int putchar(int c)
{
    return __lc_putc1(&_libc_FILE_table[2], c);  /* slot 1 = stdout */
}

int fputs(char *s, char *fp)
{
    /* direct far-ptr write — the asm shim's 127-byte staging cap is gone */
    int *e = __lc_fent(fp);
    int len = strlen(s);
    int r = __lc_wwrite(e[0], s, len);
    if (r != len) return -1;
    return r;
}

int puts(char *s)
{
    /* ANSI: fputs to stdout plus a trailing newline; EOF on error. */
    int *e = &_libc_FILE_table[2];               /* slot 1 = stdout */
    int len = strlen(s);
    if (__lc_wwrite(e[0], s, len) != len) return -1;
    return __lc_putc1(e, '\n');
}

int feof(char *fp)
{
    int *e = __lc_fent(fp);
    return e[1] & _IOEOF;
}

int ferror(char *fp)
{
    int *e = __lc_fent(fp);
    return e[1] & _IOERR;
}

int fileno(char *fp)
{
    int *e = __lc_fent(fp);
    return e[0];
}

/* fflush(NULL) flushes every buffered descriptor, which is what BSD does and
 * what exit() needs. */
int fflush(char *fp)
{
    int *e;

    if (fp == (char *)0) {
        __lc_wflushall();
        return 0;
    }
    /* Through a local rather than subscripting the call: every member must
     * still PARSE on its own, and solo __lc_fent has no declaration to give it
     * a pointer type.  tests/ld/test_libc_archive.py compiles each member alone
     * and expects only undefined-SYMBOL errors, which is what keeps the archive
     * walk able to follow every cross-member name. */
    e = __lc_fent(fp);
    return __lc_wflush(e[0]);
}

void clearerr(char *fp)
{
    int *e = __lc_fent(fp);
    e[1] &= ~(_IOEOF | _IOERR);
}

/* THE FD IS AHEAD OF THE CALLER (apple/fgx#50).  With a read buffer the
 * descriptor sits at the end of the last fill, not at the byte the caller has
 * consumed up to, so both of these have to subtract the unconsumed remainder.
 * Getting it wrong is silent: rewind() still works (SEEK_SET is absolute), and
 * ttyent.c's rewind is the only in-tree caller, so a broken SEEK_CUR would have
 * shipped unnoticed. */
int fseek(char *fp, long off, int whence)
{
    int *e = __lc_fent(fp);
    int b = __lc_bufidx(__lc_slot(fp), e);

    (void)__lc_wflush(e[0]);                     /* held output belongs at the
                                                  * OLD offset */
    if (whence == 1)                             /* SEEK_CUR: relative to the
                                                  * caller's position, not the
                                                  * fd's */
        off -= (long)__lc_bavail(b);
    __lc_bdrop(b);                               /* held bytes belong to the
                                                  * OLD offset */
    if (lseek(e[0], off, whence) < 0)
        return -1;
    e[1] &= ~_IOEOF;                             /* POSIX: seek clears EOF */
    return 0;
}

long ftell(char *fp)
{
    int *e = __lc_fent(fp);
    int b = __lc_bufidx(__lc_slot(fp), e);

    (void)__lc_wflush(e[0]);            /* otherwise the fd sits BEHIND the
                                         * caller by whatever is held */
    return lseek(e[0], 0, 1) - (long)__lc_bavail(b);   /* SEEK_CUR */
}

void rewind(fp)
    char *fp;
{
    (void)fseek(fp, 0L, 0);                    /* SEEK_SET; ignore any error */
    clearerr(fp);                              /* POSIX: rewind clears error too */
}

void perror(char *msg)
{
    char *s;

    if (msg != 0 && *msg != 0) {
        write(2, msg, strlen(msg));
        write(2, ": ", 2);
    }
    s = strerror(errno);
    write(2, s, strlen(s));
    write(2, "\n", 1);
}

