/* sizeof of `*' applied to a member chain, as 2.11BSD's uipc_syscalls.c
 * copies out `sizeof (*uap->anamelen)' bytes.  K&R A.7.4.8: "The operand
 * is either an expression, which is not evaluated, or a parenthesized type
 * name", and A.7.4.3 gives `*E' the type E points to.  Returns 42. */
struct s {
	int a;
	long b;
};
struct a {
	int *ip;
	long *lp;
	char *cp;
	struct s *sp;
};

int main()
{
	struct a *u;

	u = 0;
	return ((sizeof (*u->ip) + sizeof *u->lp + sizeof (*u->sp) +
	    sizeof (*(u->lp)) + sizeof (*u->cp) + sizeof *u->sp) * 2 - 4);
}
