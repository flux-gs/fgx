/* c07_ret.c — construct 7: deref a pointer returned across a bank boundary from
 * c07_get() (pinned in another segment via the bankmap 'callees' + lint). */
extern unsigned char *c07_get(void);

int c07_check(void)
{
	unsigned char *p = c07_get();
	return p[0] == 0x71 && p[3] == 0x74;
}
