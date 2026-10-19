/* Function-like macro whose body ends in an array subscript, used on the RHS of
 * assignments — elvis's ctype idiom toupper(c) = _ct_toupper[UCHAR(c)], reached
 * as `*dst++ = toupper(*cpy++)` (regsub) and `blk.c[j] = tolower(*pos)` (vcmd).
 *
 * Exercises the lexer's macro-frame token lifetime: parse_assign's assignment-
 * target classification does a lookahead over the macro-expanded `tab[..]`; that
 * scan exhausts and pops the expansion frame.  Before the fix a plain g_pos
 * rewind (a) read the base ident back as '' ("'' undeclared") because the frame
 * buffer was freed out from under g_cur.id_ptr, and (b) on the lex_peek re-install
 * path re-retired the same buffer, double-freeing it (malloc abort).  Now the
 * frame buffer is deferred-freed (dedup + live-guard) and the lookahead is
 * frame-safe (lex_peek_save/restore).  -> 42. */
#define UCHAR(c)   ((c) & 0xff)
#define UP(c)      up_tab[UCHAR(c)]
#define LO(c)      lo_tab[UCHAR(c)]

unsigned char up_tab[128];
unsigned char lo_tab[128];
char sbuf[4];
char dbuf[4];

int main(void)
{
	int   i;
	char *dp;
	char *sp;
	int   sum;

	for (i = 0; i < 128; i++) {
		up_tab[i] = (unsigned char)i;
		lo_tab[i] = (unsigned char)i;
	}
	up_tab['a'] = 'A';
	lo_tab['A'] = 'a';

	sbuf[0] = 'a';
	sbuf[1] = 'A';
	sbuf[2] = 0;

	/* (1) deref-postinc store, func-like macro w/ subscript body on the RHS */
	dp = dbuf;
	sp = sbuf;
	*dp++ = UP(*sp++);          /* dbuf[0] = up_tab['a'] = 'A' */

	/* (2) subscript-lvalue LHS + macro-subscript RHS (rvalue lookahead rewind) */
	dbuf[1] = LO(sbuf[1]);      /* dbuf[1] = lo_tab['A'] = 'a' */

	sum = 0;
	if (dbuf[0] == 'A') sum += 20;
	if (dbuf[1] == 'a') sum += 22;
	return sum;                 /* 42 */
}
