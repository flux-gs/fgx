/* unistd.h -- FGX port shim for tcsh.  FGX has no unistd.h; tcsh's alloc11.c
 * and sh.h include it only for a few prototypes already provided by the FGX
 * libc (sbrk/brk via stdlib, the io primitives via fcntl/sys headers).  Keep
 * it minimal and let the real declarations come from the FGX headers. */
#ifndef _FGX_UNISTD_H
#define _FGX_UNISTD_H
#include <sys/types.h>
/* FULL prototypes, not empty parens.  `extern char *sbrk();` looks harmless but
 * carries no parameter information, so fcc will not emit a cross-TU signature
 * for a matching definition -- which meant tcsh's own sigs file had no sbrk at
 * all and tc.os.c's `membot = (char *)sbrk(0)` compiled against an IMPLICIT int
 * declaration, truncating the returned far pointer's BANK.  Must match
 * toolchain/include/unistd.h. */
extern char *sbrk(int incr);
extern int brk(char *addr);
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
#endif /* _FGX_UNISTD_H */
