/* fdopen(3), ungetc(3) and labs(3).  FGX-only (MAME oracle).
 *
 * THE "a" ARM IS THE ONE WITH A CHOICE IN IT.  2.11BSD stdio/fdopen.c seeks to
 * the end on 'a' (`lseek(fd, (off_t)0, L_XTND)', falling into 'w'); a
 * descriptor handed to fdopen need not be O_APPEND, so an implementation that
 * keeps the fd's offset writes over the front of the file instead of after it.
 * Here the fd is deliberately opened WITHOUT O_APPEND and sits at offset 0.
 *
 * ungetc after EOF is upstream's empty-buffer case: `if (iop->_cnt == 0)
 * iop->_ptr++;' makes room rather than refusing, and the pushback clears EOF
 * so the next getc hands it back.
 *
 * 8 (labs) + 8 (fdopen "r") + 10 (fdopen "a" lands at the END) + 8 (ungetc
 * round-trip) + 8 (ungetc after EOF) = 42.  Measured under MAME: an fdopen
 * that keeps the offset scores 24 -- the "a" arm and the round-trip after it,
 * which reads the file that arm wrote -- and an ungetc that refuses an empty
 * buffer scores 34. */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
extern int unlink();
extern int open(), close();

char buf[16];

int main(void)
{
    FILE *f;
    int r = 0, fd, c, n;

    if (labs(-5L) == 5L && labs(5L) == 5L && labs(0L) == 0L)  r += 8;

    f = fopen("/tmp/lca", "w");
    fwrite("abc", 1, 3, f);
    fclose(f);

    /* fdopen "r": the fd's offset is kept, so this reads from the start. */
    fd = open("/tmp/lca", 0, 0);                 /* O_RDONLY */
    f = fdopen(fd, "r");
    n = f != 0 ? fread(buf, 1, 3, f) : -1;
    if (n == 3 && buf[0] == 'a' && buf[2] == 'c')             r += 8;
    if (f != 0) fclose(f); else close(fd);

    /* fdopen "a": NOT opened O_APPEND and sitting at 0, so only a seek to the
     * end puts the 'd' after "abc" rather than over the 'a'. */
    fd = open("/tmp/lca", 1, 0);                 /* O_WRONLY, offset 0 */
    f = fdopen(fd, "a");
    if (f != 0) { fwrite("d", 1, 1, f); fclose(f); } else close(fd);
    f = fopen("/tmp/lca", "r");
    n = fread(buf, 1, 8, f);
    fclose(f);
    if (n == 4 && buf[0] == 'a' && buf[3] == 'd')             r += 10;

    /* ungetc mid-buffer: take a byte, push a different one, read it back. */
    f = fopen("/tmp/lca", "r");
    c = fgetc(f);                                /* 'a' */
    if (c == 'a' && ungetc('Z', f) == 'Z' && fgetc(f) == 'Z'
     && fgetc(f) == 'b')                                      r += 8;
    fclose(f);

    /* ungetc after EOF: the buffer is empty, so upstream makes room. */
    f = fopen("/tmp/lca", "r");
    while (fgetc(f) >= 0)
        ;                                        /* drain to EOF */
    if (ungetc('Q', f) == 'Q' && fgetc(f) == 'Q')             r += 8;
    fclose(f);

    unlink("/tmp/lca");
    return r;
}
