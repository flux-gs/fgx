/* c32_time.c — time(2) via the new c_time RTC shim (2026-07-06 quick-win):
 * Unix epoch synthesized from Misc Toolset ReadTimeHex, and the result ALSO
 * stored through a SOFT-STACK long* (the bank-carrying [_fcc_ptr] lane — a
 * DBR-relative store would land t2 in the wrong bank and leave it 0). */
extern long time();

int c32_check(void)
{
	long t, t2;

	t2 = 0;
	t = time(&t2);
	if (t < 1577836800)  return 0;   /* before 2020: RTC/epoch math bogus */
	if (t > 2100000000)  return 0;   /* past 2036: unpack bogus */
	return t2 == t;                  /* store-through-pointer lane */
}
