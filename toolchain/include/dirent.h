/* FGX libc — dirent.h.  POSIX spelling over FGX's 4.2BSD-shape directory
 * access, which lives in <sys/dir.h> as `struct direct` (SYS_LISTDIR).  POSIX
 * names the record `struct dirent`; alias it so both spellings resolve to the
 * one struct libc's opendir/readdir actually fill.  d_name and d_namlen are
 * the members ports read.
 */
#ifndef _DIRENT_H
#define _DIRENT_H

#include <sys/dir.h>

#define dirent direct

#endif /* _DIRENT_H */
