/* getty(8) - greet, read a login name, exec login.
 *
 * FGX-Provenance: none.  2.11BSD keeps getty in libexec/, which this tree does
 * not vendor, and the job collapses here anyway: no baud negotiation, no modem
 * control, no parity autodetect, no gettytab.
 *
 * IT DOES NOT OPEN ITS LINE, and upstream's does.  init's child opens
 * /dev/<name> onto 0/1/2 before exec'ing us (init.c), which is where the
 * controlling terminal gets bound -- 2.11BSD's ttyopen() binds ctty and
 * process group together for a caller that has neither, so the open has to
 * happen in the process that will run on the line.  BSD puts that open in
 * getty; FGX puts it one step earlier, in the child init forks.
 *
 * Moving it here would need the console line to run getty too, because
 * /etc/ttys gives the console /bin/sh directly and a shell opens nothing --
 * i.e. it needs a login prompt on the console, which is a policy question and
 * not a refactor (apple/fgx#121).  Recorded so the difference reads as a
 * choice rather than an oversight.
 *
 * It sets cooked modes, prints /etc/issue and the prompt, reads a name, and
 * EXECS login -- exec, not spawn, so the chain costs no extra bank-0 stack
 * arena.
 */
#include <stdio.h>
#include <sgtty.h>
#include <string.h>
#include <unistd.h>

/* Declared here, not pulled from a header: no FGX header exposes `environ`
 * (see src/userland/printenv/printenv.c, which does the same thing) -- an
 * undeclared `environ` is a hard fcc compile error, not an implicit-int
 * fallback, since it is a variable reference rather than a function call. */
extern char **environ;

char name[64];

static void
catfile(path)
	char *path;
{
	FILE *f;
	int c;

	f = fopen(path, "r");
	if (f == (FILE *)0)
		return;                  /* no issue file is not an error */
	while ((c = getc(f)) != EOF)
		putchar(c);
	fclose(f);
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct sgttyb t;
	char *av[5];
	char *ttype;
	int i;

	/* -T <type>: the terminal type the caller negotiated, passed straight
	 * through to login.  telnetd(8) learns it from the client's
	 * TERMINAL-TYPE subnegotiation and has nowhere else to put it -- spawnx
	 * carries file actions and an empty environment, so upstream's
	 * setenv("TERM") + `login -p' is not available and the type travels as
	 * an argument, the way upstream threads `-h host'.  Absent, login falls
	 * back to the /etc/ttys entry, which is what every line got before
	 * (apple/fgx#147). */
	ttype = (char *)0;
	if (argc >= 3 && argv[1][0] == '-' && argv[1][1] == 'T')
		ttype = argv[2];

	/* Cooked line discipline with echo: the login name IS echoed (only the
	 * password is not).  Explicit rather than inherited, because init may
	 * respawn us after a session that left the line in raw mode -- and
	 * "raw mode" is EITHER sg_flags bit: the kernel's cooked-vs-char-at-a-
	 * time gate is SG_RAWCB = SG_RAW+SG_CBREAK (include/loader.s:668,
	 * tested at src/kernel/syscall.s:3397), so clearing only CBREAK left a
	 * line RAW from a prior vi/elvis session on the raw read path
	 * (syscall.s:3618) forever: Enter never becomes the LF fgets() breaks
	 * on, and the "login:" prompt hangs -- the exact dead-terminal
	 * failure this file's own BUGS section warns about.
	 *
	 * If TIOCGETP itself fails, there is nothing to fix: fd 0 is not a
	 * real tty, which cannot happen under the getty(8) contract (init's
	 * child opens the line on /etc/ttys before exec'ing us -- see the
	 * man page).  Silently proceeding on whatever discipline is already
	 * in effect is the same choice libc's getpass() makes for the
	 * identical ioctl (its `have_tty` gate, libc_c.c) -- there is no
	 * getty fallback path to run instead. */
	if (ioctl(0, TIOCGETP, (char *)&t) == 0) {
		t.sg_flags = (t.sg_flags | ECHO | CRMOD) & ~(CBREAK | RAW);
		ioctl(0, TIOCSETP, (char *)&t);
	}

	for (;;) {
		catfile("/etc/issue");
		printf("login: ");
		fflush(stdout);

		if (fgets(name, sizeof(name), stdin) == (char *)0)
			return 1;            /* EOF on the line: let init respawn */
		i = strlen(name);

		/* fgets() stops at sizeof(name)-1 bytes even with no newline in
		 * sight.  A login name that long is legal -- the kernel's
		 * canonical queue holds a whole line -- and the
		 * untaken remainder does not vanish: it stays committed in the
		 * per-tty `t_canq' (the discipline hands out one canonical
		 * line across however many read() calls the caller makes) and
		 * becomes the FIRST bytes the *next* reader sees --
		 * which after execve() is login's "login:" echo or its
		 * getpass() password read.  Detect the buffer-full-without-a-
		 * newline case and drain the rest of the physical line here,
		 * discarding this attempt, instead of exec'ing a truncated
		 * fragment and leaking the tail into login.
		 *
		 * This also rejects the one legal name that is exactly
		 * sizeof(name)-1 chars: fgets() cannot be told that case apart
		 * from a genuine overflow without reading one more byte, and a
		 * 63-character username is not a real-world loss. */
		if (i == sizeof(name) - 1 &&
		    name[i - 1] != '\n' && name[i - 1] != '\r') {
			int c;

			while ((c = getchar()) != '\n' && c != EOF)
				;
			continue;
		}

		while (i > 0 && (name[i - 1] == '\n' || name[i - 1] == '\r'))
			name[--i] = '\0';
		if (name[0] == '\0')
			continue;            /* bare return: re-prompt */

		/* execve, not spawn: replaces this image, so getty's stack is
		 * freed before login's is allocated.  Plain char *argv[] is
		 * correct here -- libc's execve stages the vectors into the
		 * data bank itself (libc_c.c:966).  The spawnve int[] rule
		 * applies to init, not to us. */
		i = 0;
		av[i++] = "login";
		if (ttype != (char *)0) {
			av[i++] = "-T";
			av[i++] = ttype;
		}
		av[i++] = name;
		av[i] = (char *)0;
		execve("/bin/login", av, environ);

		/* Only reached if exec failed. */
		perror("getty: /bin/login");
		return 1;
	}
}
