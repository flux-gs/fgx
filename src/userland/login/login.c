/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD login(1)
 *   Ported from login(1), 2.11BSD (login.c 5.40.2 (2.11BSD GTE) 1997/9/26).
 *   Copyright (c) 1980, 1987, 1988
 *   The Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * login(1) - authenticate and exec the user's shell.
 *
 * Kept from upstream: getpwnam -> getpass -> crypt -> compare -> setgid/setuid
 * -> chdir -> build env -> exec the shell as "-sh", the three-attempt loop, and
 * the TTY_SECURE gate on root.  Deleted: quota, setpriority, initgroups,
 * setlogin, lastlog, syslog, tzfile, Kerberos, utmp/wtmp, the login timeout
 * alarm, and the -h hostname/netdb path (which returns if telnetd ever wants
 * it).  None of those subsystems exist on FGX.
 *
 * EXEC, not spawn: the shell replaces this image, so the getty -> login ->
 * shell chain holds exactly one task's bank-0 stack, not three.
 */
#include <stdio.h>
#include <pwd.h>
#include <ttyent.h>
#include <utmp.h>
#include <time.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#define TRIES 3
/* Discarded lines (empty, or longer than nbuf) are refunded rather than charged
 * against TRIES -- a malformed line is not a failed authentication.  But a
 * refund with no ceiling is an unbounded loop: hold Return down and login
 * re-prompts forever.  Upstream survives that on its alarm(3) login timeout,
 * which this port deletes (FGX has no such subsystem), so nothing would ever
 * reclaim the line -- init cannot respawn a getty on a process that has not
 * exited.  Ten is far past any typo and far short of a wedge. */
#define MAXDISCARD 10

char nbuf[64];
char envhome[80];
char envshell[80];
char envuser[80];
char envterm[64];
char arg0[32];
struct utmp utmp;               /* the session's /etc/utmp record */

static char *
lastpart(p)
	char *p;
{
	char *s;

	s = strrchr(p, '/');
	return s != (char *)0 ? s + 1 : p;
}

/* THE SALT DECODER WENT TO libc as crypt_salt(3).  It was a static here, and
 * being a static here is how su(1) came to be ported without it and could not
 * authenticate anybody (apple/fgx#414).  The tag is crypt's contract, so the
 * function that reads it belongs beside crypt. */

/* Read a login name into nbuf.  Returns 1 on a usable name, 0 when the line
 * must be discarded (empty, or longer than the buffer), -1 on EOF.
 *
 * The over-long case is not cosmetic.  fgets() stops at sizeof(nbuf)-1 bytes
 * with no newline in sight, and the untaken remainder does NOT vanish: it stays
 * committed in the per-tty canonical queue (`t_canq') and becomes
 * the first bytes the NEXT reader sees -- here, this program's own getpass().
 * A 200-character "name" would silently supply the password.  getty(8) carries
 * the identical guard for the identical reason; login has its own prompt on the
 * retry path, so it needs its own copy. */
static int
readname()
{
	int i, c;

	if (fgets(nbuf, sizeof(nbuf), stdin) == (char *)0)
		return -1;
	i = strlen(nbuf);
	if (i == sizeof(nbuf) - 1 && nbuf[i - 1] != '\n' && nbuf[i - 1] != '\r') {
		while ((c = getchar()) != '\n' && c != EOF)
			;
		return 0;
	}
	while (i > 0 && (nbuf[i - 1] == '\n' || nbuf[i - 1] == '\r'))
		nbuf[--i] = '\0';
	return nbuf[0] != '\0';
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct passwd *pw;
	struct ttyent *ty;
	char *name, *tn, *shell, *given, *want, *ttype;
	char *env[6], *av[2];
	int t, r, discards, aname;

	tn = ttyname(0);
	ty = tn != (char *)0 ? getttynam(lastpart(tn)) : (struct ttyent *)0;

	/* -T <type>: the terminal type the caller negotiated, which OUTRANKS
	 * the /etc/ttys entry.  This is upstream's `login -p' in a different
	 * costume: 4.xBSD telnetd sets TERM in the child's environment and
	 * passes -p to have login preserve it, but FGX's spawnx carries file
	 * actions with an EMPTY environment, so the type reaches us as an
	 * argument instead -- telnetd -> getty -> here (apple/fgx#147).
	 *
	 * /etc/ttys types a pty line `fgxpty', which is right for a session
	 * from the FGX console and wrong for an xterm; without this every
	 * remote session was driven with the console's capabilities whatever
	 * the client said it was.
	 *
	 * aname is the argv slot the login NAME sits in, which moves when the
	 * flag is present. */
	ttype = (char *)0;
	aname = 1;
	if (argc >= 3 && argv[1][0] == '-' && argv[1][1] == 'T') {
		ttype = argv[2];
		aname = 3;
	}

	pw = (struct passwd *)0;
	discards = 0;
	for (t = 0; t < TRIES; t++) {
		if (t == 0 && argc > aname)
			name = argv[aname];     /* handed over by getty */
		else {
			printf("login: ");
			fflush(stdout);
			r = readname();
			if (r < 0)
				return 1;       /* EOF on the line */
			if (r == 0) {
				if (++discards > MAXDISCARD)
					return 1;   /* wedged: give the
						     * line back to init */
				t--;            /* a discarded line is not
						 * a failed attempt */
				continue;
			}
			name = nbuf;
		}

		pw = getpwnam(name);

		/* ROOT ON AN INSECURE LINE IS REFUSED BEFORE THE PASSWORD IS
		 * ASKED FOR, AND BY NAME.  Upstream, verbatim
		 * (vendor/2.11BSD/usr/bin/login/login.c:226-238):
		 *
		 *     if (pwd->pw_uid == 0 && !rootterm(tty)) {
		 *             (void)fprintf(stderr,
		 *                 "%s login refused on this terminal.\n",
		 *                 pwd->pw_name);
		 *             ...
		 *             continue;
		 *     }
		 *
		 * This port had the gate AFTER the password compare and made it
		 * print "Login incorrect" and RETURN, which cost a real
		 * diagnosis: a correct root password on ttyp1 reported a wrong
		 * password and dropped the connection, and the only way to tell
		 * that from a broken password path was to read this file.  The
		 * message names the reason now and the loop re-prompts, so the
		 * session survives and another account can log in on the line.
		 *
		 * IT TELLS YOU THE ACCOUNT EXISTS, and that is upstream's
		 * bargain rather than an oversight: the name is in the message.
		 * The "ask anyway when the account does not exist" rule below
		 * still stands and is what keeps NAMES from leaking.
		 *
		 * A LINE ABSENT FROM /etc/ttys IS NOT INSECURE HERE, which IS a
		 * divergence: `rootterm' is `getttynam(ttyn) && ty_status &
		 * TTY_SECURE' (login.c:479-484), so upstream refuses root on
		 * every line the file does not mention.  FGX would lock the
		 * only account out of anything new, so `ty == NULL' passes.
		 *
		 * STDOUT RATHER THAN STDERR, unlike upstream: every other
		 * message in this file goes to stdout and both land on the same
		 * line, so mixing the two streams would only risk reordering. */
		if (pw != (struct passwd *)0 && pw->pw_uid == 0
		 && ty != (struct ttyent *)0
		 && (ty->ty_status & TTY_SECURE) == 0) {
			printf("%s login refused on this terminal.\n",
			       pw->pw_name);
			fflush(stdout);
			pw = (struct passwd *)0;
			continue;
		}

		/* Ask for a password even when the account does not exist:
		 * answering "no such user" immediately tells an attacker which
		 * names are real.  2.11BSD does the same. */
		given = getpass("Password:");
		want = pw != (struct passwd *)0 ? pw->pw_passwd : "*";
		if (pw != (struct passwd *)0 && want[0] != '\0'
		 && strcmp(want, crypt(given, crypt_salt(want))) == 0)
			break;                  /* authenticated */

		printf("Login incorrect\n");
		pw = (struct passwd *)0;
	}

	if (pw == (struct passwd *)0)
		return 1;


	/* NOTHING ELSE LEFT TO FAIL -- REALLY LOG IN.  The /etc/utmp record goes
	 * in here, before the privilege drop, because the file is root's: this is
	 * where 4.3BSD's login(1) puts it for the same reason.
	 *
	 * The line is the basename of ttyname(0), copied out BEFORE login(3)
	 * runs: ttyslot() inside it calls ttyname() again, and that returns a
	 * pointer into a static buffer this would otherwise still be reading.
	 * A session with no terminal gets no record, which is also what
	 * ttyslot() == 0 comes to. */
	if (tn != (char *)0) {
		memset((char *)&utmp, 0, sizeof(struct utmp));
		utmp.ut_time = time((long *)0);
		strncpy(utmp.ut_name, pw->pw_name, UT_NAMESIZE);
		strncpy(utmp.ut_line, lastpart(tn), UT_LINESIZE);
		login(&utmp);
	}

	/* THE SESSION'S LOGIN NAME, and it must go in BEFORE the privilege drop:
	 * setlogin(2) is super-user only, which is 2.11BSD's own rule for a
	 * kernel with no sessions (usr/sys/sys/kern_prot.c:181-186).  Upstream
	 * puts the call in the same place and warns the same way --
	 * usr/bin/login/login.c:434, immediately above its own setuid, with the
	 * comment "discard permissions last so can't get killed and drop core".
	 *
	 * This is what makes getlogin(3) answer after su(1): the name is in the
	 * u-area and survives the setuid below, the exec of the shell, and every
	 * fork under it. */
	if (setlogin(pw->pw_name) < 0)
		fprintf(stderr, "login: setlogin(): %s\n", strerror(errno));

	setgid(pw->pw_gid);
	setuid(pw->pw_uid);

	if (pw->pw_dir != (char *)0 && pw->pw_dir[0] != '\0')
		chdir(pw->pw_dir);              /* failure is not fatal */

	shell = (pw->pw_shell != (char *)0 && pw->pw_shell[0] != '\0')
	      ? pw->pw_shell : "/bin/sh";

	sprintf(envhome,  "HOME=%s", pw->pw_dir);
	sprintf(envshell, "SHELL=%s", shell);
	sprintf(envuser,  "USER=%s", pw->pw_name);
	sprintf(envterm,  "TERM=%s",
	        ttype != (char *)0 && ttype[0] != '\0' ? ttype
	        : (ty != (struct ttyent *)0 && ty->ty_type[0] != '\0'
	           ? ty->ty_type : "vt100"));
	env[0] = "PATH=:/bin:/usr/bin:/sbin";
	env[1] = envhome;
	env[2] = envshell;
	env[3] = envuser;
	env[4] = envterm;
	env[5] = (char *)0;

	/* argv[0] = "-sh": the leading dash is what makes it a login shell.
	 * Plain char *[] locals are correct here -- execve() stages both the
	 * pointer table and any out-of-bank strings into libc's data-bank
	 * arena.  The `static int[]` spawn ABI rule applies to spawnve/spawnx,
	 * which this file deliberately does not use. */
	sprintf(arg0, "-%s", lastpart(shell));
	av[0] = arg0;
	av[1] = (char *)0;

	execve(shell, av, env);

	/* ENOMEM here means the bank-0 stack arena cannot fund this shell.
	 * Falling back to /bin/sh (12 pages against tcsh's 55) keeps the
	 * session rather than dropping the user back to a login prompt they
	 * cannot get past.  This ships WITH the feature, not after it: until
	 * the console-lane swap (slice B3) lands it is the only backstop
	 * against the arena ceiling. */
	if (errno == ENOMEM && strcmp(shell, "/bin/sh") != 0) {
		printf("login: %s: out of memory, falling back to /bin/sh\n",
		       shell);
		av[0] = "-sh";
		execve("/bin/sh", av, env);
	}
	perror("login: exec");
	return 1;
}
