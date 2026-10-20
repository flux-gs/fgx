/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/tty.h
 *   Ported from usr/sys/h/tty.h, 2.11BSD.
 *   Original work:
 *   Copyright (c) 1982, 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* tty.h -- struct clist and struct tty.
 *
 * WHOLE, NOT THE PART WITH A READER YET.  tty_subr.c uses struct clist and
 * nothing else here; struct tty has no user until the line discipline arrives
 * (T2/T3, apple/fgx#108).  It is carried now anyway, because the ruling for
 * this campaign is to adopt BSD's struct tty and its queues -- and a struct
 * definition emits no bytes, so the cost of having it early is zero and the
 * cost of porting tty.c against a half-shape later is not.
 *
 * MEASURED ON fcc: sizeof(struct tty) is 92, against 82 for the same
 * declaration with a four-character ttychars.  A PDP-11 makes it smaller
 * because its pointers are 2 bytes; five lines is still under a kilobyte,
 * which is what the placement survey costed.
 *
 * struct winsize is upstream's, from usr/sys/h/ioctl.h:62 rather than from
 * here.  It is inlined because T1 needs no other part of ioctl.h and a header
 * whose only content is one struct is a file to open for nothing; when T2's
 * ttioctl arrives it moves out with the rest of the ioctl set.
 *
 * DROPPED, both PDP-11 memory-model artefacts with nothing behind them here:
 * the UCB_CLIST arm (segment-5 mapping for a split I/D kernel) and the
 * SUPERVISOR guard.  KEPT even though nothing reads them: the t_nu union's
 * network half (t_bufp/t_cp/t_inbuf/t_rec), because a union whose second arm
 * is deleted is a struct with a differently-sized first member, and the whole
 * point of carrying the shape is that tty.c ports against it unchanged.
 */
#ifndef _TTY_H_
#define _TTY_H_

#include "ttychars.h"

/* THE THREE ioctl PARAMETER STRUCTS, and they are HERE rather than beside the
 * field aliases below for the reason upstream's own comment gives at the head
 * of that block -- "be careful of tchars & co.".  `struct tchars' names its
 * members t_intrc, t_quitc and so on, which are exactly the names the aliases
 * #define onto t_chars members; defining the structs after them would expand
 * `char t_intrc;' into `char t_chars.tc_intrc;'.  Upstream keeps them apart in
 * h/ioctl.h for the same reason; this file has no ioctl.h to keep them in.
 *
 * THE FIELD ORDER IS LOAD-BEARING, NOT DECORATIVE.  ttioctl's TIOCGETC and
 * TIOCSETC bcopy sizeof(struct tchars) bytes straight to and from
 * `&tp->t_intrc', and TIOCSLTC/TIOCGLTC do the same at `&tp->t_suspc' -- so
 * these six-byte runs must match ttychars.h's tc_intrc..tc_brkc and
 * tc_suspc..tc_lnextc exactly, in order.  2.11BSD h/ioctl.h:22-37. */
struct tchars {
    char    t_intrc;        /* interrupt */
    char    t_quitc;        /* quit */
    char    t_startc;       /* start output */
    char    t_stopc;        /* stop output */
    char    t_eofc;         /* end-of-file */
    char    t_brkc;         /* input delimiter (like nl) */
};

struct ltchars {
    char    t_suspc;        /* stop process signal */
    char    t_dsuspc;       /* delayed stop process signal */
    char    t_rprntc;       /* reprint line */
    char    t_flushc;       /* flush output (toggles) */
    char    t_werasc;       /* word erase */
    char    t_lnextc;       /* literal next character */
};

/* TIOCGETP and TIOCSETP.  2.11BSD h/ioctl.h:45-51. */
struct sgttyb {
    char    sg_ispeed;      /* input speed */
    char    sg_ospeed;      /* output speed */
    char    sg_erase;       /* erase character */
    char    sg_kill;        /* kill character */
    short   sg_flags;       /* mode flags */
};

/* Upstream's ioctl.h:62.  "Type must be unsigned short so that types.h not
 * required" -- upstream's reason, kept. */
struct winsize {
    unsigned short  ws_row;         /* rows, in characters */
    unsigned short  ws_col;         /* columns, in characters */
    unsigned short  ws_xpixel;      /* horizontal size, pixels */
    unsigned short  ws_ypixel;      /* vertical size, pixels */
};

/*
 * A clist structure is the head of a linked list queue
 * of characters.  The characters are stored in blocks
 * containing a link and CBSIZE (ttyparam.h) characters.
 * The routines in tty_subr.c manipulate these structures.
 */
struct clist {
    int     c_cc;           /* character count */
    char   *c_cf;           /* pointer to first char */
    char   *c_cl;           /* pointer to last char */
};

/*
 * Per-tty structure.
 *
 * Should be split in two, into device and tty drivers.
 * Glue could be masks of what to echo and circular buffer
 * (low, high, timeout).
 */
struct tty {
    union {
        struct {
            struct  clist T_rawq;
            struct  clist T_canq;
        } t_t;
        struct {
            struct  buf *T_bufp;
            char        *T_cp;
            int          T_inbuf;
            int          T_rec;
        } t_n;
    } t_nu;
    struct  clist t_outq;       /* device */
    int     (*t_oproc)();       /* device */
    struct  proc *t_rsel;       /* tty */
    struct  proc *t_wsel;
            caddr_t T_LINEP;    /* ### */
    caddr_t t_addr;             /* ??? */
    dev_t   t_dev;              /* device */
    long    t_flags;            /* some of both */
    long    t_state;            /* some of both */
    short   t_pgrp;             /* tty */
    char    t_delct;            /* tty */
    char    t_line;             /* glue */
    char    t_col;              /* tty */
    char    t_ispeed, t_ospeed; /* device */
    char    t_rocount, t_rocol; /* tty */
    struct  ttychars t_chars;   /* tty */
    struct  winsize t_winsize;  /* window size */
};

#define t_rawq  t_nu.t_t.T_rawq     /* raw characters or partial line */
#define t_canq  t_nu.t_t.T_canq     /* raw characters or partial line */
#define t_bufp  t_nu.t_n.T_bufp     /* buffer allocated to protocol */
#define t_cp    t_nu.t_n.T_cp       /* pointer into the ripped off buffer */
#define t_inbuf t_nu.t_n.T_inbuf    /* number chars in the buffer */
#define t_rec   t_nu.t_n.T_rec      /* have a complete record */

/* be careful of tchars & co. */
#define t_erase     t_chars.tc_erase
#define t_kill      t_chars.tc_kill
#define t_intrc     t_chars.tc_intrc
#define t_quitc     t_chars.tc_quitc
#define t_startc    t_chars.tc_startc
#define t_stopc     t_chars.tc_stopc
#define t_eofc      t_chars.tc_eofc
#define t_brkc      t_chars.tc_brkc
#define t_suspc     t_chars.tc_suspc
#define t_dsuspc    t_chars.tc_dsuspc
#define t_rprntc    t_chars.tc_rprntc
#define t_flushc    t_chars.tc_flushc
#define t_werasc    t_chars.tc_werasc
#define t_lnextc    t_chars.tc_lnextc

#define TTIPRI  28
#define TTOPRI  29

/* limits */
#define NSPEEDS 16
#define TTMASK  15
/* OBUFSIZ IS GONE, AND THE BUFFER IS IN THE U-AREA -- apple/fgx#246.
 *
 * It was 100, upstream's (`vendor/2.11BSD/usr/sys/h/tty.h:95'), and the value
 * was never the problem; the PLACE was.  `char obuf[OBUFSIZ]' is a kernel-stack
 * local upstream, and a PDP-11 kernel stack can afford it.  FGX_KSTK_SIZE is
 * 512 and the `/dev' vnode road reaches `ttwrite' with the whole `vn_write' ->
 * `spec_write' -> `spec_chwrite' -> `kc_cddwrite' chain of fcc frames still
 * standing under it -- measured at 516 of 512, a wild write below the stack
 * and a machine reset with no diagnostic, since `_fcc_stkfloor' is left at
 * zero on FGX_DP_KERNELC.
 *
 * `U_TTYOBUF_LEN' (include/kernel.s) is the one authority on the length now,
 * and `ttwrite' asks `kc_ttobufsz()' where it used to spell OBUFSIZ -- so the
 * chunk size and the reservation cannot disagree.  Keeping a #define here as
 * well would have re-created exactly the second copy this move removes.
 *
 * THE OLD NOTE HERE IS WORTH CARRYING, because it is about a WRONG diagnosis
 * of this same symptom: the value sat at 16 for two weeks, blamed on a
 * kernel-stack overflow, and it was apple/fgx#234 -- kernel C reconstituted
 * bank 0 for every runtime int-to-pointer cast, so `cinit' built the clist
 * free chain inside the user-stack arena and a spawn's STK_PAINT fill
 * overwrote its links.  "The same run twice at two offsets" is what a queue
 * reads back when its chain has been rewritten under it, and it looked like an
 * overflow of the buffer that happened to be nearby.  That is why THIS time
 * the stack was measured -- painted arena, four numbers, one variable -- before
 * anything moved.
 *
 * `catq's 16-byte `bbuf' is still shrunk on that old wrong premise and is
 * still not restored: at 112 bytes it is a real frame, and it wants the same
 * measurement this one got. */


/* internal state bits */
#define TS_TIMEOUT  0x000001L   /* delay timeout in progress */
#define TS_WOPEN    0x000002L   /* waiting for open to complete */
#define TS_ISOPEN   0x000004L   /* device is open */
#define TS_FLUSH    0x000008L   /* outq has been flushed during DMA */
#define TS_CARR_ON  0x000010L   /* software copy of carrier-present */
#define TS_BUSY     0x000020L   /* output in progress */
#define TS_ASLEEP   0x000040L   /* wakeup when output done */
#define TS_XCLUDE   0x000080L   /* exclusive-use flag against open */
#define TS_TTSTOP   0x000100L   /* output stopped by ctl-s */
#define TS_HUPCLS   0x000200L   /* hang up upon last close */
#define TS_TBLOCK   0x000400L   /* tandem queue blocked */
#define TS_RCOLL    0x000800L   /* collision in read select */
#define TS_WCOLL    0x001000L   /* collision in write select */
#define TS_ASYNC    0x004000L   /* tty in async i/o mode */
/* state for intra-line fancy editing work */
#define TS_ERASE    0x040000L   /* within a \.../ for PRTRUB */
#define TS_LNCH     0x080000L   /* next character is literal */
#define TS_TYPEN    0x100000L   /* retyping suspended input (PENDIN) */
#define TS_CNTTB    0x200000L   /* counting tab width; leave FLUSHO alone */

#define TS_LOCAL    (TS_ERASE|TS_LNCH|TS_TYPEN|TS_CNTTB)

/* t_flags -- the sgtty mode bits, from `usr/sys/h/ioctl.h:137-168'.
 *
 * INLINED HERE the way `struct winsize' already is, and for the same reason
 * the note on that says: the bank needs these and no other part of ioctl.h,
 * whose bulk is _IO/_IOR/_IOW request numbers FGX does not use -- its ioctl
 * numbering is include/loader.s's.
 *
 * THE VALUES AGREE WITH FGX's OWN SG_* ALREADY, which is worth stating because
 * it is what makes the port a drop-in rather than a translation: include/
 * loader.s has SG_CRMOD $0010 and SG_RAW $0020 against CRMOD 0x10 and RAW 0x20
 * here.  FGX's sgtty ABI IS BSD's; the assembly and C spellings of one bit are
 * two names for the same value, not two conventions.
 *
 * LONG, and that is load-bearing on a 16-bit-int compiler: the field is
 * `long t_flags' and eleven of these bits are above 0xFFFF.  A bare 0x00800000
 * would be truncated silently, so every constant carries its L.
 */
#define TANDEM      0x00000001L /* send stopc on out q full */
#define CBREAK      0x00000002L /* half-cooked mode */
                                /* 0x4 (old LCASE) */
#define ECHO        0x00000008L /* echo input */
#define CRMOD       0x00000010L /* map \r to \r\n on output */
#define RAW         0x00000020L /* no i/o processing */
#define ODDP        0x00000040L /* get/send odd parity */
#define EVENP       0x00000080L /* get/send even parity */
#define ANYP        0x000000c0L /* get any parity/send none */
#define XTABS       0x00000400L /* expand tabs on output */
#define CRTBS       0x00010000L /* do backspacing for crt */
#define PRTERA      0x00020000L /* \ ... / erase */
#define CRTERA      0x00040000L /* " \b " to wipe out char */
#define MDMBUF      0x00100000L /* start/stop output on carrier intr */
#define LITOUT      0x00200000L /* literal output */
#define TOSTOP      0x00400000L /* SIGSTOP on background output */
#define FLUSHO      0x00800000L /* flush output to terminal */
#define NOHANG      0x01000000L /* no SIGHUP on carrier drop */
#define RTSCTS      0x02000000L /* use RTS/CTS flow control */
#define CRTKIL      0x04000000L /* kill line with " \b " */
#define PASS8       0x08000000L
#define CTLECH      0x10000000L /* echo control chars as ^X */
#define PENDIN      0x20000000L /* tp->t_rawq needs reread */
#define DECCTQ      0x40000000L /* only ^Q starts after ^S */
#define NOFLSH      0x80000000L /* no output flush on signal */

/* The two modem-control requests ttyblock and ttyunblock issue, and the one
 * bit they carry.  `usr/sys/h/ioctl.h:213' (TIOCMBIC), `:212' (TIOCMBIS) and
 * `:120' (TIOCM_RTS).
 *
 * THE VALUES ARE UPSTREAM'S KERNEL ENCODING, NOT ITS USERLAND ONE, and the
 * distinction is the whole reason these are written out rather than computed.
 * ioctl.h defines _IOW twice: under `#ifdef KERNEL' it is `(('x'<<8)|y)', and
 * outside it the 32-bit `IOC_IN|size<<16|('x'<<8)|y'.  tty.c is kernel code, so
 * TIOCMBIS is ('t'<<8)|108 == 0x746C and TIOCMBIC is ('t'<<8)|107 == 0x746B.
 * The 32-bit spelling would be a number no FGX driver could ever match.
 *
 * THAT IS ALSO FGX's OWN ENCODING, which is what makes them safe to introduce:
 * include/loader.s has TIOCGETP $7408, and upstream's is _IOR(t, 8, ...) --
 * the same ('t'<<8)|y under KERNEL.  These two extend a numbering FGX already
 * uses rather than starting a second one.
 *
 * NOTHING IMPLEMENTS THEM YET, and that is not a gap this increment leaves
 * open by accident.  No FGX character device has modem-control lines, so every
 * one answers ENOTTY, and the arm that issues these does not fire -- which is
 * the correct behaviour for a device with no RTS to drop, not a stub.  Nor can
 * the arm be reached today: it is gated on RTSCTS and nothing in FGX sets that
 * bit.  Carried because the port carries it; see the note in ttyblock.
 */
/* THE ioctl COMMANDS ttioctl SWITCHES ON.  2.11BSD h/ioctl.h, KERNEL forms.
 *
 * `_IO(x,y)', `_IOR(x,y,t)' and `_IOW(x,y,t)' are all (('x'<<8)|y) under
 * #ifdef KERNEL (ioctl.h:95-98), so every value below is one letter and one
 * ordinal, written out for the reason the block above gives.
 *
 * HALF OF THESE ALREADY EXIST IN include/loader.s AND THE VALUES AGREE, which
 * is what makes them safe to introduce here rather than a second numbering:
 * TIOCGETP $7408 = ('t'<<8)|8 against upstream's _IOR(t,8,struct sgttyb);
 * TIOCGPGRP $7477 = |119; TIOCSPGRP $7476 = |118; TIOCGETC $7412 = |18;
 * TIOCLBIS $747F = |127; TIOCGWINSZ $7468 = |104.  Spot-checked, not assumed.
 * The tty bank's C cannot see loader.s, which is why they are restated.
 */
#define TIOCGETD    0x7400      /* get line discipline    -- ioctl.h:113 */
#define TIOCSETD    0x7401      /* set line discipline    -- ioctl.h:114 */
#define TIOCHPCL    0x7402      /* hang up on last close  -- ioctl.h:115 */
#define TIOCGETP    0x7408      /* gtty                   -- ioctl.h:129 */
#define TIOCSETP    0x7409      /* stty, with flush       -- ioctl.h:130 */
#define TIOCSETN    0x740A      /* stty, no flush         -- ioctl.h:131 */
#define TIOCEXCL    0x740D      /* set exclusive use      -- ioctl.h:132 */
#define TIOCNXCL    0x740E      /* reset exclusive use    -- ioctl.h:133 */
#define TIOCFLUSH   0x7410      /* flush buffers          -- ioctl.h:134 */
#define TIOCSETC    0x7411      /* set special chars      -- ioctl.h:135 */
#define TIOCGETC    0x7412      /* get special chars      -- ioctl.h:136 */
#define TIOCSWINSZ  0x7467      /* set window size        -- ioctl.h:217 */
#define TIOCGWINSZ  0x7468      /* get window size        -- ioctl.h:216 */
#define TIOCSTART   0x746E      /* start output, like ^Q  -- ioctl.h:210 */
#define TIOCSTOP    0x746F      /* stop output, like ^S   -- ioctl.h:209 */
#define TIOCSTI     0x7472      /* simulate terminal input-- ioctl.h:199 */
#define TIOCOUTQ    0x7473      /* output queue size      -- ioctl.h:198 */
#define TIOCGLTC    0x7474      /* get local special chars-- ioctl.h:197 */
#define TIOCSLTC    0x7475      /* set local special chars-- ioctl.h:196 */
#define TIOCSPGRP   0x7476      /* set pgrp of tty        -- ioctl.h:195 */
#define TIOCGPGRP   0x7477      /* get pgrp of tty        -- ioctl.h:194 */
#define TIOCLGET    0x747C      /* get local modes        -- ioctl.h:174 */
#define TIOCLSET    0x747D      /* set local mode word    -- ioctl.h:173 */
#define TIOCLBIC    0x747E      /* bic local mode bits    -- ioctl.h:172 */
#define TIOCLBIS    0x747F      /* bis local mode bits    -- ioctl.h:171 */
#define FIOASYNC    0x667D      /* set/clear async i/o    -- ioctl.h:233 */
#define FIONBIO     0x667E      /* set/clear non-blocking -- ioctl.h:232 */
#define FIONREAD    0x667F      /* get # bytes to read    -- ioctl.h:231 */

#define TIOCMBIC    0x746B      /* bic modem bits    -- ioctl.h:213 */
#define TIOCMBIS    0x746C      /* bis modem bits    -- ioctl.h:212 */
#define TIOCM_RTS   0004        /* request to send   -- ioctl.h:120 */

/* FREAD/FWRITE -- ttyflush's `rw'.  Inlined like the rest of this block.
 *
 * NOT CITED TO 2.11BSD's h/file.h, because the vendored copy of that header is
 * TRIMMED and does not carry them; saying otherwise would be a citation that
 * does not open.  Verified instead in `vendor/4.3BSD-Reno/sys/file.h:55-56'
 * (FREAD 1, FWRITE 2), which is what FGX's own `src/kernel/vfs/file.h:107'
 * already cites and uses, and cross-checked against 2.11BSD's own sources in
 * the full distribution (`usr/sys/OTHERS/de11/de.c:11' has FREAD 01).  All
 * three agree, which is what matters: `rw' arrives from FGX callers.
 */
#define FREAD       1
#define FWRITE      2

/* FNDELAY -- ttylclose's `flag'.  Inlined for the reason FREAD/FWRITE above
 * are, and from the same place: 2.11BSD's h/file.h gets it by including
 * <fcntl.h>, and the vendored copy of THAT is trimmed away.
 *
 * `vendor/4.3BSD-Reno/sys/fcntl.h:62' has `#define FNDELAY O_NONBLOCK' and
 * `:59' has `#define O_NONBLOCK 00004', so the value is 4.  FGX's own
 * `src/kernel/vfs/file.h:109' already carries it at that number, which is what
 * makes it safe to restate: the two agree, and a flag arriving from the VFS
 * layer means here what it means there.
 *
 * NOTHING SETS IT YET.  vfs/file.h says so at length -- there is no O_NONBLOCK
 * in toolchain/include/fcntl.h, so no userland open can raise the bit, and
 * ttylclose's non-blocking arm is unreachable until one can.  Carried at the
 * right value so that adding O_NONBLOCK is a one-line change rather than a
 * renumbering, and named here so it is not mistaken for working non-blocking
 * mode.
 */
#define FNDELAY     0x0004

/* IO_NDELAY -- ttwrite's `flag'.  usr/sys/h/inode.h:224, whose own comment is
 * "FNDELAY flag set in file table".
 *
 * IT IS NOT FNDELAY, AND THE DIFFERENCE IS UPSTREAM'S, NOT A PORT ARTEFACT.
 * ttylclose above takes F* flags and says so at length, arguing with 4.4BSD
 * about it; the READ and WRITE paths take IO_* instead, which is why the two
 * constants sit here with different values and both are needed.  Getting them
 * the wrong way round is silent: 0x0004 and 0x0010 are both plausible bits and
 * neither call errors.
 */
#define IO_NDELAY   0x0010

/* SIGIO, `usr/sys/h/signal.h:38'.  Inlined for the reason the ioctl requests
 * below are: kernel C cannot include an assembly header, and this is the only
 * signal number the bank names.
 *
 * THE THREE SPELLINGS ALREADY AGREE, which is what makes it safe to restate:
 * upstream's signal.h:38, FGX's include/loader.s:802 and
 * toolchain/include/signal.h:65 are all 23.  A fourth copy that drifted would
 * post the wrong signal to a process group, so it is worth saying that this one
 * was checked against all three rather than remembered.
 */
#define SIGIO       23

/* SIGHUP and SIGCONT, `usr/sys/h/signal.h:12' and `:33' -- ttymodem's lost
 * carrier arm, which sends both.
 *
 * THE PAIR IS THE POINT, AND THE ORDER IS UPSTREAM'S.  A hangup on a line
 * whose process group is STOPPED would otherwise be delivered to a process
 * that never runs to act on it, so the continue follows the hangup to make
 * sure the group wakes up far enough to die.  Sending only SIGHUP is the
 * plausible-looking simplification that leaves a stopped shell parked on a
 * dead line forever.
 *
 * Checked against all three spellings the way SIGIO above was:
 * upstream's signal.h:12/:33, FGX's include/loader.s:780/:798 and
 * toolchain/include/signal.h:43/:61 are 1 and 19 in every copy.
 */
#define SIGHUP      1
#define SIGCONT     19

/* SIGINT, SIGQUIT and SIGTSTP -- `usr/sys/h/signal.h:13', `:14' and `:32'.
 * ttyinput's three signal-generating characters: ^C, ^\ and ^Z.
 *
 * Checked against all three spellings as the pair above was: upstream's
 * signal.h:13/:14/:32, FGX's include/loader.s:781/:782/:797 and
 * toolchain/include/signal.h:44/:45/:60 are 2, 3 and 18 in every copy.
 *
 * SIGTSTP IS 18, NOT 20.  4.4BSD and everything after it renumbered the job-
 * control signals, and 18 there is SIGCONT -- so a number remembered from a
 * modern signal.h would send CONTINUE where the terminal meant STOP, on a
 * table where both numbers exist and neither errors.
 */
#define SIGINT      2
#define SIGQUIT     3
#define SIGTSTP     18

/* SIGTTIN and SIGTTOU -- `usr/sys/h/signal.h:36' and `:37'.  ttwrite's
 * background-output stop raises SIGTTOU; ttread's raises SIGTTIN.
 *
 * Checked against all three spellings as the sets above were: upstream's
 * signal.h:36/:37, FGX's include/loader.s:800/:801 and
 * toolchain/include/signal.h:63/:64 are 21 and 22 in every copy.
 *
 * THESE TWO DID NOT MOVE IN 4.4BSD, unlike SIGTSTP above -- worth stating,
 * because the neighbouring warning invites the assumption that they did.
 */
#define SIGTTIN     21
#define SIGTTOU     22

/* SIGWINCH -- `usr/sys/h/signal.h:43'.  ttioctl's TIOCSWINSZ raises it, and
 * only when the size actually CHANGED, which is why that arm is a bcmp and not
 * an assignment.  Checked the same three ways: upstream's signal.h:43 and
 * FGX's include/loader.s:807 are both 28. */
#define SIGWINCH    28

/* The output watermarks, `usr/sys/h/tty.h:93-100'.  Indexed by the line's
 * output speed, so a slow line drains to a lower mark before a writer is
 * woken.  The tables themselves are tty.c:93-96 and are carried verbatim.
 *
 * SHORT, not int: they hold 2000 at the top, which fits, but upstream declares
 * them `short' and tty_pty.c reads them, so the width travels with the name.
 */
/* NSPEEDS and TTMASK are upstream's own, in the `limits' block above.  They
 * are NOT restated here: a second copy is what this header carried until the
 * duplicate was found, and two spellings of a table bound is how one of them
 * goes stale. */
extern short tthiwat[NSPEEDS], ttlowat[NSPEEDS];
#define TTHIWAT(tp) tthiwat[(tp)->t_ospeed & TTMASK]
#define TTLOWAT(tp) ttlowat[(tp)->t_ospeed & TTMASK]

/* define partab character types */
#define ORDINARY    0
#define CONTROL     1
#define BACKSPACE   2
#define NEWLINE     3
#define TAB         4
#define VTAB        5
#define RETURN      6

#endif /* _TTY_H_ */
