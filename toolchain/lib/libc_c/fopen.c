/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fopen.c
 *   Original work: fopen.c 5.2 (Berkeley) 3/9/86,
 *	Copyright (c) 1980
 *	Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
FILE *
fopen(file, mode)
	char *file;
	register char *mode;
{
	register FILE *iop;
	register f, rw, oflags;
	extern FILE *_findiop();

	iop = _findiop();
	if (iop == NULL)
		return (NULL);

	rw = (mode[1] == '+');

	switch (*mode) {
	case 'a':
		oflags = O_CREAT | (rw ? O_RDWR : O_WRONLY);
		break;
	case 'r':
		oflags = rw ? O_RDWR : O_RDONLY;
		break;
	case 'w':
		oflags = O_TRUNC | O_CREAT | (rw ? O_RDWR : O_WRONLY);
		break;
	default:
		return (NULL);
	}

	f = open(file, oflags, 0666);
	if (f < 0)
		return (NULL);

	if (*mode == 'a')
		lseek(f, (off_t)0, L_XTND);

	iop->_cnt = 0;
	iop->_file = f;
	iop->_bufsiz = 0;
	if (rw)
		iop->_flag = _IORW;
	else if (*mode == 'r')
		iop->_flag = _IOREAD;
	else
		iop->_flag = _IOWRT;
	iop->_base = iop->_ptr = NULL;
	return (iop);
}
