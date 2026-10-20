/* M22: in-struct array member via '->' decays to its ADDRESS, not a
 * deref.  `p->name` (name is char[N]) yields &p->name[0] (char *), so
 * indexing/strcmp through it works.  Regression for fcc Issue 1
 * (df prtstat: fn = s->f_mntfromname read the first name bytes AS a
 * pointer).  Returns 42. */
struct rec { int id; char name[8]; };

int main()
{
    struct rec  r;
    struct rec *p;
    char       *q;
    p = &r;
    r.name[0] = 42;
    q = p->name;        /* array-to-pointer decay: q = &r.name[0] */
    return q[0];        /* 42 if decayed to address; garbage if derefed */
}
