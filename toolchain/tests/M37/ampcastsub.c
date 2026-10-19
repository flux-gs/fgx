/* &((cast)ptr)[i] — address of an indexed cast-value, semantically
 * `(cast)ptr + i` (compress de_stack: `&((char_type *)(htab))[idx]`).  Was:
 * die "expected identifier after '&'".  The greedy amp-paren loop eats the
 * cast's own '(', so the fix rewinds and re-parses `&(EXPR)[i]`.  Covers a
 * typedef cast (char_type) — the type name lexes as an IDENT.  Exit 42. */
typedef char char_type;
long words[4];

int main(void)
{
	char_type *p;
	((char *)words)[3] = 42;
	p = &((char_type *)(words))[3];   /* &(words-as-bytes)[3] */
	return *p;                        /* 42 */
}
