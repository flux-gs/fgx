/* c40_arrderef.c — construct 40: UNARY DEREF of a decayed LOCAL array (`*arr`).
 *
 * `*arr` where arr is a local array === arr[0].  The array's frame slot IS the
 * data (bank 0), so the deref must read at bank 0.  The pre-2026-07-13 fcc built
 * an N_DEREF_FAST / IR_DEREF_LOCAL for `*arr`, which loads the frame bytes AS a
 * stored far pointer (offset @ slot+0, BANK @ slot+2) — but an array has no
 * stored pointer.  The "bank" came from a stale hardware-stack slot that, in a
 * multibank build, aliases the far-call return PB (a nonzero CODE bank) → the
 * deref read arr[0] from the WRONG bank.  Single-bank hid it (code bank == 0).
 *
 * Real-world mole: elvis `char key[2]; switch(*key){case ctrl('['):...}` — ESC
 * and CR read the wrong bank, never matched, and were inserted literally (^[ /
 * ^M).  Fix: route `*arr` through the proven indexed-read path (arr[0]).
 * Covers char-array, int-array, and multi-dim row-decay (*m === m[0], char*). */

int c40_check(void)
{
	char key[2];
	int  ia[2];
	char m[2][3];
	char *row;

	key[0] = 27; key[1] = 13;          /* ESC, CR */
	ia[0]  = 0x1234; ia[1] = 7;
	m[0][0] = 0x55; m[1][0] = 0x66;

	if (*key != 27)     return 0;      /* char-array:  *key === key[0]   */
	if (*ia  != 0x1234) return 0;      /* int-array:   *ia  === ia[0]    */
	row = *m;                          /* multi-dim:   *m   === m[0] (char*) */
	if (row[0] != 0x55) return 0;

	return 1;
}
