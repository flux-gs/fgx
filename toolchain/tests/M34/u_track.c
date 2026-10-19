/* u_track.c — A-1 drop sites: unsigned-ness must survive ARRAY-ELEMENT,
 * FUNCTION-RETURN, PTR->FIELD, and (unsigned)-CAST positions (2026-07-06;
 * all four silently compared signed before).  0x9000 vs 0x100 is the
 * discriminator: unsigned true, signed (-28672) false.  Also pins
 * unsigned->long widening (zero-extend, not sign-extend).  Exit 42. */
struct us { unsigned int v; };

unsigned int garr[3];
struct us gs;
struct us *gp;

unsigned int uret()
{
	return 0x9000;
}

int main()
{
	unsigned int u;
	unsigned long ul;
	int si, n;

	n = 0;
	garr[1] = 0x9000;
	gs.v = 0x9000;
	gp = &gs;
	if (garr[1] > 0x100) n += 1;          /* array element */
	if (uret() > 0x100) n += 2;           /* function return */
	if (gp->v > 0x100) n += 4;            /* ptr->field */
	si = 0x9000;                          /* as int: -28672 */
	if ((unsigned)si > 0x100) n += 8;     /* cast makes it unsigned */
	u = 0x9000;
	ul = u;                               /* widen: MUST zero-extend */
	if ((ul >> 8) == 0x90) n += 16;       /* sign-extend would give 0xFFFF90 */
	return n == 31 ? 42 : n;
}
