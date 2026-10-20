/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/gen/syslog.c
 *   Ported from syslog(3), 2.11BSD (8.4.3 (2.11BSD) 1995/07/15).  Original work:
 *   Copyright (c) 1983, 1988, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* syslog.c -- openlog(3), syslog(3), vsyslog(3), closelog(3), setlogmask(3).
 *
 * THE LINE GOES TO _PATH_LOG as one AF_UNIX SOCK_DGRAM datagram, formed as
 * "<pri>Mon dd hh:mm:ss tag[pid]: message" -- the shape syslogd parses.
 *
 * THE FILE ARM IS UPSTREAM'S OWN, not an FGX invention.  2.11BSD guards it with
 * `#ifdef pdp11' and it is compiled unconditionally here because its condition
 * is live on this machine: when socket(AF_UNIX, SOCK_DGRAM, 0) fails there is no
 * unp transport, which is a boot with no net module, and openlog() appends to
 * /usr/adm/messages instead.  With the transport present and nothing bound to
 * _PATH_LOG the datagram is dropped, exactly as it is on 2.11BSD with no
 * syslogd running.
 *
 * EVERY WRITE INTO `tbuf' IS BOUNDED, where upstream's are not.  2.11BSD, and
 * 4.4BSD-Lite2's syslog.c 8.5 after it, sprintf the tag and vsprintf the
 * message into tbuf with no limit, trusting the buffer to be big enough.  Here
 * it is 2.11BSD's 640 bytes and one argument can be 1,023 (the loader's
 * LSARG_STRMAX), so logger(1) handed a long word or tag wrote past it -- into
 * fmt_cpy, the format vsprintf was still reading, which then read the message
 * back as more format and ran away through the bank.  The tag, the pid, the
 * ": " and the message go through snprintf/vsnprintf and are cut at the room
 * left, which keeps two bytes back for the "\r\n" the LOG_CONS arm appends.
 * fmt_cpy is not bounded: it is the caller's format, which is program text.
 *
 * `tbuf' AND `fmt_cpy' ARE FILE-SCOPE statics, FOR THE STACK.  Upstream declares
 * both as locals of vsyslog (`char *stdp, tbuf[640], fmt_cpy[512]'), which makes
 * its frame over 1,150 bytes, and a caller's bank-0 stack reservation cannot see
 * it -- stack_measure.py builds its graph from the program's OWN .s and drops
 * every edge whose callee it cannot see, which is the whole of libc
 * (apple/fgx#404, /testbin/slogprobe).  su(1) was killed by the stack guard
 * mid-syslog with fmt_cpy on the stack: `stack overflow: killed pid', so the
 * shell it should have handed to root stayed the caller's.  The recursive call
 * below cannot collide with either: its `bad fac/pri' arm runs before either
 * buffer is written.
 *
 * THE LOG_CONS VFORK IS KEPT, and FGX has the hazard it exists for.  Upstream's
 * comment is that opening the console must not acquire a controlling terminal
 * ("bad news for 'init'!"): src/kernel/ttyv.s binds u.u_ttyp on a tty open when
 * and only when the process's SE_PGroup is 0, which is 2.11BSD tty.c ttyopen's
 * condition, and init has no process group.  A direct open from inside syslog()
 * would therefore hand init a controlling terminal.
 *
 * upstream's `extern char *__progname' HAS NO EQUIVALENT TO DECLARE.  crt0's
 * cell is a 2-byte near offset where an fcc `char *' is four bytes, and a C
 * object of that name collides with the assembler's at link -- err.c's header
 * carries the merlin32 message.  The default tag is derived from args_argv[0],
 * which is a real far pointer, by the same basename walk crt0 does.
 */
#define STDERR_FILENO   2

/* _PATH_CONSOLE, from 2.11BSD usr/include/paths.h:25.  FGX has no <paths.h>;
 * _PATH_LOG is in <syslog.h> because 2.11BSD usr/sys/h/syslog.h:40 puts it
 * there. */
#define _PATH_CONSOLE   "/dev/console"

static  int     LogFile = -1;           /* fd for log */
static  char    connected;              /* have done connect */
static  char    ToFile = 0;             /* set if logfile is used */
static  int     LogStat = 0;            /* status bits, set by openlog() */
static  char    *LogTag = NULL;         /* string to tag the entry with */
static  int     LogFacility = LOG_USER; /* default facility code */
static  int     LogMask = 0xff;         /* mask of priorities to be logged */
static  char    logfile[] = "/usr/adm/messages";
static  char    tbuf[640];              /* the formed line; see the note above */
static  char    fmt_cpy[512];           /* %m-expanded format; see the note above */

/* The room left in tbuf at p, keeping two bytes for LOG_CONS's "\r\n". */
#define TBUF_LEFT(p)    ((int)(sizeof(tbuf) - 2 - ((p) - tbuf)))

/* p moved past what a bounded print at p stored, given the n it answered:
 * snprintf answers the length it would have printed, not what fit. */
static char *
tbuf_past(p, n)
	char *p;
	int n;
{
	int left = TBUF_LEFT(p);

	return (p + (n < left ? n : left - 1));
}

/* THE ADDRESS IS A BYTE ARRAY AND NOT A `struct sockaddr'.  Upstream's is a
 * sockaddr, whose 14-byte sa_data holds "/dev/log" -- but fcc pads struct
 * members and the kernel reads an AF_UNIX address by raw offset, family in the
 * first two bytes and the path from offset 2, so <sys/un.h> states the size and
 * unixprobe.c builds it the same way. */
static  char    SyslogAddr[SUN_LEN];    /* AF_UNIX address of local logger */

/* args_argv is crt0's, and holds four bytes per entry. */
extern  char    *args_argv[];

/* Declared before its first caller: an implicit declaration is assumed
 * int-returning, which would drop the bank off the far pointer it answers. */
static  char    *slprogname();

/*
 * syslog, vsyslog --
 *	print message on log file; output is intended for syslogd(8).
 */
void
syslog(int pri, char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vsyslog(pri, fmt, ap);
	va_end(ap);
}

void
vsyslog(pri, fmt, ap)
	int pri;
	register char *fmt;
	va_list ap;
{
	int cnt;
	char ch;
	register char *p, *t;
	long now;
	int fd, saved_errno;
	char *stdp;
	int pid;

#define	INTERNALLOG	LOG_ERR|LOG_CONS|LOG_PERROR|LOG_PID
	/* Check for invalid bits. */
	if (pri & ~(LOG_PRIMASK|LOG_FACMASK)) {
		syslog(INTERNALLOG,
		    "syslog: bad fac/pri: %x", pri);
		pri &= LOG_PRIMASK|LOG_FACMASK;
	}

	/* Check priority against setlogmask values.
	 *
	 * IT NEVER FILTERS, AND THE EXPRESSION IS UPSTREAM'S VERBATIM.  K&R 2nd
	 * ed A.7.4 Unary Operators: "Expressions with unary operators group
	 * right-to-left" and lists `!' among the unary operators, so
	 * `!LOG_MASK(LOG_PRI(pri))' is the whole left operand of `&'.
	 * LOG_MASK(p) is `1 << p' for p in 0..7 and never zero, so the `!' of it
	 * is 0 and `0 & LogMask' is 0.  netbsd-0-9's copy of this file has the
	 * identical expression and 4.3BSD-Reno's writes a different but equally
	 * non-filtering form, so no upstream here fixes it -- and diverging would
	 * make FGX DROP messages that 2.11BSD delivers. */
	if (!LOG_MASK(LOG_PRI(pri)) & LogMask)
		return;

	saved_errno = errno;

	/* Set default facility if none specified. */
	if ((pri & LOG_FACMASK) == 0)
		pri |= LogFacility;

	/* Build the message.
	 *
	 * THE TIMESTAMP IS 4.3BSD-Reno's ROUTE, NOT 2.11BSD's, and the output is
	 * byte-identical.  2.11BSD 8.4.3 writes
	 * `strftime(p, ..., "%h %e %T ", localtime(&now))'; Reno's syslog.c:93 and
	 * netbsd-0-9's :122 both write the sprintf below.  `ctime' yields
	 * "Thu Nov 24 18:22:48 1986\n", so +4 skips the weekday and "%.15s" takes
	 * "Nov 24 18:22:48"; asctime's own "%2d" space-pads the day exactly as
	 * strftime's "%e" does, so a single-digit day reads "Nov  2" either way.
	 *
	 * Reno's route is taken because strftime's libc member does not fit:
	 * su(1)'s seg2 is one bank holding libc.s, the shims, libc.sel.s and
	 * libfgx.s, which its own header records cannot be split because they are
	 * near-call peers, and the syslog closure put it 5,238 bytes past 64 KB.
	 * ctime is already linked here -- strftime's own call to `localtime' is in
	 * ctime.c -- so this form costs no member at all and drops strftime's
	 * 5,357 bytes. */
	(void)time(&now);
	(void)sprintf(tbuf, "<%d>%.15s ", pri, ctime(&now) + 4);
	for (p = tbuf; *p; ++p)
		;
	if (LogStat & LOG_PERROR)
		stdp = p;
	if (LogTag == NULL)
		LogTag = slprogname();
	if (LogTag != NULL)
		p = tbuf_past(p, snprintf(p, TBUF_LEFT(p), "%s", LogTag));
	if (LogStat & LOG_PID)
		p = tbuf_past(p, snprintf(p, TBUF_LEFT(p), "[%d]", getpid()));
	if (LogTag != NULL)
		p = tbuf_past(p, snprintf(p, TBUF_LEFT(p), ": "));

	/* Substitute error message for %m.
	 *
	 * UPSTREAM'S sprintf("%s", ...) CANNOT REINTERPRET the error text, which
	 * is why nothing is escaped here: a `%' inside a strerror string is
	 * copied rather than read as a conversion.  It reaches vsprintf below as
	 * part of fmt_cpy, where it WOULD be read -- and what makes that safe is
	 * the table rather than this loop: libc_data.s's messages contain no
	 * `%', and the fallback is the literal `Unknown error'.  A message added
	 * with a `%' in it would eat an argument that was never passed. */
	for (t = fmt_cpy; ch = *fmt; ++fmt)
		if (ch == '%' && fmt[1] == 'm') {
			++fmt;
			t += sprintf(t, "%s", strerror(saved_errno));
		} else
			*t++ = ch;
	*t = '\0';

	p = tbuf_past(p, vsnprintf(p, TBUF_LEFT(p), fmt_cpy, ap));
	cnt = p - tbuf;

	/* Output to stderr if requested. */
	if (LogStat & LOG_PERROR) {
		struct iovec iov[2];
		register struct iovec *v = iov;

		v->iov_base = stdp;
		v->iov_len = cnt - (stdp - tbuf);
		++v;
		v->iov_base = "\n";
		v->iov_len = 1;
		(void)writev(STDERR_FILENO, iov, 2);
	}

	/* Get connected, output the message to the local logger. */
	if (!connected)
		openlog(LogTag, LogStat | LOG_NDELAY, 0);
	if (ToFile) {
		if (write(LogFile, tbuf, cnt) == cnt)
			return;
	}
	else
	if (send(LogFile, tbuf, cnt, 0) >= 0)
		return;

	/*
	 * Output the message to the console; don't worry about blocking,
	 * if console blocks everything will.  Make sure the error reported
	 * is the one from the syslogd failure.
	 *
	 * The fork is what keeps the open from acquiring a controlling
	 * terminal, which would be bad news for 'init'.
	 */
	if (LogStat & LOG_CONS) {
		pid = vfork();
		if (pid == -1)
			return;
		if (pid == 0) {
	   		fd = open(_PATH_CONSOLE, O_WRONLY, 0);
			(void)strcat(tbuf, "\r\n");
			cnt += 2;
			p = index(tbuf, '>') + 1;
			(void)write(fd, p, cnt - (p - tbuf));
			(void)close(fd);
			_exit(0);
		}
		while (waitpid(pid, (int *)0, 0) == -1 && (errno == EINTR))
			;
	}
}

void
openlog(ident, logstat, logfac)
	char *ident;
	int logstat;
	register int logfac;
{
	register int i;

	if (ident != NULL)
		LogTag = ident;
	LogStat = logstat;
	if (logfac != 0 && (logfac &~ LOG_FACMASK) == 0)
		LogFacility = logfac;

	if (LogFile == -1) {
		for (i = 0; i < SUN_LEN; i++)
			SyslogAddr[i] = '\0';
		SyslogAddr[0] = AF_UNIX;
		(void)strncpy(&SyslogAddr[2], _PATH_LOG, SUN_PATH_MAX);
		if (LogStat & LOG_NDELAY) {
			LogFile = socket(AF_UNIX, SOCK_DGRAM, 0);
			if (LogFile == -1) {
				LogFile = open(logfile, O_WRONLY|O_APPEND);
				ToFile = 1;
				connected = 1;
			}
			else
				ToFile = 0;
			if (LogFile == -1)
				return;
			(void)fcntl(LogFile, F_SETFD, 1);
		}
	}
	if (LogFile != -1 && !connected)
		if (connect(LogFile, (struct sockaddr *)SyslogAddr,
		    SUN_LEN) == -1) {
			(void)close(LogFile);
			LogFile = -1;
		} else
			connected = 1;
}

void
closelog()
{
	(void)close(LogFile);
	LogFile = -1;
	connected = 0;
}

/* setlogmask -- set the log mask level */
int
setlogmask(pmask)
	register int pmask;
{
	register int omask;

	omask = LogMask;
	if (pmask != 0)
		LogMask = pmask;
	return (omask);
}

/* The default LogTag: basename of args_argv[0], which is where crt0's own walk
 * starts.  Cached, so the walk happens once. */
static char *
slprogname()
{
	register char *p, *b;
	static char *progname;

	if (progname == 0 && args_argv[0] != 0) {
		b = args_argv[0];
		for (p = b; *p; p++)
			if (*p == '/')
				b = p + 1;
		progname = b;
	}
	return (progname);
}
