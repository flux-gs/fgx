/* fknest - fork train Stage F probe: NESTED snapshot forks (LIFO restore).
 *
 * parent forks child; child mutates, forks grandchild; grandchild
 * mutates and dies; child must be restored to ITS state (50), then dies;
 * parent must be restored to the ORIGINAL state (11).  Each level's
 * snapshot captures the level above's live image, so restores must
 * unwind newest-first -- which the per-child descriptors give for free.
 */
#include <stdio.h>

int fork();
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_flag;
int g_st;

int main(int argc, char **argv)
{
    int pid1, pid2, r;

    g_flag = 11;
    pid1 = fork();
    if (pid1 < 0) { printf("FAIL fork1\n"); return 1; }
    if (pid1 == 0) {
        g_flag = 50;
        pid2 = fork();
        if (pid2 < 0) _exit(2);
        if (pid2 == 0) {
            g_flag = 99;
            _exit(3);
        }
        r = waitpid(pid2, &g_st, 0);
        if (r != pid2) _exit(4);
        if (((unsigned)g_st >> 8) != 3) _exit(5);
        if (g_flag != 50) _exit(6);  /* child restored after grandchild */
        _exit(7);
    }
    r = waitpid(pid1, &g_st, 0);
    if (r != pid1) { printf("FAIL wait\n"); return 1; }
    if (((unsigned)g_st >> 8) != 7) { printf("FAIL st=%d\n", g_st); return 1; }
    if (g_flag != 11) { printf("FAIL iso g=%d\n", g_flag); return 1; }
    printf("FKNEST OK\n");
    return 0;
}
