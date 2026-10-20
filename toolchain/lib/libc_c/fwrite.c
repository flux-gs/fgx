int fwrite(char *buf, int sz, int n, char *fp)
{
    int *e = __lc_fent(fp);
    int want = sz * n;
    int put = 0;
    int r;

    if (sz <= 0 || n <= 0 || want <= 0)
        return 0;
    /* Through the shared per-fd queue, not write(2) directly: a program that
     * mixes fwrite with putchar or printf on one stream would otherwise see
     * this overtake whatever they are still holding. */
    while (put < want) {
        r = __lc_wwrite(e[0], buf + put, want - put);
        if (r <= 0)
            break;
        put = put + r;
    }
    return put / sz;
}
