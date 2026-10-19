/* T5-C C5 find: c_stat SIGN-extended st_size for files >= 32KB — with a
 * 16-bit int, `eofword & 0xFFFF` is a no-op and (long) sign-extends, so
 * st_size went negative.  Latent from batch 11 until the C5 pile growth
 * pushed /bin/true past 0x8000 (statops caught it).  Pin with a file whose
 * size this fixture controls: write 33000 bytes, stat, exact-match.
 * FGX-only (MAME oracle).  Exit 42. */
#include <sys/stat.h>

char blk[500];

int main(void)
{
    struct stat st;
    int i, fd;
    long got;

    fd = creat("/tmp/statbig", 0644);
    if (fd < 0) return 1;
    for (i = 0; i < 66; i++)
        write(fd, blk, 500);               /* 66 * 500 = 33000 > 0x8000 */
    close(fd);
    if (stat("/tmp/statbig", &st) != 0) { unlink("/tmp/statbig"); return 2; }
    got = st.st_size;
    unlink("/tmp/statbig");
    if (got != 33000L) return 3;
    return 42;
}
