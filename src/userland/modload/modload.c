/* FGX-Origin: original -- FGX code.  Nothing here derives from the Regents'
 * work.  It NAMES NetBSD only to say where the responsibility for loading a
 * module belongs -- userland -- which is a design citation, not a port:
 * NetBSD has no SYS_MODLOAD and does not stream a bank.  2.11BSD has no
 * loadable modules at all.
 */
/* modload(8) -- install a kernel module, from userland.
 *
 * WHERE BSD RUNS IT FROM.  NetBSD 0.9 loads modules with a userland
 * modload(8) (sbin/modload, over sys/kern/kern_lkm.c); FGX read them in the
 * kernel because the boot needed them before there was a userland to ask.
 * That is what this replaces -- `Mod_LoadConf' and its Fs_ReadN, which answers EBADF for a descriptor on a
 * UFS root and is why a UFS boot brings up four modules and misses five.
 *
 * ONLY THE READ MOVES.  Bank allocation, relocation and mod_init stay
 * kernel-side behind SYS_MODLOAD; this walks the file and hands over chunks.
 * Plan: docs/history/plans/2026-09-01-userland-modload.md, increment C1.
 *
 * THE BUFFER IS A GLOBAL AND MUST STAY ONE.  SYS_MODLOAD's `data' reads the
 * chunk out of the caller's DATA bank -- the kernel takes the bank from
 * _Sys_CallerBank, not from the pointer -- so a stack local would name an
 * offset in bank 0 and the kernel would copy whatever sits at that offset in
 * the data bank instead.  Silent and wrong, which is the worst shape.
 */
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#define SYS_MODLOAD 110
#define ML_BEGIN    0
#define ML_DATA     1
#define ML_END      2
#define ML_ABORT    3

#define CHUNK       512     /* what Mod_Load already read at a time */
#define FGXM_HDR    40      /* include/fgxm.s FGXM_HEADER_SZ: v1's 16 plus
                             * name[16], modver[2] and 6 reserved */

char mlbuf[CHUNK];          /* data bank -- see the header */
char mlpath[80];

/* EVERY FAILURE AFTER `begin' HAS TO SAY SO.  A session that is opened and
 * never closed leaves the kernel answering EBUSY to every later `begin' for
 * the rest of the boot, and leaves the extent this module claimed standing
 * against the modules that follow it.  ML_ABORT gives both back.
 */
int
mlfail(name, why, fd)
char *name;
char *why;
int   fd;
{
    (void)__syscall(SYS_MODLOAD, ML_ABORT, 0, 0);
    printf("modload: %s: %s\n", name, why);
    if (fd >= 0)
        close(fd);
    return (1);
}

/* load_one -- install ONE module by name.  0 on success, 1 on failure.
 *
 * SPLIT OUT OF main SO ONE PROCESS CAN LOAD SEVERAL: /etc/rc brings up its
 * modules with one invocation, one fork/exec pair rather than one per module,
 * the last slot, before the user had a shell.  Looping here costs one. */
static int load_one(name)
char *name;
{
    int fd, n;

    strcpy(mlpath, "/lib/modules/");
    strcat(mlpath, name);

    fd = open(mlpath, O_RDONLY);
    if (fd < 0) {
        printf("modload: %s: cannot open\n", mlpath);
        return (1);
    }

    /* `begin' claims the SESSION, not a bank: which bank this module goes in
     * is its ordinal's business and is not known until the header arrives. */
    (void)__syscall(SYS_MODLOAD, ML_BEGIN, 0, 0);
    if (__syscall_c() == 0) {
        printf("modload: %s: busy\n", name);
        close(fd);
        return (1);
    }

    /* THE HEADER GOES OVER AS ITS OWN CHUNK, which the kernel requires: it
     * cannot place the text until it has read the placement offset out of the
     * header, and reading 40 bytes here is easier than carving them there. */
    n = read(fd, mlbuf, FGXM_HDR);
    if (n != FGXM_HDR)
        return (mlfail(name, "short header", fd));
    (void)__syscall(SYS_MODLOAD, ML_DATA,
                    (unsigned)(unsigned long)mlbuf, n);
    if (__syscall_c() == 0)
        return (mlfail(name, "header rejected", fd));

    while ((n = read(fd, mlbuf, CHUNK)) > 0) {
        (void)__syscall(SYS_MODLOAD, ML_DATA,
                        (unsigned)(unsigned long)mlbuf, n);
        if (__syscall_c() == 0)
            return (mlfail(name, "write failed", fd));
    }
    close(fd);

    /* `end' zeroes BSS, walks VTDR and runs mod_init.  The header was
     * validated, placed and its range claimed back at the header chunk --
     * before any of this module's bytes were written -- so what can still fail
     * here is the image itself and its own mod_init.  ML_END closes the
     * session on both outcomes, so this failure needs no abort. */
    (void)__syscall(SYS_MODLOAD, ML_END, 0, 0);
    if (__syscall_c() == 0) {
        printf("modload: %s: init failed\n", name);
        return (1);
    }

    /* SILENT ON SUCCESS.  The KERNEL announces a module that came up --
     * `module: <name> loaded', src/kernel/modload.s, printed only after
     * mod_init actually returned success -- so this printf put a second line
     * about one event on every boot, in the conf file's spelling (SERIAL)
     * rather than the module's own (serial).  A tool that succeeds says
     * nothing, which is what every other tool on this volume does; the
     * failures above still speak, and they are the half worth having. */
    return (0);
}

/* THE ARGUMENTS ARE A LIST, and every one is attempted: a module that will not
 * load must not stop the ones after it, exactly as /etc/rc's separate lines
 * would not have.  The exit status is the LAST failure's, so a caller that
 * tests it still learns that something went wrong. */
int main(argc, argv)
int    argc;
char **argv;
{
    int i, rc;

    if (argc < 2) {
        printf("usage: modload name [name ...]\n");
        return (1);
    }

    rc = 0;
    for (i = 1; i < argc; i++) {
        if (load_one(argv[i]) != 0)
            rc = 1;
    }
    return (rc);
}
