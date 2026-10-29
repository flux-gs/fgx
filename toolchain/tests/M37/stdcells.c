/* stdin, stdout and stderr are 2.11BSD's &_iob[0], [1] and [2]: the table is a
 * C global in libc's per-process core, in the program's data bank.  A FILE*
 * fopen() returns is another entry of the same table, so it must carry the
 * same bank (check 4); a FILE* compares equal to itself (2); and the three
 * standard streams are descriptors 0, 1 and 2.  FGX-only (MAME oracle).
 * Exit 42. */
#include <stdio.h>

int main(void)
{
    FILE *f, *h;

    f = stdout;
    if (fileno(f) != 1) return 1;
    if (f != stdout) return 2;
    h = fopen("/tmp/sc", "w");
    if (h == 0) return 3;
    if (((unsigned long)h >> 16) != ((unsigned long)stdout >> 16))
        { fclose(h); unlink("/tmp/sc"); return 4; }
    fputc('x', h);
    fclose(h);
    unlink("/tmp/sc");
    if (fileno(stderr) != 2) return 5;
    if (fileno(stdin) != 0) return 6;
    return 42;
}
