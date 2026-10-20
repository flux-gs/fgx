/* vfexec - fork train Stage V2 probe: vfork + execv, the tcsh hot path.
 *
 * The child borrows the image and execv()s /bin/basename with an argv whose
 * strings live in main's STACK frame (bank 0) -- exercising the libc
 * exec staging (out-of-bank strings bounce through the data-bank arena)
 * -- then the parent, suspended across the vfork window, resumes at the
 * child's exec (not its exit), reaps the child, and checks status 0.
 * basename(1) prints its argument, so the marker on screen proves the exec'd image really ran with
 * the staged argv.
 */
#include <stdio.h>

int vfork();
int execv(char *path, char **argv);
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_st;                        /* global status cell (the stack-local
                                  * waitpid store is the known open
                                  * toolchain defect) */

int main(int argc, char **argv)
{
    char m0[10], m1[12];         /* stack-frame strings: bank-0 residents */
    char *av[3];
    int pid, r;

    m0[0]='b'; m0[1]='n'; m0[2]=0;      /* argv[0] name (cosmetic) */
    m1[0]='V'; m1[1]='F'; m1[2]='E'; m1[3]='X'; m1[4]='M'; m1[5]='A';
    m1[6]='R'; m1[7]='K'; m1[8]=0;
    av[0] = m0;
    av[1] = m1;
    av[2] = (char *)0;

    pid = vfork();
    if (pid < 0) { printf("FAIL vfork=%d\n", pid); return 1; }
    if (pid == 0) {
        execv("/bin/basename", av);
        _exit(99);               /* exec failed: distinct status */
    }
    printf("parent: pid=%d\n", pid);
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL waitpid r=%d\n", r); return 1; }
    if (g_st == 99 << 8) { printf("FAIL exec st=%d\n", g_st); return 1; }
    if (g_st != 0) { printf("FAIL status st=%d\n", g_st); return 1; }
    printf("VFEXEC OK\n");
    return 0;
}
