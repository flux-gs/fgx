/* G19 lock: octal + hex escapes inside STRING literals -- the sibling of
 * M21's char-literal escapes and M10's octal integer literals.  fcc folds
 * "\033", "\xNN", and "\N"/"\NN"/"\NNN" at string-scan time, so ANSI/term
 * strings ("\033[2J\033[H") and ascii.h's "\334" carry the right bytes.
 *
 * A stale colortest.c note once claimed strings could not hold these escapes
 * (hence its printf("%c",27) workaround); they can.  This fixture pins the
 * behaviour so the lexer can't silently drop it.  Returns 42 on success; a
 * mismatched byte returns the failing check number instead.
 */
int main(void)
{
	char *ansi = "\033[2J\033[H";	/* 1B 5B 32 4A 1B 5B 48 00 */
	char *hex  = "\x1b[\x41";	/* 1B 5B 41 00 */
	char *oct  = "\7\33\334";	/* 07 1B DC 00  (1-, 2-, 3-digit octal) */

	if ((ansi[0] & 0xFF) != 0x1B) return 1;
	if (ansi[1] != '[')           return 2;
	if (ansi[2] != '2')           return 3;
	if (ansi[3] != 'J')           return 4;
	if ((ansi[4] & 0xFF) != 0x1B) return 5;
	if (ansi[5] != '[')           return 6;
	if (ansi[6] != 'H')           return 7;
	if (ansi[7] != 0)             return 8;

	if ((hex[0] & 0xFF) != 0x1B)  return 9;
	if (hex[1] != '[')            return 10;
	if ((hex[2] & 0xFF) != 0x41)  return 11;

	if ((oct[0] & 0xFF) != 0x07)  return 12;
	if ((oct[1] & 0xFF) != 0x1B)  return 13;
	if ((oct[2] & 0xFF) != 0xDC)  return 14;
	if (oct[3] != 0)              return 15;

	return 42;
}
