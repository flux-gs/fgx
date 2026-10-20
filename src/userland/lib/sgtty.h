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
#define TANDEM  0x0001    /* flow control (inert on console) */
#define CBREAK  0x0002    /* char-at-a-time, signals active */
#define ECHO    0x0008    /* echo input */
#define CRMOD   0x0010    /* map CR->CR+LF on output (inert; console is CR) */
#define RAW     0x0020    /* char-at-a-time, no processing */
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

int gtty(int fd, struct sgttyb *p);   /* TIOCGETP: fill *p from the tty */
int stty(int fd, struct sgttyb *p);   /* TIOCSETP: apply *p to the tty */

#endif /* _SGTTY_H */
