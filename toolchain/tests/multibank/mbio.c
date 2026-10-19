/* mbio.c — printf-free screen markers (so a %d/pow10 bank bug can't corrupt the
 * report) + far-pointer bank extraction.  Lives in seg0.
 *
 * mb_bankof reads byte 2 of a STORED far pointer: fcc lays far pointers out as
 * {offset:2, bank:1, pad:1} (fcc_runtime.s: _fcc_ptr+2 = bank byte), so the
 * bank of any pointer value p is ((unsigned char*)&p)[2]. */
extern int write();

static void mb_puts(char *s) { int n = 0; while (s[n]) n++; write(1, s, n); }

static void mb_num(int v, char *out)              /* 3-digit decimal, no libc */
{
	out[0] = '0' + (v / 100) % 10;
	out[1] = '0' + (v / 10) % 10;
	out[2] = '0' + v % 10;
	out[3] = 0;
}

void mb_mark(int id, int pass)                    /* "=MBi NNN P|F\n" per construct */
{
	char buf[5];
	mb_puts("=MBi ");
	mb_num(id, buf); mb_puts(buf);
	mb_puts(pass ? " P\n" : " F\n");
}

void mb_end(int code)                             /* "=MBEND NNN\n" final marker */
{
	char buf[5];
	mb_puts("=MBEND ");
	mb_num(code, buf); mb_puts(buf);
	mb_puts("\n");
}

int mb_bankof(void *p) { unsigned char *q = (unsigned char *)&p; return q[2]; }
