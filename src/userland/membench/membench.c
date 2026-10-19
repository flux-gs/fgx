/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * membench - libc bulk-primitive cycle benchmark + correctness check.
 *
 * TIMING: brackets a representative memset+memcpy workload (elvis-startup-
 * shaped KB fills/copies) with the fbench cycle markers ($025000 START /
 * $025002 DONE, DBR-independent STAL); the mame_test cycle_markers facility
 * taps those writes and reports the emu.time() delta.  Same-machine
 * baseline-vs-current delta is authoritative.
 *
 * CORRECTNESS: after timing, exercises memset+memcpy across EVEN, ODD, and
 * tiny sizes (the 16-bit word loop + odd-tail path) and writes RESULT=... .
 */
#include <stdio.h>
#include <string.h>
int write(int fd, char *buf, int n);

#define SZ    2048      /* per-op size for the timed loop (even: word path) */
#define ITERS 64        /* -> 128KB memset + 128KB memcpy */

static unsigned char src[SZ + 4];
static unsigned char dst[SZ + 4];

/* verify memset then memcpy at a given length; returns 1 ok, 0 bad. */
static int check(int len)
{
    int i;
    /* poison, then memset a known value */
    for (i = 0; i < len + 2; i++) dst[i] = 0x5A;
    memset(dst, 0xC3, len);
    for (i = 0; i < len; i++) if (dst[i] != 0xC3) return 0;   /* fill wrong  */
    if (len < (SZ + 2) && dst[len] != 0x5A) return 0;          /* overrun!    */
    /* seed src, memcpy, compare */
    for (i = 0; i < len; i++) src[i] = (unsigned char)(i * 7 + 3);
    for (i = 0; i < len + 2; i++) dst[i] = 0x5A;
    memcpy(dst, src, len);
    if (memcmp(dst, src, len) != 0) return 0;                  /* copy wrong  */
    if (len < (SZ + 2) && dst[len] != 0x5A) return 0;          /* overrun!    */
    return 1;
}

int main(void)
{
    int i;

    /* seed source for the timed copy */
    for (i = 0; i < SZ; i++) src[i] = (unsigned char)(i * 7 + 3);

    /* --- MARKER: start --- */
    __asm("PHP", "REP #$30", "LDA #$A1A1", "STAL $025000", "PLP");
    for (i = 0; i < ITERS; i++) {
        memset(dst, 0, SZ);
        memcpy(dst, src, SZ);
    }
    /* --- MARKER: done --- */
    __asm("PHP", "REP #$30", "LDA #$A2A2", "STAL $025002", "PLP");

    /* correctness across even/odd/tiny lengths (exercises word loop + tail) */
    if (check(2048) && check(2047) && check(256) && check(255) && check(47) &&
        check(33) && check(32) && check(31) && check(17) && check(16) &&
        check(3) && check(2) && check(1) && check(0))
        write(1, "RESULT=MEMBENCH_OK\n", 19);
    else
        write(1, "RESULT=MEMBENCH_BAD\n", 20);
    return 0;
}
