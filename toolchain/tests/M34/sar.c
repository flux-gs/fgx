/* sar.c — A-1's mirror bug: SIGNED >> was a logical LSR loop (_fcc_shr16),
 * zero-filling negatives.  Signed >> now selects the new arithmetic
 * _fcc_shrs16 (sign-preserving ROR); unsigned >> keeps the logical
 * routine/inline LSR.  Exit 42. */
int si;
unsigned int u;

int main()
{
	int n;

	n = 0;
	si = -16;
	if ((si >> 2) == -4) n += 1;   /* logical gave 16380 */
	si = -1;
	if ((si >> 1) == -1) n += 2;   /* sign-fill keeps -1 */
	u = 0x8000;
	if ((u >> 3) == 0x1000) n += 4; /* unsigned stays logical */
	return n == 7 ? 42 : n;
}
