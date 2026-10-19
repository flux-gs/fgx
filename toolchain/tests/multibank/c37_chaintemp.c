/* c37_chaintemp.c — TWO pointer deref-chains live inside ONE expression.
 *
 * P3-2 model edge: `a->next->name[i] <op> b->next->name[j]` needs two
 * simultaneously-live far pointers.  Today both serialize through the
 * shared _fcc_ptr carrier with re-staging between the chains; under the
 * FPR model each chain owns a register.  Anchors and strings land in
 * different banks (data seg vs heap) so a dropped/stale bank half reads
 * garbage, not a lucky alias. */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

struct c37n { struct c37n *next; char *name; };

struct c37n  c37_ga;             /* data-bank anchor node */
struct c37n *c37_gb;             /* heap anchor, home cell in data bank */

int
c37_check(void)
{
	struct c37n *t;
	char *s1, *s2;
	s1 = malloc(4);
	s2 = malloc(4);
	t  = (struct c37n *)malloc(sizeof(struct c37n));
	c37_gb = (struct c37n *)malloc(sizeof(struct c37n));
	if (!s1 || !s2 || !t || !c37_gb) return 0;
	s1[0] = 'x'; s1[1] = 'Q';
	s2[0] = 'y'; s2[1] = 'Q';
	c37_ga.next  = t;       t->name       = s1;
	c37_gb->next = c37_gb;  c37_gb->name  = s2;
	/* both chains deref'd in one expression, twice over */
	if (c37_ga.next->name[1] != c37_gb->next->name[1]) return 0;  /* 'Q'=='Q' */
	if (c37_ga.next->name[0] == c37_gb->next->name[0]) return 0;  /* 'x'!='y' */
	/* pointer-compare of the two chain RESULTS (both temps live) */
	if (c37_ga.next->name == c37_gb->next->name) return 0;
	return 1;
}
