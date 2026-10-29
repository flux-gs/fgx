/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fread.c
 *   Original work: fread.c 5.2 (Berkeley) 3/9/86,
 *	Copyright (c) 1980
 *	Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
fread(ptr, size, count, iop)
	register char *ptr;
	unsigned size, count;
	register FILE *iop;
{
	register unsigned s;
	int c;

	s = size * count;
	while (s > 0) {
		if (iop->_cnt < s) {
			if (iop->_cnt > 0) {
				bcopy(iop->_ptr, ptr, iop->_cnt);
				ptr += iop->_cnt;
				s -= iop->_cnt;
			}
			/*
			 * filbuf clobbers _cnt & _ptr,
			 * so don't waste time setting them.
			 */
			if ((c = _filbuf(iop)) == EOF)
				break;
			*ptr++ = c;
			s--;
		}
		if (iop->_cnt >= s) {
			bcopy(iop->_ptr, ptr, s);
			iop->_ptr += s;
			iop->_cnt -= s;
			return (count);
		}
	}
	return (size != 0 ? count - ((s + size - 1) / size) : 0);
}
