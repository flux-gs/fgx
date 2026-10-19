/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* clkprobe -- sysctl kern.clockrate (2.11BSD kern_sysctl.c sysctl_clockrate):
 * hz is the clock's rate in whole hertz, tick its microseconds per interrupt,
 * stathz = hz and profhz = 0, read-only.  Prints CLK OK, or a FAIL line. */
#include <sys/types.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <errno.h>

extern int errno;

int
main()
{
	int mib[2], fails = 0;
	unsigned size;
	struct clockinfo ci;
	long want;

	mib[0] = CTL_KERN;
	mib[1] = KERN_CLOCKRATE;
	size = sizeof ci;
	if (sysctl(mib, 2, &ci, &size, (void *)0, 0) < 0) {
		printf("CLK FAIL read %d\n", errno);
		return 1;
	}
	printf("CLK hz %d tick %d stathz %d profhz %d size %u\n",
	    ci.hz, ci.tick, ci.stathz, ci.profhz, size);
	want = (1000000L + ci.tick / 2) / ci.tick;
	if (size != sizeof ci || ci.tick <= 0 || (long)ci.hz != want ||
	    ci.stathz != ci.hz || ci.profhz != 0) {
		printf("CLK FAIL value\n");
		fails++;
	}
	size = 2;
	if (sysctl(mib, 2, &ci, &size, (void *)0, 0) >= 0 || errno != ENOMEM) {
		printf("CLK FAIL short %d\n", errno);
		fails++;
	}
	if (sysctl(mib, 2, (void *)0, (unsigned *)0, &ci, sizeof ci) >= 0 ||
	    errno != EPERM) {
		printf("CLK FAIL write %d\n", errno);
		fails++;
	}
	if (!fails)
		printf("CLK OK\n");
	return fails;
}
