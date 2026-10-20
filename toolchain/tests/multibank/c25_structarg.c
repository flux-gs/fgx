/* c25_structarg.c — gap construct (parse_stmt.c:3403): pass a struct BY VALUE as
 * an argument.  fcc copies the struct arg onto the callee stack with an MVN block
 * move; the source (a data-bank global struct) bank must be correct.  The callee
 * (a separate TU, different bank) reads the copied struct. */
struct c25_s { int a; int b; int c; };
struct c25_s c25_g = { 0x25, 0x35, 0x45 };

extern int c25_sum(struct c25_s s);      /* by-value struct param, different bank */

int c25_check(void)
{
	return c25_sum(c25_g) == (0x25 + 0x35 + 0x45);
}
