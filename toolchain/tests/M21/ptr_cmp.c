/* Pointer relational operators (< <= > >=) must compile to UNSIGNED comparisons
 * (address compare), NOT signed.  A signed 16-bit compare reads a pointer offset
 * whose bit15 is set -- e.g. a malloc'd array that grew across heap offset $8000 --
 * as a NEGATIVE number and INVERTS the loop bound.  That was the ed(1) substitute
 * crash: `for(a1=addr1; a1<=addr2; a1++)` mis-terminated once the line-handle
 * array straddled $8000 (addr2 low word $84A0 read as signed -31584).  Pointers
 * into one object share a bank, so an unsigned 16-bit OFFSET compare is correct.
 *
 * GOLDEN ASSERTION: pcount()/the ptr compares in main() must emit _fcc_leu16 /
 * _fcc_ltu16 / _fcc_gtu16 / _fcc_geu16 (UNSIGNED).  The int control icmp() must
 * STAY _fcc_les16 (SIGNED) -- the fix must not over-broaden to plain ints.
 * Logic (clang-checked) returns 42. */
int arr[8];
int *lo, *hi;

int pcount()              /* pointer <= : UNSIGNED (_fcc_leu16) */
{
	int *p, n;
	n = 0;
	for (p = lo; p <= hi; p++)
		n++;
	return n;
}

int icmp(a, b)            /* int <= : must STAY SIGNED (_fcc_les16) */
{
	return a <= b;
}

int main()
{
	int c;
	lo = &arr[0];
	hi = &arr[3];
	c = pcount();             /* lo..hi inclusive = 4 elements */
	if (c != 4) return 1;
	if (!(lo <  hi)) return 2;   /* ptr <  : _fcc_ltu16 */
	if (!(hi >  lo)) return 3;   /* ptr >  : _fcc_gtu16 */
	if (!(hi >= lo)) return 4;   /* ptr >= : _fcc_geu16 */
	if (icmp(3, 5)  != 1) return 5;
	if (icmp(-1, 0) != 1) return 6;   /* signed: -1 <= 0 TRUE (would be FALSE if unsigned) */
	return 42;
}
