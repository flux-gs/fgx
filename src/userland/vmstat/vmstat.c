/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD vmstat(1)
 *   Ported from vmstat(1), 2.11BSD (vmstat.c 5.4.2 1997/3/28,
 *   vendor/2.11BSD/usr/ucb/vmstat.c).
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* vmstat - report virtual memory statistics.
 *
 * WHERE THE NUMBERS COME FROM.  Upstream looks every counter up in /vmunix
 * with nlist(3) and reads it from /dev/kmem.  FGX has neither yet
 * (apple/fgx#538), so each read is a sysctl(3) leaf instead -- one leaf per
 * kernel variable, the same structure upstream reads:
 *
 *	_cp_time	vm.cp_time	long cp_time[CPUSTATES]
 *	_sum		vm.sum		struct vmsum
 *	_total		vm.meter	struct vmtotal
 *	_boottime	kern.boottime	struct timeval
 *	_hz, _phz	kern.clockrate	struct clockinfo's hz and profhz
 *
 * The body is upstream's pdp11 path.  What changes, and why:
 *
 *  - There is no `_rate'.  The kernel keeps only the running sums, so an
 *    interval line takes `sum' less the previous `sum' where upstream reads
 *    the five-second averages.  `rate' is a struct vmsum, so a large count
 *    is not cut to 16 bits on its way to the division.
 *  - No disk, text-cache, fork or name-cache statistics are kept: dk_ndrive
 *    is 0 and the disk columns are absent (upstream refuses to run), the
 *    ti/tc/fr/fc columns print 0, -s omits its name-lookup and xalloc lines,
 *    and -f says the statistics are not kept.  -z needs to write /dev/kmem.
 *  - A click is the coremap's 256-byte page (<machine/machparam.h>), and
 *    `fre' is vm.meter's t_free, the kernel's free pages; upstream reads
 *    `_freemem' for the same figure.
 *  - The SIGCONT handler only asks for a header; upstream prints it from
 *    the handler, which an FGX handler must not do.
 *  - -m, -c and -g are FGX's: the kernel heap's tables and the Memory
 *    Manager's, through meminfo(2).  NetBSD's vmstat names its kernel
 *    malloc report -m.
 */
#include <stdio.h>
#include <ctype.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <sys/vmparam.h>
#include <sys/vmmeter.h>
#include <sys/dk.h>
#include <machine/machparam.h>
#include <fgx.h>

char	**dr_name;
int	*dr_select;
int	dk_ndrive;
int	ndrives = 0;
long	pfree;
int	flag29;
double	stat1();
int	hz;
int	phz;
int	HZ;

#define	INTS(x)	((x) - (hz + phz) < 0 ? 0 : (x) - (hz + phz))

struct {
	int	busy;
	long	time[CPUSTATES];
	long	*xfer;
	struct	vmsum Rate;
	struct	vmtotal	Total;
	struct	vmsum Sum;
} s, s1;
#define	rate		s.Rate
#define	total		s.Total
#define	sum		s.Sum

struct	vmsum osum;
double	etime;
time_t	now, boottime;
int	printhdr();
int	contin();
int	lines = 1;

static void	getleaf();
static void	dosum();
static void	dotimes();
static void	doforkst();
static void	dointr();
static void	stats();
static int	domem();
static int	dochunks();

main(argc, argv)
	int argc;
	char **argv;
{
	register i;
	int iter, iflag = 0, mflag = 0;
	long nintv, t;
	struct timeval bt;
	struct clockinfo ci;

	iter = 0;
	argc--, argv++;
	while (argc>0 && argv[0][0]=='-') {
		char *cp = *argv++;
		argc--;
		while (*++cp) switch (*cp) {

		case 't':
			dotimes();
			exit(0);

		case 'z':
			fprintf(stderr, "vmstat: -z needs /dev/kmem\n");
			exit(1);

		case 'f':
			doforkst();
			exit(1);

		case 's':
			dosum();
			exit(0);

		case 'i':
			iflag++;
			break;

		case 'p':
			flag29++;
			break;

		case 'm':
			exit(domem());

		case 'c':
			exit(dochunks(2));

		case 'g':
			exit(dochunks(4));

		default:
			fprintf(stderr,
			    "usage: vmstat [ -fsip ] [ interval ] [ count]\n");
			fprintf(stderr,
			    "       vmstat -m | -c | -g\n");
			exit(1);
		}
	}
	getleaf(CTL_KERN, KERN_BOOTTIME, &bt, sizeof bt);
	boottime = bt.tv_sec;
	getleaf(CTL_KERN, KERN_CLOCKRATE, &ci, sizeof ci);
	hz = ci.hz;
	phz = ci.profhz;
	HZ = phz ? phz : hz;
	dk_ndrive = 0;			/* no disk statistics are kept */
	if (argc > 1)
		iter = atoi(argv[1]);
	signal(SIGCONT, contin);
	time(&now);
	nintv = now - boottime;
	if (nintv <= 0 || nintv > 60L*60L*24L*365L*10L) {
		fprintf(stderr,
		    "Time makes no sense... namelist must be wrong.\n");
		exit(1);
	}
	if (iflag) {
		dointr(nintv);
		exit(0);
	}
loop:
	if (--lines == 0)
		printhdr();
	getleaf(CTL_VM, VM_CPTIME, s.time, sizeof s.time);
	osum = sum;
	getleaf(CTL_VM, VM_SUM, &sum, sizeof sum);
	if (nintv != 1)
		rate = sum;		/* the first line: since boot */
	else {
		long *rp, *np, *op;

		rp = &rate.v_swtch;
		np = &sum.v_swtch;
		op = &osum.v_swtch;
		for (i = 0; i < sizeof sum / sizeof (long); i++)
			*rp++ = *np++ - *op++;
	}
	getleaf(CTL_VM, VM_METER, &total, sizeof total);
	pfree = total.t_free * 4;	/* kb to clicks */
	etime = 0;
	for (i=0; i < CPUSTATES; i++) {
		t = s.time[i];
		s.time[i] -= s1.time[i];
		s1.time[i] = t;
		etime += s.time[i];
	}
	if(etime == 0.)
		etime = 1.;
	printf("%2d%2d%2d", total.t_rq, total.t_dw, total.t_sw);
	printf("%6D", ctok(total.t_avm));
	if (flag29)
		printf("%4D",
		    total.t_avm ? (total.t_avmtxt * 100) / total.t_avm : 0);
	printf("%6D", ctok(pfree));
	if (flag29)
		printf("%4D%3D  ", rate.v_swpin / nintv, rate.v_swpout / nintv);
	else {
		printf("%4D%3D", 0L, 0L);	/* no text statistics are kept */
		printf("%4D%4D", rate.v_pgin / nintv, rate.v_pgout / nintv);
		printf("%4D%4D", 0L, 0L);
		printf("%4D", rate.v_ovly / nintv);
	}
	etime /= (float)HZ;
	for (i = 0; i < dk_ndrive; i++)
		if (dr_select[i])
			stats(i);
	if (flag29)
		printf("%4D%4D%4D%4D%4D%4D",
		    rate.v_pdma / nintv, INTS(rate.v_intr / nintv),
		    rate.v_syscall / nintv, rate.v_trap / nintv,
		    rate.v_ovly / nintv, rate.v_swtch / nintv);
	else
	printf("%4D%4D%4D", INTS(rate.v_intr/nintv), rate.v_syscall/nintv,
	    rate.v_swtch/nintv);
	for(i=0; i<CPUSTATES; i++) {
		float f = stat1(i);
		if (!flag29)
		if (i == 0) {		/* US+NI */
			i++;
			f += stat1(i);
		}
		printf("%3.0f", f);
	}
	printf("\n");
	fflush(stdout);
	nintv = 1;
	if (--iter &&argc > 0) {
		sleep(atoi(argv[0]));
		goto loop;
	}
	exit(0);
}

/* One kernel variable, as upstream's lseek()+read() of /dev/kmem. */
static void
getleaf(top, leaf, p, len)
	int top, leaf;
	char *p;
	unsigned len;
{
	int name[2];
	unsigned got;

	name[0] = top;
	name[1] = leaf;
	got = len;
	if (sysctl(name, 2, p, &got, (void *)0, 0) < 0 || got != len) {
		fprintf(stderr, "vmstat: cannot read %d.%d\n", top, leaf);
		exit(1);
	}
}

printhdr()
{
	register int i, j;

	if (flag29)
	    printf(" procs       memory      swap      ");
	else
	    printf(" procs     memory              page           ");
	i = (ndrives * 3 - 6) / 2;
	if (i < 0)
		i = 0;
	for (j = 0; j < i; j++)
		putchar(' ');
	printf("faults");
	i = ndrives * 3 - 6 - i;
	for (j = 0; j < i; j++)
		putchar(' ');
	if (flag29) {
		printf("              cpu\n");
		printf(" r b w   avm  tx   fre   i  o   ");
	}
	else {
		printf("               cpu\n");
		printf(" r b w   avm   fre  ti tc  pi  po  fr  fc  ov ");
	}
	for (i = 0; i < dk_ndrive; i++)
		if (dr_select[i])
			printf("%c%c ", dr_name[i][0], dr_name[i][2]);
	if (flag29)
	    printf(" pd  in  sy  tr  ov  cs us ni sy id\n");
	else
	printf(" in  sy  cs us sy id\n");
	lines = 19;
}

/* SIGCONT.  Upstream's handler is printhdr itself; an FGX handler sets a flag
 * and returns (userland-abi.md 6A), so the header comes at the next line. */
contin()
{
	lines = 1;
}

static void
dotimes()
{
	printf("page in/out/reclamation is not applicable to 2.11BSD\n");
}

static void
dosum()
{
	getleaf(CTL_VM, VM_SUM, &sum, sizeof sum);
	printf("%9D swap ins\n", sum.v_swpin);
	printf("%9D swap outs\n", sum.v_swpout);
	printf("%9D pages swapped in\n", sum.v_pswpin / CLSIZE);
	printf("%9D pages swapped out\n", sum.v_pswpout / CLSIZE);
	printf("%9D page ins\n", sum.v_pgin);
	printf("%9D page outs\n", sum.v_pgout);
	printf("%9D cpu context switches\n", sum.v_swtch);
	printf("%9D device interrupts\n", sum.v_intr);
	printf("%9D software interrupts\n", sum.v_soft);
	printf("%9D pseudo-dma dz interrupts\n", sum.v_pdma);
	printf("%9D traps\n", sum.v_trap);
	printf("%9D overlay emts\n", sum.v_ovly);
	printf("%9D system calls\n", sum.v_syscall);
	/* upstream's name-lookup and xalloc lines: neither is kept */
}

static void
doforkst()
{
	fprintf(stderr, "vmstat: fork statistics are not kept\n");
}

static void
stats(dn)
{

	if (dn >= dk_ndrive) {
		printf("  0");
		return;
	}
	printf("%3.0f", s.xfer[dn]/etime);
}

double
stat1(row)
{
	double t;
	register i;

	t = 0;
	for(i=0; i<CPUSTATES; i++)
		t += s.time[i];
	if(t == 0.)
		t = 1.;
	return(s.time[row]*100./t);
}

static void
dointr(nintv)
	long nintv;
{
	printf("Device interrupt statistics are not applicable to 2.11BSD\n");
}

/*
 * FGX's kernel memory tables, through meminfo(2).  All records are
 * little-endian, decoded with byte math (no struct overlays).
 */
#define BUFMAX 2048

static char buf[BUFMAX];

static char *tname[8] = {
	"FREE", "TEMP", "SHEL", "FONT", "FS", "CONS", "KERN", "ANON"
};

static int
w(off)
	int	off;
{
	return (buf[off] & 0xFF) | ((buf[off + 1] & 0xFF) << 8);
}

/* Kilobytes of the 32-bit little-endian long at buf[off] -- int math only
 * (hi16*64 + lo16/1024; tops out at 64MB-1K, far past any IIgs). */
static unsigned
kb(off)
	int	off;
{
	return ((unsigned)w(off + 2) << 6) + (((unsigned)w(off)) >> 10);
}

/* -m: the kernel heap's types and arenas, the Memory Manager's block table
 * and its own totals. */
static int
domem()
{
	int n, i, off, kind;
	char name[9];

	/* subcmd 0: 8 x 16 B { name[8], inuse, count, calls, peak } */
	n = meminfo(0, buf, BUFMAX);
	if (n < 0) return 1;
	printf("TYPE         INUSE  COUNT  CALLS   PEAK\n");
	for (off = 0; off + 16 <= n; off += 16) {
		for (i = 0; i < 8; i++)
			name[i] = buf[off + i];
		name[8] = 0;
		for (i = 7; i > 0 && name[i] == ' '; i--)
			name[i] = 0;
		printf("  %-8s%9u%7d%7d%7u\n", name,
		       (unsigned)w(off + 8), w(off + 10), w(off + 12),
		       (unsigned)w(off + 14));
	}

	/* subcmd 1: ArenaCount x 16 B Kmem_Arenas records */
	n = meminfo(1, buf, BUFMAX);
	if (n < 0) return 1;
	printf("\nARENA  BANK  TOTAL  USED   PEAK   ALLOC  FREE\n");
	for (off = 0, i = 0; off + 16 <= n; off += 16, i++)
		printf("%5d  $%02X  %5u  %5u  %5u  %5d  %5d\n",
		       i, buf[off] & 0xFF,
		       (unsigned)w(off + 6), (unsigned)w(off + 8),
		       (unsigned)w(off + 10), w(off + 12), w(off + 14));

	/* subcmd 5: the Memory Manager block table, every live claim the
	 * kernel manages: 8 B rows {base, count, kind, pad, handle32}; kind 0
	 * is a free row. */
	n = meminfo(5, buf, BUFMAX);
	if (n >= 8) {
		printf("\nMMBLK  BASE  BANKS  KIND        HANDLE\n");
		for (off = 0, i = 0; off + 8 <= n; off += 8, i++) {
			kind = buf[off + 2] & 0xFF;
			if (kind == 0)
				continue;
			printf("  %2d   $%02X   %4d   ", i,
			       buf[off] & 0xFF, buf[off + 1] & 0xFF);
			if (kind == 1)      printf("boot-claim");
			else if (kind == 2) printf("arena-grow");
			else if (kind == 3) printf("user-grant");
			else if (kind == 4) printf("big-alloc ");
			else                printf("kind=%d    ", kind);
			if (w(off + 4) == 0 && w(off + 6) == 0)
				printf("  -\n");
			else
				printf("  $%04X%04X\n",
				       (unsigned)w(off + 6), (unsigned)w(off + 4));
		}
	}

	/* subcmd 6: the Memory Manager's TotalMem/FreeMem/MaxBlock longs.
	 * TOTAL-FREE is in use machine-wide; FREE is what NewHandle can
	 * still give. */
	n = meminfo(6, buf, BUFMAX);
	if (n >= 12)
		printf("MM     TOTAL=%uK ($%04X%04X)  FREE=%uK ($%04X%04X)  MAXBLK=%uK\n",
		       kb(0), (unsigned)w(2), (unsigned)w(0),
		       kb(4), (unsigned)w(6), (unsigned)w(4),
		       kb(8));
	else
		printf("MM     (meminfo 6 -> %d)\n", n);
	return 0;
}

/* -c (subcmd 2, every chunk) and -g (subcmd 4, corrupt ones only): 8 B
 * { bank, flags, off, size, type }; flags bit0 = free, bit1 = guard
 * corrupt. */
static int
dochunks(subcmd)
	int	subcmd;
{
	int n, off, fl, ty;

	n = meminfo(subcmd, buf, BUFMAX);
	if (n < 0) return 1;
	if (subcmd == 4) {
		printf("CORRUPT CHUNKS (guard byte != $A5):\n");
		if (n == 0) {
			printf("  (none)\n");
			return 0;
		}
	} else
		printf("CHUNK         STATE  SIZE   TYPE   GUARD\n");
	for (off = 0; off + 8 <= n; off += 8) {
		fl = buf[off + 1] & 0xFF;
		ty = w(off + 6) & 7;
		printf("    $%02X:%04X  %-4s %6u  %s",
		       buf[off] & 0xFF, (unsigned)w(off + 2),
		       (fl & 1) ? "free" : "used",
		       (unsigned)w(off + 4), tname[ty]);
		if (!(fl & 1))
			printf("  %s", (fl & 2) ? "BAD" : "ok");
		printf("\n");
	}
	return 0;
}
