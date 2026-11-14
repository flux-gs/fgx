/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/net/getnbyname.c
 *   Ported from usr/lib/libc/net/getnbyname.c, 2.11BSD (getnetbyname.c 5.3).  Original work:
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.
 */
/* getnetbyname, verbatim.  The #include lines are the aggregate's (libc_c.c). */
extern int _net_stayopen;

struct netent *
getnetbyname(name)
	register char *name;
{
	register struct netent *p;
	register char **cp;

	setnetent(_net_stayopen);
	while (p = getnetent()) {
		if (strcmp(p->n_name, name) == 0)
			break;
		for (cp = p->n_aliases; *cp != 0; cp++)
			if (strcmp(*cp, name) == 0)
				goto found;
	}
found:
	if (!_net_stayopen)
		endnetent();
	return (p);
}
