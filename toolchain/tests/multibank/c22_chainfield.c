/* c22_chainfield.c — gap construct (emit.c:1228, G22 chained struct-ptr field).
 * Chained deref o->p->v across banks: loading the struct-pointer FIELD `p` must
 * carry the field's STORED bank (the pointed-to struct's data bank), not PHK
 * (own code bank).  If emit.c:1228 uses PHK, `o->p->v0` reads this code bank at
 * p's offset -> garbage.  p is stored at runtime so its 4-byte {offset,bank} is
 * a real far pointer into the data bank.  Scalar fields (a char[] field can't be
 * brace-initialized). */
struct c22_inner { unsigned char v0; unsigned char v1; unsigned char v2; unsigned char v3; };
struct c22_outer { struct c22_inner *p; };
struct c22_inner c22_ig = { 0xC2, 0xD2, 0xE2, 0xF2 };
struct c22_outer c22_og;

int c22_check(void)
{
	struct c22_outer *o = &c22_og;
	o->p = &c22_ig;                      /* store the struct-ptr field (offset + data bank) */
	return o->p->v0 == 0xC2 && o->p->v3 == 0xF2;   /* chained deref o->p->v */
}
