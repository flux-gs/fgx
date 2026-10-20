/* FGX libc -- sys/vmparam.h.  2.11BSD usr/sys/h/vmparam.h's CTL_VM
 * identifiers, and two of FGX's own past its VM_MAXID.
 *
 * VM_SUM and VM_CPTIME are what 2.11BSD's vmstat reads through /dev/kmem as
 * `_sum' and `_cp_time'; FGX has no /dev/kmem yet (apple/fgx#538), so the vm
 * node serves them.  VM_LOADAVG and VM_SWAPMAP answer ENOTSUP: FGX keeps no
 * load average and has no swap.
 */
#ifndef _SYS_VMPARAM_H
#define _SYS_VMPARAM_H

#define	VM_METER	1		/* struct vmtotal */
#define	VM_LOADAVG	2		/* struct loadavg */
#define	VM_SWAPMAP	3		/* struct mapent _swapmap[] */
#define	VM_COREMAP	4		/* struct mapent _coremap[] */
#define	VM_SUM		5		/* FGX: struct vmsum */
#define	VM_CPTIME	6		/* FGX: long cp_time[CPUSTATES] */
#define	VM_MAXID	7		/* number of valid vm ids */

#endif /* _SYS_VMPARAM_H */
