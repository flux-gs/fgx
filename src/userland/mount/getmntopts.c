/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD mount(8)
 *   vendor/2.11BSD/usr/sbin/mount/getmntopts.c, VERBATIM.
 *   Copyright (c) 1980, 1989, 1993, 1994 The Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; the FGX header above is BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 */
/*-
 * Copyright (c) 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#if	!defined(lint) && defined(DOSCCS)
static char sccsid[] = "@(#)getmntopts.c	8.1.1 (2.11BSD) 1996/1/16";
#endif /* not lint */

#include <sys/param.h>
#include <sys/mount.h>

#include <errno.h>
#include <fstab.h>
#include <stdlib.h>
#include <string.h>

#include "mntopts.h"

void
getmntopts(options, m0, flagp)
	char *options;
	struct mntopt *m0;
	int *flagp;
{
	register struct mntopt *m;
	int negative;
	register char *opt;
	char *optbuf;

	/* Copy option string, since it is about to be torn asunder... */
	if ((optbuf = strdup(options)) == NULL)
		err(1, NULL);

	for (opt = optbuf; (opt = strtok(opt, ",")) != NULL; opt = NULL) {
		/* Check for "no" prefix. */
		if (opt[0] == 'n' && opt[1] == 'o') {
			negative = 1;
			opt += 2;
		} else
			negative = 0;

		/* Scan option table. */
		for (m = m0; m->m_option != NULL; ++m)
			if (strcasecmp(opt, m->m_option) == 0)
				break;

		/* Save flag, or fail if option is not recognised. */
		if (m->m_option) {
			if (negative == m->m_inverse)
				*flagp |= m->m_flag;
			else
				*flagp &= ~m->m_flag;
		} else
			errx(1, "-o %s: option not supported", opt);
	}

	free(optbuf);
}
