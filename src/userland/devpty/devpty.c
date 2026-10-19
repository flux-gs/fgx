/*
 * SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptsread/ptswrite.
 *
 * devpty - A PTY SLAVE READS AND WRITES THE SAME THROUGH TWO NAMES FOR IT.
 * apple/fgx#198's third defect, and the stateful-device case UFS 1.7d I3 step
 * 4 records as OWED rather than skipped.
 *
 * WHAT THE PAIR MEASURES IS AN ALIAS.  `/dev/ttyp0' and `/dev/./ttyp0' are
 * two DIFFERENT VNODES naming ONE device: `checkalias' links them on the rdev
 * hash and flags both VALIASED, and `spec_close' turns on the difference
 * between them -- "TWO COUNTS, AND THEY ANSWER DIFFERENT QUESTIONS ... vcount
 * asks how many VNODES name this device ... returning early here is what stops
 * one path's close tearing the driver down under another" (apple/fgx#76).  So
 * the claim is: both names reach the same line, in both directions, and
 * holding one open does not change what the other does.
 *
 * THE `.' IS HOW THE SECOND NAME IS GOT: it is the cheapest way to make the
 * resolver produce a second vnode for one device.
 *
 * EVERY MEASUREMENT HAS ITS CONTROL ON THE SAME PAIR, THE SAME LINE AND THE
 * SAME MODE, so the only difference between them is the NAME.  R1/R2 are the
 * plain name, R4/R5 the same two bytes through the alias.  Without the
 * controls a failure could be the pty, the raw mode or the master -- and
 * attribution is the reason this pair exists rather than R4/R5 alone.
 *
 * THE MODE IS SET ON THE FIRST FD AND READ BACK THROUGH THE SECOND.  The mode
 * belongs to the LINE and not to a descriptor, so either fd sets it for both,
 * which is precisely what an alias has to prove.
 *
 * R6 AND R9 ARE THE TWO ENDS OF THE IOCTL ROAD AND ARE NOT INTERCHANGEABLE.
 * TIOCGLTC and TIOCSLTC are answered by `_PtyS_Ioctl' out of its per-pair
 * store, so R6 exercises the DRIVER end; TIOCGETP is answered by the
 * discipline, so R9 exercises that end.  Collapsing them into one would lose
 * the driver half.
 *
 * UPSTREAM REACHES THE DISCIPLINE THROUGH THE SWITCH: `ptyioctl' answers the
 * commands that are its own and then falls through to `ttioctl'
 * unconditionally (vendor/2.11BSD/usr/sys/sys/tty_pty.c).  `_Io_CdThenTty' is
 * that sequence, and `@kc_cdioctl' calls it.
 *
 * R6 ASKS ITS QUESTION WHOLE: six bytes IN through TIOCSLTC and the same six
 * OUT through TIOCGLTC, both on the device node.  That exercises syscall,
 * seam, vnode, spec arm, registry and driver in both directions, and it is the
 * only place on target where the ioctl arm discriminates at all -- a refusal
 * fails, a pointer that did not travel fails, and a store that was never
 * written fails.  `ufs_devprobe' cannot: it says against itself that every
 * chardev it reaches answers ENOTTY to every command, which is exactly what a
 * stubbed `spec_ioctl' returns.
 *
 * R7/R8 ARE THE SELECT PAIR, AND THE ASSERTION IS A CHANGE AND NOT A VALUE:
 * not readable with the queue empty, readable after the master writes.  A
 * descriptor answered "ready for everything" locally -- right for a regular
 * file, wrong for a line that can block -- passes any single-state check, and
 * no constant answer passes both of these.
 *
 * RAW WITH NO ECHO because the measurement is one byte at a time: a cooked read
 * would not return until a newline, and an echo would leave bytes in `t_outq'
 * for the master reads to trip over.
 */
#include <stdio.h>
#include <errno.h>
#include <sys/time.h>

/* THE 16-BIT KERNEL FORM, not BSD's encoded _IOR/_IOW -- include/loader.s:685.
   The encoded values assemble fine and simply never match. */
#define TIOCGETP 0x7408
#define TIOCSETP 0x7409
#define TIOCGLTC 0x7474
#define TIOCSLTC 0x7475
#define RAW      0x0020
#define ECHO     0x0008
#define TIOCLBIS 0x747F
#define TIOCLBIC 0x747E
#define LPASS8   0x0800

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);
int select(int nfds, void *rf, void *wf, void *ef, void *tv);

static char master[]  = "/dev/ptyp0";
static char slaveL[]  = "/dev/ttyp0";
static char slaveD[]  = "/dev/./ttyp0";

static char bA[] = "A";
static char bB[] = "B";
static char bC[] = "C";
static char bD[] = "D";
static char b340[] = "\340";

static int m, sl, sd;
static char buf[8];

/* One byte in at `wfd', one byte out at `rfd'.  Returns the byte, or -1. */
static int
hop(wfd, src, rfd)
int wfd;
char *src;
int rfd;
{
    int n;

    if (write(wfd, src, 1) != 1)
        return (-1);
    n = read(rfd, buf, 4);
    if (n != 1)
        return (-1000 - n);
    return (buf[0]);
}

int
main()
{
    char sg[6];
    char ltc[6];
    char ltd[6];
    char sgd[6];
    long rf;
    struct timeval tv;
    int i, n;
    int lm;

    printf("DEVPTY START\n");

    m = open(master, 2);
    if (m < 0) { printf("DEVPTY FAIL master e=%d\n", errno); return 1; }
    sl = open(slaveL, 2);
    if (sl < 0) { printf("DEVPTY FAIL slaveL e=%d\n", errno); return 1; }

    if (ioctl(sl, TIOCGETP, sg) < 0) { printf("DEVPTY FAIL getp\n"); return 1; }
    sg[4] = (sg[4] | RAW) & ~ECHO;
    if (ioctl(sl, TIOCSETP, sg) < 0) { printf("DEVPTY FAIL setp\n"); return 1; }

    /* R1/R2 -- THE CONTROLS.  The plain name, both directions. */
    if (hop(m, bA, sl) != 'A') { printf("DEVPTY FAIL plain-in\n"); return 1; }
    printf("DEVPTY R1 plain-in\n");
    if (hop(sl, bB, m) != 'B') { printf("DEVPTY FAIL plain-out\n"); return 1; }
    printf("DEVPTY R2 plain-out\n");

    /* The SAME line, reached through a SECOND vnode for the same device. */
    sd = open(slaveD, 2);
    if (sd < 0) { printf("DEVPTY FAIL slaveD e=%d\n", errno); return 1; }
    printf("DEVPTY R3 open\n");

    /* R4 -- `ptsread'.  Before the wiring this read reached _PtyS_Read and
       returned EIO, so `n=-1' rather than a byte. */
    if (hop(m, bC, sd) != 'C') { printf("DEVPTY FAIL alias-in e=%d\n", errno); return 1; }
    printf("DEVPTY R4 alias-in\n");

    /* R5 -- `ptswrite'.  Before the wiring the per-byte loop reached
       _PtyS_Write, whose only driver was `tty_oproc' draining and which has
       failed loud since T4 increment 4.

       THIS LINE COST A STACK MOVE -- apple/fgx#246.  Written first, it RESET
       THE MACHINE: `ttwrite' kept upstream's `char obuf[OBUFSIZ]' on the
       kernel stack, and the vnode road is ~136 bytes deeper than the registry's was, so
       this same probe reached 516 of the 512-byte per-task stack with no
       guard to catch it.  The buffer is in the u-area now. */
    if (hop(sd, bD, m) != 'D') { printf("DEVPTY FAIL dev-out e=%d\n", errno); return 1; }
    printf("DEVPTY R5 alias-out\n");

    /* R6 -- ioctl THROUGH THE DEVICE NODE, both directions.  Six bytes in and
       the same six back out, all on `sd'.  The values are arbitrary and
       non-repeating so a partial copy, a stale buffer or a store that answered
       from the wrong pair cannot pass by coincidence.  See the header for why
       this one has no control on the other road. */
    for (i = 0; i < 6; i++)
        ltc[i] = (char)(0x11 * (i + 1));
    if (ioctl(sd, TIOCSLTC, ltc) < 0) {
        printf("DEVPTY FAIL dev-sltc e=%d\n", errno);
        return 1;
    }
    for (i = 0; i < 6; i++)
        ltd[i] = (char)0x5A;
    if (ioctl(sd, TIOCGLTC, ltd) < 0) {
        printf("DEVPTY FAIL dev-ioctl e=%d\n", errno);
        return 1;
    }
    for (i = 0; i < 6; i++) {
        if (ltd[i] != ltc[i]) {
            printf("DEVPTY FAIL dev-ioctl byte %d %d != %d\n",
                   i, ltd[i], ltc[i]);
            return 1;
        }
    }
    printf("DEVPTY R6 dev-ioctl\n");

    /* R7 -- NOT READABLE WITH NOTHING QUEUED.  Every hop above consumed what
       it wrote, so the line is drained here.  A zero timeout makes this a
       poll: select must answer, not wait.  This is the case the old local
       answer got wrong -- it said ready. */
    rf = (1L << sd);
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    n = select(sd + 1, &rf, (void *)0, (void *)0, &tv);
    if (n != 0 || (rf & (1L << sd))) {
        printf("DEVPTY FAIL dev-sel-empty n=%d rf=%ld\n", n, rf);
        return 1;
    }
    printf("DEVPTY R7 dev-sel-empty\n");

    /* R8 -- AND READABLE ONCE A BYTE IS WAITING.  The same fd, the same call,
       the only difference being a byte the master put on the line.  The pair
       is the measurement; either half alone is a constant. */
    if (write(m, bC, 1) != 1) { printf("DEVPTY FAIL dev-sel-write\n"); return 1; }
    rf = (1L << sd);
    tv.tv_sec = 0;
    tv.tv_usec = 0;
    n = select(sd + 1, &rf, (void *)0, (void *)0, &tv);
    if (n != 1 || !(rf & (1L << sd))) {
        printf("DEVPTY FAIL dev-sel-ready n=%d rf=%ld\n", n, rf);
        return 1;
    }
    printf("DEVPTY R8 dev-sel-ready\n");
    read(sd, buf, 4);           /* drain it, so close leaves nothing behind */

    /* R9 -- THE SGTTY FAMILY THROUGH THE DEVICE NODE (apple/fgx#267).
     *
     * This is the comparison R6 could not make.  TIOCGETP through `/dev' used
     * to answer ENOTTY (measured: e=25): FGX routes the sgtty family in the
     * syscall layer, at `@si_ttyX', BEFORE the chardev dispatch, so it never
     * reached a driver at all -- while upstream's `ptyioctl' answers its own
     * commands and then falls through to `ttioctl' unconditionally, which puts
     * the discipline THROUGH the switch where both roads meet it.
     *
     * The fall-through is `_Io_CdThenTty' now and both roads call it, so this
     * asks the SAME line the SAME question by the other road and requires the
     * SAME six bytes -- the shape every other measurement in this probe uses.
     * `sg' still holds what the TIOCSETP at the top of main set, RAW on and
     * ECHO off, so this is a comparison against a state THIS PROGRAM chose and
     * not against two defaults that would agree by construction. */
    for (i = 0; i < 6; i++)
        sgd[i] = (char)0x5A;
    if (ioctl(sd, TIOCGETP, sgd) < 0) {
        printf("DEVPTY FAIL dev-getp e=%d\n", errno);
        return 1;
    }
    for (i = 0; i < 6; i++) {
        if (sgd[i] != sg[i]) {
            printf("DEVPTY FAIL dev-getp byte %d %d != %d\n", i, sgd[i], sg[i]);
            return 1;
        }
    }
    printf("DEVPTY R9 dev-getp\n");

    /* R10 -- PASS8 REACHES THE OUTPUT SIDE (apple/fgx#279, 2.11BSD patch 484).
     * Upstream's Repeat-By: under `stty pass8', printf "\340" came out as a
     * backtick, because ttyoutput masked every character to seven bits.  RAW
     * goes off first, since RAW never reaches that mask.  With PASS8 clear the
     * strip is still upstream's and is required, so the case tells a kernel
     * that masks nothing from one that masks correctly. */
    sg[4] = sg[4] & ~RAW;
    if (ioctl(sl, TIOCSETP, sg) < 0) { printf("DEVPTY FAIL setp8\n"); return 1; }
    lm = LPASS8;
    ioctl(sl, TIOCLBIC, (char *)&lm);
    if ((i = hop(sl, b340, m)) != 0140) {
        printf("DEVPTY FAIL seven-bit %d\n", i);
        return 1;
    }
    ioctl(sl, TIOCLBIS, (char *)&lm);
    if ((i = hop(sl, b340, m)) != 0340) {
        printf("DEVPTY FAIL pass8 %d\n", i);
        return 1;
    }
    ioctl(sl, TIOCLBIC, (char *)&lm);
    printf("DEVPTY R10 pass8-out\n");

    close(sd);
    close(sl);
    close(m);
    printf("DEVPTY OK\n");
    return 0;
}
