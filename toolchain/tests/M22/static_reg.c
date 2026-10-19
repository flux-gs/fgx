/* A `static` local declaration followed by a declaration whose leading token
 * is a MACRO expanding to `register` (elvis's `REG`).  The `static` local is
 * parsed via parse_stmt (the prologue decl loop doesn't list STATIC_KW), so the
 * NEXT decl also goes through parse_stmt, where `register` (a TOK_IDENT) enters
 * the label probe.  That probe's lookahead must snapshot/restore the pp-frame
 * (lex_peek_save/restore); a raw g_pos/g_cur restore dangled into the popped
 * `REG` macro-expansion buffer and mis-parsed (`expected ';'` / `expected
 * declarator name` — elvis blk/vi/input/misc/redraw).  Also verifies the
 * static local actually persists across calls.  -> 42. */
#define REG register

int accum(void)
{
	static int	calls;   /* static local: must persist across calls   */
	REG int		add;     /* macro -> register, right after the static */

	add = 7;
	calls = calls + 1;
	return calls * add;
}

int main(void)
{
	int r;

	r = accum();        /* calls=1: 1*7 = 7  */
	r = accum();        /* calls=2: 2*7 = 14 */
	r = accum();        /* calls=3: 3*7 = 21 */
	return r + 21;      /* 21 + 21 = 42 (persistence proven) */
}
