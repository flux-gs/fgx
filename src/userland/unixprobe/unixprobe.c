/* unixprobe - prove the AF_UNIX SOCK_DGRAM transport end to end, headless,
 * with no hardware, no peer process and no network.
 *
 * FGX-Provenance: none.  Original FGX code.  The errno and address-family
 * numbers it compares against come from 2.11BSD's <errno.h> and
 * <sys/socket.h>, and naming the source of a constant is not derivation.
 *
 * One process does the whole closed loop, which is deliberate: it needs no
 * second program, no host-side helper and no network, so it runs under MAME as
 * an ordinary fixture.
 *
 * WHY IT PROVES SOMETHING.  A descriptor is serviced by the AF_UNIX transport
 * only when SOCK_Proto carries XPORT_UNIX, and socket() sets that from the
 * DOMAIN argument alone.  So reaching a successful socket() at all means the
 * new arm ran.  And because the AF_UNIX arm never calls _W5_SockAlloc, three
 * consecutive AF_UNIX sockets must ALL succeed on a machine with three usable
 * hardware sockets -- which is what separates "AF_UNIX works" from "AF_UNIX
 * quietly borrowed the W5100".
 *
 * IT CARRIES THE NEGATIVE ASSERTIONS, and that is the point rather than an
 * extra.  A kernel that answered every socket() with a descriptor would pass a
 * positive-only probe.  SOCK_STREAM must be REFUSED with EPROTOTYPE: upstream's
 * SOCK_STREAM AF_UNIX is what pipe(2) is built from, this kernel has real
 * pipes, and the design scopes it out -- so a silent success there would hand a
 * caller a descriptor with no transport behind it.
 *
 * THE BUFFERS ARE MOSTLY static AND ONE ARM'S ARE NOT.  A socket call's buffer
 * carries its own bank (apple/fgx#480), so a stack local works; the stack-bank
 * arm near the end is the one that asserts it, and every other arm keeps its
 * buffers in the data segment so it measures one thing.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <fcntl.h>
#include <unistd.h>
#include <fgx.h>

/* One byte past PIPE_MAX_BUFSZ (include/kernel.s), so the oversize case is
 * oversize even after the ring has grown to its ceiling. */
#define UNP_PAST_CEILING 4097

/* AN AF_UNIX ADDRESS IS NOT A `struct sockaddr'.  sun_path is 108 bytes
 * (2.11BSD usr/sys/h/un.h:20), where a sockaddr is 16 in total -- and sizing the
 * buffer as a sockaddr truncated every path at 13 characters, so bind(2) named
 * `/tmp/unixprob' and SUCCEEDED while the stat of the intended name answered
 * ENOENT.  <sys/un.h> carries the size now. */
#define UNP_SA_SIZE      SUN_LEN

/* The MESSAGES are literals, strcpy'd into txbuf before each send. */
#define SOCKNAME "/tmp/unixprobe.sock"
#define REGNAME  "/tmp/unixprobe.reg"

static char *msg[3] = { "a", "bbbb", "ccccccccc" };
#define UIO_PAST_MAX 17         /* one past 2.11BSD's aiov[16] */
static char  txbuf[64];
static char  rxbuf[64];
static char  big[UNP_PAST_CEILING];

/* A sockaddr_un in the data segment: family in the first two bytes, the path
 * from offset 2, NUL-terminated.  Built here rather than with a struct because
 * fcc pads struct members and the kernel reads these by raw offset -- the same
 * reason src/userland/lib/socket_h.h uses offsets for sockaddr_in. */
static void
unp_mkaddr(sa, path)
char *sa;
char *path;
{
    int i;

    for (i = 0; i < UNP_SA_SIZE; i++)
        sa[i] = '\0';
    sa[0] = AF_UNIX;
    for (i = 0; path[i] != '\0' && i < SUN_PATH_MAX - 1; i++)
        sa[2 + i] = path[i];
}

int
main()
{
    int        fd[3];
    int        i;
    int        r;
    int        n;

    /* POSITIVE CONTROL FIRST: SOCK_STREAM must be refused.  If this SUCCEEDS,
     * the transport is answering requests it has no implementation for, and
     * every later PASS in this file is worthless. */
    r = socket(AF_UNIX, SOCK_STREAM, 0);
    if (r >= 0) {
        printf("unixprobe: FAIL stream-not-refused fd=%d\n", r);
        return (1);
    }
    if (errno != EPROTOTYPE) {
        printf("unixprobe: FAIL stream-wrong-errno %d\n", errno);
        return (1);
    }

    /* Three descriptors, none of which may consume a W5100 socket.  The
     * machine has three usable -- socket 0 is reserved for /dev/bpf0 MACRAW,
     * so _W5_SockAlloc hands out 1..3.  Three AF_UNIX sockets that each took
     * one would exhaust the chip exactly, so this passing is necessary but not
     * sufficient; the interleaved AF_INET check below is what makes it sharp. */
    for (i = 0; i < 3; i++) {
        fd[i] = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (fd[i] < 0) {
            printf("unixprobe: FAIL socket-%d errno=%d\n", i, errno);
            return (1);
        }
    }

    /* THE SHARP ASSERTION: with three AF_UNIX sockets open, all three W5100
     * slots must still be free.  A UDP socket needs a real one, so if the
     * AF_UNIX arm had borrowed even one this fails -- and it fails HERE, where
     * the cause is unambiguous, rather than in some later test whose socket()
     * mysteriously ran out. */
    r = socket(AF_INET, SOCK_DGRAM, 0);
    if (r < 0) {
        printf("unixprobe: FAIL unix-stole-hw errno=%d\n", errno);
        return (1);
    }
    (void)close(r);

    /* AN IDLE UDP SOCKET IS NOT READABLE (apple/fgx#296), and syslogd's select
     * loop is what made that matter: with -u it holds a UDP socket bound to
     * 0.0.0.0:514 beside /dev/log and /dev/klog.  On a machine with no card
     * every chip register read is whatever the bus last carried, and measured
     * here before the fix: select alternated readable and not, FIONREAD read
     * 0, -7968, -8064, and recvfrom answered 0 bytes as a success -- so the
     * daemon spun, logging `recvfrom inet' to the console several times a
     * second.  FOUR ROUNDS, because one clean answer from noise proves nothing.
     *
     * With a card and no traffic the same three answers hold.  Without one, a
     * send has no interface to leave by, and 2.11BSD's in_pcbconnect, which
     * udp_output calls for a sendto, answers EADDRNOTAVAIL. */
    {
        static char usin[16];
        static char uifr[32];
        fd_set urd;
        struct timeval utv;
        int us, uk, un, unav, ucard;

        uifr[8] = 0;                            /* IFC_GETN: interface 0 */
        ucard = ifctl(0, uifr) == 0;
        us = socket(AF_INET, SOCK_DGRAM, 0);
        memset(usin, 0, sizeof usin);
        usin[0] = AF_INET;
        usin[2] = 0x02;                         /* port 514, network order */
        usin[3] = 0x02;
        if (us < 0 || bind(us, (struct sockaddr *)usin, sizeof usin) < 0) {
            printf("unixprobe: FAIL udp-bind errno=%d\n", errno);
            return (1);
        }
        for (uk = 0; uk < 4; uk++) {
            FD_ZERO(&urd);
            FD_SET(us, &urd);
            utv.tv_sec = 0;
            utv.tv_usec = 0;
            un = select(us + 1, &urd, (fd_set *)0, (fd_set *)0, &utv);
            if (un != 0) {
                printf("unixprobe: FAIL udp-idle-readable k=%d n=%d\n", uk, un);
                return (1);
            }
            unav = -1;
            (void)ioctl(us, FIONREAD, &unav);
            if (unav != 0) {
                printf("unixprobe: FAIL udp-idle-nread k=%d n=%d\n", uk, unav);
                return (1);
            }
            errno = 0;
            if (recvfrom(us, rxbuf, sizeof rxbuf, 0, (char *)0, (int *)0) >= 0 ||
                errno != EAGAIN) {
                printf("unixprobe: FAIL udp-idle-recv k=%d errno=%d\n", uk, errno);
                return (1);
            }
        }
        /* AND THROUGH read(2) UNDER FIONBIO, which is how apple/fgx#296 first
         * showed it: the ioctl succeeding and the read then returning 8 bytes
         * off the floating bus as though a datagram had arrived.  read(2) is
         * its own road into the transport, not recvfrom's. */
        uk = 1;
        if (ioctl(us, FIONBIO, &uk) != 0) {
            printf("unixprobe: FAIL udp-fionbio errno=%d\n", errno);
            return (1);
        }
        errno = 0;
        un = read(us, rxbuf, 8);
        if (un >= 0 || errno != EAGAIN) {
            printf("unixprobe: FAIL udp-nbio-read n=%d errno=%d\n", un, errno);
            return (1);
        }
        uk = 0;
        (void)ioctl(us, FIONBIO, &uk);
        if (!ucard) {
            usin[4] = 10;                       /* 10.0.0.1 */
            usin[7] = 1;
            if (sendto(us, txbuf, 1, 0, (struct sockaddr *)usin, sizeof usin) >= 0 ||
                errno != EADDRNOTAVAIL) {
                printf("unixprobe: FAIL udp-nocard-send errno=%d\n", errno);
                return (1);
            }
        }
        (void)close(us);
    }

    /* ---- datagrams between a paired sender and receiver ----------------
     *
     * fd[1] binds a name and fd[0] connects to it by path, which is what
     * unp_bind and unp_connect do upstream: the sockaddr carries a real
     * filesystem path and the node it makes is a VSOCK.
     */
    {
        static char sa[UNP_SA_SIZE];

        (void)unlink(SOCKNAME);
        unp_mkaddr(sa, SOCKNAME);
        if (bind(fd[1], (struct sockaddr *)sa, UNP_SA_SIZE) < 0) {
            printf("unixprobe: FAIL bind errno=%d\n", errno);
            return (1);
        }
        /* THE NODE IS A SOCKET ON THE VOLUME, not the regular file ufs_create
         * would have made before it honoured VSOCK. */
        {
            struct stat sb;

            if (stat(SOCKNAME, &sb) < 0) {
                printf("unixprobe: FAIL bind-no-node errno=%d\n", errno);
                return (1);
            }
            if (!S_ISSOCK(sb.st_mode)) {
                printf("unixprobe: FAIL bind-wrong-type mode=%o\n",
                       (unsigned)sb.st_mode);
                return (1);
            }
        }
        /* POSITIVE CONTROL 1: a SECOND bind of the same name is EADDRINUSE.
         * Upstream's comment marks adopt-and-wakeup as a FIFO-style improvement
         * it did not make, so a silent success here would leave two sockets
         * believing they own one name. */
        if (bind(fd[2], (struct sockaddr *)sa, UNP_SA_SIZE) >= 0) {
            printf("unixprobe: FAIL rebind-accepted\n");
            return (1);
        }
        if (errno != EADDRINUSE) {
            printf("unixprobe: FAIL rebind-errno %d\n", errno);
            return (1);
        }
        /* POSITIVE CONTROL 2: connect to a REGULAR FILE is ENOTSOCK.  Without
         * that check connect would hand back a descriptor paired to a vnode with
         * no socket behind it. */
        {
            static char sar[UNP_SA_SIZE];
            int         tf;

            tf = creat(REGNAME, 0666);
            if (tf >= 0)
                (void)close(tf);
            unp_mkaddr(sar, REGNAME);
            if (connect(fd[0], (struct sockaddr *)sar, UNP_SA_SIZE) >= 0) {
                printf("unixprobe: FAIL connect-regfile-accepted\n");
                return (1);
            }
            if (errno != ENOTSOCK) {
                printf("unixprobe: FAIL connect-regfile-errno %d\n", errno);
                return (1);
            }
        }
        if (connect(fd[0], (struct sockaddr *)sa, UNP_SA_SIZE) < 0) {
            printf("unixprobe: FAIL connect errno=%d\n", errno);
            return (1);
        }

        /* BOUNDARIES.  Three writes of DIFFERENT lengths, then three reads.  A
         * byte-stream ring hands back 1+4+9 as one 14-byte read; a
         * boundary-preserving one gives exactly three records.  One round trip
         * cannot tell those apart, which is why there are three. */
        for (i = 0; i < 3; i++) {
            strcpy(txbuf, msg[i]);
            n = strlen(txbuf);
            if (send(fd[0], txbuf, n, 0) != n) {
                printf("unixprobe: FAIL send-%d errno=%d\n", i, errno);
                return (1);
            }
        }
        for (i = 0; i < 3; i++) {
            n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
            if (n != (int)strlen(msg[i])) {
                printf("unixprobe: FAIL recv-%d got=%d want=%d\n",
                       i, n, (int)strlen(msg[i]));
                return (1);
            }
            rxbuf[n] = '\0';
            if (strcmp(rxbuf, msg[i]) != 0) {
                printf("unixprobe: FAIL recv-%d content b0=%d b1=%d n=%d\n",
                       i, rxbuf[0] & 0xFF, rxbuf[1] & 0xFF, n);
                return (1);
            }
        }

        /* POSITIVE CONTROL: a datagram past the ring's CEILING must be refused
         * WHOLE.  A truncating send would split one message across two records
         * and every boundary after it is lost -- and the next recv would return
         * plausible bytes, so nothing downstream could notice.  The second half
         * of the assertion is the one that catches truncation: the ring must
         * still be usable afterwards.
         *
         * EMSGSIZE, not ENOBUFS.  2.11BSD splits the two and sosend answers this
         * one before PRU_SEND is entered: "if (sosendallatonce(so) &&
         * uio->uio_resid > so->so_snd.sb_hiwat) return (EMSGSIZE);"
         * (usr/sys/sys/uipc_socket.c:311).  ENOBUFS is for a receiver with no
         * room right now, which the next case covers. */
        if (send(fd[0], big, sizeof big, 0) >= 0) {
            printf("unixprobe: FAIL oversize-accepted\n");
            return (1);
        }
        if (errno != EMSGSIZE) {
            printf("unixprobe: FAIL oversize-errno %d\n", errno);
            return (1);
        }

        /* THE 16-BIT WRAP, and this is the assertion the earlier probe could not
         * make.  A length of -1 reaches the kernel as $FFFF; adding the 3-byte
         * header wraps it to $0002, which passes any ceiling test written after
         * the add.  The record would be accepted with a header claiming 65535,
         * the payload write would stop short of it, and the next recv would drop
         * 65472 bytes from a ring holding far fewer -- underflowing PIPE_Count and
         * leaving that ring unable to frame a record ever again.  One unprivileged
         * call, and from unp_bind on the ring is /dev/log.
         *
         * The ring must still work afterwards, which is what separates "refused"
         * from "refused after damage". */
        if (send(fd[0], txbuf, -1, 0) >= 0) {
            printf("unixprobe: FAIL wrap-accepted\n");
            return (1);
        }
        if (errno != EMSGSIZE) {
            printf("unixprobe: FAIL wrap-errno %d\n", errno);
            return (1);
        }
        /* AND THE RING MUST BE UNDAMAGED, which the errno alone does not show.
         * Refusing at the carry is what stops the write happening at all; a guard
         * further down -- catching the short payload write after the header is
         * already in the ring -- turns the silent corruption into an error return
         * but leaves the bad record behind.  So the assertion is a round trip,
         * not a refusal. */
        txbuf[0] = 'r';
        if (send(fd[0], txbuf, 1, 0) != 1) {
            printf("unixprobe: FAIL post-wrap-send errno=%d\n", errno);
            return (1);
        }
        n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
        if (n != 1 || rxbuf[0] != 'r') {
            printf("unixprobe: FAIL ring-broken-after-wrap n=%d b0=%d\n",
                   n, rxbuf[0] & 0xFF);
            return (1);
        }
        txbuf[0] = 'z';
        if (send(fd[0], txbuf, 1, 0) != 1) {
            printf("unixprobe: FAIL post-refusal-send errno=%d\n", errno);
            return (1);
        }
        n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
        if (n != 1 || rxbuf[0] != 'z') {
            printf("unixprobe: FAIL ring-corrupt-after-refusal n=%d\n", n);
            return (1);
        }

        /* A ZERO-LENGTH DATAGRAM IS A DELIVERED DATAGRAM.  It carries a header
         * and no payload, so a receiver that asks the ring for 0 payload bytes
         * finds nothing resident -- and before the wait was hoisted out of the
         * payload read, it slept forever on a record that had already arrived. */
        if (send(fd[0], txbuf, 0, 0) != 0) {
            printf("unixprobe: FAIL zero-send errno=%d\n", errno);
            return (1);
        }
        n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
        if (n != 0) {
            printf("unixprobe: FAIL zero-recv n=%d\n", n);
            return (1);
        }

        /* NON-BLOCKING MUST BE HONOURED, or a select-driven reader -- which is
         * what syslogd is -- blocks in the kernel with no way out.  Both the
         * DESCRIPTOR's flag and the
         * CALL's flag must work; net_loop.s honours both and its comment names
         * apple/fgx#441 as the defect from honouring only one. */
        {
            int one = 1;

            if (recv(fd[1], rxbuf, sizeof rxbuf - 1, MSG_DONTWAIT) >= 0) {
                printf("unixprobe: FAIL dontwait-returned-data\n");
                return (1);
            }
            if (errno != EAGAIN) {
                printf("unixprobe: FAIL dontwait-errno %d\n", errno);
                return (1);
            }
            if (ioctl(fd[1], FIONBIO, &one) < 0) {
                printf("unixprobe: FAIL fionbio errno=%d\n", errno);
                return (1);
            }
            if (recv(fd[1], rxbuf, sizeof rxbuf - 1, 0) >= 0) {
                printf("unixprobe: FAIL sockNb-returned-data\n");
                return (1);
            }
            if (errno != EAGAIN) {
                printf("unixprobe: FAIL sockNb-errno %d\n", errno);
                return (1);
            }
            one = 0;
            (void)ioctl(fd[1], FIONBIO, &one);
        }

        /* SELECT(2) MUST ANSWER FOR AN AF_UNIX DESCRIPTOR.  This is the whole
         * of syslogd's main loop: it sits in select(20, &readfds, ...) over
         * /dev/klog and the socket together (syslogd.c:299), so a transport
         * that never reports ready leaves it asleep with messages waiting.
         *
         * THREE PROBES, BECAUSE ANY ONE OF THEM ALONE IS A CONSTANT: not
         * readable while the ring is empty, readable once a datagram is
         * resident, and not readable again once it has been taken.  A single
         * "ready" assertion would pass against a transport that answered ready
         * unconditionally, which is the failure mode one arm over.
         *
         * WRITABLE THROUGHOUT, and that is upstream rather than an accident:
         * the local domain's SOCK_DGRAM protosw entry carries no
         * PR_CONNREQUIRED (2.11BSD usr/sys/sys/uipc_proto.c), so sowriteable()'s
         * connected clause is vacuous and a datagram socket is writable whether
         * or not it ever connected. */
        {
            fd_set rfds, wfds;
            struct timeval tv;
            int r;

            FD_ZERO(&rfds); FD_SET(fd[1], &rfds);
            FD_ZERO(&wfds); FD_SET(fd[1], &wfds);
            tv.tv_sec = 0; tv.tv_usec = 0;
            r = select(fd[1] + 1, &rfds, &wfds, (void *)0, &tv);
            if (r < 0) {
                printf("unixprobe: FAIL select-empty errno=%d\n", errno);
                return (1);
            }
            if (FD_ISSET(fd[1], &rfds)) {
                printf("unixprobe: FAIL select-empty-readable\n");
                return (1);
            }
            if (!FD_ISSET(fd[1], &wfds)) {
                printf("unixprobe: FAIL select-empty-not-writable\n");
                return (1);
            }

            if (send(fd[0], txbuf, 4, 0) != 4) {
                printf("unixprobe: FAIL select-send errno=%d\n", errno);
                return (1);
            }
            FD_ZERO(&rfds); FD_SET(fd[1], &rfds);
            tv.tv_sec = 0; tv.tv_usec = 0;
            r = select(fd[1] + 1, &rfds, (void *)0, (void *)0, &tv);
            if (r <= 0 || !FD_ISSET(fd[1], &rfds)) {
                printf("unixprobe: FAIL select-ready r=%d\n", r);
                return (1);
            }
            n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
            if (n != 4) {
                printf("unixprobe: FAIL select-recv n=%d\n", n);
                return (1);
            }
            FD_ZERO(&rfds); FD_SET(fd[1], &rfds);
            tv.tv_sec = 0; tv.tv_usec = 0;
            r = select(fd[1] + 1, &rfds, (void *)0, (void *)0, &tv);
            if (r < 0 || FD_ISSET(fd[1], &rfds)) {
                printf("unixprobe: FAIL select-drained r=%d\n", r);
                return (1);
            }
            printf("unixprobe: select ok\n");
        }

        /* TRUNCATION: a payload larger than the caller's buffer is cut, and the
         * remainder must be DISCARDED rather than left to be read as the next
         * record's header.  Asking for 4 of 9 bytes then reading again must give
         * the NEXT message, not the tail of this one. */
        strcpy(txbuf, msg[2]);
        if (send(fd[0], txbuf, 9, 0) != 9) {
            printf("unixprobe: FAIL trunc-setup-1 errno=%d\n", errno);
            return (1);
        }
        strcpy(txbuf, "tail");
        if (send(fd[0], txbuf, 4, 0) != 4) {
            printf("unixprobe: FAIL trunc-setup-2 errno=%d\n", errno);
            return (1);
        }
        n = recv(fd[1], rxbuf, 4, 0);
        if (n != 4) {
            printf("unixprobe: FAIL trunc-short n=%d\n", n);
            return (1);
        }
        n = recv(fd[1], rxbuf, sizeof rxbuf - 1, 0);
        rxbuf[n > 0 ? n : 0] = '\0';
        if (n != 4 || strcmp(rxbuf, "tail") != 0) {
            printf("unixprobe: FAIL trunc-remainder n=%d '%s'\n", n, rxbuf);
            return (1);
        }
    }

    for (i = 0; i < 3; i++)
        (void)close(fd[i]);

    /* close() MUST FREE THE RECEIVE RING.  Only a bound socket owns one, and
     * nothing else releases it: the loopback teardown claims a descriptor only
     * when it carries the loopback sentinel, and an AF_UNIX one does not, so the
     * generic arm used to free the descriptor and leak the pipe slot.  NPIPE is 8
     * for the whole machine and shared with shell pipes, so a leak here stops
     * pipe(2) working system-wide after eight of these.
     *
     * TEN ROUNDS, NOT EIGHT: the count has to exceed NPIPE for the leak to bite,
     * and a run that merely equals it proves nothing. */
    {
        static char sa2[UNP_SA_SIZE];
        int         a, b, k;

        for (k = 0; k < 10; k++) {
            a = socket(AF_UNIX, SOCK_DGRAM, 0);
            b = socket(AF_UNIX, SOCK_DGRAM, 0);
            if (a < 0 || b < 0) {
                printf("unixprobe: FAIL leak-socket round=%d errno=%d\n",
                       k, errno);
                return (1);
            }
            (void)unlink(SOCKNAME);
            unp_mkaddr(sa2, SOCKNAME);
            if (bind(b, (struct sockaddr *)sa2, UNP_SA_SIZE) < 0) {
                printf("unixprobe: FAIL leak-bind round=%d errno=%d\n",
                       k, errno);
                return (1);
            }
            if (connect(a, (struct sockaddr *)sa2, UNP_SA_SIZE) < 0) {
                printf("unixprobe: FAIL leak-connect round=%d errno=%d\n",
                       k, errno);
                return (1);
            }
            (void)close(a);
            (void)close(b);
        }
    }

    /* WHAT IS *NOT* ASSERTED HERE, AND WHAT COVERS IT INSTEAD.
     *
     * unp_bind ends VOP_UNLOCK and KEEPS its vnode reference, as 4.3BSD-Reno's
     * does (`unp->unp_vnode = vp'), and UNP_OP_UNBIND drops it at close.  A bind
     * that released the vnode instead left it on the free list with the
     * descriptor slot still in `v_un', and getnewvnode zeroes that word on
     * reuse -- so the name stopped resolving to its socket once VNODE_POOL
     * entries had been handed out past it, with the socket still open and still
     * reading.  That is the shape that would take /dev/log down a minute into
     * every boot, and there is NO direct assertion for it in this file.
     *
     * Three ways of writing one were tried and none is affordable:
     *   - creat/close/unlink per round touches ONE vnode, not N: vfree puts a
     *     closed vnode on the TAIL and getnewvnode takes from the HEAD, but an
     *     unlinked file's vnode is reclaimed and vgone returns it to the HEAD,
     *     so the next creat takes the same one back.  Eighty rounds of it
     *     passed with the fix reverted -- an inert test.
     *   - creat/close WITHOUT the unlink does walk the pool, at an inode
     *     allocation and a directory write per round, and ran past the frame cap.
     *   - a stat(2) of every /bin entry is cheap enough and walks 75 distinct
     *     vnodes, but hangs this probe; the readdir loop wants diagnosing on its
     *     own rather than inside this campaign.
     * `freevnodes' would make it an O(1) assertion and is not reachable from
     * userland: there is no sysctl arm for it.
     *
     * WHAT DOES HOLD THE LINE is the reference-count invariant, and it is
     * load-bearing rather than incidental: with UNP_OP_UNBIND's vrele in place, a
     * bind that stops holding its reference makes the close a DOUBLE release, and
     * the kernel's own check fires -- `vrele: zero usecount', measured, a panic
     * this probe reaches through the stale case below.  So the retention cannot
     * be removed by itself.  It CAN be removed together with the unbind's vrele,
     * and that pairing is the gap.
     */

    /* A NAME MUST STOP NAMING A SOCKET THAT HAS CLOSED.  close(2) does not
     * unlink the node -- which is why syslogd unlinks before it binds -- so the
     * VSOCK node outlives its socket, and its `v_un' has to be cleared or it
     * keeps pointing at a descriptor slot the kernel is free to hand to somebody
     * else.  4.3BSD-Reno's unp_detach clears it (`unp->unp_vnode->v_socket = 0'),
     * and UNP_OP_UNBIND is where that happens here.
     *
     * ECONNREFUSED IS THE WHOLE ASSERTION, and the failure it discriminates is
     * not an error but a SUCCESS: with the node still carrying a stale slot,
     * connect() returns 0 and the datagrams go into whatever socket now holds
     * it. */
    {
        static char sa4[UNP_SA_SIZE];
        int         a2, b2;

        a2 = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (a2 < 0) {
            printf("unixprobe: FAIL stale-socket errno=%d\n", errno);
            return (1);
        }
        (void)unlink(SOCKNAME);
        unp_mkaddr(sa4, SOCKNAME);
        if (bind(a2, (struct sockaddr *)sa4, UNP_SA_SIZE) < 0) {
            printf("unixprobe: FAIL stale-bind errno=%d\n", errno);
            return (1);
        }
        (void)close(a2);                /* the node stays; the socket does not */

        b2 = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (b2 < 0) {
            printf("unixprobe: FAIL stale-cli errno=%d\n", errno);
            return (1);
        }
        if (connect(b2, (struct sockaddr *)sa4, UNP_SA_SIZE) == 0) {
            printf("unixprobe: FAIL stale-connected to a closed socket\n");
            return (1);
        }
        if (errno != ECONNREFUSED) {
            printf("unixprobe: FAIL stale-errno %d want %d\n",
                   errno, ECONNREFUSED);
            return (1);
        }
        (void)close(b2);
        (void)unlink(SOCKNAME);
    }

    /* A NAME MADE IN /dev AFTER ALL OF THE ABOVE MUST NOT PANIC THE MACHINE.
     *
     * `v_un' is a UNION word: the mounted-on mount for a covered directory, the
     * specinfo for a device, and the socket's descriptor slot here.  vgone
     * clears it only in its VBLK/VCHR arm, so a vnode that had been a VSOCK and
     * still carried a small integer there was handed to getnewvnode, recycled
     * for a device node, and had that integer walked as a `struct specinfo *':
     * `vgone: missing bdev', PANIC, on the FIRST creat in /dev after this
     * probe's AF_UNIX body.  Measured on a tree with no syslog and no libc
     * change, so it was the socket slot and nothing else.
     *
     * Clearing `v_un' at unbind removes the stale integer, and the invariant
     * that makes it complete is that a bound socket HOLDS its vnode: the word is
     * non-zero only while a reference is held, so a vnode carrying it can never
     * reach vgone at all.  /dev is the directory that matters because it is the
     * only one whose creates take a device-vnode path.
     *
     * FOUR ROUNDS, not one: the first proves the panic is gone and the rest
     * prove the recycle is repeatable rather than having moved by one slot. */
    {
        int t, k;

        for (k = 0; k < 4; k++) {
            t = creat("/dev/vgz", 0666);
            if (t < 0) {
                printf("unixprobe: FAIL vgone-creat k=%d errno=%d\n", k, errno);
                return (1);
            }
            (void)close(t);
            if (unlink("/dev/vgz") < 0) {
                printf("unixprobe: FAIL vgone-unlink k=%d errno=%d\n", k, errno);
                return (1);
            }
        }
    }

    /* THE BUFFERS ARE STACK LOCALS, and that is the assertion.  fcc puts
     * locals on the bank-0 hardware stack and a program's data lives in its
     * own bank, so a socket call that carries a buffer's 16-bit offset without
     * its bank reads the right offset in the wrong bank: the sent bytes are
     * whatever the data bank holds there, and the received ones land in it.
     * The expected bytes come from a literal copied into a stack buffer, so
     * nothing here happens to sit in the data bank. */
    {
        static char sa6[UNP_SA_SIZE];
        char        sbuf[16];
        char        rbuf[16];
        char        froms[20];
        int         slen;
        int         s0, s1;

        s1 = socket(AF_UNIX, SOCK_DGRAM, 0);
        s0 = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (s0 < 0 || s1 < 0) {
            printf("unixprobe: FAIL sb-socket errno=%d\n", errno);
            return (1);
        }
        (void)unlink(SOCKNAME);
        unp_mkaddr(sa6, SOCKNAME);
        if (bind(s1, (struct sockaddr *)sa6, UNP_SA_SIZE) < 0 ||
            connect(s0, (struct sockaddr *)sa6, UNP_SA_SIZE) < 0) {
            printf("unixprobe: FAIL sb-pair errno=%d\n", errno);
            return (1);
        }
        strcpy(sbuf, "stack-bank");
        if (send(s0, sbuf, 10, 0) != 10) {
            printf("unixprobe: FAIL sb-send errno=%d\n", errno);
            return (1);
        }
        memset(rbuf, 'x', sizeof rbuf);
        n = recv(s1, rbuf, sizeof rbuf, 0);
        if (n != 10 || memcmp(rbuf, "stack-bank", 10) != 0) {
            printf("unixprobe: FAIL sb-recv n=%d first=%d\n", n, rbuf[0]);
            return (1);
        }
        if (send(s0, sbuf, 10, 0) != 10) {
            printf("unixprobe: FAIL sb-send2 errno=%d\n", errno);
            return (1);
        }
        memset(rbuf, 'x', sizeof rbuf);
        memset(froms, 'x', sizeof froms);
        slen = sizeof froms;
        n = recvfrom(s1, rbuf, sizeof rbuf, 0, (struct sockaddr *)froms, &slen);
        if (n != 10 || memcmp(rbuf, "stack-bank", 10) != 0) {
            printf("unixprobe: FAIL sb-recvfrom n=%d first=%d\n", n, rbuf[0]);
            return (1);
        }
        if (froms[0] != AF_UNIX || slen != 16 || froms[16] != 'x') {
            printf("unixprobe: FAIL sb-from fam=%d slen=%d\n", froms[0], slen);
            return (1);
        }
        (void)close(s0);
        (void)close(s1);
    }

    /* recvfrom(2) ON AN AF_UNIX SOCKET, which is syslogd's receive call
     * (syslogd.c:322).  The datagram arrives whole, and `from' is what 2.11BSD
     * attaches to a sender that never bound: sun_noname, `{ AF_UNIX }', a
     * 16-byte struct sockaddr (uipc_usrreq.c:30, :172).  recvit copies
     * min(*fromlen, 16) of it and writes the count back (netcopyout,
     * sys_net.c:221-223), so a 110-byte sockaddr_un gets 16 bytes and the byte
     * past them is untouched, and a fromlen of 4 gets exactly 4.
     *
     * The buffers are static here so this arm measures recvfrom alone; the
     * stack-bank arm above is the one that moves them. */
    {
        static char sa5[UNP_SA_SIZE];
        static char fromu[UNP_SA_SIZE];
        static int  flen;
        int         s0, s1, k;

        s1 = socket(AF_UNIX, SOCK_DGRAM, 0);
        s0 = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (s0 < 0 || s1 < 0) {
            printf("unixprobe: FAIL rf-socket errno=%d\n", errno);
            return (1);
        }
        (void)unlink(SOCKNAME);
        unp_mkaddr(sa5, SOCKNAME);
        if (bind(s1, (struct sockaddr *)sa5, UNP_SA_SIZE) < 0 ||
            connect(s0, (struct sockaddr *)sa5, UNP_SA_SIZE) < 0) {
            printf("unixprobe: FAIL rf-pair errno=%d\n", errno);
            return (1);
        }
        for (k = 0; k < 2; k++) {
            strcpy(txbuf, "recvfrom");
            if (send(s0, txbuf, 8, 0) != 8) {
                printf("unixprobe: FAIL rf-send errno=%d\n", errno);
                return (1);
            }
            memset(rxbuf, 'x', sizeof rxbuf);
            memset(fromu, 'x', sizeof fromu);
            flen = k ? 4 : UNP_SA_SIZE;
            n = recvfrom(s1, rxbuf, sizeof rxbuf, 0,
                         (struct sockaddr *)fromu, &flen);
            if (n != 8 || memcmp(rxbuf, "recvfrom", 8) != 0) {
                printf("unixprobe: FAIL rf-data k=%d n=%d errno=%d\n",
                       k, n, errno);
                return (1);
            }
            if (fromu[0] != AF_UNIX || fromu[1] != 0 || fromu[2] != 0) {
                printf("unixprobe: FAIL rf-from k=%d %d %d %d\n",
                       k, fromu[0], fromu[1], fromu[2]);
                return (1);
            }
            if (flen != (k ? 4 : 16) || fromu[flen] != 'x') {
                printf("unixprobe: FAIL rf-fromlen k=%d flen=%d past=%d\n",
                       k, flen, fromu[flen]);
                return (1);
            }
        }
        /* sendto(2) NAMING A PATH IS REFUSED, which unix(4)'s BUGS states.
         * Upstream's PRU_SEND connects an unconnected datagram socket for the
         * one call and answers EISCONN on a connected one (2.11BSD
         * uipc_usrreq.c, `if (nam) { if (unp->unp_conn) error = EISCONN; ...
         * unp_connect(so, nam)'); here the address is not honoured at all.
         * This pins the answer the page gives. */
        if (sendto(s0, txbuf, 1, 0, (struct sockaddr *)sa5, UNP_SA_SIZE) >= 0) {
            printf("unixprobe: FAIL sendto-accepted\n");
            return (1);
        }
        if (errno != EINVAL) {
            printf("unixprobe: FAIL sendto-errno %d\n", errno);
            return (1);
        }

        /* ONE writev(2) IS ONE DATAGRAM.  2.11BSD's writev hands the whole
         * vector to sosend as one uio (sys_generic.c rwuio), so 1+4+9 bytes
         * in three entries arrive as one 14-byte record; a writev that looped
         * write(2) would send three.  readv(2) scatters that one record over
         * two entries, and the kernel works on its own copy of each vector:
         * the caller's iov_len is what the caller wrote. */
        {
            static struct iovec wv[UIO_PAST_MAX];
            static struct iovec rv[2];
            static char         ra[5];
            int                 p[2];

            for (k = 0; k < 3; k++) {
                wv[k].iov_base = msg[k];
                wv[k].iov_len = strlen(msg[k]);
            }
            if ((n = writev(s0, wv, 3)) != 14) {
                printf("unixprobe: FAIL writev n=%d errno=%d\n", n, errno);
                return (1);
            }
            if (wv[0].iov_len != 1 || wv[2].iov_len != 9) {
                printf("unixprobe: FAIL writev-iov %d %d\n",
                       wv[0].iov_len, wv[2].iov_len);
                return (1);
            }
            memset(rxbuf, 'x', sizeof rxbuf);
            rv[0].iov_base = ra;
            rv[0].iov_len = sizeof ra;
            rv[1].iov_base = rxbuf;
            rv[1].iov_len = sizeof rxbuf;
            n = readv(s1, rv, 2);
            if (n != 14 || memcmp(ra, "abbbb", 5) != 0 ||
                memcmp(rxbuf, "ccccccccc", 9) != 0) {
                printf("unixprobe: FAIL readv n=%d errno=%d\n", n, errno);
                return (1);
            }
            for (k = 0; k < UIO_PAST_MAX; k++) {
                wv[k].iov_base = msg[0];
                wv[k].iov_len = 1;
            }
            if (writev(s0, wv, UIO_PAST_MAX) >= 0 || errno != EINVAL) {
                printf("unixprobe: FAIL writev-17 errno=%d\n", errno);
                return (1);
            }
            for (k = 0; k < 3; k++) {
                wv[k].iov_base = msg[k];
                wv[k].iov_len = strlen(msg[k]);
            }
            memset(rxbuf, 'x', sizeof rxbuf);
            rv[1].iov_len = 9;
            if (pipe(p) < 0 || writev(p[1], wv, 3) != 14 ||
                (n = readv(p[0], rv, 2)) != 14 ||
                memcmp(ra, "abbbb", 5) != 0 ||
                memcmp(rxbuf, "ccccccccc", 9) != 0) {
                printf("unixprobe: FAIL pipe-vec n=%d errno=%d\n", n, errno);
                return (1);
            }
            (void)close(p[0]);
            (void)close(p[1]);
        }
        (void)close(s0);
        (void)close(s1);
    }

    (void)unlink(SOCKNAME);
    (void)unlink(REGNAME);

    printf("unixprobe: PASS named + boundaries + wrap + oversize + zero + nonblock + trunc + noleak + stale + vgone + recvfrom + stackbank + udpidle + vector\n");
    return (0);
}
