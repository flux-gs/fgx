/* ungetc(3): push one character back so the next getc returns it.
 *
 * Ported from 2.11BSD stdio/ungetc.c.  The buffer's cursor steps back one and
 * that slot is overwritten, because ungetc may push a byte the file never
 * held.  Upstream's three refusals are all here: EOF is never pushed, a stream
 * that is not readable has no buffer to push into (__lc_bufidx answers -1 for
 * the write side), and neither has one never read from (upstream's
 * `iop->_base == NULL', which _filbuf sets on the first read).  An
 * unbuffered stream -- a terminal, or one whose malloc failed -- pushes back
 * into its one-byte _lc_small, as upstream's does into _smallbuf.
 *
 * AT THE START OF THE BUFFER IT DEPENDS ON WHETHER ANYTHING IS HELD, which is
 * upstream's
 *
 *     if (iop->_ptr == iop->_base)
 *             if (iop->_cnt == 0) iop->_ptr++;
 *             else                return (EOF);
 *
 * -- with bytes held there is no earlier slot to overwrite and it refuses;
 * with the buffer empty it makes room and the pushback stands.  A pushback
 * clears EOF, so getc after ungetc after EOF hands back the pushed byte. */
int ungetc(int c, char *fp)
{
    int *e = __lc_fent(fp);
    int b = __lc_bufidx(__lc_slot(fp), e);
    char *p;

    if (c < 0)
        return -1;
    if (b < 0 || _lc_bfd[b] != e[0] + 1)
        return -1;
    if (_lc_bpos[b] == 0) {
        if (_lc_blen[b] != 0)
            return -1;
        _lc_blen[b] = 1;
    } else {
        _lc_bpos[b] = _lc_bpos[b] - 1;
    }
    p = __lc_bptr(b);
    p[_lc_bpos[b]] = (char)c;
    e[1] &= ~_IOEOF;
    return c & 0xFF;
}
