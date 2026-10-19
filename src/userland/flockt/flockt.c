/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* flockt -- flock(2).
 *
 *   FL NB ok     an exclusive lock refuses a second open's shared and
 *                exclusive LOCK_NB tries; shared locks coexist; an upgrade
 *                against another shared holder is refused; close drops a lock
 *   FL WAIT ok   a child blocked in LOCK_EX runs only after its parent unlocks
 *   FL PIPE ok   a pipe is EOPNOTSUPP
 *
 * Every wrong answer prints FL ... FAIL with what was seen. */
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/file.h>

int fork();
int wait();
int pipe();
int sleep();
int access();
int unlink();
void _exit();

#define F   "/tmp/flockt.f"
#define M   "/tmp/flockt.m"

static int
nb(fd, how)
int fd, how;
{
    if (flock(fd, how | LOCK_NB) == 0)
        return (0);
    return (errno == EWOULDBLOCK ? 1 : -errno);
}

int
main()
{
    int a, b, p[2], st;

    unlink(M);
    a = open(F, O_RDWR | O_CREAT, 0644);
    b = open(F, O_RDWR, 0);
    if (a < 0 || b < 0) {
        printf("FL NB FAIL open\n");
        return (1);
    }
    if (flock(a, LOCK_EX) != 0 || nb(b, LOCK_SH) != 1 || nb(b, LOCK_EX) != 1) {
        printf("FL NB FAIL ex\n");
        return (1);
    }
    if (flock(a, LOCK_UN) != 0 || nb(b, LOCK_SH) != 0 || nb(a, LOCK_SH) != 0
        || nb(a, LOCK_EX) != 1) {
        printf("FL NB FAIL sh\n");
        return (1);
    }
    close(b);
    if (nb(a, LOCK_EX) != 0) {
        printf("FL NB FAIL close\n");
        return (1);
    }
    printf("FL NB ok\n");
    fflush(stdout);

    /* a holds LOCK_EX.  The child's own open waits for it. */
    if (fork() == 0) {
        int c = open(F, O_RDWR, 0);

        if (flock(c, LOCK_EX) != 0) {
            printf("FL WAIT FAIL flock %d\n", errno);
            _exit(1);
        }
        if (access(M, 0) != 0) {
            printf("FL WAIT FAIL early\n");
            _exit(1);
        }
        printf("FL WAIT ok\n");
        _exit(0);
    }
    sleep(2);
    close(open(M, O_WRONLY | O_CREAT, 0644));
    flock(a, LOCK_UN);
    wait(&st);

    pipe(p);
    if (flock(p[0], LOCK_EX) != -1 || errno != EOPNOTSUPP)
        printf("FL PIPE FAIL %d\n", errno);
    else
        printf("FL PIPE ok\n");
    close(a);
    unlink(F);
    unlink(M);
    return (0);
}
