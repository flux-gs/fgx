/* FGX libc — stdarg.h.  Real va_list over the K&R right-to-left stack ABI
 * (T5-C C2).
 *
 * fcc pushes args to explicitly-variadic (`...`) and empty-paren functions
 * right-to-left on the bank-0 hardware stack, so the named params sit at the
 * SHALLOW end and the varargs walk UPWARD from the last named param.  va_list
 * is a plain char * holding that walk address (&param yields a far pointer
 * into bank 0 — P3-3 put all params on the hardware stack).
 *
 * Slot rules (must mirror fcc's arg pushes):
 *   int/char/unsigned    one 2-byte slot (chars promote)
 *   long/float/pointer   one 4-byte slot
 * __va_slot rounds sizeof(T) up to the 2-byte stack granule.
 */
#ifndef _STDARG_H
#define _STDARG_H

typedef char *va_list;

#define __va_slot(T)      ((int)((sizeof(T) + 1) & ~1))

#define va_start(ap, last) \
    ((ap) = (char *)&(last) + __va_slot(last))
#define va_arg(ap, T) \
    (*(T *)(((ap) += __va_slot(T)) - __va_slot(T)))
#define va_end(ap)        ((ap) = (char *)0)

#endif
