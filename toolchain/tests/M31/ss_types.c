/* Software-stack scalar locals of every width: long / char / int / char*.  Each
 * is written and read back through [_fcc_ssp],Y (the long uses Y and Y+2; the
 * pointer's offset+bank both live in the frame).  The char* targets a GLOBAL
 * (address-of a local aggregate is Task 3), keeping this to pure scalars. -> 42 */
char gbuf[4];

int main(void)
{
	long  a;
	char  c;
	int   n;
	char *p;

	a = 100;
	c = 5;
	n = 30;
	gbuf[0] = 7;
	p = gbuf;                          /* char* local = a global's address */

	return (int)a - c - n - *p - 16;   /* 100 - 5 - 30 - 7 - 16 = 42 */
}
