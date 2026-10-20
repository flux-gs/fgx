/* T5-C C4 batch 4: the buffered syscall wrappers in C over __syscall_db —
 * creat/write/close, reopen/lseek/read into a BANK-0 STACK buffer (the
 * buffer-bank ABI in anger), memcmp the payload, open-fail errno path,
 * unlink, getwd.  read/write keep the FGX 0-on-error convention;
 * lseek returns the 32-bit position as a long.
 *
 * NOT clang-cross-checkable (FGX filesystem); MAME is the oracle.
 * 5+5+4+5+5+5+5+3+3+2 = 42. */
#include <fcntl.h>
#include <string.h>
#include <sys/param.h>          /* MAXPATHLEN for getwd(3) */

int main(void)
{
    char buf[16];
    /* getwd(3) takes NO size and requires MAXPATHLEN; the 16-byte read
     * buffer above cannot be reused for it. */
    char cwd[MAXPATHLEN];
    int fd, r = 0;

    fd = creat("/tmp/c4b4", 0);
    if (fd >= 0)                        r += 5;
    if (write(fd, "abcdef", 6) == 6)    r += 5;
    if (close(fd) == 0)                 r += 4;
    fd = open("/tmp/c4b4", 0);
    if (fd >= 0)                        r += 5;
    if (lseek(fd, 2L, 0) == 2L)         r += 5;
    if (read(fd, buf, 4) == 4)          r += 5;
    if (memcmp(buf, "cdef", 4) == 0)    r += 5;
    close(fd);
    if (open("/tmp/NOPEc4", 0) == -1)   r += 3;
    if (unlink("/tmp/c4b4") == 0)       r += 3;
    if (getwd(cwd) != 0)                r += 2;
    return r;
}
