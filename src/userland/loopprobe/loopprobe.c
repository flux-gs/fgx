/* loopprobe - the telnetd campaign's P1 gate: prove the 127.0.0.1 transport
 * end to end, headless, with no hardware and no peer process.
 *
 * FGX-Provenance: none.  Original FGX code.  It cites 2.11BSD's NOFILE below
 * because that is where FS_MAX_FDS's value comes from, and naming the source of
 * a constant is not derivation.
 *
 * One process does the whole closed loop: bind + listen on 127.0.0.1, connect
 * to itself, accept the result, then round-trip bytes BOTH directions.  That is
 * deliberate -- it needs no second program, no host-side nc, and no network, so
 * it runs under MAME as an ordinary fixture.  Until this existed, every part of
 * the loopback backend was reviewed but nothing was executed.
 *
 * WHY IT PROVES SOMETHING.  The kernel services loopback only when a descriptor
 * carries SOCK_HW_LOOP, which is set exclusively by a connect() that matched a
 * LISTENING socket on a 127/8 address.  So reaching "accept returned an fd" at
 * all means connect's scan found the listener, allocated two pipe rings, and
 * paired the two descriptors.  The two transfers then exercise both rings
 * independently -- a single direction would pass even if both descriptors were
 * wired to the SAME ring, which is the mistake this shape is chosen to catch.
 *
 * This uses 3 descriptors (listener + connector + accepted) out of SOCKD_MAX.
 * IT DOES NOT USE ZERO W5100 HARDWARE SOCKETS, which this comment claimed for
 * months: socket() claims one before bind/connect can say the destination is
 * loopback, so the two socket() calls below took two of the three the machine
 * has.  They were never given back either, so a SECOND run in the same boot
 * failed at socket() -- apple/fgx#132, fixed by _Loop_ReleaseHw handing the
 * slot back once the descriptor is known to be loopback.
 *
 * IT ALSO CARRIES THE NEGATIVE ASSERTIONS, and that is not incidental.  Every
 * check below was originally of the form "a socket with data in it reports
 * itself ready", and a kernel that answered "ready" to everything passed all
 * of them -- measured, in apple/fgx#98 and #99.  The empty-ring block after
 * accept() is the part that can go red.  Keep it before the first send: it is
 * the only window in which the state it samples exists.
 *
 * Two later blocks are negative in the same sense.  A second connect() and a
 * rebind must be REFUSED, because the loopback claim frees the descriptor's
 * W5100 slot and doing that to a live one aliases a hardware socket
 * (apple/fgx#133).  And dup2 must tear a socket down the way close(2) does:
 * dropping the last reference inside dup2 used to run no teardown at all, so
 * the peer never saw EOF (apple/fgx#134).  Neither could fail before the
 * assertions existed -- the first two-thirds of this file never touches a
 * descriptor twice.
 *
 * Prints "loopprobe: PASS" or "loopprobe: FAIL <step>"; exits 0/1.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>        /* FIONBIO */
#include <sys/time.h>         /* struct timeval, select */
#include <netinet/in.h>
#include <unistd.h>           /* close */
#include <fcntl.h>            /* open, O_RDONLY -- the `-x` fd-pressure mode */
#include <signal.h>           /* SIGALRM -- the `-u' eintr case */
#include <sys/wait.h>         /* WIFSIGNALED -- the `-t' reset case */

#define LOOPPORT 7777

/* One more than FS_MAX_FDS (include/fs.s, = 2.11BSD's NOFILE 30), so the fill
 * loop below always runs out before the array does and "never ran out" is a
 * loud failure rather than a silent truncation of the pressure it is applying. */
#define FDFILL   34

/* The payload buffers.  A stack local would work as well -- a socket call's
 * buffer carries its own bank (apple/fgx#480), and unixprobe asserts that. */
char g_buf[64];
char g_out[64];
#define C2S      "ping-to-server"
#define S2C      "pong-to-client"

/* select(2)'s timeout, as telnet(1) keeps its own. */
struct timeval g_tv;

static int fail(step)
char *step;
{
    printf("loopprobe: FAIL %s\n", step);
    exit(1);
}

/* ---- `-2`: TWO listeners, which is the only shape that tests the port
 *      compare (apple/fgx#127).
 *
 * _Loop_FindListener matched a listener by port with `CMP _loopDstPort / PLY /
 * BEQ`, and PLY sets N/Z from the PULLED value -- so the branch tested "is the
 * record offset zero", not the port.  Both halves were wrong: descriptor 0
 * matched EVERY port, and a listener at any nonzero offset could never match.
 *
 * ONE listener cannot see either half, because the only listener a caller binds
 * lands at descriptor 0, where the buggy test and the correct one agree.  That
 * is why the main case above passed throughout.
 *
 * SO THE DECOY IS BOUND FIRST, AND ON THE LOWER PORT: first so it takes
 * descriptor 0, lower so a scan that happened to order by port would still not
 * pick the wanted one by luck.  The connect then targets the SECOND listener,
 * which is the one at a nonzero offset.
 *
 * THIS CANNOT SHARE A PROCESS WITH THE MAIN CASE, and the reason is a real
 * limit rather than tidiness: socket() claims one of only three usable W5100
 * hardware sockets (0 is reserved for /dev/bpf0) and a descriptor that turns
 * out to be loopback never gives it back, so three socket() calls exhaust the
 * machine.  This mode makes exactly three, plus accept()'s descriptor, which
 * costs none.  Four descriptors against SOCKD_MAX 4, three hw sockets against
 * three: it fits exactly, with nothing to spare.
 * ---- */
#define DECOYPORT 7778
#define WANTPORT  7779

static int two_listener()
{
    int decoy, ls, cs, as, n, arg;
    struct sockaddr_in sin;

    for (n = 0; n < sizeof(sin); n++) ((char *)&sin)[n] = 0;
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = htonl(0x7F000001);        /* 127.0.0.1 */

    /* decoy first -> descriptor 0 */
    decoy = socket(AF_INET, SOCK_STREAM, 0);
    if (decoy < 0) fail("two-socket-decoy");
    sin.sin_port = htons(DECOYPORT);
    if (bind(decoy, &sin, sizeof(sin)) < 0) fail("two-bind-decoy");
    if (listen(decoy, 1) < 0)               fail("two-listen-decoy");

    /* the wanted listener -> a NONZERO descriptor */
    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) fail("two-socket-listen");
    sin.sin_port = htons(WANTPORT);
    if (bind(ls, &sin, sizeof(sin)) < 0) fail("two-bind-listen");
    if (listen(ls, 1) < 0)               fail("two-listen-listen");

    cs = socket(AF_INET, SOCK_STREAM, 0);
    if (cs < 0) fail("two-socket-connect");
    if (connect(cs, &sin, sizeof(sin)) < 0) fail("two-connect");

    /* Non-blocking, so the defect reports itself instead of hanging the
     * fixture: with the port compare broken the connect above was wired to the
     * DECOY, so this listener has nothing pending and accept says EWOULDBLOCK.
     * connect() sets the pending flag before it returns and this is one
     * process, so there is no race for the non-blocking form to lose. */
    arg = 1;
    if (ioctl(ls, FIONBIO, (char *)&arg) < 0) fail("two-ioctl-set");
    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as < 0) fail("two-accept-wrong-listener");
    arg = 0;
    if (ioctl(as, FIONBIO, (char *)&arg) < 0) fail("two-ioctl-clear");

    /* Reaching accept is not enough on its own -- prove the pair actually
     * carries bytes, so a wiring that paired the wrong rings cannot pass. */
    strcpy(g_out, C2S);
    n = send(cs, g_out, strlen(g_out), 0);
    if (n != strlen(C2S)) fail("two-send");
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    n = recv(as, g_buf, sizeof(g_buf) - 1, 0);
    if (n != strlen(C2S))   fail("two-recv-len");
    if (strcmp(g_buf, C2S)) fail("two-recv-data");

    close(as);
    close(cs);
    close(ls);
    close(decoy);
    printf("loopprobe: TWO OK second listener reached\n");
    exit(0);
}

/* ---- `-0`: bind(2) TO PORT 0 PICKS A PORT, and getsockname(2) says which.
 *
 * 2.11BSD in_pcbbind: `if (lport == 0) do { ... head->inp_lport++ ... }'
 * (vendor/2.11BSD/usr/sys/netinet/in_pcb.c:97) -- the port is chosen AT BIND,
 * so a program can name it before listen().  ftp(1)'s initconn does exactly
 * that: bind the data socket to port 0, getsockname, and send the port to the
 * server in a PORT command.  Both of this tree's bind arms recorded the 0, so
 * ftp sent `PORT a,b,c,d,0,0' and vsftpd answered `500 Illegal PORT command'.
 *
 * Two binds, one per arm: 0.0.0.0 goes to net_op_bind's hardware path and
 * 127.0.0.1 to _Loop_BindTry.  Each must report a port of at least
 * IPPORT_RESERVED, and they must differ.  THE CONNECT IS THE PART THAT CAN TELL
 * A REPORTED PORT FROM A BOUND ONE: a getsockname that invented a number would
 * pass the first checks, but connecting to it finds no listener.
 * ---- */
static int zero_port()
{
    int wd, ls, cs, as, n, len;
    unsigned wport, lport;
    struct sockaddr_in sin, got;

    for (n = 0; n < sizeof(sin); n++) ((char *)&sin)[n] = 0;
    sin.sin_family = AF_INET;

    wd = socket(AF_INET, SOCK_STREAM, 0);
    if (wd < 0) fail("zero-socket-wild");
    if (bind(wd, &sin, sizeof(sin)) < 0) fail("zero-bind-wild");
    len = sizeof(got);
    if (getsockname(wd, &got, &len) < 0) fail("zero-getsockname-wild");
    wport = ntohs(got.sin_port);
    close(wd);

    sin.sin_addr.s_addr = htonl(0x7F000001);        /* 127.0.0.1 */
    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) fail("zero-socket-loop");
    if (bind(ls, &sin, sizeof(sin)) < 0) fail("zero-bind-loop");
    len = sizeof(got);
    if (getsockname(ls, &got, &len) < 0) fail("zero-getsockname-loop");
    lport = ntohs(got.sin_port);
    printf("loopprobe: zero ports wild %u loop %u\n", wport, lport);
    if (wport < 1024) fail("zero-port-wild");
    if (lport < 1024) fail("zero-port-loop");
    if (wport == lport) fail("zero-port-same");
    if (listen(ls, 1) < 0) fail("zero-listen");

    cs = socket(AF_INET, SOCK_STREAM, 0);
    if (cs < 0) fail("zero-socket-connect");
    sin.sin_port = got.sin_port;
    if (connect(cs, &sin, sizeof(sin)) < 0) fail("zero-connect");
    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as < 0) fail("zero-accept");

    close(as);
    close(cs);
    close(ls);
    printf("loopprobe: ZERO OK bind picks the port\n");
    exit(0);
}

/* ---- `-x`: AN ACCEPT THAT FAILS ON RESOURCES MUST BE RETRYABLE
 *      (apple/fgx#145, second edge).
 *
 * _Loop_AcceptTry used to wire the accepted end, cross-link the pair and
 * CONSUME the listener's SLF_PENDING flag, and only then ask for an fd.  So an
 * fd shortage produced three kinds of stuck from one failure: a fully wired
 * descriptor with no fd that nothing would ever free (a SOCKD slot gone for the
 * boot), a connector left believing it was talking to a peer no process could
 * reach, and a listener that would never offer the connection again because the
 * flag was already spent.
 *
 * THE RETRY IS THE ASSERTION, and it is the only one that can see this.  A test
 * that checked accept() returns -1/EMFILE under pressure passes with the defect
 * present -- that part was always correct.  What the defect destroys is the
 * state AFTER the failure, so the probe has to fill the fd table, watch the
 * accept fail, free ONE fd, and then require the same connection to be
 * acceptable.  Under the bug the pending flag is gone and the second accept
 * finds nothing; the listener is non-blocking by then so it says EWOULDBLOCK
 * instead of sleeping for the rest of the fixture's timeout.
 *
 * Separate process from the main case for the reason two_listener is: socket()
 * takes one of only three usable W5100 slots and a loopback descriptor gives it
 * back only at teardown. ---- */
#define XPORT 7780

static int fd_exhaust()
{
    int fds[FDFILL], i, f;

    for (i = 0; i < FDFILL; i++) fds[i] = -1;
    for (i = 0; i < FDFILL; i++) {
        f = open("/etc/rc", O_RDONLY);
        if (f < 0) break;
        fds[i] = f;
    }
    /* SAY HOW MANY AND WHY IT STOPPED.  "accept succeeded under pressure" is
     * a claim about the fd table being full, and this loop is the only thing
     * that makes it so -- if open stopped for a reason other than a full
     * descriptor table (ENFILE from the shared file_pool, say, or ENOENT
     * because the file it opens is not there) the pressure was never applied
     * and the failure downstream describes the wrong subject. */
    printf("loopprobe: x-fill got %d fd(s), open stopped with errno %d\n",
           i, errno);
    if (i == 0)     fail("x-open-none");
    if (i >= FDFILL) fail("x-open-never-ran-out");
    return fds[i - 1];          /* the last one we got: our release valve */
}

static int accept_pressure()
{
    int ls, cs, as, spare, arg, n;
    struct sockaddr_in sin;

    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) fail("x-socket-listen");
    for (n = 0; n < sizeof(sin); n++) ((char *)&sin)[n] = 0;
    sin.sin_family = AF_INET;
    sin.sin_port   = htons(XPORT);
    sin.sin_addr.s_addr = htonl(0x7F000001);
    if (bind(ls, &sin, sizeof(sin)) < 0) fail("x-bind");
    if (listen(ls, 1) < 0)               fail("x-listen");

    cs = socket(AF_INET, SOCK_STREAM, 0);
    if (cs < 0) fail("x-socket-connect");
    if (connect(cs, &sin, sizeof(sin)) < 0) fail("x-connect");

    /* Non-blocking BEFORE the pressure: a listener with nothing pending sleeps,
     * and after the defect eats the flag that is exactly the state we are in.
     * A fixture that hangs reports nothing; one that says EWOULDBLOCK names the
     * defect. */
    arg = 1;
    if (ioctl(ls, FIONBIO, (char *)&arg) < 0) fail("x-ioctl-set");

    spare = fd_exhaust();

    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as >= 0)        fail("x-accept-succeeded-under-pressure");
    if (errno != EMFILE) fail("x-accept-errno");

    close(spare);               /* one fd back; the connection is still queued */

    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as < 0) fail("x-retry-refused");

    /* Reaching an fd is not enough -- prove the pair carries bytes, so a retry
     * that handed back a half-wired descriptor cannot pass. */
    strcpy(g_out, C2S);
    n = send(cs, g_out, strlen(g_out), 0);
    if (n != strlen(C2S)) fail("x-send");
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    n = recv(as, g_buf, sizeof(g_buf) - 1, 0);
    if (n != strlen(C2S))   fail("x-recv-len");
    if (strcmp(g_buf, C2S)) fail("x-recv-data");

    printf("loopprobe: X OK accept retryable after EMFILE\n");
    exit(0);
}

/* apple/fgx#440 -- THE DATAGRAM ARG BLOCKS CARRY THEIR FLAGS WORD.
 * `sendto' and `recvfrom' stopped short of it in libc, so MSG_OOB and
 * MSG_DONTWAIT were discarded before the kernel could honour or refuse them.
 * The word is read now, and MSG_OOB is refused for the same reason it is on
 * `send'/`recv': no transport here carries urgent data (apple/fgx#422).
 *
 * THIS RUNS ON A MACHINE WITH NO NETWORK CARD, which is what the loopprobe
 * fixtures boot.  socket() allocates out of a bitmap and touches no chip, and
 * both refusals are answered as soon as the descriptor resolves -- ahead of
 * _Sock_EnsureBound and ahead of any W5100 transaction.  A flags-0 datagram
 * call would reach the chip, so there is deliberately none here; the two
 * offsets are held to their kernel counterparts by tools/check_sock_argblk.py
 * instead, which is the only check that can see them disagree.
 *
 * The bad-fd arm is the ordering assertion: upstream resolves the socket
 * before splitting on MSG_OOB (`getsock()' in `sendit()' ahead of `sosend()'),
 * so a closed descriptor must answer EBADF and not the refusal.
 */
static int datagram_argblk()
{
    int s, n, fl;
    struct sockaddr_in to;
    char b[4];

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) fail("dgram-socket");

    for (n = 0; n < sizeof(to); n++) ((char *)&to)[n] = 0;
    to.sin_family = AF_INET;
    to.sin_port   = htons(9);
    to.sin_addr.s_addr = htonl(0x7F000001);

    b[0] = 'x';
    errno = 0;
    n = sendto(s, b, 1, MSG_OOB, (struct sockaddr *)&to, sizeof(to));
    if (n != -1)             fail("dgram-sendto-oob-accepted");
    if (errno != EOPNOTSUPP) fail("dgram-sendto-oob-errno");

    fl = sizeof(to);
    errno = 0;
    n = recvfrom(s, b, sizeof(b), MSG_OOB, (struct sockaddr *)&to, &fl);
    if (n != -1)             fail("dgram-recvfrom-oob-accepted");
    if (errno != EOPNOTSUPP) fail("dgram-recvfrom-oob-errno");

    close(s);

    /* Closed now, so the descriptor cannot resolve: EBADF, not the refusal. */
    errno = 0;
    n = sendto(s, b, 1, MSG_OOB, (struct sockaddr *)&to, sizeof(to));
    if (n != -1)        fail("dgram-badfd-accepted");
    if (errno != EBADF) fail("dgram-badfd-errno");
    return 0;
}

/* apple/fgx#439 -- setsockopt(2) VALIDATES WHAT IT IS GIVEN.
 * It used to answer 0 for everything: any option name, at any level, with the
 * value and its length discarded in libc before the kernel could see them.  So
 * an option this machine has never heard of was accepted, and SO_BROADCAST
 * could be turned on but never off -- passing a zero to clear it set it.
 *
 * THE SUCCESSES ARE THE HALF THAT CAN GO RED THE OTHER WAY.  A handler that
 * refused everything would satisfy all four error arms below; the three
 * accepted calls are what pins it to upstream's list rather than to "no".
 * SO_LINGER is asked for by NUMBER, as <sys/socket.h> does not name it.  The
 * socket is the network stack's, whose sosetopt is 2.11BSD's
 * (uipc_socket.c): SO_LINGER takes a struct linger, and an int-sized value is
 * EINVAL (`m->m_len != sizeof (struct linger)').
 *
 * Hardware-free: the socket is the kernel stack's, over lo0 or nothing.
 */
static int sockopt_check()
{
    int s, on, off, r;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) fail("sockopt-socket");
    on = 1;
    off = 0;

    if (setsockopt(s, SOL_SOCKET, SO_BROADCAST, (char *)&on, sizeof(on)) < 0)
        fail("sockopt-broadcast-refused");
    if (setsockopt(s, SOL_SOCKET, SO_DEBUG, (char *)&on, sizeof(on)) < 0)
        fail("sockopt-debug-refused");
    if (setsockopt(s, SOL_SOCKET, SO_BROADCAST, (char *)&off, sizeof(off)) < 0)
        fail("sockopt-broadcast-clear-refused");

    errno = 0;
    r = setsockopt(s, SOL_SOCKET, 0x4321, (char *)&on, sizeof(on));
    if (r != -1)              fail("sockopt-unknown-accepted");
    if (errno != ENOPROTOOPT) fail("sockopt-unknown-errno");

    errno = 0;                                  /* SO_LINGER: not a struct linger */
    r = setsockopt(s, SOL_SOCKET, 0x0080, (char *)&on, sizeof(on));
    if (r != -1)              fail("sockopt-linger-accepted");
    if (errno != EINVAL)      fail("sockopt-linger-errno");

    errno = 0;                                  /* udp's pr_ctloutput, ip_ctloutput: */
    r = setsockopt(s, IPPROTO_TCP, SO_BROADCAST, (char *)&on, sizeof(on));
    if (r != -1)              fail("sockopt-level-accepted");
    if (errno != EINVAL)      fail("sockopt-level-errno");   /* not IPPROTO_IP */

    errno = 0;                                  /* too small to hold an int */
    r = setsockopt(s, SOL_SOCKET, SO_BROADCAST, (char *)&on, 1);
    if (r != -1)             fail("sockopt-shortlen-accepted");
    if (errno != EINVAL)     fail("sockopt-shortlen-errno");

    close(s);
    errno = 0;
    r = setsockopt(s, SOL_SOCKET, SO_BROADCAST, (char *)&on, sizeof(on));
    if (r != -1)        fail("sockopt-badfd-accepted");
    if (errno != EBADF) fail("sockopt-badfd-errno");
    return 0;
}

/* ---- `-u`: UDP ON THE KERNEL'S STACK, over lo0 (net-mux S3).
 *
 * Every AF_INET datagram socket is a 2.11BSD socket in the network modules,
 * reached through net.mod's descriptor, so each case below is upstream's
 * behavior and names the file it comes from.  Each prints `UDP FAIL <case>'
 * and the run goes on, so one failure does not hide the next; `UDP OK' only
 * when none failed.  A blocking call that never returns is a failure too: the
 * harness's frame cap catches it, and the cases that may block say so.
 * ---- */
#define UDPPORT  7790
static int ufails;

static void
ufail(what, v)
char *what;
int v;
{
    printf("UDP FAIL %s %d\n", what, v);
    ufails++;
}

static void
uaddr(sin, port)
struct sockaddr_in *sin;
int port;
{
    int n;

    for (n = 0; n < sizeof(*sin); n++) ((char *)sin)[n] = 0;
    sin->sin_family = AF_INET;
    sin->sin_port = htons(port);
    sin->sin_addr.s_addr = htonl(0x7F000001);
}

static int
ubound(port)
int port;
{
    struct sockaddr_in sin;
    int s;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) { ufail("socket", errno); return -1; }
    uaddr(&sin, port);
    if (bind(s, &sin, sizeof(sin)) < 0) { ufail("bind", errno); close(s); return -1; }
    return s;
}

/* readable now, by a zero-timeout select */
static int
uready(s)
int s;
{
    fd_set rd;

    FD_ZERO(&rd);
    FD_SET(s, &rd);
    g_tv.tv_sec = 0;
    g_tv.tv_usec = 0;
    return select(s + 1, &rd, (fd_set *)0, (fd_set *)0, &g_tv);
}

/* pair: a datagram both ways between two bound sockets, and recvfrom names
 * the sender (udp_input hands the source to sbappendaddr). */
static void
u_pair()
{
    struct sockaddr_in to, from;
    int a, b, n, fl;

    a = ubound(UDPPORT);
    b = ubound(UDPPORT + 1);
    if (a < 0 || b < 0) return;
    uaddr(&to, UDPPORT + 1);
    if (sendto(a, "a2b", 3, 0, &to, sizeof(to)) != 3) ufail("pair-send", errno);
    fl = sizeof(from);
    n = recvfrom(b, g_buf, sizeof(g_buf), 0, &from, &fl);
    if (n != 3 || strncmp(g_buf, "a2b", 3) != 0) ufail("pair-recv", n);
    if (ntohs(from.sin_port) != UDPPORT || fl != sizeof(from)) ufail("pair-from", ntohs(from.sin_port));
    uaddr(&to, UDPPORT);
    if (sendto(b, "b2a!", 4, 0, &to, sizeof(to)) != 4) ufail("pair-back", errno);
    n = recv(a, g_buf, sizeof(g_buf), 0);
    if (n != 4 || strncmp(g_buf, "b2a!", 4) != 0) ufail("pair-backrecv", n);
    close(a);
    close(b);
}

/* zero: bind to port 0 picks one (in_pcbbind's noname arm), getsockname says it */
static void
u_zero()
{
    struct sockaddr_in sin;
    int s, len;

    s = ubound(0);
    if (s < 0) return;
    len = sizeof(sin);
    if (getsockname(s, &sin, &len) < 0) ufail("zero-getsockname", errno);
    else if (ntohs(sin.sin_port) < 1024) ufail("zero-port", ntohs(sin.sin_port));
    close(s);
}

/* conn: a connected socket sends without an address and hears only its peer
 * (in_pcblookup matches inp_faddr exactly). */
static void
u_conn()
{
    struct sockaddr_in to;
    int a, b, c, n;

    a = ubound(UDPPORT + 2);
    b = ubound(UDPPORT + 3);
    c = ubound(UDPPORT + 4);
    if (a < 0 || b < 0 || c < 0) return;
    uaddr(&to, UDPPORT + 3);
    if (connect(a, &to, sizeof(to)) < 0) ufail("conn-connect", errno);
    if (send(a, "hi", 2, 0) != 2) ufail("conn-send", errno);
    n = recv(b, g_buf, sizeof(g_buf), 0);
    if (n != 2) ufail("conn-recv", n);
    uaddr(&to, UDPPORT + 2);
    if (sendto(c, "stray", 5, 0, &to, sizeof(to)) != 5) ufail("conn-stray-send", errno);
    if (uready(a) != 0) ufail("conn-stray-delivered", 1);
    close(a);
    close(b);
    close(c);
}

/* sel: readable only once a datagram is queued (soo_select).  FIONREAD is
 * soo_ioctl's so_rcv.sb_cc, which on a datagram socket counts the sender's
 * address as well: sbappendaddr (uipc_socket2.c) sballoc's the address mbuf
 * with the data, so 7 bytes from a sockaddr_in read 7 + 16. */
static void
u_sel()
{
    struct sockaddr_in to;
    int a, b, n, nread;

    a = ubound(UDPPORT + 5);
    b = ubound(UDPPORT + 6);
    if (a < 0 || b < 0) return;
    if (uready(b) != 0) ufail("sel-idle-readable", 1);
    nread = -1;
    if (ioctl(b, FIONREAD, &nread) < 0 || nread != 0) ufail("sel-idle-nread", nread);
    uaddr(&to, UDPPORT + 6);
    if (sendto(a, "seven!!", 7, 0, &to, sizeof(to)) != 7) ufail("sel-send", errno);
    if (uready(b) != 1) ufail("sel-not-readable", 0);
    nread = -1;
    if (ioctl(b, FIONREAD, &nread) < 0 || nread != 7 + sizeof(struct sockaddr_in))
        ufail("sel-nread", nread);
    n = recv(b, g_buf, sizeof(g_buf), 0);
    if (n != 7) ufail("sel-recv", n);
    close(a);
    close(b);
}

/* selwake: a select with no timeout, blocked on an empty socket, returns when
 * a child sends to it, within a second or so of the send.  sbselqueue arms
 * sb_sel and sowakeup's selwakeup wakes the select channel; the kernel's idle
 * loop rescans every blocked select at 60 Hz as well (sched.s), so this case
 * shows the wakeup arrives, and cannot show which of the two delivered it.
 * BLOCKS if neither does. */
extern long time();

static void
u_selwake()
{
    struct sockaddr_in to;
    fd_set rd;
    long t0, t;
    int a, s, n;

    a = ubound(UDPPORT + 7);
    if (a < 0) return;
    t0 = time((long *)0);
    if (fork() == 0) {
        sleep(1);
        s = socket(AF_INET, SOCK_DGRAM, 0);
        uaddr(&to, UDPPORT + 7);
        sendto(s, "wake", 4, 0, &to, sizeof(to));
        exit(0);
    }
    FD_ZERO(&rd);
    FD_SET(a, &rd);
    n = select(a + 1, &rd, (fd_set *)0, (fd_set *)0, (struct timeval *)0);
    t = time((long *)0) - t0;
    if (n != 1 || !FD_ISSET(a, &rd)) ufail("selwake", n);
    if (t >= 4) ufail("selwake-late", (int)t);
    wait((int *)0);
    close(a);
}

/* big: 300 bytes, more than one mbuf holds, both ways and intact: udp_input
 * checks the checksum over the chain (in_cksum across mbuf boundaries). */
static char ubig[300], ubig2[300];

static void
u_big()
{
    struct sockaddr_in to;
    int a, b, n, i;

    a = ubound(UDPPORT + 11);
    b = ubound(UDPPORT + 12);
    if (a < 0 || b < 0) return;
    for (i = 0; i < sizeof(ubig); i++) ubig[i] = i * 7 + 3;
    uaddr(&to, UDPPORT + 12);
    if (sendto(a, ubig, sizeof(ubig), 0, &to, sizeof(to)) != sizeof(ubig))
        ufail("big-send", errno);
    n = recv(b, ubig2, sizeof(ubig2), 0);
    if (n != sizeof(ubig)) ufail("big-recv", n);
    else
        for (i = 0; i < sizeof(ubig); i++)
            if (ubig2[i] != ubig[i]) { ufail("big-byte", i); break; }
    close(a);
    close(b);
}

/* eintr: a blocking recvfrom that a signal interrupts answers -1 and EINTR,
 * the handler having run, and the socket still works afterward (2.11BSD's
 * sleep: EINTR in u_error and a longjmp to the syscall's setjmp). */
static int ualarmed;

static void
uonalarm(sig)
int sig;
{
    ualarmed++;
}

static void
u_eintr()
{
    struct sockaddr_in to;
    int a, b, n;

    a = ubound(UDPPORT + 13);
    b = ubound(UDPPORT + 14);
    if (a < 0 || b < 0) return;
    ualarmed = 0;
    signal(SIGALRM, uonalarm);
    alarm(1);
    errno = 0;
    n = recv(a, g_buf, sizeof(g_buf), 0);
    alarm(0);
    if (n != -1 || errno != EINTR) ufail("eintr", errno);
    if (ualarmed != 1) ufail("eintr-handler", ualarmed);
    uaddr(&to, UDPPORT + 13);
    if (sendto(b, "after", 5, 0, &to, sizeof(to)) != 5) ufail("eintr-send", errno);
    n = recv(a, g_buf, sizeof(g_buf), 0);
    if (n != 5) ufail("eintr-after", n);
    close(a);
    close(b);
}

/* two: two processes inside the stack at once.  A child sleeps in recvfrom
 * while the parent, on a socket connected to a port nobody holds, sends, has
 * the ICMP port unreachable come back, and gets ECONNREFUSED on its next send
 * (udp_ctlinput reaches only a pcb whose inp_faddr matches, in_pcbnotify).
 * Then a signal breaks the child's sleep: its recvfrom must answer -1 and
 * EINTR, which means the longjmp went to the child's own setjmp and not to
 * one the parent's calls made meanwhile -- the u area each sleeper keeps.
 * The child's next read gets the parent's datagram with its own length. */
static void
u_two()
{
    struct sockaddr_in to;
    int a, c, pid, n, st;

    a = ubound(UDPPORT + 15);
    if (a < 0) return;
    pid = fork();
    if (pid == 0) {
        ualarmed = 0;
        signal(SIGUSR1, uonalarm);
        errno = 0;
        n = recv(a, g_buf, sizeof(g_buf), 0);
        if (n != -1 || errno != EINTR || ualarmed != 1)
            exit(2);
        n = recv(a, g_buf, sizeof(g_buf), 0);
        exit(n == 6 ? 0 : 3);
    }
    c = socket(AF_INET, SOCK_DGRAM, 0);
    uaddr(&to, UDPPORT + 16);                 /* bound by nobody */
    if (connect(c, &to, sizeof(to)) < 0) ufail("two-connect", errno);
    if (send(c, "x", 1, 0) != 1) ufail("two-send", errno);
    sleep(1);                                 /* the unreachable comes back */
    errno = 0;
    if (send(c, "x", 1, 0) != -1 || errno != ECONNREFUSED)
        ufail("two-refused", errno);
    close(c);
    kill(pid, SIGUSR1);
    sleep(1);
    c = socket(AF_INET, SOCK_DGRAM, 0);
    uaddr(&to, UDPPORT + 15);
    if (sendto(c, "child!", 6, 0, &to, sizeof(to)) != 6) ufail("two-tochild", errno);
    st = -1;
    wait(&st);
    if (st != 0) ufail("two-child", st);
    close(c);
    close(a);
}

/* fork: a socket shared across fork stays open until its last reference
 * goes; the child closing it leaves the parent able to use it (soclose runs
 * once, at the last close). */
static void
u_fork()
{
    struct sockaddr_in to;
    int a, b, n, st;

    a = ubound(UDPPORT + 17);
    b = ubound(UDPPORT + 18);
    if (a < 0 || b < 0) return;
    if (fork() == 0) {
        close(a);
        exit(0);
    }
    wait(&st);
    uaddr(&to, UDPPORT + 18);
    if (sendto(a, "still", 5, 0, &to, sizeof(to)) != 5) ufail("fork-send", errno);
    n = recv(b, g_buf, sizeof(g_buf), 0);
    if (n != 5) ufail("fork-recv", n);
    close(a);
    close(b);
}

/* size: a 200-byte datagram read with a 50-byte buffer gives 50, and the rest
 * is gone -- the next read is the next datagram (soreceive drops the record
 * of an atomic protocol).  A send over the send buffer's high water mark is
 * EMSGSIZE (sosend, sosendallatonce). */
static char usz[200];
static char uhuge[2100];

static void
u_size()
{
    struct sockaddr_in to;
    int a, b, n;

    a = ubound(UDPPORT + 19);
    b = ubound(UDPPORT + 20);
    if (a < 0 || b < 0) return;
    uaddr(&to, UDPPORT + 20);
    if (sendto(a, usz, sizeof(usz), 0, &to, sizeof(to)) != sizeof(usz))
        ufail("size-send", errno);
    if (sendto(a, "next", 4, 0, &to, sizeof(to)) != 4) ufail("size-send2", errno);
    n = recv(b, g_buf, 50, 0);
    if (n != 50) ufail("size-trunc", n);
    n = recv(b, g_buf, sizeof(g_buf), 0);
    if (n != 4 || strncmp(g_buf, "next", 4) != 0) ufail("size-next", n);
    errno = 0;
    if (sendto(a, uhuge, sizeof(uhuge), 0, &to, sizeof(to)) != -1 || errno != EMSGSIZE)
        ufail("size-emsgsize", errno);
    close(a);
    close(b);
}

/* nbio: non-blocking reads of an empty socket answer EAGAIN, by FIONBIO and by
 * MSG_DONTWAIT (soreceive's SS_NBIO arm).  BLOCKS if the bit is lost. */
static void
u_nbio()
{
    int b, on;

    b = ubound(UDPPORT + 8);
    if (b < 0) return;
    errno = 0;
    if (recv(b, g_buf, sizeof(g_buf), MSG_DONTWAIT) != -1 || errno != EAGAIN)
        ufail("nbio-dontwait", errno);
    on = 1;
    if (ioctl(b, FIONBIO, &on) < 0) ufail("nbio-ioctl", errno);
    errno = 0;
    if (read(b, g_buf, 8) != -1 || errno != EAGAIN) ufail("nbio-read", errno);
    close(b);
}

/* inuse: a second bind to a held port is EADDRINUSE, and SO_REUSEADDR on the
 * wildcard and the specific address lets both bind (in_pcbbind) */
static void
u_inuse()
{
    struct sockaddr_in sin;
    int a, b, on;

    a = ubound(UDPPORT + 9);
    if (a < 0) return;
    b = socket(AF_INET, SOCK_DGRAM, 0);
    uaddr(&sin, UDPPORT + 9);
    errno = 0;
    if (bind(b, &sin, sizeof(sin)) != -1 || errno != EADDRINUSE) ufail("inuse", errno);
    close(b);
    close(a);
    a = socket(AF_INET, SOCK_DGRAM, 0);
    b = socket(AF_INET, SOCK_DGRAM, 0);
    on = 1;
    setsockopt(a, SOL_SOCKET, SO_REUSEADDR, (char *)&on, sizeof(on));
    setsockopt(b, SOL_SOCKET, SO_REUSEADDR, (char *)&on, sizeof(on));
    uaddr(&sin, UDPPORT + 10);
    sin.sin_addr.s_addr = 0;
    if (bind(a, &sin, sizeof(sin)) < 0) ufail("reuse-wild", errno);
    uaddr(&sin, UDPPORT + 10);
    if (bind(b, &sin, sizeof(sin)) < 0) ufail("reuse-specific", errno);
    close(a);
    close(b);
}

/* closed: a send on a closed descriptor is EBADF, ahead of anything else */
static void
u_closed()
{
    struct sockaddr_in to;
    int s;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    close(s);
    uaddr(&to, UDPPORT);
    errno = 0;
    if (sendto(s, "x", 1, 0, &to, sizeof(to)) != -1 || errno != EBADF) ufail("closed", errno);
}

/* many: more UDP sockets than net.mod's old descriptor table held (12), each
 * sending one datagram to the first, which reads them all. */
#define UMANY 20
static void
u_many()
{
    struct sockaddr_in to;
    int s[UMANY], i, n, got;

    for (i = 0; i < UMANY; i++) {
        s[i] = ubound(UDPPORT + 10 + i);
        if (s[i] < 0) {
            ufail("many-socket", i);
            while (--i >= 0) close(s[i]);
            return;
        }
    }
    uaddr(&to, UDPPORT + 10);
    for (i = 0; i < UMANY; i++)
        if (sendto(s[i], "m", 1, 0, &to, sizeof(to)) != 1) ufail("many-send", i);
    for (got = 0; got < UMANY; got++) {
        n = recv(s[0], g_buf, sizeof(g_buf), 0);
        if (n != 1) break;
    }
    if (got != UMANY) ufail("many-recv", got);
    for (i = 0; i < UMANY; i++) close(s[i]);
}

/* ---- `-t': TCP ON THE KERNEL'S STACK, over lo0 (net-mux S4).
 *
 * Each case prints `TCP FAIL <case> <value>' and the run goes on; `TCP OK' only
 * when none failed.  A case that blocks forever shows as the frame cap.
 * ---- */
#define TCPPORT  7820
static int tfails, n_errsave;
static char tbuf[1024], tbuf2[1024];

static void
tfail(what, v)
char *what;
int v;
{
    printf("TCP FAIL %s %d\n", what, v);
    tfails++;
}

/* a listener on 127.0.0.1:port */
static int
tlisten(port, backlog)
int port, backlog;
{
    struct sockaddr_in sin;
    int s;

    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) { tfail("socket", errno); return -1; }
    uaddr(&sin, port);
    if (bind(s, &sin, sizeof(sin)) < 0) { tfail("bind", errno); close(s); return -1; }
    if (listen(s, backlog) < 0) { tfail("listen", errno); close(s); return -1; }
    return s;
}

/* a blocking connect to 127.0.0.1:port; -1 with errno on failure */
static int
tconnect(port)
int port;
{
    struct sockaddr_in sin;
    int s;

    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return -1;
    uaddr(&sin, port);
    if (connect(s, &sin, sizeof(sin)) < 0) { n_errsave = errno; close(s); errno = n_errsave; return -1; }
    return s;
}

/* read exactly n bytes, or fewer at EOF/error; returns what it read */
static int
treadn(s, buf, n)
int s, n;
char *buf;
{
    int got, r;

    for (got = 0; got < n; got += r) {
        r = read(s, buf + got, n - got);
        if (r <= 0) break;
    }
    return got;
}

static void
tfill(buf, n, seed)
char *buf;
int n, seed;
{
    int i;

    for (i = 0; i < n; i++) buf[i] = (char)(i * 7 + seed);
}

/* echo: 10 KB each way in 1 KB rounds, byte-checked */
static void
t_echo()
{
    int ls, c, a, i;

    ls = tlisten(TCPPORT, 1);
    if (ls < 0) return;
    c = tconnect(TCPPORT);
    if (c < 0) { tfail("echo-connect", errno); close(ls); return; }
    a = accept(ls, (struct sockaddr *)0, (int *)0);
    if (a < 0) { tfail("echo-accept", errno); close(c); close(ls); return; }
    for (i = 0; i < 10; i++) {
        tfill(tbuf, 1024, i);
        if (write(c, tbuf, 1024) != 1024) { tfail("echo-write", errno); break; }
        if (treadn(a, tbuf2, 1024) != 1024 || memcmp(tbuf, tbuf2, 1024) != 0) { tfail("echo-c2s", i); break; }
        tfill(tbuf, 1024, i + 100);
        if (write(a, tbuf, 1024) != 1024) { tfail("echo-writeback", errno); break; }
        if (treadn(c, tbuf2, 1024) != 1024 || memcmp(tbuf, tbuf2, 1024) != 0) { tfail("echo-s2c", i); break; }
    }
    close(a);
    close(c);
    close(ls);
}

/* nb: a non-blocking connect answers EINPROGRESS, is writable when done, and a
 * second connect answers EISCONN (2.11BSD connect(): SS_ISCONNECTING) */
static void
t_nb()
{
    struct sockaddr_in sin;
    fd_set wr;
    int ls, c, a, on;

    ls = tlisten(TCPPORT + 1, 1);
    if (ls < 0) return;
    c = socket(AF_INET, SOCK_STREAM, 0);
    on = 1;
    ioctl(c, FIONBIO, &on);
    uaddr(&sin, TCPPORT + 1);
    errno = 0;
    if (connect(c, &sin, sizeof(sin)) != -1 || errno != EINPROGRESS) tfail("nb-inprogress", errno);
    FD_ZERO(&wr);
    FD_SET(c, &wr);
    g_tv.tv_sec = 5;
    g_tv.tv_usec = 0;
    if (select(c + 1, (fd_set *)0, &wr, (fd_set *)0, &g_tv) != 1) tfail("nb-writable", errno);
    errno = 0;
    if (connect(c, &sin, sizeof(sin)) != -1 || errno != EISCONN) tfail("nb-isconn", errno);
    a = accept(ls, (struct sockaddr *)0, (int *)0);
    if (a < 0) tfail("nb-accept", errno);
    else close(a);
    close(c);
    close(ls);
}

/* refused: nobody listens, tcp_input answers the SYN with a reset */
static void
t_refused()
{
    errno = 0;
    if (tconnect(TCPPORT + 2) != -1 || errno != ECONNREFUSED) tfail("refused", errno);
}

/* drain: the client writes 6 KB and closes at once; the server reads all of it,
 * then end of file (soclose -> sodisconnect -> tcp_usrclosed sends after the data) */
static void
t_drain()
{
    int ls, a, c, n, got;

    ls = tlisten(TCPPORT + 3, 1);
    if (ls < 0) return;
    if (fork() == 0) {
        c = tconnect(TCPPORT + 3);
        if (c < 0) exit(2);
        for (n = 0; n < 6; n++) {
            tfill(tbuf, 1024, n);
            if (write(c, tbuf, 1024) != 1024) exit(3);
        }
        close(c);
        exit(0);
    }
    a = accept(ls, (struct sockaddr *)0, (int *)0);
    if (a < 0) { tfail("drain-accept", errno); close(ls); wait((int *)0); return; }
    for (got = 0; (n = read(a, tbuf, sizeof(tbuf))) > 0; got += n)
        ;
    if (got != 6144 || n != 0) tfail("drain", got);
    close(a);
    close(ls);
    wait((int *)0);
}

/* reset: SO_LINGER with 0 makes close a reset (tcp_disconnect -> tcp_drop); the
 * peer's read answers ECONNRESET, and a write after it EPIPE and SIGPIPE, which
 * kills a child that does not catch it (sosend's NETPSIGNAL) */
static void
t_reset()
{
    struct linger lg;
    int ls, c, a, st;

    ls = tlisten(TCPPORT + 4, 1);
    if (ls < 0) return;
    c = tconnect(TCPPORT + 4);
    if (c < 0) { tfail("reset-connect", errno); close(ls); return; }
    a = accept(ls, (struct sockaddr *)0, (int *)0);
    if (a < 0) { tfail("reset-accept", errno); close(c); close(ls); return; }
    lg.l_onoff = 1;
    lg.l_linger = 0;
    if (setsockopt(a, SOL_SOCKET, SO_LINGER, (char *)&lg, sizeof(lg)) < 0) tfail("reset-linger", errno);
    close(a);
    errno = 0;
    if (read(c, tbuf, 10) != -1 || errno != ECONNRESET) tfail("reset-read", errno);
    if (fork() == 0) {
        signal(SIGPIPE, SIG_DFL);
        write(c, "x", 1);
        exit(0);
    }
    st = 0;
    wait(&st);
    if (!WIFSIGNALED(st) || WTERMSIG(st) != SIGPIPE) tfail("reset-sigpipe", st);
    close(c);
    close(ls);
}

/* fork: a child takes a connection off a shared listener and exits; its peer
 * sees end of file, and the parent's listener still accepts (soclose only at the
 * last reference) */
static void
t_fork()
{
    int ls, c1, c2, a, a2;

    ls = tlisten(TCPPORT + 5, 2);
    if (ls < 0) return;
    c1 = tconnect(TCPPORT + 5);
    if (c1 < 0) { tfail("fork-connect", errno); close(ls); return; }
    if (fork() == 0) {
        a = accept(ls, (struct sockaddr *)0, (int *)0);
        exit(a < 0);
    }
    wait((int *)0);
    if (read(c1, tbuf, 10) != 0) tfail("fork-eof", errno);
    c2 = tconnect(TCPPORT + 5);
    if (c2 < 0) tfail("fork-connect2", errno);
    a2 = accept(ls, (struct sockaddr *)0, (int *)0);
    if (a2 < 0) tfail("fork-accept2", errno);
    else close(a2);
    if (c2 >= 0) close(c2);
    close(c1);
    close(ls);
}

/* oob: one urgent byte through send/recv MSG_OOB (tcp_output's URG, tcp_pulloutofband) */
static void
t_oob()
{
    int ls, c, a, i, n;

    ls = tlisten(TCPPORT + 6, 1);
    if (ls < 0) return;
    c = tconnect(TCPPORT + 6);
    a = accept(ls, (struct sockaddr *)0, (int *)0);
    if (c < 0 || a < 0) { tfail("oob-setup", errno); return; }
    if (send(c, "!", 1, MSG_OOB) != 1) tfail("oob-send", errno);
    n = -1;
    for (i = 0; i < 20 && n != 1; i++) {
        n = recv(a, tbuf, 1, MSG_OOB);
        if (n != 1) {
            g_tv.tv_sec = 0;
            g_tv.tv_usec = 100000;
            select(0, (fd_set *)0, (fd_set *)0, (fd_set *)0, &g_tv);
        }
    }
    if (n != 1 || tbuf[0] != '!') tfail("oob-recv", errno);
    close(a);
    close(c);
    close(ls);
}

/* name: both ends agree on who is who; accept names the peer */
static void
t_name()
{
    struct sockaddr_in cl, pe, ac;
    int ls, c, a, len, alen;

    ls = tlisten(TCPPORT + 7, 1);
    if (ls < 0) return;
    c = tconnect(TCPPORT + 7);
    alen = sizeof(ac);
    a = accept(ls, &ac, &alen);
    if (c < 0 || a < 0) { tfail("name-setup", errno); return; }
    len = sizeof(cl);
    if (getsockname(c, &cl, &len) < 0) tfail("name-sock", errno);
    len = sizeof(pe);
    if (getpeername(a, &pe, &len) < 0) tfail("name-peer", errno);
    if (cl.sin_port != pe.sin_port) tfail("name-ports", ntohs(pe.sin_port));
    if (alen != sizeof(ac) || ac.sin_port != cl.sin_port) tfail("name-accept", ntohs(ac.sin_port));
    len = sizeof(pe);
    if (getpeername(c, &pe, &len) < 0 || ntohs(pe.sin_port) != TCPPORT + 7) tfail("name-server", ntohs(pe.sin_port));
    close(a);
    close(c);
    close(ls);
}

static int
tcp_main()
{
    signal(SIGPIPE, SIG_IGN);
    t_echo();
    t_nb();
    t_refused();
    t_drain();
    t_reset();
    t_fork();
    t_oob();
    t_name();
    if (tfails == 0)
        printf("TCP OK\n");
    exit(tfails != 0);
}

/* ---- `-m': more connections at once than the chip has sockets (spec 6).  A
 * parent listens; a child makes MANYCONN connections and keeps them all open;
 * then each carries 1 KB both ways.  `MANY OK'. ---- */
#define MANYPORT 7840
#define MANYCONN 16

static int
many_main()
{
    int ls, c[MANYCONN], a[MANYCONN], i, st, bad;

    signal(SIGPIPE, SIG_IGN);
    ls = tlisten(MANYPORT, 5);
    if (ls < 0) exit(1);
    if (fork() == 0) {
        close(ls);
        for (i = 0; i < MANYCONN; i++) {
            c[i] = tconnect(MANYPORT);
            if (c[i] < 0) { printf("MANY FAIL connect %d %d\n", i, errno); exit(1); }
        }
        for (i = 0; i < MANYCONN; i++) {
            tfill(tbuf, 1024, i);
            if (write(c[i], tbuf, 1024) != 1024) { printf("MANY FAIL write %d %d\n", i, errno); exit(1); }
        }
        for (i = 0; i < MANYCONN; i++) {
            tfill(tbuf, 1024, i + 50);
            if (treadn(c[i], tbuf2, 1024) != 1024 || memcmp(tbuf, tbuf2, 1024) != 0) { printf("MANY FAIL back %d\n", i); exit(1); }
        }
        exit(0);
    }
    bad = 0;
    for (i = 0; i < MANYCONN; i++) {
        a[i] = accept(ls, (struct sockaddr *)0, (int *)0);
        if (a[i] < 0) { printf("MANY FAIL accept %d %d\n", i, errno); bad = 1; break; }
    }
    for (i = 0; !bad && i < MANYCONN; i++) {
        tfill(tbuf, 1024, i);
        if (treadn(a[i], tbuf2, 1024) != 1024 || memcmp(tbuf, tbuf2, 1024) != 0) { printf("MANY FAIL recv %d\n", i); bad = 1; }
    }
    for (i = 0; !bad && i < MANYCONN; i++) {
        tfill(tbuf, 1024, i + 50);
        if (write(a[i], tbuf, 1024) != 1024) { printf("MANY FAIL send %d %d\n", i, errno); bad = 1; }
    }
    st = 1;
    wait(&st);
    if (!bad && st == 0)
        printf("MANY OK\n");
    exit(0);
}

/* `-s': one syslog line, user.err, to 127.0.0.1:514, for syslogd -u to log
 * (netudp's script).  The text is built so the screen can only show it if it
 * arrived: the needle is the joined halves. */
static int
udp_syslog()
{
    struct sockaddr_in to;
    int s;
    static char line[] = "<11>loopprobe: kernel UDP to syslogd ok";

    s = socket(AF_INET, SOCK_DGRAM, 0);
    uaddr(&to, 514);
    if (s < 0 || sendto(s, line, sizeof(line) - 1, 0, &to, sizeof(to)) < 0)
        printf("UDP FAIL syslog %d\n", errno);
    exit(0);
}

static int
udp_main()
{
    u_pair();
    u_zero();
    u_conn();
    u_sel();
    u_selwake();
    u_big();
    u_eintr();
    u_two();
    u_fork();
    u_size();
    u_nbio();
    u_inuse();
    datagram_argblk();          /* oob: MSG_OOB is EOPNOTSUPP */
    u_closed();
    u_many();
    if (ufails == 0)
        printf("UDP OK\n");
    exit(ufails != 0);
}

main(argc, argv)
int argc;
char **argv;
{
    int  ls, cs, as, d, arg, n;
    struct sockaddr_in sin;

    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == '2')
        two_listener();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'x')
        accept_pressure();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == '0')
        zero_port();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 't')
        tcp_main();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'm')
        many_main();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'u')
        udp_main();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 's')
        udp_syslog();
    if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'n') {
        /* -n: a UDP socket, which only the network modules provide */
        if (socket(AF_INET, SOCK_DGRAM, 0) < 0) {
            perror("socket");
            exit(1);
        }
        printf("UDP socket opened\n");
        exit(0);
    }

    datagram_argblk();
    sockopt_check();

    /* ---- listener on 127.0.0.1:LOOPPORT ---- */
    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) fail("socket-listen");

    for (n = 0; n < sizeof(sin); n++) ((char *)&sin)[n] = 0;
    sin.sin_family = AF_INET;
    sin.sin_port   = htons(LOOPPORT);
    sin.sin_addr.s_addr = htonl(0x7F000001);        /* 127.0.0.1 */

    arg = 1;                /* a run right after another: TIME_WAIT */
    setsockopt(ls, SOL_SOCKET, SO_REUSEADDR, (char *)&arg, sizeof(arg));
    if (bind(ls, &sin, sizeof(sin)) < 0) fail("bind");
    if (listen(ls, 1) < 0)               fail("listen");

    /* ---- connect to ourselves.  This is the step that has to find the
     *      listener above and build the ring pair. ---- */
    cs = socket(AF_INET, SOCK_STREAM, 0);
    if (cs < 0) fail("socket-connect");
    if (connect(cs, &sin, sizeof(sin)) < 0) fail("connect");

    /* ---- accept: hands back the mirror end of the same pair ---- */
    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as < 0) fail("accept");

    /* ---- THE NEGATIVE ASSERTIONS, and they have to come first.
     *
     * Everything else in this file checks that a socket with data in it
     * reports itself ready.  None of that can fail if the kernel simply
     * answers "ready" to everything -- which is precisely what apple/fgx#98
     * and #99 measured: DELETING select's per-fd dispatch, and gutting the
     * socket ioctl arm to return ENOTTY, each left all 96 tests green.  This
     * test was already running at the time and did not notice, because its
     * one select() call samples the ready direction only.
     *
     * An EMPTY ring is the single state whose true answer differs from the
     * broken default, and it exists only before the first send.  Hence here.
     * ---- */
    {
        int rfds[2];
        int arg;

        /* #99 -- select must report NOTHING ready on an empty socket.
         * A zero timeval is a non-blocking poll (libc converts it to 0 ticks;
         * the kernel tests _Sel_Expired before it ever yields), so a wrong
         * answer fails the assertion rather than hanging the fixture. */
        g_tv.tv_sec  = 0;
        g_tv.tv_usec = 0;
        rfds[0] = 1 << as;
        rfds[1] = 0;
        if (select(as + 1, rfds, (void *)0, (void *)0, &g_tv) != 0)
            fail("select-empty-ready");
        if (rfds[0] & (1 << as))
            fail("select-empty-bit");

        /* apple/fgx#423 -- THE EXCEPTIONAL SET IS ASKED, AND ANSWERED "NO".
         * A socket with no urgent data has no exceptional condition, so a
         * select whose ONLY set is the exceptional one must report nothing
         * ready and must come back with the mask cleared.  That is the exact
         * shape of telnetd's stilloob(): select(s+1, 0, 0, &excepts, &timeout).
         *
         * THE MASK CHECK IS THE HALF THAT CAN GO RED ON ITS OWN.  A kernel
         * that never wrote _selExOut would satisfy the count check by leaving
         * the caller's input mask untouched, which reads as "this fd has an
         * exceptional condition" to any caller that tests the bit rather than
         * the count -- and stilloob tests the bit. */
        {
            int efds[2];

            efds[0] = 1 << as;
            efds[1] = 0;
            g_tv.tv_sec  = 0;
            g_tv.tv_usec = 0;
            if (select(as + 1, (void *)0, (void *)0, efds, &g_tv) != 0)
                fail("except-socket-ready");
            if (efds[0] & (1 << as))
                fail("except-socket-bit");
        }

        /* #98 -- FIONBIO must be ACCEPTED and must TAKE EFFECT.  The second
         * half is what makes this discriminating: an ioctl that returns 0 and
         * does nothing passes the first check on its own.  With SOCK_NB set,
         * a read of the still-empty ring must come back EWOULDBLOCK; if the
         * flag is ignored the read sleeps and the fixture times out. */
        arg = 1;
        if (ioctl(as, FIONBIO, (char *)&arg) < 0) fail("ioctl-fionbio-set");
        n = recv(as, g_buf, sizeof(g_buf) - 1, 0);
        if (n >= 0)                fail("nonblock-recv-got-data");
        if (errno != EWOULDBLOCK)  fail("nonblock-recv-errno");

        /* Back to blocking -- every assertion below assumes it. */
        arg = 0;
        if (ioctl(as, FIONBIO, (char *)&arg) < 0) fail("ioctl-fionbio-clear");

        /* apple/fgx#441 -- MSG_DONTWAIT IS THE OTHER WAY TO SAY "DO NOT
         * SLEEP", and only SOCK_NB was honoured.  The descriptor is back in
         * BLOCKING mode above, which is the whole point: the flag has to carry
         * the decision on its own, for this one call, without the caller
         * touching descriptor state.  The ring is still empty, so an ignored
         * flag sleeps and the fixture times out -- the same failure shape as
         * the FIONBIO check it sits beside, and the reason both live in this
         * window rather than after the first send.
         *
         * This also covers the SEND direction: _Loop_SoIo reads the call's
         * flags and folds them into the same non-blocking decision for both, so
         * one call exercises the code both take.  The W5100 half of the fix
         * (_Tcp_SendCore) needs a card and is not reachable from the suite. */
        errno = 0;
        n = recv(as, g_buf, sizeof(g_buf) - 1, MSG_DONTWAIT);
        if (n >= 0)               fail("dontwait-recv-got-data");
        if (errno != EWOULDBLOCK) fail("dontwait-recv-errno");

        /* #98/#97 -- FIONREAD on an EMPTY loopback socket must say zero.
         * The number has to come from the Rx ring: there is no W5100 socket
         * behind a loopback descriptor, and reading socket $FE's RX_RSR on a
         * machine with no card returns open bus, which is only accidentally
         * ever zero. */
        arg = -1;
        if (ioctl(as, FIONREAD, (char *)&arg) < 0) fail("ioctl-fionread-empty");
        if (arg != 0) fail("fionread-empty-nonzero");
    }

    /* ---- client -> server ---- */
    strcpy(g_out, C2S);
    n = send(cs, g_out, strlen(g_out), 0);
    if (n != strlen(C2S)) fail("send-c2s");
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    {   /* select() must see the loopback socket readable -- this is what the
         * telnet client relies on, and the only consumer of _Loop_StatusTry. */
        int rfds[2];
        rfds[0] = 0; rfds[1] = 0;
        rfds[0] = 1 << as;
        if (select(as + 1, rfds, (void *)0, (void *)0, (struct timeval *)0) <= 0)
            fail("select-readable");
        if ((rfds[0] & (1 << as)) == 0)
            fail("select-bit");
    }
    {   /* FIONREAD, now that there IS something to count.  Paired with the
         * empty-ring check above this is discriminating in both directions:
         * a stuck zero fails here, a stuck constant fails there, and only a
         * real count of the Rx ring satisfies both. */
        int avail;
        avail = -1;
        if (ioctl(as, FIONREAD, (char *)&avail) < 0) fail("ioctl-fionread");
        if (avail != strlen(C2S)) fail("fionread-count");
    }
    n = recv(as, g_buf, sizeof(g_buf) - 1, 0);
    if (n != strlen(C2S))    fail("recv-c2s-len");
    if (strcmp(g_buf, C2S))    fail("recv-c2s-data");

    /* ---- server -> client.  Uses the OTHER ring; a single direction would
     *      pass even with both ends bound to one ring. ---- */
    strcpy(g_out, S2C);
    n = send(as, g_out, strlen(g_out), 0);
    if (n != strlen(S2C)) fail("send-s2c");
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    n = recv(cs, g_buf, sizeof(g_buf) - 1, 0);
    if (n != strlen(S2C))    fail("recv-s2c-len");
    if (strcmp(g_buf, S2C))    fail("recv-s2c-data");


    /* ---- read(2)/write(2) on the socket: the fd-style path telnet(1) uses,
     *      which is NOT the same kernel route as send()/recv().  A short read
     *      here is exactly what stalled telnetd.  It ALSO proves the MSG_OOB
     *      arm above did not swallow the flags word for a path that has
     *      none -- read/write share the loopback tail. ---- */
    strcpy(g_out, C2S);
    n = write(cs, g_out, strlen(g_out));
    if (n != strlen(C2S)) fail("write-len");
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    n = read(as, g_buf, sizeof(g_buf) - 1);
    if (n != strlen(C2S)) fail("read-len");
    if (strcmp(g_buf, C2S)) fail("read-data");

    /* ---- apple/fgx#133 -- THE CLAIM MUST REFUSE AN INELIGIBLE DESCRIPTOR,
     *      and these are negative assertions for the same reason the empty-ring
     *      block is: nothing else here can tell a kernel that checks from one
     *      that says yes to everything.
     *
     * Claiming a descriptor for loopback RELEASES its W5100 slot, which is only
     * sound while that slot has never been OPENed on the chip.  Neither
     * pre-check asked, so a second connect() on a live connection -- or a rebind
     * -- handed a LIVE hardware socket back to the allocator; the next socket()
     * re-issued the index and two descriptors drove one chip socket.
     *
     * Both calls must fail, and the errno is checked too: a claim that succeeds
     * is the defect, and one that fails with the wrong errno is a different
     * bug wearing this one's clothes.  Neither call changes any state, so they
     * sit here rather than costing a second pair. ---- */
    if (connect(cs, &sin, sizeof(sin)) != -1) fail("reconnect-allowed");
    if (errno != EISCONN)                     fail("reconnect-errno");
    if (bind(ls, &sin, sizeof(sin)) != -1)    fail("rebind-allowed");
    if (errno != EINVAL)                      fail("rebind-errno");

    /* ---- apple/fgx#139 -- A CONNECT ON A LISTENER IS REFUSED, toward an
     *      address off lo0 as well.  2.11BSD's soconnect (sys/uipc_socket.c):
     *      `if (so->so_options & SO_ACCEPTCONN) return (EOPNOTSUPP);'.  The
     *      errno is asserted, not merely the failure: the defect this guarded
     *      failed too, with ETIMEDOUT, after spinning on the chip. ---- */
    {
        struct sockaddr_in wire;
        for (n = 0; n < sizeof(wire); n++) ((char *)&wire)[n] = 0;
        wire.sin_family = AF_INET;
        wire.sin_port   = htons(23);
        wire.sin_addr.s_addr = htonl(0x0A636363);      /* 10.99.99.99 */
        if (connect(ls, &wire, sizeof(wire)) != -1) fail("wire-on-loop-allowed");
        if (errno != EOPNOTSUPP)                    fail("wire-on-loop-errno");
    }

    /* ---- apple/fgx#142 -- getpeername(2) / getsockname(2).  Both were
     *      DECLARED in sys/socket.h and implemented nowhere, so a caller
     *      compiled clean and failed at LINK: a declaration reads as shipped.
     *
     * The VALUES are asserted, not merely the return code, and that is the
     * whole point of putting them here rather than in a standalone probe: a
     * pair of stubs returning 0 and leaving the buffer untouched passes any
     * check that only looks at the errno.  So each field is named.
     *
     * `as' is the ACCEPTED end.  Its local name is the listener's --
     * 127.0.0.1:LOOPPORT -- which is what BSD reports and what the kernel had
     * been leaving as zero, because until these calls existed nothing read
     * SOCK_LPort on an accepted descriptor.
     *
     * Its PEER is `cs', the connector, and a loopback connector is never given
     * a local port: connect(2) does not bind one.  So the peer port is 0 here,
     * honestly rather than fabricated -- the man page says so and apple/fgx#156
     * carries it.  THE PEER PORT IS DELIBERATELY NOT ASSERTED: a check for 0
     * would have to be rewritten the day #156 lands, and a check for nonzero
     * would be red today.  The ADDRESS is the part telnetd(8) wants and the
     * part that is right. ---- */
    {
        struct sockaddr_in nm;
        int nl;

        nl = sizeof(nm);
        for (n = 0; n < sizeof(nm); n++) ((char *)&nm)[n] = 0x5A;
        if (getsockname(as, &nm, &nl) < 0)  fail("getsockname");
        if (nl != sizeof(nm))               fail("getsockname-len");
        if (nm.sin_family != AF_INET)       fail("getsockname-family");
        if (nm.sin_addr.s_addr != htonl(0x7F000001)) fail("getsockname-addr");
        if (nm.sin_port != htons(LOOPPORT)) fail("getsockname-port");

        nl = sizeof(nm);
        for (n = 0; n < sizeof(nm); n++) ((char *)&nm)[n] = 0x5A;
        if (getpeername(as, &nm, &nl) < 0)  fail("getpeername");
        if (nm.sin_family != AF_INET)       fail("getpeername-family");
        if (nm.sin_addr.s_addr != htonl(0x7F000001)) fail("getpeername-addr");

        /* A LISTENER has no peer, and this is the negative half: a stub that
         * always succeeds passes everything above and fails here. */
        nl = sizeof(nm);
        if (getpeername(ls, &nm, &nl) != -1) fail("getpeername-listener-ok");
        if (errno != ENOTCONN)               fail("getpeername-listener-errno");

        /* A buffer too small for a whole record is refused rather than
         * short-written -- libc's half of the contract. */
        nl = 4;
        if (getsockname(as, &nm, &nl) != -1) fail("getsockname-short-ok");
        if (errno != EINVAL)                 fail("getsockname-short-errno");
    }

    /* ---- teardown: the peer's next read must see EOF, not hang ---- */
    close(cs);
    for (n = 0; n < sizeof(g_buf); n++) g_buf[n] = 0;
    n = recv(as, g_buf, sizeof(g_buf) - 1, 0);
    if (n != 0) fail("eof-after-close");

    close(as);

    /* ---- apple/fgx#134 -- dup2 MUST TEAR A SOCKET DOWN THE WAY close(2) DOES.
     *
     * dup2 closed an already-open target with a bare _Fcb_Free, which drops the
     * refcount and frees the FCB at zero while running no type teardown at all
     * -- the socket, pipe and chardev arms live only in Fs_Close.  So the
     * sequence below dropped the LAST reference to a connected socket inside
     * dup2: rings leaked and the peer never saw EOF.
     *
     * The observer is made NON-BLOCKING first, so the defect reports itself as
     * a failed assertion instead of hanging the fixture -- with the bug the
     * recv comes back EWOULDBLOCK, with the fix it comes back 0.  The listener
     * is still bound, so this costs a second pair of rings but no third
     * listener; the first pair was freed by the closes just above. ---- */
    cs = socket(AF_INET, SOCK_STREAM, 0);
    if (cs < 0)                             fail("dup2-socket");
    if (connect(cs, &sin, sizeof(sin)) < 0) fail("dup2-connect");
    as = accept(ls, (struct sockaddr *)0, (int *)0);
    if (as < 0)                             fail("dup2-accept");

    arg = 1;
    if (ioctl(cs, FIONBIO, (char *)&arg) < 0) fail("dup2-fionbio");

    d = dup2(as, 9);                     /* two references to one socket FCB */
    if (d < 0)                              fail("dup2-target");
    close(as);                           /* d is now the only one */
    if (dup2(ls, d) < 0)                    fail("dup2-overwrite");
                                         /* ...and it died inside that dup2 */
    n = recv(cs, g_buf, sizeof(g_buf) - 1, 0);
    if (n != 0)                             fail("dup2-no-eof");

    close(cs);
    close(d);
    close(ls);

    printf("loopprobe: PASS both directions + EOF\n");
    exit(0);
}
