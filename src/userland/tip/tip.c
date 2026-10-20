/* tip(1) — serial terminal for /dev/tty00 (printer port) and /dev/tty01
 * (modem port).  C rewrite retiring the hand-asm tip.s ("tip-lite") and
 * cu.s; cu(1) is this same binary staged under a second name (the classic
 * BSD arrangement — argv[0] picks the name in messages, behavior is
 * identical).
 *
 * Usage:  tip [tty00|tty01|/dev/ttyNN]        default /dev/tty01
 *
 * Architecture is FGX-native: one non-blocking poll loop bridges the
 * console and the line — pollkey() feeds typed keys out (7-bit masked,
 * no local echo), read()/EAGAIN drains arriving bytes to the console.
 * It is one process, not the historical two-process (fork) design, and
 * has no remote(5)/ACU/uucp-lock machinery: there are no modems to dial,
 * and two fixed lines whose speed/framing come from the IIgs Control Panel.
 *
 * CONSOLE ONLY AS OF apple/fgx#151, AND A RE-PORT IS OWED.  pollkey() takes no
 * fd: it dequeues the kernel keyboard ring, so run over a pty this fed the
 * PHYSICAL CONSOLE's keystrokes down the serial line while the remote user
 * typed into nothing.  The kernel now answers "no key" to a caller whose
 * controlling terminal is a pty, so tip is correct on the console and INERT
 * over telnet -- which is the safe half of wrong, not a fix.  Every other
 * caller in that class moved to reading its own terminal; tip did not, because
 * it multiplexes two sources and wants select() on {terminal, line} rather
 * than a poll loop.  Tracked in docs/ROADMAP.md under Userland / polish.
 *
 * Escapes, '~' at beginning of line:
 *   ~.  ~^D   exit                    ~~   send a literal '~'
 *   ~>        send a local file raw out the line
 *   ~<        toggle capture of incoming bytes to a local file
 *   ~?        this summary
 * Anything else after '~' sends the '~' plus that key.
 *
 * Incoming CR/LF is collapsed to one LF per line (the console is a true
 * VT and the kernel tty path does ONLCR, so a raw CRLF would double-space).
 * Capture files record the line raw, before that normalization.
 */
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>

/* THE 16-BIT KERNEL FORM, not BSD's encoded _IOR/_IOW -- include/loader.s:685.
   The encoded values assemble fine and simply never match. */
#define TIOCGETP 0x7408
#define TIOCSETP 0x7409
#define RAW      0x0020
#define ECHO     0x0008

#define CR      '\r'
#define LF      '\n'
#define CTRL_D  004
#define BS      010
#define DEL     0177

static char *myname = "tip";
static int ttyfd = -1;
static int capfd = -1;          /* ~< capture file, -1 = off */
static int at_bol = 1;          /* '~' is special only here */
static int rx_sawcr = 0;        /* incoming CR/LF collapse state */
static char iobuf[256];

static int usage()
{
	fprintf(stderr, "usage: %s [tty00|tty01|/dev/ttyNN]\n", myname);
	return 1;
}

static int con_emit(c)
	int	c;
{
	char b;

	b = c;
	write(1, &b, 1);
	return 0;
}

static int send_line(c)
	int	c;
{
	char b;

	b = c;
	write(ttyfd, &b, 1);
	at_bol = (c == CR);
	return 0;
}

/* Read one line from the console keyboard (for escape prompts), with
 * local echo and BS/DEL erase.  Blocks in a pollkey loop; incoming
 * serial bytes are NOT drained meanwhile (prompts are brief). */
static int con_gets(buf, max)
	char	*buf;
	int	max;
{
	int k, n;

	n = 0;
	for (;;) {
		k = pollkey();
		if (k < 0)
			continue;
		k &= 0x7F;
		if (k == CR || k == LF)
			break;
		if (k == BS || k == DEL) {
			if (n > 0) {
				n--;
				con_emit(BS); con_emit(' '); con_emit(BS);
			}
			continue;
		}
		if (k < ' ' || n >= max - 1)
			continue;
		buf[n++] = k;
		con_emit(k);
	}
	buf[n] = 0;
	con_emit(LF);
	return n;
}

/* ~> — send a local file raw out the line. */
static int sendfile()
{
	char path[64];
	int fd, n;
	long total;

	printf("\nlocal file to send: ");
	if (con_gets(path, sizeof(path)) == 0)
		return 0;
	fd = open(path, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "%s: %s: open failed (errno %d)\n",
			myname, path, errno);
		return 0;
	}
	total = 0;
	while ((n = read(fd, iobuf, sizeof(iobuf))) > 0) {
		write(ttyfd, iobuf, n);
		total += n;
	}
	close(fd);
	printf("%s: sent %ld bytes\n", myname, total);
	at_bol = 1;
	return 0;
}

/* ~< — toggle capture of incoming bytes to a local file. */
static int capture()
{
	char path[64];

	if (capfd >= 0) {
		close(capfd);
		capfd = -1;
		printf("\n%s: capture off\n", myname);
		return 0;
	}
	printf("\ncapture to local file: ");
	if (con_gets(path, sizeof(path)) == 0)
		return 0;
	capfd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
	if (capfd < 0) {
		capfd = -1;
		fprintf(stderr, "%s: %s: create failed (errno %d)\n",
			myname, path, errno);
		return 0;
	}
	printf("%s: capturing (~< to stop)\n", myname);
	return 0;
}

static int help()
{
	printf("\n~.  ~^D  exit          ~~  send literal ~\n");
	printf("~>  send local file    ~<  toggle capture to file\n");
	printf("~?  this summary\n");
	return 0;
}

/* One masked key from the keyboard.  Returns 1 to quit. */
static int handle_key(k)
	int	k;
{
	static int esc = 0;

	if (esc) {
		esc = 0;
		switch (k) {
		case '.':
		case CTRL_D:
			return 1;
		case '~':
			send_line('~');
			return 0;
		case '>':
			sendfile();
			return 0;
		case '<':
			capture();
			return 0;
		case '?':
			help();
			return 0;
		default:
			send_line('~');
			send_line(k);
			return 0;
		}
	}
	if (k == '~' && at_bol) {
		esc = 1;
		return 0;
	}
	send_line(k);
	return 0;
}

/* One byte from the line: capture raw, then CR/LF-collapse to console. */
static int rx_byte(c)
	int	c;
{
	char b;

	if (capfd >= 0) {
		b = c;
		write(capfd, &b, 1);
	}
	if (c == CR) {
		rx_sawcr = 1;
		con_emit(LF);
	} else if (c == LF) {
		if (!rx_sawcr)
			con_emit(LF);
		rx_sawcr = 0;
	} else {
		rx_sawcr = 0;
		con_emit(c);
	}
	return 0;
}

int main(argc, argv)
	int	argc;
	char	**argv;
{
	char path[32];
	char *arg, *p;
	int k, n;
	char b;
	char sg[6];                     /* struct sgttyb, as ptyhog(8) reads it:
	                                 * flags is the short at byte 4, and RAW
	                                 * and ECHO both live in its low byte. */

	/* cu is this binary under its other name. */
	if (argc > 0 && argv[0] != NULL) {
		for (p = argv[0]; *p; p++)
			if (*p == '/' && p[1])
				argv[0] = p + 1;
		if (strcmp(argv[0], "cu") == 0)
			myname = "cu";
	}

	arg = "/dev/tty01";
	if (argc > 1) {
		if (argv[1][0] == '-')
			return usage();
		if (argv[1][0] == '/')
			arg = argv[1];
		else {
			strcpy(path, "/dev/");
			strncat(path, argv[1], 20);
			arg = path;
		}
	}

	ttyfd = open(arg, O_RDONLY);
	if (ttyfd < 0) {
		fprintf(stderr, "%s: %s: open failed (errno %d)\n",
			myname, arg, errno);
		return 1;
	}
	/* THE LINE IS A COOKED TERMINAL NOW, so put it in RAW -- which is what
	 * upstream tip does and what this one never could.  Before apple/fgx#108
	 * T7 the serial line was a raw byte pipe: serial_isr filled a ring and
	 * serial_read popped it, the bytes met no discipline, and serial_ioctl
	 * answered ENOTTY to everything so there was nothing to set.  The line
	 * has a real `struct tty' now, and in cooked mode `ttread' hands nothing
	 * back until a line DELIMITER arrives -- so a peer that sends a prompt
	 * with no newline would sit in `t_rawq' unseen, which is exactly what a
	 * terminal program must not do.
	 *
	 * RAW **AND ECHO OFF**: RAW does not disable echo -- `ttyecho's own RAW
	 * arm still calls `ttyoutput' -- and echo here would send every arriving
	 * character straight back down the line at the far end. */
	if (ioctl(ttyfd, TIOCGETP, sg) < 0 || (sg[4] = (sg[4] | RAW) & ~ECHO, 0)
	    || ioctl(ttyfd, TIOCSETP, sg) < 0)
		fprintf(stderr, "%s: warning: cannot set raw mode (errno %d)\n",
			myname, errno);

	printf("%s: connected to %s (~. to exit, ~? for help)\n", myname, arg);

	for (;;) {
		k = pollkey();
		if (k >= 0 && handle_key(k & 0x7F))
			break;
		errno = 0;
		n = read(ttyfd, &b, 1);
		if (n == 1)
			rx_byte(b & 0xFF);
		else if (errno != EAGAIN && errno != 0) {
			fprintf(stderr, "\n%s: read error (errno %d)\n",
				myname, errno);
			break;
		}
	}

	if (capfd >= 0)
		close(capfd);
	close(ttyfd);
	printf("\n%s: disconnected\n", myname);
	return 0;
}
