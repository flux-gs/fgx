/* tty_dev.c -- the tty instances, and which device is which tty.
 *
 * FGX-Provenance: none.  This file is FGX's, not a port: it supplies what
 * `cdevsw[major(dev)].d_ttys[minor(dev)]' supplies in BSD, and FGX has no
 * cdevsw array to hang a d_ttys off -- its character-device switch is the
 * runtime registry in include/chardev.s.  The DATA it answers with is
 * upstream's (`struct tty', tty.h); only the lookup is ours.
 *
 *============================================================================
 * ONE ARRAY, INDEXED THE WAY _ttyTable IS.  include/kernel.s fixes the order:
 * tty[0] console, tty[1] ttyp0, tty[2] ttyp1, tty[3] ttyv1, tty[4] ttyv2,
 * tty[5] tty01, tty[6] ttyv3.
 * Upstream would scatter these across their drivers (`struct tty cons[1]',
 * `struct tty pt_tty[NPTY]') and that is where they end up -- T4 moves the pty
 * pair into pty.mod with its driver.  Keeping one array until then means the
 * mapping is arithmetic rather than a second table to keep in step.
 *
 * THE REGISTRY IS THE AUTHORITY ON WHICH DEVICE IS WHICH TTY, not this file.
 * CD_TtyOff is written at registration by the code that knows -- and it is a
 * _ttyTable byte offset PLUS ONE, so tty[0] is distinguishable from an unset
 * field (apple/fgx#129).  Reading it rather than hard-coding the device
 * indices here is deliberate: registration order has changed twice, and a
 * remembered index goes wrong silently while a read of the live registry
 * cannot.
 *
 * THE TTY INDEX IS THE SEAM T3 REMOVES.  Until then the line discipline is
 * still the core bank's, driven off _ttyTable, and ttys[i] stands for
 * _ttyTable entry i -- the same i, which is what lets the T2.2 adapters reach
 * across.  T3 deletes _ttyTable and the correspondence stops mattering; it is
 * recorded here rather than assumed so the deletion is findable.
 */

#include "ttyparam.h"
#include "clist.h"
#include "tty.h"
#include "conf.h"
#include "../vfs/uio.h"     /* kc_ttwrite hands one straight through */

/* THE DECLARATION UPSTREAM'S OWN tty_pty.c CARRIES, at
 * vendor/2.11BSD/usr/sys/sys/tty_pty.c:28 -- `extern int TTYHOG', with a
 * comment pointing at tty.c.  The watermark is a VARIABLE there
 * (tty.c:39, `int TTYHOG = 255') rather than a #define, so every file
 * that reads it declares it.  FGX's tty.c:76 keeps both the value and
 * the reason.
 */
/* The third answer `_FarSh_TtyGetByte'/`_FarSh_TtyPollByte' can give, beside a
 * byte and -1: this line's bytes arrive without a pump.  T6 increment 4a. */

extern int TTYHOG;
extern int kc_cdttyidx();
extern int kc_curctty();
extern int kc_curpgrp();
extern int ttbgread();
extern int ttnread();           /* tty.c -- select(2)'s readiness answer */
extern int ttyselect();         /* tty.c -- and the whole of it, slot 32  */
extern void ttyflush();         /* tty.c -- discard a queue */

/* The three the OUTPUT routine needs, declared for the reason clist.h's own
 * block gives: keeping this file at zero implicit-declaration warnings is what
 * makes the one that matters -- a far pointer losing its bank -- readable.
 * kc_cdwrite is the one that would be caught by it: its second argument is a
 * pointer INTO THIS BANK and its declaration is what stops fcc treating the
 * call as int-returning and the pointer as narrow. */
extern void kc_cdwrite();       /* kc_sys.s -- a RUN of bytes to a chardev */
/* The pump's two doors onto the core's byte source (T3 stage 4).  Both answer
 * 0..255 for a character and -1 for none -- the carry the core routines really
 * return, folded into a value C can see. */
extern void kc_ptywake();       /* kc_sys.s -- wake WCHAN_PTY (T4 inc 4)      */
extern void ttyowake();         /* tty.c -- dzstart's low-water wake */
extern void ttrstrt();          /* tty.c -- the output rail's PERFORM half */
extern void kc_cdstop_now();    /* kc_sys.s -- d_stop, WITHOUT the rail */

/* NTTY and CHARDEV_MAX, from include/kernel.s and include/chardev.s.  Restated
 * for the reason the errnos are: kernel C cannot include an assembly header.
 *
 * TTY_SIZE IS NOT RESTATED, deliberately -- it is a stride a DUM block
 * computes, so a copy of it goes wrong the first time a field is added to
 * _ttyTable.  _Chardev_TtyIdx does that division on the assembly side and
 * hands this file an index.
 *
 * THIS COMMENT USED TO SAY the two counts "cannot drift the same way, and
 * tty_probe drives the drift that matters anyway: it asserts the number of
 * ttys the registry binds against the number this file has room for".  THAT
 * CLAIM IS FALSE IN THE GROWTH DIRECTION, and apple/fgx#108 T7 is the change
 * that tested it: raise NTTY in include/kernel.s alone and `tty_devinit's own
 * loop is bounded by THIS copy, so it never binds the new line at all, the
 * bound count stays at the old number, and the probe is GREEN with the new
 * terminal silently unbound.  A probe that counts what the loop was willing to
 * visit cannot see a line the loop never reached.
 *
 * tools/check_ntty.py holds all three copies together now -- this one,
 * tty_probe.h's, and include/kernel.s's.
 */
#define NTTY            7
#define CHARDEV_MAX     16

struct tty ttys[NTTY];

/* Which chardev index each struct tty is bound to, PLUS ONE; 0 = unbound.
 *
 * THE PLUS-ONE IS THE SAME TRICK CD_TtyOff USES and for the same reason:
 * chardev index 0 is a real device, so a bare 0 cannot mean "unbound".  It
 * cost apple/fgx#129 once already.
 */
int tty_bound[NTTY];

/* tty_irq -- nonzero while the discipline is running at INTERRUPT time.
 * apple/fgx#108 T6 increment 4b.
 *
 * ONE FLAG, ONE READER, AND IT IS THE OUTPUT SIDE THAT READS IT.  `ttyinput'
 * is safe at interrupt time; what is not is the chardev dispatch underneath
 * its ECHO.  `_Chardev_Dispatch' self-modifies `_cdTrampJSL' -- one shared
 * five-byte JSL cell in bank 0, patched per dispatch (chardev.s:501,
 * include/memmap.s:1772) -- so the critical region runs THROUGH the device
 * call, and an ISR dispatching inside a task's dispatch repoints the
 * trampoline that task is about to jump through.  A wild jump, not a lost
 * wake.
 *
 * AND SAVE/RESTORE WOULD NOT BE ENOUGH EVEN THOUGH IT WOULD BE CORRECT.  The
 * ISR cannot be interrupted (I is set for its duration), so saving the cells
 * around its own dispatch would leave the task's intact.  The objection is
 * DURATION: FGX's console `t_oproc' PAINTS THE SCREEN, and a scroll inside the
 * heartbeat holds the next VBL off for as long as the paint takes.
 *
 * SO THE ISR FILLS `t_outq' AND MARKS, AND A SOFT SITE PERFORMS -- which is
 * upstream's own arrangement rather than an FGX invention: `dzstart' hands its
 * run to the SILO and returns, and the wire is somebody else's problem.  See
 * `tty_oproc' below for the mark and `kc_ttdrain' for the perform. */
int tty_irq;

/* tty_deferred -- did anything get marked during this interrupt?  Read once by
 * `kc_ttyinput' on the way out, so the ISR can set the core's summary word
 * without a second crossing to ask. */
int tty_deferred;

/* tty_stoppend[idx] -- `d_stop's rw bits PLUS ONE, owed to a line whose stop
 * the interrupt deferred; 0 is "none".  The plus-one is not decoration: rw is
 * 0 for the `^S' stop (tty.c:1085) and 3 for `ttyflush's (tty.c:818), so a bare
 * 0 cannot mean "nothing owed" -- the same trap `tty_bound' above records. */
char tty_stoppend[NTTY];

/* bzero -- the bank's only libc-shaped primitive, and it is here rather than
 * in a ported file for a reason.
 *
 * THE TTY BANK LINKS NO libc.  ttybank.s PUTs the fcc runtime and this bank's
 * own C, and nothing else; every primitive tty.c reaches for is either ported
 * (tty_subr.c's getc/putc/b_to_q) or a seam (kc_*).  Upstream's bzero is
 * neither -- 2.11BSD's is machine-dependent assembly, outside the tree this
 * campaign ports from -- so the bank has to carry one.
 *
 * NOT IN tty.c OR tty_subr.c, which are attributed ports: a function upstream
 * does not have, added to a file whose provenance row says it came from
 * usr/sys/sys, is exactly the drift check_provenance.py exists to catch.  This
 * file is FGX's own.
 *
 * ttyopen's `bzero(&tp->t_winsize, sizeof(tp->t_winsize))' is the only caller
 * today.  Written as a byte loop rather than a word one because the size comes
 * from sizeof and nothing guarantees it is even.
 */
void
bzero(cp, n)
register char *cp;
register int n;
{

    while (--n >= 0)
        *cp++ = 0;
}

/* bcopy, bcmp -- bzero's siblings, here for exactly bzero's reason.
 *
 * 2.11BSD's are machine-dependent assembly (machine/mch_xxx.s), outside the
 * tree this campaign ports from, and this bank links no libc.  So the bank
 * carries them, in FGX's own file rather than inside an attributed port.
 *
 * ttioctl is the only caller: TIOCGETC/SETC and TIOCGLTC/SLTC move six-byte
 * runs to and from tp->t_chars, and TIOCSWINSZ compares a winsize before
 * signalling, which is what makes it a compare rather than an assignment --
 * upstream signals SIGWINCH only when the size actually CHANGED.
 *
 * `from' OR `to' MAY NAME ANOTHER BANK.  ttioctl's `data' is the caller's own
 * pointer, and in this kernel that is an ordinary far pointer; fcc emits
 * bank-carrying loads for both, so nothing here needs to know which side is
 * which.  A byte loop for the same reason bzero uses one: the length comes
 * from sizeof and nothing guarantees it is even.
 */
void
bcopy(from, to, n)
register char *from;
register char *to;
register int n;
{

    while (--n >= 0)
        *to++ = *from++;
}

/* Nonzero when the two runs DIFFER, which is upstream's sense: ttioctl spells
 * it `if (bcmp(&tp->t_winsize, data, sizeof (struct winsize)))'. */
int
bcmp(a, b, n)
register char *a;
register char *b;
register int n;
{

    while (--n >= 0)
        if (*a++ != *b++)
            return (1);
    return (0);
}

/* scanc -- how many of the next `size' bytes are NOT special.
 *
 * Ported from 4.3BSD-Reno ufs/ufs_subr.c:160, and the tree is deliberate.
 * 2.11BSD's scanc is PDP-11 assembly (machine/mch_xxx.s), outside what this
 * campaign ports from; Reno carries a portable C version under
 * `#if !defined(vax) && !defined(tahoe) && !defined(hp300)', headed "C
 * definitions of special instructions", which is exactly the case a 65816 is
 * in.  So this is upstream's own C for a non-VAX, not a local reimplementation
 * -- the same reason bzero above is hand-written and this one is not.
 *
 * It returns bytes REMAINING, not the index, which is why ttwrite spells its
 * use `ce = cc - scanc(...)'.
 *
 * `table[*cp]' INDEXES WITH AN UNMASKED BYTE, which is why partab carries all
 * 256 entries and tty.c says so beside it.
 */
int
scanc(size, cp, table, mask)
unsigned size;
register unsigned char *cp;
register unsigned char table[];
register unsigned char mask;
{
    register unsigned char *end;

    end = &cp[size];
    while (cp < end && (table[*cp] & mask) == 0)
        cp++;
    return (end - cp);
}

/* tty_find -- the `struct tty *' for a chardev index, or NULL.
 *
 * NULL for three different reasons, and the caller cannot tell them apart on
 * purpose: the index names no device, the device is not a tty, or it is a tty
 * that tty_devinit never bound.  All three mean "there is no tty here", which
 * is the only thing a driver does with the answer.  tty_probe drives each case
 * separately, which is where they are distinguished.
 */
struct tty *
tty_find(dev)
int dev;
{
    int idx;

    idx = kc_cdttyidx(dev);
    if (idx < 0 || idx >= NTTY)
        return ((struct tty *)0);
    /* BOUND, not merely in range.  A struct tty nothing registered is zeroed
     * memory that would answer every field plausibly. */
    if (tty_bound[idx] == 0)
        return ((struct tty *)0);
    return (&ttys[idx]);
}

/* tty_byidx -- the `struct tty *' for a TTY INDEX, or NULL.
 *
 * `tty_find' above answers the same question from a CHARDEV index, by asking
 * the registry which tty a device is.  Every kc_ door below already holds the
 * tty index itself and was open-coding the other half of tty_find -- the range
 * test and the bound test -- which by increment 4 stood NINE times in this
 * file.  Nine copies of a two-line guard is nine places to forget the second
 * line, and the second line is the one that matters: an unbound `struct tty' is
 * zeroed memory that answers every field plausibly.
 *
 * IT IS ALSO WHY THIS FITS.  The bank pays for every copy in all four probe
 * configs as well as the shipping kernel, and the tightest half had 224 bytes
 * left when increment 4's four doors landed.
 */
struct tty *
tty_byidx(idx)
int idx;
{

    if (idx < 0 || idx >= NTTY)
        return ((struct tty *)0);
    if (tty_bound[idx] == 0)
        return ((struct tty *)0);
    return (&ttys[idx]);
}

/* kc_ttwrite -- the core bank's door into the discipline's write half.
 * apple/fgx#108 T3 stage 3, and the twin of kc_ttioctl above.
 *
 * IT GOES THROUGH linesw RATHER THAN CALLING ttwrite, and that is the stage
 * rather than a formality: T2.1 built the switch so that `l_write' could be
 * repointed, and a seam that called `ttwrite' directly would leave the table
 * decorative -- a line whose t_line userland has set to some other discipline
 * would still get OTTYDISC's write.  `usr/sys/sys/tty_pty.c:295' is upstream
 * doing exactly this: `(*linesw[tp->t_line].l_write)(tp, uio, flag)'.
 *
 * BOUND, NOT MERELY IN RANGE, for tty_find's reason: a struct tty nothing
 * registered is zeroed memory whose t_line indexes linesw[0] plausibly.
 *
 * Returns an errno, 0 on success -- ttwrite's own convention.  How much moved
 * is NOT the return value: the caller reads it off the uio, which ttwrite
 * consumes as it goes.  That is what a uio is for and the core side is written
 * to match.
 */
int
kc_ttwrite(idx, uio, flag)
    int idx;
    struct uio *uio;
    int flag;
{
    register struct tty *tp;

    if (idx < 0 || idx >= NTTY)
        return (ENXIO);
    if (tty_bound[idx] == 0)
        return (ENXIO);
    tp = &ttys[idx];
    return ((*linesw[tp->t_line].l_write)(tp, uio, flag));
}

/* kc_ttflush -- the core bank's door onto `ttyflush' (tty.c:776).
 *
 * apple/fgx#108 T3 stage 4 increment 8b.  The core used to flush a tty's input
 * by zeroing its own `TTY_CanonLen'/`TTY_CanonPos'; the queue is a clist now,
 * so the flush has to happen where the queue lives.  `rw' is TTYIO_FREAD /
 * TTYIO_FWRITE from include/ktty.s, which are upstream's FREAD/FWRITE and the
 * same constants tty.h compiles against.
 *
 * The bound check is `kc_ttread's, for its reason: a zero on a booted machine
 * is a broken lookup rather than a line with no device, and flushing a tty that
 * never bound would walk a null `t_oproc'.
 */
int
kc_ttflush(idx, rw)
    int idx;
    int rw;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    ttyflush(tp, rw);
    return (0);
}

/* kc_ttnread -- how many bytes a read(2) would return right now.
 *
 * `ttnread' (tty.c:1200) is upstream's own answer and it already knows the
 * difference the core's cursor compare could not make: in cooked mode a raw
 * key that has not been terminated is NOT a readable line.  select(2) asked
 * the core for this and the core answered from `TTY_CanonPos < TTY_CanonLen'.
 *
 * Zero for an unbound or out-of-range line, which select reads as "would
 * block" -- the safe answer, and the one the core's compare gave for an empty
 * buffer anyway.
 */
int
kc_ttnread(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    return (ttnread(tp));
}

/* kc_ttopen -- the core bank's door onto `l_open', which is `ttyopen'.
 * apple/fgx#108 T4 increment 2, KTTY export slot 22.
 *
 * `ptsopen' ends with `error = (*linesw[tp->t_line].l_open)(dev, tp)'
 * (2.11BSD usr/sys/sys/tty_pty.c:88) and that call is what sets TS_ISOPEN.
 * NOTHING IN FGX HAD EVER MADE IT: no open path dispatched `l_open', so no
 * line in this kernel had TS_ISOPEN set, and every test of it -- ttread's,
 * ttwrite's, and above all ttymodem's lost-carrier arm -- was reading a bit
 * that could not be 1.  A hangup therefore had nobody to signal, which is why
 * the carrier work of this increment needs the OPEN half with it rather than
 * after it.
 *
 * IT REPLACES A CALL RATHER THAN ADDING ONE.  `_PtyS_Open' reached the session
 * block directly through KSVC_TTYOPEN -> `_Se_TtyOpen'; `ttyopen' reaches the
 * same core routine through `kc_ttyopen' and then does the rest of the open
 * this structure owns.  Two paths to one predicate is how the two banks' idea
 * of a line drifts apart, so the driver now takes the discipline's door.
 *
 * DISPATCHED THROUGH `linesw[t_line]', not straight at ttyopen, for slot 17's
 * reason: the table IS the indirection, and a line whose discipline userland
 * has changed must open through the discipline it is on.
 */
int
kc_ttopen(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    return ((*linesw[tp->t_line].l_open)(tp->t_dev, tp));
}

/* kc_ttmodem -- the core bank's door onto `l_modem', which is `ttymodem'.
 * apple/fgx#108 T4 increment 2, KTTY export slot 23.
 *
 * THE MASTER'S PRESENCE IS THE SLAVE'S CARRIER, and BSD says it in two calls:
 * `ptcopen' does `(void)(*linesw[tp->t_line].l_modem)(tp, 1)' (tty_pty.c:214)
 * and `ptcclose' does the same with 0 (tty_pty.c:228).  Everything a hangup
 * means -- SIGHUP, SIGCONT, both queues flushed -- is `ttymodem's, and this is
 * the whole of what the pty driver needs to reach it.
 *
 * THE ANSWER IS UPSTREAM'S: 0 asks the DRIVER to turn the line off, 1 says
 * carry on.  `ptcclose' discards it (there is nothing to turn off on a pty)
 * and it is returned anyway, because a caller that grows a use for it should
 * not have to change this door.
 *
 * AN UNBOUND LINE ANSWERS 1, not an errno.  A carrier transition on a line
 * with no device is not an error to report; it is a transition with nothing to
 * act on, which is exactly what `ttymodem' itself answers for a line that is
 * not open.
 */
/* kc_ttclose -- the core bank's door onto the pair that ends a session:
 * `l_close', which is `ttylclose', and then `ttyclose'.  apple/fgx#108 T4
 * increment 3, KTTY export slot 24.
 *
 * BOTH, IN THAT ORDER, BECAUSE `ptsclose' CALLS BOTH (2.11BSD tty_pty.c:94-95):
 *
 *      (*linesw[tp->t_line].l_close)(tp, flag);
 *      ttyclose(tp);
 *
 * They are not alternatives and they are not the same routine.  `ttylclose'
 * takes the DISCIPLINE off the line -- drain or discard, then `t_line = 0'.
 * `ttyclose' cleans the LINE -- flush both queues, `t_pgrp = 0', and a
 * whole-word `t_state = 0' that takes TS_ISOPEN down with everything else.  A
 * driver that called only the first would leave the line believing it is open
 * and carrying; one that called only the second would leave it on a discipline
 * it has closed.
 *
 * THE FLAG IS THE FD'S IN UPSTREAM AND IS 0 HERE, and that is a divergence
 * worth stating rather than implying: FNDELAY is what decides whether
 * `ttylclose' discards the output queue or waits for it to drain, and FGX's
 * chardev close op is handed a minor and nothing else -- there is no `flag' at
 * the call site to pass.  0 is the ordinary close, which is the arm a close(2)
 * without O_NDELAY takes upstream, so the common case is faithful and the
 * non-blocking case is not available to ask for.
 *
 * THE DRAIN CANNOT HANG THE COMMON ORDER.  `ttywflush' waits only while the
 * line has carrier and an output routine, so a slave closed AFTER its master
 * returns at once -- carrier went with the master (increment 2).  Closed
 * BEFORE its master it drains into the pty ring through `tty_oproc', which is
 * exactly what upstream does into a silo.
 */
int
kc_ttclose(idx, flag)
    int idx;
    int flag;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    (*linesw[tp->t_line].l_close)(tp, flag);
    ttyclose(tp);
    return (0);
}

int
kc_ttmodem(idx, flag)
    int idx;
    int flag;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (1);
    return ((*linesw[tp->t_line].l_modem)(tp, flag));
}

/* kc_ttread -- the core's door into the discipline's READ half.  apple/fgx#108
 * T3 stage 4, KTTY export slot 18.
 *
 * kc_ttwrite's twin, and its header above carries the reasoning for everything
 * the two share: kernel C because a read(2) arrives from a syscall where no
 * second C context can be live, dispatched through `linesw[t_line]' rather
 * than straight at ttread, an errno for a return with 0 for success.
 *
 * HOW MUCH WAS READ IS `uio_offset', not the return value and NOT
 * `_Sys_RdMax - uio_resid'.  `_Sys_UioOne' seeds the offset at 0 and `ureadc'
 * advances it once per delivered byte, so the count lives in the caller's own
 * per-task u-area for the whole call.  The subtraction would read a core-bank
 * singleton that `_Tty_GetByte' does not park across its sleep -- the trap the
 * first attempt at this stage hit, where a stale 1024 over a five-byte line
 * reported 1024 bytes read.
 *
 * THE PUMP IS GONE AND THE INTERRUPT FILLS THE LINE.  This paragraph used to
 * open "NO PUMP YET.  FGX has no receive interrupt that can run a line
 * discipline until T6, so nothing fills `t_rawq' asynchronously" -- true when
 * written, and T6 increment 4b is exactly the increment that ended it.  The
 * heartbeat now hands each arriving key to `ttyinput' (toolbox.s), so `t_rawq'
 * fills asynchronously and a `ttread' on an empty queue sleeps on `&tp->t_rawq'
 * with the receive path able to wake it -- upstream's own arrangement.
 *
 * WHAT THE PUMP LEFT BEHIND is `ttbgread' (tty.c): the background-read test had
 * to be factored out of `ttread' so the pump could ask it BEFORE fetching, and
 * that factoring stays even though the pump does not, because it costs nothing
 * and the alternative is re-deriving why it exists.
 */
int
kc_ttread(idx, uio, flag)
    int idx;
    struct uio *uio;
    int flag;
{
    register struct tty *tp;
    register int c;

    if (idx < 0 || idx >= NTTY)
        return (ENXIO);
    if (tty_bound[idx] == 0)
        return (ENXIO);
    tp = &ttys[idx];

    /* THE PUMP STOOD HERE and went at T6 increment 4b.  It pulled bytes from
     * the core's `_Tty_GetByte' one at a time and handed them to `l_rint'
     * from inside `read(2)' -- because FGX had no interrupt that could run a
     * line discipline.  It has one now: the heartbeat calls `kc_ttyinput' at
     * arrival, the way 2.11BSD's `dzrint' does, so by the time a reader gets
     * here the bytes are already in the line's own queues and `ttread's own
     * sleep on `&tp->t_rawq' is the wait.
     *
     * FOUR THINGS WENT WITH IT and each was the pump's alone:
     *   - the `ttbgread' PRE-TEST.  `ttread' runs its own background gate
     *     (tty.c:1786); this copy existed only to refuse to PUMP for a
     *     background reader, and there is nothing left to refuse.
     *   - the `kc_ttflushpend' / `ttyflush(FREAD)' pair.  The heartbeat
     *     latched that because it CONSUMED the `^C' and the discipline
     *     therefore never ran its own flush.  `ttyinput' sees the `^C' now and
     *     does `if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)' itself,
     *     which is upstream's and is the WIDER flush.
     *   - `NOTPUMPED', the -2 the far shims answered for a pty line.  With no
     *     pump there is no line to exempt from it.
     *   - the IO_NDELAY arm, which skipped the blocking half; `ttread' has
     *     upstream's own EWOULDBLOCK arm (tty.c:1791). */
    /* A PTY SLAVE'S READ IS WHAT UNBLOCKS ITS MASTER -- T6 increment 4a, and
     * the flip breaks this if it is left out.  `_PtyM_Write' sleeps on
     * WCHAN_PTY when `kc_ptcinput' answers TTYHOG, and the only thing that ever
     * posted that channel for INPUT was `_Pty_InPut' -- which no longer runs.
     * So the master slept forever the first time a writer outran its reader.
     *
     * NOTHING IN THE SUITE COULD SEE IT and `ptyhog' is why it was found: no
     * other fixture writes a master past the hog mark, so all 53 stayed green
     * with the wake missing.
     *
     * AFTER the read, not before: the point is that the queue has just been
     * drained.  Coarse on purpose, which is WCHAN_PTY's whole arrangement --
     * one channel serves every pty waiter and each re-tests on waking. */
    c = (*linesw[tp->t_line].l_read)(tp, uio, flag);
    kc_ptywake();
    return (c);
}

/* tty_oproc -- the line's OUTPUT routine, `tp->t_oproc'.  apple/fgx#108 T3
 * stage 3.
 *
 * IT IS `dzstart' AND `dzxint' COLLAPSED INTO ONE CALL, and that is a property
 * of FGX rather than a simplification.  `dzstart'
 * (examples/2.11BSD/usr/sys/pdpuba/dz.c) hands a run to the silo and returns;
 * the transmit-done interrupt `dzxint' then `ndflush'es what went out and
 * calls start again.  FGX's console write is SYNCHRONOUS -- the bytes are on
 * the screen when kc_cdwrite returns -- so there is no interrupt to come back
 * on and the flush belongs immediately after the write.  `TS_BUSY' is set and
 * cleared inside this call and is never observable, which is what a polled
 * driver looks like, not a divergence.
 *
 * THE LOW-WATER WAKE IS UPSTREAM'S AND COMES FIRST, before the drain: a writer
 * asleep on a full queue has to be released whether or not there is anything
 * left to send.  `ttwrite' sleeps on `&tp->t_outq' with TS_ASLEEP set, and
 * `ttselect' registers `t_wsel'; both are woken here.
 *
 * EVERY BYTE IN `t_outq' IS DATA, and the run is `ndqb(q, 0)' whatever the
 * mode.  2.11BSD's `ttyoutput' encodes no delays, so nothing it queues is a
 * marker; the console's own start routine sends each byte it dequeues
 * (`cnstart', vendor/2.11BSD/usr/sys/pdp/cons.c:163-167) and gives a byte
 * with the high bit set no second meaning.  Only `dzstart' still carries the
 * older `ndqb(q, 0200)' delay arm, which has no producer left upstream --
 * and a drain that followed it here would swallow, as a delay, every
 * character above 0177 that PASS8 lets `ttyoutput' queue.
 */
void
tty_oproc(tp)
    register struct tty *tp;
{
    register int cc;

    if (tp->t_state & (TS_TIMEOUT|TS_BUSY|TS_TTSTOP))
        return;
    /* THE MARK, and it is UPSTREAM'S OWN BIT rather than one invented for FGX.
     * TS_TIMEOUT means "output is deferred and something will restart it", and
     * the line above already treats it that way -- so marking is a store, and
     * the guard that makes it idempotent was here before this increment was.
     * The PERFORM is `ttrstrt', which does `t_state &= ~TS_TIMEOUT; ttstart(tp)'
     * and was ported at tty.c:251 with NO CALLER: upstream reaches it through
     * `timeout()', which this bank has no equivalent of.  `kc_ttdrain' is that
     * caller now.  READ THE TREE BEFORE PORTING THE ROW -- for the fifth time
     * in this campaign the increment's work was already in the file. */
    if (tty_irq) {
        tp->t_state |= TS_TIMEOUT;
        tty_deferred = 1;
        return;
    }
    /* ttyowake IS dzstart's low-water block, already ported (tty.c:738) -- the
     * TS_ASLEEP wake and the selector wake, behind the same
     * `c_cc <= TTLOWAT' test.  Calling it rather than open-coding the same
     * five lines is not only shorter: it keeps ONE copy of the divergence
     * ttwakeup records about FGX's selwakeup being a channel rather than a
     * recorded proc. */
    ttyowake(tp);
    tp->t_state |= TS_BUSY;
    while (tp->t_outq.c_cc) {
        cc = ndqb(&tp->t_outq, 0);
        kc_cdwrite((int)tp->t_dev, tp->t_outq.c_cf, cc);
        /* DZXINT'S TEST, AND THE REASON THE COLLAPSE NEEDS IT.  This routine
         * is dzstart and dzxint in one call because the console write is
         * synchronous -- but `synchronous' means the CPU is inside kc_cdwrite
         * painting the screen, with `cc' bytes and `c_cf' held, for as long as
         * a scroll takes, and INTERRUPTS ARE ON (this routine cannot mask; see
         * the head note at tty_dev.c:121).  Since the receive interrupt began
         * running ttyinput at arrival time, that window is one an interrupt
         * can empty the queue in: ttyinput's INTR arm runs
         * `if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)' (tty.c:1109).
         *
         * So the completion half needs upstream's guard even though the
         * transmit interrupt it came from does not exist here:
         *      if (tp->t_state & TS_FLUSH) tp->t_state &= ~TS_FLUSH;
         *      else ndflush(&tp->t_outq, ...);
         * (dz.c:389-398).  Without it the stale `cc' is flushed against a
         * queue the interrupt already emptied and refilled, so the count is
         * charged to bytes that were enqueued AFTER the flush.
         *
         * WHAT THIS IS NOT: the `^C' that ttyinput echoes (tty.c:1111) does
         * not reach the screen, and this guard does NOT fix it -- measured.
         * That echo happens at an idle prompt, where nothing is painting and
         * TS_BUSY is therefore clear, so the latch never arms and the ordinary
         * ndflush runs exactly as before.  The two were assumed to be one
         * defect and are not; the missing echo is still unexplained and is
         * kept on apple/fgx#254 rather than claimed as fixed here.
         * Cases 243-245 in tty_probe3.c witness the latch itself. */
        if (tp->t_state & TS_FLUSH)
            tp->t_state &= ~TS_FLUSH;
        else
            ndflush(&tp->t_outq, cc);
    }
    tp->t_state &= ~TS_BUSY;
}

/*============================================================================
 * THE PTY SLAVE'S OUTPUT HOOK AND ITS QUEUE, apple/fgx#108 T4 increment 4.
 *
 * Upstream's pty has exactly ONE output buffer and it is the discipline's:
 * `ptsstart' moves no data, and `ptcread' does the dequeue itself with
 * `q_to_b(&tp->t_outq, ...)' (tty_pty.c:213, :234-296).  FGX bound the generic
 * `tty_oproc' to every line, which DRAINS -- right for a console, where the
 * bytes are on the screen when the call returns, and a second buffer on a pty,
 * where the far end's read IS the device.  `ptyoutq' measured what that cost:
 * TIOCOUTQ answering 0 with five bytes pending, and with it ttycheckoutq,
 * ttywait, ttyflush(FWRITE) and TS_TTSTOP all reasoning about an empty queue.
 *
 * WHAT LIVES HERE IS WHAT CANNOT LIVE IN pty.mod.  `t_oproc' is called through
 * a function pointer in `struct tty', and a pointer cannot cross a bank, so
 * `ptsstart' is this bank's.  `t_outq' is this bank's data, so the queue
 * primitives are too.  The DRIVER stays in pty.mod and pulls through these.
 *============================================================================*/

/* ptsstart -- the pty slave line's `t_oproc'.  2.11BSD tty_pty.c:290.
 *
 * IT MOVES NO DATA, which is the whole difference from `tty_oproc' above.  A
 * pty has no device to hand a run to: the master's read is the device, so all
 * this owes is the wakeup.
 *
 * TS_TTSTOP IS UPSTREAM'S FIRST LINE AND IT IS NOT A SHORTCUT: a stopped line
 * has told the far end to wait, and waking a reader that will find the queue
 * withheld is a spin, not a delivery.  `ptcread' tests the same bit before it
 * breaks out of its wait loop.
 *
 * UPSTREAM'S OTHER TWO LINES ARE NOT HERE, AND THIS IS THE DIVERGENCE, T4
 * INCREMENT 5b.  The body it is missing is
 *
 *      if (pti->pt_flags & PF_STOPPED) {
 *              pti->pt_flags &= ~PF_STOPPED;
 *              pti->pt_send = TIOCPKT_START;
 *      }
 *
 * and `pt_flags'/`pt_send' are the DRIVER's, in pty.mod, a bank this one
 * cannot write.  This routine is here at all only because `t_oproc' is a
 * pointer inside `struct tty' and a pointer cannot cross a bank -- so FGX's
 * `ptsstart' is the half of upstream's that has to live beside the queue, and
 * the half that touches driver state cannot follow it.
 *
 * SO THE ARM IS EVALUATED AT THE MASTER'S READ INSTEAD, out of the same two
 * facts: PF_STOPPED, which `ptsstop' records in the driver, and TS_TTSTOP,
 * which `kc_ttstopped' below hands across.  "Stopped once, and running now" is
 * exactly the condition this routine tests eagerly, and `pt_send' has no other
 * consumer -- `ptcread' delivers it and `ptcselect' asks whether it is set, and
 * both of those are the driver's.  The WAKE still happens here, so a master
 * parked in read(2) is woken by the restart as upstream's `ptcwakeup(tp, FREAD)'
 * wakes it, and finds the byte when it re-tests.
 */
void
ptsstart(tp)
    register struct tty *tp;
{

    if (tp->t_state & TS_TTSTOP)
        return;
    kc_ptywake();
}

/* kc_ttselect -- the discipline's own readiness answer.  KTTY slot 32.
 *
 * `ttyselect(tp, rw)' (tty.c:1240), which for FWRITE is
 * `tp->t_outq.c_cc <= TTLOWAT(tp)' and for FREAD is `ttnread(tp) > 0'.  A
 * driver in another bank cannot reach either, and `_PtyS_Poll' had been
 * answering POLLOUT from `PTYR_OutCount' -- the slave->master ring's fill
 * level, which T4 increment 4 stopped feeding, so it read 0 forever and the
 * arm said "writable" unconditionally while `ttwrite' still slept at the high
 * watermark.  A select that promises a write which then blocks is the one
 * thing select exists to prevent.
 *
 * THE SAME DEFECT `_PtyM_Poll' HAD, and it is the same fix: ask the queue that
 * actually holds the bytes.  Increment 4 caught the master's by reading and
 * noted that no fixture covered select on a pty master; none covered the slave
 * either, and `ptyswsel' is now that fixture for both halves of the answer.
 *
 * IT TAKES `rw' RATHER THAN BEING TWO SLOTS because `ttyselect' is one
 * function upstream and the driver should not have to know which of its two
 * arms is which.  Only FWRITE has a caller today; FREAD is here because
 * splitting one upstream routine across two exports would make the second
 * caller invent a second convention.
 */
int
kc_ttselect(idx, rw)
    int idx;
    int rw;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    return (ttyselect(tp, rw));
}

/* kc_ttstopped -- is this line's output stopped?  KTTY slot 31.
 *
 * `(tp->t_state & TS_TTSTOP) != 0', which `ptcread' reads directly off the
 * shared `struct tty' (tty_pty.c:271) and which a driver in another bank
 * cannot.  It is the second half of the pair `ptsstart' above describes: the
 * driver holds PF_STOPPED and asks this for "and is it running again?".
 *
 * NOT FOLDED INTO `kc_ttoutq_run', which already tests the same bit: that one
 * answers ZERO for a stopped line AND for an empty one, on purpose, because
 * its caller wants "may I take bytes now".  A caller that has to tell the two
 * apart cannot use an answer that merges them, and packing a flag into the
 * count is the shape apple/fgx#234 spent a session on.
 */
/* kc_ptcinput -- `ptcwrite's inner loop, one byte.  apple/fgx#108 T6
 * increment 4a, KTTY export slot 35.
 *
 * UPSTREAM'S LOOP BODY AND NOTHING ELSE.
 * `vendor/2.11BSD/usr/sys/sys/tty_pty.c:432-440':
 *
 *      while (cc > 0) {
 *              if ((tp->t_rawq.c_cc + tp->t_canq.c_cc) >= TTYHOG - 2 &&
 *                 (tp->t_canq.c_cc > 0 ||
 *                    tp->t_flags & (RAW|CBREAK))) {
 *                      wakeup((caddr_t)&tp->t_rawq);
 *                      goto block;
 *              }
 *              (*linesw[tp->t_line].l_rint)(*cp++, tp);
 *              cnt++;
 *              cc--;
 *      }
 *
 * ONE BYTE PER CALL because FGX's chardev write is a per-byte loop
 * (syscall.s:3908) -- the same property that made REMOTE mode undeliverable at
 * increment 6.  So the caller owns `cc' and this owns the body.
 *
 * THE TTYHOG TEST IS THE HALF THAT IS EASY TO LOSE.  What it replaces is
 * `_Pty_InPut' answering C=0 on a full ring, which `_PtyM_Write' blocks on --
 * so FGX has this behaviour today by a different mechanism, and porting the
 * `l_rint' without the guard would swap "block until the slave reads" for
 * "discard once the clist pool runs dry".  NOTHING IN THE SUITE WOULD NOTICE:
 * no fixture writes a master faster than its slave reads.  `ptyhog' is the
 * witness that does.
 *
 * `- 2' AND THE `t_canq' DISJUNCT ARE BOTH UPSTREAM'S and neither is
 * decoration.  The margin leaves room for the two characters `ttyinput' may
 * add for one input byte (an echo of `^X' is two), and the disjunct is what
 * stops a COOKED line blocking forever on a partial line that no terminator
 * will ever complete -- in cooked mode with an empty `t_canq' the writer is
 * allowed past the hog mark, because the line it is building has to be able to
 * finish.
 *
 * Returns 1 if the byte went to the discipline, 0 if the caller must block,
 * -1 for no such line.  The CALLER blocks: sleeping here would be a tty-bank C
 * context asleep inside a module's write, and `ttread' is the routine that
 * owns waiting on this queue.
 */
int
kc_ptcinput(idx, c)
    int idx;
    int c;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (-1);
    if ((tp->t_rawq.c_cc + tp->t_canq.c_cc) >= TTYHOG - 2 &&
        (tp->t_canq.c_cc > 0 || tp->t_flags & (RAW|CBREAK))) {
        kc_wakeup((char *)&tp->t_rawq);
        return (0);
    }
    (*linesw[tp->t_line].l_rint)(c, tp);
    return (1);
}

/* kc_ttyinput -- THE RECEIVE INTERRUPT'S DOOR INTO THE DISCIPLINE.
 * apple/fgx#108 T6 increment 4b, landed inert: nothing calls this until the
 * heartbeat does.
 *
 * `2.11BSD's dzrint (pdpuba/dz.c) IS THIS ROUTINE': take the character the
 * hardware just delivered, work out which line it belongs to, and hand it to
 * that line's `l_rint' before the discipline has any idea an interrupt
 * happened.  FGX's "hardware" is the 60 Hz heartbeat draining the one-deep
 * Mega II key latch, and the line is whichever virtual console is on screen --
 * a binding toolbox.s already computes, for `^C', under a comment that names
 * `dzrint' by name.
 *
 * IT IS `kc_ptcinput' MINUS THE HOG ARM, and that difference is the whole
 * distinction between the two producers.  `kc_ptcinput' serves `ptcwrite',
 * which has a WRITER to push back on, so it answers 0 at `TTYHOG - 2' and
 * `_PtyM_Write' blocks (2.11BSD tty_pty.c:433-438, `goto block').  A receive
 * interrupt has nobody to block: the key has already been typed.  Upstream
 * does not need one either, because `ttyinput' CARRIES ITS OWN overflow
 * handling -- vendor/2.11BSD/usr/sys/sys/tty.c:994, inside `ttyinput' at :791:
 *
 *      if (tp->t_rawq.c_cc+tp->t_canq.c_cc >= TTYHOG) {
 *              if (tp->t_line == NTTYDISC)
 *                      (void) ttyoutput(CTRL(g), tp);
 *              goto endcase;
 *      }
 *
 * -- it rings the bell and DROPS the character.  Ported verbatim at
 * tty.c:1168.  So the right thing for this seam to do at a full queue is
 * nothing special, and adding a guard here would be an invention.
 *
 * RETURNS 0, or -1 for an index that names no line.  `l_rint' is void
 * upstream; the answer here is the SEAM's, not the discipline's, and it exists
 * because the caller is assembly at interrupt time with no other way to learn
 * that the index was junk.
 *
 * ENTERED THROUGH KTTY_KC_ENTER_IRQ, which is what makes this legal at all:
 * the singleton register file rule (include/kernelc.s) still holds, and this
 * runs on the SECOND file T6 increment 1 built.  `ttyinput' signals, and
 * `kc_gsignal' does its own `_FarSh_KernDP' dance, which was MEASURED valid
 * from the heartbeat -- 4,034 ticks, both directions of workload; see
 * docs/history/plans/tty-kernel-bank.md, "T6 4b MEASURED 2026-08-27". */
/* kc_cdstop -- d_stop, ON THE RAIL.  apple/fgx#108 T6 increment 4b.
 *
 * THE DISCIPLINE CALLS THIS AND NOT `kc_cdstop_now', and the ported callers did
 * not have to change for it: `ttyflush' (tty.c:818) and `ttyinput's `^S' arm
 * (tty.c:1085) are BOTH reachable from the heartbeat since the flip landed -- the
 * second directly, the first through the INTR arm's
 * `if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)'.  `ttymodem' (:905) and
 * `ttioctl' (:1550) reach it only in task context, where this is a straight
 * pass-through.
 *
 * A STOP IS DEFERRED, NOT DROPPED.  What it halts is output already in flight;
 * TS_TTSTOP is set by the caller BEFORE this and takes effect immediately, so
 * nothing new is queued in the meantime.  `kc_ttdrain' performs it.
 *
 * THE LINE IS FOUND BY SCANNING `tty_bound', which holds `dev + 1'.  Five
 * entries, and the alternative is a second dev->idx table to keep in step.  A
 * dev no line owns is DROPPED, which is what an unbound line's stop already
 * did before this existed. */
void
kc_cdstop(dev, rw)
    int dev;
    int rw;
{
    register int i;

    if (tty_irq == 0) {
        kc_cdstop_now(dev, rw);
        return;
    }
    for (i = 0; i < NTTY; i++) {
        if (tty_bound[i] == dev + 1) {
            tty_stoppend[i] = rw + 1;
            tty_deferred = 1;
            return;
        }
    }
}

/* kc_ttdrain -- THE SOFT SITE'S HALF OF THE OUTPUT RAIL.  Restart every line
 * whose output the interrupt deferred.  Returns how many it restarted, so the
 * caller can tell "nothing was marked" from "the slot never ran".
 *
 * BOTH DRAIN SITES ARE KERNEL-DP CONTEXTS AND BOTH MAY ENTER C.  `_Sys_CheckSignal'
 * obviously may.  The swtch IDLE LOOP may too, and that is worth stating
 * because signal.s says the opposite about `_kTtyFlushPend' -- "one of that
 * routine's two callers is the swtch idle loop, where entering the shared
 * kernel-C register file is not safe".  THAT COMMENT PREDATES apple/fgx#204.
 * `_KcDp_Save' (sched.s:297) is unconditional now and runs BEFORE the pick;
 * `_KcDp_Rest' (:390) runs only on the success path after it; and the idle arm
 * `@sw_none' (:435) sits between them, re-entering `@sw_pick' when it is done.
 * So in the idle loop the shared band belongs to nobody: the outgoing task's
 * copy is already in its slot and the incoming task's has not been restored.
 *
 * IT MATTERS THAT BOTH SITES WORK.  A cooked line wakes its reader on a LINE
 * DELIMITER, so between the first keystroke and Enter no syscall need happen at
 * all -- and with only `_Sys_CheckSignal' draining, every character typed
 * before the newline would echo late, in a burst, when the line was submitted. */
/* kc_ttgetraw -- one RAW byte from line `idx'.  KTTY slot 40, T6 increment 4b.
 *
 * SYS_GETKEY and SYS_POLLKEY read the caller's CONTROLLING TERMINAL through
 * this.  Until this increment they dequeued `_kKbdRing', a second copy of the
 * keystroke that no fd named -- so a program on a pty read the physical
 * console (`ptykey' measures exactly that), and once T6 4b's flip retired the
 * pump nothing drained that ring at all, so it saturated and served keys
 * minutes old.
 *
 * `tty_tty.c' is the upstream this follows: resolve the controlling terminal,
 * then do the ordinary thing to it.  The resolve is `_Se_CurCtty' in the core
 * (syscall.s `_Key_Uio'); this is the "ordinary thing".
 *
 * MODE-INDEPENDENT, WHICH IS WHY IT IS NOT `kc_ttread'.  "One raw key" is the
 * contract -- more(1)'s pager key, worm and robots steering, ping's interrupt
 * check -- so it cannot wait for a line terminator.  Upstream has no such
 * syscall: a program that wants raw keys sets CBREAK and reads, and this is
 * that pair for callers with no fd to set modes on.
 *
 * Answers: the byte, -1 when there is none, -2 when a signal interrupted the
 * wait.  `nonblock' picks which of the first two an empty queue gives.
 */
int
kc_ttgetraw(idx, nonblock)
    int idx;
    int nonblock;
{
    register struct tty *tp;
    int s, c;

    if (idx < 0 || idx >= NTTY)
        return (-1);
    if (tty_bound[idx] == 0)
        return (-1);
    tp = &ttys[idx];
    for (;;) {
        s = spltty();
        if (tp->t_rawq.c_cc > 0) {
            c = getc(&tp->t_rawq);
            splx(s);
            return (c & 0377);
        }
        if (nonblock) {
            splx(s);
            return (-1);
        }
        /* INTERRUPTIBLE, for `ttread's reason: a `^C' flushes this very queue
         * and wakes us, so an uninterruptible sleep would find it empty, loop,
         * and never reach the syscall boundary where the signal is delivered. */
        if (kc_sleepi(&tp->t_rawq)) {
            splx(s);
            return (-2);
        }
        splx(s);
    }
}

int
kc_ttdrain()
{
    register struct tty *tp;
    register int i;
    int n;
    int rw;

    n = 0;
    for (i = 0; i < NTTY; i++) {
        tp = &ttys[i];
        /* STOPS BEFORE RESTARTS.  A `^S' that arrived in the same tick as an
         * echo must halt the line before anything restarts it -- and it would
         * anyway, because TS_TTSTOP is the first thing `tty_oproc' tests, but
         * ordering it here means the two do not depend on that. */
        if (tty_stoppend[i]) {
            rw = tty_stoppend[i] - 1;
            tty_stoppend[i] = 0;
            kc_cdstop_now((int)tp->t_dev, rw);
            n++;
        }
        if (tp->t_state & TS_TIMEOUT) {
            ttrstrt(tp);
            n++;
        }
    }
    return (n);
}

int
kc_ttyinput(idx, c)
    int idx;
    int c;
{
    register struct tty *tp;
    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (-1);
    /* `tty_irq' IS WHAT MAKES THE OUTPUT SIDE DEFER, and it is set HERE rather
     * than by the caller because this routine IS the definition of "the
     * discipline is running at interrupt time".  A caller that had to remember
     * to set it is a caller that will one day forget. */
    tty_deferred = 0;
    tty_irq = 1;
    (*linesw[tp->t_line].l_rint)(c, tp);
    tty_irq = 0;
    /* 1 SAYS "SOMETHING WAS DEFERRED", so the ISR can set the core's summary
     * word without a second crossing to ask.  BOTH MARKERS SET IT -- the output
     * one in `tty_oproc' and the stop one in `kc_cdstop' -- because a tick can
     * defer either, and a `^S' with no echo behind it would otherwise leave the
     * summary clear and the stop stranded. */
    return (tty_deferred);
}

/* kc_ptcwritable -- `ptcselect's FWRITE arm.  T6 increment 4a, KTTY slot 37.
 *
 * "CAN A MASTER WRITE WITHOUT BLOCKING?", and it is the exact complement of
 * `kc_ptcinput' above -- deliberately, because a select that disagrees with
 * the write it predicts is worse than no select at all.
 * `vendor/2.11BSD/usr/sys/sys/tty_pty.c:395-402':
 *
 *      if (tp->t_rawq.c_cc + tp->t_canq.c_cc < TTYHOG-2)
 *              return (1);
 *      if (tp->t_canq.c_cc == 0 &&
 *          (tp->t_flags & (RAW|CBREAK)) == 0)
 *              return (1);
 *
 * The second clause is the cooked exception `kc_ptcinput' carries as a
 * disjunct: a cooked line with an empty canonical queue is writable past the
 * hog mark, because the line being built has to be able to finish.
 *
 * WHAT IT REPLACES AND WHY THAT WAS BROKEN.  `_PtyM_Poll' answered POLLOUT
 * from `PTYR_InCount < PTY_RING_SZ'.  T6 increment 4a stopped feeding that
 * ring, so the count is pinned at 0 and the answer became "always writable" --
 * while `_PtyM_Write' refuses at TTYHOG with EAGAIN.  **A select that promises
 * a write which then fails is the one answer select exists to prevent**, and
 * `_PtyS_Poll's own header says exactly that about the identical bug one
 * increment earlier.
 *
 * PF_REMOTE'S ARM IS NOT PORTED, and it does not need to be: increment 6
 * settled that FGX has no REMOTE mode and `TIOCREMOTE' answers ENOTTY, so
 * `pt_flags & PF_REMOTE' is never set and upstream's `t_canq.c_cc == 0'
 * branch above it is unreachable here.  Stated rather than silently dropped.
 */
int
kc_ptcwritable(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    if (tp->t_rawq.c_cc + tp->t_canq.c_cc < TTYHOG - 2)
        return (1);
    if (tp->t_canq.c_cc == 0 && (tp->t_flags & (RAW|CBREAK)) == 0)
        return (1);
    return (0);
}

/* kc_irqprobe -- the interrupt-time register file's callee.  T6 increment 1.
 *
 * `src/kernel/far/kc_probe.c' IN THE TTY BANK, and written for the same reason
 * that one gives: it exists so a bracket that nothing else calls is a contract
 * something has tested.  What differs is which bracket -- this one is reached
 * through `KTTY_KC_ENTER_IRQ', the SECOND register file (include/kernelc.s).
 *
 * IT IS BUILT TO TOUCH THE REGISTER FILE, and that is not decoration.  The
 * first version of `_KcIrqProbe' called `kc_ttstopped' instead, on the
 * reasoning that any C would do -- and it went RED, correctly: fcc kept the
 * whole of that routine in A/X/Y and wrote not one promoted-local slot.  Its
 * far twin records the same trap in advance ("A function that only added its
 * two arguments would pass with no direct page at all"), which is the second
 * time that paragraph has been paid for.  So, as there:
 *
 *   - a local ARRAY, which forces a real frame and makes the prologue seed
 *     `_fcc_fb' and the epilogue restore it;
 *   - walked through a POINTER, which routes every load and store through
 *     `_fcc_ptr';
 *   - accumulated ACROSS iterations, so one clobbered slot changes the answer
 *     rather than being masked.
 *
 * WHAT IT CANNOT PROVE IS WHICH PAGE IT RAN ON -- it writes every slot it later
 * reads, so it is self consistent anywhere.  That is the caller's job, and
 * `_KcIrqProbe' does it by pattern-filling the OTHER page and checking the
 * pattern survives.  Read that routine's header before changing this one.
 *
 * kc_irqprobe(seed) returns seed*4 + 6.  The caller passes 9 and expects 42,
 * deliberately the same arithmetic its far twin uses: two probes that disagree
 * about their own answer would be one more thing to reason about.
 */
int
kc_irqprobe(seed)
    int seed;
{
    int  cell[4];
    int *p;
    int  i;
    int  sum;

    p = cell;
    for (i = 0; i < 4; i++)
        p[i] = seed + i;

    sum = 0;
    for (i = 0; i < 4; i++)
        sum = sum + p[i];

    return (sum);
}

/* kc_splprobe -- proof that `spltty()'/`splx()' are a bracket and not a pair of
 * zeroes.  apple/fgx#108 T6 increment 2, KTTY export slot 34.
 *
 * THE 53-FIXTURE WITNESS CANNOT DO THIS JOB.  It stayed green across increment
 * 2 -- which is exactly right, because nothing about behaviour was supposed to
 * change -- and a suite that would look identical if the macros were still
 * `#define spltty() 0' is not evidence that they are not.  A test that cannot
 * go red is not coverage, so the bracket gets one that can.
 *
 * IT READS THE I FLAG THROUGH THE BRACKET'S OWN RETURN VALUE, which is the one
 * observable the tty bank has without a new seam onto core state:
 *
 *   a  interrupts were ON when we arrived        -> 0
 *   b  ...and the first spltty() masked them     -> 4
 *      splx(b) is handed "they were masked", so it must LEAVE them masked --
 *      this is the nesting the seventy call sites depend on, and the arm that
 *      a splx which simply CLI'd would fail
 *   c  ...so the third ask still sees them masked -> 4
 *
 * 0*100 + 4*10 + 4 = 44.  With the old empty macros every ask is 0 and so is
 * the answer, which is what makes the case discriminate rather than decorate.
 *
 * `a' IS MEASURED AND NOT ASSUMED: _LboltProbe runs immediately before this in
 * main.s and its case 2 watches a real VBL go by, so interrupts are known to be
 * enabled on the way in rather than believed to be.
 */
int
kc_splprobe()
{
    int a;
    int b;
    int c;

    a = spltty();
    b = spltty();
    splx(b);
    c = spltty();
    splx(c);
    splx(a);
    return (a * 100 + b * 10 + c);
}

int
kc_ttstopped(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    if (tp->t_state & TS_TTSTOP)
        return (1);
    return (0);
}

/* kc_ttcarrier -- is the CARRIER up on this line?  KTTY slot 41.
 *
 * `ptcread' decides end of file on the carrier and on nothing else:
 *
 *     if ((tp->t_state&TS_CARR_ON) == 0)
 *         return (0);          -- upstream's own comment here reads "EOF"
 *         -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:268
 *
 * and it asks that AFTER the TS_ISOPEN block has fallen through, so a master
 * whose slave is not open right now BLOCKS rather than reporting EOF.  The
 * driver could not ask this before: TS_CARR_ON lives in `t_state', a bank
 * away, which is why `_PtyM_Read' asked its own PTYF_SOPEN instead and
 * answered EOF in a window where upstream sleeps (apple/fgx#266).
 *
 * Zero for an unbound line, which is what `kc_ttstopped' answers and what the
 * caller wants: no line, no carrier, and the master's read ends.
 */
int
kc_ttcarrier(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    if (tp->t_state & TS_CARR_ON)
        return (1);
    return (0);
}

/* kc_ptyoproc -- install or clear `ptsstart' on a line.  KTTY slot 25.
 *
 * `ptcopen' does `tp->t_oproc = ptsstart' and `ptcclose' does `tp->t_oproc = 0'
 * (tty_pty.c:213, :231); this is those two lines, on the side of the bank where
 * the function's address means something.
 *
 * ZERO IS UPSTREAM'S CLEARED VALUE and it is safe here for upstream's own
 * reason: `ttstart' tests `tp->t_oproc' before calling through it -- its
 * comment there is "kludge for pty" -- so a line whose master has gone queues
 * output and drains nothing, rather than jumping through a zero.
 */
int
kc_ptyoproc(idx, on)
    int idx;
    int on;
{

    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    if (on)
        tp->t_oproc = ptsstart;
    else
        tp->t_oproc = 0;
    return (0);
}

/* kc_ttoutq_run -- how many contiguous bytes the master may take now.
 * KTTY slot 26.
 *
 * `ndqb' IS THE SAME PRIMITIVE `tty_oproc' USES, and this is deliberate: the
 * drain above asks the queue for a run, moves it and flushes it, and the only
 * thing increment 4 changes is who calls the pair.  Reusing it keeps ONE answer
 * to "what may leave the queue next" rather than two that can disagree.
 *
 * EVERY BYTE IS DATA, as it is to `ptcread', which takes the queue with
 * `q_to_b(&tp->t_outq, buf, ...)' (vendor/2.11BSD/usr/sys/sys/tty_pty.c:278)
 * and interprets nothing -- so a byte above 0177, which PASS8 lets
 * `ttyoutput' queue, reaches the master as itself.
 *
 * ZERO FOR A STOPPED LINE, and that is `ptcread's own test: `if (tp->t_outq.c_cc
 * && (tp->t_state&TS_TTSTOP) == 0) break;'.  A stopped line has nothing
 * available even when it has bytes.
 */
int
kc_ttoutq_run(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    if (tp->t_state & TS_TTSTOP)
        return (0);
    return (ndqb(&tp->t_outq, 0));
}

/* kc_ttoutq_cf -- where that run starts, as an offset in this bank.
 * KTTY slot 27.
 *
 * A SECOND CALL RATHER THAN A SECOND RETURN VALUE.  fcc returns a long in A and
 * `_fcc_long_hi', so one slot could hand back offset and count together -- and
 * would put a long shift on the path for the sake of one crossing per RUN, not
 * per byte.  A run is a whole cblock or more, fcc's long arithmetic has a
 * defect history of its own (apple/fgx#209), and the caller wants the count
 * first anyway to know whether to ask.
 *
 * `ndqb' HAS NO SIDE EFFECT, so the offset is still valid when this is called
 * after it: the scan counts and returns, and only the marker drop above touches
 * the queue.  The offset is `c_cf', the first byte the queue will give up --
 * the same pointer `tty_oproc' hands `kc_cdwrite'.
 */
int
kc_ttoutq_cf(idx)
    int idx;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (0);
    return ((int)tp->t_outq.c_cf);
}

/* kc_ttoutq_flush -- the run has been taken; drop it and wake a blocked writer.
 * KTTY slot 28.
 *
 * `ndflush' is `tty_oproc's own third line.  `ttyowake' rides with it because
 * that is where upstream puts it: `ptcread' wakes a writer parked at hiwat once
 * `c_cc <= TTLOWAT(tp)', and the flush is the moment `c_cc' drops.  Putting it
 * in the caller would mean every future caller had to remember.
 */
int
kc_ttoutq_flush(idx, cc)
    int idx;
    int cc;
{
    register struct tty *tp;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    if (cc > 0)
        ndflush(&tp->t_outq, cc);
    ttyowake(tp);
    return (0);
}

/* kc_ttoutq_uio -- take runs out of `t_outq' into a uio.  KTTY slot 29.
 *
 * `ptcread's body, near enough to read as the port it is (2.11BSD
 * tty_pty.c:277-283):
 *
 *      while (uio->uio_resid && error == 0) {
 *              cc = q_to_b(&tp->t_outq, buf, MIN(uio->uio_resid, BUFSIZ));
 *              if (cc <= 0) break;
 *              error = uiomove(buf, cc, uio);
 *      }
 *
 * NO STAGING BUFFER, AND UPSTREAM'S REASON FOR ONE DOES NOT APPLY.  Reno
 * copies through `char buf[BUFSIZ]' because `q_to_b' walks a chain of cblocks
 * and there is no contiguous form to hand `uiomove'.  `ndqb' answers with a
 * CONTIGUOUS RUN -- it is what `tty_oproc' hands `kc_cdwrite' -- so the bytes
 * go where they lie, one run at a time.  That is upstream's structure with
 * FGX's primitive, not a divergence: `tty_oproc' has taken runs this way since
 * T3 stage 3.
 *
 * WHY THIS EXISTS BESIDE `_Tty_OutqRead' (the core's MVN loop) RATHER THAN
 * INSTEAD OF IT.  FGX has two master-read paths and they deliver differently:
 * `_PtyM_Read' is the RECORD-mode syscall op and writes to
 * `_Sys_CallerBank:_Sys_RdBufOff', while `_PtyM_DRead' is cdevsw's `d_read'
 * for the /dev vnode route and writes through a uio (apple/fgx#198).  The
 * QUEUE work is identical and is not duplicated -- both go through
 * `kc_ttoutq_run' and `kc_ttoutq_flush' below -- only the delivery differs.
 *
 * THE REJECTED ALTERNATIVE, because it is the one that reads cheaper: have
 * `_PtyM_DRead' unpack its uio and stage the base and bank into the two
 * `_Sys_*' cells, so one door serves both.  That is a driver writing statics
 * its signature never mentions, which is apple/fgx#198's shape and #231's, and
 * this campaign has paid for that reading twice.
 */
int
kc_ttoutq_uio(idx, uio)
    int idx;
    register struct uio *uio;
{
    register struct tty *tp;
    register int cc;
    int error;

    tp = tty_byidx(idx);
    if (tp == (struct tty *)0)
        return (ENXIO);
    error = 0;
    while (uio->uio_resid) {
        cc = kc_ttoutq_run(idx);
        if (cc == 0)
            break;                      /* queue empty, or the line is stopped */
        if (cc > uio->uio_resid)
            cc = uio->uio_resid;
        error = kc_uiomove(tp->t_outq.c_cf, cc, uio);
        if (error)
            break;                      /* the run is NOT flushed: nothing moved */
        (void) kc_ttoutq_flush(idx, cc);
    }
    return (error);
}

/* tty_devinit -- bind every registered tty device to its struct tty.
 *
 * Called once at boot, before anything dispatches.  It does NOT invent the
 * bindings: it asks the registry for each device in turn and records what came
 * back, so this array cannot disagree with the registry about which tty a
 * device is -- there is one answer and it lives there.
 *
 * Returns how many devices bound.  A zero on a booted machine is a broken
 * lookup rather than a machine with no terminals, which is why the probe
 * checks the count rather than only that the calls returned.
 */
int
tty_devinit()
{
    int dev;
    int idx;
    int bound;

    for (idx = 0; idx < NTTY; idx++) {
        tty_bound[idx] = 0;
        ttys[idx].t_dev = (dev_t)0;
        /* NTTYDISC, NOT OTTYDISC, and the flip is what forced the question.
         * `ttyinput's SUSPEND arm is inside
         * `if (tp->t_line == NTTYDISC)' (tty.c:1053, arm :1072), so the moment
         * the heartbeat stops hand-coding `^Z' the discipline has to be the one
         * that owns it.  The INTR/QUIT arm (:1096) is NOT gated and works
         * either way.
         *
         * WHAT ELSE COMES ALIVE, all already ported and all currently
         * unreachable: `^V' literal-next (:1054), `^O' flush-output (:1060),
         * `^W'/`^R' word and line rubout, and the TTYHOG bell (:1169).
         *
         * IT IS WHAT 2.11BSD LINES LOOK LIKE AFTER getty.  Upstream binds at
         * OTTYDISC and lets `getty'/`stty new' promote the line through
         * TIOCSETD (tty.c:1491); FGX has no getty that issues one, and
         * TIOCSETD is the only other writer -- so a line bound at OTTYDISC
         * here would stay there for the life of the machine.  Binding at
         * NTTYDISC states the intent once instead of leaving every FGX line in
         * a pre-getty state nothing ever leaves.  `linesw's NTTYDISC row is
         * fully populated (tty_conf.c:146-148); this is a one-word change. */
        ttys[idx].t_line = NTTYDISC;
    }

    return (tty_devbind());
}


/* tty_devbind -- bind every tty device that is not bound yet.  The second half
 * of tty_devinit, split out so it can run AGAIN.
 *
 * A LINE WHOSE DRIVER ARRIVES AFTER BOOT WOULD OTHERWISE NEVER BIND, and one
 * does.  Every tty line except the serial one is registered by the KERNEL
 * before tty_devinit runs (chardev.s:1197-1249); /dev/tty01 is registered by
 * serial.mod, which says which line it is through KSVC_CDSETTTYIDX -- and
 * modules load from /etc/rc, which is userland and runs long after
 * main.s's one call to tty_devinit.  So tty_bound[5] stayed 0, tty_byidx(5)
 * answered NULL, and the receive interrupt had no line to hand a character to.
 * That is apple/fgx#108 T7's defect returning by a different road: the module
 * moved, not the binding.
 *
 * RE-RUNNING THIS HALF IS SAFE AND RE-RUNNING tty_devinit IS NOT, which is the
 * whole reason for the split.  The loop below skips any line already bound, so
 * a second pass can only fill gaps.  The half above it ZEROES tty_bound and
 * resets t_line, t_dev and t_oproc on every line -- run twice, that would take
 * the console's discipline and output routine out from under a live session.
 */
int
tty_devbind()
{
    int dev;
    int idx;
    int bound;

    bound = 0;
    for (dev = 0; dev < CHARDEV_MAX; dev++) {
        idx = kc_cdttyidx(dev);
        if (idx < 0 || idx >= NTTY)
            continue;               /* no such device, or not a tty */
        /* TWO DEVICES CLAIMING ONE TTY IS A REGISTRY BUG, not something to
         * average.  Keep the first and let the probe see the count come up
         * short rather than silently rebinding. */
        if (tty_bound[idx] != 0)
            continue;
        /* t_dev is upstream's field and this is upstream's use of it: a
         * driver's ops get a dev and need to get back here. */
        ttys[idx].t_dev = (dev_t)dev;
        /* THE OUTPUT ROUTINE, bound with the device and for the same reason:
         * `ttstart' tests `tp->t_oproc' before calling it (tty.c:240, upstream's
         * "kludge for pty"), so a line that never bound has no output routine
         * and `ttwrite' on it queues and drains nothing rather than jumping
         * through a zero.  apple/fgx#108 T3 stage 3. */
        ttys[idx].t_oproc = tty_oproc;
        /* AND THE LINE IS CARRYING, because it has a device on it.
         *
         * `ttwrite' opens with `if (!(tp->t_state&TS_CARR_ON))' and, for a
         * blocking write on a line that is neither carrying nor open, SLEEPS
         * ON t_rawq WAITING FOR CARRIER -- forever, on a machine where nothing
         * raises it.  TS_CARR_ON is set by `ttymodem' (tty.c:268), which is
         * `l_modem' and still an adapter, so before stage 3 nothing in FGX had
         * ever set it and nothing had ever asked.
         *
         * UPSTREAM'S OWN IDIOM FOR A DEVICE WITH NO MODEM, and it is one line:
         * `ptsopen' (usr/sys/sys/tty_pty.c:77) is
         *     if (tp->t_oproc)            'Ctrlr still around.'
         *         tp->t_state |= TS_CARR_ON;
         * -- the presence of an output routine IS the carrier.  Every FGX line
         * is a console, a virtual console or a pty slave; not one has a modem,
         * and all three are exactly as present as their binding.
         *
         * TS_ISOPEN IS NOT SET HERE, deliberately.  It belongs to `ttyopen'
         * (tty.c:2159), which is `l_open' and repoints when the OPEN path
         * moves.  ttwrite consults it only when carrier is absent, which it no
         * longer is, so claiming it now would be this stage writing state a
         * routine it does not own is responsible for. */
        ttys[idx].t_state |= TS_CARR_ON;
        /* AND THE LINE GETS A PERSONALITY, which is the third thing upstream
         * does at open and the one T7 left out (apple/fgx#247).  `dzopen':
         *
         *      if ((tp->t_state & TS_ISOPEN) == 0) {
         *              ttychars(tp);
         *              ...
         *              tp->t_flags = IFLAGS;
         *      }
         *          -- vendor/2.11BSD/usr/sys/pdpuba/dz.c:130-140
         *
         * Without it a bound line has t_flags 0 and every control character 0:
         * no `^C', no `^U', and no `^S', because `CCEQ(tp->t_stopc, c)' cannot
         * match a zero.  The serial line shipped that way and it is why
         * `serial_stop' had no witness -- `ttyinput's stop arm could never fire.
         *
         * AT BIND TIME, NOT AT OPEN, for the reason the two lines above it are:
         * FGX HAS NO getty to configure a line, so a line that is not seeded
         * here is never seeded at all.  It is also where the other lines
         * already get theirs -- main.s for tty[0], ttyv.s for the virtual
         * consoles -- so this generalises an existing rule rather than adding
         * one, and those seeds still run afterwards with the same values.
         *
         * TWO PLACEMENTS CLOSER TO UPSTREAM WERE TRIED AND REVERTED, and the
         * issue carries their measurements: seeding from the driver's open op
         * HUNG THE MACHINE, because a chardev op runs inside
         * `_Chardev_Dispatch', which self-modifies one shared trampoline cell;
         * seeding from the module's init broke the boot.  Here there is no
         * cross-bank call at all -- `ttychars' is upstream's own routine and it
         * is in this bank, three functions away. */
        ttychars(&ttys[idx]);
        ttys[idx].t_flags = ECHO | CRMOD;
        tty_bound[idx] = dev + 1;
        bound = bound + 1;
    }
    return (bound);
}

/* kc_ttioctl -- the CORE bank's door into ttioctl (apple/fgx#108 T3 stage 2).
 *
 * `_IoOp_TtyAtX' (syscall.s) answers three commands the discipline has no
 * counterpart for -- TIOCISCONS, TIOCNOTTY and FIODGNAME -- and hands
 * everything else here.  That is upstream's order, not an FGX invention:
 * `usr/sys/sys/tty_pty.c:508-527' has the pty driver take the commands that
 * are its own and then fall through to `ttioctl(tp, cmd, data, flag)' for the
 * rest.  TIOCNOTTY is NOT the discipline's there either -- `syioctl' answers
 * it before any dispatch, at `usr/sys/sys/tty_tty.c:58':
 *
 *      if (cmd == TIOCNOTTY) {
 *              u.u_ttyp = 0;
 *              u.u_ttyd = 0;
 *              u.u_procp->p_pgrp = 0;
 *              return (0);
 *      }
 *
 * TIOCISCONS and FIODGNAME have no 2.11BSD counterpart at all and stay core.
 *
 * THE INDEX IS BOUNDS-CHECKED AND BOUND-CHECKED, not just bounds-checked.  A
 * `struct tty' nothing registered is zeroed memory that answers every field
 * plausibly, which is the same trap tty_find's header names -- so an ioctl on
 * a line no device claimed must be ENOTTY rather than a successful read of
 * zeroes.
 *
 * THE RETURN IS THREE-WAY and the caller depends on all three: 0 handled,
 * -1 "not one of mine", and any positive value an errno.  The -1 is upstream's
 * own -- `usr/sys/sys/tty.c:571' is ttioctl's default arm, `return (-1);',
 * against `return (0)' two lines later for the handled case.  Keeping it
 * distinct from an errno is what lets a command the discipline does not know
 * fall back to the core's answer instead of being reported as a failure.
 */
int
kc_ttioctl(idx, com, data, flag)
    int idx;
    int com;
    char *data;
    int flag;
{
    if (idx < 0 || idx >= NTTY)
        return (ENOTTY);
    if (tty_bound[idx] == 0)
        return (ENOTTY);
    return (ttioctl(&ttys[idx], com, data, flag));
    return (ttioctl(&ttys[idx], com, data, flag));
}

/* kc_ttychars -- give one line the default special characters.
 *
 * The core bank's door onto `ttychars' (tty.c:223), which is
 * `tp->t_chars = ttydefaults' and nothing else.  It exists because
 * `_Tty_CookedDefaults' (pty.s) used to make these nine stores into
 * `_ttyTable' itself, and T3 stage 2b moves the tchars and ltchars images into
 * `ttys[]' where `ttioctl' already reads and writes them.
 *
 * THE VALUES WERE COMPARED, NOT ASSUMED.  All fourteen of `ttydefaults'
 * (tty.c:216, from ttychars.h) match what the core was storing: CERASE 0177,
 * CKILL ^U, CINTR ^C, CQUIT 034, CSTART ^Q, CSTOP ^S, CEOF ^D, CSUSP ^Z,
 * CDSUSP ^Y, CRPRNT ^R, CFLUSH ^O, CWERASE ^W, CLNEXT ^V.  Only CBRK differs
 * in spelling -- _POSIX_VDISABLE where the core wrote $FFFF -- and both mean
 * "no delimiter character".
 *
 * IT ALSO SETS t_erase AND t_kill, which stage 2b does NOT migrate: they are
 * part of the sgttyb image and move with it.  That is not two copies in the
 * sense the campaign warns about, because nothing READS the bank's copy until
 * then -- `struct tchars' is t_intrc..t_brkc and `struct ltchars' is
 * t_suspc..t_lnextc, so neither TIOCGETC/SETC nor TIOCGLTC/SLTC touches erase
 * or kill.  The bank's pair is write-only until the sgttyb migration, at which
 * point it is already correct.  Stage 2d is that migration and the pair was
 * already right, exactly as written here.
 *
 * THE SPEEDS ARE SET BESIDE THE CHARACTERS BECAUSE UPSTREAM SETS THEM THERE.
 * `tty_pty.c:72-73' is `ttychars(tp); tp->t_ispeed = tp->t_ospeed = EXTB;' --
 * two lines, one after the other, in the open path.  They are the rest of the
 * sgttyb image (`sg_ispeed'/`sg_ospeed'), so stage 2d has to seed them
 * somewhere, and the place upstream picked is this one.
 *
 * B9600 RATHER THAN UPSTREAM'S EXTB, which is what the core's
 * `_Tty_CookedDefaults' has always stored and what `stty' has always reported.
 * Neither is real: no FGX line has a baud rate, the value is nominal, and
 * changing what `stty' prints is not part of this stage.  B9600 is 13 and EXTB
 * is 15 (`usr/sys/h/ttydev.h:31,33').
 */
void
kc_ttychars(idx)
    int idx;
{
    if (idx < 0 || idx >= NTTY)
        return;
    ttychars(&ttys[idx]);
    ttys[idx].t_ispeed = B9600;
    ttys[idx].t_ospeed = B9600;
}
