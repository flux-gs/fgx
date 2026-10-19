/* fkiso - fork train Stage F core probe: snapshot-fork ISOLATION.
 *
 * The child runs IN the parent's image and mutates every mutable tier --
 * a data-bank global, an sbrk-heap byte, a stack local -- then dies
 * pre-exec.  The parent, restored from the snapshot, must see all three
 * UNTOUCHED (and the child must have seen its own writes: shared-until-
 * restore, reverted-after).  That is fork semantics, minus only the
 * deferred-parent scheduling.
 */
#include <stdio.h>

int fork();
char *sbrk(int incr);
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_flag;
int g_st;

int main(int argc, char **argv)
{
    char *h;
    int pid, r, loc;

    h = sbrk(64);
    if (h == (char *)-1) { printf("FAIL sbrk\n"); return 1; }
    h[0] = 11;
    g_flag = 11;
    loc = 5;

    pid = fork();
    if (pid < 0) { printf("FAIL fork=%d\n", pid); return 1; }
    if (pid == 0) {
        g_flag = 99;
        h[0] = 99;
        loc = 99;
        if (g_flag != 99 || h[0] != 99 || loc != 99)
            _exit(2);            /* the child must see its own writes */
        _exit(7);
    }
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL wait r=%d\n", r); return 1; }
    if (((unsigned)g_st >> 8) != 7) { printf("FAIL st=%d\n", g_st); return 1; }
    if (g_flag != 11) { printf("FAIL isoG g=%d\n", g_flag); return 1; }
    if (h[0] != 11)   { printf("FAIL isoH h=%d\n", h[0]); return 1; }
    if (loc != 5)     { printf("FAIL isoL l=%d\n", loc); return 1; }
    printf("FKISO OK\n");
    return 0;
}
