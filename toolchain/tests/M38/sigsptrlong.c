/* A POINTER ARGUMENT TO A `long' PARAMETER KEEPS ITS BANK.  elvis's
 * msg(fmt, arg1, ..., arg7) is defined with seven `long' parameters and
 * called with pointers for its %s conversions.  Through a signature the
 * argument is converted to the parameter's type, and K&R A.6.6 lets "a
 * pointer ... be converted to an integral type large enough to hold it"
 * with an implementation-defined mapping: fcc's, as a cast does it, puts the
 * offset in the low word and the BANK in the high.  The argument path took
 * the int route instead (offset through _fcc_long_from_int, bank lost), so
 * msg's %s read the string from bank 0 and vi drew a stale screen.
 *
 * sigsptrlong.sigs gives `same' (long, long).  Exit 42 only if the pointer
 * arrives exactly as the cast makes it.
 */
char buf[4];

main()
{
    char *p = buf;
    return (same(p, (long)p));
}

same(a, b)
    long a, b;
{
    return (a == b ? 42 : 7);
}
