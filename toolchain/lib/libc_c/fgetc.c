int fgetc(char *fp)
{
    int *e = __lc_fent(fp);

    return __lc_getcb(e, __lc_bufidx(__lc_slot(fp), e));
}
