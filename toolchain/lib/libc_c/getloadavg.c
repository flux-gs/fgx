/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/getloadavg.c
 *   Original work: getloadavg.c 8.1.1 (2.11BSD GTE) 1/15/95,
 *	Copyright (c) 1989, 1993 The Regents of the University of California.
 */
/* getloadavg(3): the vm.loadavg sysctl, scaled by its fscale.  Upstream's
 * body, verbatim.  Its own member: it is double arithmetic, which only its
 * callers should link. */
int
getloadavg(loadavg, nelem)
	double loadavg[];
	register int nelem;
{
	struct loadavg loadinfo;
	register int i;
	int mib[2];
	size_t size;

	mib[0] = CTL_VM;
	mib[1] = VM_LOADAVG;
	size = sizeof(loadinfo);
	if (sysctl(mib, 2, &loadinfo, &size, NULL, 0) < 0)
		return (-1);

	nelem = MIN(nelem, sizeof(loadinfo.ldavg) / sizeof(short));
	for (i = 0; i < nelem; i++)
		loadavg[i] = (double) loadinfo.ldavg[i] / loadinfo.fscale;
	return (nelem);
}
