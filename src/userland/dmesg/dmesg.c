/* dmesg(1) — print the kernel log ring.  FGX-native C rewrite (H1
 * roadmap), replacing the hand-asm dmesg.s.  The historical Unix dmesg
 * grovels the kernel msgbuf through /dev/kmem + a symbol table — FGX
 * exposes the ring directly via SYS_DMESG, so this is a two-call tool:
 * fetch, write.  No flags (the incremental '-' mode would need a read
 * cursor the ring doesn't keep).
 */
#include <stdio.h>

/* MUST BE >= KMEM_LOGBUF_SIZE (include/memmap.s).  _Sys_Dmesg copies
 * oldest->newest and stops at this limit, so a buffer smaller than the ring
 * drops the NEWEST lines -- silently, and in the one tool whose whole job is
 * showing them.  It was 2048 against a 1792-byte ring, which was fine until
 * the ring grew to 4096 for the third console (apple/fgx#43).
 */
#define DM_MAX 4096

static char buf[DM_MAX];

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int n;

	n = dmesg(buf, DM_MAX);
	if (n > 0)
		write(1, buf, n);
	return 0;
}
