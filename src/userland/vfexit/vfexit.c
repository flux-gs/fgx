/* vfexit - fork train Stage V probe: vfork + child _exit, no exec.
 *
 * The child borrows the parent's image and immediately _exit(7)s; the
 * parent must resume with the child's pid and reap status 7 via waitpid.
 * g_touch proves the memory really is SHARED (vfork, not fork): the
 * parent must see the child's write.  The parent's printf after resume
 * also proves its stack frame survived the child's reuse of the shared
 * stack (the kernel + libc stub stash/rebuild path).
 */
#include <stdio.h>

int vfork();
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_touch;
int g_st;                    /* global status cell: discriminates a kernel
                              * Y-return failure (both zero) from a bank-0
                              * stack-local far-store failure (only st zero) */

int main(int argc, char **argv) {
    int pid, st, r;

    pid = vfork();
    if (pid < 0) { printf("FAIL vfork=%d\n", pid); return 1; }
    if (pid == 0) {
        g_touch = 42;
        _exit(7);            /* never returns through the shared frame */
    }
    printf("parent: pid=%d\n", pid);
    if (g_touch != 42) { printf("FAIL share g=%d\n", g_touch); return 1; }
    st = 0;
    r = waitpid(pid, &g_st, 0);          /* global cell this run: discriminate
                                          * kernel-Y-path vs stack-local store */
    st = g_st;
    if (r != pid) { printf("FAIL waitpid r=%d\n", r); return 1; }
    printf("st=%d\n", st);
    if (((unsigned)st >> 8) != 7) { printf("FAIL status st=%d\n", st); return 1; }
    printf("VFEXIT OK\n");
    return 0;
}
