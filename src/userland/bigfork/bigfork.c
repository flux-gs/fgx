/* bigfork - a LARGE allocation must be COPIED by fork, not shared (#11 / #4).
 *
 * malloc(80000L) comes back as a dedicated multi-bank MM block, which lives
 * OUTSIDE the task's data bank.  Snapshot-fork copies the parent's mutable
 * banks to spares and runs the child in place, so any bank it does not know
 * about is silently SHARED -- the child's writes would survive into the
 * restored parent.  That is exactly the class of bug #4 was: libc malloc
 * allocating from the shared kernel arena, so a child's heap writes leaked
 * into the parent while its data-bank writes reverted.
 *
 * The sentinels straddle the block's bank crossing (offset 0 and 70000) so a
 * snapshot that covers only the FIRST bank of a multi-bank block still fails.
 *
 * Output: "BIGFORK OK" on success, "FAIL <what>" otherwise.
 */
#include <stdio.h>
#include <stdlib.h>

int fork();
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_st;

int main(int argc, char **argv)
{
    unsigned char *p;
    int pid, r;

    p = (unsigned char *)malloc(80000L);
    if (p == (unsigned char *)0) { printf("FAIL alloc\n"); return 1; }
    p[0] = 'A';
    p[70000] = 'B';

    pid = fork();
    if (pid < 0) { printf("FAIL fork=%d\n", pid); return 1; }
    if (pid == 0) {
        p[0] = 'Z';
        p[70000] = 'Z';
        /* The child must see its OWN writes: shared-until-restore is the
         * contract, so a child that cannot write the block at all is just as
         * wrong as one whose writes survive. */
        if (p[0] != 'Z' || p[70000] != 'Z')
            _exit(2);
        _exit(7);
    }
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL wait r=%d\n", r); return 1; }
    if (((unsigned)g_st >> 8) != 7) { printf("FAIL st=%d\n", g_st); return 1; }
    if (p[0] != 'A')     { printf("FAIL iso0 %d\n", p[0]); return 1; }
    if (p[70000] != 'B') { printf("FAIL iso1 %d\n", p[70000]); return 1; }
    free((char *)p);
    printf("BIGFORK OK\n");
    return 0;
}
