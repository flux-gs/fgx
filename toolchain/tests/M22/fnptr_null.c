/* A fn-ptr struct field initialized with a null pointer constant other than
 * a bare 0: FGX's NULL, ((char *)0), and (void *)0, both of which K&R A.6.6
 * lets convert "to a pointer of any type".  FreeBSD ee's menu tables fill
 * their unused handlers with NULL.  Returns 42 when the null fields read as
 * null and the named one dispatches. */
#define NULL ((char *)0)

int add40(x) int x; { return x + 40; }
struct ment { char *name; int (*fn)(); int (*alt)(); };
struct ment tbl[] = {
    { "a", NULL, (void *)0 },
    { "b", add40, NULL },
};

int main(void)
{
    if (tbl[0].fn != 0 || tbl[0].alt != 0 || tbl[1].alt != 0)
        return 1;
    return tbl[1].fn(2);   /* 40 + 2 = 42 */
}
