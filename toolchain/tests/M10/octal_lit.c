/* M10: C octal integer literals (0NNN).  The lexer had no octal branch, so a
 * leading-0 literal fell into the decimal loop: 0377 lexed as decimal 377, and
 * Merlin then read `LDA #377` as $0179 -- masking od's `*cc & 0377` down to
 * & $79 and mangling its -c char dump (0x80 -> '\0', 'B' -> '@').  Each octal
 * constant must equal its true value; the `& 0377` line mirrors od's c_put. */
int main(void)
{
    int b;

    if (0377 != 255) return 1;
    if (0177 != 127) return 2;
    if (010  != 8)   return 3;
    if (07   != 7)   return 4;
    if (0    != 0)   return 5;

    b = 0x80;
    if ((b & 0377) != 0x80) return 6;   /* od c_put: c = *cc & 0377 */

    return 42;
}
