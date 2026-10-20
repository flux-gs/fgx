/* c12_shim.c — construct 12: a libc shim (sprintf) fills a caller buffer that is
 * a soft-stack LOCAL (bank != DBR).  The shim must write to the caller's buffer
 * bank (pushed far-ptr), not DBR/path bank.  %ld also exercises pf_pow10
 * (libc data read DBR-relative from the code seg). */
extern int sprintf();

int c12_check(void)
{
	char buf[12];                        /* soft-stack local, bank != DBR */
	sprintf(buf, "%ld", 123456L);        /* %ld -> pf_pow10 path + non-DBR dest */
	return buf[0] == '1' && buf[1] == '2' && buf[2] == '3'
	    && buf[3] == '4' && buf[4] == '5' && buf[5] == '6' && buf[6] == 0;
}
