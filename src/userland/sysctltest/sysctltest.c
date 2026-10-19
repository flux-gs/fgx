/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* sysctltest -- exercise sysctl(2)'s securelevel leaf and its refusals, and
 * read kern.boottime and the vm node.  apple/fgx#410, apple/fgx#529.
 *
 * WHY A TEST BINARY AND NOT sysctl(8).  The securelevel fixture asserts the
 * EFFECT -- a multiuser fsck of the raw root opens read-only -- and that is the
 * blast radius.  What it cannot see is the syscall's own error paths, and one
 * of those is a security rule: if the level could be LOWERED by anything but
 * pid 1, the gate it arms could be switched off by whoever wanted to write the
 * disk.  A test whose failure would be silent is exactly the case that earns a
 * probe.
 *
 * NOT sysctl(8) because the tool's job is the whole MIB name table, and this
 * kernel serves one leaf; shipping the tool would mean shipping a table of
 * twenty-four names that answer ENOTSUP.  That arrives with the rest of the
 * MIB.
 *
 * Prints one PASS/FAIL line per case and exits 0 only if every one passed.
 */
#include <stdio.h>
#include <errno.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/vmparam.h>
#include <sys/vmmeter.h>
#include <sys/dk.h>

static int fails;
static struct vmsum vs;                 /* in the data bank */
static unsigned cmap[128];              /* {size, addr} pieces */

static void
report(name, ok)
char *name;
int   ok;
{
	printf("%s %s\n", ok ? "ok" : "FAIL", name);
	if (!ok)
		fails++;
}

main(argc, argv)
int argc;
char **argv;
{
	int name[3], level, before, r;
	struct timeval bt;
	struct vmtotal vt;              /* on the stack: oldp in bank 0 */
	long cp[CPUSTATES];
	long pages;
	int i;
	extern long time();
	unsigned len;

	/* READ THE LEVEL.  init raised it to 1 when /etc/rc returned, so a
	 * machine that has reached a shell is multiuser and secure. */
	name[0] = CTL_KERN;
	name[1] = KERN_SECURELVL;
	len = sizeof level;
	level = -99;
	r = sysctl(name, 2, &level, &len, (void *)0, 0);
	report("read", r == 0 && len == sizeof level);
	printf("securelevel=%d\n", level);
	report("multiuser-is-level-1", level == 1);
	before = level;

	/* AN UNKNOWN NAME IS ENOTSUP, which is upstream's `default:' answer
	 * (kern_sysctl.c's __sysctl, EOPNOTSUPP).  KERN_HOSTNAME exists in the
	 * numbering and is not served here, so it tests the LEAF arm; CTL_HW
	 * tests the top-level one. */
	name[1] = KERN_HOSTNAME;
	len = sizeof level;
	r = sysctl(name, 2, &level, &len, (void *)0, 0);
	report("unknown-leaf-enotsup", r == -1 && errno == ENOTSUP);
	name[0] = CTL_HW;
	name[1] = 1;
	len = sizeof level;
	r = sysctl(name, 2, &level, &len, (void *)0, 0);
	report("unknown-top-enotsup", r == -1 && errno == ENOTSUP);

	/* A NAME SHORTER THAN TWO COMPONENTS IS EINVAL -- "all top-level
	 * sysctl names are non-terminal". */
	name[0] = CTL_KERN;
	name[1] = KERN_SECURELVL;
	len = sizeof level;
	r = sysctl(name, 1, &level, &len, (void *)0, 0);
	report("namelen-1-einval", r == -1 && errno == EINVAL);

	/* LOWERING IS PID 1's ALONE (kern_sysctl.c:233).  This is not pid 1,
	 * so a write of 0 over a level of 1 must be refused -- and the level
	 * must be UNCHANGED afterwards, which is the half that matters: a rule
	 * that returns EPERM after writing would be no rule. */
	level = 0;
	r = sysctl(name, 2, (void *)0, (unsigned *)0, &level, sizeof level);
	report("lower-eperm", r == -1 && errno == EPERM);
	len = sizeof level;
	level = -99;
	(void)sysctl(name, 2, &level, &len, (void *)0, 0);
	report("lower-did-not-take", level == before);

	/* RAISING TO THE LEVEL ALREADY IN FORCE IS PERMITTED -- equal is not
	 * lower -- and is what makes init's raise idempotent. */
	level = before;
	r = sysctl(name, 2, (void *)0, (unsigned *)0, &level, sizeof level);
	report("raise-to-same-ok", r == 0);

	/* LEVEL 2 IS REFUSED rather than accepted and ignored: FGX does not
	 * enforce its extra clause (raw disks read-only whether mounted or
	 * not), and a settable value that means nothing reads as protection
	 * and is none.  sysctl(2) BUGS says so. */
	level = 2;
	r = sysctl(name, 2, (void *)0, (unsigned *)0, &level, sizeof level);
	report("level-2-einval", r == -1 && errno == EINVAL);

	/* A newlen THAT IS NOT AN int's IS EINVAL, and an oldp buffer too
	 * small is ENOMEM -- sysctl_int's own two tests. */
	level = 1;
	r = sysctl(name, 2, (void *)0, (unsigned *)0, &level, 1);
	report("newlen-1-einval", r == -1 && errno == EINVAL);
	len = 1;
	r = sysctl(name, 2, &level, &len, (void *)0, 0);
	report("oldlen-1-enomem", r == -1 && errno == ENOMEM);

	/* KERN.BOOTTIME, a read-only struct timeval set when the clock
	 * started: after the epoch and not after now. */
	name[0] = CTL_KERN;
	name[1] = KERN_BOOTTIME;
	len = sizeof bt;
	bt.tv_sec = 0L;
	r = sysctl(name, 2, &bt, &len, (void *)0, 0);
	report("boottime", r == 0 && len == sizeof bt && bt.tv_sec > 0L &&
	    bt.tv_sec <= time((long *)0));

	/* THE VM NODE copies each structure to oldp itself, in oldp's own
	 * bank -- vt is on the stack, vs in the data bank.  A size probe with
	 * no oldp, then a read. */
	name[0] = CTL_VM;
	name[1] = VM_METER;
	len = 0;
	r = sysctl(name, 2, (void *)0, &len, (void *)0, 0);
	report("vm-meter-size", r == 0 && len == sizeof vt);
	len = sizeof vt;
	vt.t_rq = -1;
	r = sysctl(name, 2, &vt, &len, (void *)0, 0);
	report("vm-meter", r == 0 && len == sizeof vt && vt.t_rq >= 1 &&
	    vt.t_sw == 0 && vt.t_vm > 0L && vt.t_avm >= vt.t_vm - vt.t_vmtxt &&
	    vt.t_rm > 0L && vt.t_free > 0L);
	len = 2;
	r = sysctl(name, 2, &vt, &len, (void *)0, 0);
	report("vm-meter-enomem", r == -1 && errno == ENOMEM);
	/* A new value is refused whatever it is (sysctl_rdstruct); two bytes,
	 * because libc refuses one past 8 bytes before the kernel sees it. */
	len = sizeof vt;
	r = sysctl(name, 2, &vt, &len, &i, sizeof i);
	report("vm-meter-eperm", r == -1 && errno == EPERM);

	name[1] = VM_SUM;
	len = sizeof vs;
	r = sysctl(name, 2, &vs, &len, (void *)0, 0);
	report("vm-sum", r == 0 && len == sizeof vs && vs.v_swtch > 0L &&
	    vs.v_syscall > 0L && vs.v_intr > 0L && vs.v_trap == 0L);

	name[1] = VM_CPTIME;
	len = sizeof cp;
	cp[CP_SYS] = 0L;
	cp[CP_NICE] = -1L;
	r = sysctl(name, 2, cp, &len, (void *)0, 0);
	report("vm-cptime", r == 0 && len == sizeof cp && cp[CP_SYS] > 0L &&
	    cp[CP_NICE] == 0L);

	/* The coremap and vm.meter's t_free are one map read twice: its free
	 * pages, a quarter of them in kb. */
	name[1] = VM_COREMAP;
	len = sizeof cmap;
	r = sysctl(name, 2, cmap, &len, (void *)0, 0);
	pages = 0L;
	for (i = 0; i < (int)(len / 4) && cmap[2 * i] != 0; i++)
		pages += cmap[2 * i];
	name[1] = VM_METER;
	len = sizeof vt;
	sysctl(name, 2, &vt, &len, (void *)0, 0);
	report("vm-coremap", r == 0 && pages > 0L && pages / 4 == vt.t_free);

	name[1] = VM_LOADAVG;
	len = sizeof cp;
	r = sysctl(name, 2, cp, &len, (void *)0, 0);
	report("vm-loadavg-enotsup", r == -1 && errno == ENOTSUP);
	name[1] = VM_METER;
	name[2] = 0;
	r = sysctl(name, 3, &vt, &len, (void *)0, 0);
	report("vm-namelen-3-enotdir", r == -1 && errno == ENOTDIR);

	printf("SYSCTLTEST %s\n", fails ? "FAILED" : "DONE");
	return (fails != 0);
}
