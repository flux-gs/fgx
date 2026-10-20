/*
 * exectime -- fork and exec a program n times and print the mean, in ms,
 * from gettimeofday: `EXT <path> <ms>'.  The exec budget's meter (shared
 * libc SP4 spec, section 8): every subject pays the same fork.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <sys/time.h>

static struct timeval tv;

static long
ms()
{
    gettimeofday(&tv, (struct timezone *)0);
    return tv.tv_sec * 1000L + tv.tv_usec / 1000;
}

main(argc, argv)
int argc;
char **argv;
{
    int i, n, pid, st;
    long t;

    if (argc < 3)
        return 2;
    n = atoi(argv[2]);
    t = ms();
    for (i = 0; i < n; i++) {
        pid = fork();
        if (pid == 0) {
            execl(argv[1], argv[1], (char *)0);
            _exit(127);
        }
        wait(&st);
        if (st != 0) {
            printf("EXT %s failed %d\n", argv[1], st);
            return 1;
        }
    }
    printf("EXT %s %ld\n", argv[1], (ms() - t) / n);
    return 0;
}
