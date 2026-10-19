/*
 * killtest - headless self-check for Phase 5.1 signal default actions.
 *
 * Spawns /testbin/spinner (a task that loops yielding), sends it SIGTERM, then
 * wait()s and inspects the BSD wait status.  A signal-terminated child encodes
 * the terminating signal in the low byte of the status (WIFSIGNALED); a normal
 * exit puts the exit code in the high byte and leaves the low byte 0 (WIFEXITED).
 * PASS iff the low byte equals SIGTERM — i.e. the kernel applied the SA_TERM
 * default action to a pending SIGTERM at the spinner's next syscall exit.
 *
 * Self-checking: prints "killtest: PASS"/"killtest: FAIL" and returns 0/1.
 */
#include <stdio.h>

#define SIGTERM 15

int spawnv(char *path, char **argv); /* libc: async posix_spawn -> pid/-1 */
int kill(int pid, int sig);    /* kt_stubs.s: SYS_KILL                    */
int wait(int *status);          /* kt_stubs.s: wait(&status) -> pid/-1     */

int wstatus;                      /* data-bank global: the kernel writes the
                                     status here via the caller's bank */

int main(int argc, char **argv)
{
    int pid, reaped, sig;

    pid = spawnv("/testbin/spinner", 0);
    if (pid < 0) {
        printf("killtest: spawn failed\n");
        return 1;
    }
    printf("killtest: spawned spinner pid %d\n", pid);

    if (kill(pid, SIGTERM) < 0) {
        printf("killtest: kill failed\n");
        return 1;
    }

    wstatus = 0;
    reaped = wait(&wstatus);
    if (reaped < 0) {
        printf("killtest: wait failed\n");
        return 1;
    }

    sig = wstatus & 0xff;
    if (sig == SIGTERM) {
        printf("killtest: PASS - pid %d killed by signal %d\n", reaped, sig);
        return 0;
    }
    printf("killtest: FAIL - status %d low byte %d\n", wstatus, sig);
    return 1;
}
