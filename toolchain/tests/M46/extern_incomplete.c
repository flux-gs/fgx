/* An extern declaration of a struct object before its struct is complete,
 * as 2.11BSD's netinet/in.h declares `extern struct domain inetdomain;'
 * where struct domain may not be complete yet.  K&R A.8.3: "Objects with an
 * incomplete structure or union type may be mentioned in contexts where
 * their size is not needed, for example in declarations (not
 * definitions)".  The struct is completed and the object defined later;
 * sizeof and member access then see the whole type.  Returns 42. */
extern struct domain inetdomain;

struct domain {
	int	dom_family;
	struct	domain *dom_next;
};

struct domain inetdomain = { 40, 0 };

int main()
{
	if (sizeof (inetdomain) != sizeof (struct domain))
		return (1);
	inetdomain.dom_next = &inetdomain;
	return (inetdomain.dom_family + (inetdomain.dom_next == &inetdomain) * 2);
}
