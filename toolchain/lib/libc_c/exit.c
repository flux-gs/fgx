/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/exit.c
 *   Original work: exit.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
exit(code)
	int code;
{

	_cleanup();
	_exit(code);
}
