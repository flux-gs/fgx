/* ptyshell - pty P4 closed loop: a REAL /bin/sh driven over a pty.
 * telnetd's session shape, network aside.
 *
 * FGX-Provenance: none.  A test fixture with no upstream: 2.11BSD drives its
 * pty tests from scripts and has nothing shaped like this.  The tty.c line it
 * quotes below is cited, not derived.
 *
 * IT NAMED /bin/jsh, AND jsh WAS DELETED ON 2026-07-29 (tools/ninja/manifest
 * .json records the removal: bsh is /bin/sh and tcsh is the interactive
 * shell).  So this fixture answered `PS1 FAIL spawn e=2' on every tree that
 * had one -- and nothing ran it, because it has no manifest of its own and is
 * cited only in nottykey.json's prose.  Repointed at /bin/sh, which is the
 * 2.11BSD Bourne shell and syncs on its own `# ' prompt.
 *
 * Opens /dev/ptyp0 (master) and spawns the shell on /dev/ttyp0 (slave) via
 * the LEGACY registry, and apple/fgx#310 is why it is still spelled that way.
 * Moved to /dev and measured 2026-09-03: open, FIONBIO, spawnx and the first
 * prompt all work through the real vnode, and the drain after the first WRITE
 * blocks forever -- spec_read drops its ioflag for VCHR, so no device on that
 * road can be non-blocking.  Parked here rather than worked around.
 * spawnx file_actions {open slave -> child fd 3; dup2 3 onto 0,1,2; close 3}
 * -- the verified spawn-on-slave recipe -- so driving it over the master
 * exercises the whole stack: master write -> ttyinput at arrival -> cooked
 * line discipline (echo + CRMOD) -> the shell's read -> command runs -> the
 * shell's write -> t_outq + ONLCR -> master read.
 *
 * PS4 IS THE ONE THAT IS HARD TO GET FROM ANYWHERE ELSE.  A ^D at a fresh
 * prompt has to reach `ttread's `if (CCEQ(tp->t_eofc, c) && (t_flags&CBREAK)
 * == 0)' (2.11BSD usr/sys/sys/tty.c, ported at tty.c:1914) and come back as a
 * ZERO-BYTE read, which the shell sees as EOF: it exits, its slave fds close,
 * and the master reads EOF.  That is what a dropped connection looks like.
 * `logintest' LT9 asserts the same property but through TCSH, which puts the
 * line in CBREAK for its own editor -- so it stopped measuring the discipline
 * the moment the pty flip made CBREAK mean something (apple/fgx#249).  A
 * COOKED reader is what the kernel property needs.
 *
 * ptyshell SYNCHRONIZES on the shell's prompt: after each command it drains to
 * the next prompt (which appears only after the shell runs the command and
 * loops), so it never overruns it.
 *
 * The master is non-blocking + polled (the select idiom).  Prints PS<n> OK /
 * PTYSHELL PASS, or PS<n> FAIL and exit 1.
 */
#include <stdio.h>

int open(char *path, int flags);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);
int spawnx(char *path, char **argv, unsigned char *acts);
int nanosleep(int ticks);
int ioctl(int fd, int cmd, char *arg);
extern int errno;
#define FIONBIO 0x667E

unsigned char fa[48];   /* 6 records + terminator: DETACH, open, 3x dup2, close */
char mbuf[512];
char acc[4096];
int  acclen;

static int
count_in_acc(char *needle)
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

/* poll-read the non-blocking master into acc until count("# ") >= want (1),
 * EOF (2), or tries exhausted (0). */
static int
drain_to_prompts(int m, int want, int tries)
{
	int n, i, t;
	for (t = 0; t < tries; t++) {
		n = read(m, mbuf, sizeof mbuf);
		/* A ZERO READ BEFORE ANY BYTE HAS ARRIVED IS THE SLAVE NOT BEING
		 * OPEN YET, NOT END OF FILE, and upstream says so: ptcread
		 * returns 0 while TS_CARR_ON is clear, and carrier goes up in
		 * ptsopen -- 4.3BSD-Reno kern/tty_pty.c:301 and :98.  So the
		 * window between spawnx and the shell's own open(2) reads as EOF
		 * to any master, and a reader that gives up in it gives up on
		 * every session.  telnetd does not notice because it is in
		 * select(2); this has to notice for itself.
		 *
		 * AFTER a byte has arrived, a zero read IS end of file and still
		 * ends the drain -- which is what PS4 measures, through
		 * drain_to_eof below.  Only the opening window is forgiving.
		 *
		 * It never mattered while this ran through the registry, where the record-mode
		 * op answers differently in that window; it does on /dev, which
		 * is the road this now takes. */
		if (n == 0 && acclen == 0) { nanosleep(2); continue; }
		if (n == 0) return 2;
		if (n < 0) { nanosleep(2); continue; }
		for (i = 0; i < n; i++)
			if (acclen < (int)sizeof acc - 1)
				acc[acclen++] = mbuf[i];
		acc[acclen] = 0;
		if (count_in_acc("# ") >= want)
			return 1;
	}
	return 0;
}

static int
drain_to_eof(int m, int tries)
{
	int n, t;
	for (t = 0; t < tries; t++) {
		n = read(m, mbuf, sizeof mbuf);
		if (n == 0) return 1;
		if (n < 0) nanosleep(2);
	}
	return 0;
}

int
main()
{
	int m, k, poff, on;
	char *argv[2];         /* char ** since apple/fgx#302 */
	static char slavepath[] = "/dev/ttyp0";
	static char shpath[] = "/bin/sh";

	m = open("/dev/ptyp0", 2);
	if (m < 0) { printf("PS1 FAIL master %d\n", m); return 1; }
	on = 1;
	ioctl(m, FIONBIO, (char *)&on);

	poff = (int)slavepath;
	k = 0;
	/* DETACH FIRST: telnetd's TIOCNOTTY-then-open, in spawn's vocabulary
	 * (apple/fgx#60).  Now that spawn inherits the process group like fork
	 * does, a shell spawned from here would arrive already in THIS driver's
	 * group and ttyopen's `if (pp->p_pgrp == 0)` claim would never fire --
	 * the pty line would get no foreground group at all. */
	fa[k++] = 4; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0;
	fa[k++] = 1; fa[k++] = 3; fa[k++] = poff & 0xff; fa[k++] = (poff >> 8) & 0xff;
	fa[k++] = 2; fa[k++] = 0;
	fa[k++] = 3; fa[k++] = 0; fa[k++] = 3; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0;
	fa[k++] = 3; fa[k++] = 1; fa[k++] = 3; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0;
	fa[k++] = 3; fa[k++] = 2; fa[k++] = 3; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0;
	fa[k++] = 2; fa[k++] = 3; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0; fa[k++] = 0;
	fa[k++] = 0;

	argv[0] = shpath;
	argv[1] = (char *)0;
	if (spawnx(shpath, argv, fa) < 0) { printf("PS1 FAIL spawn e=%d\n", errno); return 1; }

	acclen = 0; acc[0] = 0;
	if (drain_to_prompts(m, 1, 800) != 1) { printf("PS1 FAIL no-prompt\n"); return 1; }
	printf("PS1 OK\n");

	/* PS2: run echo; sync to the 2nd prompt (proves the shell ran it and
	 * looped), then confirm the output token is present. */
	write(m, "echo PTYOK\r", 11);
	if (drain_to_prompts(m, 2, 800) != 1) { printf("PS2 FAIL no-prompt2\n"); return 1; }
	if (count_in_acc("PTYOK") < 1) { printf("PS2 FAIL no-out\n"); return 1; }
	printf("PS2 OK\n");

	/* PS3: a second command; sync to the 3rd prompt */
	write(m, "echo SECOND\r", 12);
	if (drain_to_prompts(m, 3, 800) != 1) { printf("PS3 FAIL no-prompt3\n"); return 1; }
	if (count_in_acc("SECOND") < 1) { printf("PS3 FAIL no-out\n"); return 1; }
	printf("PS3 OK\n");

	/* PS4: ^D at a fresh prompt -> the shell EOFs and exits -> master read
	 * EOF.  No CR after it: ^D is a line terminator in its own right. */
	write(m, "\004", 1);
	if (drain_to_eof(m, 800) != 1) { printf("PS4 FAIL no-eof\n"); return 1; }
	printf("PS4 OK\n");

	close(m);
	printf("PTYSHELL PASS\n");
	return 0;
}
