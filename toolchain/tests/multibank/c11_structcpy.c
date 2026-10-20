/* c11_structcpy.c — construct 11: whole-struct value copy from a data-bank
 * pointer (a = *p).  Mole: elvis add() buf = *blk.  Dual path: copy into a
 * soft-stack local AND a data-bank global, so a consistent-wrong-source shows.
 * Scalar fields (byte-packed since B-8 2026-07-06 — this struct is 6 bytes;
 * a char[] field can't be brace-initialized). */
struct c11_b {
	unsigned char d0;
	unsigned char d1;
	unsigned char d2;
	unsigned char d3;
	unsigned char d4;
	unsigned char d5;
};
struct c11_b c11_g = { 0x51, 0x52, 0x53, 0x54, 0x55, 0x56 };
struct c11_b c11_dst;

int c11_check(void)
{
	struct c11_b *p = &c11_g;
	struct c11_b local;
	local = *p;                          /* cross-bank block move -> soft stack */
	c11_dst = *p;                        /* cross-bank block move -> data bank (2nd path) */
	return local.d0 == 0x51 && local.d5 == 0x56
	    && c11_dst.d0 == 0x51 && c11_dst.d5 == 0x56;
}
