/* Loop-hot locals of a function that calls others live in the callee-saved
 * direct-page band: every function that writes a band word saves its
 * caller's value on entry and restores it on return, and setjmp/longjmp
 * carry the band for the returns a longjmp skips.  sum and walk nest band
 * users through a call; rec, which recurses and so keeps its locals on its
 * frame, runs under main's band words; and outer reads its band locals
 * after deep's are overwritten and deep's epilogue skipped by a longjmp.
 * Returns 42 when every value survives. */
#include <setjmp.h>

jmp_buf env;
char s1[] = "abcdefgh";
char s2[] = "ABCDEFGH";
int calls;

int
leaf(c)
int c;
{
	calls++;
	return c & 1;
}

int
walk(p, n)
char *p;
int n;
{
	char *q;
	int i, k;

	k = 0;
	q = p;
	for (i = 0; i < n; i++) {
		k += leaf(*q);
		q++;
	}
	return k;			/* odd letters among the first n */
}

int
sum(p)
char *p;
{
	char *q;
	int t, i;

	t = 0;
	q = p;
	for (i = 0; i < 8; i++) {
		t += walk(s2, i);	/* walk's band words are this function's */
		t += *q & 7;
		q++;
	}
	return t;
}

int
rec(p, d)
char *p;
int d;
{
	char *q;
	int t, i;

	t = 0;
	q = p;
	for (i = 0; i < 2; i++) {
		if (d)
			t += rec(p + 1, d - 1);
		t += *q;
		q++;
	}
	return t;
}

void
jumper()
{
	longjmp(env, 3);
}

int
deep(p)
char *p;
{
	char *q;
	int i, t;

	t = 0;
	q = p;
	for (i = 0; i < 4; i++) {
		t += *q++;
		if (i == 2)
			jumper();	/* deep's epilogue never runs */
		leaf(t);
	}
	return t;
}

int
outer(p)
char *p;
{
	char *q;
	int i, t, r;

	q = p;
	r = setjmp(env);
	t = 0;
	for (i = 0; i < 4; i++) {
		t += q[i];		/* q, set before setjmp, never changed */
		if (r == 0)
			deep(s2);
		leaf(i);
	}
	return t + r;
}

int
main()
{
	char *m;
	int i, r, t;

	r = 0;
	m = s1;
	t = 0;
	for (i = 0; i < 3; i++) {
		t += *m++;
		leaf(i);		/* main's band words cross every call */
	}
	if (t == 'a' + 'b' + 'c' && *m == 'd') r += 10;
	if (sum(s1) == 44) r += 10;
	if (rec(s1, 3) == 2993) r += 10;
	if (outer(s1) == 'a' + 'b' + 'c' + 'd' + 3 && *m == 'd') r += 12;
	return r;
}
