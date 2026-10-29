/* getfsstat(2) fills no more entries than `bufsize' bytes hold.  2.11BSD
 * ufs_syscalls2.c:98, `maxcount = uap->bufsize / sizeof (struct statfs)',
 * and Reno's the same: a buffer with room for one entry gets one, and the
 * call answers 1.  The syscall glue once parked the buffer's offset on the
 * stack between the pointer and bufsize, so the kernel read the ADDRESS as
 * the size and copied every mount -- harmless into df(1)'s malloc'd buffer,
 * a second 100 bytes over the frame when the buffer was a small local.  The
 * bytes after the first entry are checked untouched.  Returns 42. */
char gbuf[300];

int main(void)
{
    int i, r;

    for (i = 0; i < 300; i++)
        gbuf[i] = (char)0xAA;
    r = getfsstat(gbuf, 100, 0);
    for (i = 100; i < 300; i++)
        if (gbuf[i] != (char)0xAA)
            return 1;               /* wrote past the room it was given */
    return r == 1 ? 42 : 2;
}
