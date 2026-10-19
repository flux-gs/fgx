/* od's us_put reads struct-pointer-param fields AS ARGUMENTS to a nested call:
 *   emit_field(d, icvt((long)*n, d->df_radix, d->df_signed, d->df_field));
 * i.e. `d->field` is read while args are being pushed (g_s_delta shifting) and
 * a 4-byte long arg is in the mix.  probe3 only summed the fields with no
 * intervening call.  This isolates "param struct-field read during nested-call
 * arg marshalling".  Returns 42 if correct. */
struct dfmt {
    int df_field; int df_size; int df_radix; int df_signed;
    int df_paddr; int df_putid; int df_pad;
};
struct dfmt  a;
struct dfmt *vec[4];
char data[2];

/* mirrors icvt's signature: a long first arg + three ints. */
int sink(long v, int radix, int sgn, int field)
{
    return (int)v + radix + sgn + field;     /* 1 + 8 + 0 + 6 = 15 */
}

int put1(char *np, struct dfmt *d)
{
    short *n = (short *)np;
    int r = sink((long)*n, d->df_radix, d->df_signed, d->df_field);
    return r + d->df_size;                    /* 15 + 2 = 17 */
}
int (*tbl[])() = { put1 };

void setit(struct dfmt *d, int f, int s, int r, int sg)
{
    d->df_field = f; d->df_size = s; d->df_radix = r; d->df_signed = sg;
}

int main(void)
{
    struct dfmt **cv;
    struct dfmt  *d;
    int (*put)();

    setit(&a, 6, 2, 8, 0);
    data[0] = 1; data[1] = 0;        /* *(short*)data == 1 */
    vec[0] = &a; vec[1] = 0;
    cv = vec;
    d = *cv;
    put = tbl[0];
    return put(data, d) + 25;        /* 17 + 25 = 42 */
}
