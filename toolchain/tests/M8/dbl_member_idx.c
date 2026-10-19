/* A double or long long array member, read by subscript through `->': the
 * one-hop `p->a[i]' and the dotted `p->s.a[i]'.  K&R A.7.3.1: "The expression
 * E1[E2] is identical (by definition) to *((E1)+(E2))" -- no condition on the
 * element type.  2.11BSD ntp's clock filter shifts its samples as
 * `peer->filter.offset[i] = peer->filter.offset[i - 1]'.  Returns 42. */

struct flt { double off[4]; long long cnt[3]; };
struct peer { int n; double d[4]; struct flt filter; };

static struct peer pr;

int main()
{
    struct peer *p;
    int i;

    p = &pr;
    for (i = 0; i < 4; i++) {
        p->d[i] = (double)(i * 10);
        p->filter.off[i] = (double)i;
    }
    p->filter.cnt[0] = 5;
    p->filter.cnt[1] = 7;
    for (i = 3; i; i--)
        p->filter.off[i] = p->filter.off[i - 1];   /* 0 0 1 2 */
    return (int)(p->d[3] + p->d[1]) - 1              /* 40 - 1 = 39 */
         + (int)p->filter.off[3]                     /* + 2 = 41 */
         + (int)(p->filter.cnt[1] - p->filter.cnt[0]) /* + 2 = 43 */
         - (int)p->filter.off[2];                    /* - 1 = 42 */
}
