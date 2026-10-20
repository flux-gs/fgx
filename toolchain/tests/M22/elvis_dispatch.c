/* M22/M18: elvis command-table dispatch — the EXPLICIT-DEREF call
 * `(*tbl[i].fn)(args)` (ex.c:665 `(*cmdnames[cmdidx].fn)(...)`,
 * `(*vikeys[prevkey].func)(...)`).  Init a struct-array with fn-ptr fields,
 * then dispatch through an element's fn-ptr field via `(*...)`. */
int add5(x) int x; { return x + 5; }
int add37(x) int x; { return x + 37; }
struct centry { char *name; int (*fn)(); };
struct centry tbl[] = {
    { "a", add5 },
    { "b", add37 },
};

int main(void)
{
    return (*tbl[1].fn)(5);   /* 37 + 5 = 42 */
}
