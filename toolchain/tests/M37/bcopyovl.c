/* bcopy copies as if through a temporary (4.3BSD): with the source and
 * destination overlapping by one byte in either direction, at odd and even
 * lengths, and apart.  Returns 42 when every copy matches a byte loop. */
#include <string.h>

char a[40], w[40];

void
fill()
{
	int i;
	for (i = 0; i < 40; i++)
		a[i] = w[i] = 'A' + i;
}

int
ref(s, d, n)
int s, d, n;
{
	int i;
	char t[40];
	for (i = 0; i < n; i++)
		t[i] = w[s + i];
	for (i = 0; i < n; i++)
		w[d + i] = t[i];
	for (i = 0; i < 40; i++)
		if (a[i] != w[i])
			return 0;
	return 1;
}

int
one(s, d, n)
int s, d, n;
{
	fill();
	bcopy(a + s, a + d, n);
	return ref(s, d, n);
}

int main()
{
	int r;

	r = 0;
	if (one(4, 5, 7)) r += 6;	/* up one, odd */
	if (one(4, 5, 8)) r += 6;	/* up one, even */
	if (one(5, 4, 7)) r += 6;	/* down one, odd */
	if (one(5, 4, 8)) r += 6;	/* down one, even */
	if (one(0, 20, 13)) r += 6;	/* apart */
	if (one(3, 3, 9) && one(2, 9, 1)) r += 6;	/* same place; one byte */
	fill();
	bcopy(a + 1, a + 2, 0);
	bcopy(a + 1, a + 2, -1);
	if (ref(0, 0, 0)) r += 6;	/* nothing moves */
	return r;
}
