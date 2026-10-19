/* c24_gcompound.c — gap construct (parse_stmt.c:2815): `garr[i] op= x` compound
 * assignment to a GLOBAL array element.  A non-pointer global-array base is loaded
 * offset-only (no _fcc_ptr+2), so the read-modify-write must seed _fcc_ptr+2 = DBR
 * (PHB) or the [_fcc_ptr] read grabs a stale bank while the store writes the data
 * bank -> silent wrong value. */
int c24_g[4] = { 10, 20, 30, 40 };

int c24_check(void)
{
	c24_g[1] += 5;                       /* read-modify-write global array element */
	c24_g[2] *= 2;
	return c24_g[0] == 10 && c24_g[1] == 25 && c24_g[2] == 60 && c24_g[3] == 40;
}
