/* static_min.c -- the smallest program fgx_static links: one call into
 * libc with no block (strlen), one with one (strtok). */
extern char *strtok();
extern int strlen();

int
main()
{
    char buf[8];

    buf[0] = 'a'; buf[1] = ' '; buf[2] = 'b'; buf[3] = 0;
    return strlen(strtok(buf, " "));
}
