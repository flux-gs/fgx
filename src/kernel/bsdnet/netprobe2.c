/* netprobe2 -- netprobe.c's other half, in bsdnet1. */
extern	int np_seen0;
int	np_seen1;
int	np_common;

int	np2_vec_called;

int
np2_read0()
{
	return (np_seen0);
}

int
np2_write1(v)
	int v;
{
	np_seen1 = v;
	return (0);
}

long
np2_call(a, b, p)
	int a, b, *p;
{
	(*p)++;
	return (0x12340000L + a + b);
}

int *
np2_commonaddr()
{
	return (&np_common);
}

char *
np2_string()
{
	return ("bank1");
}

long
np2_lmul(a, b)
	long a, b;
{
	return (a * b);
}

static int
np2_target(v)
	int v;
{
	np2_vec_called++;
	return (v * 2);
}

int	(*np2_vec)() = np2_target;
