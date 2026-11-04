/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/proc.h
 *   Written for FGX after usr/sys/h/proc.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* proc.h -- what the socket layer reads of a process: its wait channel, for
 * selwakeup's test of a selecting process. */
#ifndef _PROC_H_
#define _PROC_H_
struct proc {
	caddr_t	p_wchan;
};
#endif
