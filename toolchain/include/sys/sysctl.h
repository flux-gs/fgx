/* FGX libc -- sys/sysctl.h.  2.11BSD usr/sys/h/sysctl.h's names and numbers,
 * which are 4.4BSD-Lite's ("sysctl() was borrowed from 4.4BSD-Lite", 2.11BSD
 * patch #219).
 *
 * THE WHOLE CTL_KERN SET IS LISTED, NOT ONLY THE ONE THAT ANSWERS.  The
 * namespace is a numbering that other systems share, so a name that exists
 * upstream keeps its number here whether or not this kernel serves it; taking
 * only KERN_SECURELVL and renumbering it 1 would make a FGX program's MIB mean
 * something different from every other BSD's.
 *
 * WHAT THIS KERNEL ANSWERS TODAY is kern.securelevel, kern.clockrate,
 * kern.boottime, the machdep node (<machine/cpu.h>) and the vm node
 * (<sys/vmparam.h>).  Every other name returns -1 with errno ENOTSUP, which
 * is upstream's own `default:' answer for a top-level id it was not built
 * with (kern_sysctl.c's __sysctl, EOPNOTSUPP).
 */
#ifndef _SYS_SYSCTL_H
#define _SYS_SYSCTL_H

#define CTL_MAXNAME     12      /* largest number of components supported */

/* Top-level identifiers */
#define CTL_UNSPEC       0      /* unused */
#define CTL_KERN         1      /* "high kernel": proc, limits */
#define CTL_VM           2      /* virtual memory */
#define CTL_FS           3      /* file system, mount type is next */
#define CTL_NET          4      /* network, see socket.h */
#define CTL_DEBUG        5      /* debugging parameters */
#define CTL_HW           6      /* generic cpu/io */
#define CTL_MACHDEP      7      /* machine dependent */
#define CTL_USER         8      /* user-level */
#define CTL_MAXID        9      /* number of valid top-level ids */

/* The CTL_MACHDEP identifiers are in <machine/cpu.h>, as in both BSDs. */

/* CTL_KERN identifiers */
#define KERN_OSTYPE      1      /* string: system version */
#define KERN_OSRELEASE   2      /* string: system release */
#define KERN_OSREV       3      /* int: system revision */
#define KERN_VERSION     4      /* string: compile time info */
#define KERN_MAXINODES   5      /* int: max inodes */
#define KERN_MAXPROC     6      /* int: max processes */
#define KERN_MAXFILES    7      /* int: max open files */
#define KERN_ARGMAX      8      /* int: max arguments to exec */
#define KERN_SECURELVL   9      /* int: system security level -- SERVED */
#define KERN_HOSTNAME   10      /* string: hostname */
#define KERN_HOSTID     11      /* int: host identifier */
#define KERN_CLOCKRATE  12      /* struct: struct clockrate */
#define KERN_INODE      13      /* struct: inode structures */
#define KERN_PROC       14      /* struct: process entries */
#define KERN_FILE       15      /* struct: file entries */
#define KERN_PROF       16      /* node: kernel profiling info */
#define KERN_POSIX1     17      /* int: POSIX.1 version */
#define KERN_NGROUPS    18      /* int: # of supplemental group ids */
#define KERN_JOB_CONTROL 19     /* int: is job control available */
#define KERN_SAVED_IDS  20      /* int: saved set-user/group-ID */
#define KERN_BOOTTIME   21      /* struct: time kernel was booted */
#define KERN_MAXTEXTS   22      /* int: # of text entries */
#define KERN_TEXT       23      /* struct: text entries */
#define KERN_ACCTTHRESH 24      /* int: accounting daemon threshold */
#define KERN_MAXID      25      /* number of valid kern ids */

int sysctl();

#endif /* _SYS_SYSCTL_H */
