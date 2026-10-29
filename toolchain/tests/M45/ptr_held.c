/* Pointer variables held in direct page and read in place.  A struct pointer
 * parameter used several times, a pointer to a pointer, and a local list
 * cursor are promoted to an img pair, and a member read through the far-
 * pointer register a load filled reads the pair itself.  Each case checks
 * what a stale or early read would get wrong: the cursor's OLD value while
 * `p = p->next' is being evaluated, values that cross calls (the band is
 * callee-saved, the registers are not), a branch on one path only, and a
 * pointer returned in the pointer register.  Returns 42 when every check
 * holds. */
struct node { int v; struct node *next; char *name; };
struct node c3 = { 3, 0, "three" };
struct node c2 = { 2, &c3, "two" };
struct node c1 = { 1, &c2, "one" };

int bump(n) int n; { return n + 1; }

int sum(p) struct node *p;              /* cursor walked to the end */
{
    int s;
    s = 0;
    while (p) {
        s += p->v * 10 + bump(p->v);    /* reads across a call */
        p = p->next;                    /* the old p is read for its own successor */
    }
    return s;                           /* 10+2 + 20+3 + 30+4 = 69 */
}

struct node *pick(p, n) struct node *p; int n;   /* returned in the register */
{
    if (p->v == n) return p;
    if (p->next && p->next->v == n) return p->next;
    return p->next ? p->next->next : p;
}

int deep(pp) struct node **pp;          /* a pointer to a pointer */
{
    int t;
    t = (*pp)->v;
    *pp = (*pp)->next;                  /* advances the caller's cursor */
    t += (*pp)->v + bump((*pp)->v);
    return t;                           /* 1 + 2 + 3 = 6 */
}

int walker(s, p) char *s; struct node *p;  /* (s)[i] and (p)->m: the value, not &s */
{
    (s)[1] = 'X';
    (p)->v = (p)->v + 100;
    (*p).v = (*p).v + 1;
    return (s)[1] == 'X' && (p)->v == 104;
}

int main()
{
    struct node *cur;
    char buf[4];
    int bad;

    bad = 0;
    if (sum(&c1) != 69) bad++;
    if (pick(&c1, 2) != &c2 || pick(&c1, 3) != &c3 || pick(&c1, 1) != &c1) bad++;
    cur = &c1;
    if (deep(&cur) != 6 || cur != &c2) bad++;
    buf[0] = 'a'; buf[1] = 'b'; buf[2] = 0;
    if (!walker(buf, &c3) || buf[1] != 'X' || c3.v != 104) bad++;
    c3.v = 3;
    if (pick(&c1, 9)->name[0] != 't' || sum(&c2) != 20 + 3 + 30 + 4) bad++;
    return bad ? bad : 42;
}
