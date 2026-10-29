/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/filbuf.c
 *   Original work: filbuf.c 5.3 (Berkeley) 3/9/86,
 *	Copyright (c) 1980
 *	Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
_filbuf(iop)
register FILE *iop;
{
	int size;
	struct stat stbuf;
	extern char *_smallbuf;
	char c;

	if (iop->_flag & _IORW)
		iop->_flag |= _IOREAD;

	if ((iop->_flag&_IOREAD) == 0)
		return(EOF);
	if (iop->_flag&(_IOSTRG|_IOEOF))
		return(EOF);
tryagain:
	if (iop->_base==NULL) {
		if (iop->_flag&_IONBF) {
			iop->_base = _smallbuf ? &_smallbuf[fileno(iop)] : &c;
			goto tryagain;
		}
		if (fstat(fileno(iop), &stbuf) < 0 || stbuf.st_blksize <= NULL)
			size = BUFSIZ;
		else
			size = stbuf.st_blksize;
		if ((iop->_base = malloc(size)) == NULL) {
			iop->_flag |= _IONBF;
			goto tryagain;
		}
		iop->_flag |= _IOMYBUF;
		iop->_bufsiz = size;
	}
	if (iop == stdin) {
		if (stdout->_flag&_IOLBF)
			fflush(stdout);
		if (stderr->_flag&_IOLBF)
			fflush(stderr);
	}
	iop->_cnt = read(fileno(iop), iop->_base,
		iop->_flag & _IONBF ? 1 : iop->_bufsiz);
	iop->_ptr = iop->_base;
	if (iop->_flag & _IONBF && iop->_base == &c)
		iop->_base = NULL;
	if (--iop->_cnt < 0) {
		if (iop->_cnt == -1) {
			iop->_flag |= _IOEOF;
			if (iop->_flag & _IORW)
				iop->_flag &= ~_IOREAD;
		} else
			iop->_flag |= _IOERR;
		iop->_cnt = 0;
		return(EOF);
	}
	return(*iop->_ptr++&0377);
}
