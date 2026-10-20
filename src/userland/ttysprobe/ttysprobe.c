/* ttysprobe - closed-loop check for the libc ttyent + crypt additions.
 *
 * FGX-Provenance: none
 *
 * Prints TP<n> OK / TP<n> FAIL per assertion and a final verdict line.
 * Reads the SHIPPED /etc/ttys, so it fails if the file or the parser drifts.
 */
#include <stdio.h>
#include <ttyent.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sgtty.h>              /* TIOCL* local-mode family (TP19/TP20) */

int fails;

static void
chk(n, cond)
    int n;
    int cond;
{
    if (cond)
        printf("TP%d OK\n", n);
    else {
        printf("TP%d FAIL\n", n);
        fails++;
    }
}

int
main()
{
    struct ttyent *t;
    int n;
    int fd;
    char h1[32];
    char h2[32];

    /* 1: the file opens and yields the first line. */
    chk(1, setttyent() != 0);
    t = getttyent();
    chk(2, t != (struct ttyent *)0 && strcmp(t->ty_name, "console") == 0);

    /* 3: ty_getty is the whole command path, not a truncated token. */
    chk(3, t != (struct ttyent *)0 && strcmp(t->ty_getty, "/bin/sh") == 0);

    /* 4: exactly five lines, so comments and blanks are skipped.  The console
     * plus two virtual consoles plus the two pty slaves -- ttyp0/ttyp1 were
     * added so login(1) has a real ty_type and a real secure flag to read over
     * a pty (an absent line silently gets the vt100 fallback and no root
     * gate). */
    n = 1;
    while (getttyent() != (struct ttyent *)0)
        n++;
    chk(4, n == 6);
    endttyent();

    /* 5: getttynam finds a middle line and reads its type. */
    t = getttynam("ttyv1");
    chk(5, t != (struct ttyent *)0 && strcmp(t->ty_type, "vt100") == 0);

    /* 6: a name that is not there returns NULL rather than the last line. */
    chk(6, getttynam("ttyzz") == (struct ttyent *)0);

    /* 7: status parses to a flag, not a string compare at every use site --
     * and the two directions are asserted on the shipped file, because init(8)
     * starts a line on TTY_ON alone.  "console" is on.
     *
     * The off-direction used to be "ttyv2", off until the ttyv* chardevs
     * existed.  They exist now and both virtual consoles ship ON, so that line
     * can no longer carry this assertion.  "ttyp0" replaces it and is a better
     * anchor besides: a pty line is off for a REASON THAT DOES NOT EXPIRE --
     * a pty session belongs to whoever opened the master, so init must never
     * start a getty on one -- whereas ttyv2 was only waiting on a feature. */
    t = getttynam("console");
    chk(7, t != (struct ttyent *)0 && (t->ty_status & TTY_ON) != 0);
    t = getttynam("ttyp0");
    chk(15, t != (struct ttyent *)0 && (t->ty_status & TTY_ON) == 0);

    /* 8: a second setttyent() with NO endttyent() between must rewind the
     * already-open stream back to the top, not resume mid-file.  This is
     * the path init(8) hits on SIGHUP: it re-reads /etc/ttys on a stream
     * it never closed. */
    setttyent();
    getttyent();                  /* consume console; cursor now on ttyv1 */
    setttyent();                  /* reopen with no endttyent() first */
    t = getttyent();
    chk(8, t != (struct ttyent *)0 && strcmp(t->ty_name, "console") == 0);
    endttyent();

    /* 9: crypt is deterministic and carries its tag. */
    strcpy(h1, crypt("swordfish", "ab"));
    chk(9, strncmp(h1, "$f$ab$", 6) == 0);
    chk(10, strcmp(h1, crypt("swordfish", "ab")) == 0);

    /* 11: a different password under the same salt differs. */
    chk(11, strcmp(h1, crypt("swordfisi", "ab")) != 0);

    /* 12: the same password under a different salt gives a different WHOLE
     * STRING -- but buf[3]/buf[4] echo the salt argument straight into the
     * tag independently of the digest, so this only proves the tag differs.
     * It catches salt being dropped from the whole interface, but it cannot
     * catch salt being dropped from just the hash; see TP13 for that. */
    chk(12, strcmp(h1, crypt("swordfish", "cd")) != 0);

    /* 13: same password, two salts: the DIGEST (the 8 hex chars at offset 6)
     * must differ, not merely the echoed tag bytes.  Comparing whole strings
     * (TP12) would pass even if crypt ignored the salt entirely when folding
     * the hash, because buf[3]/buf[4] copy the salt argument through
     * independently.  This is the assertion that actually catches a dropped
     * salt-folding loop. */
    strcpy(h1, crypt("swordfish", "ab"));
    strcpy(h2, crypt("swordfish", "cd"));
    chk(13, strcmp(&h1[6], &h2[6]) != 0);

    /* 14: the returned buffer is static; a second call invalidates it,
     * which is the BSD contract callers strcpy out of. */
    chk(14, crypt("x", "yz") == crypt("q", "yz"));

    /* 16/17 (slice D, D0): the virtual-console lines are REGISTERED chardevs.
     * /etc/ttys has named ttyv1/ttyv2 since slice C, but until now no device
     * backed them -- TP15 above still asserts ttyv2 is `off` for that reason.
     * These two say the devices now exist and that exactly three of them do:
     * ttyv3 is the card's console (VC_CARD, include/kernel.s) since 2026-09-18.
     *
     * Openable is ALL this asserts.  Read is EOF and write returns ENXIO until
     * D1.5 builds the real arms (see src/kernel/ttyv.s), so do not add an I/O
     * assertion here expecting it to pass.
     *
     * Discriminates: drop a _Chardev_RegisterInternal call in
     * _Chardev_InitBuiltins and TP16 goes red; register a fourth and TP17 does. */
    fd = open("/dev/ttyv3", O_RDWR);
    chk(16, fd >= 0);
    if (fd >= 0)
        close(fd);

    fd = open("/dev/ttyv4", O_RDWR);
    chk(17, fd < 0);
    if (fd >= 0)
        close(fd);

    /* 18 (slice D, D1.5): ttyname() answers on a VC line.
     *
     * DEFERRED HERE FROM D0 ON PURPOSE.  ttyname(3) is FIODGNAME, and the
     * ioctl chardev arm used to map only the pty slaves, so every other
     * chardev fell through to _Chardev_Ioctl and got ENOTTY -- the assertion
     * could not have passed when the lines were first registered.  It passes
     * now because syscall.s routes ttyv fds into the shared @si_ttyX block.
     *
     * This one is security-relevant, not cosmetic: login(1) reads TERM and the
     * TTY_SECURE root gate by whatever ttyname() hands back, so a name/offset
     * mismatch silently gives a VC session the vt100 fallback and no root gate.
     *
     * Discriminates: shorten _ttyNames by one record and it reads a wrong name;
     * drop the ttyv case from the ioctl arm and it fails outright. */
    fd = open("/dev/ttyv1", O_RDWR);
    chk(18, fd >= 0 && ttyname(fd) != (char *)0
            && strcmp(ttyname(fd), "/dev/ttyv1") == 0);

    /* 19: the sgtty LOCAL-MODE family answers on a VC line too.
     *
     * The kernel has had real per-tty state for these since 2026-07-27
     * (TTY_Ltchars + TTY_Lmode), but the ioctl chardev arm forwarded only ten
     * commands, so on a ttyv line -- or a pty slave -- they fell through to
     * _Chardev_Ioctl and came back ENOTTY, while the identical call on the
     * console succeeded.  A program's terminal setup would then degrade purely
     * on the basis of which line it happened to be running on.
     *
     * TIOCLGET is the read half and is enough to prove the routing: it either
     * reaches @si_ttyX or it does not.  The round-trip is asserted too -- set a
     * bit with TIOCLBIS, read it back, then clear it with TIOCLBIC -- because a
     * forwarding arm that reached the wrong TTY OFFSET would still return
     * success while reading somebody else's state.
     *
     * Not exercised by anything shipped today (elvis uses only TIOCGETP/SETP),
     * but tcsh uses this family, and tcsh on a virtual console is next. */
    if (fd >= 0) {
        int lm, lm2;
        lm = 0;
        chk(19, ioctl(fd, TIOCLGET, (char *)&lm) == 0);
        lm2 = LCRTBS;
        chk(20, ioctl(fd, TIOCLBIS, (char *)&lm2) == 0
                && ioctl(fd, TIOCLGET, (char *)&lm2) == 0
                && (lm2 & LCRTBS) != 0);
        lm2 = LCRTBS;
        ioctl(fd, TIOCLBIC, (char *)&lm2);
        close(fd);
    } else {
        chk(19, 0);
        chk(20, 0);
    }

    printf(fails == 0 ? "TTYSPROBE PASS\n" : "TTYSPROBE FAIL\n");
    return fails != 0;
}
