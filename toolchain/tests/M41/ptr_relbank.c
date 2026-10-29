/* Pointers into one object that spans a bank boundary compare by their
 * whole address (K&R A.7.9: pointers to members of the same object
 * compare by their position in it).  Comparing the offset words alone put
 * $09:0003 below $08:FF00.  Returns 42. */
int
main()
{
	char *lo, *hi;
	int r;

	lo = (char *)0x08FF00L;
	hi = (char *)0x090003L;
	r = 0;
	if (lo < hi)	r += 10;
	if (hi > lo)	r += 10;
	if (!(hi < lo))	r += 10;
	if (lo <= hi && hi >= lo) r += 12;
	return r;
}
