/* c26_stmtarg.c — gap construct (parse_stmt.c:3400): pass a struct BY VALUE in
 * STATEMENT context (a bare `f(structval);` expression-statement).  The
 * statement-context call emitter is a near-duplicate of the expression-context
 * one (c25) and had drifted: it still copied the struct arg with MVN $00,$00 +
 * PHK/PLB (source bank forced to 0, DBR left = PB), while the expression arm
 * does the bank-aware [_fcc_ptr],Y copy.  The callee (a separate TU, different
 * bank) stores the field sum into a data-seg global the checker then reads. */
struct c26_s { int a; int b; int c; };
struct c26_s c26_g = { 0x1126, 0x2226, 0x3326 };

extern void c26_take(struct c26_s s);    /* by-value struct param, different bank */
extern int  c26_result;                  /* written by the callee */

int c26_check(void)
{
	c26_take(c26_g);                     /* STATEMENT context — parse_stmt.c arm */
	return c26_result == (0x1126 + 0x2226 + 0x3326);
}
