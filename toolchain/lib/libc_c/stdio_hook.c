/* ---- the exit-time stdio flush hook (apple/fgx#373) -----------------------
 * crt0 calls __lc_stdio_flush when main RETURNS, because that path never
 * reaches exit() and most tools that print return from main rather than
 * calling it.  That reference is unconditional, so whatever member holds the
 * flush is linked into EVERY binary.
 *
 * Calling stdio's flush by name cost a program that prints nothing the whole
 * buffered-stdio subtree: `true' went from 19,642 to 38,794 bytes.  So the
 * entry point lives HERE, in a member with no imports of its own, and
 * _flsbuf (flsbuf.c) names _cleanup here the first time a stream is written.
 * A binary that never prints links this member and nothing else -- about
 * thirty bytes.
 *
 * The pointer is called by NAME rather than through (*p)(): that is the form
 * fcc supports, and the one qsort's comparator already uses. */

void (*_lc_flush_hook)();

void __lc_stdio_flush()
{
    if (_lc_flush_hook)
        _lc_flush_hook();
}

/* exit(2) AND _exit(2) LIVE HERE, not beside putchar.  Archive members are
 * whole files, so a program that only calls exit() would otherwise pull
 * all of stdio -- the _iob table, _filbuf, _flsbuf and the printf engine.  The M37 vreclaim fixture prints nothing, calls exit, and
 * overflowed its 64 KB seg0 on exactly that.
 *
 * Their only libc dependency is the flush above, and it is a no-op until some
 * program actually buffers. */

void exit(int code)
{
    /* Held output goes out FIRST.  Without this a buffered program's last
     * partial line dies with it, which is the failure mode that makes write
     * buffering look like data loss rather than a speed-up.
     *
     * THROUGH THE HOOK, not _cleanup directly: exit() is the one libc
     * entry point that nearly every program reaches, and calling the buffer's
     * flush by name would make merely calling exit() drag in all of buffered
     * stdio.  It did -- the M37 vreclaim fixture prints nothing, calls exit,
     * and overflowed its 64 KB seg0 on that alone. */
    __lc_stdio_flush();
    __syscall(1, code & 0xFF, 0, 0);
    for (;;) ;                                   /* not reached */
}

void _exit(int code)
{
    /* BSD _exit(2) DOES NOT FLUSH, and that is the whole difference from
     * exit() now that stdio buffers.  A vfork child shares the parent's image
     * until it execs, so flushing here would emit the PARENT's held output
     * from the child and then emit it again when the parent exits.  That is
     * also why BSD sources call _exit in a vfork child (fork train V0). */
    __syscall(1, code & 0xFF, 0, 0);
    for (;;) ;                                   /* not reached */
}
