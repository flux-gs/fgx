/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/pdp/gen/nsym.c
 *   Ported from usr/lib/libc/pdp/gen/nsym.c, 2.11BSD (S.M. Schultz), and the
 *   macros from usr/include/a.out.h.  Original work:
 *   Copyright (c) 1991 The Regents of the University of California.
 *   All rights reserved.
 */
/* The offsets of an a.out's parts, verbatim; and a.out.h's macros for them.  The #include lines are the aggregate's (libc_c.c). */
/* 2.11BSD usr/include/a.out.h's macros for a name list's offsets.  They are
 * here, not in <a.out.h>, because FGX's <a.out.h> describes FGX's own
 * executables; a name list is 2.11BSD's a.out (<sys/exec.h>). */
#define	N_BADMAG(x) \
	(((x).a_magic)!=A_MAGIC1 && ((x).a_magic)!=A_MAGIC2 && \
	((x).a_magic)!=A_MAGIC3 && ((x).a_magic)!=A_MAGIC4 && \
	((x).a_magic)!=A_MAGIC5 && ((x).a_magic)!=A_MAGIC6)

#define	N_TXTOFF(x) \
	((x).a_magic==A_MAGIC5 || (x).a_magic==A_MAGIC6 ? \
	sizeof(struct ovlhdr) + sizeof(struct exec) : sizeof(struct exec))

off_t	n_stroff(), n_symoff(), n_datoff(), n_dreloc(), n_treloc();

#define	N_STROFF(e) (n_stroff(&e))
#define	N_SYMOFF(e) (n_symoff(&e))

/*
 *      Program Name:   nsym.c
 *      Author:  S.M. Schultz
 *
 *      -----------   Modification History   ------------
 *      Version Date            Reason For Modification
 *      1.0     31Oct93         1. Initial release into the public domain.
 *				   Calculating the offsets of the string
 *				   and symbol tables in an executable is
 *				   rather messy and verbose when dealing
 *				   with overlaid objects.  The macros (in
 *				   a.out.h) N_STROFF, N_SYMOFF, etc simply
 *				   call these routines.
 *      --------------------------------------------------              
*/


off_t
n_stroff(ep)
	register struct xexec *ep;
	{
	off_t	l;

	l = n_symoff(ep);
	l += ep->e.a_syms;
	return(l);
	}

off_t
n_datoff(ep)
	register struct xexec *ep;
	{
	off_t	l;

	l = n_treloc(ep);
	l -= ep->e.a_data;
	return(l);
	}

/*
 * Obviously if bit 0 of the flags word (a_flag) is not off then there's
 * no relocation information present and this routine shouldn't have been
 * called.
*/

off_t
n_dreloc(ep)
	register struct xexec *ep;
	{
	off_t	l;
	register u_short *ov = ep->o.ov_siz;
	register int	i;

	l = (off_t)sizeof (struct exec) + ep->e.a_text + ep->e.a_data;
	if	(ep->e.a_magic == A_MAGIC5 || ep->e.a_magic == A_MAGIC6)
		{
		for	(i = 0; i < NOVL; i++)
			l += *ov++;
		l += sizeof (struct ovlhdr);
		}
	l += ep->e.a_text;
	return(l);
	}

off_t
n_treloc(ep)
	register struct xexec *ep;
	{
	off_t	l;

	l = n_dreloc(ep);
	l -= ep->e.a_text;
	return(l);
	}

off_t
n_symoff(ep)
	register struct xexec *ep;
	{
	register int	i;
	register u_short *ov;
	off_t	sum, l;

	l = (off_t) N_TXTOFF(ep->e);
	sum = (off_t)ep->e.a_text + ep->e.a_data;
	if	(ep->e.a_magic == A_MAGIC5 || ep->e.a_magic == A_MAGIC6)
		{
		for	(ov = ep->o.ov_siz, i = 0; i < NOVL; i++)
			sum += *ov++;
		}
	l += sum;
	if	((ep->e.a_flag & 1) == 0)	/* relocation present? */
		l += sum;
	return(l);
	}
