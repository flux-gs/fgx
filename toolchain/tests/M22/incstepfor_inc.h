/* Regression helper for the fcc for-loop step-replay use-after-free on
 * #included files.  The LAST construct in this file is a for-loop WITH a step
 * clause -- exactly the shape that, before the parse_stmt.c is_macro guard,
 * caused fcc to free() this file's whole #include source buffer mid-parse (an
 * #include FILE frame also has owns_buf=1), so the post-loop `return s; }` was
 * lexed from freed heap ("unexpected character" / 0x02).  #included by
 * incstepfor.c; kept small so the freed block is recycled and would corrupt. */
int sumto(nn)
	int nn;
{
	int i, s;

	s = 0;
	for (i = 1; i <= nn; i = i + 1)
		s = s + i;
	return s;
}
