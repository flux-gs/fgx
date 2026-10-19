/* sgtty.h - old-style (2.11BSD) terminal modes for FGX C programs.
 *
 * The 6-byte struct sgttyb and the sg_flags bits a program manipulates via
 * gtty(2)/stty(2) (which wrap SYS_IOCTL TIOCGETP/TIOCSETP).  Matches 2.11BSD's
 * own <sys/ioctl.h> declaration byte for byte, which is what the tty bank's
 * `struct tty' is laid out for, so a faithful vi port compiles against it.
 *
 * Acted on by the FGX console line discipline: clearing ECHO + setting CBREAK
 * (or RAW) gives single-keystroke, unechoed input (vi visual mode); leaving
 * ECHO set gives echoed input.  CRMOD/XTABS/TANDEM round-trip but are inert on
 * the console today (reserved for a future serial line).
 */
#ifndef _SGTTY_H
#define _SGTTY_H

/* 2.11BSD <sgtty.h> pulls in <sys/ioctl.h> (the FIO/SIOC file and socket
 * ioctls live there); tools that include only <sgtty.h> expect them, e.g.
 * the Bourne /bin/sh main.c call ioctl(fb, FIOCLEX, 0). */
#include <sys/ioctl.h>

/* `char', NOT `short', AND THAT CHANGED AT apple/fgx#108 T3 stage 2d, for the
 * reason `struct tchars' next door changed at 2b.  The fields were short
 * because the KERNEL IMAGE was a 10-byte all-short record in `_ttyTable' -- and
 * that image is gone.  2.11BSD `usr/sys/h/ioctl.h:44-50' is four `char' plus
 * one `short' and always was; the tty bank matches it because the tty bank IS
 * the port; and `ttioctl' copies the five members one at a time
 * (`usr/sys/sys/tty.c:1554-1600'), so there is no image on either side any
 * more.  The old note said the fields "MUST STAY short ... fcc packs scalar
 * chars to 1 byte since 2026-07-06 (B-8), so modernizing these to char would
 * shrink the struct to 6 bytes and silently mismatch the kernel image" -- every
 * clause of which was true when written, including the arithmetic.  What
 * expired is the premise: it is the KERNEL that moved to 6 bytes.
 *
 * fcc's `char' is UNSIGNED -- measured, not assumed: every char load is
 * `LDA c / AND #$00FF'.  So a field set to -1 reads back as 255 and compares
 * equal to _POSIX_VDISABLE, and FGX does not inherit BSD's signed-char CCEQ
 * wrinkle.  K&R 2nd ed A.4.2 permits either: "the available range of values,
 * and especially whether the value is signed, is implementation-dependent".
 * Source-compatible for a vi port -- it only reads and writes these as small
 * integer values. */
struct sgttyb {
    char  sg_ispeed;      /* input speed  (baud code) */
    char  sg_ospeed;      /* output speed (baud code) */
    char  sg_erase;       /* erase character */
    char  sg_kill;        /* kill character */
    short sg_flags;       /* mode bits, below */
};

/* sg_flags bits (2.11BSD values). */
/* Baud-rate codes -- the sg_ispeed/sg_ospeed values, verbatim from 2.11BSD
 * `usr/sys/h/ttydev.h:17-31'.  The console boots at B9600 and stty(1) names
 * these codes in its own table.
 *
 * EXTA AND EXTB ARE NOT DEFINED, and the reason is not that they are exotic:
 * 2.11BSD gives codes 14 and 15 those names, and FGX's stty(1) speed table
 * gives them 19200 and 38400.  Defining upstream's names over FGX's meanings
 * would make `#ifdef EXTA' rows in a port compile and then say the wrong
 * thing, which is worse than the row being skipped. */
#define B0      0
#define B50     1
#define B75     2
#define B110    3
#define B134    4
#define B150    5
#define B200    6
#define B300    7
#define B600    8
#define B1200   9
#define B1800   10
#define B2400   11
#define B4800   12
#define B9600   13

#define TANDEM  0x0001    /* flow control (inert on console) */
#define CBREAK  0x0002    /* char-at-a-time, signals active */
#define LCASE   0x0004    /* map upper to lower case (inert) */
#define ECHO    0x0008    /* echo input */
#define CRMOD   0x0010    /* map CR->CR+LF on output (inert; console is CR) */
#define RAW     0x0020    /* char-at-a-time, no processing */
#define ODDP    0x0040    /* get/send odd parity (inert on console) */
#define EVENP   0x0080    /* get/send even parity (inert on console) */
#define ANYP    0x00C0    /* get any parity / send none (ODDP|EVENP) */
#define XTABS   0x0400    /* expand tabs on output (inert) */

/* ioctl(2) request codes (2.11BSD values; match include/loader.s).  A faithful
 * BSD port calls `ioctl(fd, TIOCGETP, &sgttyb)` directly (e.g. elvis curses.c)
 * rather than the gtty/stty wrappers; the kernel SYS_IOCTL handles these. */
#define TIOCGETP  0x7408      /* get tty sgttyb (== gtty) */
#define TIOCSETP  0x7409      /* set tty sgttyb, flush typeahead (== stty) */
#define TIOCSETN  0x740A      /* set tty sgttyb, no flush */

/* Old-style tty special characters (2.11BSD <sgtty.h>).  A BSD curses/vi port
 * (elvis) saves these, forces its own interrupt char, then restores on exit via
 * ioctl(fd, TIOCGETC/TIOCSETC, &tchars).
 *
 * `char', NOT `short', AND THAT CHANGED AT apple/fgx#108 T3 stage 2b.  These
 * used to be short "because the struct is 12 bytes matching the kernel image",
 * and that reason has gone: the kernel image WAS a 12-byte all-short array in
 * `_ttyTable' that FGX invented, and the tty bank's `ttys[].t_chars' replaced
 * it with upstream's own `struct ttychars' -- fourteen `char' members, one
 * byte each.  2.11BSD `usr/sys/h/ioctl.h:22-29' is six `char' and always was,
 * `ttioctl' bcopies `sizeof (struct tchars)' out of `&tp->t_intrc', and
 * `struct ltchars' below has been six packed bytes here all along.  So this is
 * the declaration catching up to the kernel it describes, and to BSD.
 *
 * Round-trip only today: the kernel stores and returns them so save/restore
 * works, but the console line discipline does not yet act on t_intrc (^C ->
 * SIGINT is a later signal-model step). */
struct tchars {
    char t_intrc;        /* interrupt character (^C) */
    char t_quitc;        /* quit character (^\) */
    char t_startc;       /* start-output character (^Q) */
    char t_stopc;        /* stop-output character (^S) */
    char t_eofc;         /* end-of-file character (^D) */
    char t_brkc;         /* input delimiter (like nl); -1 = undefined */
};

#define TIOCGETC  0x7412      /* get tty special chars (struct tchars) */
#define TIOCSETC  0x7411      /* set tty special chars (struct tchars) */

/* The line-discipline and queue commands, answered by the tty bank's ttioctl
 * since apple/fgx#108 T3 stage 2.  Values are the low 16 bits of 2.11BSD's
 * _IOxx encoding, which is the form the FGX cmd word carries -- the same
 * derivation as every command above, and they must keep matching
 * src/kernel/tty/tty.h's copy, which is what ttioctl switches on.
 *
 * The discipline NUMBERS are 2.11BSD's, read from `usr/sys/h/ioctl.h:221-225'
 * rather than remembered -- NTTYDISC is 2, not 1, because NETLDISC sits at 1
 * between them.  src/kernel/tty/tty_conf.c registers all five slots in that
 * order and tty_devinit binds every line as OTTYDISC. */
#define TIOCGETD  0x7400      /* get line discipline number */
#define TIOCSETD  0x7401      /* set line discipline number (ENXIO if unknown) */
#define TIOCHPCL  0x7402      /* hang up the line on last close */
#define TIOCEXCL  0x740D      /* set exclusive use: further opens EBUSY */
#define TIOCNXCL  0x740E      /* reset exclusive use */
#define TIOCSTOP  0x746F      /* stop output, as if ^S had been typed */
#define TIOCSTART 0x746E      /* restart output, as if ^Q had been typed */
#define TIOCOUTQ  0x7473      /* *arg = bytes still queued for output */
#define OTTYDISC  0           /* old, v7 std tty driver */
#define NETLDISC  1           /* line discipline for the berk net */
#define NTTYDISC  2           /* new tty discipline */
#define TABLDISC  3           /* tablet discipline */
#define SLIPDISC  4           /* serial IP discipline */

int gtty(int fd, struct sgttyb *p);   /* TIOCGETP: fill *p from the tty */
int stty(int fd, struct sgttyb *p);   /* TIOCSETP: apply *p to the tty */

/* BSD "local" special chars — TIOCGLTC/TIOCSLTC (telnet mode()/AO handling,
 * tcsh Rawmode()).  Implemented by the kernel since 2026-07-27 (per-tty
 * 6-byte packed image, round-trip only — the discipline does not yet act on
 * t_suspc).  NOTE the layout: unlike sgttyb/tchars (deliberately all-short),
 * this struct keeps its BSD shape of 6 chars, and fcc packs char members at
 * 1 byte, so sizeof == 6 and the kernel copies 6 bytes.  TIOCFLUSH and the
 * pty TIOCPKT packet mode remain unimplemented placeholders. */
struct ltchars {
    char t_suspc;    /* stop process signal (^Z)        */
    char t_dsuspc;   /* delayed stop process signal (^Y) */
    char t_rprntc;   /* reprint line (^R)               */
    char t_flushc;   /* flush output (^O)               */
    char t_werasc;   /* word erase (^W)                 */
    char t_lnextc;   /* literal next char (^V)          */
};
#define TIOCGLTC  0x7474      /* get local special chars (struct ltchars) */
#define TIOCSLTC  0x7475      /* set local special chars (struct ltchars) */
#define TIOCFLUSH 0x7410      /* flush tty input/output queues */
#define TIOCPKT   0x7470      /* pty master: packet mode (telnetd) */
/* TIOCNOTTY: give up the controlling terminal -- ctty becomes "none" AND the
 * caller's process group becomes 0.  2.11BSD tty_tty.c:57-62.  What a
 * session-creating daemon calls BEFORE opening the line it means to own, so
 * that ttyopen's `if (p_pgrp == 0)` claim fires for it; telnetd.c:266-271 is
 * the canonical sequence.  Takes no argument, and reads nothing from the fd:
 * BSD issues it on /dev/tty, FGX has no such node and accepts it on any tty
 * fd, which is the same operation.  A spawned child wanting this before its
 * own opens uses the FA_OP_DETACH file action instead -- spawn is a fused
 * fork+exec, so there is no other point at which the child can run code. */
#define TIOCNOTTY 0x7471
/* TIOCPKT status bits, `usr/sys/h/ioctl.h:202-208'.  The master reads one of
 * these ahead of any data whenever `pt_send' is non-zero.  FLUSHREAD and
 * FLUSHWRITE share their values with FREAD and FWRITE, which is not a
 * coincidence: `ptsstop' is handed the flush mask and ORs it straight into
 * `pt_send', and upstream's comment there is "note: FLUSHREAD and FLUSHWRITE
 * already ok". */
#define TIOCPKT_DATA      0x00
#define TIOCPKT_FLUSHREAD 0x01
#define TIOCPKT_FLUSHWRITE 0x02
#define TIOCPKT_STOP      0x04
#define TIOCPKT_START     0x08
#define TIOCPKT_NOSTOP    0x10
#define TIOCPKT_DOSTOP    0x20

/* BSD "local mode" word — TIOCLGET/TIOCLSET/TIOCLBIS/TIOCLBIC (2.11BSD
 * <sys/ioctl.h> "locals, from 127 down").  tcsh's editor (GSTTY path) reads
 * the local mode word, twiddles the CRT-erase / literal-out / flush bits, and
 * writes it back.  The L* bit values are the 2.11BSD 32-bit mode bits shifted
 * >>16 (the low half is the sgttyb flags); here they are the 16-bit local
 * word tcsh manipulates as an int.  Implemented by the kernel since
 * 2026-07-27 (per-tty 16-bit word; get/set/bis/bic all work).  This was NOT
 * a graceful degradation: Rawmode() hard-fails when TIOCLGET or TIOCGLTC
 * errors, and GetNextChar() turns that into a fabricated EOF, so interactive
 * tcsh printed "exit" and quit without ever issuing a read. */
#define TIOCLBIS  0x747F      /* bis (OR-in) local mode bits */
#define TIOCLBIC  0x747E      /* bic (clear) local mode bits */
#define TIOCLSET  0x747D      /* set entire local mode word */
#define TIOCLGET  0x747C      /* get local mode word */
#define LCRTBS    0x0001      /* backspacing for crt */
#define LPRTERA   0x0002      /* printing terminal '\ ... /' erase */
#define LCRTERA   0x0004      /* '\b \b' erase */
#define LMDMBUF   0x0010      /* start/stop output on carrier intr */
#define LLITOUT   0x0020      /* literal output */
#define LTOSTOP   0x0040      /* SIGTTOU on background output */
#define LFLUSHO   0x0080      /* output being flushed (state) */
#define LNOHANG   0x0100      /* no SIGHUP on carrier drop */
#define LRTSCTS   0x0200      /* RTS/CTS flow control */
#define LCRTKIL   0x0400      /* kill line with '\b \b' */
#define LPASS8    0x0800      /* pass all 8 bits in cbreak */
#define LCTLECH   0x1000      /* echo control chars as ^X */
#define LPENDIN   0x2000      /* rawq needs reread */
#define LDECCTQ   0x4000      /* only ^Q restarts after ^S */
#define LNOFLSH   0x8000      /* no output flush on signal */

/* Terminal process-group (job control) — TIOCGPGRP/TIOCSPGRP.  Kernel
 * job-control tty ownership is the same P2 work item. */
#define TIOCGPGRP 0x7477      /* get pgrp of controlling tty */
#define TIOCSPGRP 0x7476      /* set pgrp of controlling tty */

#endif /* _SGTTY_H */
