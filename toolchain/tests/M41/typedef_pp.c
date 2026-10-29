/* A typedef'd pointer to pointer, and one to long (K&R A.8.9: "A typedef
 * declaration attributes a type to each name among its declarators in the
 * usual way", its example making Blockptr "pointer to long").
 * `typedef char **Handle'.
 * Recording only "is a pointer" made *h read one byte through h.
 * Returns 42. */
typedef char **Handle;
typedef long *LP;

char s[] = "*";
char *sp = s;
long lv = 42L;

int
main()
{
	Handle h;
	LP lp;

	h = &sp;
	lp = &lv;
	if (**h != '*')
		return 1;
	return (int)*lp;
}
