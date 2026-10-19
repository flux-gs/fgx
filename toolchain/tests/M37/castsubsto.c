/* ((cast)ptr)[i] = rhs — indexed store through a parenthesized pointer cast
 * (compress tab_suffixof: a long* table reused as a byte array).  Was: the
 * statement-level redundant-paren strip dropped the store ("expected ';'"
 * at '=") because the outer parens are load-bearing when '[' follows.  A
 * read `x = ((cast)p)[i]` already worked; this is the store twin.  Exit 42. */
long words[4];

int main(void)
{
	int i;
	for (i = 0; i < 8; i++)
		((char *)words)[i] = (char)(i + 1);   /* bytes 1..8 into long[] */
	if (((char *)words)[0] != 1) return 1;
	if (((char *)words)[7] != 8) return 2;
	return ((char *)words)[5] * 7;            /* 6 * 7 = 42 */
}
