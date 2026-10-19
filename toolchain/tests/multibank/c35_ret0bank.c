/* c35_ret0bank.c — NULL return from a pointer-returning function AFTER a
 * mid-body K&R implicit declaration (Increment 4 regression, found by the
 * stable-handles differential in ed(1)'s address()).
 *
 * The `return 0;` bank normalization gate reads the CURRENT function's
 * return type.  Before g_cur_fn_idx, "current" meant "last g_funcs slot" —
 * and the implicit declaration of c35_note() below APPENDS a slot, so the
 * gate read c35_note's int return type instead of c35_get's char*, skipped
 * the normalization, and the NULL leaked whatever bank the caller's last
 * deref left in _fcc_ptr+2.  The 4-byte pointer compare then saw
 * $<bank>:0000 != NULL and misbranched. */
extern char *malloc(unsigned long n);   /* WIDE (M-4): a 16-bit prototype under-fills the 32-bit size read */

char *c35_dat;
int   c35_seen;

char *
c35_get(want)
{
	c35_note(want + 1);          /* UNDECLARED here: implicit int decl
	                              * appends a g_funcs slot mid-body */
	if (want)
		return c35_dat;
	return 0;                    /* must carry bank 0, not the caller's
	                              * poisoned _fcc_ptr+2 */
}

c35_note(v)
{
	c35_seen = v;
	return 0;
}

int
c35_check(void)
{
	char *p;
	c35_dat = malloc(8);
	if (c35_dat == 0) return 0;
	*c35_dat = 42;               /* poison _fcc_ptr+2 with the heap bank */
	p = c35_get(0);              /* NULL return: bank must be zeroed */
	if (p != 0) return 0;        /* 4-byte compare incl. the bank byte */
	if (*c35_get(1) != 42) return 0;
	return c35_seen == 2;
}
