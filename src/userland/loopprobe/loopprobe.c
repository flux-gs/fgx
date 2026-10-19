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
 * SO_LINGER is asked for by NUMBER because it is deliberately not in
 * <sys/socket.h>: it is a real BSD option with no implementation here, so
 * naming it in the header would be the absent-behaviour-behind-a-present-
 * interface pattern, and it must be refused like any other unknown.
 *
 * Hardware-free: the handler resolves the descriptor and touches SOCK_Flags.
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

    errno = 0;                                  /* SO_LINGER: real, unimplemented */
    r = setsockopt(s, SOL_SOCKET, 0x0080, (char *)&on, sizeof(on));
    if (r != -1)              fail("sockopt-linger-accepted");
    if (errno != ENOPROTOOPT) fail("sockopt-linger-errno");

    errno = 0;                                  /* no pr_ctloutput at this level */
    r = setsockopt(s, IPPROTO_TCP, SO_BROADCAST, (char *)&on, sizeof(on));
    if (r != -1)              fail("sockopt-level-accepted");
    if (errno != ENOPROTOOPT) fail("sockopt-level-errno");

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

    datagram_argblk();
    sockopt_check();

    /* ---- listener on 127.0.0.1:LOOPPORT ---- */
    ls = socket(AF_INET, SOCK_STREAM, 0);
    if (ls < 0) fail("socket-listen");

    for (n = 0; n < sizeof(sin); n++) ((char *)&sin)[n] = 0;
    sin.sin_family = AF_INET;
    sin.sin_port   = htons(LOOPPORT);
    sin.sin_addr.s_addr = htonl(0x7F000001);        /* 127.0.0.1 */

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

    /* ---- apple/fgx#422 -- MSG_OOB IS REFUSED, NOT SILENTLY DEMOTED.
     *      Loopback is pipe-backed and a pipe has no urgent mark, so neither
     *      direction can carry out-of-band.  Before this, both calls returned
     *      SUCCESS and moved ordinary bytes, so a caller believed it had sent
     *      urgent data and the reader never learned any had arrived.
     *
     *      THE TWO ROUND TRIPS ABOVE ARE THIS BLOCK'S CONTROL.  They run the
     *      same two rings with flags = 0 and must still pass: an arm that
     *      refused every send, or that read the flags word from the wrong
     *      offset, fails there rather than here.  The byte count is checked
     *      as well as the errno, because a refusal that consumed the bytes
     *      first would leave the ring desynchronised for everything below. ---- */
    strcpy(g_out, C2S);
    errno = 0;
    n = send(cs, g_out, strlen(g_out), MSG_OOB);
    if (n != -1)              fail("oob-send-accepted");
    if (errno != EOPNOTSUPP)  fail("oob-send-errno");
    errno = 0;
    n = recv(as, g_buf, sizeof(g_buf) - 1, MSG_OOB);
    if (n != -1)              fail("oob-recv-accepted");
    if (errno != EOPNOTSUPP)  fail("oob-recv-errno");
    /* The refused send must have moved nothing: the ring is still empty. */
    if (ioctl(as, FIONREAD, (char *)&arg) < 0) fail("oob-fionread");
    if (arg != 0) fail("oob-send-left-bytes");

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

    /* ---- apple/fgx#139 -- AND THE HARDWARE PATH MUST REFUSE A DESCRIPTOR
     *      ALREADY CLAIMED FOR LOOPBACK.  The pair to the two calls above,
     *      asked from the other side: those are "a loopback claim must refuse
     *      a live chip socket", this is "the chip path must refuse a loopback
     *      descriptor".
     *
     * `ls' is claimed for loopback, so its SOCK_HwIdx is the sentinel
     * SOCK_HW_LOOP ($FE).  connect() to a NON-127 address falls straight
     * through the loopback pre-check -- _Loop_ConnectTry declines a
     * destination that is not its own -- and into the wire arm, which had no
     * bound check, so $FE was used as a W5100 socket NUMBER and _W5_SetSnAR
     * computed a register address well past the four real socket blocks.
     *
     * The errno is asserted, not merely the failure: this call ALREADY failed
     * before the fix, with ETIMEDOUT after spinning out a full 16-bit counter
     * waiting for a chip state that open bus was never going to report.  A
     * test that accepted any failure would have been green with the defect
     * present, which is the exact shape of vacuous assertion this file's other
     * negative blocks exist to avoid. ---- */
    {
        struct sockaddr_in wire;
        for (n = 0; n < sizeof(wire); n++) ((char *)&wire)[n] = 0;
        wire.sin_family = AF_INET;
        wire.sin_port   = htons(23);
        wire.sin_addr.s_addr = htonl(0x0A636363);      /* 10.99.99.99 */
        if (connect(ls, &wire, sizeof(wire)) != -1) fail("wire-on-loop-allowed");
        if (errno != EINVAL)                        fail("wire-on-loop-errno");
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
