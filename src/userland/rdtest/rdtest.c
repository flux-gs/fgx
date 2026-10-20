/* rdtest — minimal repro for the elvis paint-dead ROOT CAUSE.
 *
 * elvis's block buffer (blk.c) writes lines into a temp file, then reads a
 * block back with lseek(fd, phys*BLKSIZE, SEEK_SET) + read(fd, buf, BLKSIZE).
 * The temp file is a ProDOS SAPLING (>1 block).  We proved the block IS on
 * disk at the right offset, yet elvis's read-back comes back empty.  This
 * isolates that positioned read-back from elvis entirely.
 *
 * Faithful to elvis: creat()+close then open(O_RDWR); a 3-block sapling; the
 * blkflush append idiom (lseek(0,SEEK_END)+write); the blkget read-back
 * (lseek(off,SEEK_SET)+read).  Tests read-back with NO cross-file churn and
 * again AFTER reading a second open file (owner churn) to see if the FS
 * single-file-state switch is the trigger.
 */
#include <stdio.h>              /* SEEK_SET=0, SEEK_END=2, printf */
#include <fcntl.h>              /* O_RDWR, O_RDONLY */

#define BLKSIZE 2048

int  open(char *path, int flags);
int  creat(char *path, int mode);
int  close(int fd);
int  read(int fd, char *buf, int n);
int  write(int fd, char *buf, int n);
long lseek(int fd, long off, int whence);
int  unlink(char *path);

char wblk[BLKSIZE];
char rbuf[BLKSIZE];

static void fill(char *s)
{
    int i;
    char *p;
    for (i = 0; i < BLKSIZE; i++) wblk[i] = 0;
    p = wblk;
    while (*s) *p++ = *s++;
}

/* read physical block 2 (offset 4096) back and check it == "fgx\n..." */
static void check(int fd, char *label)
{
    int n;
    rbuf[0] = rbuf[1] = rbuf[2] = rbuf[3] = 0;
    lseek(fd, 4096L, SEEK_SET);
    n = read(fd, rbuf, BLKSIZE);
    printf("RDT %s: n=%d b=%d,%d,%d,%d\n", label, n,
           rbuf[0], rbuf[1], rbuf[2], rbuf[3]);
    if (n == BLKSIZE && rbuf[0] == 'f' && rbuf[1] == 'g'
     && rbuf[2] == 'x' && rbuf[3] == '\n')
        printf("RDT %s: PASS\n", label);
    else
        printf("RDT %s: FAIL\n", label);
}

int main()
{
    int tfd, ofd;
    long pos;
    char *tmp = "/var/tmp/rdt.dat";

    unlink(tmp);
    close(creat(tmp, 0600));            /* elvis's create dance (tmp.c:218) */
    tfd = open(tmp, O_RDWR);            /* reopen readable (tmp.c:222)      */
    if (tfd < 0) { printf("RDT: open FAIL\n"); return 1; }

    fill("HDRBLOCK");       write(tfd, wblk, BLKSIZE);   /* phys 0        */
    fill("/etc/hostname");  write(tfd, wblk, BLKSIZE);   /* phys 1        */
    pos = lseek(tfd, 0L, SEEK_END);                      /* blkflush idiom */
    fill("fgx\n");          write(tfd, wblk, BLKSIZE);   /* phys 2 @ 4096 */
    printf("RDT: seekend=%d want=4096\n", (int)pos);

    check(tfd, "nochurn");              /* read-back, last op was on tfd  */

    ofd = open("/etc/hostname", O_RDONLY);
    if (ofd >= 0) read(ofd, rbuf, 16);  /* touch a 2nd file -> owner churn */
    check(tfd, "churn");                /* read-back after the churn      */
    if (ofd >= 0) close(ofd);

    close(tfd);
    unlink(tmp);
    return 0;
}
