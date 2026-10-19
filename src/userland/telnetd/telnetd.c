/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD telnetd(8)
 *   Reimplemented following telnetd(8), 2.11BSD (telnetd.c 5.20.3 (2.11BSD)
 *   1996/11/16), vendored at vendor/2.11BSD/usr/libexec/telnetd/telnetd.c.
 *   NOT a code port: upstream's protocol answers, its pty-slave-plus-getty
 *   structure, its TIOCNOTTY-before-open ordering and telrcv's state machine
 *   are followed; none of its code is used.
 *
 *   Absent here, present upstream: netflush, ptyflush, ttloop, willoption,
 *   dooption, wontoption, dontoption, suboption, interrupt, sendbrk,
 *   stilloob, netclear, nextitem, rmut, mode, cleanup, fatal, doit.
 *
 *   Copyright (c) 1983,1986 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * telnetd(8) - relay a TCP connection to a login session on a pty.
 *
 * STRUCTURE KEPT FROM UPSTREAM: the standalone socket/bind/listen/accept block
 * (upstream's `#if defined(DEBUG)` arm of main), the pty-pair scan, the
 * TIOCNOTTY-then-open detach ordering, and exec'ing /bin/login on the slave --
 * upstream already does `execl("/bin/login", "login", "-h", host, ...)`, so an
 * authenticated session is the ORIGINAL behaviour, not an FGX addition.
 *
 * WHAT IS RESHAPED, and why:
 *  - Upstream is normally an inetd child: main() does getpeername(0,...) on a
 *    connected socket handed in as fd 0.  BOTH SHAPES EXIST HERE NOW: `-i` is
 *    the inetd child (the connection arrives as fd 0/1/2 and nothing is bound),
 *    and the standalone block is what runs without it.  Neither path learns
 *    the peer: getpeername(2) exists (SYS_GETPEERNAME) but is not called, and
 *    accept() is passed a null address.  That is why getty is started
 *    without the -h argument upstream passes it.
 *  - fork()+execl() on the slave becomes spawnx() with file_actions
 *    {DETACH, open slave->3, dup2 3->0/1/2, close 3}: the verified FGX
 *    spawn-on-slave recipe (src/userland/ptyshell/ptyshell.c).  DETACH comes
 *    FIRST for the same reason upstream calls TIOCNOTTY before opening the
 *    slave -- otherwise the child arrives already in this daemon's process
 *    group and the pty line never gets a foreground group of its own.
 *  - Its syslog lines reach syslogd(8) through /dev/log as AF_UNIX datagrams
 *    (see syslog.h), which does not depend on where stderr points -- so
 *    detaching costs nothing here that running from a shell does not.
 *
 * IAC HANDLING (this increment).  Upstream's telrcv is a full state machine
 * over TS_DATA/TS_IAC/TS_WILL/TS_WONT/TS_DO/TS_DONT/TS_SB with per-option
 * bookkeeping; the version here keeps its SHAPE and its answers but not its
 * option table, because FGX negotiates exactly the three the client already
 * understands.  Refusing everything else is upstream's own default for an
 * option it does not implement, so a client asking for LINEMODE or NAWS gets
 * a well-formed DONT/WONT rather than silence.
 *
 * THE OPTION TABLE IS NOT OPTIONAL.  Dropping it (as this port's first attempt
 * did) makes the two ends ping-pong forever: we announce WILL ECHO, the client
 * answers DO ECHO, we re-affirm WILL ECHO, and the session fills with
 * negotiation instead of data.  RFC 854's rule is that a party may only
 * respond to a request that CHANGES the option's state -- re-confirming an
 * already-agreed option is what creates the loop.  g_myopt/g_hisopt below are
 * upstream's options[] in miniature, and they exist for exactly this.
 *
 * Two more rules that are easy to get wrong:
 *  - IAC bytes must NEVER reach the pty.  Passing them through as text is what
 *    the previous increment did, and getty read the negotiation as a login
 *    name.
 *  - a literal 255 in the data stream arrives as IAC IAC and must be delivered
 *    to the pty as ONE 255.
 *
 * Still deferred: the
 * interrupt()/sendbrk() urgent path.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/telnet.h>
#include <sys/ioctl.h>              /* struct winsize, TIOCSWINSZ, FIONBIO */
#include <utmp.h>                   /* logout(3): the session's utmp record */

#define TELNETD_PORT 23
#define PTY_NPAIR    2              /* kernel: src/kernel/pty.s PTY_NPAIR */
#define BUFSZ        512

int  spawnx(char *path, char **argv, unsigned char *acts);
int  ioctl(int fd, int cmd, char *arg);
int  select(int nfds, char *rd, char *wr, char *ex, char *tv);
int  nanosleep(int ticks);

#define TIOCPKT  0x7470             /* not in <sys/ioctl.h> */

/* telrcv states, upstream's names */
#define TS_DATA  0
#define TS_IAC   1
#define TS_WILL  2
#define TS_WONT  3
#define TS_DO    4
#define TS_DONT  5
#define TS_SB    6

/* 60 Hz ticks to wait for the client's TERMINAL-TYPE before giving up and
 * keeping the /etc/ttys entry.  Two seconds: long enough for a LAN client's
 * round trip, short enough that a client which will not answer does not hold
 * the login prompt hostage. */
#define TTYPE_WAIT  120
#define TS_SE    7
#define TS_CR    8   /* just passed a CR: strip a following NUL or LF */

/* The relay's state and buffers, at file scope because they persist across
 * reads. */
int  g_state;                       /* telrcv state, persists across reads */
/* Per-option agreement state -- see the header: without these the negotiation
 * never terminates.  g_myopt[x] = this end has said WILL x; g_hisopt[x] = the
 * peer has said WILL x.  Indexed by option code, so 256 entries each. */
char g_myopt[256];
char g_hisopt[256];
char g_reply[8];                    /* an IAC triple, or the TTYPE SEND */
char g_pty[BUFSZ];                  /* de-IAC'd data destined for the pty */
char g_mbuf[BUFSZ];                 /* pty master -> socket */
char g_nbuf[2 * BUFSZ];             /* g_mbuf escaped for the net: worst case
                                     * every byte doubled */
char g_sbuf[BUFSZ];                 /* socket -> pty master */
/* Subnegotiation body: g_sb[0] is the option code, the rest is its payload.
 * 8 is enough for the only one this end reads -- NAWS is opt + 4 bytes. */
char g_sb[48];
int  g_sbn;

/* The client's answer to TERMINAL-TYPE, lowercased, empty until negotiated.
 * Sized for the long ones ("xterm-256color") with room to spare; a name that
 * overruns it is truncated rather than dropped, because a truncated name still
 * selects a better entry than the /etc/ttys default in every case that matters
 * ("xterm-..." -> "xterm"). */
char g_ttype[24];
static char g_tflag[] = "-T";
char g_master[]  = "/dev/ptyp0";
char g_slave[]   = "/dev/ttyp0";
char g_gettyp[]  = "/bin/getty";
unsigned char g_fa[48];
char  *g_argv[6];

/* Open the first free pty pair; leaves the master fd, and patches the unit
 * digit into both path buffers so the slave path matches.  -1 if none free. */
static int
openpty()
{
    int i, m;

    for (i = 0; i < PTY_NPAIR; i++) {
        g_master[sizeof("/dev/ptyp") - 1] = '0' + i;
        m = open(g_master, 2);
        if (m >= 0) {
            g_slave[sizeof("/dev/ttyp") - 1] = '0' + i;
            return m;
        }
    }
    return -1;
}

/* Spawn the login chain on the slave.
 *
 * PORT DELTA, and the reason the first attempt failed: upstream execs
 * /bin/login directly, because 4.xBSD's login(1) does its own greeting -- it
 * prints "login:", reads the name, then authenticates.  FGX split those jobs
 * the way /etc/ttys describes: getty(8) opens the line, greets, reads the
 * name, and EXECS login, which only authenticates.  So exec'ing login here
 * produced a session that opened the slave and then sat with nothing to say.
 * /bin/getty is FGX's equivalent of what upstream means by "/bin/login", and
 * it is what logintest(8) -- the verified getty->login->shell fixture --
 * spawns.  Note /etc/ttys marks ttyp0 `off secure`: off so init leaves the
 * pair for us, secure so root may log in over it.
 *
 * Mirrors upstream's TIOCNOTTY-then-open ordering via the DETACH action. */
static int
spawn_login()
{
    int poff, k;

    poff = (int)g_slave;
    k = 0;
    g_fa[k++] = 4; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 1; g_fa[k++] = 3; g_fa[k++] = poff & 0xff; g_fa[k++] = (poff >> 8) & 0xff;
    g_fa[k++] = 2; g_fa[k++] = 0;
    g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 3; g_fa[k++] = 1; g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 3; g_fa[k++] = 2; g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 2; g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 0;

    /* Hand the negotiated terminal type down the chain.  Upstream sets TERM
     * in the child's environment and execs `login -p' to have it preserved;
     * spawnx carries file actions and an EMPTY environment (the split
     * apple/fgx#121 also ran into), so the type travels as an argument
     * instead -- the same way upstream threads `-h host' through.  getty
     * passes it on to login, which prefers it over the /etc/ttys entry.
     *
     * Nothing negotiated means nothing passed, and the session keeps the
     * /etc/ttys type: a client that will not say what it is has not earned an
     * assumption. */
    g_argv[0] = g_gettyp;
    if (g_ttype[0] != '\0') {
        g_argv[1] = g_tflag;
        g_argv[2] = g_ttype;
        g_argv[3] = (char *)0;
    } else
        g_argv[1] = (char *)0;
    return spawnx(g_gettyp, g_argv, g_fa);
}

/* Send one IAC triple.  Errors are ignored: a peer that has gone away will be
 * noticed by the next read, and a half-written negotiation is not worth
 * failing a session over. */
static void
sendopt(cmd, opt, c)
int cmd, opt, c;
{
    g_reply[0] = (char)IAC;
    g_reply[1] = (char)cmd;
    g_reply[2] = (char)opt;
    send(c, g_reply, 3, 0);
}

/* Answer an option request.  We WILL ECHO and WILL SGA (this end echoes and
 * suppresses go-ahead, which is what a pty-backed login session wants), and we
 * DO want TTYPE.  Everything else is refused -- upstream's default for an
 * unimplemented option, and a refusal is what keeps a client from waiting. */
static void
answer(cmd, opt, c)
int cmd, opt, c;
{
    int want;

    switch (cmd) {
    case DO:                        /* peer asks us to enable opt */
        want = (opt == TELOPT_ECHO || opt == TELOPT_SGA);
        if (want) {
            if (g_myopt[opt])       /* already agreed -- SILENCE, or we loop */
                return;
            g_myopt[opt] = 1;
            sendopt(WILL, opt, c);
        } else {
            if (!g_myopt[opt])      /* already refused/off */
                return;
            g_myopt[opt] = 0;
            sendopt(WONT, opt, c);
        }
        break;
    case DONT:
        if (!g_myopt[opt])
            return;
        g_myopt[opt] = 0;
        sendopt(WONT, opt, c);
        break;
    case WILL:                      /* peer offers to enable opt */
        want = (opt == TELOPT_TTYPE || opt == TELOPT_NAWS);
        if (want) {
            if (g_hisopt[opt])
                return;
            g_hisopt[opt] = 1;
            sendopt(DO, opt, c);
        } else {
            if (!g_hisopt[opt])
                return;
            g_hisopt[opt] = 0;
            sendopt(DONT, opt, c);
        }
        break;
    case WONT:
        if (!g_hisopt[opt])
            return;
        g_hisopt[opt] = 0;
        sendopt(DONT, opt, c);
        break;
    }
}

/* Apply a completed subnegotiation.  NAWS (RFC 1073) is the only one this end
 * reads: IAC SB NAWS <col-hi> <col-lo> <row-hi> <row-lo> IAC SE -- WIDTH FIRST,
 * which is the easy thing to get backwards.
 *
 * The size goes to the pty MASTER, because that is the fd this process holds;
 * the kernel routes the window-size pair from a master to its slave's tty
 * (apple/fgx#150), which is what BSD gets for free by having both ends share
 * one struct tty.  Setting a size that differs from the current one also sends
 * SIGWINCH to the session's foreground group, so a full-screen program redraws
 * at the new geometry.
 *
 * A zero dimension is REFUSED rather than stored: RFC 1073 lets a client send 0
 * to mean "you choose", and storing it would tell the child it has a zero-row
 * terminal. Keeping the previous value is the useful reading of "you choose". */
static void
subneg(m)
int m;
{
    struct winsize ws;
    int row, col;

    /* TERMINAL-TYPE first: IAC SB TERMINAL-TYPE IS <name> IAC SE.  Upstream
     * lowercases the name before using it, because termcap names are lower
     * case and clients are not required to be (apple/fgx#147). */
    if (g_sbn >= 2 && (unsigned char)g_sb[0] == TELOPT_TTYPE
                   && (unsigned char)g_sb[1] == TELQUAL_IS) {
        int i, n;

        n = g_sbn - 2;
        if (n > (int)sizeof(g_ttype) - 1)
            n = (int)sizeof(g_ttype) - 1;
        for (i = 0; i < n; i++) {
            int ch = (unsigned char)g_sb[2 + i];
            if (ch >= 'A' && ch <= 'Z')
                ch = ch - 'A' + 'a';
            g_ttype[i] = (char)ch;
        }
        g_ttype[n] = '\0';
        return;
    }

    if (g_sbn < 5)                          /* opt + 4 payload bytes */
        return;
    if ((unsigned char)g_sb[0] != TELOPT_NAWS)
        return;                             /* not one we act on */

    col = (((unsigned char)g_sb[1]) << 8) | (unsigned char)g_sb[2];
    row = (((unsigned char)g_sb[3]) << 8) | (unsigned char)g_sb[4];
    if (row <= 0 || col <= 0)
        return;

    ws.ws_row = (short)row;
    ws.ws_col = (short)col;
    ws.ws_xpixel = 0;
    ws.ws_ypixel = 0;
    ioctl(m, TIOCSWINSZ, (char *)&ws);
}

/* Upstream's telrcv, reduced: consume the socket buffer, answer negotiation
 * inline, and return the number of DATA bytes left in g_pty for the child.
 * State persists in g_state so an IAC split across two reads still works. */
static int
telrcv(n, c, m)
int n, c, m;
{
    int i, out;
    unsigned char ch;

    out = 0;
    for (i = 0; i < n; i++) {
        ch = (unsigned char)g_sbuf[i];
        /* RFC 854: a bare CR travels as CR NUL, and CR LF is the line
         * terminator -- so the byte AFTER a CR is stripped when it is NUL or
         * LF.  Upstream does this with a TS_CR state that falls through into
         * TS_DATA (telnetd.c:630-637); the test is hoisted above the switch
         * here so the port does not depend on switch fall-through.
         *
         * WITHOUT IT THE NUL IS DELIVERED TO THE PTY as an ordinary data byte,
         * where it becomes the FIRST character of the next line the child
         * reads.  Measured: logging in over telnet, the pty slave's canonical
         * buffer held `00 66 67 78` -- a NUL ahead of `fgx` -- so login(1)
         * compared a four-character password and answered "Login incorrect".
         * The FIRST line of a session is always clean, because there is no
         * preceding CR; every line after it carries the previous line's NUL,
         * which is why the login name is accepted and the password never is.
         *
         * Upstream gates the CR state on `hisopts[TELOPT_BINARY] == OPT_NO`.
         * This port never offers BINARY, so his side cannot be in it and the
         * gate is constant-true -- omitted rather than faked. */
        if (g_state == TS_CR) {
            g_state = TS_DATA;
            if (ch == 0 || ch == '\n')
                continue;
        }
        switch (g_state) {
        case TS_DATA:
            if (ch == IAC)
                g_state = TS_IAC;
            else {
                g_pty[out++] = (char)ch;
                if (ch == '\r')
                    g_state = TS_CR;
            }
            break;
        case TS_IAC:
            switch (ch) {
            case IAC:  g_pty[out++] = (char)IAC; g_state = TS_DATA; break;
            case WILL: g_state = TS_WILL; break;
            case WONT: g_state = TS_WONT; break;
            case DO:   g_state = TS_DO;   break;
            case DONT: g_state = TS_DONT; break;
            case SB:   g_state = TS_SB; g_sbn = 0; break;
            default:   g_state = TS_DATA; break;   /* NOP/DM/GA: swallow */
            }
            break;
        case TS_WILL: answer(WILL, ch, c); g_state = TS_DATA; break;
        case TS_WONT: answer(WONT, ch, c); g_state = TS_DATA; break;
        case TS_DO:   answer(DO,   ch, c); g_state = TS_DATA; break;
        case TS_DONT: answer(DONT, ch, c); g_state = TS_DATA; break;
        case TS_SB:                     /* collect the subnegotiation body */
            if (ch == IAC)
                g_state = TS_SE;
            else if (g_sbn < (int)sizeof(g_sb))
                g_sb[g_sbn++] = (char)ch;
            break;
        case TS_SE:
            if (ch == SE) {
                subneg(m);              /* act on it, then back to data */
                g_state = TS_DATA;
            } else if (ch == IAC) {
                /* IAC IAC inside a body is a literal 255 -- a width or height
                 * of 255 is perfectly legal, so it must be UNescaped rather
                 * than dropped. */
                if (g_sbn < (int)sizeof(g_sb))
                    g_sb[g_sbn++] = (char)IAC;
                g_state = TS_SB;
            } else {
                g_state = TS_SB;        /* IAC <other> inside SB: keep eating */
            }
            break;
        }
    }
    return out;
}

/* Upstream's getterminaltype(), reduced: ASK for the terminal type and wait
 * for the answer, because DO TERMINAL-TYPE only wins the client's agreement to
 * be asked -- the name itself arrives only in reply to a subnegotiation.
 *
 * THIS RUNS BEFORE THE SLAVE IS STARTED, which is upstream's ordering and is
 * forced: the type has to be known while there is still an argument list to
 * put it in.  Until now telnetd asked, threw the answer away, and every remote
 * session ran as the /etc/ttys type whatever the client actually was.
 *
 * BOUNDED, because a client is free not to answer.  When the budget runs out
 * the type stays empty and the session keeps the /etc/ttys entry, which is
 * exactly the behaviour every session had before this existed.
 *
 * Data arriving in this window is discarded: there is no child to give it to
 * yet, and a client cannot type ahead of a prompt it has not been shown. */
static void
getterminaltype(c, m)
int c, m;
{
    int on, tries, n;

    on = 1;
    ioctl(c, FIONBIO, (char *)&on);
    g_state = TS_DATA;

    g_reply[0] = (char)IAC;
    g_reply[1] = (char)SB;
    g_reply[2] = (char)TELOPT_TTYPE;
    g_reply[3] = (char)TELQUAL_SEND;
    g_reply[4] = (char)IAC;
    g_reply[5] = (char)SE;
    if (send(c, g_reply, 6, 0) < 0)
        return;

    for (tries = 0; tries < TTYPE_WAIT && g_ttype[0] == '\0'; tries++) {
        n = recv(c, g_sbuf, BUFSZ, 0);
        if (n == 0)
            return;                         /* peer closed */
        if (n > 0)
            (void) telrcv(n, c, m);
        else
            nanosleep(1);
    }
}

/* Send n bytes of pty output to the net, as upstream's pty-to-net loop does
 * (telnet(), telnetd.c:580-595).  A data byte of 255 is IAC to the client, so
 * it goes out as IAC IAC (RFC 854); undoubled, the client takes it and the byte
 * after it for a command and loses both.  And unless this end has agreed to
 * BINARY, a CR not followed by LF goes out as CR NUL, the NVT's bare carriage
 * return.  A cooked pty never produces a 255 -- ttyoutput clears bit 7 unless
 * the line is RAW or LITOUT -- so the doubling matters to 8-bit output from a
 * program that set one of those. */
static int
netout(c, p, n)
int c;
char *p;
int n;
{
    int i, o;
    unsigned char ch;

    o = 0;
    for (i = 0; i < n; i++) {
        ch = (unsigned char)p[i];
        if (ch == IAC)
            g_nbuf[o++] = (char)IAC;
        g_nbuf[o++] = (char)ch;
        if (ch == '\r' && !g_myopt[TELOPT_BINARY]) {
            if (i + 1 < n && p[i + 1] == '\n')
                g_nbuf[o++] = p[++i];
            else
                g_nbuf[o++] = '\0';
        }
    }
    return send(c, g_nbuf, o, 0);
}

/* Relay until either side closes.  Returns 0 on a clean session end. */
static int
relay(c, m)
int c, m;
{
    int n, on, started, idle;

    started = 0;                /* has the slave ever been open? */
    idle = 0;
    g_state = TS_DATA;
    on = 1;
    ioctl(m, FIONBIO, (char *)&on);
    ioctl(c, FIONBIO, (char *)&on);

    for (;;) {
        /* pty master -> socket.  Master reads are RECORD mode and every one
         * is prefixed with a TIOCPKT status byte, which must be dropped; an
         * empty read with no slave open is EOF and means the shell exited. */
        n = read(m, g_mbuf, BUFSZ);
        if (n == 0) {
            /* Master reads report EOF for "ring empty AND no slave open".
             * Immediately after spawn that is NOT teardown -- login has not
             * reached its open() yet -- so EOF only means the session is over
             * once we have seen the slave open at least once.  Without this the
             * relay exited before login could write its first prompt. */
            if (!started) {
                if (++idle > 2000)
                    return 0;               /* the greeter never came up */
                nanosleep(1);
                continue;
            }
            return 0;                       /* slave gone: session over */
        }
        if (n > 0) {
            started = 1;
            idle = 0;
        }
        if (n > 1) {
            if (netout(c, g_mbuf + 1, n - 1) < 0)
                return 0;                   /* peer gone */
        }

        /* socket -> pty master, through the IAC filter: negotiation is
         * answered here and never reaches the child. */
        n = recv(c, g_sbuf, BUFSZ, 0);
        if (n == 0)
            return 0;                       /* peer closed */
        if (n > 0) {
            n = telrcv(n, c, m);        /* strips IAC, answers options */
            if (n > 0)
                write(m, g_pty, n);
            continue;                   /* did work: go round again at once */
        }

        /* Both directions returned EWOULDBLOCK.  YIELD -- without this the
         * relay busy-spins and starves every other task, including the peer
         * that is supposed to produce the next byte, so the session hangs
         * with the connection up and no data moving. */
        nanosleep(1);
    }
}

main(argc, argv)
int argc;
char **argv;
{
    int ls, c, m, port, inetd;
    struct sockaddr_in sin;

    openlog("telnetd", LOG_PID, LOG_DAEMON);

    /* -i: WE ARE AN INETD CHILD, which is upstream's normal shape rather than
     * an FGX addition -- inetd(8) accepts the connection and hands it over as
     * fd 0/1/2, so there is nothing here to bind, listen on or accept.
     *
     * NOTHING MAY BE PRINTED TO STDOUT IN THIS MODE.  fd 1 IS the connection,
     * so the progress lines the standalone path prints would be injected into
     * the TELNET stream ahead of the login prompt.  Upstream has no printfs at
     * all for exactly this reason; syslog(3) still works, because FGX routes it
     * to stderr -- which is also the connection here, so it is quiet too until
     * there is a real syslogd.
     *
     * The listener fd is -1 throughout, and the teardown at the end skips it. */
    inetd = 0;
    port = TELNETD_PORT;
    if (argc > 1 && strcmp(argv[1], "-i") == 0)
        inetd = 1;
    else if (argc > 1)
        port = atoi(argv[1]);

    if (inetd) {
        ls = -1;
        c = 0;                          /* the connection, per inetd(8) */
        m = openpty();
        if (m < 0) { syslog(LOG_ERR, "no free pty"); exit(1); }
        goto haveconn;
    }

    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) { syslog(LOG_ERR, "socket: %m"); exit(1); }

    for (c = 0; c < sizeof(sin); c++) ((char *)&sin)[c] = 0;
    sin.sin_family = AF_INET;
    sin.sin_port   = htons(port);
    sin.sin_addr.s_addr = htonl(0x7F000001);    /* 127.0.0.1 for now */

    if (bind(ls, &sin, sizeof(sin)) < 0)  { syslog(LOG_ERR, "bind: %m");   exit(1); }
    if (listen(ls, 1) < 0)                { syslog(LOG_ERR, "listen: %m"); exit(1); }

    printf("telnetd: listening on 127.0.0.1:%d\n", port);

    /* One session at a time.  accept() DETACHES the listener on the W5100
     * path, so a real server re-creates it per session (echod does); the
     * loopback path mirrors that deliberately, so the same shape works here. */
    m = openpty();
    if (m < 0) { syslog(LOG_ERR, "no free pty"); exit(1); }

    c = accept(ls, (struct sockaddr *)0, (int *)0);
    if (c < 0) { syslog(LOG_ERR, "accept: %m"); exit(1); }

haveconn:
    { int on = 1; ioctl(m, TIOCPKT, (char *)&on); }

    /* Opening negotiation, upstream's set: we echo, we suppress go-ahead, and
     * we would like the terminal type.  Sent BEFORE the relay so the client
     * has our answers in hand as soon as it starts. */
    g_myopt[TELOPT_ECHO] = 1;   sendopt(WILL, TELOPT_ECHO, c);
    g_myopt[TELOPT_SGA]  = 1;   sendopt(WILL, TELOPT_SGA,  c);
    g_hisopt[TELOPT_TTYPE] = 1; sendopt(DO,   TELOPT_TTYPE, c);
    /* Ask for the client's window size.  Without this the child runs at the
     * pty's default 80x24 whatever the client actually is, and a full-screen
     * program draws the wrong number of lines -- measured as a lost top row on
     * a 24-row client being told it had 25 (apple/fgx#150). */
    g_hisopt[TELOPT_NAWS] = 1;  sendopt(DO,   TELOPT_NAWS,  c);

    /* Ask for the type and wait for it, THEN start the session -- the order
     * is upstream's and it is what makes the answer usable (apple/fgx#147). */
    getterminaltype(c, m);

    if (spawn_login() < 0) { syslog(LOG_ERR, "/bin/getty: %m"); exit(1); }

    /* Naming the negotiated type is upstream's habit and it earns its line:
     * "the client is being driven as the wrong terminal" is otherwise only
     * visible as a corrupted screen, and the two are hard to tell apart from
     * a bug report.  An empty pair of brackets says the client never answered
     * and the /etc/ttys type stands. */
    if (!inetd)
        printf("telnetd: session on %s [%s]\n", g_slave, g_ttype);
    relay(c, m);

    /* THE SESSION IS OVER: blank its /etc/utmp record.  login(1) wrote it, and
     * on a pty line the daemon holding the master is the only process that
     * outlives the shell -- there is no init watching this line -- so clearing
     * it is this daemon's job, as upstream telnetd's cleanup() does through
     * logout().  ut_line holds the bare name, so the record is looked up by the
     * basename of the slave path rather than the path.  The wtmp end record
     * follows only a record found, as 2.11BSD rlogind's `if (logout(p))
     * logwtmp(p, "", "");' (libexec/rlogind/rlogind.c:483-484). */
    {
        char *ln = strrchr(g_slave, '/');
        ln = ln != (char *)0 ? ln + 1 : g_slave;
        if (logout(ln))
            logwtmp(ln, "", "");
    }

    close(c);
    close(m);
    if (ls >= 0)
        close(ls);
    if (!inetd)
        printf("telnetd: session ended\n");
    exit(0);
}
