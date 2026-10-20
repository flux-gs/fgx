/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/setenv.c
 *   Ported from setenv(3), 2.11BSD (setenv.c 1.3, 6/16/87), with _findenv
 *   from getenv.c (5.4, 3/13/87).  Original work:
 *   Copyright (c) 1987 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* setenv(3), unsetenv(3), and _findenv, which upstream keeps in getenv.c
 * beside a getenv that FGX's env.c supplies.  Wanted by date(1)'s -u, which
 * sets TZ=GMT.
 *
 * FGX deltas: a null environ (a near-crt0 binary, env.c) is an empty
 * environment rather than a fault; malloc, realloc and bcopy are the
 * prototypes in scope rather than local K&R declarations.
 */
char *_findenv();

/*
 * setenv(name,value,rewrite)
 *	Set the value of the environmental variable "name" to be
 *	"value".  If rewrite is set, replace any current value.
 */
setenv(name,value,rewrite)
	register char	*name,
			*value;
	int	rewrite;
{
	extern char	**environ;
	static int	alloced;		/* if allocated space before */
	register char	*C;
	int	l_value,
		offset;

	if (*value == '=')			/* no `=' in value */
		++value;
	l_value = strlen(value);
	if ((C = _findenv(name,&offset))) {	/* find if already exists */
		if (!rewrite)
			return(0);
		if (strlen(C) >= l_value) {	/* old larger; copy over */
			while (*C++ = *value++);
			return(0);
		}
	}
	else {					/* create new slot */
		register int	cnt;
		register char	**P;

		cnt = 0;			/* FGX: environ may be null */
		if (environ)
			for (P = environ;*P;++P,++cnt);
		if (alloced) {			/* just increase size */
			environ = (char **)realloc((char *)environ,
			    (unsigned long)(sizeof(char *) * (cnt + 2)));
			if (!environ)
				return(-1);
		}
		else {				/* get new space */
			alloced = 1;		/* copy old entries into it */
			P = (char **)malloc((unsigned long)(sizeof(char *) *
			    (cnt + 2)));
			if (!P)
				return(-1);
			if (cnt)
				bcopy(environ,P,cnt * sizeof(char *));
			environ = P;
		}
		environ[cnt + 1] = 0;
		offset = cnt;
	}
	for (C = name;*C && *C != '=';++C);	/* no `=' in name */
	if (!(environ[offset] =			/* name + `=' + value */
	    malloc((unsigned long)((int)(C - name) + l_value + 2))))
		return(-1);
	for (C = environ[offset];(*C = *name++) && *C != '=';++C);
	for (*C++ = '=';*C++ = *value++;);
	return(0);
}

/*
 * unsetenv(name) --
 *	Delete environmental variable "name".
 */
void
unsetenv(name)
	char	*name;
{
	extern	char	**environ;
	register char	**P;
	int	offset;

	while (_findenv(name,&offset))		/* if set multiple times */
		for (P = &environ[offset];;++P)
			if (!(*P = *(P + 1)))
				break;
}

/*
 * _findenv(name,offset) --
 *	Returns pointer to value associated with name, if any, else NULL.
 *	Sets offset to be the offset of the name/value combination in the
 *	environmental array, for use by setenv(3) and unsetenv(3).
 *	Explicitly removes '=' in argument name.
 *
 *	This routine *should* be a static; don't use it.
 */
char *
_findenv(name,offset)
	register char *name;
	int	*offset;
{
	extern char	**environ;
	register int	len;
	register char	**P,
			*C;

	if (!environ)				/* FGX: environ may be null */
		return(0);
	for (C = name,len = 0;*C && *C != '=';++C,++len);
	for (P = environ;*P;++P)
		if (!strncmp(*P,name,len))
			if (*(C = *P + len) == '=') {
				*offset = P - environ;
				return(++C);
			}
	return(0);
}
