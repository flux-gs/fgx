/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/setvbuf.c
 *   Original work: setvbuf.c 8.1.1 (2.11BSD) 1997/7/27,
 *	Copyright (c) 1990, 1993
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
/*
 * This has been slightly trimmed from the 4.4BSD version for use with 2.11BSD.
 * In particular 1) the flag names were changed back to the original ones 
 * since I didn't feel like porting all of 4.4's stdio package right now and 
 * 2) The constant BUFSIZ is used rather than importing the "optimum buffer
 * size selection" logic from 4.4 (besides, a PDP11 can't afford more than 1kb
 * most of the time anyhow).
 *
 * Set one of the three kinds of buffering, optionally including
 * a buffer.
 */
setvbuf(fp, buf, mode, size)
	register FILE *fp;
	char *buf;
	register int mode;
	size_t size;
{
	int	ret;
	register int flags;

/*
 * Verify arguments. Note, buf and size are ignored when setting _IONBF.
 */
	if (mode != _IONBF)
		if ((mode != _IOFBF && mode != _IOLBF) || (int)size < 0)
			return (EOF);

	/*
	 * Write current buffer, if any.  Discard unread input, cancel
	 * line buffering, and free old buffer if malloc()ed.
	 */
	(void)fflush(fp);
	fp->_cnt = fp->_bufsiz = 0;
	flags = fp->_flag;
	if (flags & _IOMYBUF)
		free((void *)fp->_base);
	flags &= ~(_IOLBF | _IONBF | _IOMYBUF);
	ret = 0;

	/* If setting unbuffered mode, skip all the hard work. */
	if (mode == _IONBF)
		goto nbf;

	if (size == 0) {
		buf = NULL;	/* force local allocation */
		size = BUFSIZ;
	}

	/* Allocate buffer if needed. */
	if (buf == NULL) {
		if ((buf = (char *)malloc(size)) == NULL) {
			/*
			 * Unable to honor user's request.  We will return
			 * failure, but try again with file system size.
			 */
			ret = EOF;
			if (size != BUFSIZ) {
				size = BUFSIZ;
				buf = (char *)malloc(size);
			}
		}
		if (buf == NULL) {
			/* No luck; switch to unbuffered I/O. */
nbf:
			fp->_flag = flags | _IONBF;
			fp->_base = fp->_ptr = NULL;
			return (ret);
		}
		flags |= _IOMYBUF;
	}

	/*
	 * Fix up the FILE fields.  If in r/w mode, go to the unknown state
	 * so that the the first read performs its initial call to _filbuf and
	 * the first write has an empty buffer to fill.
	 */
	if (mode == _IOLBF)
		flags |= _IOLBF;
	if (flags & _IORW)
		flags &= ~(_IOREAD | _IOWRT);
	fp->_flag = flags;
	fp->_base = fp->_ptr = (char *)buf;
	fp->_bufsiz = size;
	return (ret);
}
