/* FGX libc -- machine/machparam.h.  The click conversions of 2.11BSD's
 * usr/sys/pdp/machparam.h for FGX's click: the coremap's 256-byte page
 * (src/kernel/bank.s), where the PDP-11's is 64 bytes.  A page is one click,
 * so CLSIZE is 1.
 */
#ifndef _MACHINE_MACHPARAM_H
#define _MACHINE_MACHPARAM_H

#define	CLSIZE		1

/* clicks to bytes */
#define	ctob(x)	((long)(x) << 8)

/* bytes to clicks */
#define	btoc(x)	(((unsigned long)(x) + 255) >> 8)

/* clicks to KB */
#define	ctok(x)	((long)(x) >> 2)

#endif /* _MACHINE_MACHPARAM_H */
