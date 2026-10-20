/* logintest - closed-loop check for the getty -> login -> shell chain.
 *
 * FGX-Provenance: none
 *
 * Spawns /bin/getty on the slave side of /dev/ttyp0 and drives the whole login
 * chain from the master, the same shape ptyshell uses for jsh: spawnx
 * file_actions {open slave -> child fd 3; dup2 3 onto 0,1,2; close 3}, a
 * non-blocking polled master, and drain-until-substring synchronization.  The
 * parent never holds the slave open, so the master reads EOF the moment the
 * final shell exits.
 *
 * ptyshell drives a RAW consumer (jsh takes the plain-byte-read path over a
 * pty).  This one drives a COOKED one -- getty clears RAW and CBREAK, so every
 * byte goes through the kernel's canonical line discipline: erase/kill editing,
 * ICRNL, and echo.  That is a different kernel path, and it is the one a real
 * terminal session uses.
 *
 * Seven children, seventeen assertions:
 *
 *   LT1  getty opens the line and greets
 *   LT2  a name reaches login, which asks for a password -- and the NAME is
 *        echoed, because only the password is secret
 *   LT3  WRONG password -> "Login incorrect", no shell        (load-bearing)
 *   LT4  the password itself is NOT echoed on the line        (load-bearing)
 *   LT5  right password -> a root login shell prompt
 *   LT6  ECHO is RESTORED after getpass turned it off
 *   LT7  the shell's environment carries HOME
 *   LT8  ... and TERM, read from /etc/ttys rather than the fallback
 *   LT9  ^D tears the session down -> EOF on the master
 *   LT10 an over-long login name is discarded, and its tail does NOT leak into
 *        the password prompt
 *   LT11 root is REFUSED on an insecure line even with the RIGHT password
 *        (TTY_SECURE)                                         (load-bearing)
 *   LT12 repeated empty lines at login's prompt END the session instead of
 *        re-prompting forever
 *   LT13 passwd(1) changes root's password from a login shell
 *   LT14 ... after which the OLD password is REFUSED         (load-bearing)
 *   LT15 ... and the NEW one reaches a shell
 *   LT16 ... and the REST of /etc/passwd survived the rewrite  (load-bearing)
 *   LT17 passwd puts the original password back, proved by logging in with it
 *
 * LT3 is the discriminating case for authentication.  A login that never checks
 * the password passes every other assertion here with flying colours, so a
 * suite without LT3 would go green against an authentication bypass.
 *
 * LT4 and LT6 are the pair that guards getpass.  getpass() clears ECHO and is
 * responsible for putting it back.  If it never cleared it, the password is on
 * the wire (LT4).  If it never restores it, the user lands at what looks like a
 * dead keyboard (LT6).  "The password was accepted" proves neither.  Over a pty
 * both are directly observable: with ECHO on, what you type comes back TWICE --
 * once echoed by the line discipline, once as the program's own output.
 *
 * LT10 runs on a SECOND child on purpose.  A leaked name tail ends the session,
 * and that must not be able to take the nine assertions above down with it.
 *
 * LT11 needs a DIFFERENT LINE, not just a different child: /etc/ttys marks
 * ttyp0 secure and ttyp1 not, so it runs on the second pty pair.  Without it
 * the TTY_SECURE gate is unreachable -- every other line in the file is secure
 * -- and deleting the gate outright would leave all ten other assertions green.
 * LT8 pairs with it: ty_type for both pty lines is "fgxpty", never "vt100", so
 * LT8 can tell the file's value apart from login's hardcoded fallback.
 *
 * LT14 is the discriminating half of the passwd case, and LT13 is not.  A
 * passwd that prompts, prints nothing, and writes NOTHING leaves the account
 * exactly as it was -- so LT13 (it ran) and LT15 (a password works) would both
 * be green against a program that does not touch /etc/passwd, as long as the
 * password it "set" happened to be the one already there.  Only "the old
 * password STOPPED working" can tell a real rewrite from no rewrite at all.
 *
 * LT16 is the other thing a rewrite can silently get wrong: emit the changed
 * line and drop everything else.  The shipped file is one entry plus a comment,
 * so nothing else in this suite would notice -- until a second account exists.
 *
 * LT17 is not decoration either.  It restores the original password so the
 * suite is re-runnable, and it asserts the restore by LOGGING IN with the
 * original -- not by reading anything back.  A case that changed the root
 * password and left it changed would poison every later run on the same disk,
 * starting with the ones that log in as root.
 *
 * LT12 covers the one thing a login prompt must not do: hold a line open with
 * no way out.  login refunds a malformed line rather than charging it against
 * the three password attempts, and upstream bounds that with an alarm(3) login
 * timeout this port does not have -- so the refund needs its own ceiling, and
 * the ceiling needs a test that goes red when it is removed.
 *
 * Prints LT<n> OK / LT<n> FAIL and a verdict line.
 */
#include <stdio.h>

int open(char *path, int flags);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);
int spawnx(char *path, char **argv, unsigned char *acts);
int nanosleep(int ticks);
int ioctl(int fd, int cmd, char *arg);
int strlen(char *s);
extern int errno;
#define FIONBIO 0x667E

#define TRIES 600               /* poll rounds per drain (~1/30 s each) */

#define OLDPW "fgx"             /* what disk_src/etc/passwd ships with */
#define NEWPW "Hunter7"         /* what LT13 sets it to.  Distinct from OLDPW,
                                 * and deliberately long enough and mixed-case
                                 * enough to satisfy the rules passwd applies
                                 * to NON-root users, so this case keeps
                                 * driving passwd the same way on the day FGX
                                 * grows per-process uids and root stops being
                                 * the only account anyone runs as. */

unsigned char fa[48];   /* 6 records + terminator: DETACH, open, 3x dup2, close */
char mbuf[512];
char acc[4096];
int  acclen;
int  lastdr;                    /* last drain_until result, for dumpacc */
int  lastm = -1;                /* the master `drain_until' last read, so the
                                 * EOF probe below can ask it again */
char longname[81];              /* 80 chars: longer than getty's and login's
                                 * 64-byte name buffers, well inside the tty's
                                 * 256-byte canonical line */

/* getty's argv for spawnx: a NULL-terminated char *[] of far pointers, which
 * the kernel walks in place. */
static char gettypath[] = "/bin/getty";
static char slave0[] = "/dev/ttyp0";    /* /etc/ttys: fgxpty, SECURE   */
static char slave1[] = "/dev/ttyp1";    /* /etc/ttys: fgxpty, INSECURE */
static char  *gav[2];

static int
count_in_acc(needle)
	char *needle;
{
	int a, b, c;

	c = 0;
	for (a = 0; a <= acclen; a++) {
		for (b = 0; needle[b]; b++)
			if (acc[a + b] != needle[b])
				break;
		if (needle[b] == 0) { c++; a += b - 1; }
	}
	return c;
}

/* Poll-read the non-blocking master into acc until count(needle) >= want (1),
 * EOF (2), or tries exhausted (0). */
static int
drain_until(m, needle, want, tries)
	int m;
	char *needle;
	int want, tries;
{
	int n, i, t;

	lastdr = 1;
	lastm = m;
	if (count_in_acc(needle) >= want)
		return 1;
	for (t = 0; t < tries; t++) {
		n = read(m, mbuf, sizeof mbuf);
		if (n == 0) { lastdr = 2; return 2; }
		if (n < 0) { nanosleep(2); continue; }
		for (i = 0; i < n; i++)
			if (acclen < (int)sizeof acc - 1)
				acc[acclen++] = mbuf[i];
		acc[acclen] = 0;
		if (count_in_acc(needle) >= want)
			return 1;
	}
	lastdr = 0;
	return 0;
}

/* Wait for the NEXT shell prompt, whatever the count is now.
 *
 * THE FIXTURE HAS TO STOP TYPING AHEAD OF THE SHELL, and LT9 is where that
 * stopped being free.  `drain_until' returns the moment its needle appears in
 * the OUTPUT of a command, which is one or more reads before the shell has
 * finished, redrawn its prompt and put the line back into the mode it reads
 * in -- tcsh runs the line COOKED while a command runs and CBREAK while it
 * edits (measured: t_flags $040504D2 with the session up).  A `^D' written
 * into that window is not "a ^D at a fresh prompt", which is what LT9 says it
 * is testing.
 *
 * "# " IS THE PROMPT AND NOTHING ELSE ON THIS LINE: root's prompt ends with it
 * and no command run here emits one.  The count is read at CALL time rather
 * than passed in, so inserting a case above does not silently shift it.
 */
static int
next_prompt(m)
	int m;
{
	return (drain_until(m, "# ", count_in_acc("# ") + 1, TRIES));
}

static int
drain_to_eof(m, tries)
	int m, tries;
{
	int n, i, t;

	lastdr = 0;
	for (t = 0; t < tries; t++) {
		n = read(m, mbuf, sizeof mbuf);
		if (n == 0) { lastdr = 2; return 1; }
		if (n < 0) { nanosleep(2); continue; }
		for (i = 0; i < n; i++)         /* keep it: dumpacc needs the
						 * shell's parting words when
						 * the teardown does not land */
			if (acclen < (int)sizeof acc - 1)
				acc[acclen++] = mbuf[i];
		acc[acclen] = 0;
	}
	return 0;
}

/* On a failure, show what the master actually saw.  A pty test that says only
 * "no reprompt" costs a rebuild-and-boot cycle to learn anything; the drain
 * result (1 matched / 2 EOF, i.e. the child exited / 0 timed out) plus the tail
 * of the accumulator says immediately which it was.  Runs of one character
 * collapse so an 80-character name does not bury the rest. */
static void
dumpacc()
{
	int i, from, run;

	/* WAS THE EOF PERMANENT?  `dr=2' says a master read answered 0, and on
	 * its own that is two different findings: the session really ended, or
	 * the line reported EOF while still very much alive.  apple/fgx#266
	 * could not tell them apart, and every occurrence so far was re-run to
	 * green instead of asked.  So ask: read the master again, and count what
	 * comes back.  The master is non-blocking here -- the drain loop's own
	 * `if (n < 0) continue' proves it -- so 0 and -1 are distinguishable,
	 * and that is the whole distinction.  All zeroes means gone.  A single
	 * -1 or a byte means the EOF was TRANSIENT, which no consumer of a pty
	 * master is entitled to see. */
	if (lastdr == 2 && lastm >= 0) {
		int t, z, e, d, r;
		char b[8];

		z = e = d = 0;
		for (t = 0; t < 40; t++) {
			r = read(lastm, b, sizeof b);
			if (r == 0)      z++;
			else if (r < 0)  e++;
			else             d++;
			nanosleep(2);
		}
		printf("  eof-probe: %d eof, %d empty, %d data -> %s\n",
		       z, e, d, (e || d) ? "TRANSIENT" : "permanent");
	}
	from = acclen > 260 ? acclen - 260 : 0;
	printf("  dr=%d acc[%d]: ", lastdr, acclen);
	for (i = from; i < acclen; i++) {
		run = 1;
		while (i + run < acclen && acc[i + run] == acc[i])
			run++;
		if (run > 3) {
			printf("<%c x%d>", acc[i] >= 32 && acc[i] < 127
			       ? acc[i] : '?', run);
			i += run - 1;
		} else if (acc[i] == '\n')
			printf("<nl>");
		else if (acc[i] >= 32 && acc[i] < 127)
			printf("%c", acc[i]);
		else
			printf("<%d>", acc[i] & 0xff);
	}
	printf("\n");
}

/* Write a line to the master.  CR, not LF: the cooked line discipline maps it
 * (ICRNL), which is what a real terminal sends. */
static void
wr(m, s)
	int m;
	char *s;
{
	write(m, s, strlen(s));
	write(m, "\r", 1);
}

static int
openmaster(path)
	char *path;
{
	int m, on;

	m = open(path, 2);
	if (m < 0)
		return m;
	on = 1;
	ioctl(m, FIONBIO, (char *)&on);
	return m;
}

/* spawnx file_actions: DETACH; open the slave -> child fd 3; dup2 3 onto
 * 0, 1, 2; close 3.  Six-byte records {op, a, b, c, d, e} with a 0 terminator:
 * 1 = open(fd, path offset, flags), 3 = dup2(dst, src), 2 = close(fd),
 * 4 = detach.  ptyshell's verified recipe, plus the detach.
 *
 * DETACH COMES FIRST, AND THE ORDER IS THE WHOLE POINT (apple/fgx#60).  This
 * is telnetd's sequence -- open /dev/tty, TIOCNOTTY, close, THEN open the line
 * (telnetd.c:266-271) -- expressed in spawn's vocabulary.  Now that spawn
 * inherits the process group like fork does, a getty spawned from here would
 * otherwise arrive already in THIS driver's group, and ttyopen's
 * `if (pp->p_pgrp == 0)` claim would never fire: the pty line would get no
 * foreground group and ^C on it would reach nobody.  Detaching first puts the
 * child in pgrp 0, which is the state BSD's init hands its gettys for free. */
static int
spawngetty(slavepath)
	char *slavepath;
{
	int i, r;

	i = 0;
	fa[i++] = 4; fa[i++] = 0;
	fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 1; fa[i++] = 3;
	fa[i++] = ((int)slavepath) & 0xff;
	fa[i++] = (((int)slavepath) >> 8) & 0xff;
	fa[i++] = 2; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 0; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 1; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 2; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 2; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 0;

	gav[0] = gettypath;
	gav[1] = (char *)0;
	r = spawnx(gettypath, gav, fa);
	if (r < 0)
		printf("LT1 FAIL spawn %s e=%d\n", slavepath, errno);
	return r;
}

/* Log root in on a FRESH child (empty accumulator) and land at a shell prompt.
 * `lt` names the assertion the caller is inside and `tag` disambiguates the
 * failure token between children, so a red run still says which one broke. */
static int
login_as(m, pw, lt, tag)
	int m;
	char *pw;
	int lt;
	char *tag;
{
	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT%d FAIL no-greeting%s\n", lt, tag);
		dumpacc(); return 0;
	}
	wr(m, "root");
	if (drain_until(m, "Password:", 1, TRIES) != 1) {
		printf("LT%d FAIL no-password-prompt%s\n", lt, tag);
		dumpacc(); return 0;
	}
	wr(m, pw);
	if (drain_until(m, "# ", 1, TRIES) != 1) {
		printf("LT%d FAIL no-shell-prompt%s\n", lt, tag);
		dumpacc(); return 0;
	}
	return 1;
}

/* Drive /bin/passwd from a shell prompt already on the line: run it, answer
 * both prompts with `np`, and require that it EXITED ZERO.
 *
 * Two pieces of discipline here, both of them lessons paid for:
 *
 *   `&&`, not `;`.  A marker after a semicolon runs whatever happened to the
 *   command before it.  When rename(2) was executing $00 bytes (apple/fgx#30) it
 *   killed its caller SILENTLY -- no diagnostic, straight back to the prompt --
 *   and any wait keyed on "the shell prompt came back" would have called that
 *   a pass.  `&& echo` reports the exit status instead of the fact that
 *   something, anything, finished.
 *
 *   The marker is SPLICED, so the echoed command line cannot match it.  The
 *   line discipline echoes `/bin/passwd && echo PW"OK"` back at us verbatim,
 *   quote included, which does not contain the byte sequence PWOK; only the
 *   shell's own output does.  Asserting a marker the command line itself
 *   carries is how wide60 once passed on a run that produced no output at all.
 *
 * One occurrence is proof: every caller resets the accumulator at the start of
 * its child and calls this at most once. */
static int
setpw(m, np, lt)
	int m;
	char *np;
	int lt;
{
	wr(m, "/bin/passwd && echo PW\"OK\"");
	if (drain_until(m, "Changing password for root.", 1, TRIES) != 1) {
		printf("LT%d FAIL passwd-did-not-start\n", lt);
		dumpacc(); return 0;
	}
	if (drain_until(m, "New password:", 1, TRIES) != 1) {
		printf("LT%d FAIL no-new-password-prompt\n", lt);
		dumpacc(); return 0;
	}
	wr(m, np);
	if (drain_until(m, "Retype new password:", 1, TRIES) != 1) {
		printf("LT%d FAIL no-retype-prompt\n", lt);
		dumpacc(); return 0;
	}
	wr(m, np);
	if (drain_until(m, "PWOK", 1, TRIES) != 1) {
		printf("LT%d FAIL passwd-did-not-exit-zero\n", lt);
		dumpacc(); return 0;
	}
	/* passwd is silent on success.  Every diagnostic it can print begins
	 * "passwd: ", and neither the echoed command line nor the marker can
	 * produce that sequence, so one occurrence is a real failure. */
	if (count_in_acc("passwd: ") != 0) {
		printf("LT%d FAIL passwd-error\n", lt);
		dumpacc(); return 0;
	}
	return 1;
}

int
main()
{
	int m, i;

	for (i = 0; i < 80; i++)
		longname[i] = 'x';
	longname[80] = '\0';

	m = openmaster("/dev/ptyp0");
	if (m < 0) { printf("LT1 FAIL master %d\n", m); return 1; }

	/* ---- child 1: the whole chain, happy and unhappy paths ---------- */
	if (spawngetty(slave0) < 0) return 1;

	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT1 FAIL no-greeting\n");
		dumpacc(); return 1;
	}
	printf("LT1 OK\n");

	/* LT2: the name reaches login through execve, which asks for a
	 * password.  The name comes back echoed -- getty leaves ECHO on, and
	 * a user who cannot see what they typed cannot correct it. */
	wr(m, "root");
	if (drain_until(m, "Password:", 1, TRIES) != 1) {
		printf("LT2 FAIL no-password-prompt\n");
		dumpacc(); return 1;
	}
	if (count_in_acc("root") < 1) {
		printf("LT2 FAIL name-not-echoed\n");
		dumpacc(); return 1;
	}
	printf("LT2 OK\n");

	/* LT3: THE load-bearing case.  A wrong password must be refused. */
	wr(m, "wrongpw");
	if (drain_until(m, "Login incorrect", 1, TRIES) != 1) {
		printf("LT3 FAIL wrong-password-accepted\n");
		dumpacc(); return 1;
	}
	printf("LT3 OK\n");

	/* LT4: and it must not have been echoed on the way in.  The token is
	 * unique to the password, so a single occurrence is a leak. */
	if (count_in_acc("wrongpw") != 0) {
		printf("LT4 FAIL password-echoed\n");
		dumpacc(); return 1;
	}
	printf("LT4 OK\n");

	/* LT5: the right password, at login's own retry prompt, reaches a
	 * shell.  The prompt is "# ", not "$ ": root's uid is 0 and bsh picks
	 * supprompt over stdprompt (sh/main.c dfault(&ps1nod, userid ?
	 * stdprompt : supprompt)). */
	if (drain_until(m, "login:", 2, TRIES) != 1) {
		printf("LT5 FAIL no-retry-prompt\n");
		dumpacc(); return 1;
	}
	wr(m, "root");
	if (drain_until(m, "Password:", 2, TRIES) != 1) {
		printf("LT5 FAIL no-password-prompt2\n");
		dumpacc(); return 1;
	}
	wr(m, "fgx");
	if (drain_until(m, "# ", 1, TRIES) != 1) {
		printf("LT5 FAIL no-shell-prompt\n");
		dumpacc(); return 1;
	}
	printf("LT5 OK\n");

	/* LT6: ECHO restored.  Two copies of the token = the line discipline
	 * echoed the command AND the shell ran it; one copy = the shell ran it
	 * on a line getpass() left with ECHO off. */
	wr(m, "echo ECHOCHK");
	if (drain_until(m, "ECHOCHK", 2, TRIES) != 1) {
		printf("LT6 FAIL echo-not-restored\n");
		dumpacc(); return 1;
	}
	printf("LT6 OK\n");

	/* LT7/LT8: login built the environment.  Neither value appears in the
	 * echo of the command that asks for it, so one occurrence is proof --
	 * but for HOME the PROMPT carries it, and that is not a detail.
	 *
	 * THE NEEDLE HAS TO CARRY THE LINE TERMINATOR.  The prompt is
	 * `[n] root@fgx:/root# ', so a bare "/root" is already in the
	 * accumulator before the command is even typed: the check passed on a
	 * shell that printed nothing, and MEASURED, it is what let LT8's
	 * command be typed ahead of LT7's output and LT9's ^D land in the
	 * window where the shell was not reading.  printenv's line ends CR LF
	 * (ONLCR) and the prompt's does not, so "/root\r" separates them. */
	wr(m, "printenv HOME");
	if (drain_until(m, "/root\r", 1, TRIES) != 1) {
		printf("LT7 FAIL no-home\n");
		dumpacc(); return 1;
	}
	printf("LT7 OK\n");

	/* "fgxpty", not "vt100": login must read ty_type out of /etc/ttys.
	 * Asserting the fallback value instead would pass whether or not the
	 * file was ever consulted. */
	wr(m, "printenv TERM");
	if (drain_until(m, "fgxpty", 1, TRIES) != 1) {
		printf("LT8 FAIL no-term\n");
		dumpacc(); return 1;
	}
	printf("LT8 OK\n");

	/* LT9: ^D at a fresh prompt -> the cooked discipline returns a 0-byte
	 * read -> the shell sees EOF and exits -> its slave fds close -> the
	 * master reads EOF.  ptyshell's teardown, and the one that matters:
	 * it is what a dropped connection looks like.  No CR after it -- ^D is
	 * a line terminator in its own right. */
	if (next_prompt(m) != 1) {
		printf("LT9 FAIL no-prompt-before-eof\n");
		dumpacc(); return 1;
	}
	write(m, "\004", 1);
	if (drain_to_eof(m, TRIES) != 1) {
		printf("LT9 FAIL no-eof\n");
		dumpacc(); return 1;
	}
	printf("LT9 OK\n");

	/* ---- child 2: the over-long name, on a fresh session ------------ */
	/* The master stays open, so the pair survives the first slave's close
	 * and a second getty can open it. */
	acclen = 0; acc[0] = 0;
	if (spawngetty(slave0) < 0) return 1;
	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT10 FAIL no-greeting2\n");
		dumpacc(); return 1;
	}
	wr(m, longname);
	if (drain_until(m, "login:", 2, TRIES) != 1) {
		printf("LT10 FAIL no-reprompt\n");
		dumpacc(); return 1;
	}
	if (count_in_acc("Password:") != 0) {
		printf("LT10 FAIL name-leaked\n");
		dumpacc(); return 1;
	}
	printf("LT10 OK\n");
	close(m);

	/* ---- child 3: root on an INSECURE line -------------------------- */
	/* Same account, different line: /etc/ttys does not mark ttyp1 secure,
	 * so login refuses root there.
	 *
	 * THE REFUSAL COMES BEFORE THE PASSWORD PROMPT AND NAMES ITSELF, which
	 * is upstream's shape (vendor/2.11BSD/usr/bin/login/login.c:226-238)
	 * and was not this port's until 2026-08-29.  It used to authenticate
	 * first and then print "Login incorrect", so this case needed the
	 * RIGHT password to avoid printing the same words for the wrong
	 * reason -- and a real user on ttyp1 was told their correct password
	 * was wrong.  Now there is nothing to get wrong: no password is asked
	 * for at all, which is itself the assertion below.
	 *
	 * AND THE SESSION SURVIVES IT.  Upstream `continue's to the login
	 * prompt rather than returning, so the line stays usable by another
	 * account; LT11 checks the re-prompt for that reason. */
	acclen = 0; acc[0] = 0;
	m = openmaster("/dev/ptyp1");
	if (m < 0) { printf("LT11 FAIL master1 %d\n", m); return 1; }
	if (spawngetty(slave1) < 0) return 1;
	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT11 FAIL no-greeting3\n");
		dumpacc(); return 1;
	}
	wr(m, "root");
	if (drain_until(m, "login refused on this terminal", 1, TRIES) != 1) {
		printf("LT11 FAIL root-not-refused\n");
		dumpacc(); return 1;
	}
	/* NO PASSWORD WAS ASKED FOR, and that is half the case: a gate that
	 * runs after the compare would have printed "Password:" first, and
	 * would tell a user with the right password that it was wrong. */
	if (count_in_acc("Password:") != 0) {
		printf("LT11 FAIL password-asked\n");
		dumpacc(); return 1;
	}
	if (count_in_acc("# ") != 0) {
		printf("LT11 FAIL shell-started\n");
		dumpacc(); return 1;
	}
	/* ...and the line is still usable: login re-prompts rather than
	 * handing the line back to init. */
	if (drain_until(m, "login:", 2, TRIES) != 1) {
		printf("LT11 FAIL no-reprompt-after-refusal\n");
		dumpacc(); return 1;
	}
	printf("LT11 OK\n");
	/* TEAR THE SESSION DOWN ON PURPOSE.  The refusal no longer ends the
	 * session -- that is the point of it -- so login is still sitting at
	 * its prompt here, and leaving it for `close(m)' to hang up left a
	 * process alive into the next child and cost LT17 its greeting.  A
	 * `^D' is what a user would do, and drain_to_eof is what proves it
	 * landed. */
	write(m, "\004", 1);
	drain_to_eof(m, TRIES);
	close(m);

	/* ---- child 4: empty lines must not hold the line open ----------- */
	/* Reach LOGIN's own prompt first (getty's prompt has its own,
	 * separate loop), then hold Return down.  Each empty line is refunded
	 * against the three password attempts, so only the discard ceiling can
	 * end this; without it, login re-prompts until the machine is power
	 * cycled and init can never respawn a getty on the line. */
	acclen = 0; acc[0] = 0;
	m = openmaster("/dev/ptyp0");
	if (m < 0) { printf("LT12 FAIL master %d\n", m); return 1; }
	if (spawngetty(slave0) < 0) return 1;
	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT12 FAIL no-greeting4\n");
		dumpacc(); return 1;
	}
	wr(m, "root");
	if (drain_until(m, "Password:", 1, TRIES) != 1) {
		printf("LT12 FAIL no-password-prompt4\n");
		dumpacc(); return 1;
	}
	wr(m, "wrongpw");
	if (drain_until(m, "login:", 2, TRIES) != 1) {
		printf("LT12 FAIL no-login-prompt4\n");
		dumpacc(); return 1;
	}
	for (i = 0; i <= 10; i++)       /* MAXDISCARD + 1 bare Returns */
		write(m, "\r", 1);
	if (drain_to_eof(m, TRIES) != 1) {
		printf("LT12 FAIL still-prompting\n");
		dumpacc(); return 1;
	}
	printf("LT12 OK\n");
	close(m);

	/* ---- child 5: passwd(1) changes the password ------------------- */
	/* Root, so passwd does not ask for the old one (BSD's rule: root sets
	 * anyone's password without proving knowledge of it).  Neither new
	 * password prompt echoes -- passwd reads them through getpass -- so the
	 * only thing to synchronize on is the prompts themselves and the
	 * shell prompt coming back afterwards. */
	acclen = 0; acc[0] = 0;
	m = openmaster("/dev/ptyp0");
	if (m < 0) { printf("LT13 FAIL master %d\n", m); return 1; }
	if (spawngetty(slave0) < 0) return 1;
	if (login_as(m, OLDPW, 13, "5") != 1) return 1;
	if (setpw(m, NEWPW, 13) != 1) return 1;
	printf("LT13 OK\n");
	/* setpw stops on passwd's marker, which is OUTPUT: the shell has not
	 * redrawn its prompt yet, and a ^D written into that window is not the
	 * ^D at a fresh prompt this teardown wants -- see next_prompt. */
	(void) next_prompt(m);
	write(m, "\004", 1);
	drain_to_eof(m, TRIES);
	close(m);

	/* ---- child 6: the OLD password is dead, the NEW one works ------- */
	acclen = 0; acc[0] = 0;
	m = openmaster("/dev/ptyp0");
	if (m < 0) { printf("LT14 FAIL master %d\n", m); return 1; }
	if (spawngetty(slave0) < 0) return 1;
	if (drain_until(m, "login:", 1, TRIES) != 1) {
		printf("LT14 FAIL no-greeting6\n");
		dumpacc(); return 1;
	}
	wr(m, "root");
	if (drain_until(m, "Password:", 1, TRIES) != 1) {
		printf("LT14 FAIL no-password-prompt6\n");
		dumpacc(); return 1;
	}
	wr(m, OLDPW);
	if (drain_until(m, "Login incorrect", 1, TRIES) != 1) {
		printf("LT14 FAIL old-password-still-works\n");
		dumpacc(); return 1;
	}
	if (count_in_acc("# ") != 0) {
		printf("LT14 FAIL shell-started\n");
		dumpacc(); return 1;
	}
	printf("LT14 OK\n");

	/* The retry prompt is login's own, so the new password goes in here
	 * rather than on a fresh child. */
	if (drain_until(m, "login:", 2, TRIES) != 1) {
		printf("LT15 FAIL no-retry-prompt6\n");
		dumpacc(); return 1;
	}
	wr(m, "root");
	if (drain_until(m, "Password:", 2, TRIES) != 1) {
		printf("LT15 FAIL no-password-prompt7\n");
		dumpacc(); return 1;
	}
	wr(m, NEWPW);
	if (drain_until(m, "# ", 1, TRIES) != 1) {
		printf("LT15 FAIL new-password-refused\n");
		dumpacc(); return 1;
	}
	printf("LT15 OK\n");

	/* Put it back from inside this same shell, then prove the restore by
	 * logging in with the original on a fresh child. */

	/* LT16: the REST of /etc/passwd survived the rewrite.  A passwd that
	 * emitted only the line it changed would pass every assertion above --
	 * the shipped file is one entry plus a comment, so "the account still
	 * works" cannot tell a rewrite from a truncation.  It would keep
	 * passing right up until someone adds a second account, and then eat
	 * it silently.
	 *
	 * "gecos" is the token to look for: it appears only in the file's
	 * leading "# name:passwd:uid:gid:gecos:dir:shell" comment, and NOT in
	 * the command line the line discipline echoes back -- so one
	 * occurrence is proof the file still has content passwd never wrote. */
	wr(m, "/bin/head -1 /etc/passwd");
	if (drain_until(m, "gecos", 1, TRIES) != 1) {
		printf("LT16 FAIL non-target-lines-lost\n");
		dumpacc(); return 1;
	}
	printf("LT16 OK\n");

	if (setpw(m, OLDPW, 17) != 1) return 1;
	(void) next_prompt(m);
	write(m, "\004", 1);
	drain_to_eof(m, TRIES);
	close(m);

	/* ---- child 7: the original password works again ----------------- */
	acclen = 0; acc[0] = 0;
	m = openmaster("/dev/ptyp0");
	if (m < 0) { printf("LT17 FAIL master %d\n", m); return 1; }
	if (spawngetty(slave0) < 0) return 1;
	if (login_as(m, OLDPW, 17, "7") != 1) return 1;
	printf("LT17 OK\n");
	write(m, "\004", 1);
	drain_to_eof(m, TRIES);
	close(m);

	printf("LOGINTEST PASS\n");
	return 0;
}
