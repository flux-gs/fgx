/* Storage class specifiers and qualifiers written after the base type.
 * K&R A.8: "the declaration-specifiers consist of a sequence of type and
 * storage class specifiers", in a grammar with no order.  2.11BSD tee.c
 * declares `int register r,w,p;'.  A trailing `static' must still make a
 * local static (the count survives the calls) and a trailing `extern' must
 * still name the file's object.  An auto `n' would be initialized on every
 * call and give 2 where the static gives 4.  Returns 42. */
struct pt { int x, y; };

int static gs = 3;
char gc[4] = "ab";
char extern gc[];

int bump(void)
{
    int static n = 1;

    return ++n;
}

int main(void)
{
    int register r, w, p;
    char register *q;
    struct pt pt;
    struct pt register *sp;
    long register l;
    int const c = 5;
    int auto a;

    bump();
    bump();
    r = bump();                     /* 4 when n is static */
    q = gc;
    w = q[1] - 'a';                 /* 1 */
    sp = &pt;
    sp->x = 10;
    sp->y = 20;
    l = 70000L;
    a = (int)(l - 69990L);          /* 10 */
    p = sp->x + sp->y;              /* 30 */
    return r + w + p + c + a + gs - 11;     /* 4+1+30+5+10+3-11 = 42 */
}
