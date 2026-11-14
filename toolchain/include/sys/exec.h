/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/exec.h
 *   2.11BSD's a.out header, verbatim.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* FGX's executables are not a.out (<a.out.h> describes them).  This is the
 * header of a 2.11BSD name list, such as /netnix: nlist(3) reads it. */
#ifndef _EXEC_
#define _EXEC_
/*
 * Header prepended to each a.out file.
 */
struct	exec {
	int	a_magic;	/* magic number */
unsigned int	a_text;		/* size of text segment */
unsigned int	a_data;		/* size of initialized data */
unsigned int	a_bss;		/* size of uninitialized data */
unsigned int	a_syms;		/* size of symbol table */
unsigned int	a_entry; 	/* entry point */
unsigned int	a_unused;	/* not used */
unsigned int	a_flag; 	/* relocation info stripped */
};

#define	NOVL	15		/* number of overlays */
struct	ovlhdr {
	int	max_ovl;	/* maximum overlay size */
unsigned int	ov_siz[NOVL];	/* size of i'th overlay */
};

/*
 * eXtended header definition for use with the new macros in a.out.h
*/
struct	xexec {
	struct	exec	e;
	struct	ovlhdr	o;
	};

#define	A_MAGIC1	0407	/* normal */
#define	A_MAGIC2	0410	/* read-only text */
#define	A_MAGIC3	0411	/* separated I&D */
#define	A_MAGIC4	0405	/* overlay */
#define	A_MAGIC5	0430	/* auto-overlay (nonseparate) */
#define	A_MAGIC6	0431	/* auto-overlay (separate) */

#endif
