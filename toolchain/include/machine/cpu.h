/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX libc -- machine/cpu.h: the CTL_MACHDEP sysctl identifiers, where both
 * BSDs keep them (2.11BSD pdp/cpu.h, FreeBSD 2.2.8 i386/include/cpu.h) and
 * where their programs include them from beside <sys/sysctl.h>.
 *
 * The ids are FreeBSD 2.2.8's (i386/include/cpu.h:127-131), whose adjkerntz,
 * disable_rtc_set and wall_cmos_clock the kernel clock serves
 * (src/kernel/tty/kern_time.c, which mirrors them).  2.11BSD's own machdep
 * ids name PDP-11 devices (CPU_TMSCP 2, CPU_MSCP 3) and are not served.
 * CPU_TICK is FGX's own, at the id FreeBSD's CPU_MAXID leaves free:
 * microseconds per VBL. */
#ifndef _MACHINE_CPU_H
#define _MACHINE_CPU_H

#define CPU_ADJKERNTZ    2      /* long: timezone offset (seconds) */
#define CPU_DISRTCSET    3      /* int: disable resettodr() call */
#define CPU_WALLCLOCK    5      /* int: indicates wall CMOS clock */
#define CPU_TICK         6      /* int: microseconds per VBL (FGX) */

#endif /* _MACHINE_CPU_H */
