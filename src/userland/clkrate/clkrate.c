/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * clkrate -- measure the VBL period against the battery clock.
 *
 * The kernel's time of day advances by `tick' microseconds per VBL, so tick
 * has to be this machine's real frame period.  MAME's IIgs runs at exactly
 * 60 Hz; a real IIgs does not.  This waits for the battery clock's second to
 * change, counts VBLs across N more changes, and prints the period:
 *
 *     CR ticks=17981 secs=300 tick_us=16684
 *
 * THE BATTERY CLOCK IS READ DIRECTLY (SYS_RTCREAD), not through gettimeofday:
 * the kernel's clock is itself driven by the VBL, and measuring the VBL
 * against it would measure nothing.
 *
 * Each edge is found to within one VBL, so the count is good to +-2 in
 * secs*60: about 110 ppm over 300 s, 55 ppm over 600 s.
 */
#include <stdio.h>
#include <stdlib.h>

long ticks();

/* The kernel writes the frame through (caller bank, offset), so it lives in
 * the data bank; a stack local would name an offset in bank 0. */
static unsigned char rtc[6];            /* sec min hour year day mon */

static int
rtcsec()
{
    (void)__syscall(31, (unsigned)(unsigned long)&rtc[0], 0, 0);
    return rtc[0];
}

/* The tick count at the next change of the battery clock's second.  The clock
 * is polled once per VBL: each read is a ROM excursion with interrupts off, and
 * polling faster would only hold them off longer. */
static long
edge()
{
    int s;
    long t;

    s = rtcsec();
    for (;;) {
        t = ticks();
        while (ticks() == t)
            ;
        if (rtcsec() != s)
            return ticks();
    }
}

main(argc, argv)
int argc;
char **argv;
{
    int secs, i;
    long t0, n;

    secs = (argc > 1) ? atoi(argv[1]) : 300;
    if (secs < 10)
        secs = 10;
    if (secs > 2000)
        secs = 2000;                    /* secs * 1000000 must fit a long */
    t0 = edge();
    for (i = 0; i < secs; i++)
        n = edge();
    n -= t0;
    printf("CR ticks=%ld secs=%d tick_us=%ld\n",
           n, secs, (long)secs * 1000000L / n);
    exit(0);
}
