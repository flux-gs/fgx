/* T5-C C4 batch 12: system(3) + time(2) in C — the FIRST pile-data users
 * (system's argv table + "/bin/sh"/"sh"/"-c" literals live in
 * lib/libc_c_data.s, PUT into every seg1 at a frozen offset).
 *
 * system returns the RAW WAIT STATUS, not the exit code, which is
 * 2.11BSD's contract and what apple/fgx#61 changed it to.  /bin/false
 * exits 1, so the status is 0x0100 and WEXITSTATUS(status) is 1.  This
 * fixture asserted `== 1` against the pre-#61 exit-code return and was
 * not updated with it; it went unnoticed for as long as it did because
 * the runtime oracle only runs when fcc's SOURCE changes, so a libc
 * contract change never triggers it (apple/fgx#87).
 *
 * The assertion is written through WEXITSTATUS rather than against the
 * literal 256 on purpose: the claim is "the child's exit code was 1",
 * and a raw comparison would also pass on a status that happened to
 * equal 256 for some other reason.
 *
 * time reads the IIgs RTC (MAME wall clock): > 2026-01-01 epoch,
 * monotonic across the two calls, and the NULL / store-through-pointer
 * paths agree.
 *
 * FGX-only (MAME oracle).  11+11+10+10 = 42. */
#include <sys/wait.h>

extern int  system();
extern long time();

int main(void)
{
    long t1, t2;
    int st;
    int r = 0;

    if (system("/bin/true") == 0)      r += 11;
    st = system("/bin/false");
    if (WIFEXITED(st) && WEXITSTATUS(st) == 1)
                                       r += 11;
    t1 = time((long *)0);
    if (t1 > 1767225600)               r += 10;   /* past 2026-01-01 */
    t2 = 0;
    time(&t2);
    if (t2 >= t1 && t2 - t1 < 30)      r += 10;   /* stored, sane, monotonic */
    return r;
}
