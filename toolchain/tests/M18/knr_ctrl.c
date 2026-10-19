/* K&R substitute-inside-CHAR-literal: the 2.11BSD CTRL('c')&037 idiom (telnet
 * escape/echo chars, sys/ttychars.h).  fcc previously kept 'c' (ANSI: no
 * substitution in literals) -> silent miscompile.  Now CTRL(]) = ']'&037 = 035
 * and CTRL(E) = 'E'&037 = 005. */
#define CTRL(c) ('c' & 037)
char escape = CTRL(]);
char echoc = CTRL(E);
int main() { return escape * 7 + echoc; }   /* 29*7 + 5 = 208 */
