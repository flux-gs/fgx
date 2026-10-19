/* M22: the timed-read primitives pollkey()/ticks()/yield() (SYS_POLLKEY /
 * SYS_TICKS / SYS_YIELD).  Guards the fcc libc-table registration + the
 * c_pollkey/c_ticks/c_yield shims — elvis unix.c's FGX ttyread() polls these.
 * Headless: after draining any startup keystrokes the ring is empty, so
 * pollkey() returns -1; yield() returns 0; ticks() is monotonic across a yield.
 * Returns 42. */
int pollkey();
int ticks();
int yield();

int main()
{
    int t0, d;

    /* drain any startup keystrokes (e.g. the autoboot line's Enter) */
    while (pollkey() >= 0)
        ;

    if (yield() != 0)    return 1;   /* yield() returns 0 */
    if (pollkey() >= 0)  return 2;   /* ring now empty -> -1 */

    t0 = ticks();
    yield();
    d = ticks() - t0;                /* elapsed >= 0 (monotonic 60 Hz) */
    if (d < 0)           return 3;

    return 42;
}
