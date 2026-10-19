/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno vendor/4.3BSD-Reno/lib/libc/gen/difftime.c
 *   (5.2, 6/1/90).  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* difftime(3), which ctime(3)'s page documents with the rest of ctime.c.
 * VERBATIM but for the K&R header's time_t, which is FGX's long. */

double
difftime(time1, time0)
	time_t time1, time0;
{
	return(time1 - time0);
}
