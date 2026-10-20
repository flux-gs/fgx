/* c39_target.c — cross-bank callee for c39_fnptrret (separate TU so the
 * bankmap lint can pin it to a different code segment than its caller). */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */
extern char *c39_stash;

char *
c39_get()
{
	char *p = malloc(2);
	if (!p) return 0;
	*p = 42;
	c39_stash = p;
	return p;
}
