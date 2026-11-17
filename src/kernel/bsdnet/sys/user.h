/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/user.h
 *   Written for FGX after usr/sys/h/user.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* user.h -- the fields of 2.11BSD's u area the network code reads.
 *
 * ONE GLOBAL, filled for the calling process at each socket call
 * (machine/bn_sys.c).  sleep() (machine/net_kern.c) keeps the caller's copy across
 * the sleep, in a per-process slot, so another process's call in the meantime
 * does not reach it.
 * label_t is what the kernel's setjmp saves (machine/net_asm.s). */
#ifndef _USER_H_
#define _USER_H_
#include "errno.h"
typedef struct { int val[24]; } label_t;
struct user {
	int	u_error;
	int	*u_ap;
	struct {
		int	r_val1;
		int	r_val2;
	} u_r;
	label_t	u_qsave;
	u_short	u_uid;
	struct {
		long	ru_msgsnd;
		long	ru_msgrcv;
	} u_ru;
	struct	proc *u_procp;
	struct	file *u_ofile[NOFILE];	/* last: sleep() keeps what is above it */
};
extern struct user u;
#endif
