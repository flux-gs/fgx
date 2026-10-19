/* c23_idxstore.c — gap construct (parse_stmt.c:2576): `g[i].c[j] = p[k]`.  The
 * LHS array's bank must be re-established (PHB=DBR) for the store AFTER the RHS
 * deref (p[k]) clobbered _fcc_ptr+2 with the RHS's bank.  If not, the store lands
 * in the RHS's bank instead of the array's data bank. */
struct c23_s { unsigned char c[2]; };
struct c23_s c23_g[3];                   /* uninit (array field can't be brace-init) */
unsigned char c23_src[2] = { 0x23, 0x33 };

int c23_check(void)
{
	unsigned char *p = c23_src;
	c23_g[1].c[0] = p[0];                /* indexed struct-array field store; RHS deref clobbers bank */
	c23_g[1].c[1] = p[1];
	return c23_g[1].c[0] == 0x23 && c23_g[1].c[1] == 0x33;
}
