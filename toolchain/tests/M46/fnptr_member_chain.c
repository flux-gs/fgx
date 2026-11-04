/* A call through a function pointer at the end of a member chain, as
 * 2.11BSD's netinet/if_ether.c calls `(*ac->ac_if.if_output)(...)'.
 * K&R A.7.3.2: the postfix expression "must be of type ``pointer to
 * function returning T''", however it is reached.  Returns 42. */
struct in {
	int (*fn)();
	int z;
};
struct out {
	int y;
	struct in s;
};

int
add20(a)
	int a;
{
	return (a + 20);
}

int main()
{
	struct out q, *p;
	int r;

	q.y = 7;
	q.s.fn = add20;
	q.s.z = 9;
	p = &q;
	r = (*p->s.fn)(1) + p->s.fn(1) + (*q.s.fn)(1);
	if (p->s.z != 9 || q.y != 7)
		return (1);
	return (r - 21);
}
