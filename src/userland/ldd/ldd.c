/*
 * ldd -- list a dynamic program's shared libraries: run it with
 * LD_TRACE_LOADED_OBJECTS in its environment and let the binder report
 * (shared libc SP4 spec, section 7).
 *
 * FGX-Provenance: vendor/SunOS-4.1.3/bin/ldd.c.  Changes: FGX's executable
 * test (an FGX2/FGX3 header, flags bit 2 for a dynamic program) in place of
 * a.out's; the trace variable set to `1'; argv[0] passed to the program;
 * FGX's wait(2) status macros in place of `union wait'; the two
 * fprintf/printf calls upstream gets wrong (no stream, a stream to printf)
 * written as intended.
 */
#include <stdio.h>
#include <fcntl.h>
#include <sys/wait.h>

extern char **environ;
extern char *malloc();

main(argc, argv)
int argc;
char *argv[];
{
    unsigned i, j;
    int fd, pid, status;
    char **nenvp, *nargv[2];
    unsigned char hdr[16];

    if (argc <= 1) {
        fprintf(stderr, "Usage: ldd file ...\n");
        exit(1);
    }
    for (i = 0; environ[i]; i++)
        ;
    if ((nenvp = (char **)malloc((i + 2) * sizeof (char *))) == NULL) {
        perror("ldd: out of memory for environment");
        exit(1);
    }
    nenvp[0] = "LD_TRACE_LOADED_OBJECTS=1";
    for (j = 0; j < i + 1; j++)
        nenvp[j + 1] = environ[j];

    for (i = 1; i < argc; i++) {
        if ((fd = open(argv[i], O_RDONLY)) == -1) {
            fprintf(stderr, "ldd: %s unreadable: ", argv[i]);
            perror("");
            continue;
        }
        j = read(fd, (char *)hdr, sizeof hdr);
        close(fd);
        if (j != sizeof hdr || hdr[0] != 'F' || hdr[1] != 'G' || hdr[2] != 'X' ||
            (hdr[3] != '2' && hdr[3] != '3')) {
            fprintf(stderr, "ldd: %s: not an executable\n", argv[i]);
            continue;
        }
        if (!(hdr[10] & 4)) {
            printf("%s: statically linked\n", argv[i]);
            continue;
        }
        if ((pid = fork()) == 0) {
            if (argc > 2)
                printf("%s:\n", argv[i]);
            fflush(stdout);
            nargv[0] = argv[i];
            nargv[1] = (char *)0;
            execve(argv[i], nargv, nenvp);
            fprintf(stderr, "ldd: %s execution failed: ", argv[i]);
            perror("");
            _exit(1);
        } else if (pid != -1) {
            while (wait(&status) != pid)
                ;
            if (WIFSIGNALED(status))
                fprintf(stderr, "ldd: %s execution failed due to signal %d\n",
                        argv[i], WTERMSIG(status));
            else if (WEXITSTATUS(status))
                fprintf(stderr, "ldd: %s execution failed: exit status %d\n",
                        argv[i], WEXITSTATUS(status));
        } else
            perror("ldd: fork() failed");
    }
    exit(0);
}
