/*
 * sleep - suspend execution for N seconds.   Usage: sleep seconds
 *
 * The canonical well-behaved background job: `sleep 30 &` idles (the kernel
 * WAIs) instead of busy-looping like spinner.  Blocks via SYS_NANOSLEEP, which
 * idle-sleeps the task on a 60 Hz timer deadline and wakes it when the deadline
 * passes (or early, EINTR, on ^C -> SIGINT).
 *
 * The kernel syscall takes a 16-bit tick count; fcc ints are 16-bit signed, so
 * we sleep in chunks of <= 500 s (30000 ticks < 32767) to keep `chunk * 60`
 * from overflowing, looping for longer durations.
 */
#include <stdio.h>

int atoi(const char *s);          /* libc (fcc -> c_atoi) */
int nanosleep(int ticks);        /* sleep_stubs.s: SYS_NANOSLEEP */

int main(int argc, char **argv)
{
    int secs, chunk;

    if (argc < 2) {
        printf("usage: sleep seconds\n");
        return 1;
    }
    secs = atoi(argv[1]);
    if (secs < 0)
        secs = 0;

    while (secs > 0) {
        chunk = secs;
        if (chunk > 500)
            chunk = 500;
        if (nanosleep(chunk * 60) < 0)     /* interrupted (^C) */
            return 1;
        secs = secs - chunk;
    }
    return 0;
}
