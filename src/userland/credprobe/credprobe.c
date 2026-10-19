/* FGX-Origin: original -- FGX code.  It CITES BSD (2.11BSD and 4.3BSD-Reno, for
 * the semantics it asserts) but contains none of it; registering it would claim
 * the Regents' copyright over work they did not write.
 */
/* credprobe - P2 gate for the credentials campaign, and the test that finally
 * makes P1's fork-inheritance provable from userland.
 *
 * Until setuid existed, inheritance could only be demonstrated by poking a
 * sentinel into init's u-area and rebuilding the kernel — a manual one-shot,
 * not a standing gate.  With setuid(2) a test can establish a non-root parent
 * itself, so the whole chain becomes assertable in one program.
 *
 * WHAT IS CHECKED
 *   1. getuid/getgid return real ids and geteuid/getegid the EFFECTIVE ones.
 *      They agree at start (nothing can make them differ before a setuid).
 *   2. seteuid(N) as root moves ONLY the effective uid.  This is the first
 *      point where real != effective, so it also proves geteuid is no longer
 *      the "return getuid()" delegation it was before P2 — the kernel now
 *      answers both from one syscall (A = real, Y = effective, as V7 does).
 *   3. Dropping privilege with setuid(N) as root moves all three (real,
 *      effective, saved).
 *   4. Having dropped, setuid back to 0 is REFUSED with EPERM — 0 is now
 *      neither our real nor our saved-set id.  This is the check that proves
 *      the permission rule is enforced rather than assumed; without it every
 *      other assertion here would pass on a kernel that let anyone be root.
 *   5. setuid to our own real id is permitted (the non-root allowed case).
 *   6. fork(): the child reports the SAME non-root ids.  THIS IS P1'S GATE —
 *      it is only reachable because steps 3-5 established a non-root parent.
 *
 * The uid used is arbitrary but non-zero and not a plausible zero-value from a
 * broken read (77), so a kernel that silently returned 0 everywhere would fail
 * loudly rather than look like a successful drop to root.
 *
 * Prints "credprobe: PASS" or "credprobe: FAIL <step> <detail>"; exits 0/1. */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/stat.h>          /* umask */
#include <sys/resource.h>     /* getrlimit/setrlimit, RLIM_* */

#define TESTUID 77
#define TESTGID 88
/* 0710 rather than something inside 0777: bit 0400 is fine either way, but the
 * 04000/02000/01000 range is what the retired libc static silently dropped.
 * A mask that only used 0777 bits could not tell the two maskings apart. */
#define TESTMASK 04710
/* A limit value that is not a plausible zero, a plausible infinity, or a
 * plausible byte -- so a wrong read is obvious rather than lucky. */
#define TESTLIM  1234567L
#define EPERM   1

static int fail(step, a, b)
char *step;
int a, b;
{
	printf("credprobe: FAIL %s (got %d, want %d)\n", step, a, b);
	exit(1);
}

main(argc, argv)
int argc;
char **argv;
{
	int r, pid, st, m;
	struct rlimit rl;

	/* 1. start as root, real == effective */
	if (getuid()  != 0) fail("start-ruid",  getuid(),  0);
	if (geteuid() != 0) fail("start-euid",  geteuid(), 0);
	if (getgid()  != 0) fail("start-rgid",  getgid(),  0);
	if (getegid() != 0) fail("start-egid",  getegid(), 0);

	/* 2. seteuid moves the effective id only -- real must stay 0 */
	if (seteuid(TESTUID) != 0) fail("seteuid-rc", -1, 0);
	if (geteuid() != TESTUID) fail("seteuid-euid", geteuid(), TESTUID);
	if (getuid()  != 0)       fail("seteuid-ruid", getuid(),  0);

	/* restore effective privilege: still permitted, real id is still 0 */
	if (seteuid(0) != 0)  fail("seteuid-back-rc", -1, 0);
	if (geteuid() != 0)   fail("seteuid-back", geteuid(), 0);

	/* 3. full drop: real, effective and saved all move */
	if (setgid(TESTGID) != 0) fail("setgid-rc", -1, 0);
	if (setuid(TESTUID) != 0) fail("setuid-rc", -1, 0);
	if (getuid()  != TESTUID) fail("drop-ruid",  getuid(),  TESTUID);
	if (geteuid() != TESTUID) fail("drop-euid",  geteuid(), TESTUID);
	if (getgid()  != TESTGID) fail("drop-rgid",  getgid(),  TESTGID);
	if (getegid() != TESTGID) fail("drop-egid",  getegid(), TESTGID);

	/* 4. THE enforcement check: root is no longer reachable. */
	r = setuid(0);
	if (r != -1)          fail("regain-allowed", r, -1);
	if (errno != EPERM)   fail("regain-errno", errno, EPERM);
	if (getuid() != TESTUID) fail("regain-ruid-moved", getuid(), TESTUID);

	/* 5. setting to our own real id is the permitted non-root case */
	if (setuid(TESTUID) != 0) fail("self-setuid", -1, 0);

	/* 7. umask(2) reports the PREVIOUS mask and installs the new one.
	 *
	 * The default is 022 and comes from the kernel now, not from a libc
	 * static -- Task_AllocUarea installs it, so a task that were created
	 * without inheriting would still get 022 rather than 0.  0 is the
	 * dangerous value here: it masks nothing.
	 *
	 * TESTMASK names bits 0777 does not cover, because the old libc static
	 * masked to 0777 and would silently drop them; the kernel masks to
	 * 07777 as both BSDs do. */
	m = umask(TESTMASK);
	if (m != 022) fail("umask-default", m, 022);
	m = umask(TESTMASK);            /* set-and-read-back, sh's own idiom */
	if (m != TESTMASK) fail("umask-readback", m, TESTMASK);

	/* 8. Resource limits live in the kernel now, not in a libc constant.
	 *
	 * EVERY INDEX MUST ANSWER.  The kernel's U_RLIM_NLIMITS and the header's
	 * RLIM_NLIMITS are two copies of one count, and this loop is what stops
	 * them drifting: a kernel array shorter than the header would refuse the
	 * top indices with EINVAL while honouring the rest, which is worse than
	 * either number on its own.
	 *
	 * They start unlimited, as Reno's init_main.c sets them before vminit()
	 * narrows the VM ones -- FGX has no VM, so they all stay that way. */
	for (r = 0; r < RLIM_NLIMITS; r++) {
		if (getrlimit(r, &rl) != 0) fail("getrlimit", r, 0);
		if (rl.rlim_cur != RLIM_INFINITY || rl.rlim_max != RLIM_INFINITY)
			fail("rlimit-default", r, 0);
	}

	/* Set one and read it back.  The old libc stub reported a CONSTANT, so
	 * it passed the loop above and could never pass this. */
	rl.rlim_cur = TESTLIM;
	rl.rlim_max = RLIM_INFINITY;
	if (setrlimit(RLIMIT_FSIZE, &rl) != 0) fail("setrlimit", -1, 0);
	rl.rlim_cur = 0; rl.rlim_max = 0;
	if (getrlimit(RLIMIT_FSIZE, &rl) != 0) fail("getrlimit-back", -1, 0);
	if (rl.rlim_cur != TESTLIM) fail("rlimit-readback", (int)rl.rlim_cur, TESTLIM);
	if (rl.rlim_max != RLIM_INFINITY) fail("rlimit-max", -1, 0);

	/* A limit this build has no slot for is REFUSED, not wrapped onto a
	 * neighbour -- the check that keeps an out-of-range index from reading
	 * whatever follows the array. */
	if (getrlimit(RLIM_NLIMITS, &rl) != -1) fail("rlimit-range", -1, 0);

	/* Setting one must not disturb another.  An index calculation that
	 * ignored the resource would pass everything above this. */
	if (getrlimit(RLIMIT_CPU, &rl) != 0) fail("getrlimit-cpu", -1, 0);
	if (rl.rlim_cur != RLIM_INFINITY) fail("rlimit-crosstalk", -1, 0);

	/* 6. P1's gate: a forked child inherits the non-root credentials --
	 *    AND, since UFS 1.2, the rest of the u-area with them.
	 *
	 * The mask is the discriminating half now.  Credentials inherited even
	 * under the old copy-the-exceptions policy, because they were the one
	 * block on the list; the mask is the first field to rely on the u-area
	 * being copied WHOLE.  A child reporting 022 here would mean it got a
	 * freshly-defaulted u-area instead of its parent's. */
	pid = fork();
	if (pid < 0)
		fail("fork", pid, 0);
	if (pid == 0) {
		/* child: exit 0 only if every id survived the fork */
		if (getuid() != TESTUID || geteuid() != TESTUID ||
		    getgid() != TESTGID || getegid() != TESTGID)
			_exit(1);
		/* ...and the mask with them.  umask(0) both reads it and
		 * proves the child has its OWN copy: the parent checks its
		 * mask again after the wait, and must still see TESTMASK. */
		if (umask(0) != TESTMASK)
			_exit(2);
		/* ...and the limit, which is 72 bytes further into the u-area
		 * than the mask -- so a copy that stops short shows here and
		 * not in the mask. */
		if (getrlimit(RLIMIT_FSIZE, &rl) != 0)
			_exit(3);
		if (rl.rlim_cur != TESTLIM)
			_exit(4);
		_exit(0);
	}
	if (wait(&st) < 0) fail("wait", -1, 0);
	if (st != 0) fail("child-creds", st, 0);

	/* The child's umask(0) must not have reached the parent's u-area: two
	 * processes, two copies.  Without this the child's read above would
	 * pass just as well on a kernel that SHARED one u-area. */
	m = umask(022);
	if (m != TESTMASK) fail("umask-parent-clobbered", m, TESTMASK);

	printf("credprobe: PASS uid=%d gid=%d\n", getuid(), getgid());
	exit(0);
}
