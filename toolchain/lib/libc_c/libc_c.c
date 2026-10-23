/* lib/libc_c/libc_c.c — the C-converted libc pile TU (T5-C C4).
 *
 * One TU, many functions: every conversion moves a wrapper here and
 * retires its hand block in fcc_libc_shims.s (tombstone comment points
 * back).  Compiled by `make libc_c` (fcc --pile) into the CHECKED-IN
 * lib/libc_c.s that every pile link PUTs — no fcc at link time.
 *
 * Pile rules (docs: 2026-07-10-fgx-t5c-libc-in-c.md): near calls only,
 * zero reloc rows, no CALLEE_ENTER — DBR stays the caller's data bank,
 * which is exactly where errno and the frozen-prefix cells live.
 * Failure contract (mirrors SYSCALL_ERR/_ERRSW): on the kernel's fail
 * carry the syscall's A return IS the errno code.
 *
 * UMBRELLA (2026-08-05, libc-breakup task 1).  The bodies now live in
 * sibling member .c files and this file is the aggregator -- the system
 * includes, then one #include per member, exactly the libcurses_c/
 * libcurses.c pattern.  Members are NOT separate translation units and
 * must never be compiled standalone: that would re-expose the cross-TU
 * far-pointer hazard, and the pile rules above (near calls only, zero
 * reloc rows, no CALLEE_ENTER, DBR = the caller's data bank) depend on
 * the one-TU aggregation.
 *
 * THE INCLUDE ORDER IS THE ORIGINAL DEFINITION ORDER AND IS LOAD-BEARING.
 * One TU means file-scope statics and forward declarations cross member
 * boundaries: doprnt.c defines __lc_pfc() for fltpr.c.  Reordering the list also reorders the
 * emitted routines, so libc_c.s stops being byte-identical.  Add a new
 * member where its definitions belong, not at the end of the list.
 *
 * ANYTHING SHARED THAT IS NOT A SYMBOL GOES IN THE PROLOGUE BELOW, not in
 * a member -- see the comment there (libc-breakup task 2).
 */
#include <ctype.h>              /* isdigit (mktemp's name walk) */
#include <errno.h>
#include <fcntl.h>              /* O_CREAT/O_EXCL/O_RDWR (mkstemp) */
#include <sys/file.h>           /* L_XTND (fopen, fdopen, freopen) */
#include <stdarg.h>
#include <string.h>
#include <strings.h>             /* index (syslog) */
#include <sys/dir.h>
#include <sys/ioctl.h>          /* FIODGNAME, FIODGNAME_MAX (ttyname) */
#include <sys/param.h>          /* MAXPATHLEN, for getwd(3) */
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/resource.h>    /* struct rusage (wait3) */
#include <sys/wait.h>             /* union wait (pclose) */
#include <sys/mount.h>          /* struct statfs, MNT_* (getmntinfo, df) */
#include <sys/sysctl.h>         /* CTL_KERN, KERN_SECURELVL (sysctl) */
#include <stdlib.h>             /* malloc/free -- PROTOTYPED, apple/fgx#327 */
#include <pwd.h>                /* struct passwd (the /etc/passwd database) */
#include <grp.h>                /* struct group (the /etc/group database) */
#include <ttyent.h>             /* struct ttyent (the /etc/ttys database) */
#include <utmp.h>               /* struct utmp (ttyslot/login/logout) */
#include <sys/timeb.h>          /* struct timeb (ftime) */
#include <sgtty.h>              /* struct sgttyb, TIOCGETP/TIOCSETP, ECHO (getpass) */
#include <unistd.h>             /* _PASSWORD_LEN (getpass) */
#include <sys/uio.h>            /* struct iovec (readv/writev) */
#include <sys/ldctl.h>          /* struct ld_work (ld_load) */
#include <syslog.h>             /* LOG_* (syslog(3), for daemon ports) */
/* sys/signal.h gives struct sigvec plus the sigvec/sigpause declarations, and
 * it includes <signal.h> itself, so the SIG numbers and NSIG come along too.
 * (Keep the comment OFF the #include line: fcc's pp does not carry a block
 * comment across a line break there.) */
#include <sys/signal.h>
#include <time.h>
/* <tzfile.h>: TZDIR, TZ_MAX_*, SECSPER*, TM_YEAR_BASE (ctime, strftime) */
#include <tzfile.h>
#include <netinet/in.h>                       /* struct in_addr, u_long (inet_*) */
#include <netdb.h>                            /* struct hostent (gethostbyname) */
#include <sys/socket.h>                       /* AF_INET, SOCK_DGRAM (resolver) */
#include <sys/un.h>                           /* SUN_LEN, SUN_PATH_MAX (syslog) */
#include <arpa/nameser.h>                     /* DNS wire constants (resolver)  */
#include <arpa/inet.h>                         /* inet_addr (resolver) */

/* ---- CROSS-MEMBER PROLOGUE (libc-breakup task 2) -------------------------
 * Declarations and macros MORE THAN ONE member needs.  They used to sit in
 * whichever member happened to come first, which made the umbrella's include
 * ORDER a compile-time dependency the archive index cannot see: these name
 * things DEFINED OUTSIDE lib/libc_c (hand asm, crt0) or are preprocessor
 * macros, so no symbol edge exists for `fgx_ar` to follow and a dead-strip
 * that dropped the declaring member broke the COMPILE of the survivors
 * (24 of 42 single-member closures, measured 2026-08-05).  Here they are in
 * the aggregate's prologue, which every filtered subset keeps.
 * Declarations only -- no storage, no code, so lib/libc_c.s is unchanged.
 */

/* __asm staging cells (fcc_runtime_data.s).  The C side stores args here
 * (far-pointer stores carry the bank); the __asm body lifts them into the
 * pile's DP long-pointer slots (c_strcmp_a/b, EQUs in fcc_libc_shims.s) for
 * [dp],Y loops.  Dedicated cells, NOT _fcc_* scratch -- fcc codegen may
 * clobber scratch between the C store and the block. */
extern char *__asm_p0;
extern char *__asm_p1;
extern int   __asm_w0;
extern int   __asm_w1;
extern int   __asm_w2;

/* The env block crt0 captured (args_data.s): packed "NAME=VAL\0...\0\0". */
extern char args_env[];

/* Data-bank staging for the syscalls that take a path or a pair of time_t:
 * the kernel reads them through _Sys_CallerBank (libc_data.s). */
extern char _libc_lstrBufA[];
extern char _libc_lstrBufB[];


#include "syscall_misc.c"
#include "uio.c"
#include "mem.c"
#include "ctype_.c"
#include "string.c"
/* UFS 2.1: one function per file, deliberately -- the pile is dead-stripped at
 * FILE granularity, so a function living in string.c rides into every binary
 * that calls strlen.  These three did exactly that and pushed an M37 fixture's
 * 64 KB code segment over the limit.  Upstream's own layout is one per file. */
#include "strcasecmp.c"
#include "strpbrk.c"
#include "strsep.c"
#include "strstr.c"
#include "strtok.c"
#include "fstab.c"
#include "syscall_file.c"
#include "proc.c"
#include "exec.c"
#include "execl.c"
#include "execle.c"
#include "execvp.c"
#include "getdtablesize.c"
#include "fcntl.c"
#include "flock.c"
#include "fchown.c"
#include "fchmod.c"
#include "wait.c"
#include "stdlib.c"
#include "strtol.c"
#include "bzero.c"
#include "abs.c"
#include "labs.c"
#include "rand.c"
#include "env.c"
#include "setenv.c"
#include "socket.c"
#include "socket_srv.c"
#include "select.c"
#include "sysctl.c"
#include "sockopt.c"
#include "err.c"
#include "getmntinfo.c"
#include "malloc.c"
#include "popen.c"
#include "ioctl.c"
#include "signal.c"
#include "stat.c"
#include "syserrlst.c"
#include "strerror.c"
#include "system.c"
#include "time.c"
#include "_exit.c"
#include "findiop.c"
#include "filbuf.c"
#include "flsbuf.c"
#include "exit.c"
#include "fopen.c"
#include "fdopen.c"
#include "freopen.c"
#include "fread.c"
#include "fwrite.c"
#include "fgetc.c"
#include "fputc.c"
#include "getchar.c"
#include "putchar.c"
#include "fgets.c"
#include "fputs.c"
#include "gets.c"
#include "puts.c"
#include "getw.c"
#include "putw.c"
#include "ungetc.c"
#include "fseek.c"
#include "ftell.c"
#include "rew.c"
#include "clrerr.c"
#include "setvbuf.c"
#include "setbuf.c"
#include "setbuffer.c"
#include "perror.c"
#include "sigmask.c"
#include "sigaction.c"
#include "siglist.c"
#include "pgrp.c"
#include "ttyname.c"
#include "rlimit.c"
#include "gethostname.c"
#include "ldexp.c"
#include "modf.c"
#include "ecvt.c"
#include "atof.c"
#include "doscan.c"
#include "scanf.c"
#include "pwent.c"
#include "grent.c"
#include "ttyent.c"
#include "utmp.c"
#include "ftime.c"
#include "doprnt.c"
#include "printf.c"
#include "fprintf.c"
#include "vfprintf.c"
#include "vprintf.c"
#include "sprintf.c"
#include "vsprintf.c"
#include "fltpr.c"
#include "vsnprintf.c"
#include "inet.c"
#include "netdb.c"
#include "dir.c"
/* AFTER dir.c and stat.c: getwd walks the tree with opendir/readdir and
 * stats each level.  One pile TU, so an include that came first would meet
 * them undeclared. */
#include "getwd.c"
#include "uid.c"
#include "calloc.c"
#include "getopt.c"
#include "qsort.c"
#include "ctime.c"
#include "strftime.c"
#include "strmode.c"
#include "difftime.c"
#include "utimes.c"
#include "gettimeofday.c"
#include "settimeofday.c"
#include "adjtime.c"
#include "itimer.c"
#include "alias.c"
#include "crypt.c"
#include "getpass.c"
#include "mktemp.c"
#include "syslog.c"
/* AFTER the members it calls -- fork, isatty/dup2, chdir, open/close and
 * _exit are all defined above, and one TU means a call ahead of the
 * definition would be an implicit declaration. */
#include "daemon.c"
#include "groups.c"
#include "libc_init.c"
#include "ld_load.c"
#include "ld_bind.c"
