/* Array-of-pointer STRUCT FIELD (elvis's Henry-Spencer regexp:
 * `char *startp[NSUBEXP]; char *endp[NSUBEXP];`).  fcc rejected array-of-ptr
 * fields ("array of pointer field not supported"); now the field lays out as
 * N x 4-byte pointers and `p->startp[i]` reads / writes the pointer element
 * (constant and variable index, statement and expression context), leaving
 * later scalar fields intact.  -> 42. */
struct re { char *startp[3]; char *endp[3]; int minlen; };
char *ga;
char *gb;

int main(void)
{
	struct re r;
	struct re *p;
	int i;
	char *q;

	p = &r;
	ga = "AA";
	gb = "BB";

	p->startp[0] = ga;        /* statement store, constant index */
	i = 1;
	p->startp[i] = gb;        /* statement store, variable index */
	p->endp[2]   = ga;        /* second array-of-ptr field */
	p->minlen    = 7;         /* scalar field after the arrays */

	q = p->startp[0];         /* read, constant index  */
	if (q[0] != 'A') return 1;
	q = p->startp[i];         /* read, variable index  */
	if (q[0] != 'B') return 2;
	q = p->endp[2];
	if (q[0] != 'A') return 3;
	if (p->minlen != 7) return 4;   /* arrays didn't clobber the scalar */

	if ((p->endp[0] = gb) != gb) return 5;   /* expression-context store yields value */
	q = p->endp[0];
	if (q[0] != 'B') return 6;
	return 42;
}
