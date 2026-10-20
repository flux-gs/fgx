/* ---- getpass(3) -----------------------------------------------------------
 * FGX-Provenance: 2.11BSD usr/lib/libc/gen/getpass.c 5.2.
 *
 * Upstream's body: the password is read from the controlling terminal,
 * /dev/tty, so a redirected stdin cannot capture it, and from stdin only when
 * there is no controlling terminal.  SIGINT is ignored while ECHO is off, so a
 * ^C cannot leave the terminal silent.
 *
 * One divergence: the buffer holds _PASSWORD_LEN (32) characters where
 * upstream's pbuf holds 8.  Documented in getpass(3).
 */
static char _getpass_buf[_PASSWORD_LEN + 1];

char *getpass(prompt)
	char *prompt;
{
	struct sgttyb ttyb;
	int flags;
	register char *p;
	register int c;
	FILE *fi;
	int (*sig)();

	if ((fi = fdopen(open("/dev/tty", 2), "r")) == NULL)
		fi = stdin;
	else
		setbuf(fi, (char *)NULL);
	sig = signal(SIGINT, SIG_IGN);
	ioctl(fileno(fi), TIOCGETP, &ttyb);
	flags = ttyb.sg_flags;
	ttyb.sg_flags &= ~ECHO;
	ioctl(fileno(fi), TIOCSETP, &ttyb);
	fprintf(stderr, "%s", prompt); fflush(stderr);
	for (p = _getpass_buf; (c = getc(fi)) != '\n' && c != EOF;) {
		if (p < &_getpass_buf[_PASSWORD_LEN])
			*p++ = c;
	}
	*p = '\0';
	fprintf(stderr, "\n"); fflush(stderr);
	ttyb.sg_flags = flags;
	ioctl(fileno(fi), TIOCSETP, &ttyb);
	signal(SIGINT, sig);
	if (fi != stdin)
		fclose(fi);
	return (_getpass_buf);
}
