/* vnprobe - does a name lookup give back every vnode reference it takes?
 *
 * FGX-Provenance: none
 *
 * apple/fgx#467: a directory vnode was seen at use count 8 with nothing
 * obviously holding it.  A reference namei takes and never returns does not
 * fail where it happens; the vnode just never becomes reclaimable, and the
 * pool (VNODE_POOL, 64) behaves like a smaller one until getnewvnode answers
 * ENFILE.
 *
 * SO THIS WALKS MORE DIRECTORIES THAN THE POOL HOLDS, once per namei path:
 * mkdir (CREATE, LOCKPARENT), a file created in each (CREATE), stat of that
 * file (LOOKUP), stat of the directory's ".." (the ".." arm), rename within
 * the directory (RENAME), unlink (DELETE) and rmdir (DELETE of a directory).
 * NDIRS is past 64 on purpose: one leaked parent reference per operation pins
 * every directory, and the phase after it cannot find a vnode.  A clean run is
 * also its own control -- each phase touches over 64 distinct vnodes, which
 * only succeeds if the pool really recycles.
 */
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>

#define NDIRS   80

static char p1[64], p2[64];
static struct stat st;
static int fails;

static void
name(buf, i, leaf)
    char *buf;
    int i;
    char *leaf;
{
    if (leaf)
        sprintf(buf, "/tmp/vnp/d%d/%s", i, leaf);
    else
        sprintf(buf, "/tmp/vnp/d%d", i);
}

/* One line per phase: how far it got and the errno that stopped it. */
static void
report(what, i)
    char *what;
    int i;
{
    if (i == NDIRS)
        printf("VN ok   %s x%d\n", what, NDIRS);
    else {
        printf("VN FAIL %s at %d errno=%d\n", what, i, errno);
        fails++;
    }
    fflush(stdout);
}

int
main()
{
    int i, fd;

    printf("VNSTART\n");
    fflush(stdout);
    mkdir("/tmp/vnp", 0755);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, (char *)0);
        if (mkdir(p1, 0755) < 0)
            break;
    }
    report("mkdir", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, "f");
        if ((fd = open(p1, O_WRONLY | O_CREAT, 0644)) < 0)
            break;
        close(fd);
    }
    report("create", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, "f");
        if (stat(p1, &st) < 0)
            break;
    }
    report("stat", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, "..");
        if (stat(p1, &st) < 0)
            break;
    }
    report("stat dotdot", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, "f");
        name(p2, i, "g");
        if (rename(p1, p2) < 0)
            break;
    }
    report("rename", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, "g");
        if (unlink(p1) < 0)
            break;
    }
    report("unlink", i);

    for (i = 0; i < NDIRS; i++) {
        name(p1, i, (char *)0);
        if (rmdir(p1) < 0)
            break;
    }
    report("rmdir", i);

    rmdir("/tmp/vnp");
    printf("VNDONE %d failed\n", fails);
    fflush(stdout);
    return (fails ? 1 : 0);
}
