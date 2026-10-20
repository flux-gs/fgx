/* permtest -- does the filesystem actually REFUSE a non-root caller?
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD setthetime()
 * (vendor/2.11BSD/usr/sys/sys/kern_time.c:80) as the behaviour under test.
 *
 * UFS campaign 2.6, apple/fgx#320.  This exists because every other test on
 * this machine runs as root, and `ufs_access' returns on its super-user line
 * before the mode logic executes -- so a green suite says nothing at all about
 * whether permissions work.  Three defects found while 2.6 was landing all
 * failed SILENTLY OPEN, which is the direction a root-only test cannot see:
 *
 *   - kc_curuid answered 0 for every caller, because the kernel's direct page
 *     is per-task and the module shims borrowed a cached one.  Every check
 *     would have passed, forever, looking exactly like a working system.
 *   - an EACCES from the check was discarded by _Sys_Open, which read only the
 *     carry, and the legacy resolver then opened the file anyway.
 *   - vn_open's two VOP_ACCESS calls were absent entirely.
 *
 * So the whole point of this program is to BE a non-root caller.  It drops to
 * NOBODY and then asks four questions whose answers differ from each other --
 * a test where every answer is the same cannot tell a working check from an
 * absent one.
 *
 * THE FILE IS ROOT'S AND MODE 0644, so as NOBODY we are `other': read is
 * granted and write is not.  That asymmetry is the discrimination.  Expected,
 * and any other line is a finding:
 *
 *     PT r=0 w=-1 or=0 ow=-1
 *
 * r/w are access(2) for R_OK and W_OK; or/ow are open(2) for O_RDONLY and
 * O_WRONLY, normalised to 0 or -1.  A machine with the DP defect answers
 * `r=0 w=0 or=0 ow=0' -- every question yes -- and one with the discarded
 * refusal answers `ow=0' alone.
 *
 * ONE QUESTION THAT IS NOT THE FILESYSTEM'S, asked here because this is the
 * one program that is not root: setting the clock.  2.11BSD's setthetime()
 * refuses anyone but the super user (kern_time.c:80), so settimeofday(2) with
 * the time it already has must fail with EPERM (apple/fgx#446):
 *
 *     PT st=-1 e=1
 *
 * A kernel that asks nothing answers `st=0 e=0' -- and has rewritten the
 * battery clock -- and a libc that loses the errno answers `e=22'.  adjtime(2)
 * is the same question (2.11BSD kern_time.c:123), asked with a one-second
 * slew, and so is a write to machdep.adjkerntz (2.11BSD kern_sysctl.c:100):
 *
 *     PT adj=-1 e=1 kz=-1 e=1
 *
 * setuid IS IRREVERSIBLE HERE and is therefore the last thing before the
 * questions: there is no way back to root, so nothing after it can clean up.
 * The unlink at the top is what makes a re-run honest instead of testing
 * whatever the previous run left behind.
 */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <machine/cpu.h>

#define NOBODY  77
#define TESTF   "/tmp/permtest.dat"

main()
{
    int fd;
    int ar, aw, ord, owr, st, ste, adj, ade, kz, kze;
    struct timeval tv;

    (void)unlink(TESTF);
    fd = creat(TESTF, 0644);
    if (fd < 0) {
        printf("PT SETUP creat errno=%d\n", errno);
        exit(1);
    }
    (void)write(fd, "x", 1);
    (void)close(fd);

    if (setuid(NOBODY) != 0) {
        printf("PT SETUP setuid errno=%d\n", errno);
        exit(1);
    }
    if (getuid() != NOBODY) {
        /* Without this the whole run is vacuous: still root, every answer yes,
         * and the line below would read like a pass. */
        printf("PT SETUP uid=%d not %d\n", getuid(), NOBODY);
        exit(1);
    }

    ar  = access(TESTF, R_OK);
    aw  = access(TESTF, W_OK);
    ord = open(TESTF, O_RDONLY);
    owr = open(TESTF, O_WRONLY);
    if (ord >= 0)
        (void)close(ord);
    if (owr >= 0)
        (void)close(owr);

    (void)gettimeofday(&tv, (struct timezone *)0);
    errno = 0;
    st  = settimeofday(&tv, (struct timezone *)0);
    ste = (st < 0) ? errno : 0;

    printf("PT r=%d w=%d or=%d ow=%d\n",
           ar, aw, (ord >= 0) ? 0 : -1, (owr >= 0) ? 0 : -1);
    printf("PT st=%d e=%d\n", st, ste);
    {
        struct timeval d;

        d.tv_sec = 1;
        d.tv_usec = 0;
        errno = 0;
        adj = adjtime(&d, (struct timeval *)0);
        ade = (adj < 0) ? errno : 0;
    }
    {
        int mib[2], v;

        mib[0] = CTL_MACHDEP;
        mib[1] = CPU_ADJKERNTZ;
        v = 3600;
        errno = 0;
        kz = sysctl(mib, 2, (void *)0, (unsigned *)0, &v, sizeof(int));
        kze = (kz < 0) ? errno : 0;
    }
    printf("PT adj=%d e=%d kz=%d e=%d\n", adj, ade, kz, kze);

    if (ar == 0 && aw == -1 && ord >= 0 && owr < 0 &&
        st == -1 && ste == EPERM && adj == -1 && ade == EPERM &&
        kz == -1 && kze == EPERM)
        printf("PT VERDICT ENFORCED\n");
    else
        printf("PT VERDICT OPEN\n");
    exit(0);
}
