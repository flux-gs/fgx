/* netprobe -- the network modules' self-test: code banks over one data bank.
 * Built only at kernel.netprobe = 1.  This half is in bsdnet0, netprobe2.c in
 * bsdnet2.  Returns 0, or the first failed case. */
int	np_seen0;		/* written here, read in bank 1 */
extern	int np_seen1;		/* the reverse */
int	np_common;		/* tentative in both files: one object */
int	np_inited = 7;		/* an initializer reaches the data image */
int	*np_ptr = &np_inited;	/* so does a pointer one */
char	*np_str = "direct";

extern	int np2_read0(), np2_write1(), netprobe3(), netprobe4(), netprobe5();
extern	long np2_call();
extern	int *np2_commonaddr();
extern	char *np2_string();
extern	long np2_lmul();
extern	int (*np2_vec)();
extern	int np2_vec_called;

static int
same(a, b)
	register char *a, *b;
{
	while (*a == *b) {
		if (*a == 0)
			return (1);
		a++;
		b++;
	}
	return (0);
}

static char np_buf[9];

static int
np_fill()
{
	register int i;

	for (i = 0; i < 8; i++)
		np_buf[i] = 'a' + i;
	np_buf[8] = 0;
	return (0);
}

static int
np_bcopy()
{
	char st[9];

	np_fill();
	bcopy(np_buf, st, 9);			/* data bank to stack bank */
	if (!same(st, "abcdefgh"))
		return (1);
	bcopy(np_buf, np_buf + 2, 6);		/* dst above src: backward */
	if (!same(np_buf, "ababcdef"))
		return (1);
	np_fill();
	bcopy(np_buf + 2, np_buf, 6);		/* dst below src: forward */
	if (!same(np_buf, "cdefghgh"))
		return (1);
	np_fill();
	bcopy(np_buf, np_buf + 1, 0);		/* nothing moves */
	if (!same(np_buf, "abcdefgh"))
		return (1);
	return (0);
}

int
netprobe()
{
	int local;
	long l;

	/* 1: globals cross both ways */
	np_seen0 = 0x1234;
	if (np2_read0() != 0x1234)
		return (1);
	np2_write1(0x4321);
	if (np_seen1 != 0x4321)
		return (1);
	/* 2: one object for a tentative definition in two files */
	*np2_commonaddr() = 0x5555;
	if (np_common != 0x5555)
		return (2);
	/* 3: a direct call passes ints and a pointer, returns a long */
	local = 9;
	l = np2_call(3, 4, &local);
	if (l != 0x12340007L || local != 10)
		return (3);
	/* 4: a call through a cell in the data bank */
	if (np2_vec == 0 || (*np2_vec)(21) != 42 || np2_vec_called != 1)
		return (4);
	/* 5: a literal from the other file, and pointer initializers */
	if (!same(np2_string(), "bank1") || !same(np_str, "direct"))
		return (5);
	if (*np_ptr != 7)
		return (5);
	/* 6: the runtime's scratch is shared; a value held across its use */
	l = 70000L;
	if (l * 3L != 210000L || np2_lmul(70000L, 3L) != 210000L ||
	    l / 7L != 10000L || l != 70000L)
		return (6);
	/* 7: bcopy as 2.11BSD's: across banks, and an overlap either way */
	if (np_bcopy() != 0)
		return (7);
	if ((local = netprobe3()) != 0)
		return (local);
	if ((local = netprobe4()) != 0)
		return (local);
	return (netprobe5());
}
