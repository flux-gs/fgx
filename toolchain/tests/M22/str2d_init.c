/* A 2D char array initialized with STRING-LITERAL rows: `char x[][4] = { "..",
 * .. }` — elvis main.c's digtable[][4].  Each string literal fills one 4-byte
 * innermost row (chars, then a NUL if it fits, zero-pad to the row length; a
 * string exactly N bytes keeps no NUL).  parse_nested_brace_init now accepts a
 * string at the second-to-last level instead of only a `{ 'a','b',.. }` brace
 * group; the emitted bytes are identical to the equivalent nested-brace form.
 * Exercises an octal escape, exact-fit NUL, short-row zero-fill, an empty row,
 * and [row][col] indexing (row stride 4).  -> 42. */
char dig[][4] = { "C,\5", "ab", "" };

int main(void)
{
	int s;

	if (dig[0][0] != 'C') return 1;
	if (dig[0][1] != ',') return 2;
	if (dig[0][2] != 5)   return 3;   /* octal escape \5           */
	if (dig[0][3] != 0)   return 4;   /* NUL fills the row exactly */
	if (dig[1][0] != 'a') return 5;
	if (dig[1][2] != 0)   return 6;   /* zero-fill after short "ab" */
	if (dig[2][0] != 0)   return 7;   /* empty row: all zero        */

	s = dig[1][0] - dig[1][1];        /* 'a' - 'b' = 97 - 98 = -1 */
	return 43 + s;                    /* 42 */
}
