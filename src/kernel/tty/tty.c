/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/tty.c
 *   Ported from usr/sys/sys/tty.c, 2.11BSD.
 *   Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* tty.c -- the line discipline, in the TTY bank.
 *
 * Ported from 2.11BSD usr/sys/sys/tty.c: partab, ttyoutput, ttyopen,
 * ttylclose, ttread, ttwrite, ttyinput, ttypend, ttioctl, ttselect, ttstart
 * and ttymodem are here, and linesw[] (tty_conf.c) names them for OTTYDISC
 * and NTTYDISC.  What this bank cannot reach directly -- process state such
 * as the controlling tty and pgrp, gsignal, sleep/wakeup, uiomove/ureadc,
 * selwakeup, the driver's d_stop and ioctl -- it reaches through the kc_*
 * seams in kc_sys.s, declared below.
 *
 * spltty/splx are kc_spltty() and kc_splx() (ttyparam.h), with bodies in
 * kc_sys.s over the 65816's I flag, so the call sites keep upstream's text.
 *
 * AN UNBALANCED PAIR IS A HANG: nothing
 * lowers the mask on the way out and the heartbeat IS the VBL.
 * tools/check_spl_balance.py holds the rule.
 */

#include "ttyparam.h"
#include "clist.h"
#include "ttychars.h"
#include "tty.h"
#include "conf.h"        /* NTTYDISC -- ttyinput's discipline tests */
#include "../vfs/uio.h"  /* ttwrite walks the uio it is handed */

/* kc_panic -- halt, naming the failure.  kc_sys.s; the far bank's C declares
 * it the same way.  ttyrub's `default:' arm is its first caller in this bank. */
extern void kc_panic();

/* ttyrub reaches ttyretype before it is defined.  Declared rather than left
 * implicit for the reason clist.h gives beside nextc: K&R types an undeclared
 * function int, and this bank's warning for that shape is the one that catches
 * a far-pointer return being truncated.  Keeping the file warning-clean for
 * genuine cases means not adding a benign one. */
extern void ttyretype();

/* ttypend and ttyinput are MUTUALLY RECURSIVE: ttyinput calls ttypend when
 * PENDIN is set, and ttypend replays the queue back through ttyinput.  One of
 * them has to be declared ahead of the other for the same reason ttyretype is
 * above.  The recursion terminates because ttypend clears PENDIN before it
 * calls ttyinput at all. */
extern void ttyinput();

/* kc_cdioctl -- cdevsw[].d_ioctl, as this bank can reach it.  kc_sys.s.
 * Returns an errno, 0 on success, which is upstream's `== 0' convention. */
extern int kc_cdioctl();

/* SET/CLR/ISSET -- upstream defines these in tty.c itself, at :103-105.
 *
 * CARRIED ONLY NOW, WITH ttread, WHICH IS THEIR FIRST USER HERE.  The earlier
 * increments ported routines that upstream itself writes as bare `t_state &
 * TS_x', so importing three macros nothing used would have been noise; ttread
 * is where upstream starts spelling the same test through ISSET, and matching
 * its text is what keeps the next reader's diff against upstream empty.
 */
#define SET(t,f)    (t) |= (f)
#define CLR(t,f)    (t) &= ~(f)
#define ISSET(t,f)  ((t) & (f))

/* The clist watermarks, upstream's own values from tty.c:39-41.  VARIABLES
 * rather than #defines because that is what upstream makes them -- tty_pty.c
 * declares `extern int TTYHOG' -- and T4 ports that file. */
int TTYHOG = 255;
int TTYBLOCK = 128;
int TTYUNBLOCK = 64;

/* d_stop, as this bank reaches it.  kc_sys.s. */
extern void kc_cdstop();

/* kc_sleep -- BSD's sleep(chan, pri), as this bank reaches it.  kc_sys.s.
 * UNINTERRUPTIBLE; see there for why, and for the expiry on that. */
extern void kc_sleep();
/* kc_sleepi -- the INTERRUPTIBLE twin, T6 increment 4b.  Answers 1 when a
 * signal wants us and we did NOT sleep, 0 when we slept and were woken.
 * `ttread' waits at TTIPRI upstream (vendor/2.11BSD/usr/sys/sys/tty.c:1187),
 * TTIPRI 28 (h/tty.h) is above PZERO 25's threshold for PCATCH (h/param.h:38,
 * kern_synch.c:238) -- so THIS is the port and kc_sleep is the divergence. */
extern int kc_sleepi();

/* selwakeup and gsignal, as this bank reaches them.  kc_sys.s. */
extern void kc_selwakeup();
extern void kc_gsignal();

/* kc_wakeup and ttyoutput are used before their definition/declaration would
 * otherwise reach the call site.  Declared for the reason clist.h gives beside
 * its own block: both return int (kc_wakeup returns nothing anyone reads), so
 * this changes no code -- it keeps the file at ZERO implicit-declaration
 * warnings, which is what makes the next one worth reading. */
extern void kc_wakeup();
extern int  ttyoutput();
extern struct tty *tty_find();   /* tty_dev.c -- FGX's cdevsw[].d_ttys */

/* kc_cdttyidx -- a chardev index -> its TTY INDEX, negative if there is none.
 * kc_sys.s; tty_dev.c's tty_find is built on the same call.  ttyopen needs the
 * INDEX rather than the `struct tty *' it already holds, because that index is
 * what names the line to the core bank. */
extern int kc_cdttyidx();

/* kc_ttyopen -- ttyopen's session acquisition, as this bank reaches it.
 * kc_sys.s, and read the block comment there before changing ttyopen: it is
 * the ONE core predicate this file calls instead of porting. */
extern int kc_ttyopen();

/* bzero -- tty_dev.c.  The bank links no libc; see the comment there. */
extern void bzero();

/* scanc -- tty_dev.c, ported from 4.3BSD-Reno.  ttwrite's bulk-transfer scan. */
extern int scanc();

/* The per-process reads ttwrite's background gate needs.  kc_sys.s, and
 * far_shims.s argues why they are FIELD reads rather than one predicate call.
 * kc_curctty answers an INDEX where upstream compares `struct tty *', because
 * FGX keeps the controlling terminal as an index in SE_Flags. */
extern int kc_curpgrp();
extern int kc_curctty();
/* DECLARED, AND THE RETURN TYPE IS THE POINT.  An implicit declaration is
 * assumed int-returning, and fcc warns in as many words that "a far-pointer
 * return loses its bank" -- which for this one would hand `ttwrite' a buffer
 * address in whatever bank happened to be live.  apple/fgx#246. */
extern char *kc_ttobuf();       /* kc_sys.s -- &u.u_ttyobuf, per task */
extern int  kc_ttobufsz();      /* kc_sys.s -- U_TTYOBUF_LEN */
extern int kc_isvforked();
extern int kc_sigopted();

/* kc_pendsig -- `u.u_procp->p_sig', the WHOLE mask.  kc_sys.s.  LONG, and that
 * is a divergence from upstream's own declaration rather than a transcription
 * of it; ttycheckoutq's header is where the reason lives. */
extern long kc_pendsig();

/* kc_uid -- `u.u_uid'.  kc_spgok -- the WHOLE of TIOCSPGRP's ownership
 * conjunction, because the core owns pfind and inferior already.  kc_sys.s. */
extern int kc_uid();
extern int kc_spgok();

/* kc_lbolt -- `sleep((caddr_t)&lbolt, TTIPRI)'.  kc_sys.s. */
extern void kc_lbolt();

/* kc_uiomove -- uiomove in vfs.mod, two banks away.  kc_sys.s.  ttwrite is its
 * first caller in this file; the probes reached it directly before. */
extern int kc_uiomove();

/* kc_ureadc -- ureadc in vfs.mod, beside uiomove and reached the same way.
 * kc_sys.s.  ttread's one-character handoff to the reader. */
extern int kc_ureadc();

/* The output watermarks, upstream's own tables at tty.c:93-96, verbatim.
 * Indexed by the line's output speed through TTHIWAT/TTLOWAT in tty.h. */
short tthiwat[16] =
   { 100,100,100,100,100,100,100,200,200,400,400,400,650,650,1300,2000 };
short ttlowat[16] =
   {  30, 30, 30, 30, 30, 30, 30, 50, 50,120,120,120,125,125,125,125 };

/* The modem bit ttyblock and ttyunblock hand to the driver, upstream's
 * `static int rts = TIOCM_RTS' at tty.c:210.  Its ADDRESS is what goes to the
 * ioctl, so it has to be an object rather than a constant. */
static int rts = TIOCM_RTS;

/* partab -- character classes for the output routines.  If the low 6 bits are
 * zero the character needs no special processing on output.
 *
 * ALL 256 ENTRIES, though ttyoutput masks with 0177 and can only ever index
 * the first 128.  Upstream's own comment says the upper half exists "for the
 * sake of the tty output routines which use special vax instructions which
 * need a 256 character trt table", which reads like an invitation to drop it
 * on a 65816.  It is not: ttwrite indexes this table through scanc() with an
 * UNMASKED character (tty.c:1398), so a 128-entry table would be read past its
 * end by the very next increment.  128 bytes against 38 KB free in this bank
 * is not a trade worth a landmine.
 */
char partab[] = {
    0001,0201,0201,0001,0201,0001,0001,0201,
    0202,0004,0003,0201,0005,0206,0201,0001,
    0201,0001,0001,0201,0001,0201,0201,0001,
    0001,0201,0201,0001,0201,0001,0001,0201,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0000,0200,0200,0000,0200,0000,0000,0200,
    0000,0200,0200,0000,0200,0000,0000,0200,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0000,0200,0200,0000,0200,0000,0000,0200,
    0000,0200,0200,0000,0200,0000,0000,0200,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0000,0200,0200,0000,0200,0000,0000,0200,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0200,0000,0000,0200,0000,0200,0200,0000,
    0000,0200,0200,0000,0200,0000,0000,0201,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,
    0007,0007,0007,0007,0007,0007,0007,0007,};

/* ttyrubo's two strings.  UPSTREAM WRITES THEM AS A STRING LITERAL IN THE
 * CONDITIONAL -- `tp->t_flags&CRTERA ? "\b \b" : "\b"' -- and they are named
 * globals here for one reason: fcc puts a string literal in the DATA segment
 * and hands back its address, which is what the ternary then selects between,
 * and a `register char *' initialised from a ternary of two literals is a
 * shape with no fixture behind it.  Two globals and an if is the same object
 * code with a construct the compiler is known to get right. */
static char erasecrt[4] = { '\b', ' ', '\b', 0 };
static char erasebs[2]  = { '\b', 0 };

/* The special characters a freshly opened line starts with. */
struct ttychars ttydefaults = {
    CERASE, CKILL,  CINTR,  CQUIT,  CSTART, CSTOP,  CEOF,
    CBRK,   CSUSP,  CDSUSP, CRPRNT, CFLUSH, CWERASE, CLNEXT
};

/* ttychars -- give a line the default special characters. */
void
ttychars(tp)
    struct tty *tp;
{
    tp->t_chars = ttydefaults;
}

/* ttstart -- start output on the line.
 *
 * THE NULL TEST IS UPSTREAM'S AND ITS COMMENT CALLS IT A "kludge for pty",
 * which undersells it here: FGX's pty has no t_oproc at all and neither does
 * a tty that has not been opened, so this is the ordinary case rather than
 * the odd one.  Dropping the test is a JSL through a zero pointer.
 */
void
ttstart(tp)
    register struct tty *tp;
{
    if (tp->t_oproc)                    /* kludge for pty */
        (*tp->t_oproc)(tp);
}

/* ttrstrt -- restart output after a delay timeout.
 *
 * NO CALLER YET.  Upstream reaches it through timeout(), which FGX has no
 * equivalent of in this bank; it is carried with ttstart because it is
 * ttstart's other half and two lines are not worth a second increment.
 */
void
ttrstrt(tp)
    register struct tty *tp;
{
    tp->t_state &= ~TS_TIMEOUT;
    ttstart(tp);
}

/* nullmodem -- the default modem-control routine, for the disciplines that
 * have no opinion.  Returns its flag so a carrier drop can turn the device
 * off, which is what upstream's comment means by "return argument flag".
 */
int
nullmodem(tp, flag)
    register struct tty *tp;
    int flag;
{
    if (flag)
        tp->t_state |= TS_CARR_ON;
    else
        tp->t_state &= ~TS_CARR_ON;
    return (flag);
}

/* ttyout -- send a NUL-terminated string to a tty. */
void
ttyout(cp, tp)
    register char *cp;
    register struct tty *tp;
{
    register int c;

    while (c = *cp++)
        (void) ttyoutput(c, tp);
}

/* ttbreakc -- is c a line-break character for this tty?
 *
 * CCEQ, not a bare compare: a special character SET TO _POSIX_VDISABLE is
 * disabled, and comparing against it directly would make the disabling byte
 * itself a delimiter.  ttychars.h carries the macro for that reason.
 */
int
ttbreakc(c, tp)
    register int c;
    register struct tty *tp;
{
    return (c == '\n' || CCEQ(tp->t_eofc, c) || CCEQ(tp->t_brkc, c) ||
            c == '\r' && (tp->t_flags & CRMOD));
}

/* ttyrubo -- back the cursor over cnt characters, erasing them if the terminal
 * is a CRT that can.
 */
void
ttyrubo(tp, cnt)
    register struct tty *tp;
    register int cnt;
{
    register char *rubostring;

    rubostring = (tp->t_flags & CRTERA) ? erasecrt : erasebs;
    while (--cnt >= 0)
        ttyout(rubostring, tp);
}

/* ttyecho -- echo a typed character back to the terminal.
 *
 * THE FLUSHO CLEAR HAPPENS BEFORE THE ECHO TEST, and the order is upstream's
 * rather than incidental: typing anything ends an output flush, whether or not
 * the character itself is echoed.  A version that returned early on !ECHO
 * would leave a terminal in ^O flush that no keystroke could get out of.
 *
 * TS_CNTTB is the exception, and its own definition in tty.h says why --
 * "counting tab width; leave FLUSHO alone".  The width count echoes into
 * nowhere to measure a tab, so it must not disturb the flush state.
 */
void
ttyecho(c, tp)
    register int c;
    register struct tty *tp;
{
    register int c7;

    if ((tp->t_state & TS_CNTTB) == 0)
        tp->t_flags &= ~FLUSHO;
    if ((tp->t_flags & ECHO) == 0)
        return;
    c &= 0377;

    if (tp->t_flags & RAW) {
        (void) ttyoutput(c, tp);
        return;
    }
    if (c == '\r' && (tp->t_flags & CRMOD))
        c = '\n';
    c7 = (tp->t_flags & PASS8) == 0 ? c & 0177 : c;
    if (tp->t_flags & CTLECH) {
        if ((c7 <= 037 && c != '\t' && c != '\n') || c7 == 0177) {
            (void) ttyoutput('^', tp);
            if (c7 == 0177)
                c7 = '?';
            else
                c7 += 'A' - 1;
        }
    }
    (void) ttyoutput(c7, tp);
}

/* ttyoutput -- put a character on a tty's output queue, doing the output
 * translations the mode bits ask for.
 *
 * Returns -1 when the character was accepted, and the character itself when
 * the queue is full so the caller can retry it.  THAT INVERSION IS UPSTREAM'S
 * and it is worth naming because it reads backwards: -1 is success.
 *
 * The tab arm returns '\t' only when it put NOTHING, which happens when
 * b_to_q could not take a single space; a partial expansion still counts the
 * columns it managed and answers -1.
 */
int
ttyoutput(c, tp)
    register int c;
    register struct tty *tp;
{
    register int col;
    int s;

    if (tp->t_flags & (RAW|LITOUT)) {
        if (tp->t_flags & FLUSHO)
            return (-1);
        if (putc(c, &tp->t_outq))
            return (c);
        return (-1);
    }

    if ((tp->t_flags & PASS8) == 0)
        c &= 0177;

    /* Turn tabs to spaces as required. */
    if (c == '\t' && (tp->t_flags & XTABS)) {
        c = 8 - (tp->t_col & 7);
        if ((tp->t_flags & FLUSHO) == 0) {
            s = spltty();               /* don't interrupt tabs */
            c -= b_to_q("        ", c, &tp->t_outq);
            splx(s);
        }
        tp->t_col += c;
        return (c ? -1 : '\t');
    }

    /* Turn <nl> to <cr><lf> if desired. */
    if (c == '\n' && (tp->t_flags & CRMOD)) {
        if (putc('\r', &tp->t_outq))
            return (c);
    }
    if ((tp->t_flags & FLUSHO) == 0 && putc(c, &tp->t_outq))
        return (c);

    col = tp->t_col;
    switch (partab[c & 0177] & 077) {

    case ORDINARY:
        col++;
    case CONTROL:
        break;
    case BACKSPACE:
        if (col)
            col--;
        break;
    case NEWLINE:
    case RETURN:
        col = 0;
        break;
    case TAB:
        col = (col | 07) + 1;
        break;
    }
    tp->t_col = col;
    return (-1);
}


/* ttyrub -- rub out one echoed input character, c, as the user erases it.
 *
 * 2.11BSD usr/sys/sys/tty.c:1480.  The three arms are three kinds of terminal:
 * CRTBS backs the cursor over what was echoed, PRTERA brackets the erased text
 * in backslashes the way a printing terminal must, and the default just echoes
 * the erase character itself.
 *
 * THE `9th BIT' TEST IS UPSTREAM'S AND SO IS ITS COMMENT: t_rawq holds a quoted
 * tab or newline with bit 7 set, and this is the only place in the whole tty
 * subsystem that reads it.  Comparing against the bare character would rub out
 * one column for a quoted tab that was echoed as two.
 *
 * t_rocount IS THE REASON THIS CAN GIVE UP.  It counts how many characters of
 * the current line are still known to be on the screen; ttwrite zeroes it when
 * the program writes over the echo.  At zero the screen no longer matches the
 * queue, so there is nothing to back over and the only correct answer is to
 * retype the line -- which is what upstream's "Screwed by ttwrite" comment
 * means.  The same test guards the TAB arm, where a partially-consumed rawq
 * would replay the wrong width.
 */
void
ttyrub(c, tp)
    register int c;
    register struct tty *tp;
{
    register char *cp;
    int savecol;
    int s;

    if ((tp->t_flags & ECHO) == 0)
        return;
    tp->t_flags &= ~FLUSHO;
    c &= 0377;
    if (tp->t_flags & CRTBS) {
        if (tp->t_rocount == 0) {
            /* the screen no longer matches the queue -- start again */
            ttyretype(tp);
            return;
        }
        /* the ONLY place the quoted-character bit is tested */
        if (c == ('\t' | 0200) || c == ('\n' | 0200))
            ttyrubo(tp, 2);
        else
            switch (partab[c & 0177] & 0177) {

            case ORDINARY:
                ttyrubo(tp, 1);
                break;

            case VTAB:
            case BACKSPACE:
            case CONTROL:
            case RETURN:
                if (tp->t_flags & CTLECH)
                    ttyrubo(tp, 2);
                break;

            case TAB:
                if (tp->t_rocount < tp->t_rawq.c_cc) {
                    ttyretype(tp);
                    return;
                }
                s = spltty();
                savecol = tp->t_col;
                tp->t_state |= TS_CNTTB;
                tp->t_flags |= FLUSHO;
                tp->t_col = tp->t_rocol;
                /* Re-echo the line into nowhere -- TS_CNTTB and FLUSHO make
                 * ttyecho count columns without emitting -- to learn how wide
                 * this tab actually was. */
                for (cp = tp->t_rawq.c_cf; cp; cp = nextc(&tp->t_rawq, cp))
                    ttyecho(*cp, tp);
                tp->t_flags &= ~FLUSHO;
                tp->t_state &= ~TS_CNTTB;
                splx(s);
                /* savecol is now the tab's width */
                savecol -= tp->t_col;
                tp->t_col += savecol;
                if (savecol > 8)
                    savecol = 8;                /* overflow screw */
                while (--savecol >= 0)
                    (void) ttyoutput('\b', tp);
                break;

            default:
                /* t_flags names an erase mode partab cannot classify.  Upstream
                 * panics and so does this: rubbing out against a screen state
                 * the terminal does not have corrupts the line silently. */
                kc_panic("ttyrub");
            }
    } else if (tp->t_flags & PRTERA) {
        if ((tp->t_state & TS_ERASE) == 0) {
            (void) ttyoutput('\\', tp);
            tp->t_state |= TS_ERASE;
        }
        ttyecho(c, tp);
    } else
        ttyecho(tp->t_erase, tp);
    tp->t_rocount--;
}

/* ttyretype -- reprint the line being edited, when the echo on screen can no
 * longer be trusted to match the queue.
 *
 * 2.11BSD usr/sys/sys/tty.c:1590.  Upstream's comment "We assume c_cc has
 * already been checked" is about the CALLER: ttyrub only reaches here with a
 * line in progress.
 *
 * BOTH QUEUES, canq FIRST.  The characters already accepted into the canonical
 * queue come before the ones still raw, because that is the order the user
 * typed them; replaying rawq alone would print a line missing its own start.
 *
 * FGX PORTS THE NON-UCB_CLIST ARM.  Upstream carries two, selected by an ifdef:
 * the UCB one calls nextc(q, cp, &store) and reads the character out of the
 * store, the other calls nextc(q, cp) and dereferences cp.  T1 ported the
 * two-argument nextc (tty_subr.c:407), so this is the arm that matches the
 * clists this bank actually has.
 */
void
ttyretype(tp)
    register struct tty *tp;
{
    register char *cp;
    int s;

    if (tp->t_rprntc != _POSIX_VDISABLE)
        ttyecho(tp->t_rprntc, tp);
    (void) ttyoutput('\n', tp);
    s = spltty();
    for (cp = tp->t_canq.c_cf; cp; cp = nextc(&tp->t_canq, cp))
        ttyecho(*cp, tp);
    for (cp = tp->t_rawq.c_cf; cp; cp = nextc(&tp->t_rawq, cp))
        ttyecho(*cp, tp);
    tp->t_state &= ~TS_ERASE;
    splx(s);
    tp->t_rocount = tp->t_rawq.c_cc;
    tp->t_rocol = 0;
}

/* ttyblock -- ask the far end to stop sending, the input queue being full.
 *
 * 2.11BSD usr/sys/sys/tty.c:215.  Two independent ways to say stop, and a
 * terminal may have both, one or neither: TANDEM sends the stop character
 * in band, RTSCTS drops the RTS line out of band.
 *
 * THE THRESHOLD TEST HAS THREE CLAUSES AND ALL THREE MATTER.  Enough
 * characters queued, AND some of them actually available to a reader -- raw
 * or cbreak delivers immediately, cooked does not until a line is complete --
 * AND not already blocked.  Dropping the middle clause would throttle a user
 * halfway through a line they cannot yet be reading.
 *
 * FGX HAS NO cdevsw ARRAY, so the d_ioctl call is spelled kc_cdioctl; see
 * tty_dev.c for why, and kc_sys.s for what the shim does.  Upstream's fourth
 * argument is a `flag' both call sites pass 0 for and FGX's registry op takes
 * from elsewhere, so it is not forwarded.
 *
 * THE RTSCTS ARM CANNOT FIRE IN FGX TODAY and is carried anyway.  Nothing sets
 * RTSCTS -- there is no path from stty to that bit -- and no FGX character
 * device has modem-control lines, so the ioctl answers ENOTTY and the arm
 * declines. Both are the correct behaviour for a machine with no RTS to drop,
 * and neither is a reason to leave the arm out: the port carries what upstream
 * has, and the first serial line that wants hardware flow control finds this
 * already right rather than absent.
 */
void
ttyblock(tp)
    register struct tty *tp;
{
    register int total;

    total = tp->t_rawq.c_cc + tp->t_canq.c_cc;
    /* Block further input iff:
     * Current input > threshold AND input is available to user program
     */
    if (total >= TTYBLOCK &&
        ((tp->t_flags & (RAW|CBREAK)) || (tp->t_canq.c_cc > 0)) &&
        (tp->t_state & TS_TBLOCK) == 0) {
        /* TANDEM is the same as IXOFF for all intents and purposes.  Since we
         * could get called for either software or hardware flow control we
         * need to check the IXOFF bit. */
        if ((tp->t_flags & TANDEM) &&
            tp->t_stopc != _POSIX_VDISABLE &&
            putc(tp->t_stopc, &tp->t_outq) == 0) {
            tp->t_state |= TS_TBLOCK;
            ttstart(tp);
        }
        /* If queue is full, drop RTS to tell modem to stop sending us stuff */
        if ((tp->t_flags & RTSCTS) &&
            kc_cdioctl((int)tp->t_dev, TIOCMBIC, &rts) == 0) {
            tp->t_state |= TS_TBLOCK;
        }
    }
}

/* ttyunblock -- tell the far end it may send again.
 *
 * 2.11BSD usr/sys/sys/tty.c:252.  The mirror of ttyblock, and NOT its exact
 * inverse: it re-sends unconditionally rather than testing a watermark,
 * because the callers test the watermark for it (ttread at tty.c:1273 against
 * TTYUNBLOCK, ttyflush at :205 on TS_TBLOCK alone).
 *
 * UPSTREAM TAKES AN spl AND NEVER RESTORES IT, and it is carried verbatim.
 * That looks like a leak and is not one: `s' is assigned and never read, and
 * every one of the three call sites brackets the call itself -- ttyflush
 * (:206) inside its own spltty/splx pair, ttread (:1274) inside the pair at
 * :1272-1275, and ttyinput's path already at interrupt level.  4.3BSD-Reno has
 * no ttyunblock at all to compare against, and 2.11BSD's own ttyblock takes no
 * spl either, so the asymmetry is upstream's oversight rather than a design.
 * A dead store, not a missing restore.  FGX's spltty/splx are the empty macros
 * ttyparam.h defines, so it emits nothing today; the increment that makes them
 * real should find this note rather than rediscover the analysis.
 */
void
ttyunblock(tp)
    register struct tty *tp;
{
    register int s;

    s = spltty();
    if ((tp->t_flags & TANDEM) &&
        tp->t_startc != _POSIX_VDISABLE &&
        putc(tp->t_startc, &tp->t_outq) == 0) {
        tp->t_state &= ~TS_TBLOCK;
        ttstart(tp);
    }
    if ((tp->t_flags & RTSCTS) &&
        kc_cdioctl((int)tp->t_dev, TIOCMBIS, &rts) == 0) {
        tp->t_state &= ~TS_TBLOCK;
    }
    /* THE ONE LINE UPSTREAM DOES NOT HAVE, AND IT IS NOT A CORRECTION.
     *
     * `vendor/2.11BSD/usr/sys/sys/tty.c:252' opens `register int s = spltty()'
     * and simply falls off the end -- no `splx(s)' anywhere.  On the PDP-11
     * that is a harmless dead store: nothing after this routine needs the
     * priority back within this call, and the kernel drops to base priority on
     * its own at the syscall boundary.  It was carried verbatim for that
     * reason, and this file's provenance row still names that line.
     *
     * FGX's spl is the 65816's I flag (ttyparam.h, T6 increment 2), and it is
     * the SAME masking the scheduler already calls spl (sched.s `_sleep':
     * "re-test ... under SEI (spl)").  Nothing lowers it on the way out, so
     * falling off the end here leaves interrupts masked for good -- and the
     * heartbeat IS the VBL, so the quantum, `lbolt', the keyboard scan and the
     * tty signal latch all stop.  The machine does not crash, it goes quiet.
     *
     * Reachable rather than theoretical: `ttyflush' and `ttread' both call
     * this behind TS_TBLOCK, which `ttyblock' sets when the input queue fills.
     * Rare is worse, not better -- it is a hang that waits for load.
     *
     * `tools/check_spl_balance.py' holds the rule now, so the next one is a
     * build error rather than a quiet machine. */
    splx(s);
}

/* ttwakeup -- the input side became interesting; tell whoever is waiting.
 *
 * 2.11BSD usr/sys/sys/tty.c:1683.  Three audiences and they are independent:
 * a selector, an owner who asked for SIGIO, and an ordinary blocked reader.
 *
 * `wakeup(&t_rawq)' at the end is what an ordinary read(2) blocked on this line
 * is waiting for.  The TS_ASYNC arm is inert -- it comes from FIOASYNC, which
 * no FGX ioctl route sets -- and is carried so the increment that adds it finds
 * the wiring here.
 *
 * FGX DIVERGENCE: THE SELECTOR WAKE IS UNCONDITIONAL.  Upstream guards it with
 * `if (tp->t_rsel)' (tty.c:1687) and passes the registered proc to selwakeup,
 * which wakes THAT ONE task.  FGX's select(2) registers on nothing, so t_rsel
 * is never set and the guard would make this call dead code -- a tty could
 * never wake its own selector, and a select blocked on a pty or serial line
 * would move only on the 60 Hz idle re-scan in sched.s.
 *
 * DROPPING THE GUARD IS UPSTREAM'S OWN FALLBACK, NOT AN INVENTION.  BSD's
 * selwakeup takes `(p, coll)' and, when it cannot target one proc, does exactly
 * what FGX does always (sys_generic.c:511-514):
 *
 *     if (coll) {
 *             nselcoll++;
 *             wakeup((caddr_t)&selwait);
 *     }
 *
 * `coll' is set by `ttyselect' (tty.c:606), at its collision test on
 * tty.c:619-620, when a SECOND task selects on a tty that already has one
 * recorded -- one slot, two selectors, so it marks
 * TS_RCOLL and falls back to a broadcast plus a full rescan.  FGX has one
 * channel and no slot at all, which is that collision case permanently; and
 * select rescans after every wake either way, because BSD's select is itself a
 * poll-and-retry loop (`goto retry' after tsleep, sys_generic.c:431) and the
 * registration never carried readiness.
 *
 * IT IS NOT A WAKEUP STORM: _FarSh_SelWakeup tests `_nSelSleepers' first and
 * returns, so with nobody selecting this costs an LDA and a BEQ -- the same
 * guard sched.s:172 and :194 use at their own wake sites.
 *
 * ttyflush already spelled it this way, because upstream does too there: its
 * selwakeup call carries no `if' (tty.c:201), the NULL test living inside
 * selwakeup.  This makes the three call sites agree.
 */
void
ttwakeup(tp)
    register struct tty *tp;
{

    kc_selwakeup();                     /* FGX DIVERGENCE -- see the note above */
    tp->t_state &= ~TS_RCOLL;
    tp->t_rsel = 0;
    if (tp->t_state & TS_ASYNC)
        kc_gsignal(tp->t_pgrp, SIGIO);
    kc_wakeup(&tp->t_rawq);
}

/* ttyowake -- the output queue drained far enough; wake a blocked writer.
 *
 * 2.11BSD usr/sys/sys/tty.c:123.  The watermark is the whole point: a writer
 * is woken when the queue falls to TTLOWAT, not when it empties, so the line
 * keeps feeding rather than stalling between writes.  The mark is a function of
 * SPEED -- a 300-baud line wakes at 30 characters and a 19200 one at 125 --
 * which is why the tables are indexed rather than a constant.
 *
 * TS_ASLEEP IS CLEARED BEFORE THE WAKE, and the order is upstream's: the flag
 * says a writer is parked on t_outq, so leaving it set past the wakeup would
 * let the next drain wake a writer that is already running.
 *
 * The selector wake is unconditional here for the reason ttwakeup's is, and
 * upstream's guard (`if (tp->t_wsel)', tty.c:134) is dropped with it -- see the
 * divergence note there.  This is the write side: a select waiting to WRITE
 * wants waking when the queue drains to the low watermark, and nothing else in
 * FGX would tell it.
 */
void
ttyowake(tp)
    register struct tty *tp;
{

    if (tp->t_outq.c_cc <= TTLOWAT(tp)) {
        if (tp->t_state & TS_ASLEEP) {
            tp->t_state &= ~TS_ASLEEP;
            kc_wakeup(&tp->t_outq);
        }
        kc_selwakeup();                 /* FGX DIVERGENCE -- see ttwakeup */
        tp->t_wsel = 0;
        tp->t_state &= ~TS_WCOLL;
    }
}

/* ttyflush -- throw away what is queued, in one direction or both.
 *
 * 2.11BSD usr/sys/sys/tty.c:179.  The two halves are independent and a caller
 * may ask for either: ^C flushes input, a TIOCFLUSH may ask for both, and
 * ttywflush asks for input after waiting on output.
 *
 * THE OUTPUT HALF STOPS THE DEVICE BEFORE IT DRAINS THE QUEUE, and the order
 * is the point.  Emptying t_outq first would leave the driver still feeding
 * out whatever it had already taken, so the terminal would print characters
 * the flush was meant to discard.  kc_cdstop is FGX's d_stop; for every device
 * but the serial line it finds a zero slot and returns, which is upstream's
 * arrangement too -- 2.11BSD gives its own console `nulldev' there.
 *
 * TS_TTSTOP IS CLEARED BEFORE THE STOP, which reads backwards and is not: the
 * flag means "output is stopped and must not restart", and a flush ENDS that
 * state -- what is being discarded is exactly what was waiting for the restart.
 * Upstream clears it in the same order.
 *
 * THE TBLOCK RELEASE IS LAST AND IS GATED ON FREAD.  Flushing input is what
 * makes room, so a line that had been throttled with ^S can be released; a
 * write-only flush has changed nothing about the input queue and must not.
 */
void
ttyflush(tp, rw)
    register struct tty *tp;
    int rw;
{
    register int s;

    s = spltty();
    if (rw & FREAD) {
        while (getc(&tp->t_canq) >= 0)
            ;
        while (getc(&tp->t_rawq) >= 0)
            ;
        tp->t_rocount = 0;
        tp->t_rocol = 0;
        tp->t_state &= ~TS_LOCAL;
        ttwakeup(tp);
    }
    if (rw & FWRITE) {
        /* THE FLUSH HAS TO ANNOUNCE ITSELF, because on this port the output
         * "in flight" is a synchronous paint holding a pointer into the very
         * blocks the drain below frees.  Upstream announces it from the
         * driver: dzstop sets TS_FLUSH when it stops a busy line
         * (vendor/2.11BSD/usr/sys/pdpuba/dz.c:463-470) and dzxint then
         * test-and-clears instead of ndflushing what is already gone (:389-398).
         *
         * IT CANNOT LIVE IN d_stop HERE, and that is FGX's ABI rather than a
         * choice -- serial.s:325 states it for the one driver that has a
         * d_stop body: "a chardev op receives a MINOR, not a `struct tty *',
         * so it cannot set tty state".  kc_cdstop also DEFERS at interrupt
         * time -- see its own header in this bank -- which is when this arm
         * runs once the
         * receive interrupt drives ttyinput, so a driver-side set could not
         * beat the drain anyway.  So the discipline sets it, on the same test
         * dzstop uses.
         *
         * TS_TTSTOP IS UPSTREAM'S OTHER CONJUNCT and it is kept: a line
         * stopped by ^S has nothing in flight to disown, and tty_oproc
         * returns early on TS_TTSTOP without ever reaching its ndflush. */
        if ((tp->t_state & TS_BUSY) && (tp->t_state & TS_TTSTOP) == 0)
            tp->t_state |= TS_FLUSH;
        tp->t_state &= ~TS_TTSTOP;
        kc_cdstop((int)tp->t_dev, rw);
        kc_wakeup(&tp->t_outq);
        while (getc(&tp->t_outq) >= 0)
            ;
        kc_selwakeup();
        tp->t_state &= ~TS_WCOLL;
        tp->t_wsel = 0;
    }
    if (rw & FREAD && (tp->t_state & TS_TBLOCK))
        ttyunblock(tp);
    splx(s);
}

/* ttyclose -- clean the line on its LAST close.
 *
 * 2.11BSD usr/sys/sys/tty.c:695.  Three lines, and the third is the one that
 * matters: `t_state = 0' is a whole-word clear, not a mask, so every bit the
 * line was carrying goes at once -- TS_ISOPEN, TS_CARR_ON, the flow-control
 * state, the collision bits.  That is what makes the next open see a fresh
 * line rather than one still believing it has carrier.
 *
 * THE FLUSH COMES FIRST AND IT IS NOT INTERCHANGEABLE.  ttyflush reads
 * t_state (TS_TBLOCK for the unblock, TS_TTSTOP for the stop) and writes
 * t_wsel, so clearing the word first would leave it flushing a line whose
 * state said nothing was queued or throttled.
 *
 * t_pgrp IS CLEARED SEPARATELY because it is not in t_state: it is the process
 * group that owns the line, and leaving it set would aim the next hangup at a
 * group that no longer has this tty.
 */
void
ttyclose(tp)
    register struct tty *tp;
{

    ttyflush(tp, FREAD|FWRITE);
    tp->t_pgrp = 0;
    tp->t_state = 0;
}

/* ttymodem -- a carrier transition on the line.  Returns 0 if the line should
 * be turned off, 1 otherwise.
 *
 * 2.11BSD usr/sys/sys/tty.c:709.  The full counterpart of nullmodem above:
 * nullmodem records the carrier and returns it, ttymodem acts on it.  It is
 * the `l_modem' slot the real disciplines carry (tty_conf.c:22 declares the
 * two side by side), and tty_conf.c's adapter names it as its target.
 *
 * THREE ARMS, AND THE FIRST IS NOT THE ONE IT LOOKS LIKE.  MDMBUF makes
 * carrier itself the flow control -- carrier high starts output, carrier low
 * stops it -- so a modem that cannot keep up is throttled the way a ^S would
 * throttle it.  IT IS GATED ON TS_WOPEN BEING CLEAR: a line still waiting for
 * its open to complete has no output to pace, and treating the opening
 * transition as flow control would start output on a line nobody has yet.
 *
 * THE LOST-CARRIER ARM IS THE ONLY ONE THAT RETURNS 0, and only when the
 * line is open and NOHANG is clear.  It sends SIGHUP then SIGCONT -- see the
 * note in tty.h on why the pair travels together -- then flushes both queues,
 * because what is in them belongs to a session that has just ended.
 *
 * A CARRIER DROP ON A LINE THAT IS NOT OPEN FALLS THROUGH TO `return (1)'
 * having cleared TS_CARR_ON, which is upstream's arrangement and reads like an
 * omission until the callers are checked: returning 0 asks the DRIVER to turn
 * the line off, and there is nothing to turn off on a line no one opened.
 *
 * WHAT THIS DOES IN FGX TODAY IS STRUCTURE, NOT BEHAVIOUR, and honestly so:
 * no FGX character device has modem-control lines (the same reason ttyblock's
 * RTSCTS arm is inert), so nothing calls it with a real transition yet.  It is
 * ported because the linesw slot it fills is what T4's repoint needs to find
 * already here, not because a carrier can drop today.
 *
 * kc_cdstop is FGX's d_stop; as in ttyflush it finds a zero slot for every
 * device but the serial line, which is upstream's arrangement too.
 */
int
ttymodem(tp, flag)
    register struct tty *tp;
    int flag;
{

    if ((tp->t_state & TS_WOPEN) == 0 && (tp->t_flags & MDMBUF)) {
        /* MDMBUF: flow control follows the carrier flag. */
        if (flag) {
            tp->t_state &= ~TS_TTSTOP;
            ttstart(tp);
        } else if ((tp->t_state & TS_TTSTOP) == 0) {
            tp->t_state |= TS_TTSTOP;
            kc_cdstop((int)tp->t_dev, 0);
        }
    } else if (flag == 0) {
        /* Lost carrier. */
        tp->t_state &= ~TS_CARR_ON;
        if (tp->t_state & TS_ISOPEN) {
            if ((tp->t_flags & NOHANG) == 0) {
                kc_gsignal(tp->t_pgrp, SIGHUP);
                kc_gsignal(tp->t_pgrp, SIGCONT);
                ttyflush(tp, FREAD|FWRITE);
                return (0);
            }
        }
    } else {
        /* Carrier now on. */
        tp->t_state |= TS_CARR_ON;
        kc_wakeup(&tp->t_rawq);
    }
    return (1);
}

/* ttypend -- replay the raw queue through ttyinput after a mode switch.
 *
 * 2.11BSD usr/sys/sys/tty.c:768.  When a mode change arrives while characters
 * are already queued, those characters were interpreted under the OLD mode and
 * must be re-read under the new one.  PENDIN says that is owed; this pays it.
 *
 * THE QUEUE IS MOVED, NOT WALKED.  `tq = tp->t_rawq' takes the clist header by
 * VALUE and then empties the real one, so the replay reads from a private copy
 * and the ttyinput calls below re-queue into a rawq that starts empty.  Walking
 * the live queue instead would have ttyinput appending to the queue being read
 * -- the loop would never end.  That struct assignment is why this routine
 * needed apple/fgx#214 fixed before it could be ported.
 *
 * TS_TYPEN IS THE RE-ENTRY FLAG, and ttyinput reads it: while it is set,
 * ttyinput skips the `c &= 0177' that would strip the high bit a previous pass
 * added.  Without it a literal-next character would lose its marking on the
 * replay and be re-interpreted as the special character it was escaping.
 *
 * MUTUALLY RECURSIVE WITH ttyinput, which calls this on PENDIN.  The recursion
 * terminates because PENDIN is cleared FIRST, before any ttyinput call.
 */
void
ttypend(tp)
    register struct tty *tp;
{
    struct clist tq;
    register int c;

    tp->t_flags &= ~PENDIN;
    tp->t_state |= TS_TYPEN;
    tq = tp->t_rawq;
    tp->t_rawq.c_cc = 0;
    tp->t_rawq.c_cf = tp->t_rawq.c_cl = 0;
    while ((c = getc(&tq)) >= 0)
        ttyinput(c, tp);
    tp->t_state &= ~TS_TYPEN;
}

/* ttyinput -- a character has arrived; interpret it and queue it.
 *
 * 2.11BSD usr/sys/sys/tty.c:791.  The whole input half of the discipline, and
 * the routine every other one in this bank exists to serve: it is what calls
 * ttyrub, ttyretype, ttyecho, ttyblock, ttwakeup and ttyflush.
 *
 * IT IS A CASE STATEMENT WHOSE CASES ARE NOT CONSTANTS -- every arm compares
 * against a per-tty character out of t_chars -- so none of it can be a switch,
 * and upstream's gotos to `endcase' are how the arms converge.  They are
 * carried verbatim rather than restructured: the fall-through order IS the
 * precedence of the special characters, and rewriting it as nested ifs would
 * make that order implicit.
 *
 * THE ARMS, IN UPSTREAM'S ORDER, WHICH IS THE PRECEDENCE:
 *   literal-next, flush-output, suspend   (NTTYDISC only)
 *   stop/start                            (flow control, before signals)
 *   interrupt/quit                        (signals)
 *   CBREAK                                (no line editing below here)
 *   erase, kill                           (cooked-mode editing)
 *   word-erase, reprint                   (NTTYDISC only)
 *   overflow check, then the ordinary queue-and-echo
 *
 * ^S TWICE RESTARTS OUTPUT, and that is upstream's behaviour rather than a
 * transcription slip -- it was measured, and it made a probe assertion wrong
 * the first time this was ported.  The stop arm returns EARLY only when
 * TS_TTSTOP was clear; a line already stopped falls through to `endcase' and
 * on into `restartoutput', which clears the flag.  The only way to stop output
 * and keep it stopped is a stop character that differs from the start
 * character, which is what the DECCTQ test at `endcase' is about.
 *
 * `c &= 0377' THEN `c &= 0177' UNLESS TS_TYPEN OR PASS8.  The second mask is
 * skipped on a replay because ttypend is re-feeding characters this routine
 * may already have marked with 0200 for literal-next; see ttypend.
 *
 * THE LITERAL-NEXT ARM IS THE ONLY PLACE THAT ORs IN 0200, and it is kept,
 * WHICH DIVERGES FROM 2.11BSD PATCH 484.  The patch deletes this arm, the
 * strip before it and ttyrub's quoted-character test, and replaces them with
 * nothing: `t_lnextc' still sets TS_LNCH and no line reads it afterwards, so
 * upstream's ^V echoes `^\b' and quotes nothing.  4.3BSD-Reno keeps literal
 * next by quoting in a ninth bit, `TTY_QUOTE 0x100' (sys/tty.h:127), which
 * needs clists that store one; 2.11BSD's are eight bits wide.  So FGX keeps
 * the pre-484 input side and the cost that came with it upstream: a
 * character typed under PASS8 with its high bit set is a quoted character to
 * ttyrub.
 *
 * FGX DELTAS: `gsignal' is kc_gsignal over the core's _Kill_GroupFanout, and
 * `(*cdevsw[major(tp->t_dev)].d_stop)(tp, 0)' is kc_cdstop -- the same two
 * seams ttyflush and ttymodem already use.  The UCB_METER `tk_nin++' is
 * dropped, FGX having no tk_* counters.
 *
 * WHAT THIS DOES NOT DO YET: it runs in TASK CONTEXT, behind PENDIN, rather
 * than at character-arrival time.  Returning it to arrival time is T6, which
 * needs a second fcc register file; until then the ioctl-singleton hazard the
 * kc_cdioctl seam is written for cannot fire.
 */
void
ttyinput(c, tp)
    register int c;
    register struct tty *tp;
{
    long t_flags = tp->t_flags;
    int i;

    /* If input is pending take it first. */
    if (t_flags & PENDIN)
        ttypend(tp);
    c &= 0377;

    /* In tandem mode, check high water mark. */
    if (t_flags & (TANDEM|RTSCTS))
        ttyblock(tp);

    if (t_flags & RAW) {
        /* Raw mode: queue the character with no interpretation. */
        if (tp->t_rawq.c_cc > TTYHOG)
            ttyflush(tp, FREAD|FWRITE);
        else {
            if (putc(c, &tp->t_rawq) == 0)
                ttwakeup(tp);
            ttyecho(c, tp);
        }
        goto endcase;
    }

    /* Ignore any high bit added during previous ttyinput processing. */
    if ((tp->t_state & TS_TYPEN) == 0 && (t_flags & PASS8) == 0)
        c &= 0177;

    /* Literal next, checked before anything else: flag the character so it
     * matches none of the special characters below. */
    if (tp->t_state & TS_LNCH) {
        c |= 0200;
        tp->t_state &= ~TS_LNCH;
    }

    if (tp->t_line == NTTYDISC) {
        if (CCEQ(tp->t_lnextc, c)) {
            if (t_flags & ECHO)
                ttyout("^\b", tp);
            tp->t_state |= TS_LNCH;
            goto endcase;
        }
        if (CCEQ(tp->t_flushc, c)) {
            if (t_flags & FLUSHO)
                tp->t_flags &= ~FLUSHO;
            else {
                ttyflush(tp, FWRITE);
                ttyecho(c, tp);
                if (tp->t_rawq.c_cc + tp->t_canq.c_cc)
                    ttyretype(tp);
                tp->t_flags |= FLUSHO;
            }
            goto startoutput;
        }
        if (CCEQ(tp->t_suspc, c)) {
            if ((t_flags & NOFLSH) == 0)
                ttyflush(tp, FREAD);
            ttyecho(c, tp);
            kc_gsignal(tp->t_pgrp, SIGTSTP);
            goto endcase;
        }
    }

    /* Start/stop characters. */
    if (CCEQ(tp->t_stopc, c)) {
        if ((tp->t_state & TS_TTSTOP) == 0) {
            tp->t_state |= TS_TTSTOP;
            kc_cdstop((int)tp->t_dev, 0);
            return;
        }
        if (CCEQ(tp->t_startc, c))
            return;
        goto endcase;
    }
    if (CCEQ(tp->t_startc, c))
        goto restartoutput;

    /* Interrupt/quit. */
    if (CCEQ(tp->t_intrc, c) || CCEQ(tp->t_quitc, c)) {
        if ((t_flags & NOFLSH) == 0)
            ttyflush(tp, FREAD|FWRITE);
        ttyecho(c, tp);
        kc_gsignal(tp->t_pgrp, CCEQ(tp->t_intrc, c) ? SIGINT : SIGQUIT);
        goto endcase;
    }

    /* Cbreak mode: no line editing; check the high water mark for wakeup. */
    if (t_flags & CBREAK) {
        if (tp->t_rawq.c_cc > TTYHOG) {
            if (tp->t_outq.c_cc < TTHIWAT(tp) &&
                tp->t_line == NTTYDISC)
                (void) ttyoutput(CTRL(g), tp);
        } else if (putc(c, &tp->t_rawq) == 0) {
            ttwakeup(tp);
            ttyecho(c, tp);
        }
        goto endcase;
    }

    /* Cooked mode from here down. */
    if (CCEQ(tp->t_erase, c)) {
        if (tp->t_rawq.c_cc)
            ttyrub(unputc(&tp->t_rawq), tp);
        goto endcase;
    }
    if (CCEQ(tp->t_kill, c)) {
        if (t_flags & CRTKIL &&
            tp->t_rawq.c_cc == tp->t_rocount) {
            while (tp->t_rawq.c_cc)
                ttyrub(unputc(&tp->t_rawq), tp);
        } else {
            ttyecho(c, tp);
            ttyecho('\n', tp);
            while (getc(&tp->t_rawq) > 0)
                ;
            tp->t_rocount = 0;
        }
        tp->t_state &= ~TS_LOCAL;
        goto endcase;
    }

    /* New line discipline: word erase and reprint. */
    if (tp->t_line == NTTYDISC) {
        if (CCEQ(tp->t_werasc, c)) {
            if (tp->t_rawq.c_cc == 0)
                goto endcase;
            do {
                c = unputc(&tp->t_rawq);
                if (c != ' ' && c != '\t')
                    goto erasenb;
                ttyrub(c, tp);
            } while (tp->t_rawq.c_cc);
            goto endcase;
    erasenb:
            do {
                ttyrub(c, tp);
                if (tp->t_rawq.c_cc == 0)
                    goto endcase;
                c = unputc(&tp->t_rawq);
            } while (c != ' ' && c != '\t');
            (void) putc(c, &tp->t_rawq);
            goto endcase;
        }
        if (CCEQ(tp->t_rprntc, c)) {
            ttyretype(tp);
            goto endcase;
        }
    }

    /* Input buffer overflow. */
    if (tp->t_rawq.c_cc + tp->t_canq.c_cc >= TTYHOG) {
        if (tp->t_line == NTTYDISC)
            (void) ttyoutput(CTRL(g), tp);
        goto endcase;
    }

    /* Queue the character, and wake a reader on a line delimiter. */
    if (putc(c, &tp->t_rawq) == 0) {
        if (ttbreakc(c, tp)) {
            tp->t_rocount = 0;
            catq(&tp->t_rawq, &tp->t_canq);
            ttwakeup(tp);
        } else if (tp->t_rocount++ == 0)
            tp->t_rocol = tp->t_col;
        if (tp->t_state & TS_ERASE) {
            tp->t_state &= ~TS_ERASE;
            (void) ttyoutput('/', tp);
        }
        i = tp->t_col;
        ttyecho(c, tp);
        if (CCEQ(tp->t_eofc, c) && t_flags & ECHO) {
            i = MIN(2, tp->t_col - i);
            while (i > 0) {
                (void) ttyoutput('\b', tp);
                i--;
            }
        }
    }
endcase:
    /* DEC-style start/stop: do not restart output until the start character. */
    if (t_flags & DECCTQ && tp->t_state & TS_TTSTOP &&
        tp->t_startc != tp->t_stopc)
        return;
restartoutput:
    tp->t_state &= ~TS_TTSTOP;
    tp->t_flags &= ~FLUSHO;
startoutput:
    ttstart(tp);
}

/* ttnread -- how many characters a read(2) could take from this line.
 *
 * 2.11BSD usr/sys/sys/tty.c:576.  The canonical queue always counts; the raw
 * one counts only in RAW or CBREAK, because in cooked mode a partial line is
 * not yet readable -- it becomes readable when ttyinput sees a delimiter and
 * moves it across with catq.
 *
 * IT TAKES PENDING INPUT FIRST, and that is not an optimisation: characters
 * queued under a previous mode have not been interpreted under the current
 * one, so counting them before ttypend replays them would report a length the
 * following read cannot deliver.  This is the reason ttnread cannot be ported
 * before ttyinput -- the call chain runs ttnread -> ttypend -> ttyinput, and
 * no seam is missing from any of them.
 */
int
ttnread(tp)
    register struct tty *tp;
{
    register int nread;

    if (tp->t_flags & PENDIN)
        ttypend(tp);
    nread = tp->t_canq.c_cc;
    if (tp->t_flags & (RAW|CBREAK))
        nread += tp->t_rawq.c_cc;
    return (nread);
}

/* ttyselect -- is this line ready for the direction asked?  1 yes, 0 no.
 *
 * 2.11BSD usr/sys/sys/tty.c:606.
 *
 * READABLE MEANS CHARACTERS OR NO CARRIER, and the second half is not an error
 * case: a line whose carrier has dropped is at end-of-file, and a reader must
 * be let through to see the zero-length read rather than blocked forever on a
 * line that will never produce anything.
 *
 * WRITABLE IS THE LOW WATERMARK, NOT AN EMPTY QUEUE -- the same TTLOWAT
 * ttyowake wakes on, so a writer is admitted while the line is still draining
 * and the device keeps feeding instead of stalling between writes.
 *
 * FGX DIVERGENCE: THERE IS NO REGISTRATION.  Upstream's two arms record the
 * selecting proc in `t_rsel'/`t_wsel' and mark TS_RCOLL/TS_WCOLL when one is
 * already recorded (tty.c:619-620 and :628-629).  FGX's select(2) registers on
 * nothing, so there is no proc to name and nothing to collide; the arms are
 * dropped rather than written as stores nobody reads.
 *
 * THAT COSTS NOTHING BUT A TARGETED WAKE, because the registration never
 * carried readiness in the first place: BSD's select is a poll-and-retry loop
 * (`select1', sys_generic.c:323) that calls this routine again after every
 * wake, so the answer always comes from the tests above and never from a
 * recorded proc.  See the note in ttwakeup, and docs/history/plans/tty-kernel-bank.md, for
 * why the wake side is unconditional to match.
 */
int
ttyselect(tp, rw)
    register struct tty *tp;
    int rw;
{
    int nread;
    register int s;

    s = spltty();
    switch (rw) {

    case FREAD:
        nread = ttnread(tp);
        if ((nread > 0) || ((tp->t_state & TS_CARR_ON) == 0))
            goto win;
        break;

    case FWRITE:
        if (tp->t_outq.c_cc <= TTLOWAT(tp))
            goto win;
        break;
    }
    splx(s);
    return (0);
win:
    splx(s);
    return (1);
}

/* ttselect -- ttyselect for a caller that has a device rather than a tty.
 *
 * 2.11BSD usr/sys/sys/tty.c:597, where it is
 * `&cdevsw[major(dev)].d_ttys[minor(dev)&0177]' and a comment saying the
 * routine goes away once every driver has its own.  FGX HAS NO cdevsw ARRAY --
 * `tty_find' is the registry lookup that stands for `d_ttys', the same one
 * kc_cdttyidx feeds -- so the masking of the minor number has no counterpart
 * here either: the registry answers per device index, and the softcarrier bit
 * upstream is stripping does not exist.
 *
 * A DEVICE WITH NO TTY ANSWERS READY, which upstream never has to decide
 * because cdevsw indexing always yields a struct.  tty_find returns NULL for
 * an index that names no device, one that is not a tty, and one never bound;
 * all three mean there is nothing here that will EVER become ready, so
 * answering 0 would park a select on it forever.  Answering 1 sends the caller
 * to the read or write that reports the real error.  That is `seltrue's
 * convention (sys_generic.c:496), which upstream installs for exactly the
 * devices it cannot poll.
 */
int
ttselect(dev, rw)
    dev_t dev;
    int rw;
{
    register struct tty *tp;

    tp = tty_find((int)dev);
    if (tp == (struct tty *)0)
        return (1);
    return (ttyselect(tp, rw));
}

/* ttywait -- wait for the output queue to drain.
 *
 * 2.11BSD usr/sys/sys/tty.c:154.  The first routine in this bank that BLOCKS,
 * and the loop is upstream's exactly because each of its four conditions is a
 * separate reason not to wait:
 *
 *   nothing queued and not busy   there is nothing to wait FOR
 *   carrier down                  nothing will ever drain it
 *   no t_oproc                    there is no device to drain it
 *
 * A wait that dropped any of them would be a wait with no end.
 *
 * IT KICKS THE DEVICE BEFORE EVERY SLEEP, not once: `(*tp->t_oproc)(tp)' at
 * the top of each turn is what makes progress, and the sleep is only how the
 * caller yields until that progress happens.
 *
 * THE BREAK AFTER THE KICK IS UPSTREAM'S OWN FIX, and its comment says why --
 * "If the output routine drains the queue and the device is no longer busy
 * then don't wait for something that's already happened."  Without it a driver
 * that empties the queue synchronously would sleep on a wakeup that was
 * already delivered, and nothing would send another.  It is the one arm of
 * this routine the probe can drive at boot, and case 340 does.
 *
 * TS_ASLEEP IS SET BEFORE THE SLEEP AND CLEARED BY ttyowake, not here.  That
 * split is deliberate upstream: the flag says "a writer is parked on t_outq",
 * and the routine that wakes it is the one that knows the queue moved.
 *
 * FGX DELTA: `sleep(chan, TTOPRI)' is kc_sleep(chan), which is UNINTERRUPTIBLE
 * where upstream's TTOPRI can take a signal.  The reasoning is in kc_sys.s and
 * it is a divergence with an expiry: upstream unwinds a caught signal through
 * u.u_error, and this bank has no u-area to unwind through.  The spl dance
 * upstream does inside the loop to "give interrupts a chance" is carried with
 * the empty macros, for the reason ttyparam.h gives.
 */
void
ttywait(tp)
    register struct tty *tp;
{
    register int s;

    s = spltty();
    while ((tp->t_outq.c_cc || tp->t_state & TS_BUSY) &&
           tp->t_state & TS_CARR_ON && tp->t_oproc) {
        (*tp->t_oproc)(tp);
        if (tp->t_outq.c_cc == 0 && (tp->t_state & TS_BUSY) == 0)
            break;
        tp->t_state |= TS_ASLEEP;
        kc_sleep(&tp->t_outq);
        splx(s);                /* drop priority, give interrupts a chance */
        s = spltty();
    }
    splx(s);
}

/* ttywflush -- drain the output, then throw the input away.
 *
 * 2.11BSD usr/sys/sys/tty.c:146.  Two lines, and the ORDER is the whole
 * routine: what has been typed AHEAD is discarded, but what has already been
 * printed is allowed to finish.  Flushing output too would cut off the message
 * the caller is very likely in the middle of -- a mode change, or a close.
 */
void
ttywflush(tp)
    register struct tty *tp;
{

    ttywait(tp);
    ttyflush(tp, FREAD);
}

/* ttioctl -- the discipline's ioctl half.  2.11BSD usr/sys/sys/tty.c:304.
 *
 * NO CALLER YET, like ttrstrt at :234 and ttycheckoutq above.  The core still
 * answers tty ioctls from _IoOp_TtyAtX (syscall.s), and repointing it is the
 * linesw cutover, not this increment: the fourteen arms there are the only
 * writers of _ttyTable fields that ttyv.s, signal.s, toolbox.s and pty.s still
 * read live, so they move together or job control desynchronises.
 *
 * `data' IS THE CALLER'S OWN POINTER, WHERE UPSTREAM'S IS A KERNEL COPY, and
 * that is the one deliberate divergence in this routine.  2.11BSD's ioctl(2)
 * copies the parameter block into a kernel buffer before dispatch and back
 * after (sys_generic.c:215-240), so ttioctl only ever sees kernel memory.  FGX
 * has no second address space to cross: a caller's pointer is an ordinary far
 * pointer and fcc emits bank-carrying loads for it, so upstream's `*(int *)
 * data' and its bcopy calls port unchanged and reach the caller directly.
 *
 * WHAT THAT COSTS, stated rather than left to be found: there is no single
 * validation point and no atomicity across the parameter block, so a bad
 * pointer is discovered per-arm rather than once.  On this machine that is
 * currently inert -- there are no page faults to interrupt a partial update --
 * and it is not a NEW divergence either: every one of _IoOp_TtyAtX's existing
 * arms already dereferences the caller's pointer the same way.  It stops being
 * inert if FGX ever gains memory protection, and the fix then is one change at
 * the syscall layer rather than anything in here, because dereferencing a far
 * pointer works whichever side of the seam the buffer sits on.
 *
 * THE COMMAND ENCODING NEEDED NO WORK, which is worth recording because it
 * looked like the blocker.  Upstream's ioctl(2) receives the 32-bit userland
 * encoding and hands the DRIVER the 16-bit kernel one -- sys_generic.c:199 is
 * `k_com = (u_int)com;' and :259 passes k_com -- and that 16-bit form is
 * already FGX's own (tty.h's TIOC block).  So the switch below is upstream's,
 * value for value.
 *
 * pfind AND inferior ARE NOT PORTED, and TIOCSPGRP is one call because of it.
 * The core already owns both as Task_Lookup and _Spg_Permitted, whose header
 * quotes the identical guard out of 2.11BSD kern_prot.c; kc_spgok answers the
 * whole of upstream's ownership conjunction.  See _Se_SpgOk in process.s.
 *
 * THE BACKGROUND GATE IS ttwrite's WITH TWO DIFFERENCES, both upstream's: it
 * leads with `t_line == NTTYDISC' and it does NOT test TOSTOP, because a
 * modifying ioctl from the background stops the caller whether or not the line
 * has asked for output stops.  `sleep(&lbolt, TTOPRI)' is kc_lbolt(), the same
 * uninterruptible substitution ttwrite's gate already carries and for the same
 * reason.
 */
int
ttioctl(tp, com, data, flag)
    register struct tty *tp;
    int com;
    char *data;
    int flag;
{
    int dev = tp->t_dev;
    int s, myidx;
    long newflags;

    /*
     * If the ioctl involves modification,
     * hang if in the background.
     */
    switch (com) {

    case TIOCSETD:
    case TIOCSETP:
    case TIOCSETN:
    case TIOCFLUSH:
    case TIOCSETC:
    case TIOCSLTC:
    case TIOCSPGRP:
    case TIOCLBIS:
    case TIOCLBIC:
    case TIOCLSET:
    case TIOCSTI:
    case TIOCSWINSZ:
        myidx = kc_cdttyidx((int)tp->t_dev);
        while (tp->t_line == NTTYDISC &&
               kc_curpgrp() != tp->t_pgrp &&
               myidx >= 0 && myidx == kc_curctty() &&
               kc_isvforked() == 0 &&
               !kc_sigopted(SIGTTOU, 0) &&
               !kc_sigopted(SIGTTOU, 1)) {
            kc_gsignal(kc_curpgrp(), SIGTTOU);
            kc_lbolt();
        }
        break;
    }

    /*
     * Process the ioctl.
     */
    switch (com) {

    /* get discipline number */
    case TIOCGETD:
        *(int *)data = tp->t_line;
        break;

    /* set line discipline */
    case TIOCSETD: {
        register int t = *(int *)data;
        int error = 0;

        if ((unsigned) t >= nldisp)
            return (ENXIO);
        if (t != tp->t_line) {
            s = spltty();
            (*linesw[tp->t_line].l_close)(tp, flag);
            error = (*linesw[t].l_open)(dev, tp);
            if (error) {
                (void) (*linesw[tp->t_line].l_open)(dev, tp);
                splx(s);
                return (error);
            }
            tp->t_line = t;
            splx(s);
        }
        break;
    }

    /* prevent more opens on channel */
    case TIOCEXCL:
        tp->t_state |= TS_XCLUDE;
        break;

    case TIOCNXCL:
        tp->t_state &= ~TS_XCLUDE;
        break;

    /* hang up line on last close */
    case TIOCHPCL:
        tp->t_state |= TS_HUPCLS;
        break;

    case TIOCFLUSH: {
        register int flags = *(int *)data;

        if (flags == 0)
            flags = FREAD|FWRITE;
        else
            flags &= FREAD|FWRITE;
        ttyflush(tp, flags);
        break;
    }

    /* return number of characters immediately available */
    case FIONREAD:
        *(off_t *)data = (off_t)ttnread(tp);
        break;

    case TIOCOUTQ:
        *(int *)data = tp->t_outq.c_cc;
        break;

    case TIOCSTOP:
        s = spltty();
        if ((tp->t_state&TS_TTSTOP) == 0) {
            tp->t_state |= TS_TTSTOP;
            kc_cdstop((int)tp->t_dev, 0);
        }
        splx(s);
        break;

    case TIOCSTART:
        s = spltty();
        if ((tp->t_state&TS_TTSTOP) || (tp->t_flags&FLUSHO)) {
            tp->t_state &= ~TS_TTSTOP;
            tp->t_flags &= ~FLUSHO;
            ttstart(tp);
        }
        splx(s);
        break;

    /*
     * Simulate typing of a character at the terminal.
     */
    case TIOCSTI:
        if (kc_uid() && (flag & FREAD) == 0)
            return (EPERM);
        myidx = kc_cdttyidx((int)tp->t_dev);
        if (kc_uid() && (myidx < 0 || myidx != kc_curctty()))
            return (EACCES);
        (*linesw[tp->t_line].l_rint)(*(char *)data, tp);
        break;

    case TIOCSETP:
    case TIOCSETN: {
        register struct sgttyb *sg = (struct sgttyb *)data;

        tp->t_erase = sg->sg_erase;
        tp->t_kill = sg->sg_kill;
        tp->t_ispeed = sg->sg_ispeed;
        tp->t_ospeed = sg->sg_ospeed;
        newflags = (tp->t_flags&0xffff0000L) | (sg->sg_flags&0xffffL);
        s = spltty();
        if (tp->t_flags&RAW || newflags&RAW || com == TIOCSETP) {
            ttywait(tp);
            ttyflush(tp, FREAD);
        } else if ((tp->t_flags&CBREAK) != (newflags&CBREAK)) {
            if (newflags&CBREAK) {
                struct clist tq;

                catq(&tp->t_rawq, &tp->t_canq);
                tq = tp->t_rawq;
                tp->t_rawq = tp->t_canq;
                tp->t_canq = tq;
            } else {
                tp->t_flags |= PENDIN;
                newflags |= PENDIN;
                ttwakeup(tp);
            }
        }
        tp->t_flags = newflags;
        if (tp->t_flags&RAW) {
            tp->t_state &= ~TS_TTSTOP;
            ttstart(tp);
        }
        splx(s);
        break;
    }

    /* send current parameters to user */
    case TIOCGETP: {
        register struct sgttyb *sg = (struct sgttyb *)data;

        sg->sg_ispeed = tp->t_ispeed;
        sg->sg_ospeed = tp->t_ospeed;
        sg->sg_erase = tp->t_erase;
        sg->sg_kill = tp->t_kill;
        sg->sg_flags = (short)tp->t_flags;
        break;
    }

    case FIONBIO:
        break;  /* XXX remove */

    case FIOASYNC:
        if (*(int *)data)
            tp->t_state |= TS_ASYNC;
        else
            tp->t_state &= ~TS_ASYNC;
        break;

    case TIOCGETC:
        bcopy((char *)&tp->t_intrc, data, sizeof (struct tchars));
        break;

    case TIOCSETC:
        bcopy(data, (char *)&tp->t_intrc, sizeof (struct tchars));
        break;

    /* set/get local special characters */
    case TIOCSLTC:
        bcopy(data, (char *)&tp->t_suspc, sizeof (struct ltchars));
        break;

    case TIOCGLTC:
        bcopy((char *)&tp->t_suspc, data, sizeof (struct ltchars));
        break;

    /*
     * Modify local mode word.
     */
    case TIOCLBIS:
        tp->t_flags |= (long)*(unsigned *)data << 16;
        break;

    case TIOCLBIC:
        tp->t_flags &= ~((long)*(unsigned *)data << 16);
        break;

    case TIOCLSET:
        tp->t_flags &= 0xffffL;
        tp->t_flags |= (long)*(unsigned *)data << 16;
        break;

    case TIOCLGET:
        *(int *)data = (int)(tp->t_flags >> 16);
        break;

    /*
     * Allow SPGRP only if tty is open for reading.
     * Quick check: if we can find a process in the new pgrp,
     * this user must own that process.
     * SHOULD VERIFY THAT PGRP IS IN USE AND IS THIS USER'S.
     */
    case TIOCSPGRP: {
        int pgrp = *(int *)data;

        if (kc_uid() && (flag & FREAD) == 0)
            return (EPERM);
        if (!kc_spgok(pgrp))
            return (EPERM);
        tp->t_pgrp = pgrp;
        break;
    }

    case TIOCGPGRP:
        *(int *)data = tp->t_pgrp;
        break;

    case TIOCSWINSZ:
        if (bcmp((char *)&tp->t_winsize, data,
            sizeof (struct winsize))) {
            tp->t_winsize = *(struct winsize *)data;
            kc_gsignal(tp->t_pgrp, SIGWINCH);
        }
        break;

    case TIOCGWINSZ:
        *(struct winsize *)data = tp->t_winsize;
        break;

    default:
        return (-1);
    }
    return (0);
}

/* ttbgread -- is this read a BACKGROUND read on our controlling terminal?
 *
 * FACTORED OUT OF ttread SO THE PUMP CAN ASK THE SAME QUESTION, and the reason
 * is a real difference between this kernel and upstream rather than tidiness.
 *
 * Upstream tests this and then, if the line is empty, SLEEPS on &tp->t_rawq
 * until the receive interrupt fills it -- so the refusal necessarily comes
 * BEFORE the wait.  FGX HAD no receive interrupt when this was factored out:
 * `kc_ttread' pumped the line itself, and THE PUMP WAS THE WAIT.  A pump that
 * ran first blocked a background reader on a key that was never coming, and
 * ttread never got to answer.  Measured then: `conctty' setpgid's itself out of
 * the foreground group, ignores SIGTTIN and reads one byte expecting EIO -- and
 * hung, with all three conjuncts below TRUE, because the fetch came first.
 *
 * T6 INCREMENT 4b RETIRED THE PUMP -- the heartbeat feeds `ttyinput' at arrival
 * and `ttread' sleeps the way upstream does -- so the ordering hazard is gone
 * and this routine could fold back into `ttread'.  It stays out because it
 * costs nothing where it is and `kc_ttread' still calls it, and because the
 * paragraph above is the only surviving record of why `conctty' exists.
 *
 * The TEST moves; the ACTION does not.  ttread still signals or answers EIO,
 * so nothing posts SIGTTIN twice.
 */
int
ttbgread(tp)
    register struct tty *tp;
{
    register int myidx;

    myidx = kc_cdttyidx((int)tp->t_dev);
    return (myidx >= 0 && myidx == kc_curctty() && kc_curpgrp() != tp->t_pgrp);
}

/* ttread -- the discipline's read half.  2.11BSD usr/sys/sys/tty.c:1136.
 *
 * THE BACKGROUND GATE IS SIGTTIN's, and it differs from ttwrite's in a way
 * worth naming because the two look alike: this one has an EIO OPT-OUT.  A
 * reader that ignores or blocks SIGTTIN, or is a vfork child, is handed an
 * error instead of a signal it has said it does not want.  Without that arm a
 * reader in that state LIVELOCKS -- the gate fires, the signal is dropped, the
 * syscall restarts and the gate fires again.  FGX's core read path learned that
 * the hard way at apple/fgx#121; the arm is upstream's and it comes across.
 *
 * IT ALSO HAS NO TOSTOP.  Background OUTPUT is only stopped when the line asks
 * for it; background INPUT is always stopped, because there is one keyboard and
 * two readers cannot both have it.  Upstream's asymmetry, carried.
 *
 * THREE PLACES SLEEP AND ALL THREE ARE REACHABLE, so the probe cannot drive
 * them at boot: the empty-queue wait on `&tp->t_rawq', the gate's retry on
 * lbolt, and the delayed-suspend retry on lbolt.  The IO_NDELAY and EOF arms
 * that return instead are what the probe exercises.
 *
 * `carrier' IS READ AND THEN TESTED, not tested twice.  Upstream reads
 * TS_CARR_ON into a local under spltty and tests the local; the value can
 * change under an interrupt, and taking it once is what makes the EOF decision
 * consistent with the sleep decision that follows it.
 */
int
ttread(tp, uio, flag)
    register struct tty *tp;
    struct uio *uio;
    int flag;
{
    register struct clist *qp;
    register int c;
    long t_flags;
    int s, first, error, carrier;

    error = 0;
loop:
    /*
     * Take any pending input first.
     */
    s = spltty();
    if (tp->t_flags&PENDIN)
        ttypend(tp);
    splx(s);

    /*
     * Hang process if it's in the background.
     */
    if (ttbgread(tp)) {
        if (kc_sigopted(SIGTTIN, 0) || kc_sigopted(SIGTTIN, 1) ||
            kc_isvforked())
            return (EIO);
        kc_gsignal(kc_curpgrp(), SIGTTIN);
        /* EINTR, NOT `kc_lbolt(); goto loop;'.  THE SAME DIVERGENCE THE WRITE
         * SIDE ALREADY CARRIES, and for the same measured reason -- ttwrite's
         * copy of this argument is two hundred lines down, filed under
         * apple/fgx#105 and signal.s:1222.
         *
         * Upstream can retry inside the syscall because BSD's
         * `sleep(&lbolt, TTOPRI)' is interruptible and issig/psig run from
         * within it.  FGX DELIVERS SIGNALS AT SYSCALL BOUNDARIES ONLY, and
         * `kc_lbolt' is uninterruptible besides (kc_sys.s -- it is
         * _FarSh_SleepUn).  A reader that stayed in this loop would post
         * SIGTTIN to itself once a second forever and never stop, because the
         * delivery point is the syscall RETURN it is refusing to reach.
         *
         * EINTR reaches the same state one syscall later: the pending SIGTTIN
         * is delivered at this syscall's exit, and for a default disposition
         * that stops the job before the caller ever sees the errno.
         *
         * The EIO opt-out above is unchanged -- a reader that has said it does
         * not want the signal gets the error upstream gives it. */
        return (EINTR);
    }
    t_flags = tp->t_flags;

    /*
     * In raw mode take characters directly from the
     * raw queue w/o processing.
     */
    if (t_flags&RAW) {
        s = spltty();
        if (tp->t_rawq.c_cc <= 0) {
            carrier = ISSET(tp->t_state, TS_CARR_ON);
            if (!carrier && ISSET(tp->t_state, TS_ISOPEN)) {
                splx(s);
                return (0);         /* EOF */
            }
            if (flag & IO_NDELAY) {
                splx(s);
                return (EWOULDBLOCK);
            }
            /* INTERRUPTIBLE, T6 increment 4b.  Until the flip this wait was the
             * PUMP'S and the pump's sleep answered signals; now it is ours, and
             * a ^C that reaches `ttyinput' flushes this very queue and wakes us
             * -- so an uninterruptible sleep would find it empty, loop, and
             * sleep again forever without ever reaching the syscall boundary
             * where the signal is delivered. */
            if (kc_sleepi(&tp->t_rawq)) {
                splx(s);
                return (EINTR);
            }
            splx(s);
            goto loop;
        }
        splx(s);
        while (!error && tp->t_rawq.c_cc && uio->uio_resid)
            error = kc_ureadc(getc(&tp->t_rawq), uio);
        goto checktandem;
    }

    /*
     * In cbreak mode use the rawq, otherwise
     * take characters from the canonicalized q.
     */
    qp = t_flags&CBREAK ? &tp->t_rawq : &tp->t_canq;

    /*
     * No input, sleep on rawq awaiting hardware
     * receipt and notification.
     */
    s = spltty();
    if (qp->c_cc <= 0) {
        carrier = ISSET(tp->t_state, TS_CARR_ON);
        if (!carrier && ISSET(tp->t_state, TS_ISOPEN)) {
            splx(s);
            return (0);             /* EOF */
        }
        if (flag & IO_NDELAY) {
            splx(s);
            return (EWOULDBLOCK);
        }
        /* INTERRUPTIBLE -- see the RAW arm above. */
        if (kc_sleepi(&tp->t_rawq)) {
            splx(s);
            return (EINTR);
        }
        splx(s);
        goto loop;
    }
    splx(s);

    /*
     * Input present, perform input mapping
     * and processing (we're not in raw mode).
     */
    first = 1;
    while ((c = getc(qp)) >= 0) {
        if (t_flags&CRMOD && c == '\r')
            c = '\n';
        /*
         * Check for delayed suspend character.
         */
        if (tp->t_line == NTTYDISC && CCEQ(tp->t_dsuspc, c)) {
            kc_gsignal(tp->t_pgrp, SIGTSTP);
            if (first) {
                kc_lbolt();
                goto loop;
            }
            break;
        }
        /*
         * Interpret EOF only in cooked mode.
         */
        if (CCEQ(tp->t_eofc, c) && (t_flags&CBREAK) == 0)
            break;
        /*
         * Give user character.
         */
        error = kc_ureadc(t_flags&PASS8 ? c : c & 0177, uio);
        if (error)
            break;
        if (uio->uio_resid == 0)
            break;
        /*
         * In cooked mode check for a "break character"
         * marking the end of a "line of input".
         */
        if ((t_flags&CBREAK) == 0 && ttbreakc(c, tp))
            break;
        first = 0;
    }

checktandem:
    /*
     * Look to unblock output now that (presumably)
     * the input queue has gone down.
     */
    s = spltty();
    if (ISSET(tp->t_state, TS_TBLOCK) && tp->t_rawq.c_cc < TTYUNBLOCK)
        ttyunblock(tp);
    splx(s);
    return (error);
}

/* ttycheckoutq -- is there room on tp's output queue for a kernel message?
 *
 * 2.11BSD usr/sys/sys/tty.c:1287.  Upstream's header, tty.c:1280-1285:
 *
 *     Check the output queue on tp for space for a kernel message
 *     (from uprintf/tprintf).  Allow some space over the normal
 *     hiwater mark so we don't lose messages due to normal flow
 *     control, but don't let the tty run amok.
 *     Sleeps here are not interruptible, but we return prematurely
 *     if new signals come in.
 *
 * NO CALLER YET, on the same footing as ttrstrt at :234.  Upstream's only two
 * are uprintf and tprintf (subr_prf.c), and FGX has neither -- Kern_LogStr
 * writes the boot console directly and buffers into no clist.
 *
 * `timeout(wakeup, &tp->t_outq, hz)' IS kc_lbolt(), AND THE TIMEOUT IS THE
 * LOAD-BEARING HALF.  It is the only timeout() in all of upstream's tty.c, and
 * upstream's own header says why it is there: the sleep is at PZERO-1, and
 * kern_synch.c:238 makes a sleep interruptible only `if (pri > PZERO)' with
 * PZERO 25 (h/param.h:38), so 24 is not, and the callout is the ONLY thing that
 * can make this loop look again.  ttywait sleeps on this same channel with no
 * timeout because it can be woken by the drain; this one cannot rely on that,
 * which is exactly what upstream's comment is warning about.  kc_sleep here is
 * uninterruptible too, so keeping the sleep and dropping the timeout would be
 * STRICTLY WORSE than upstream -- a missed drain wake would park a process
 * nothing could kill.  kc_lbolt is the shape the callout has: an
 * uninterruptible wait of at most one second that the caller re-tests around,
 * at upstream's own hz period, and the `while' below is that re-test.
 *
 * THE DELTA IS LATENCY, NOT SAFETY, and it is stated rather than buried.
 * Upstream wakes on EITHER the drain or the one-second tick; this wakes only on
 * the tick, so a queue that drains immediately is still noticed up to a second
 * late.  The bound is upstream's own timeout period.  It ends when this bank
 * has a callout to sleep on two channels with, which is T4's problem: pty is
 * the second caller that would justify building one.
 *
 * `oldsig' IS long AND UPSTREAM'S int IS A BUG.  h/proc.h:28 declares
 * `long p_sig' and tty.c:1291 snapshots it into an `int', so on the PDP-11's
 * 16-bit int upstream truncates the mask and then re-widens it to compare.
 * 4.3BSD-Reno writes the same line correctly only because its p_sig is a
 * 32-bit int (sys/proc.h:53).  fcc's int is 16 bits, so a verbatim port would
 * inherit the defect -- and it would bite HARDER here: this kernel numbers
 * pending bits `byte = sig>>3, bit = sig&7' with no decrement (signal.s's
 * @ka_post),
 * so signals 16..23 sit in byte 2, and that is SIGURG through SIGTTOU
 * (loader.s:795-801).  Truncating would drop every job-control signal, and the
 * observable failure would be a SPURIOUS EARLY RETURN: any process holding a
 * high-half signal at snapshot time makes the very first compare unequal, so
 * the kernel message is dropped although nothing new arrived.
 *
 * TS_ASLEEP IS SET AND ttyowake CLEARS IT, the split ttywait's header explains.
 */
int
ttycheckoutq(tp, wait)
    register struct tty *tp;
    int wait;
{
    int  hiwat, s;
    long oldsig;

    hiwat = TTHIWAT(tp);
    s = spltty();
    oldsig = kc_pendsig();
    if (tp->t_outq.c_cc > hiwat + 200)
        while (tp->t_outq.c_cc > hiwat) {
            ttstart(tp);
            if (wait == 0 || kc_pendsig() != oldsig) {
                splx(s);
                return (0);
            }
            tp->t_state |= TS_ASLEEP;
            kc_lbolt();
        }
    splx(s);
    return (1);
}

/* ttwrite -- the discipline's write half.  2.11BSD usr/sys/sys/tty.c:1315.
 *
 * THE BACKGROUND GATE LIVES HERE, in the tty layer, where both BSD trees put
 * every SIGTTIN/SIGTTOU gate.  Reno factors it into `sys/tty.h' as
 * `isbackground(p, tp)' -- HANDED the proc rather than reaching a global, which
 * is the shape a cross-bank accessor can serve.  docs/history/plans/tty-kernel-bank.md
 * section 9 has the sites.
 *
 * `tp == u.u_ttyp' BECOMES AN INDEX COMPARE.  Upstream compares pointers
 * because `u_ttyp' IS a `struct tty *'; FGX stores the controlling terminal as
 * an index packed into SE_Flags, so there is no pointer identity to compare and
 * kc_curctty answers the index.  The line's own index comes from the registry
 * the same way ttyopen gets it.
 *
 * THE ORDER OF THE CONJUNCTION IS UPSTREAM'S.  Leading with TOSTOP would save a
 * pgroup lookup and a ctty walk on the common path, but every term is a
 * cross-bank call, and a port that reorders a conjunction on an unmeasured
 * assumption is how a divergence starts.
 *
 * THE GATE RETURNS EINTR RATHER THAN SLEEPING AND RETRYING; the note at the
 * gate says why, and apple/fgx#105 records it.
 *
 * `flag' IS IO_NDELAY, NOT FNDELAY.  See the two constants in tty.h.
 *
 * UCB_METER's `tk_nout += ce' is dropped with the rest of the metering, as
 * everywhere else in this file.
 */
int
ttwrite(tp, uio, flag)
    register struct tty *tp;
    register struct uio *uio;
    int flag;
{
    char *cp;
    register int cc, ce;
    int i, hiwat, cnt, error, s;
    int myidx;
    /* UPSTREAM'S `char obuf[OBUFSIZ]' IS A KERNEL-STACK LOCAL AND THIS ONE IS
     * NOT.  100 bytes is a fifth of FGX_KSTK_SIZE, and through a `/dev' node
     * this routine runs with the whole vnode chain of fcc frames still under
     * it: measured at 516 of 512, a machine reset with no diagnostic.  The
     * buffer is per-task in the u-area now -- it has to be per-task, because
     * this routine holds it across `kc_lbolt' and across the high-watermark
     * sleep.  apple/fgx#246; `U_TtyObuf' in include/kernel.s carries the
     * argument and `U_TTYOBUF_LEN' is the one authority on the size. */
    char *obuf;

    obuf = kc_ttobuf();
    hiwat = TTHIWAT(tp);
    cnt = uio->uio_resid;
    error = 0;
    cc = 0;
    cp = obuf;
loop:
    s = spltty();
    if (!(tp->t_state&TS_CARR_ON)) {
        if (tp->t_state & TS_ISOPEN) {
            splx(s);
            return (EIO);
        } else if (flag & IO_NDELAY) {
            splx(s);
            error = EWOULDBLOCK;
            goto out;
        } else {
            /* Sleep awaiting carrier. */
            kc_sleep(&tp->t_rawq);
            goto loop;
        }
    }
    splx(s);
    /*
     * Hang the process if it's in the background.
     */
    myidx = kc_cdttyidx((int)tp->t_dev);
    if (kc_curpgrp() != tp->t_pgrp && myidx >= 0 && myidx == kc_curctty() &&
        (tp->t_flags&TOSTOP) && kc_isvforked() == 0 &&
        !kc_sigopted(SIGTTOU, 0) &&
        !kc_sigopted(SIGTTOU, 1)) {
        kc_gsignal(kc_curpgrp(), SIGTTOU);
        /* EINTR, NOT `kc_lbolt(); goto loop;' -- AND THE DIVERGENCE IS FORCED.
         *
         * Upstream signals and then RETRIES INSIDE THE SYSCALL, because BSD's
         * `sleep(&lbolt, TTOPRI)' is interruptible: issig()/psig() run from
         * within sleep, so the SIGTTOU that was just posted stops the process
         * before the loop comes round again.  FGX DELIVERS SIGNALS AT SYSCALL
         * BOUNDARIES ONLY.  A writer that stayed in here would post SIGTTOU to
         * itself once a second forever and never stop, because the delivery
         * point is the syscall RETURN it is refusing to reach -- measured, and
         * it is what `tostop' reports as BAD notstopped.
         *
         * EINTR reaches the same state one syscall later: the signal is posted,
         * the write unwinds, delivery happens at the boundary, and the process
         * stops with nothing written.  apple/fgx#105 (ERESTART) is the
         * divergence on record.
         *
         * `ttioctl''s SIGTTOU loop (:1439) has the same shape and is left
         * alone: nothing in the suite reaches it, so changing it would be
         * speculative.  When something does, this note is the precedent. */
        return (EINTR);
    }

    /*
     * Process the user's data in at most one bufferful per chunk.  Upstream
     * spells the bound OBUFSIZ; here the buffer's owner is asked, so the chunk
     * size and the reservation are the same number by construction.
     */
    while (uio->uio_resid || cc > 0) {
        if (tp->t_flags&FLUSHO) {
            uio->uio_resid = 0;
            return (0);
        }
        if (tp->t_outq.c_cc > hiwat)
            goto ovhiwat;
        if (cc == 0) {
            cc = MIN(uio->uio_resid, kc_ttobufsz());
            cp = obuf;
            error = kc_uiomove(cp, cc, uio);
            if (error) {
                cc = 0;
                break;
            }
        }
        while (cc > 0) {
            if (tp->t_flags & (RAW|LITOUT))
                ce = cc;
            else {
                ce = cc - scanc((unsigned)cc, (unsigned char *)cp,
                    (unsigned char *)partab, 077);
                /*
                 * If ce is zero, then we're processing
                 * a special character through ttyoutput.
                 */
                if (ce == 0) {
                    tp->t_rocount = 0;
                    if (ttyoutput(*cp, tp) >= 0) {
                        /* no c-lists, wait a bit */
                        ttstart(tp);
                        kc_lbolt();
                        goto loop;
                    }
                    cp++, cc--;
                    if (tp->t_flags&FLUSHO ||
                        tp->t_outq.c_cc > hiwat)
                        goto ovhiwat;
                    continue;
                }
            }
            tp->t_rocount = 0;
            i = b_to_q(cp, ce, &tp->t_outq);
            ce -= i;
            tp->t_col += ce;
            cp += ce, cc -= ce;
            if (i > 0) {
                /* out of c-lists, wait a bit */
                ttstart(tp);
                kc_lbolt();
                goto loop;
            }
            if (tp->t_flags&FLUSHO || tp->t_outq.c_cc > hiwat)
                break;
        }       /* while (cc > 0) */
        ttstart(tp);
    }           /* while (uio->uio_resid || cc > 0) */
out:
    /*
     * If cc is nonzero, we leave the uio structure inconsistent, as the
     * offset and iov pointers have moved forward, but it doesn't matter
     * (the call will either return short or restart with a new uio).
     */
    uio->uio_resid += cc;
    return (error);

ovhiwat:
    s = spltty();
    /*
     * This can only occur if FLUSHO is also set in t_flags,
     * or if ttstart/oproc is synchronous (or very fast).
     */
    if (tp->t_outq.c_cc <= hiwat) {
        splx(s);
        goto loop;
    }
    ttstart(tp);
    if (flag & IO_NDELAY) {
        splx(s);
        uio->uio_resid += cc;
        return (uio->uio_resid == cnt ? EWOULDBLOCK : 0);
    }
    tp->t_state |= TS_ASLEEP;
    kc_sleep(&tp->t_outq);
    splx(s);
    goto loop;
}

/* ttyopen -- initial open of a tty, or re-entry to a line discipline.
 *
 * 2.11BSD usr/sys/sys/tty.c:646.  It establishes the process group through
 * which quits and interrupts from this line will be distributed.
 *
 * THE SESSION BLOCK IS ONE CALL OUT, AND IT IS THE ONLY PLACE IN THIS FILE
 * THAT ASKS THE CORE BANK A QUESTION RATHER THAN ANSWERING IT.  Upstream, at
 * tty.c:652-659:
 *
 *     pp = u.u_procp;
 *     if (pp->p_pgrp == 0) {
 *         u.u_ttyp = tp;  u.u_ttyd = dev;
 *         if (tp->t_pgrp == 0)  tp->t_pgrp = pp->p_pid;
 *         pp->p_pgrp = tp->t_pgrp;
 *     }
 *
 * BSD PUTS THE JOB-CONTROL PREDICATE IN THE TTY LAYER.  Every SIGTTIN and
 * SIGTTOU background gate in both trees sits in the tty layer's own files, and
 * not one is in the syscall layer or in the signal code; the sites are listed
 * in docs/history/plans/tty-kernel-bank.md section 9.  So the background gates that ttread
 * and ttwrite carry will port as C into this file.  THIS block is the
 * exception, and the same section argues it: FGX's answer to WHICH PROCESS an
 * open is for is _kCttyTarget when a spawn is applying file actions and
 * _curTask otherwise, because init opens the device inside the CHILD.
 * `u.u_procp' cannot say that.  A verbatim port would put the shell's line
 * under init's process group -- the defect _Se_TtyOpen's header in ttyv.s
 * records, found once already.
 *
 * THE PGRP GOES OUT AND COMES BACK, which is what keeps the tty state here.
 * The core routine was split for this: it no longer reads _ttyTable, so the
 * core's copy of t_pgrp and this bank's cannot drift apart through it.
 *
 * A DEVICE THAT IS NOT A TTY SKIPS THE BLOCK, and upstream has no such case
 * because cdevsw indexing cannot produce one.  FGX's registry can answer "not
 * a tty" or "no such device" (kc_cdttyidx, -1 and -2), and binding a session
 * to a line that is not there would be worse than binding none.  The rest of
 * the open still runs: TS_ISOPEN and the window size are this structure's own
 * business and need no registry to be right.
 */
int
ttyopen(dev, tp)
    dev_t dev;
    register struct tty *tp;
{
    int idx;

    tp->t_dev = dev;
    idx = kc_cdttyidx((int)dev);
    if (idx >= 0)
        tp->t_pgrp = kc_ttyopen(idx, tp->t_pgrp);
    tp->t_state &= ~TS_WOPEN;
    if ((tp->t_state & TS_ISOPEN) == 0) {
        tp->t_state |= TS_ISOPEN;
        bzero((caddr_t)&tp->t_winsize, sizeof(tp->t_winsize));
        if (tp->t_line != NTTYDISC)
            ttywflush(tp);
    }
    return (0);
}

/* ttylclose -- take a line discipline off a tty.
 *
 * 2.11BSD usr/sys/sys/tty.c:674.  FNDELAY decides whether the close WAITS:
 * a non-blocking close throws both queues away, an ordinary one drains the
 * output first.
 *
 * THE FLAG IS `FNDELAY', NOT `IO_NDELAY', and upstream says so in a comment
 * arguing with 4.4BSD: the upper-level close routines all pass `fp->f_flags'
 * down, so the F* flags are what arrive here.  Carried as upstream has it,
 * including the reasoning, because a port that "corrected" it to IO_NDELAY
 * would silently take the draining path on every non-blocking close.
 *
 * `t_line = 0' IS THE LAST LINE and it is not a tidy-up: it puts the tty back
 * on discipline 0, which is where linesw sends it next.  Doing it before the
 * flush would send the flush through the wrong discipline.
 */
void
ttylclose(tp, flag)
    register struct tty *tp;
    int flag;
{

    if (flag & FNDELAY)
        ttyflush(tp, FREAD|FWRITE);
    else
        ttywflush(tp);
    tp->t_line = 0;
}
