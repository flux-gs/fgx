/* Parenthesized-lvalue compound assignment `(x) op= y` — the G21 case the lexer
 * had explicitly deferred (needed by elvis recycle's BCLR `((byte) &= ~m)`).
 * The inner lvalue is copied to a synthetic frame and re-dispatched, so codegen
 * matches the un-parenthesized store.  Local scalar + local-array element across
 * several operators.  -> 42.
 *
 * (Global-array-element compound assign is a separate pre-existing codegen bug —
 * covered by a distinct fix, not exercised here.) */
int gsv;

int main(void)
{
	int lsv;
	int la[4];

	lsv = 40;    (lsv)   += 2;       /* 40 + 2    = 42  */
	la[1] = 15;  (la[1]) &= 6;       /* 15 & 6    = 6   */
	la[2] = 0xF0;(la[2]) |= 0x0F;    /* 240 | 15  = 255 */
	la[3] = 200; (la[3]) -= 100;     /* 200 - 100 = 100 */
	gsv = 20;    (gsv)   *= 2;       /* 20 * 2    = 40  (global scalar) */

	if (la[1] != 6)   return 1;
	if (la[2] != 255) return 2;
	if (la[3] != 100) return 3;
	if (gsv   != 40)  return 4;
	return lsv;                      /* 42 */
}
