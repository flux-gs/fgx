/* fkbg - fork train Stage F probe: the parent resumes at the child's
 * EXEC (not its exit) -- true background concurrency after fork+exec.
 *
 * fork; the child execs /bin/sleep 2.  When the parent resumes, a
 * WNOHANG poll returning 0 proves the child is STILL RUNNING alongside
 * us (the snapshot restore happened at exec, not exit).  Then reap and
 * check a clean 0.
 */
#include <stdio.h>
#include <sys/wait.h>

int fork();
int execv(char *path, char **argv);
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_st;

int main(int argc, char **argv)
{
    char *av[3];
    int pid, r;

    av[0] = "sleep";
    av[1] = "2";
    av[2] = (char *)0;

    pid = fork();
    if (pid < 0) { printf("FAIL fork\n"); return 1; }
    if (pid == 0) {
        execv("/bin/sleep", av);
        _exit(99);
    }
    r = waitpid(pid, &g_st, WNOHANG);
    if (r == 0)
        printf("CONCURRENT\n");  /* child alive while we run: the win */
    else
        printf("FAIL nohang r=%d st=%d\n", r, g_st);
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL wait\n"); return 1; }
    if (g_st == 99 << 8) { printf("FAIL exec\n"); return 1; }
    if (g_st != 0) { printf("FAIL st=%d\n", g_st); return 1; }
    printf("FKBG OK\n");
    return 0;
}
