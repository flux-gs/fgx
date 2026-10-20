/* C parameter adjustment when the array-ness arrives via a TYPEDEF.
 *
 * K&R A.10.1: a parameter declared with array type has type "pointer to
 * element".  `T p[]` is decayed where the `[` is parsed, but the 2.11BSD
 * Bourne shell writes the array type into a typedef and the use site has no
 * `[` at all:
 *
 *      typedef struct sysnod SYSTAB[];
 *      syslook(w, syswds)  STRING w;  SYSTAB syswds;  { ... }
 *
 * Unadjusted, syswds stays a real array OBJECT, so reading it decays to the
 * address of its own parameter SLOT (bank 0) rather than the pointer the
 * caller pushed -- sh's builtin (`commands`) and reserved-word tables then
 * scan the stack, never match, and every builtin and shell keyword dies.
 *
 * Covers both parameter paths: K&R (walk) and ANSI prototype (count).
 */

struct sysnod {
	char	*sysnam;
	int	sysval;
};

typedef struct sysnod SYSTAB[];
typedef char MSG[];

MSG	tag = "cd";

struct sysnod table[] = {
	{ "cd",   2 },
	{ "read", 17 },
	{ 0,      0 },
};

/* K&R old-style parameter declaration -- the shape syslook() uses. */
int
walk(t)
	SYSTAB	t;
{
	int n;

	n = 0;
	while (t[n].sysnam)
		n++;
	return n;
}

/* ANSI prototype form of the same adjustment. */
int count(SYSTAB t)
{
	struct sysnod *p;
	int n;

	n = 0;
	for (p = t; p->sysnam; p++)
		n++;
	return n;
}

/* An array typedef of char, passed and indexed. */
int first(MSG m)
{
	return m[0];
}

int
main()
{
	return walk(table) + count(table) + first(tag);
}
