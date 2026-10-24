/* putc on a FILE with room, and on a line-buffered FILE whose buffer is
 * full by its count: the char is stored and not flushed when it is not a
 * newline.  put() holds one putc expansion, the size of which every stdio
 * user pays.  Returns 42 when both paths store and return the char. */
#include <stdio.h>

char b[8];

int put(c, fp)
int c;
FILE *fp;
{
	return putc(c, fp);
}

int main()
{
	FILE f;
	int r;

	r = 0;
	f._ptr = f._base = b;
	f._cnt = 2;
	f._bufsiz = 8;
	f._flag = _IOWRT;
	if (put('a', &f) == 'a' && put('b', &f) == 'b')
		r += 20;
	f._flag = _IOWRT | _IOLBF;
	if (put('c', &f) == 'c' && f._cnt == -1 && f._ptr == b + 3)
		r += 20;
	if (b[0] == 'a' && b[1] == 'b' && b[2] == 'c')
		r += 2;
	return r;
}
