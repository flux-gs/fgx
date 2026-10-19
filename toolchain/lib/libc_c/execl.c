/* execl(path, arg0, arg1, ..., (char *)0): the varargs spelling of execv.
 *
 * The argv array here is a STACK LOCAL, which is exactly what the kernel now
 * expects: it is handed over as a far pointer inside the arg-block, so it and
 * the strings it names may live wherever they like.  The 16 bound matches the
 * kernel's LSARGV_MAX, past which SYS_EXECVE answers E2BIG anyway; it is here
 * only so an over-long list cannot overrun this frame. */
int execl(char *path, ...)
{
    va_list ap;
    char   *argv[17];
    int     n;

    va_start(ap, path);
    for (n = 0; n < 16; n++) {
        argv[n] = va_arg(ap, char *);
        if (argv[n] == (char *)0)
            break;
    }
    va_end(ap);
    argv[n] = (char *)0;                 /* NUL-terminate even at the cap */
    return execv(path, argv);
}
