/* FGX libc -- sys/syslog.h.  The facility/priority codes, which FGX keeps in
 * <syslog.h> and this forwards to.
 *
 * BOTH SPELLINGS ARE UPSTREAM AND THEY ARE THE SAME FILE THERE.  2.11BSD ships
 * `/usr/include/syslog.h' for userland and `usr/sys/h/syslog.h' for the kernel,
 * and `/usr/include/sys' is the kernel's h/ directory, so <sys/syslog.h> and
 * <syslog.h> resolve to copies of the same content.  syslogd(8) includes the
 * sys/ spelling and syslog(3)'s callers include the other; FGX has one file and
 * this is how the sys/ spelling reaches it, so neither has to be edited.
 */
#ifndef _SYS_SYSLOG_H
#define _SYS_SYSLOG_H

#include <syslog.h>

#endif /* _SYS_SYSLOG_H */
