/* c06_kr.c — construct 6: a char* passed through a K&R / vararg boundary and
 * consumed by %s (mole #2b: %s char* through a long slot dropped the bank).
 * c06_buf is an output buffer (not a tag), so it is not anti-coincidence-scanned. */
extern int sprintf();
char c06_buf[8];

int c06_check(void)
{
	char *name = "MB6";
	sprintf(c06_buf, "%s", name);        /* far char* through varargs -> %s */
	return c06_buf[0] == 'M' && c06_buf[1] == 'B' && c06_buf[2] == '6' && c06_buf[3] == 0;
}
