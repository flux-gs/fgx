/* M42: --libso block-static shapes, third set: a for loop's init and step,
 * statement-level prefix ++ on a member, a parenthesized lvalue (K&R A.7.2),
 * and calls through a function-pointer array element and through `*fp'. */
struct t { int x; int y; };
static int n;
static struct t p;
static int (*tab[2])();
static int (*fp)();
int g() { return 5; }
int main()
{
    int s = 0;
    for (n = 0; n < 3; n++) s += n;           /* init, test, step */
    for (; n < 5; n++) s++;
    p.y = 1; ++p.y;
    (n) = 9; (n) += 1;
    tab[1] = g; fp = g;
    return (s == 5 && n == 10 && p.y == 2 && tab[1]() == 5 &&
            (*tab[1])() == 5 && (*fp)() == 5) ? 42 : 1;
}
