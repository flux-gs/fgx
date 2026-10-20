/* Supplementary groups, and the login name.
 *
 * FGX HAS EXACTLY ONE GROUP PER PROCESS and says so in sys/param.h: `NGROUPS 1'.
 * The kernel's u-area carries U_Rgid/U_Gid/U_Svgid and no array, so a process's
 * group set IS its effective gid -- these are not stubs that pretend, they are
 * the accurate answer for this system.  A real supplementary list would be a
 * kernel change (an NGROUPS array in the u-area and a SYS_GETGROUPS to read
 * it), not a libc one, which is why the shape is stated here rather than
 * silently returning zero groups.
 */
#include <sys/param.h>
#include <sys/types.h>
#include <errno.h>
#include <grp.h>
#include <pwd.h>
#include <string.h>
#include <unistd.h>

/* getgroups(2).  Answers 1 and the effective gid.  A caller asking for 0
 * entries is asking HOW MANY, which is 2.11BSD's convention (getgroups(2):
 * "if gidsetlen is zero, returns the number of groups"). */
int getgroups(int gidsetlen, gid_t *gidset)
{
    if (gidsetlen == 0)
        return 1;
    if (gidsetlen < 1 || gidset == (gid_t *)0) {
        errno = EINVAL;
        return -1;
    }
    gidset[0] = (gid_t)getegid();
    return 1;
}

/* getgrouplist(3).  The list a named user would get: their base gid, and
 * nothing else here.  *ngroups is in/out as upstream has it. */
int getgrouplist(char *name, int basegid, gid_t *groups, int *ngroups)
{
    if (ngroups == (int *)0)
        return -1;
    if (*ngroups < 1) {
        *ngroups = 1;
        return -1;                      /* upstream: -1 means it did not fit */
    }
    groups[0] = (gid_t)basegid;
    *ngroups  = 1;
    return 0;
}

/* initgroups(3).  With one group this is setgid, and su(1) calls it for
 * exactly that effect.  It is kept as its own name because the CALLER's
 * meaning is "install this user's groups", and that is what would change if
 * FGX ever grew a list. */
int initgroups(char *name, int basegid)
{
    return setgid(basegid);
}
