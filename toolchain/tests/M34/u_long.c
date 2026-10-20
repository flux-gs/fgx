/* u_long.c — A-1 unsigned long: compare/div/mod/>> all fell to the SIGNED
 * long helpers before 2026-07-06 (and the unsigned runtime didn't exist:
 * _fcc_long_{ltu,gtu,leu,geu,divu,modu,shru} are new).  0x80000000-class
 * values discriminate: unsigned-huge vs signed-negative.  The /10 case is
 * the live dhclient u32dec() miscompile shape (RFC 2131 infinite lease
 * 0xFFFFFFFF).  Exit 42. */
unsigned long ua, ub;

int main()
{
	int n;

	n = 0;
	ua = 0x80000000;
	ub = 10;
	if (ua > ub) n += 1;                  /* signed: negative > 10 false */
	if (ua >= 0x7FFFFFFF) n += 2;
	if (ua / ub == 214748364) n += 4;     /* signed div: wrong quotient */
	if (ua % ub == 8) n += 8;
	ua = 0xFFFFFFFF;
	if (ua / 10 == 429496729) n += 16;    /* the dhclient digit case */
	if ((ua >> 4) == 0x0FFFFFFF) n += 32; /* LOGICAL shr; arithmetic
	                                         sign-fills to 0xFFFFFFFF */
	return n == 63 ? 42 : n;
}
