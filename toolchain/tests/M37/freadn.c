/* fread/fwrite return COMPLETE ITEMS, not the byte count -- 2.11BSD
 * stdio/fread.c and stdio/fwrite.c both end
 * `count - ((s + size - 1) / size)'.  who(1) and w(1) read fixed 36-byte utmp
 * records as fread(&r, sizeof r, 1, fp) == 1 and got nothing under the old
 * byte-count contract, which only ever agreed with POSIX for sz == 1.
 * FGX-only (MAME oracle).
 *
 * THE LAST ARM IS THE ONE A BUFFER HIDES.  When the read buffer already holds
 * everything asked for, fread never reaches read(2) -- so an implementation
 * that converts to items only on the read(2) path still returns BYTES here.
 * Nothing else in this fixture fills the buffer first, which is exactly why it
 * needs an fgetc in front of it.
 *
 * 8 (3 items written) + 8 (2 whole 12-byte items out of 36) + 8 (the 12 bytes
 * left read as ONE item, not twelve) + 4 (nothing left reads 0) + 6 (sz 1
 * still counts bytes) + 8 (buffered hit: 2 items, not 8 bytes) = 42.
 * The byte-count contract scores 10 -- measured, not reasoned: only the
 * empty-read and the sz == 1 arms survive it. */
#include <stdio.h>
extern int unlink();

char rec[36];
char in[36];

int main(void)
{
    FILE *f;
    int r = 0, n, i, c;

    for (i = 0; i < 36; i++)
        rec[i] = 'a' + i;
    f = fopen("/tmp/frn", "w");
    if (f != 0 && fwrite(rec, 12, 3, f) == 3)        r += 8;
    fclose(f);

    f = fopen("/tmp/frn", "r");
    n = fread(in, 12, 2, f);                        /* 24 of 36: 2 items */
    if (n == 2 && in[0] == 'a' && in[23] == 'a' + 23) r += 8;
    n = fread(in, 12, 2, f);                        /* 12 left: 1 item */
    if (n == 1)                                     r += 8;
    n = fread(in, 12, 1, f);                        /* nothing left */
    if (n == 0)                                     r += 4;
    fclose(f);

    f = fopen("/tmp/frn", "r");
    n = fread(in, 1, 36, f);                        /* sz 1: bytes == items */
    if (n == 36)                                    r += 6;
    fclose(f);

    /* The buffered hit: one fgetc fills the buffer, so the whole request is
     * satisfied from it and read(2) is never called. */
    f = fopen("/tmp/frn", "r");
    c = fgetc(f);
    n = fread(in, 4, 2, f);                         /* 8 bytes held: 2 items */
    if (c == 'a' && n == 2 && in[0] == 'b' && in[7] == 'a' + 8) r += 8;
    fclose(f);

    unlink("/tmp/frn");
    return r;
}
