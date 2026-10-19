/* fread/fwrite return the number of COMPLETE ITEMS moved, which is what every
 * caller that passes a record size rather than 1 is testing.
 *
 * Ported from 2.11BSD libc, stdio/fread.c and stdio/fwrite.c (5.2 Berkeley
 * 3/9/86).  Upstream ends both with
 *
 *     return (size != 0 ? count - ((s + size - 1) / size) : 0);
 *
 * where `s' is the bytes still wanted.  Spelled here as `got / sz', which is
 * the same number: with got = q*sz + rem, ceil((sz*n - got)/sz) is n - q for
 * every rem, so n minus it is q.  The zero-size guard is upstream's too.
 *
 * A PARTIAL ITEM IS NOT AN ITEM.  36 bytes of a 40-byte record read back as 0,
 * and the bytes are gone -- upstream loses them the same way, because the
 * position advanced.  That is the contract who(1) and w(1) rely on when they
 * ask for one fixed-size utmp record and test `== 1'.
 *
 * BOTH LOOP, because one read(2) or write(2) is not one transfer.  Upstream's
 * `while (s > 0)` refills through _filbuf until the count is met or EOF; a
 * character device here returns a short count in exactly the same way
 * (Fs_WriteN), so a single call would report a short item count for a transfer
 * that had not finished.  The eof/err flags are still left alone.
 *
 * sz * n is an int and overflows past 32767; the loop then sees want <= 0 and
 * both return 0 rather than transferring anything. */
int fread(char *buf, int sz, int n, char *fp)
{
    int *e = __lc_fent(fp);
    int b = __lc_bufidx(__lc_slot(fp), e);
    int want = sz * n;
    int got = 0;
    int held, i, r;
    char *src;

    if (sz <= 0 || n <= 0 || want <= 0)
        return 0;

    /* Held bytes come FIRST.  Going straight to read() would skip whatever a
     * previous fgetc/fgets pulled into the buffer -- a caller that mixes the
     * two would silently lose up to a bufferful, and read the file's own
     * contents out of order. */
    held = __lc_bavail(b);
    if (held > 0) {
        if (held > want)
            held = want;
        src = __lc_bptr(b);
        for (i = 0; i < held; i++)
            buf[i] = src[_lc_bpos[b] + i];
        _lc_bpos[b] = _lc_bpos[b] + held;
        got = held;
    }
    while (got < want) {
        r = read(e[0], buf + got, want - got);
        if (r <= 0)                              /* EOF, or an error we do not
                                                  * distinguish from it */
            break;
        got = got + r;
    }
    return got / sz;
}
