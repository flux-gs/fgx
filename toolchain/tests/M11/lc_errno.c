/* M11: real errno decode (P3-4 I1).  Exercises the full chain:
 *   - a failing syscall shim (open) sets errno,
 *   - a failing stdio shim (fopen) sets errno (the Fable-flagged hole),
 *   - strerror() decodes errno.h codes to messages,
 *   - an unknown code gets 2.11BSD string/strerror.c's "Unknown error: <n>".
 * Returns 42 iff every assertion holds; a small code names the first failure.
 * ENOENT=2, EINVAL=22 mirror include/errno.h. */
int open(char *path, int flags);
int fopen(char *path, char *mode);
char *strerror(int e);
int strcmp(char *a, char *b);
void perror(char *s);
extern int errno;

int main()
{
    int fd;
    int fp;

    /* 1: open() a nonexistent path -> -1, errno = ENOENT. */
    errno = 0;
    fd = open("/nope", 0);              /* O_RDONLY */
    if (fd != -1) return 1;
    if (errno != 2) return 2;

    /* 2: fopen() a nonexistent path -> NULL, errno = ENOENT (the stdio hole). */
    errno = 0;
    fp = fopen("/nope", "r");
    if (fp != 0) return 3;
    if (errno != 2) return 4;

    /* 3-5: strerror decodes known codes and falls back for unknown. */
    if (strcmp(strerror(2), "No such file or directory") != 0) return 5;
    if (strcmp(strerror(22), "Invalid argument") != 0) return 6;
    if (strcmp(strerror(9999), "Unknown error: 9999") != 0) return 7;

    /* 6: prints the decoded message end-to-end (the BSD perror path).
     * errno is still ENOENT from the fopen above; strerror() did not touch it.
     * -> console line "lc_errno: No such file or directory". */
    perror("lc_errno");

    return 42;
}
