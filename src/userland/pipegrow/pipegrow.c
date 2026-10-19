/* pipegrow - fork train Stage P probe: on-demand pipe ring growth.
 *
 * Part 1 (pure growth): with NO reader at all, a single 3072-byte write
 * must complete without blocking (ring doubles 512 -> 1024 -> 2048 ->
 * 4096) and read back byte-exact across the two unwrap copies.
 *
 * Part 2 (the shape growth exists for): fork; the child writes 2048
 * bytes into the pipe and dies WITHOUT ever exec'ing, while the pipe's
 * only reader -- the snapshot-frozen parent -- is suspended.  On a
 * fixed 512-byte ring this deadlocks; with growth the child completes,
 * the restored parent reaps it and reads all 2048 bytes intact (the
 * ring is KERNEL memory, so pipe data survives the parent's snapshot
 * restore -- exactly what backquote command substitution needs).
 */
#include <stdio.h>

int pipe(int *fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);
int fork();
int waitpid(int pid, int *status, int options);
void _exit(int code);

int g_fds[2];
int g_st;
char g_buf[3072];

int main(int argc, char **argv)
{
    int i, r, got, pid;

    /* part 1: no-reader growth round trip */
    if (pipe(g_fds) != 0) { printf("FAIL pipe1\n"); return 1; }
    for (i = 0; i < 3072; i++) g_buf[i] = (char)(i * 7 + 3);
    r = write(g_fds[1], g_buf, 3072);
    if (r != 3072) { printf("FAIL wr r=%d\n", r); return 1; }
    for (i = 0; i < 3072; i++) g_buf[i] = 0;
    got = 0;
    while (got < 3072) {
        r = read(g_fds[0], g_buf + got, 3072 - got);
        if (r <= 0) { printf("FAIL rd r=%d\n", r); return 1; }
        got += r;
    }
    for (i = 0; i < 3072; i++)
        if (g_buf[i] != (char)(i * 7 + 3)) { printf("FAIL cmp@%d\n", i); return 1; }
    close(g_fds[0]);
    close(g_fds[1]);

    /* part 2: frozen-reader backquote shape */
    if (pipe(g_fds) != 0) { printf("FAIL pipe2\n"); return 1; }
    pid = fork();
    if (pid < 0) { printf("FAIL fork\n"); return 1; }
    if (pid == 0) {
        for (i = 0; i < 2048; i++) g_buf[i] = (char)(i ^ 0x55);
        r = write(g_fds[1], g_buf, 2048);
        if (r != 2048) _exit(2);     /* would deadlock on a fixed ring */
        _exit(9);
    }
    r = waitpid(pid, &g_st, 0);
    if (r != pid) { printf("FAIL wait\n"); return 1; }
    if (((unsigned)g_st >> 8) != 9) { printf("FAIL st=%d\n", g_st); return 1; }
    got = 0;
    while (got < 2048) {
        r = read(g_fds[0], g_buf + got, 2048 - got);
        if (r <= 0) { printf("FAIL rd2 r=%d\n", r); return 1; }
        got += r;
    }
    for (i = 0; i < 2048; i++)
        if (g_buf[i] != (char)(i ^ 0x55)) { printf("FAIL cmp2@%d\n", i); return 1; }
    printf("PIPEGROW OK\n");
    return 0;
}
