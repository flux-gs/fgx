/* Cross-bank WRITE coverage for the software stack.  main writes local char
 * and int arrays element-by-element (soft-stack stores), then passes their
 * addresses to reader functions that read them through POINTER PARAMS — a far
 * deref that honors the software-stack bank the address names.  If the element
 * writes had gone to bank 0 (the old hard-stack STAL $000000,X) while the far
 * reads target the software-stack bank, the sums are 0.  This is the write-side
 * analogue of lc_memcpy (whose memcpy writes far but the read was bank-0).
 * -> 42 */

int readc(char *p)
{
	return p[0] + p[1] + p[2];
}

int readi(int *p)
{
	return p[0] + p[1];
}

int main(void)
{
	char buf[8];
	int  vv[4];

	buf[0] = 10;
	buf[1] = 14;
	buf[2] = 18;                 /* char-array writes: 10+14+18 = 42 */
	vv[0] = 5;
	vv[1] = 15;                  /* int-array writes: 5+15 = 20 */

	return readc(buf) + readi(vv) - 20;   /* 42 + 20 - 20 = 42 */
}
