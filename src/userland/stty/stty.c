/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD stty(1)
 *   Ported from stty(1), 2.11BSD (stty.c 5.4.3 1997/5/7; Berkeley).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * stty - set and report terminal modes.
 *
 * Scoped to FGX's tty ABI, which is the old-style sgttyb + tchars + winsize
 * surface the kernel exposes via SYS_IOCTL:
 *
 *   TIOCGETP/TIOCSETN   struct sgttyb   speed, erase, kill, sg_flags
 *   TIOCGETC/TIOCSETC   struct tchars   intr, quit, start, stop, eof, brk
 *   TIOCGWINSZ          struct winsize  rows, columns (PER-TTY since #150)
 *
 * The 2.11BSD stty also drives BSD tty subsystems FGX's console does not have
 * -- line disciplines (TIOCGETD/SETD), ltchars (TIOCGLTC/SLTC:
 * susp/dsusp/rprnt/flush/werase/lnext), modem state (TIOCMGET/MSET),
 * TIOCFLUSH, TIOCHPCL -- and parity (EVENP/ODDP), for which sg_flags has no
 * bits.  Those args are omitted; see stty(1) NOTES.
 *
 * LOCAL MODES ARE IN, and they used to be on the list above.  That line was
 * true when it was written and the tty campaign made it false: apple/fgx#108
 * gave the kernel TIOCLGET/TIOCLSET/TIOCLBIS over the high half of t_flags
 * (src/kernel/tty/tty.c), and the bits themselves are 2.11BSD's, so the whole
 * `lmodes' table below ports straight across.
 *
 * WHY IT MATTERS, and it is not hypothetical: `ctlecho' is what renders a
 * typed control character as `^X'.  Without it `ttyecho' emits the raw byte
 * and the console shows nothing for a `^C' -- which read as a missing echo
 * until the live 2.11BSD oracle was asked and answered `crt: (... ctlecho)'.
 * Its own /.login turns the bit on with `stty dec' (upstream stty.c:264 ORs
 * LCRTBS|LCTLECH|LDECCTQ), because `login' clears every local mode on the way
 * in (login.c:157-158) whatever getty set from gettytab's `xc'.  So a BSD line
 * shows `^C' because a DOTFILE asks for it, and FGX could not ask.  Now it
 * can, by the same words.
 *
 * The window size is REPORTED but not settable HERE.  It used to be fixed --
 * every line answered the console's viewport and TIOCSWINSZ did not exist --
 * which is no longer true (apple/fgx#150): each tty carries its own size, a pty
 * tracks whatever its far end reports over telnet NAWS, and setting one signals
 * SIGWINCH to the line's foreground group.  So `stty' printing "N rows, M
 * columns" inside a remote session is a live reading of that session's
 * geometry, and a useful way to see whether a client's size actually arrived.
 * Adding `rows'/`cols' ARGUMENTS is a separate piece of work.
 *
 * The sgttyb fields are `short' on FGX (that image is still all-short); the
 * tchars fields became `char' at T3 stage 2b, matching 2.11BSD, so
 * the special-char table holds `short *' -- writing a char through a `short *'
 * would leave the high byte of the kernel image untouched.
 */
#include <stdio.h>
#include <sys/ioctl.h>
#include <sgtty.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>

/* sg_ispeed/sg_ospeed baud CODE (0..15) -> baud rate, for display. */
unsigned	speed[] = {
	0,50,75,110,134,150,200,300,600,1200,1800,2400,4800,9600,19200,38400
};

/* name -> baud code, for `stty 9600' etc.  Codes are the 2.11BSD B* values
 * (the kernel boots the console at code 13 = B9600). */
struct {
	char	*string;
	int	code;
} speeds[] = {
	"0",0, "50",1, "75",2, "110",3, "134",4, "134.5",4, "150",5, "200",6,
	"300",7, "600",8, "1200",9, "1800",10, "2400",11, "4800",12, "9600",13,
	"19200",14, "38400",15, 0,0
};

struct	MODES {
	char	*string;
	int	set;
	int	reset;
};

/* sg_flags set/reset pairs.  No even/odd: FGX sg_flags has no parity bits. */
struct	MODES	modes[] = {
	"raw",		RAW, 0,
	"-raw",		0, RAW,
	"cooked",	0, RAW,
	"-nl",		CRMOD, 0,
	"nl",		0, CRMOD,
	"echo",		ECHO, 0,
	"-echo",	0, ECHO,
	"-tabs",	XTABS, 0,
	"tabs",		0, XTABS,
	"tandem",	TANDEM, 0,
	"-tandem",	0, TANDEM,
	"cbreak",	CBREAK, 0,
	"-cbreak",	0, CBREAK,
	0, 0, 0
};

/* LOCAL-mode set/reset pairs -- the high half of t_flags, reached through
 * TIOCLGET/TIOCLSET rather than TIOCGETP/TIOCSETN.  Upstream's own table
 * (2.11BSD stty.c:84-115), minus the rows whose bits FGX's kernel does not
 * act on.  The reset columns are upstream's too: `crtbs' clears `prterase'
 * and vice versa, because a terminal cannot both wipe and bracket an erase.
 *
 * LFLUSHO AND LPENDIN ARE OMITTED because they are STATE, not settings, and
 * this table is both the setter and the `-a' display: a row here is a word the
 * user can type.  The kernel owns both bits -- ttyecho clears FLUSHO on every
 * echo and ttypend consumes PENDIN -- so a typed value would be overwritten
 * before it could be read back, which is worse than not offering it.
 * (Upstream lists them, because upstream's display is a separate macro from
 * its table.  The divergence is in what `-a' prints, not in what it means.) */
struct	MODES	lmodes[] = {
	"crtbs",	LCRTBS, LPRTERA,
	"-crtbs",	0, LCRTBS,
	"prterase",	LPRTERA, LCRTBS+LCRTKIL+LCRTERA,
	"-prterase",	0, LPRTERA,
	"crterase",	LCRTERA, LPRTERA,
	"-crterase",	0, LCRTERA,
	"crtkill",	LCRTKIL, LPRTERA,
	"-crtkill",	0, LCRTKIL,
	"ctlecho",	LCTLECH, 0,
	"-ctlecho",	0, LCTLECH,
	"litout",	LLITOUT, 0,
	"-litout",	0, LLITOUT,
	"pass8",	LPASS8, 0,
	"-pass8",	0, LPASS8,
	"tostop",	LTOSTOP, 0,
	"-tostop",	0, LTOSTOP,
	"mdmbuf",	LMDMBUF, 0,
	"-mdmbuf",	0, LMDMBUF,
	"nohang",	LNOHANG, 0,
	"-nohang",	0, LNOHANG,
	"rtscts",	LRTSCTS, 0,
	"-rtscts",	0, LRTSCTS,
	"decctlq",	LDECCTQ, 0,
	"-decctlq",	0, LDECCTQ,
	"noflsh",	LNOFLSH, 0,
	"-noflsh",	0, LNOFLSH,
	0, 0, 0
};

struct	sgttyb	mode;
struct	tchars	tc;
struct	winsize	win;
int	lmode;			/* the local-mode word, TIOCLGET/TIOCLSET */

/* the settable special characters that FGX has (sgttyb erase/kill + tchars).
 * ltchars (susp/dsusp/rprnt/flush/werase/lnext) are omitted -- no FGX struct.
 * `cp' points at a CHAR field of `mode' or `tc'; the table is wired up at
 * runtime (init_special) rather than with static `&mode.sg_erase' initializers,
 * which fcc does not fold as address constants.
 *
 * IT WAS `short *' AND THAT WAS A LATENT DEFECT FROM apple/fgx#108 T3 STAGE 2b
 * (apple/fgx#228).  2b made `struct tchars' six `char's, so the six `&tc.*'
 * entries below already pointed at one-byte fields through a two-byte pointer.
 * The READS survived by accident -- `*sp->cp & 0xff' takes the low byte of a
 * 16-bit load, which on this machine IS the byte wanted -- but every WRITE
 * stored two bytes and clobbered the character in the next slot, so
 * `stty intr ^C' silently overwrote `quit'.  Stage 2d makes the sgttyb pair
 * `char' as well, so all eight are one type again and the pointer matches. */
struct	special {
	char	*name;
	char	*cp;		/* every settable special is a char (ioctl.h) */
} special[9];

int	init_special()
{
	special[0].name = "erase";  special[0].cp = &mode.sg_erase;
	special[1].name = "kill";   special[1].cp = &mode.sg_kill;
	special[2].name = "intr";   special[2].cp = &tc.t_intrc;
	special[3].name = "quit";   special[3].cp = &tc.t_quitc;
	special[4].name = "start";  special[4].cp = &tc.t_startc;
	special[5].name = "stop";   special[5].cp = &tc.t_stopc;
	special[6].name = "eof";    special[6].cp = &tc.t_eofc;
	special[7].name = "brk";    special[7].cp = &tc.t_brkc;
	special[8].name = 0;        special[8].cp = 0;
	return (0);
}

char	*arg;
char	*Nfmt = "%-8s";
int	tty = 1;		/* fd operated on (1, or the -f file) */

int	eq(string)
	char	*string;
{
	if (!arg)
		return (0);
	if (strcmp(arg, string))
		return (0);
	arg = 0;
	return (1);
}

/* render a special char as ^X / M-x / ^? / <undef>, 2.11BSD-style. */
int	pit(sp)
	struct special *sp;
{
	int	c = *sp->cp & 0xff;
	char	junk[6];
	char	*p = junk;

	if (c == 0xff) {
		fprintf(stderr, Nfmt, "<undef>");
		return (0);
	}
	if (c & 0200) {
		*p++ = 'M';
		*p++ = '-';
		c &= ~0200;
	}
	if (c == 0177) {
		*p++ = '^';
		*p++ = '?';
	} else if (c < ' ') {
		*p++ = '^';
		*p++ = c + '@';
	} else
		*p++ = c;
	*p++ = '\0';
	fprintf(stderr, Nfmt, junk);
	return (0);
}

int	prmodes(all)
	int	all;		/* 0 short display, !0 long display */
{
	int	m, i;
	struct	special *sp;

	if (mode.sg_ispeed != mode.sg_ospeed) {
		fprintf(stderr, "input speed %u baud, ", speed[mode.sg_ispeed & 017]);
		fprintf(stderr, "output speed %u baud", speed[mode.sg_ospeed & 017]);
	} else
		fprintf(stderr, "speed %u baud", speed[mode.sg_ispeed & 017]);
	if (all)
		fprintf(stderr, ", %d rows, %d columns", win.ws_row, win.ws_col);
	fprintf(stderr, all ? "\n" : "; ");

	m = mode.sg_flags;
	if (all || (m & RAW))
		fprintf(stderr, "-raw " + ((m & RAW) != 0));
	if (all || (m & CRMOD) == 0)
		fprintf(stderr, "-nl " + ((m & CRMOD) == 0));
	if (all || (m & ECHO) == 0)
		fprintf(stderr, "-echo " + ((m & ECHO) != 0));
	if (all || (m & TANDEM))
		fprintf(stderr, "-tandem " + ((m & TANDEM) != 0));
	fprintf(stderr, "-tabs " + ((m & XTABS) != XTABS));
	if (all || (m & CBREAK))
		fprintf(stderr, "-cbreak " + ((m & CBREAK) != 0));
	fputc('\n', stderr);

	/* The local modes, on their own line as upstream prints them.  ONLY THE
	 * POSITIVE ROWS ARE WALKED -- every bit has a `name'/`-name' pair in
	 * the table and printing both would list each mode twice; `set != 0'
	 * selects the positive one, and the leading `-' is then skipped or not
	 * by the same string-offset trick the sg_flags lines above use. */
	if (all) {
		for (i = 0; lmodes[i].string; i++)
			if (lmodes[i].set)
				fprintf(stderr, "-%s " + ((lmode & lmodes[i].set) != 0),
					lmodes[i].string);
		fputc('\n', stderr);
	}

	if (all) {
		for (i = 0, sp = special; sp->name; i++, sp++)
			fprintf(stderr, Nfmt, sp->name);
		fputc('\n', stderr);
		for (i = 0, sp = special; sp->name; i++, sp++)
			pit(sp);
		fputc('\n', stderr);
	}
	return (0);
}

int	main(argc, argv)
	int	argc;
	char	**argv;
{
	int	i, fmt = 0, ch, isdec;
	struct	special *sp;
	char	*arg2;

	opterr = 0;
	while (optind < argc &&
	       strspn(argv[optind], "-aef") == strlen(argv[optind]) &&
	       (ch = getopt(argc, argv, "aef:")) != EOF) {
		switch (ch) {
		case 'e':
		case 'a':
			fmt = 2;
			break;
		case 'f':
			tty = open(optarg, O_RDONLY);
			if (tty < 0) {
				perror(optarg);
				return (1);
			}
			break;
		default:
			goto args;
		}
	}
args:
	argc -= optind;
	argv += optind;

	ioctl(tty, TIOCGETP, &mode);
	ioctl(tty, TIOCGETC, &tc);
	ioctl(tty, TIOCGWINSZ, &win);
	ioctl(tty, TIOCLGET, &lmode);
	init_special();

	if (argc == 0) {
		prmodes(fmt);
		return (0);
	}
	arg = argv[0];
	if (argc == 1 && (!strcmp(arg, "everything") || !strcmp(arg, "all"))) {
		prmodes(2);
		return (0);
	}

	while (argc-- > 0) {
		arg = *argv++;
		for (sp = special; sp->name; sp++)
			if (eq(sp->name)) {
				if (argc-- == 0)
					goto done;
				arg2 = *argv++;
				if (strcmp(arg2, "undef") == 0)
					*sp->cp = -1;
				else if (*arg2 == '^') {
					arg2++;
					*sp->cp = (*arg2 == '?') ? 0177 : (*arg2 & 037);
				} else
					*sp->cp = *arg2;
				goto cont;
			}
		if (eq("size")) {
			printf("%d %d\n", win.ws_row, win.ws_col);
			return (0);
		}
		for (i = 0; speeds[i].string; i++)
			if (eq(speeds[i].string)) {
				mode.sg_ispeed = mode.sg_ospeed = speeds[i].code;
				goto cont;
			}
		if (eq("speed")) {
			for (i = 0; speeds[i].string; i++)
				if (mode.sg_ospeed == speeds[i].code) {
					printf("%s\n", speeds[i].string);
					return (0);
				}
			printf("unknown\n");
			return (1);
		}
		for (i = 0; modes[i].string; i++)
			if (eq(modes[i].string)) {
				mode.sg_flags &= ~modes[i].reset;
				mode.sg_flags |= modes[i].set;
				goto cont;
			}
		for (i = 0; lmodes[i].string; i++)
			if (eq(lmodes[i].string)) {
				lmode &= ~lmodes[i].reset;
				lmode |= lmodes[i].set;
				goto cont;
			}
		/* THE COMPOUNDS, and they are the reason this work was wanted:
		 * `dec' is what a 2.11BSD /.login runs, and it is the single
		 * word that turns `^C' into visible text.  Upstream's three
		 * arms verbatim (stty.c:235-270), less the TIOCSETD each also
		 * does -- FGX has one discipline and no TIOCSETD.
		 *
		 * The speed test is upstream's: the erase/kill wipe modes are
		 * only worth setting on a line fast enough to repaint, and at
		 * 9600 the console always is.  Kept as a test rather than
		 * folded flat, because a slow serial line reaches here too. */
		/* `eq' CONSUMES THE ARGUMENT -- it sets `arg = 0' on a match so
		 * the unknown-mode message below stays quiet -- so a second
		 * `eq("dec")' inside the arm always answers NO.  Written that
		 * way first, and `stty dec' silently behaved as `stty crt':
		 * ctlecho came on (it is in the shared part) while decctlq and
		 * the erase/kill/intr defaults did not, which `stty -a' showed
		 * as `-decctlq'.  Remember the answer before spending it. */
		isdec = (arg && strcmp(arg, "dec") == 0);
		if (eq("crt") || eq("newcrt") || eq("dec")) {
			lmode &= ~LPRTERA;
			lmode |= LCRTBS|LCTLECH;
			if (mode.sg_ospeed >= 9)		/* >= B1200 */
				lmode |= LCRTERA|LCRTKIL;
			if (isdec) {
				mode.sg_erase = 0177;
				mode.sg_kill = ('u' & 037);
				tc.t_intrc = ('c' & 037);
				lmode |= LDECCTQ;
			}
			goto cont;
		}
		if (arg)
			fprintf(stderr, "unknown mode: %s\n", arg);
cont:
		;
	}
done:
	ioctl(tty, TIOCSETN, &mode);
	ioctl(tty, TIOCSETC, &tc);
	ioctl(tty, TIOCLSET, &lmode);
	return (0);
}
