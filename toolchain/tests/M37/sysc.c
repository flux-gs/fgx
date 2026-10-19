/* T5-C C1: the __syscall builtin family — inline JSL SYS_TRAMP / DFB n.
 *
 * Exercises all four builtins against two syscalls with fully deterministic
 * behavior on the harness disk:
 *   __syscall(24, 0, 0, 0)      SYS_GETUID: A = real uid, C=1 always
 *   __syscall_c()               carry latch (raw kernel sense)
 *   __syscall_y()               Y latch -- getuid's EFFECTIVE uid, so the
 *                               value is ASSERTED and not merely linked
 *   __syscall_db(5, bank, ...)  SYS_OPEN("/NOPExyz"): buffer-bank ABI walk;
 *                               path cannot exist -> C=0 (fail)
 *
 * getuid(2) IS THE ONE THAT ANSWERS THE SAME WAY EVERY TIME.  _Sys_GetUid
 * (src/kernel/syscall.s) reads u_ruid into A and u_uid into Y and cannot fail;
 * its no-uarea arm answers 0/0 as well, so both halves are 0 for every process
 * on this disk.  Returning the real id in A and the effective in Y is
 * 2.11BSD's getuid(2)/geteuid(2) pair answered by one call, which is what
 * gives the Y latch a value worth checking.
 *
 * The bank/offset split of the path pointer is the exact idiom the C4 shim
 * conversions will use: (unsigned long)p >> 16 / low word.
 *
 * NOT clang-cross-checked: the builtin is FGX-only by construction; the
 * MAME calibration is the oracle.  Expected exit: 8 + 20 + 2 + 12 = 42. */
static char path[] = "/NOPExyz";

int main(void)
{
    int r = 0;
    unsigned long lp;
    unsigned bank, off;
    char *p = path;

    lp   = (unsigned long)p;
    bank = (unsigned)(lp >> 16);
    off  = (unsigned)lp;

    if (__syscall(24, 0, 0, 0) == 0) r += 8;    /* real uid */
    if (__syscall_c() == 1)          r += 20;   /* SYS_GETUID: C=1 always */
    if (__syscall_y() == 0)          r += 2;    /* effective uid */
    __syscall_db(5, bank, off, 0, 0);           /* open must fail */
    if (__syscall_c() == 0)          r += 12;
    return r;
}
