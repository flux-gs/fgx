/* Isolate the indirect call od's dispatch uses: fp = tbl[i]; fp(ptr, structptr)
 * — TWO pointer args through a fn-ptr (the validated fp fixtures only ever
 * passed one int arg).  od's `put = put_table[id]; put(dbuf+i, c)` is this. */
struct S { int a; int b; int c; };
struct S gs;
char gbuf[4];

int f2(char *p, struct S *d)
{
    return p[0] + d->a + d->b + d->c;   /* read both args incl. struct fields */
}

int (*tbl[])() = { f2 };

int main(void)
{
    int (*fp)();
    int r;

    gbuf[0] = 5;
    gs.a = 10; gs.b = 20; gs.c = 7;

    fp = tbl[0];
    r = fp(gbuf, &gs);          /* indirect: 5+10+20+7 = 42 */
    return r;
}
