/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* cloexec -- fcntl(2) and close-on-exec.
 *
 *   cloexec          fcntl's answers, then the descriptors across a vfork and
 *                    execv and across a spawn:
 *                        CX FCNTL ok / CX EXEC ok / CX SPAWN ok
 *   cloexec child T A B C D
 *                    (run by the above) A and C were marked close-on-exec and
 *                    must be gone; B was marked and cleared, D is a dup of A,
 *                    and both must be open.  Prints CX T ok.
 *
 * Every wrong answer prints CX ... FAIL with what was seen. */
#include <stdio.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fgx.h>

int vfork();
int wait();
int execv();
void _exit();
int atoi();

static char *argv_child[8];
static char a1[6], a2[6], a3[6], a4[6];

static int
isopen(fd)
int fd;
{
    struct stat sb;

    return (fstat(fd, &sb) == 0);
}

static int
child(tag, a, b, c, d)
char *tag;
int a, b, c, d;
{
    if (isopen(a) || !isopen(b) || isopen(c) || !isopen(d)) {
        printf("CX %s FAIL open a=%d b=%d c=%d d=%d\n", tag,
               isopen(a), isopen(b), isopen(c), isopen(d));
        return (1);
    }
    printf("CX %s ok\n", tag);
    return (0);
}

int
main(argc, argv)
int argc;
char **argv;
{
    int a, b, c, d, w, fl, pid, st;
    int one = 1;

    if (argc == 7 && strcmp(argv[1], "child") == 0)
        return (child(argv[2], atoi(argv[3]), atoi(argv[4]), atoi(argv[5]),
                      atoi(argv[6])));

    a = open("/etc/passwd", O_RDONLY);
    b = open("/etc/passwd", O_RDONLY);
    c = open("/etc/passwd", O_RDONLY);
    if (a < 0 || b < 0 || c < 0) {
        printf("CX FCNTL FAIL open\n");
        return (1);
    }
    if (fcntl(a, F_GETFD, 0) != 0 || fcntl(a, F_SETFD, FD_CLOEXEC) != 0 ||
        fcntl(a, F_GETFD, 0) != FD_CLOEXEC) {
        printf("CX FCNTL FAIL setfd %d\n", fcntl(a, F_GETFD, 0));
        return (1);
    }
    ioctl(b, FIOCLEX, (char *)0);
    ioctl(b, FIONCLEX, (char *)0);
    ioctl(c, FIOCLEX, (char *)0);
    if (fcntl(b, F_GETFD, 0) != 0 || fcntl(c, F_GETFD, 0) != FD_CLOEXEC) {
        printf("CX FCNTL FAIL fioclex b=%d c=%d\n",
               fcntl(b, F_GETFD, 0), fcntl(c, F_GETFD, 0));
        return (1);
    }
    d = fcntl(a, F_DUPFD, 12);
    if (d < 12 || fcntl(d, F_GETFD, 0) != 0) {
        printf("CX FCNTL FAIL dupfd %d\n", d);
        return (1);
    }
    w = open("/tmp/cloexec.w", O_WRONLY | O_CREAT | O_APPEND, 0644);
    fl = fcntl(w, F_GETFL, 0);
    if (fl != (O_WRONLY | O_APPEND) || fcntl(99, F_GETFD, 0) != -1 ||
        fcntl(a, F_GETOWN, 0) != -1) {
        printf("CX FCNTL FAIL getfl %x\n", fl);
        return (1);
    }
    close(w);
    unlink("/tmp/cloexec.w");
    printf("CX FCNTL ok\n");

    sprintf(a1, "%d", a);
    sprintf(a2, "%d", b);
    sprintf(a3, "%d", c);
    sprintf(a4, "%d", d);
    argv_child[0] = "cloexec";
    argv_child[1] = "child";
    argv_child[3] = a1;
    argv_child[4] = a2;
    argv_child[5] = a3;
    argv_child[6] = a4;
    argv_child[7] = (char *)0;

    argv_child[2] = "EXEC";
    fflush(stdout);
    if ((pid = vfork()) == 0) {
        execv("/testbin/cloexec", argv_child);
        _exit(127);
    }
    wait(&st);

    argv_child[2] = "SPAWN";
    fflush(stdout);
    pid = spawnv("/testbin/cloexec", argv_child);
    if (pid < 0) {
        printf("CX SPAWN FAIL spawnv\n");
        return (1);
    }
    waitpid(pid, &st, 0);
    return (0);
}
