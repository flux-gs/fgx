/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD init(8)
 *   Ported from init(8), 2.11BSD (init.c 5.6.4 (2.11BSD) 1999/2/23).
 *   Copyright (c) 1980, 1986, 1993
 *   The Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * init(8) - PID 1.  Runs /etc/rc, then keeps a getty alive on every /etc/ttys
 * line marked "on".
 *
 * Kept from upstream: the itab line table built from getttyent(), the
 * respawn-on-child-exit loop keyed by pid, the gettytime/gettycnt throttle
 * (dfork()) that stops a broken ty_getty spinning the machine, the /etc/utmp
 * record for the console line, and multi_user()'s raise of the kernel security
 * level.  Deleted, not stubbed: syslog, autoconfig(), wtmp, the single-user
 * transition, and the window-system wcmd fork.  FGX HAS NO SINGLE-USER MODE,
 * which is why the raise below has no matching lowering: the only window in
 * which the machine runs at level 0 is /etc/rc.
 *
 * Upstream's throttle SLEEPS 30 s and retries forever; this one DISABLES the
 * line and says so.  A machine whose only console is a spinning /bin/false is
 * indistinguishable from a hung one, and FGX has no second console to notice
 * from.
 *
 * ------------------------------------------------------------------ traps --
 *
 * /etc/rc RUNS TO COMPLETION FIRST.  The vendored BSD rc sources /etc/netstart,
 * which is where dhclient leases; a getty that prompts before the network is up
 * races the MAME gates.  jsh used to source rc+netstart itself; bsh never did,
 * so when bsh became the login shell the network silently stopped coming up at
 * boot -- init owns rc now, whoever the shell is.  A missing or failing rc is
 * not fatal.
 *
 * THE WAIT LOOP MATCHES PIDS TO LINES.  Orphans are reparented to init, so a
 * blanket wait() that treated any reaped pid as "a line died" would respawn the
 * wrong line -- or, before this rewrite, halt the machine the moment any orphan
 * died.  (Orphan zombies are swept by the kernel's _Exit_Core SEF_REPARENTED
 * path, not by init.)
 *
 * THE CONSOLE LINE IS NO LONGER SPECIAL (apple/fgx#121).  It used to read:  Every other line is opened as /dev/<name> onto the child's
 * 0/1/2 (getty(8) opens nothing -- see its man page), but there is no chardev
 * named "console": the kernel registers null, ptyp0/ttyp0 and ptyp1/ttyp1
 * (chardev.s _Chardev_InitBuiltins), and /dev/console would resolve to ENOENT
 * (drivers/fs/path.s).  init's OWN 0/1/2 already are the console, so the child
 * inherits them.  The line is named "console" rather than ttyv0 to match what
 * ttyname(0) reports for tty[0] (signal.s _ttyNames), which is the key
 * login(1) looks its TERM and TTY_SECURE flag up under.
 *
 * ENVIRONMENT SEEDING survives only for a ty_getty that is a BARE SHELL, which
 * is what the console line ships as: /bin/sh with no login(1) in between, so
 * nothing else would build the environment login(1) normally supplies (per
 * environ(7): PATH, HOME, TERM).  Without it the login shell falls back to
 * whatever path is compiled into it (bsh's sh/msg.c defpath ":/bin:/usr/bin").
 * /etc/profile could not do this job and no longer exists: the Bourne shell
 * never reads it (a System V convention), and its own hook -- ".profile"
 * relative to the login directory -- is not a representable ProDOS name
 * (docs/filesystem.md).  jsh read it and jsh was removed 2026-07-29, which left
 * a file that seeded nothing, restated these three values in a second place
 * where they could drift, and cost a wrong fix for apple/fgx#114 -- the obvious
 * edit went there and changed nothing measurable.  Deleted 2026-08-15; this is
 * now the only place the login environment is defined.
 *
 * TWO THINGS IT CARRIED THAT ARE WORTH KEEPING.  TERM's value is "vt100"
 * because that is what the old baked getenv() answered, and FGX's termcap
 * bridge serves its console entry for any non-null name; BSD's login(1) would
 * derive it from the tty type, and e_term below does exactly that.  And umask
 * and stty are DELIBERATELY not seeded: BSD's root .profile tunes the tty at
 * login, but changing console modes is a behaviour change rather than an
 * environment seed, and a umask line would have to be exec'd as a program.
 *
 * Lines that run /bin/getty get their environment from login(1) instead, which
 * is just as well: SPAWNX takes file_actions and no envp (process.s
 * _Sys_PosixSpawnX), so a line that needs its device opened cannot also be
 * handed an environment.
 *
 * SIGNALS ARE FLAG-SETTERS AND NOTHING ELSE.  Delivery is synchronous, at the
 * exit of a syscall init itself made, and the trampoline preserves only the
 * interrupted call's registers -- a handler that printf'd or kill'd would
 * corrupt whatever libc call it landed on (docs/userland-abi.md section 6A).
 * So onterm/onhup set an int and return; the wait() loop does the work at the
 * next iteration.  A signal that arrives while we are blocked in wait() makes
 * that wait return EINTR, which is what gets us to the poll promptly -- hence
 * the errno test in the loop, without which an EINTR would look like ECHILD
 * and halt the machine.
 *
 * SIGTERM = orderly shutdown: stop respawning, hang the lines up, sync, exit.
 * init exiting with no parent is what trips _Kern_Halt, so the exit IS the
 * halt; the point of the handler is the sync and the hangups that precede it.
 * halt(8) no longer has to sync before signalling.  Lines are hung up with
 * SIGHUP, not SIGTERM -- an interactive Bourne shell ignores SIGTERM on
 * purpose, so the obvious signal is a no-op here.  See hangup().
 *
 * SIGHUP = re-read /etc/ttys, MERGING into the running table rather than
 * rebuilding it: an unchanged line keeps its pid untouched (its session must
 * survive a HUP), a line that is new or whose command changed is (re)started,
 * and a line that left the file or went "off" has its child hung up.  A HUP
 * also clears the respawn throttle on every line still listed "on", which is
 * how an operator says "I fixed it, try again" after a line was disabled.
 *
 * Both were dead until 2026-08-04: the kernel had handler tables for
 * SIGINT/SIGALRM/SIGCHLD only, so signal(SIGTERM, ...) reported success and
 * installed nothing (apple/fgx#26).  That gap is closed -- kernel signal.s
 * _SigHndBase now maps five signals -- but the lesson stands: check that list
 * before building on a signal.
 */
#include <stdio.h>
#include <string.h>
#include <ttyent.h>
#include <utmp.h>              /* login(3)/logout(3): the line's /etc/utmp record */
#include <fcntl.h>             /* creat: /etc/utmp starts empty at every boot */
#include <time.h>
#include <sgtty.h>              /* TIOCSPGRP, for the console line's session */
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/sysctl.h>       /* CTL_KERN/KERN_SECURELVL: the multiuser raise */
/* unistd.h for chdir: it hands the path BANK to __syscall_db, so the real
 * prototype matters -- an implicit declaration is not safe here. */
#include <unistd.h>

int execve(char *path, char **argv, char **envp);
int fork();
int open();
int close();
int dup2();
long time(long *t);

/* Set by the signal handlers, consumed by the wait loop.  Nothing else may
 * happen in a handler -- see the header. */
static int gotterm;
static int gothup;

#define NITAB     8        /* lines; /etc/ttys ships 5 */
#define GETTYCNT  5        /* spawns per window before a line is disabled */
#define GETTYTIME 60L      /* window, seconds */

struct itab {
	char name[16];     /* ty_name: also the /dev/ node for non-console */
	char cmd[64];      /* ty_getty: a single command path on FGX */
	char type[16];     /* ty_type -> TERM, for a bare-shell line */
	int  console;      /* 1 = inherit init's 0/1/2 (see header) */
	int  pid;          /* 0 = not running */
	int  count;        /* spawns inside the current window */
	long window;       /* start of the current window, seconds */
	int  disabled;     /* throttled off; never respawned again */
	int  seen;         /* SIGHUP merge scratch: still in /etc/ttys */
	int  start;        /* SIGHUP merge scratch: start once ttys is closed */
};
static struct itab itab[NITAB];
/* The console line's /etc/utmp record.  File scope because login(3) takes it by
 * address and an fcc local aggregate lands on the bank-0 stack. */
static struct utmp utrec;
static int nitab;

/* Exec-time scratch: what init hands execve and open for each line. */
static char *av[2];
static char *ev[4];
static char a_arg0[24];
/* environ(7)'s PATH, mapped onto FGX's layout.  /usr/fgx/bin is a SYSTEM tool
 * directory -- dmesg, vmstat, slotscan, font, color, fas, fractal, ntpinfo,
 * ntpplay -- so it belongs in the seed login(1) would supply, not in a per-user
 * dotfile.  It lived in /root/.profile alone until 2026-08-15, which meant nine
 * shipped tools resolved by name for root and for nobody else.  This is the one
 * place the default lives: bsh never read /etc/profile and the file is gone (header note),
 * and its compiled-in defpath is vendored 2.11BSD and is not ours to patch. */
static char e_path[] = "PATH=:/bin:/usr/bin:/sbin:/usr/fgx/bin";
static char e_home[] = "HOME=/root";
static char e_term[32];
static char devpath[24];

/* cmsg -- one line on the console, written by a CHILD.
 *
 * init has no descriptors: the kernel starts it with none, as 2.11BSD's does,
 * and it must not open a terminal itself.  ttyopen() hands a terminal to any
 * opener with no process group (tty.c:654), so init opening /dev/console would
 * make the console init's controlling terminal and put init in the path of the
 * console's ^C.  2.11BSD writes to the console from a forked child for the
 * same reason -- shutreset() (usr/sbin/init/init.c:177-181):
 *
 *      if (fork() == 0) {
 *              int ct = open(ctty, 1);
 *              write(ct, shutfailm, sizeof (shutfailm));
 *
 * Upstream's other diagnostics go to syslog with LOG_CONS; FGX's are printed
 * here, and the child is reaped at once so the respawn loop, which is keyed by
 * pid, never sees it. */
static char cbuf[128];

static void
cmsg(s)
	char *s;
{
	int pid, fd;

	pid = fork();
	if (pid == 0) {
		fd = open("/dev/console", 1);
		if (fd >= 0)
			write(fd, s, strlen(s));
		_exit(0);
	}
	if (pid > 0)
		waitpid(pid, (int *)0, 0);
}

/* getsecuritylevel / setsecuritylevel -- 2.11BSD usr/sbin/init/init.c:231 and
 * :255, minus the syslog calls upstream makes on failure (init does not open a
 * log; every other diagnostic in this file goes to the console by cmsg).
 *
 * A FAILURE IS -1 AND THE CALLER TREATS IT AS "DO NOT RAISE", which is
 * upstream's own arrangement -- its #else arm returns -1 for a kernel built
 * without KERN_SECURELVL, and the call site's `== 0' test then does nothing.
 * So a kernel that does not serve the leaf boots exactly as it did before. */
static int
getsecuritylevel()
{
	int name[2], curlevel;
	unsigned len;

	name[0] = CTL_KERN;
	name[1] = KERN_SECURELVL;
	len = sizeof curlevel;
	if (sysctl(name, 2, &curlevel, &len, (void *)0, 0) == -1)
		return (-1);
	return (curlevel);
}

static void
setsecuritylevel(newlevel)
	int newlevel;
{
	int name[2], curlevel;

	curlevel = getsecuritylevel();
	if (newlevel == curlevel)
		return;
	name[0] = CTL_KERN;
	name[1] = KERN_SECURELVL;
	if (sysctl(name, 2, (void *)0, (unsigned *)0, &newlevel,
	    sizeof newlevel) == -1)
	{
		sprintf(cbuf, "init: cannot set kernel security level %d: %s\n",
		    newlevel, strerror(errno));
		cmsg(cbuf);
	}
}


/* /etc/rc, run to completion before any line starts.  Its first argument is
 * "autoboot", which is what upstream's runcom() passes on any boot that is not
 * single-user (usr/sbin/init/init.c:326-329: "fastboot" for RB_SINGLE or
 * RB_NOFSCK, "autoboot" otherwise).  FGX has neither flag, so every boot is an
 * autoboot, and /etc/rc's autoboot arm is where the boot fsck runs. */
static char a_rcsh[] = "sh";
static char a_rc[]   = "/etc/rc";
static char a_auto[] = "autoboot";
static char *rcav[4];

/* Last path component, for argv[0]. */
static char *
lastpart(p)
	char *p;
{
	char *s;

	s = strrchr(p, '/');
	return s != (char *)0 ? s + 1 : p;
}

/* Copy one /etc/ttys line into slot i and reset that slot's runtime state.
 * Shared by the boot-time read and the SIGHUP merge, so the two cannot drift.
 * The strncpy bound leaves the last byte alone; itab is file-scope (zeroed),
 * and nothing ever writes that byte, so every field stays NUL-terminated. */
static void
fillline(i, t)
	int i;
	struct ttyent *t;
{
	strncpy(itab[i].name, t->ty_name, sizeof(itab[i].name) - 1);
	strncpy(itab[i].cmd,  t->ty_getty, sizeof(itab[i].cmd) - 1);
	strncpy(itab[i].type, t->ty_type,  sizeof(itab[i].type) - 1);
	itab[i].console = strcmp(t->ty_name, "console") == 0;
	itab[i].pid = 0;
	itab[i].count = 0;
	itab[i].window = 0;
	itab[i].disabled = 0;
}

/* Fill itab from /etc/ttys, keeping only lines with TTY_ON.  Lines that are
 * "off" are skipped HERE, by the flag -- not by failing to open them later.
 * (ttyv1/ttyv2 ship off until the virtual-console devices exist; ttyp0/ttyp1
 * are off because a pty session belongs to whoever opened the master.) */
static void
readttys()
{
	struct ttyent *t;

	nitab = 0;
	setttyent();
	while ((t = getttyent()) != (struct ttyent *)0) {
		if ((t->ty_status & TTY_ON) == 0)
			continue;
		if (nitab >= NITAB) {
			sprintf(cbuf, "init: more than %d active lines, %s ignored\n",
			       NITAB, t->ty_name);
			cmsg(cbuf);
			continue;
		}
		fillline(nitab, t);
		nitab++;
	}
	endttyent();
}

/* Spawn line i's ty_getty, unless the throttle says the line is broken.
 * Upstream dfork(): more than GETTYCNT spawns inside one GETTYTIME window
 * means the command is failing immediately rather than serving a session. */
/* reportfail -- say a line's getty could not be exec'd, on the CONSOLE.
 *
 * Opened here, in the child, after the exec has failed.  Not on the redirected
 * fd 2: a line with a real device has its own screen on 1 and 2, and `cannot
 * spawn' would go to the background console of the very line that failed to
 * start (apple/fgx#349).  Opening it this late cannot take the console as this
 * child's controlling terminal: the child's own line already is.  sprintf into
 * a local is fine -- the child is about to _exit and the strings are bounded by
 * /etc/ttys' own field widths. */
static void
reportfail(name, cmd)
char *name;
char *cmd;
{
	char buf[128];
	int fd;

	sprintf(buf, "init: %s: cannot spawn '%s'\n", name, cmd);
	fd = open("/dev/console", 1);
	if (fd >= 0)
		write(fd, buf, strlen(buf));
}


static void
startline(i)
	int i;
{
	long now;
	char *p;
	int pid, k, poff;

	if (itab[i].disabled)
		return;

	now = time((long *)0);
	itab[i].count++;
	if (itab[i].count == 1) {
		/* First spawn of this line: seed the window explicitly.  It used
		 * to be seeded only as a side effect of the >= GETTYTIME test
		 * below, which self-corrects while time() returns a real epoch
		 * (now - 0 is enormous) but not if the clock reads back small or
		 * stuck: window stayed 0, every comparison failed, and the
		 * throttle silently became a SIX-SPAWNS-PER-BOOT cap on the
		 * console.  See the RTC note in the header. */
		itab[i].window = now;
	} else if (now - itab[i].window >= GETTYTIME) {
		itab[i].window = now;
		itab[i].count = 1;
	} else if (itab[i].count > GETTYCNT) {
		itab[i].disabled = 1;
		itab[i].pid = 0;
		sprintf(cbuf, "init: %s: '%s' respawning too fast -- line disabled\n",
		       itab[i].name, itab[i].cmd);
		cmsg(cbuf);
		return;
	}

	/* argv[0] for a bare shell is "-sh": the leading '-' is what makes the
	 * Bourne shell behave as a login shell.  A getty gets its own name.
	 * BOUNDED: ty_getty is char[64] and this buffer is char[24], so the
	 * unbounded strcpy/strcat this replaced would run a long basename off
	 * the end of a_arg0 straight into e_path/e_home -- silently corrupting
	 * the environment PID 1 hands its children. */
	p = lastpart(itab[i].cmd);
	k = 0;
	if (itab[i].console)
		a_arg0[k++] = '-';
	strncpy(a_arg0 + k, p, sizeof(a_arg0) - k - 1);
	a_arg0[sizeof(a_arg0) - 1] = '\0';
	av[0] = a_arg0;
	av[1] = (char *)0;

	sprintf(e_term, "TERM=%s",
	        itab[i].type[0] != '\0' ? itab[i].type : "vt100");
	ev[0] = e_path;
	ev[1] = e_home;
	ev[2] = e_term;
	ev[3] = (char *)0;

	/* Every line is an IFCHR inode on the mounted root, resolved by namei
	 * and served through spec_*.  apple/fgx#311. */
	strcpy(devpath, "/dev/");
	strcat(devpath, itab[i].name);

	/* fork, then let the CHILD open its own line -- 2.11BSD's recipe, and
	 * the same one for every line including the console.
	 *
	 * The open is what matters and it must happen in the child: ttyopen()
	 * binds the controlling terminal AND the foreground process group in one
	 * guarded block, gated on the opener having no group yet (tty.c:654), so
	 * the process that will RUN on the line has to be the one that opens it.
	 * init's children arrive with pgrp 0, so each founds its own session.
	 *
	 * This replaces spawnx-with-file-actions for the ordinary lines and
	 * spawnve for the console.  That split existed because the console needed
	 * an environment AND actions while spawnx carried only actions and
	 * spawnve only an environment -- a fork+execve child needs neither ABI,
	 * because it does its own opens and execve takes envp.  So the console
	 * special case, and the file-action construction, both go.
	 *
	 * BSD's single-user console path is this exact sequence (init.c:296-301):
	 * open(ctty, O_RDWR), dup2 onto 0/1/2, exec the shell.
	 *
	 * fork, not vfork: measured at ~149 ms a line against spawn's ~239 ms
	 * (spawnbench(8), apple/fgx#121), which is ~0.45 s once at boot across
	 * the three lines that are `on'.  Trivial for something that happens at
	 * boot and at logout, and it keeps BSD's primitive rather than trading
	 * it for a cheaper one.
	 */
	pid = fork();
	if (pid == 0) {
		int fd;

		/* The mask survives exec, and startline() is called from inside
		 * the SIGTERM-held merge: 2.11BSD's child does the same,
		 * `sigsetmask(0L);', "since can be called from masked code"
		 * (usr/sbin/init/init.c:536). */
		sigsetmask(0L);
		fd = open(devpath, 2);            /* O_RDWR: binds ctty + pgrp */
		if (fd >= 0) {
			dup2(fd, 0);
			dup2(fd, 1);
			dup2(fd, 2);
			if (fd > 2)
				close(fd);
		}
		/* login(1) chdir()s to the home directory before exec'ing the
		 * shell (2.11BSD usr/bin/login/login.c:318), and the Bourne
		 * shell's only startup hook is ".profile" relative to the CURRENT
		 * directory (sh/main.c pathopen(nullstr, profile)) -- not $HOME.
		 * The console line has no login(1) in front of it, so its child
		 * does this too, IN THE CHILD: init itself stays in `/', as
		 * 2.11BSD's init does, and so do /etc/rc and every other line.
		 * Failure is not fatal: a missing /root means the shell starts in
		 * `/'.
		 *
		 * The session's /etc/utmp record is the same: login(1) writes it
		 * once the line is its 0, 1 and 2 (2.11BSD usr/bin/login/login.c:
		 * 359-367, `login(&utmp)'), and so does this child, as root --
		 * init never drops privilege, so root is what the shell runs as.
		 * login(3) files the record under ttyslot(), which reads fds 0-2:
		 * here they are the line; in init, which has none, they are not. */
		if (itab[i].console) {
			memset((char *)&utrec, 0, sizeof(struct utmp));
			strncpy(utrec.ut_line, itab[i].name, UT_LINESIZE);
			strncpy(utrec.ut_name, "root", UT_NAMESIZE);
			utrec.ut_time = time((long *)0);
			login(&utrec);
			chdir("/root");
		}
		/* Exec failed.  THE CHILD HAS TO SAY SO: with spawn the parent
		 * learned of a bad ty_getty synchronously, but a fork+exec
		 * failure happens over here, so the parent only ever sees a
		 * child that died.  BSD is content to let the throttle disable
		 * the line, but losing the message would make a typo in
		 * /etc/ttys silent until the fifth respawn. */
		execve(itab[i].cmd, av, ev);
		/* Only reached if exec FAILED -- execve does not return on
		 * success, so the report belongs after it, not before. */
		reportfail(itab[i].name, itab[i].cmd);
		_exit(1);
	}

	if (pid < 0) {
		sprintf(cbuf, "init: %s: cannot spawn '%s'\n",
		       itab[i].name, itab[i].cmd);
		cmsg(cbuf);
		itab[i].pid = 0;
		return;
	}

	/* The console line's parent-side session setup is GONE (apple/fgx#121).
	 *
	 * It used to do setpgid(pid,pid) + TIOCSPGRP here, reproducing
	 * ttyopen()'s process-group half from the parent because the console had
	 * no device node for the child to open -- and the controlling-terminal
	 * half had nowhere to happen at all.  The child now opens /dev/console
	 * like every other line, so ttyopen() does both halves together, in the
	 * one guarded block BSD keeps them in.
	 *
	 * Safe to delete rather than merely redundant: the line is released on
	 * close too.  _Con_Close is ttyclose(), so the shell's exit zeroes
	 * tty[0]'s foreground group and the next child FOUNDS its own session
	 * instead of joining a dead one.  Without that close half this deletion
	 * would strand every respawn in the previous shell's group.
	 */

	itab[i].pid = pid;
}

/* Hang up line i's child, if it has one, and forget the pid.
 *
 * SIGHUP rather than SIGTERM, and that is load-bearing rather than taste: an
 * interactive Bourne shell ignores SIGTERM ON PURPOSE -- sh/main.c does
 * `ignsig(KILL)` once it decides it is interactive, and sh/defs.h defines its
 * KILL as 15 -- so SIGTERM against a shell line is a no-op.  MEASURED
 * 2026-08-04: the console shell survived `kill -15 $$` with its shell variables
 * intact, and died on `kill -1 $$`.  SIGHUP is also the honest meaning here:
 * the line is going away, which is what a hangup is.
 *
 * No SIGKILL escalation.  Nothing in the image is known to ignore SIGHUP, and
 * on the shutdown path init exits immediately afterwards, which halts the
 * machine anyway.  Add the escalation when something is found to need it.
 */
static void
hangup(i)
	int i;
{
	if (itab[i].pid != 0) {
		/* 2.11BSD term(): rmut(p) before the kill; rmut's wtmp end
		 * record is written only for a record it found. */
		if (logout(itab[i].name))
			logwtmp(itab[i].name, "", "");
		kill(itab[i].pid, SIGHUP);
		itab[i].pid = 0;
	}
}

/* ------------------------------------------------------------------ signals --
 * Both handlers set a flag and return.  That is the entire supported handler
 * surface on FGX (docs/userland-abi.md section 6A): delivery lands on top of
 * whatever libc call it interrupted, and libc is not reentrant.  Every actual
 * response happens in the wait loop.  Declared int-returning to match how the
 * other FGX ports hand a function to signal(). */
int
onterm(sig)
	int sig;
{
	gotterm = 1;
	return 0;
}

int
onhup(sig)
	int sig;
{
	gothup = 1;
	return 0;
}

/* SIGHUP: merge /etc/ttys into the running table.
 *
 * A merge, not a re-read: an unchanged line's session must survive the HUP
 * untouched, so its pid is never disturbed.  New lines start; a line whose
 * command changed is retired and restarted under the new one; a line that left
 * the file, or that flipped to "off", has its child killed and is retired.
 *
 * A HUP also clears the respawn throttle on every line still listed "on" --
 * the operator fixing a broken ty_getty and sending a HUP is exactly the
 * "try it again" signal, and without this a line disabled once could never
 * come back short of a reboot. */
static void
rereadttys()
{
	struct ttyent *t;
	int i;

	for (i = 0; i < nitab; i++)
		itab[i].seen = 0;

	/* readttys()/this function both endttyent(), which CLOSES the stream,
	 * so setttyent() re-opens the file rather than rewinding a stale
	 * buffered copy.  That close is what makes an edit on disk visible. */
	setttyent();
	while ((t = getttyent()) != (struct ttyent *)0) {
		if ((t->ty_status & TTY_ON) == 0)
			continue;
		for (i = 0; i < nitab; i++)
			if (strcmp(itab[i].name, t->ty_name) == 0)
				break;
		if (i == nitab) {			/* a new line */
			if (nitab >= NITAB) {
				sprintf(cbuf, "init: more than %d active lines, %s ignored\n",
				       NITAB, t->ty_name);
				cmsg(cbuf);
				continue;
			}
			fillline(i, t);
			nitab++;
			itab[i].seen = 1;
			itab[i].start = 1;
			continue;
		}
		itab[i].seen = 1;
		if (strcmp(itab[i].cmd, t->ty_getty) != 0) {
			/* Same device, different command.  Retire the running
			 * child; hangup() clears .pid, so when the corpse is
			 * reaped the wait loop sees an unknown pid and does not
			 * respawn the OLD command over the new one. */
			hangup(i);
			fillline(i, t);
			itab[i].start = 1;
		} else if (itab[i].disabled) {
			itab[i].disabled = 0;
			itab[i].count = 0;
			itab[i].window = 0;
			if (itab[i].pid == 0)
				itab[i].start = 1;
		}
		/* else: unchanged and running -- left strictly alone. */
	}
	endttyent();

	/* THE LINES START ONLY NOW, with the ttys stream closed, as 2.11BSD's
	 * merge() marks a line CHANGE inside its getttyent() loop and runs
	 * `term(p); dfork(p);' in a pass after endttyent()
	 * (usr/sbin/init/init.c:470-497).  A child forked inside the loop
	 * inherits the open stream on init's fd 0, then dup2()s its line over
	 * that fd, and anything in it that reads /etc/ttys -- ttyslot(), under
	 * login(3) -- rewinds the inherited stream and reads the terminal. */
	for (i = 0; i < nitab; i++)
		if (itab[i].start) {
			itab[i].start = 0;
			startline(i);
		}

	for (i = 0; i < nitab; i++) {
		if (itab[i].seen)
			continue;
		sprintf(cbuf, "init: %s: no longer enabled\n", itab[i].name);
		cmsg(cbuf);
		hangup(i);
		itab[i].disabled = 1;	/* a later HUP that re-lists it clears
					 * this and starts the line again */
	}
}

/* SIGTERM: orderly shutdown.  Say so BEFORE killing anything -- the console
 * line we are about to kill is the only thing that can show the message.  Then
 * stop respawning, kill the lines, and flush the filesystem; main() returns
 * straight after, and init returning with no parent is what halts the machine.
 * So halt(8) does not have to sync before it signals: this does it. */
static void
doshutdown()
{
	int i;

	cmsg("init: shutting down\n");
	for (i = 0; i < nitab; i++) {
		itab[i].disabled = 1;
		hangup(i);
	}
	/* 2.11BSD's shutdown() appends `~'/`shutdown' once the lines are down
	 * (usr/sbin/init/init.c:196-202), so last(1) can tell a clean shutdown
	 * from a crash. */
	logwtmp("~", "shutdown", "");
	sync();
}

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	int i, pid, running;
	long omask;

	/* /etc/rc first, waited on -- see the header.  fork+execve like the
	 * lines, so there is ONE process-creation shape in this file. */
	rcav[0] = a_rcsh;
	rcav[1] = a_rc;
	rcav[2] = a_auto;
	rcav[3] = (char *)0;
	ev[0] = e_path;
	ev[1] = e_home;
	ev[2] = (char *)0;
	pid = fork();
	if (pid == 0) {
		/* "/" on 0, 1 and 2: 2.11BSD runcom() (usr/sbin/init/init.c:
		 * 320-324).  init has no descriptors, so the open returns 0.
		 * /etc/rc sends what it wants seen to /dev/console itself. */
		i = open("/", 0);
		if (i > 0)
			dup2(i, 0);
		dup2(0, 1);
		dup2(0, 2);
		execve("/bin/sh", rcav, ev);
		_exit(1);
	}
	if (pid >= 0)
		while ((i = waitpid(pid, (int *)0, 0)) != pid && i >= 0)
			;	/* waitpid(pid,...) returns only pid or -1, so
				 * this spins at most once; it is a belt-and-
				 * braces guard, not an orphan drain. */

	/* AND THE MACHINE GOES SECURE, which is the other thing that changes
	 * when rc returns.  2.11BSD's multi_user() (usr/sbin/init/init.c:384):
	 *
	 *      if (getsecuritylevel() == 0)
	 *              setsecuritylevel(1);
	 *
	 * ONLY FROM ZERO, and that is the whole of the condition's job.  An
	 * administrator who wants the machine to stay open sets -1, and an
	 * /etc/rc that wants it tighter sets its own higher level; raising
	 * unconditionally would overwrite both.  Upstream's comment says so at
	 * the call site: "If the administrator has not set the security level
	 * to -1 ... and the run script has not set a higher level of security
	 * than level 1, then put the kernel into secure mode."
	 *
	 * WHAT IT BUYS, on FGX: the raw device of a mounted filesystem stops
	 * being writable, so fsck(8) run from a booted shell opens / read-only
	 * and says (NO WRITE) instead of repairing a filesystem with daemons on
	 * it.  Before this line the gate in spec_open could never fire, which
	 * is the same shape apple/fgx#406 turned out to be -- so the two must
	 * stay together. */
	if (getsecuritylevel() == 0)
		setsecuritylevel(1);

	/* Installed only now, after rc: a shutdown request arriving DURING
	 * /etc/rc takes SIGTERM's default action (terminate init, kernel
	 * halts), which is the right answer for a machine that has not
	 * finished coming up and is what happened before handlers existed. */
	signal(SIGTERM, onterm);
	signal(SIGHUP, onhup);

	/* /etc/utmp STARTS EMPTY at every boot -- 2.11BSD init.c:151's
	 * `close(creat(utmpf, 0644))'.  A crash leaves the previous boot's
	 * sessions in the file, and who(1) would list them as logged in until
	 * each line happened to be reused. */
	close(creat(_PATH_UTMP, 0644));

	/* THE WTMP BOOT RECORD, when accounting is on.  2.11BSD init writes a
	 * `~'/reboot entry here; last(1) prints it as a system boot and ac(8)
	 * reads ut_line[0] == '~' as the instant every still-open session ended.
	 * O_APPEND with no O_CREAT is login(3)'s own switch (libc utmp.c): the
	 * record lands iff /etc/wtmp already exists, so init never enables
	 * accounting that removing the file turned off.  And wtmp, unlike utmp
	 * just above, is NOT truncated -- it is the history that outlives the
	 * boot, which is the whole point of the file. */
	logwtmp("~", "reboot", "");

	readttys();
	if (nitab == 0) {
		cmsg("init: no lines are 'on' in /etc/ttys\n");
		return 0;	/* no parent: kernel halts */
	}
	for (i = 0; i < nitab; i++)
		startline(i);

	for (;;) {
		/* SIGNALS BEFORE THE WAIT, not after it.  A signal delivered at
		 * the exit of a syscall down inside startline() -- spawnve,
		 * spawnx, printf -- sets its flag and CLEARS the kernel's
		 * pending bit, so by the time we reach wait() there is nothing
		 * left to make it return EINTR.  Testing the flags only after
		 * wait() therefore parked init on a wait that nothing was going
		 * to interrupt, and the shutdown or re-read waited for whenever
		 * a child happened to die next: `kill -TERM 1` landing in a
		 * respawn window hung the machine.  Checked here, the flag is
		 * seen on the next trip round the loop no matter which syscall
		 * the delivery landed on. */
		if (gotterm)
			break;		/* doshutdown() after the loop */
		if (gothup) {
			gothup = 0;
			/* SIGTERM IS HELD FOR THE WHOLE MERGE, as 2.11BSD's
			 * handler vector says: `struct sigvec mvec = { merge,
			 * sigmask(SIGTERM), 0 };' (usr/sbin/init/init.c:366).
			 * A shutdown that began part-way through would hang up
			 * a line whose child rereadttys() has just started
			 * before that child could report. */
			omask = sigblock(sigmask(SIGTERM));
			rereadttys();
			sigsetmask(omask);
			continue;	/* MUST loop, not fall into wait(): the
					 * held SIGTERM is delivered as the mask
					 * drops -- flag set, pending bit
					 * cleared -- and a wait() reached in
					 * the same pass would block on a signal
					 * that no longer exists to interrupt
					 * it. */
		}

		pid = wait((int *)0);
		if (pid < 0 && errno != EINTR)
			break;		/* ECHILD: nothing left to keep */

		if (pid > 0) {
			for (i = 0; i < nitab; i++)
				if (itab[i].pid == pid) {
					itab[i].pid = 0;
					/* 2.11BSD's `rmut(p); dfork(p);' -- the
					 * record is blanked BEFORE the respawn,
					 * which for the console then writes a
					 * fresh one. */
					if (logout(itab[i].name))
						logwtmp(itab[i].name, "", "");
					startline(i);
					break;
				}
			/* No match: a reparented orphan.  Reaped, not respawned. */
		}

		/* Every line disabled by the throttle means wait() would
		 * block forever on nothing.  Stop instead of hanging. */
		running = 0;
		for (i = 0; i < nitab; i++)
			if (itab[i].pid != 0)
				running++;
		if (running == 0)
			break;
	}
	/* Reached by the gotterm break above, and also by the ECHILD and
	 * nothing-left exits -- a SIGTERM that arrived just as the last line
	 * died still gets its orderly shutdown rather than being dropped on
	 * the way out. */
	if (gotterm)
		doshutdown();
	return 0;			/* no parent: kernel halts */
}
