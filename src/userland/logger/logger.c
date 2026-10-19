/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1983
 *   The Regents of the University of California.  All rights reserved.
 *
 * FGX-Provenance: 2.11BSD logger(1)
 *   Ported from logger.c 6.2.1 (2.11BSD) 1997/10/2, vendored at
 *   vendor/2.11BSD/usr/ucb/logger.c, with its argument loop from logger.c
 *   6.14 (Berkeley) 6/1/90, 4.3BSD-Reno's, vendored at
 *   vendor/4.3BSD-Reno/usr.bin/logger/logger.c.  UCB notice retained per the
 *   BSD license; FGX changes are BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).
 *
 * logger - make entries in the system log.  UPSTREAM'S TEXT, with three
 * defects repaired, each marked `FGX' and each the way 4.3BSD-Reno's logger
 * already has it:
 *
 *   - the -f error path called `fprintf("logger: ")' with no stream, so a file
 *     that would not open passed the string as the FILE.  It names stderr,
 *     as the unknown-flag message two cases below it does.
 *
 *   - THE MESSAGE WAS THE FORMAT.  syslog(pri, buf) hands the text to
 *     syslog(3) as its format string, so a `%' in a message reads arguments
 *     that were never passed.  Both calls send it through "%s", as Reno's do.
 *
 *   - THE COMMAND-LINE MESSAGE WAS JOINED WITH strcat INTO A 120-BYTE LOCAL
 *     with no bound, so a long message wrote past it into the caller's frame.
 *     Reno's loop replaces 2.11BSD's whole: it joins into the 200-byte buffer
 *     the file loop already uses, logs a line each time the next word would
 *     not fit, and logs a word longer than the buffer by itself.
 */
/*
 * Copyright (c) 1983 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if	!defined(lint) && defined(DOSCCS)
char copyright[] =
"@(#) Copyright (c) 1983 Regents of the University of California.\n\
 All rights reserved.\n";

static char sccsid[] = "@(#)logger.c	6.2.1 (2.11BSD) 1997/10/2";
#endif

#include <stdio.h>
#include <syslog.h>
#include <unistd.h>
#include <ctype.h>

/*
**  LOGGER -- read and log utility
**
**	This routine reads from an input and arranges to write the
**	result on the system log, along with a useful tag.
*/

main(argc, argv)
	int argc;
	char **argv;
{
	char buf[200];
	char *tag;
	register char *p;
	int pri = LOG_NOTICE;
	int logflags = 0;

	/* initialize */
	tag = getlogin();

	/* crack arguments */
	while (--argc > 0)
	{
		p = *++argv;
		if (*p != '-')
			break;

		switch (*++p)
		{
		  case '\0':		/* dummy */
			/* this can be used to give null parameters */
			break;

		  case 't':		/* tag */
			if (argc > 1 && argv[1][0] != '-')
			{
				argc--;
				tag = *++argv;
			}
			else
				tag = NULL;
			break;

		  case 'p':		/* priority */
			if (argc > 1 && argv[1][0] != '-')
			{
				argc--;
				pri = pencode(*++argv);
			}
			break;

		  case 'i':		/* log process id also */
			logflags |= LOG_PID;
			break;

		  case 'f':		/* file to log */
			if (argc > 1 && argv[1][0] != '-')
			{
				argc--;
				if (freopen(*++argv, "r", stdin) == NULL)
				{
					fprintf(stderr, "logger: ");	/* FGX */
					perror(*argv);
					exit(1);
				}
			}
			break;

		  default:
			fprintf(stderr, "logger: unknown flag -%s\n", p);
			break;
		}
	}

	/* setup for logging */
	openlog(tag, logflags, 0);
	(void) fclose(stdout);

	/* log input line if appropriate */
	if (argc > 0) {			/* FGX: 4.3BSD-Reno's, see the header */
		register char *p, *endp;
		int len;

		for (p = buf, endp = buf + sizeof(buf) - 2; *argv;) {
			len = strlen(*argv);
			if (p + len > endp && p > buf) {
				syslog(pri, "%s", buf);
				p = buf;
			}
			if (len > sizeof(buf) - 1)
				syslog(pri, "%s", *argv++);
			else {
				if (p != buf)
					*p++ = ' ';
				bcopy(*argv++, p, len);
				*(p += len) = '\0';
			}
		}
		if (p != buf)
			syslog(pri, "%s", buf);
		exit(0);
	}

	/* main loop */
	while (fgets(buf, sizeof buf, stdin) != NULL)
		syslog(pri, "%s", buf);		/* FGX: see the header */

	exit(0);
}


struct code {
	char	*c_name;
	int	c_val;
};

struct code	PriNames[] = {
	"panic",	LOG_EMERG,
	"emerg",	LOG_EMERG,
	"alert",	LOG_ALERT,
	"crit",		LOG_CRIT,
	"err",		LOG_ERR,
	"error",	LOG_ERR,
	"warn",		LOG_WARNING,
	"warning",	LOG_WARNING,
	"notice",	LOG_NOTICE,
	"info",		LOG_INFO,
	"debug",	LOG_DEBUG,
	NULL,		-1
};

struct code	FacNames[] = {
	"kern",		LOG_KERN,
	"user",		LOG_USER,
	"mail",		LOG_MAIL,
	"daemon",	LOG_DAEMON,
	"auth",		LOG_AUTH,
	"security",	LOG_AUTH,
	"local0",	LOG_LOCAL0,
	"local1",	LOG_LOCAL1,
	"local2",	LOG_LOCAL2,
	"local3",	LOG_LOCAL3,
	"local4",	LOG_LOCAL4,
	"local5",	LOG_LOCAL5,
	"local6",	LOG_LOCAL6,
	"local7",	LOG_LOCAL7,
	NULL,		-1
};


/*
 *  Decode a symbolic name to a numeric value
 */

pencode(s)
	register char *s;
{
	register char *p;
	int lev;
	int fac;
	char buf[100];

	for (p = buf; *s && *s != '.'; )
		*p++ = *s++;
	*p = '\0';
	if (*s++) {
		fac = decode(buf, FacNames);
		if (fac < 0)
			bailout("unknown facility name: ", buf);
		for (p = buf; *p++ = *s++; )
			continue;
	} else
		fac = 0;
	lev = decode(buf, PriNames);
	if (lev < 0)
		bailout("unknown priority name: ", buf);

	return ((lev & LOG_PRIMASK) | (fac & LOG_FACMASK));
}


decode(name, codetab)
	char *name;
	struct code *codetab;
{
	register struct code *c;
	register char *p;
	char buf[40];

	if (isdigit(*name))
		return (atoi(name));

	(void) strcpy(buf, name);
	for (p = buf; *p; p++)
		if (isupper(*p))
			*p = tolower(*p);
	for (c = codetab; c->c_name; c++)
		if (!strcmp(buf, c->c_name))
			return (c->c_val);

	return (-1);
}

bailout(a, b)
	char *a, *b;
{
	fprintf(stderr, "logger: %s%s\n", a, b);
	exit(1);
}
