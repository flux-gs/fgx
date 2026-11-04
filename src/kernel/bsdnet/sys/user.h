/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/user.h
 *   Written for FGX after usr/sys/h/user.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* user.h -- the fields of 2.11BSD's u area the network code reads.
 *
 * ONE GLOBAL, so it is not per task.  Nothing behind a socket uses it until the
 * phase that gives a task a socket, which has to make it safe across a sleep. */
#ifndef _USER_H_
#define _USER_H_
#include "errno.h"
typedef struct { int val[8]; } label_t;
struct user {
	int	u_error;
	int	*u_ap;
	struct {
		int	r_val1;
		int	r_val2;
	} u_r;
	struct	file *u_ofile[NOFILE];
	label_t	u_qsave;
	u_short	u_uid;
	struct {
		long	ru_msgsnd;
		long	ru_msgrcv;
	} u_ru;
	struct	proc *u_procp;
};
extern struct user u;
#endif
