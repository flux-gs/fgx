/* c42_ptrspill.c — construct 42: SPILLED / MATERIALIZED pointer-local banks
 * (train-2 phase 0b gap-fill).  The 20-site flip sweep left three
 * _fcc_ptr+2 sites green — emit.c 541 (bank load for a stack-SLOT pointer
 * store), 571 (DP-IMG -> _fcc_ptr+2 materialization), 652 (_fcc_ptr+2 ->
 * DP-IMG store) — because every existing construct keeps its pointer locals
 * PROMOTED, so the spill/materialize paths never run.  This construct holds
 * MORE live pointer locals than the DP-IMG pool, mixed heap + data banks,
 * across a foreign-call boundary, then verifies every pointer still derefs
 * its own bank (one is re-derived independently, the c10 rule; the data
 * anchors are cross-checked through the array itself). */
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

unsigned char c42_g[8];

static unsigned char *c42_id(unsigned char *p) { return p; }

int c42_check(void)
{
	unsigned char *p0 = (unsigned char *)malloc(2);
	unsigned char *p1 = (unsigned char *)malloc(2);
	unsigned char *p2 = (unsigned char *)malloc(2);
	unsigned char *p3 = (unsigned char *)malloc(2);
	unsigned char *p4 = &c42_g[0];
	unsigned char *p5 = &c42_g[4];
	unsigned char *q;

	if (!p0 || !p1 || !p2 || !p3) return 0;
	*p0 = 0x11; *p1 = 0x22; *p2 = 0x33; *p3 = 0x44;
	*p4 = 0x55; *p5 = 0x66;
	q = c42_id(p2);                 /* call boundary: live ptrs spill */
	*q = 0x77;
	return *p0 == 0x11 && *p1 == 0x22 && *p2 == 0x77 && *p3 == 0x44
	    && *p4 == 0x55 && *p5 == 0x66
	    && c42_g[0] == 0x55 && c42_g[4] == 0x66;
}
