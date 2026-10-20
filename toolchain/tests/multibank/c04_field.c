/* c04_field.c — construct 4: a pointer to a struct FIELD in a data-bank global,
 * read THEN stored through.  2nd path: verify the store via the whole struct's
 * fields (not re-read through the same pointer). */
struct c04_r { unsigned char a; unsigned char b; unsigned char c; unsigned char d; };
struct c04_r c04_g = { 0x41, 0x42, 0x43, 0x44 };

int c04_check(void)
{
	unsigned char *pb = &c04_g.b;
	if (*pb != 0x42) return 0;
	*pb = 0x77;                          /* store through far field ptr */
	return c04_g.b == 0x77 && c04_g.a == 0x41 && c04_g.c == 0x43 && c04_g.d == 0x44;
}
