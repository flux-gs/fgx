/*
 * bytecat -- copy stdin to stdout a byte at a time through getc and putc:
 * shared libc SP2's byte loop (spec section 8, "Measurement"), built once
 * as every program is and once statically against libc's library-mode
 * compile (bytecatso), so the two can be timed on the same input.
 */
#include <stdio.h>

int
main()
{
    int c;

    while ((c = getc(stdin)) != EOF)
        putc(c, stdout);
    return 0;
}
