/* err.h -- err(3).  Declarations for 2.11BSD's <err.h>.
 *
 * FGX-Provenance: 2.11BSD usr/include/err.h
 *   Copyright (c) 1993 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license.
 *
 * K&R DECLARATIONS, NOT PROTOTYPES, for the variadic four.  fcc has no
 * variadic prototype form, and an unprototyped declaration converts no
 * arguments -- which is right here: err(3) IS variadic and each caller's
 * arguments must arrive unconverted.  The `v' forms take a fixed list and are
 * prototyped, so a va_list cannot be passed where a format was meant.
 */
#ifndef _ERR_H_
#define _ERR_H_

void err();                     /* err(eval, fmt, ...)   -- exits            */
void errx();                    /* errx(eval, fmt, ...)  -- exits, no errno  */
void warn();                    /* warn(fmt, ...)        -- prepends progname*/
void warnx();                   /* warnx(fmt, ...)       -- no errno         */

void verr(int eval, char *fmt, char *ap);
void verrx(int eval, char *fmt, char *ap);
void vwarn(char *fmt, char *ap);
void vwarnx(char *fmt, char *ap);

#endif /* _ERR_H_ */
