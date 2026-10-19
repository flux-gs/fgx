/* T5-C C6: stdin/stdout/stderr cells widened to loader-patched 4-byte far
 * pointers (LIBC_DATA_PTR rows in libc_data.s — offset assembly-resolved,
 * bank byte relocated to the data segment by fgx_ld).  Before this, the
 * 2-byte DA cells read as a 4-byte FILE* gave a junk bank (the adjacent
 * cell's low word) — engines were immune (they rebase the offset) but any
 * far-pointer USE of the cell value was broken: FILE* equality against an
 * fopen() return, or handing the cell's value across a bank-sensitive
 * boundary.  Check 4 is the bank oracle: fopen composes its FILE* with the
 * real data bank; the widened stdout cell must carry the SAME bank.
 * FGX-only (MAME oracle).  Exit 42; pre-widening this exits 4 (RED-proven). */
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
