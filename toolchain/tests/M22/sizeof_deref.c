/* sizeof of a dereference expression: `sizeof *ptr` — input.c's
 * `dp = (struct _DIG *)malloc(sizeof *dp)`.  Peels each '*' via DECREF from the
 * operand's type, then sizes the pointee.  Compares the deref form against the
 * direct-type form so the check is host-portable (no absolute long/ptr size).
 * -> 42. */
struct big { int a; long b; char c[10]; };
struct big *bp;
char  *cp;
long  *lp;
char **cpp;

int main(void)
{
	if (sizeof *cp  != 1)              return 1;   /* char is 1 everywhere */
	if (sizeof *cp  != sizeof(char))   return 2;
	if (sizeof *lp  != sizeof(long))   return 3;
	if (sizeof *cpp != sizeof(char *)) return 4;   /* **ptr -> char*        */
	if (sizeof *bp  != sizeof(struct big)) return 5;  /* deref == direct type */
	return 42;
}
