/* FGX-Origin: original -- FGX code.  Nothing here derives from the Regents'
 * work.
 */
/* kern_time.c -- what a module's kernel C calls a clock.  apple/fgx#167.
 *
 * The clock is the kernel's (src/kernel/tty/kern_time.c): UTC, advanced by
 * the heartbeat and set at boot, by settimeofday and by adjtime.  A module
 * reaches it through KSVC_TIME, which is 2.11BSD's `time.tv_sec' -- a memory
 * load there, one service call here.
 *
 *   kern_time()   UTC.  UFS stamps with it, as 2.11BSD's does: ufs_itimes and
 *                 ufs_sbupdate (2.11BSD ufs_alloc.c:78-79's `fs->fs_time =
 *                 time.tv_sec').
 *   kern_ltime()  local time: UTC less the offset resettodr writes the battery
 *                 clock with.  ProDOS stamps with it, because GS/OS reads a
 *                 ProDOS date as local -- the case FreeBSD's adjkerntz(8) page
 *                 names, "proper timestamps for local filesystems".
 *
 * EVERY MODULE THAT STAMPS PUTS ITS OWN COPY: ufs.mod and prodosw.mod, which
 * have no import path between them.  Both read the one kernel clock, so they
 * agree.
 */

extern long kc_time();              /* kc_sys.s: KSVC_TIME, UTC */
extern long kc_ltime();             /* ...and local time */

/* kern_time -- seconds since the epoch, UTC.  As 2.11BSD's ITIMES uses
 * `time': as it stands, so a settimeofday that steps the clock back gives
 * later files earlier times, as it does upstream. */
long
kern_time()
{
    return (kc_time());
}

/* kern_ltime -- seconds since the epoch in local time, for ProDOS. */
long
kern_ltime()
{
    return (kc_ltime());
}
