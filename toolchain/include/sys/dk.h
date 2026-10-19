/* FGX libc -- sys/dk.h.  2.11BSD usr/sys/h/dk.h's CPU states, the index of
 * vm.cp_time's long cp_time[CPUSTATES].  The kernel charges a tick to
 * CP_USER, CP_SYS or CP_IDLE; CP_NICE is never charged (include/kernel.s).
 */
#ifndef _SYS_DK_H
#define _SYS_DK_H

#define	CPUSTATES	4

#define	CP_USER		0
#define	CP_NICE		1
#define	CP_SYS		2
#define	CP_IDLE		3

#define	DK_NDRIVE	10

#endif /* _SYS_DK_H */
