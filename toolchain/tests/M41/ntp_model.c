/* The ntp(8) model of apple/fgx#447, increment 7 of
 * docs/history/plans/2026-09-23-fcc-64bit-double-plan.md, run on FGX.
 *
 * 2.11BSD's ntp.c (examples/2.11BSD/usr/usr.sbin/ntp/ntp.c:303-320) turns
 * the four 32.32 timestamps of an exchange into doubles with
 * ul_fixed_to_double() (ntpsubs.c:67, its non-GENERIC_UNS_BUG arm, carried
 * below) and takes the delay and offset from their differences.  The values
 * are seconds since 1900, about 3.97e9, where adjacent IEEE singles are 256 s
 * apart: with double a single, the host model in the issue gave offset errors
 * up to 166 s and delay errors up to 256.2 s.  K&R B.11 asks DBL_DIG 10.
 *
 * The exchange: the server's clock is 90 s ahead, each leg takes 0.1005 s
 * and the server holds the packet 0.010 s, so the delay is 0.201 s and the
 * offset 90 s.  The client's send time is swept across 256 s in 64 steps of
 * 4.000037 s.  Timestamps are built in integer microseconds and converted to
 * 32.32 with long long arithmetic, so the only floating point is ntp.c's.
 * The packet fields are in host order here; ntp.c's ntohl() is omitted.
 * A check fails when an error passes 1 microsecond, the resolution ntp.c
 * prints with %f.  A failing check returns its number; all passing returns
 * 42. */
typedef unsigned long u_long;

#define	JAN_1970	2208988800	/* 1970 - 1900 in seconds */

struct l_fixedpt {
	u_long int_part;
	u_long fraction;
};

double
ul_fixed_to_double(t)
	struct l_fixedpt *t;
{
	double a, b;

	a = (u_long) t->fraction;
	a = a / (4.294967296e9);/* shift dec point over by 32 bits */
	b = (u_long) t->int_part;
	return (a + b);
}

static void
stamp(t, us)
	struct l_fixedpt *t;
	unsigned long long us;
{
	t->int_part = (u_long)(us / 1000000);
	t->fraction = (u_long)(((us % 1000000) << 32) / 1000000);
}

static double
mag(x)
	double x;
{
	return x < 0 ? -x : x;
}

int
main()
{
	struct l_fixedpt org, rec, xmt, in_timestamp;
	double t1, t2, t3, t4, delay, offset;
	unsigned long long send;
	long net_time;
	int k;

	for (k = 0; k < 64; k++) {
		send = 3970000000000000ULL + 370000ULL
		     + (unsigned long long)k * 4000037ULL;
		stamp(&org, send);
		stamp(&rec, send + 90100500ULL);
		stamp(&xmt, send + 90110500ULL);
		stamp(&in_timestamp, send + 211000ULL);

		t1 = ul_fixed_to_double(&org);
		t2 = ul_fixed_to_double(&rec);
		t3 = ul_fixed_to_double(&xmt);
		t4 = ul_fixed_to_double(&in_timestamp);

		delay = (t4 - t1) - (t3 - t2);
		offset = (t2 - t1) + (t3 - t4);
		offset = offset / 2.0;
		if (mag(delay - 0.201) > 1e-6)
			return 1;
		if (mag(offset - 90.0) > 1e-6)
			return 2;
		net_time = xmt.int_part - JAN_1970 + delay;
		if (net_time != (long)(xmt.int_part - JAN_1970))
			return 3;
	}
	return 42;
}
