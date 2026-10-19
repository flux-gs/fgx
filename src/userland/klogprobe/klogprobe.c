/* klogprobe - /dev/klog, the cursored read-only view of the kernel log ring.
 *
 * FGX-Provenance: none
 *
 * Increment 4 of the syslog campaign.  klog.mod ports 2.11BSD's subr_log.c
 * logopen/logclose/logread/logselect/logioctl onto FGX's ring, which unlike
 * upstream's msgbuf carries no read pointer -- so the cursor is the module's and
 * this probe is what proves the cursor behaves.
 *
 * WHAT IT ASSERTS, and why none of it can pass vacuously:
 *
 *   - THE CURSOR SURVIVES A CLOSE (apple/fgx#484).  Upstream's logopen never
 *     touches msg_bufr, so a reader that reopens resumes where the last one
 *     stopped.  After a drain, a close and a reopen there must be NOTHING to
 *     read; a cursor that reseeded at open would hand over the boot log again.
 *   - FRESH BYTES ARE DELIVERED ONCE, IN ORDER.  syslogd has already drained the
 *     boot log, so the probe makes its own: a second `modload pty' is refused and
 *     the refusal is a kernel log line.  What /dev/klog then hands over must
 *     contain it and must appear CONTIGUOUSLY in dmesg(2), which copies the same
 *     ring out without consuming it -- a cursor that skipped or repeated bytes
 *     breaks the match.  dmesg is the independent reader here.
 *   - WOULD-BLOCK is proven with select(2), bounded, and as a PAIR: ready while
 *     the fresh line is unread, then not ready once drained and only after
 *     spending the whole timeout.  Either half alone is a constant.  That the
 *     device is not answering EOF instead comes from the non-blocking read,
 *     which says EAGAIN and not 0.
 */
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <sys/time.h>
#include <fgx.h>

/* STATIC, NEVER STACK.  A libc frame is invisible to the caller's stack
 * reservation (apple/fgx#367) and four kilobytes of ring on the stack is how su
 * got itself killed mid-syslog.  File scope also satisfies dmesg(2)'s
 * data-bank buffer contract. */
static char kbuf[4096];         /* what /dev/klog hands back */
static char dbuf[4096];         /* the same ring, through dmesg(2) */
static int  fails;

/* EVERY REPORT IS FLUSHED.  stdout to a tty is buffered here, so a probe that
 * hangs after printing loses everything it had already proven -- which is how
 * the first run of this came back with a completely blank screen and no clue
 * which assertion it had reached. */
static void ok(what, good)
    char *what;
    int good;
{
    if (good)
        printf("KP ok   %s\n", what);
    else {
        printf("KP FAIL %s\n", what);
        ++fails;
    }
    fflush((char *)0);
}

int system();

/* Drain fd without blocking into kbuf; the byte count. */
static int
drain(fd)
    int fd;
{
    int n, total;

    total = 0;
    for (;;) {
        n = read(fd, &kbuf[total], (int)(sizeof kbuf - total));
        if (n <= 0)
            break;
        total += n;
        if (total >= (int)sizeof kbuf)
            break;
    }
    return (total);
}

main(argc, argv)
    int argc;
    char **argv;
{
    int fd, fd2, n, total, nb, i, j;
    long t0, t1;
    long rf;
    struct timeval tv;
    static char mark[] = "pty: cannot place in the module bank";

    printf("KPSTART\n");
    fflush((char *)0);

    fd = open("/dev/klog", O_RDONLY);
    if (fd < 0) {
        printf("KP FAIL open errno=%d\n", errno);
        printf("KPDONE 1 failed\n");
        return (1);
    }
    ok("open", 1);

    /* FIONBIO is implemented precisely so this path exists: there is no generic
     * kernel-side FIONBIO for a chardev. */
    nb = 1;
    ok("FIONBIO accepted", ioctl(fd, FIONBIO, &nb) == 0);

    /* Whatever arrived after syslogd's last read -- possibly nothing. */
    total = drain(fd);
    printf("KP pending=%d\n", total);

    /* THE PERSISTENCE CHECK.  Drained, closed, reopened: nothing to read. */
    close(fd);
    fd = open("/dev/klog", O_RDONLY);
    ok("reopen after close", fd >= 0);
    if (fd < 0) {
        printf("KPDONE %d failed\n", fails);
        fflush((char *)0);
        return (1);
    }
    nb = 1;
    ioctl(fd, FIONBIO, &nb);
    n = read(fd, kbuf, (int)sizeof kbuf);
    printf("KP reopen read n=%d errno=%d\n", n, errno);
    ok("a reopen resumes where the last reader stopped", n < 0 && errno == EAGAIN);

    /* FRESH BYTES: the refused second load of a loaded module. */
    system("/sbin/modload pty >/dev/null 2>&1");

    rf = (1L << fd);
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    n = select(fd + 1, &rf, (void *)0, (void *)0, &tv);
    ok("select says READY with a line unread", n == 1 && (rf & (1L << fd)));

    total = drain(fd);
    printf("KP drained=%d lastErrno=%d\n", total, errno);
    ok("drained read ends EAGAIN", errno == EAGAIN);
    for (i = 0; i + (int)sizeof mark - 1 <= total; ++i)
        if (strncmp(&kbuf[i], mark, sizeof mark - 1) == 0)
            break;
    ok("the fresh kernel line was delivered",
       i + (int)sizeof mark - 1 <= total);

    n = dmesg(dbuf, (int)sizeof dbuf);
    printf("KP dmesg=%d\n", n);

    /* CONTIGUOUS IN dmesg.  The cursor's bytes are one unbroken run of the ring,
     * so they must match dmesg at some offset byte for byte. */
    for (i = 0; total > 0 && i + total <= n; ++i) {
        for (j = 0; j < total; ++j)
            if (kbuf[j] != dbuf[i + j])
                break;
        if (j == total)
            break;
    }
    ok("klog bytes are one run of dmesg", total > 0 && i + total <= n);

    /* READ-ONLY, and the refusal comes from ABOVE the driver.  The descriptor is
     * O_RDONLY, so the syscall layer answers EBADF before any chardev op runs --
     * which is correct, and is what BSD does with a read-only fd.  klog.mod's own
     * write op answers ENOTSUP and is the backstop for a writable descriptor;
     * upstream has no log write entry point at all, the kernel reaching its ring
     * through logwrt, which is not a driver op.  So the assertion is that the
     * write FAILS, and the errno is printed rather than pinned to one value. */
    n = write(fd, "x", 1);
    printf("KP write n=%d errno=%d\n", n, errno);
    ok("a write to the read-only device fails", n < 0);

    nb = 0;
    ok("FIONBIO cleared", ioctl(fd, FIONBIO, &nb) == 0);

    /* Drained: not ready, and it spends the whole timeout rather than answering
     * at once.  A read here would have waited the same way -- and it cannot be
     * answering EOF instead, because the non-blocking read above said EAGAIN and
     * not 0. */
    rf = (1L << fd);
    tv.tv_sec = 2;
    tv.tv_usec = 0;
    t0 = time((long *)0);
    n = select(fd + 1, &rf, (void *)0, (void *)0, &tv);
    t1 = time((long *)0);
    printf("KP sel-empty n=%d rf=%ld elapsed=%d\n", n, rf, (int)(t1 - t0));
    ok("a drained read WOULD BLOCK: select waits and reports not ready",
       n == 0 && !(rf & (1L << fd)) && (t1 - t0) >= 1);

    /* ONE READER, upstream's EBUSY in logopen: two would share one cursor and
     * each would see an arbitrary half of the log.
     *
     * AND THE REFUSAL MUST LEAVE NOTHING BEHIND.  A refused open that still
     * counted as an open would make the close below something other than the
     * last close, klog's close op would never run, and the device would answer
     * EBUSY for the rest of the boot (apple/fgx#462).  The reopen after it is
     * what can tell. */
    fd2 = open("/dev/klog", O_RDONLY);
    ok("second open refused EBUSY", fd2 < 0 && errno == EBUSY);
    if (fd2 >= 0)
        close(fd2);
    close(fd);
    fd = open("/dev/klog", O_RDONLY);
    ok("reopen after a refused open", fd >= 0);
    if (fd >= 0)
        close(fd);

    printf("KPDONE %d failed\n", fails);
    fflush((char *)0);
    return (fails ? 1 : 0);
}
