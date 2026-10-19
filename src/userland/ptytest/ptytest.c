/* ptytest - pty P2 smoke (single-process; the spawn-jsh round trip is the
 * P4 closed loop).  Exercises: pair open (master exclusive, slave needs
 * master), master->slave ring through the COOKED line discipline (gather +
 * ICRNL), discipline echo back to the master, TIOCPKT prefix, sgtty ioctls
 * routed to the shared tty block from a SLAVE chardev fd, slave-close ->
 * master EOF, and pair reset on reopen.
 *
 * Prints PT<n> OK markers; any failure prints PT<n> FAIL rc and exits 1.
 */
#include <stdio.h>
#include <sgtty.h>

int
main()
{
	int m, s, n, i;
	char buf[64];
	struct sgttyb tb;
	int on;

	/* PT1: open master, slave; slave-before-master must fail */
	s = open("/dev/ttyp0", 2);
	if (s >= 0) { printf("PT1 FAIL slave-first %d\n", s); return 1; }
	m = open("/dev/ptyp0", 2);
	if (m < 0) { printf("PT1 FAIL master %d\n", m); return 1; }
	i = open("/dev/ptyp0", 2);
	if (i >= 0) { printf("PT1 FAIL exclusive %d\n", i); return 1; }
	s = open("/dev/ttyp0", 2);
	if (s < 0) { printf("PT1 FAIL slave %d\n", s); return 1; }
	printf("PT1 OK\n");

	/* PT2: master write "hi\r" -> slave cooked read gets "hi\n" (ICRNL) */
	write(m, "hi\r", 3);
	n = read(s, buf, sizeof buf);
	if (n != 3 || buf[0] != 'h' || buf[1] != 'i' || buf[2] != '\n') {
		printf("PT2 FAIL n=%d %02x %02x %02x\n", n,
		    buf[0] & 0xff, buf[1] & 0xff, n > 2 ? (buf[2] & 0xff) : 0);
		return 1;
	}
	printf("PT2 OK\n");

	/* PT3: the gather echoed h,i,CR+LF back to the master */
	n = read(m, buf, sizeof buf);
	if (n < 3 || buf[0] != 'h' || buf[1] != 'i') {
		printf("PT3 FAIL n=%d %02x %02x\n", n, buf[0] & 0xff,
		    n > 1 ? (buf[1] & 0xff) : 0);
		return 1;
	}
	printf("PT3 OK\n");

	/* PT4: slave write -> master read; cooked LF -> CR+LF (ONLCR) */
	write(s, "ok\n", 3);
	n = read(m, buf, sizeof buf);
	if (n != 4 || buf[0] != 'o' || buf[1] != 'k' ||
	    buf[2] != '\r' || buf[3] != '\n') {
		printf("PT4 FAIL n=%d\n", n);
		return 1;
	}
	printf("PT4 OK\n");

	/* PT5: sgtty on the SLAVE fd routes to its tty entry */
	if (gtty(s, &tb) < 0) { printf("PT5 FAIL gtty\n"); return 1; }
	if ((tb.sg_flags & ECHO) == 0) { printf("PT5 FAIL echo bit\n"); return 1; }
	tb.sg_flags |= CBREAK;
	if (stty(s, &tb) < 0) { printf("PT5 FAIL stty\n"); return 1; }
	if (gtty(s, &tb) < 0 || (tb.sg_flags & CBREAK) == 0) {
		printf("PT5 FAIL cbreak\n");
		return 1;
	}
	tb.sg_flags &= ~CBREAK;	/* back to cooked */
	stty(s, &tb);
	printf("PT5 OK\n");

	/* PT6: TIOCPKT — next master read carries the data-prefix byte 0 */
	on = 1;
	if (ioctl(m, TIOCPKT, (char *)&on) < 0) {
		printf("PT6 FAIL ioctl\n");
		return 1;
	}
	write(s, "p\n", 2);
	n = read(m, buf, sizeof buf);
	if (n != 4 || buf[0] != TIOCPKT_DATA || buf[1] != 'p') {
		printf("PT6 FAIL n=%d %02x %02x\n", n, buf[0] & 0xff,
		    n > 1 ? (buf[1] & 0xff) : 0);
		return 1;
	}
	on = 0;
	ioctl(m, TIOCPKT, (char *)&on);
	printf("PT6 OK\n");

	/* PT7: slave close -> master reads EOF (0) once drained */
	close(s);
	n = read(m, buf, sizeof buf);
	if (n != 0) { printf("PT7 FAIL n=%d\n", n); return 1; }
	printf("PT7 OK\n");

	/* PT8: pair resets — full reopen cycle works */
	close(m);
	m = open("/dev/ptyp0", 2);
	if (m < 0) { printf("PT8 FAIL reopen\n"); return 1; }
	s = open("/dev/ttyp0", 2);
	if (s < 0) { printf("PT8 FAIL reslave\n"); return 1; }
	close(s);
	close(m);
	printf("PT8 OK\n");

	/* PT9: byte-at-a-time cooked read (jsh's read_line shape) on BOTH pairs.
	 * Bulk reads were PT2; this is the per-byte path.  Pair 1 also proves the
	 * detour's tty[2] address (the Merlin left-to-right precedence fix). */
	{
		int pr, m2, s2, r2;
		char cb;
		static char *mp[2] = { "/dev/ptyp0", "/dev/ptyp1" };
		static char *tp[2] = { "/dev/ttyp0", "/dev/ttyp1" };
		for (pr = 0; pr < 2; pr++) {
			m2 = open(mp[pr], 2);
			s2 = open(tp[pr], 2);
			if (m2 < 0 || s2 < 0) { printf("PT9 FAIL open p%d %d %d\n", pr, m2, s2); return 1; }
			write(m2, "ab\r", 3);
			r2 = read(s2, &cb, 1); if (r2 != 1 || cb != 'a') { printf("PT9 FAIL p%d b0 r=%d c=%02x\n", pr, r2, cb & 0xff); return 1; }
			r2 = read(s2, &cb, 1); if (r2 != 1 || cb != 'b') { printf("PT9 FAIL p%d b1 r=%d c=%02x\n", pr, r2, cb & 0xff); return 1; }
			r2 = read(s2, &cb, 1); if (r2 != 1 || cb != '\n') { printf("PT9 FAIL p%d b2 r=%d c=%02x\n", pr, r2, cb & 0xff); return 1; }
			close(s2); close(m2);
		}
		printf("PT9 OK\n");
	}

	printf("PTYTEST PASS\n");
	return 0;
}
