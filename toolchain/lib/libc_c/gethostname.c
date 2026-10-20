/* gethostname(3): FGX keeps the name in /etc/hostname (one line), the same file
 * the net stack reads, so there is exactly one source of truth. */
int gethostname(char *name, int namelen)
{
    FILE *fp;
    int   i, c;

    if (name == (char *)0 || namelen <= 0) { errno = EFAULT; return -1; }
    fp = fopen("/etc/hostname", "r");
    if (fp == (FILE *)0) {
        name[0] = '\0';
        return -1;
    }
    i = 0;
    while (i < namelen - 1) {
        c = fgetc(fp);
        if (c == EOF || c == '\n' || c == '\r')
            break;
        name[i++] = (char)c;
    }
    name[i] = '\0';
    (void)fclose(fp);
    return 0;
}
