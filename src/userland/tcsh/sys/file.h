/* sys/file.h -- FGX port shim for tcsh.  BSD file-flag + seek + flock names.
 * The real open/lseek flags live in <fcntl.h>; this adds the BSD spellings
 * tcsh uses and no-op flock constants. */
#ifndef _FGX_SYS_FILE_H
#define _FGX_SYS_FILE_H
#include <fcntl.h>
#ifndef L_SET
#define L_SET   0      /* lseek: absolute (SEEK_SET) */
#define L_INCR  1      /* relative (SEEK_CUR) */
#define L_XTND  2      /* from EOF (SEEK_END) */
#endif
#ifndef FREAD
#define FREAD   0x0001
#define FWRITE  0x0002
#endif
/* flock(2): FGX has no advisory locks; provide the names as no-op-able. */
#define LOCK_SH 1
#define LOCK_EX 2
#define LOCK_NB 4
#define LOCK_UN 8
#endif /* _FGX_SYS_FILE_H */
