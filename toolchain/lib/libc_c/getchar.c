int getchar(void)
{
    int *e = &_libc_FILE_table[0];               /* slot 0 = stdin */

    return __lc_getcb(e, __lc_bufidx(0, e));
}
