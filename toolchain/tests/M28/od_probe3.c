/* Faithful mini-od: isolate WHICH construct corrupts od's `struct dfmt *d`.
 * od prints addresses fine (icvt+long div work) but data fields read garbage.
 * od_probe/od_probe2 only covered fn-ptr arg passing — NOT these:
 *   - struct-field WRITES through a pointer (set_dfmt: d->df_field = ...)
 *   - a pointer-to-struct array walk (conv_vec: d = *cv++)
 *   - df_putid-indexed dispatch
 * Returns a DISTINCT exit code per failing construct (42 = all OK). */
struct dfmt {
    int df_field; int df_size; int df_radix; int df_signed;
    int df_paddr; int df_putid; int df_pad;
};
struct dfmt  a;
struct dfmt *vec[4];

int getput(char *p, struct dfmt *d)
{
    return d->df_field + d->df_size + d->df_radix;   /* 6+2+8 = 16 */
}
int (*tbl[])() = { getput };

void setit(struct dfmt *d, int f, int s, int r, int id)
{
    d->df_field = f; d->df_size = s; d->df_radix = r; d->df_putid = id;
}

int main(void)
{
    struct dfmt **cv;
    struct dfmt  *d;
    int (*put)();
    char buf[2];

    setit(&a, 6, 2, 8, 0);            /* struct-field stores through a pointer */
    if (a.df_field != 6) return 1;
    if (a.df_size  != 2) return 2;
    if (a.df_radix != 8) return 3;
    if (a.df_putid != 0) return 4;

    cv = vec;
    *(cv++) = &a;                     /* store a struct ptr into a ptr-array */
    *cv = 0;
    cv = vec;
    d = *cv;                          /* read the 4-byte ptr back out */
    if (d != &a) return 5;            /* did the full far pointer survive? */

    if (d->df_field != 6) return 6;   /* struct field via the array-walked ptr */
    if (d->df_radix != 8) return 7;

    put = tbl[d->df_putid];           /* df_putid-indexed fn-ptr table */
    if (put(buf, d) != 16) return 8;  /* indirect call passing the struct ptr */

    return 42;
}
