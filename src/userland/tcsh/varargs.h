/* varargs.h -- FGX port shim: the pre-ANSI K&R varargs interface over fcc's
 * stdarg mechanism.  tcsh's xprintf engine (tc.printf.c) uses the old form:
 *     f(va_alist) va_dcl { va_list ap; va_start(ap); x = va_arg(ap, T); }
 * fcc pushes args right-to-left on the bank-0 hw stack, named params at the
 * shallow end (see stdarg.h).  In the K&R form `va_alist` IS the first formal
 * (declared int by va_dcl) and the varargs walk starts AT it, so
 * va_start(ap) = &va_alist (contrast stdarg's &last + slot). */
#ifndef _VARARGS_H
#define _VARARGS_H

typedef char *va_list;

#define __va_slot(T)   ((int)((sizeof(T) + 1) & ~1))

/* va_alist: the catch-all first parameter name used in the K&R signature.
 * va_dcl declares it (no trailing semicolon at the use site). */
#define va_dcl         int va_alist;
#define va_start(ap)   ((ap) = (char *)&va_alist)
#define va_arg(ap, T)  (*(T *)(((ap) += __va_slot(T)) - __va_slot(T)))
#define va_end(ap)     ((ap) = (char *)0)

#endif /* _VARARGS_H */
