/* The filesystem contracts login(3) and logout(3) stand on.  FGX-only oracle.
 *
 * 1. A WRITE PAST EOF EXTENDS THE FILE and the gap reads as zeroes.  4.3BSD
 *    login(3) seeks to `tty * sizeof(struct utmp)' and writes with no padding
 *    pass, so the hole is the filesystem's job (ufs_bmap.c: "a hole reads as
 *    zeroes").
 * 2. AN O_WRONLY DESCRIPTOR CAN SEEK ABSOLUTELY AND OVERWRITE IN PLACE without
 *    disturbing the rest of the file.
 * 3. SO CAN AN O_RDWR ONE THAT HAS ALREADY READ.
 * 4. AND SO CAN ONE SEEKING BACKWARDS WITH SEEK_CUR -- logout(3)'s own
 *    `lseek(fd, -(long)sizeof(UTMP), L_INCR)'.  lseek(2) carries a SIGNED
 *    32-bit off_t, which is what makes a negative offset expressible; the arm
 *    seeks back to a NONZERO offset first, because a seek landing on zero
 *    cannot tell a correct signed add from a high word thrown away.
 *
 * THE WEIGHTS ARE DISTINCT BITS, so the exit code names the arms that failed
 * rather than only how many: 1 + 2 + 4 + 8 = 15. */
#include <stdio.h>
#include <fcntl.h>
extern int unlink();
extern int open(), close(), read(), write();
extern long lseek();

char buf[64];

static int filesize(path)
    char *path;
{
    int fd, n;

    fd = open(path, 0, 0);
    if (fd < 0)
        return -1;
    n = (int)lseek(fd, 0L, SEEK_END);
    close(fd);
    return n;
}

static int mk35(path)                            /* 35 dense bytes of 'a' */
    char *path;
{
    int fd, i;

    for (i = 0; i < 35; i++)
        buf[i] = 'a';
    fd = open(path, 0x0601, 0644);               /* O_WRONLY|O_CREAT|O_TRUNC */
    if (fd < 0)
        return -1;
    write(fd, buf, 35);
    close(fd);
    return 0;
}

int main(void)
{
    int r = 0, fd, n, i, off, zero;

    /* (1) the hole */
    fd = open("/tmp/srw", 0x0601, 0644);
    if (fd < 0) return 0;
    lseek(fd, 32L, SEEK_SET);
    write(fd, "XYZ", 3);
    close(fd);
    fd = open("/tmp/srw", 0, 0);
    n = read(fd, buf, 64);
    close(fd);
    zero = 1;
    for (i = 0; i < 32; i++)
        if (buf[i] != 0) zero = 0;
    if (n == 35 && zero && buf[32] == 'X' && buf[34] == 'Z')   r += 1;

    /* (2) O_WRONLY, absolute seek, overwrite the front */
    mk35("/tmp/srw");
    fd = open("/tmp/srw", 1, 0);                 /* O_WRONLY */
    lseek(fd, 0L, SEEK_SET);
    write(fd, "01234567", 8);
    close(fd);
    n = filesize("/tmp/srw");
    fd = open("/tmp/srw", 0, 0);
    read(fd, buf, 64);
    close(fd);
    if (n == 35 && buf[0] == '0' && buf[7] == '7' && buf[8] == 'a') r += 2;

    /* (3) O_RDWR that has read, absolute seek back, overwrite in place */
    mk35("/tmp/srw");
    fd = open("/tmp/srw", 2, 0);                 /* O_RDWR */
    i = read(fd, buf, 8);
    lseek(fd, 0L, SEEK_SET);
    if (i == 8 && write(fd, "89abcdef", 8) == 8) i = 1; else i = 0;
    close(fd);
    n = filesize("/tmp/srw");
    fd = open("/tmp/srw", 0, 0);
    read(fd, buf, 64);
    close(fd);
    if (i && n == 35 && buf[0] == '8' && buf[7] == 'f' && buf[8] == 'a') r += 4;

    /* (4) O_RDWR that has read, BACKWARDS SEEK_CUR, overwrite in place.  Back
     *     to 8 first -- a landing that is not zero -- then back to 0, which is
     *     the offset logout(3)'s own sequence returns to. */
    mk35("/tmp/srw");
    fd = open("/tmp/srw", 2, 0);                 /* O_RDWR */
    i = read(fd, buf, 16);
    off = (int)lseek(fd, -8L, SEEK_CUR);         /* 16 - 8 */
    if (i == 16 && off == 8 && write(fd, "IJKLMNOP", 8) == 8) i = 1; else i = 0;
    off = (int)lseek(fd, -16L, SEEK_CUR);        /* 16 - 16 */
    if (off != 0 || write(fd, "01234567", 8) != 8) i = 0;
    close(fd);
    n = filesize("/tmp/srw");
    fd = open("/tmp/srw", 0, 0);
    read(fd, buf, 64);
    close(fd);
    if (i && n == 35 && buf[0] == '0' && buf[7] == '7'
          && buf[8] == 'I' && buf[15] == 'P' && buf[16] == 'a') r += 8;

    unlink("/tmp/srw");
    return r;
}
