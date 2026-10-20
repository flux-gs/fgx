/* T5-C C4 batch 13: the stdio FILE layer in C — write path, read path,
 * flags, seek/tell, and the "w"-TRUNCATES fix (SYS_OPEN ignores O_TRUNC;
 * the asm fopen engine silently never truncated — C fopen unlinks first,
 * the c_creat model).
 *
 * FGX-only (MAME oracle).  5+4+4+5+4+4+4+4+4+4 = 42. */
#include <stdio.h>
extern int unlink();

int main(void)
{
    FILE *f;
    char buf[32];
    int r = 0, n;

    f = fopen("/tmp/sio", "w");
    if (f != 0)                                     r += 5;
    if (fputs("hello\n", f) >= 0)                   r += 4;
    if (fputc('X', f) == 'X')                       r += 4;
    fclose(f);

    f = fopen("/tmp/sio", "r");
    if (f != 0 && fgets(buf, 32, f) != 0
        && buf[0] == 'h' && buf[5] == 10)           r += 5;
    if (fileno(f) >= 3)                             r += 4;
    if (fgetc(f) == 'X')                            r += 4;
    if (fgetc(f) == -1 && feof(f) != 0)             r += 4;
    if (fseek(f, (long)1, 0) == 0 && feof(f) == 0
        && fgetc(f) == 'e' && ftell(f) == 2)        r += 4;
    fclose(f);

    f = fopen("/tmp/sio", "w");                     /* must TRUNCATE */
    fputs("hi", f);
    fclose(f);
    f = fopen("/tmp/sio", "r");
    n = fread(buf, 1, 32, f);
    if (n == 2)                                     r += 4;
    if (fopen("/tmp/sio", "q") == 0)                r += 4;   /* EINVAL */
    fclose(f);
    unlink("/tmp/sio");
    return r;
}
