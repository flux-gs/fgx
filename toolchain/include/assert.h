/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* assert.h - program diagnostics.
 *
 * FGX-Provenance: 2.11BSD usr/include/assert.h
 *   Ported from assert.h 4.2 85/01/21 (2.11BSD), vendored at
 *   vendor/2.11BSD/usr/include/assert.h.
 *   Original work: the Regents of the University of California.
 *   The upstream file carries its sccsid and no dated notice.
 *   FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * Verbatim below this comment.  As upstream, assert() names fprintf, stderr
 * and exit without declaring them: the including file brings <stdio.h>.
 */
/*	assert.h	4.2	85/01/21	*/

# ifndef NDEBUG
# define _assert(ex)	{if (!(ex)){fprintf(stderr,"Assertion failed: file \"%s\", line %d\n", __FILE__, __LINE__);exit(1);}}
# define assert(ex)	_assert(ex)
# else
# define _assert(ex)
# define assert(ex)
# endif
