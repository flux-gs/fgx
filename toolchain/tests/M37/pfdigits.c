/* printf's [diouxX] digits on both sides of 16 bits: a decimal value that
 * fits in a word finishes in u_int, a larger one divides as a long first,
 * and octal and hex shift.  Returns 42 when every string matches. */
#include <stdio.h>
#include <string.h>

char b[64];

int
same(s)
char *s;
{
	return strcmp(b, s) == 0;
}

int main()
{
	int r;

	r = 0;
	sprintf(b, "%d %d %u %d", 0, 9, 0xffff, -32767 - 1);
	if (same("0 9 65535 -32768")) r += 6;
	sprintf(b, "%ld %lu %ld", 65535L, 65536L, 655359L);
	if (same("65535 65536 655359")) r += 6;
	sprintf(b, "%lu %ld", 4294967295L, -2147483647L - 1);
	if (same("4294967295 -2147483648")) r += 6;
	sprintf(b, "%o %#o %lo %o", 8, 8, 0x10000L, 0);
	if (same("10 010 200000 0")) r += 6;
	sprintf(b, "%x %X %#lx %lx", 0xbeef, 0xbeef, 0x12345L, 0xffffffffL);
	if (same("beef BEEF 0x12345 ffffffff")) r += 6;
	sprintf(b, "%5d|%-6lu|%.3d|%.0d", 42, 100000L, 7, 0);
	if (same("   42|100000|007|")) r += 6;
	sprintf(b, "%c%s%d", 'x', "y", 10);
	if (same("xy10")) r += 6;
	return r;
}
