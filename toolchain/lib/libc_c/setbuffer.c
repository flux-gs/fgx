/* setbuffer(3) and setlinebuf(3) -- 2.11BSD usr/src/lib/libc/stdio/setbuffer.c.
 * No-ops for the reason setbuf(3) is one: FGX stdio is unbuffered, so there
 * is no buffer to point at a caller's array and no line mode to switch into.
 * They exist because ported programs call them at startup and then rely on
 * WRITES BEHAVING AS IF FLUSHED -- which unbuffered output already satisfies,
 * strictly more eagerly than either function asks for.  2.11BSD's fsck opens
 * with setbuffer(stdin,...); setbuffer(stdout,...); setlinebuf(stdout);.
 *
 * setlinebuf returns int upstream (the old interface); nothing checks it. */
void setbuffer(char *fp, char *buf, int size)
{
    (void)fp; (void)buf; (void)size;
}

int setlinebuf(char *fp)
{
    (void)fp;
    return (0);
}
