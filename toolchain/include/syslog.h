/* FGX libc -- syslog.h.  BSD syslog(3) surface for daemon ports.
 *
 * syslog() forms the "<pri>Mon dd hh:mm:ss tag[pid]: message" line and sends it
 * as one AF_UNIX SOCK_DGRAM datagram to _PATH_LOG, which is where syslogd(8)
 * reads it from, and /etc/syslog.conf decides where it goes after that.  When
 * the datagram cannot reach a syslogd, the line takes the same two fallbacks
 * 2.11BSD's own libc takes:
 *
 *   - when the AF_UNIX socket cannot be created at all -- a boot with no net
 *     module, so there is no unp transport -- openlog() appends to
 *     /usr/adm/messages instead.  THE FILE must exist, not merely the
 *     directory: the open carries no O_CREAT, as upstream's does not.  And
 *     upstream latches its ToFile and connected flags BEFORE testing that
 *     open, so a missing file leaves the fallback selected and the socket is
 *     never retried for the life of the process -- verbatim 2.11BSD;
 *   - when the socket exists but the datagram cannot be delivered, a caller
 *     that asked for LOG_CONS gets the line on /dev/console.
 *
 * With the transport present and nothing bound to _PATH_LOG, the line is
 * dropped, which is what 2.11BSD does when syslogd is not running.
 *
 * Priority/facility VALUES match 2.11BSD usr/sys/h/syslog.h (8.1.2, 1999/06/18)
 * exactly so ported sources compile and compare against the same numbers
 * upstream did.
 */
#ifndef _SYSLOG_H
#define _SYSLOG_H

#define _PATH_LOG       "/dev/log"

/* Facility codes (upper bits) -- priorities are the low 3 bits. */
#define LOG_KERN        (0<<3)  /* kernel messages */
#define LOG_USER        (1<<3)  /* random user-level messages */
#define LOG_MAIL        (2<<3)  /* mail system */
#define LOG_DAEMON      (3<<3)  /* system daemons */
#define LOG_AUTH        (4<<3)  /* security/authorization messages */
#define LOG_SYSLOG      (5<<3)  /* messages generated internally by syslogd */
#define LOG_LPR         (6<<3)  /* line printer subsystem */
#define LOG_NEWS        (7<<3)  /* network news subsystem */
#define LOG_UUCP        (8<<3)  /* UUCP subsystem */
#define LOG_CRON        (9<<3)  /* clock daemon */
#define LOG_AUTHPRIV    (10<<3) /* security/authorization messages (private) */
#define LOG_FTP         (11<<3) /* ftp daemon */
                                /* codes through 15 reserved for system use */
#define LOG_LOCAL0      (16<<3) /* reserved for local use */
#define LOG_LOCAL1      (17<<3) /* reserved for local use */
#define LOG_LOCAL2      (18<<3)
#define LOG_LOCAL3      (19<<3)
#define LOG_LOCAL4      (20<<3)
#define LOG_LOCAL5      (21<<3)
#define LOG_LOCAL6      (22<<3)
#define LOG_LOCAL7      (23<<3)

#define LOG_NFACILITIES 24              /* current number of facilities */
#define LOG_FACMASK     0x03f8          /* mask to extract facility part */
#define LOG_FAC(p)      (((p) & LOG_FACMASK) >> 3)

/* Priorities, in descending order of severity. */
#define LOG_EMERG       0       /* system is unusable */
#define LOG_ALERT       1       /* action must be taken immediately */
#define LOG_CRIT        2       /* critical conditions */
#define LOG_ERR         3       /* error conditions */
#define LOG_WARNING     4       /* warning conditions */
#define LOG_NOTICE      5       /* normal but significant condition */
#define LOG_INFO        6       /* informational */
#define LOG_DEBUG       7       /* debug-level messages */

#define LOG_PRIMASK     0x07            /* mask to extract priority part */
#define LOG_PRI(p)      ((p) & LOG_PRIMASK)
#define LOG_MAKEPRI(fac, pri)   (((fac) << 3) | (pri))

/* Arguments to setlogmask(). */
#define LOG_MASK(pri)   (1 << (pri))            /* mask for one priority */
#define LOG_UPTO(pri)   ((1 << ((pri)+1)) - 1)  /* all priorities through pri */

/* openlog() option flags.  LOG_ODELAY is upstream's own no-op and LOG_NOWAIT is
 * deprecated there; the other four are honoured. */
#define LOG_PID         0x01    /* log the pid with each message */
#define LOG_CONS        0x02    /* log on the console if errors in sending */
#define LOG_ODELAY      0x04    /* delay open until first syslog() (default) */
#define LOG_NDELAY      0x08    /* don't delay open */
#define LOG_NOWAIT      0x10    /* don't wait for console forks: DEPRECATED */
#define LOG_PERROR      0x20    /* log to stderr as well */

/* K&R prototypes, matching the ports' call sites.
 *
 * syslog() supports the BSD `%m` conversion (expands to the strerror text for
 * the errno current at entry) -- 2.11BSD telnetd uses it, e.g.
 *     syslog(LOG_INFO, "ttloop:  read: %m\n");
 * so dropping it would silently lose the reason for every such failure.
 *
 * setlogmask() IS ACCEPTED AND DOES NOT FILTER, which is upstream's own defect
 * rather than a narrowing here: 2.11BSD's vsyslog tests
 * `!LOG_MASK(LOG_PRI(pri)) & LogMask', and by K&R A.7.4 the `!' binds to the
 * LOG_MASK alone, so the left operand is always 0.  Every priority is
 * delivered. */
void openlog();
void syslog();
void vsyslog();
void closelog();
int setlogmask();

#endif /* _SYSLOG_H */
