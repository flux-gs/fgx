/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * rtcread -- print the battery clock's frame as the kernel reads it at boot
 * (SYS_RTCREAD, Misc Tools ReadTimeHex): seconds, minutes, hours, the year
 * less 1900, and the day and month counted from zero.  tod_init takes a frame
 * outside 1970-2099 as "Invalid time in real time clock".
 *
 *     RTC sec=12 min=34 hour=10 year=126 day=20 mon=9
 */
#include <stdio.h>
#include <stdlib.h>

/* The kernel writes the frame through (caller bank, offset), so it lives in
 * the data bank, as clkrate's does. */
static unsigned char rtc[6];            /* sec min hour year day mon */

main()
{
    (void)__syscall(31, (unsigned)(unsigned long)&rtc[0], 0, 0);
    printf("RTC sec=%d min=%d hour=%d year=%d day=%d mon=%d\n",
           rtc[0], rtc[1], rtc[2], rtc[3], rtc[4], rtc[5]);
    exit(0);
}
