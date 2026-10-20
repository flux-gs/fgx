/* T5-C C4 batch 9: tty ioctls + signal registration in C.
 *
 * gtty(0) reads the console's sgtty modes into a bank-0 stack struct
 * (the DBR-swap through __syscall_db), stty writes the SAME modes back
 * (a no-op round-trip — harness tty state unchanged), ioctl pins the
 * bad-fd errno path.
 *
 * signal() RETURNS THE PREVIOUS HANDLER, which is the whole point of the
 * process disposition table apple/fgx#58 introduced.  This fixture used
 * to assert that BOTH calls returned 0, which can only hold if signal()
 * does not track dispositions at all -- the second call's previous
 * handler is the one the first call installed.  It was written against
 * that older behaviour and not updated with #58, and the runtime oracle
 * did not catch it because it only runs when fcc's SOURCE changes
 * (apple/fgx#87).
 *
 * So the handler half is now a ROUND TRIP: install, read the old one
 * back, put it back, and read it out again.  That is what discriminates
 * a real disposition table from one that returns a constant -- the
 * previous assertion passed on exactly the implementation the table
 * exists to replace.  The harness never sends ^C, so nothing fires;
 * §6A handler-body rules apply regardless.
 *
 * FGX-only (MAME oracle).  10+10+8+4+4+3+3 = 42. */
#include <signal.h>

char sgbuf[8];
int hits;

void onint(int sig)
{
    hits = hits + 1;     /* §6A: flag-set only */
}

int main(void)
{
    char *prev;
    int r = 0;

    if (gtty(0, sgbuf) == 0)                    r += 10;
    if (stty(0, sgbuf) == 0)                    r += 10;
    if (ioctl(99, 0x7408, sgbuf) == -1)         r += 8;

    /* Nothing was registered, so the previous disposition is SIG_DFL. */
    if (signal(SIGINT, (char *)onint) == 0)     r += 4;
    /* Now it is ours, and taking it back must hand it over rather than 0. */
    prev = signal(SIGINT, SIG_DFL);
    if (prev != 0)                              r += 4;
    /* Putting it back reports SIG_DFL again... */
    if (signal(SIGINT, prev) == 0)              r += 3;
    /* ...and the SAME pointer comes out, which is what proves the table
     * stores the handler rather than a flag saying one exists. */
    if (signal(SIGINT, SIG_DFL) == prev)        r += 3;
    return r;
}
