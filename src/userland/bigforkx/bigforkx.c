/* bigforkx - the FAIL-CLOSED half of #11.
 *
 * Snapshot-fork has to copy every bank the parent can write, and a fork that
 * cannot get one of those copies must FAIL.  Falling through to sharing a bank
 * it could not copy would be silently wrong -- the child would write through to
 * the parent, which is the exact bug #4 was.  A failure path nothing exercises
 * is a failure path nobody has ever seen work, so this drives it on purpose.
 *
 * Four blocks of 80000 bytes are two banks each: eight pairs, plus the data
 * bank and the sbrk bank, which is past FORK_MAX_PAIRS.  fork() must return -1
 * with EAGAIN, the parent's data must be untouched, and -- the part that
 * actually catches an unwind bug -- the spare banks claimed before the failure
 * must all come back.  Repeating the failing fork five times would exhaust the
 * user bank pool if each attempt leaked what it claimed, and the final fork
 * after freeing proves the pool is still healthy.
 *
 * Output: "BIGFORKX OK", or "FAIL <what>".
 */
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

int fork();
int waitpid(int pid, int *status, int options);
void _exit(int code);

#define NBLK 4

int g_st;

int main(int argc, char **argv)
{
    unsigned char *p[NBLK];
    int i, pid, r;

    for (i = 0; i < NBLK; i++) {
        p[i] = (unsigned char *)malloc(80000L);
        if (p[i] == (unsigned char *)0) { printf("FAIL alloc %d\n", i); return 1; }
        p[i][0] = (unsigned char)('A' + i);
        p[i][70000] = (unsigned char)('a' + i);
    }

    for (i = 0; i < 5; i++) {
        errno = 0;
        pid = fork();
        if (pid == 0)
            _exit(3);                   /* must be unreachable */
        if (pid > 0) {
            /* It forked anyway.  Reap it, then say so -- a fork that succeeds
             * here has snapshotted fewer banks than the parent can write. */
            waitpid(pid, &g_st, 0);
            printf("FAIL forked pid=%d try=%d\n", pid, i);
            return 1;
        }
        if (errno != EAGAIN) { printf("FAIL errno=%d try=%d\n", errno, i); return 1; }
    }

    for (i = 0; i < NBLK; i++) {
        if (p[i][0] != (unsigned char)('A' + i)
         || p[i][70000] != (unsigned char)('a' + i)) {
            printf("FAIL clobbered %d\n", i);
            return 1;
        }
    }

    for (i = 0; i < NBLK; i++)
        free((char *)p[i]);

    /* The pool must be whole again: this fork needs the data bank and the sbrk
     * bank, and gets them only if all five failed attempts unwound cleanly. */
    pid = fork();
    if (pid < 0) { printf("FAIL refork errno=%d\n", errno); return 1; }
    if (pid == 0)
        _exit(7);
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL wait r=%d\n", r); return 1; }
    if (((unsigned)g_st >> 8) != 7) { printf("FAIL st=%d\n", g_st); return 1; }

    printf("BIGFORKX OK\n");
    return 0;
}
