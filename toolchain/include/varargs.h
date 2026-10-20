/* FGX libc — varargs.h.  Pre-ANSI K&R varargs over fcc's stdarg mechanism.
 *
 * Old-form variadic functions:
 *     f(va_alist) va_dcl { va_list ap; va_start(ap); x = va_arg(ap, T); ... }
 * fcc pushes args right-to-left on the bank-0 hardware stack, named params at
 * the shallow end (see <stdarg.h> for the slot rules this must mirror).  In the
 * K&R form `va_alist` IS the first formal (declared int by va_dcl), so the walk
 * starts AT it: va_start(ap) = &va_alist (contrast stdarg's &last + slot).
 *
 * Byte-compatible with <stdarg.h> (same 2-byte granule; long/ptr = 4 bytes) and
 * safe to include in the same TU as <stdarg.h> — va_list and __va_slot are
 * shared, identical definitions.
 */
#ifndef _VARARGS_H
#define _VARARGS_H

typedef char *va_list;

#ifndef __va_slot
#define __va_slot(T)   ((int)((sizeof(T) + 1) & ~1))
#endif

/* va_dcl declares the catch-all first formal `va_alist` (no trailing ';' at
 * the use site — it already ends in one). */
#define va_dcl         int va_alist;
#define va_start(ap)   ((ap) = (char *)&va_alist)
#define va_arg(ap, T)  (*(T *)(((ap) += __va_slot(T)) - __va_slot(T)))
#define va_end(ap)     ((ap) = (char *)0)

#endif /* _VARARGS_H */
