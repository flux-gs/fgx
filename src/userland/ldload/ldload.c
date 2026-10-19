/*
 * ldload -- make shared libraries resident for the boot: libc first, then
 * each library /etc/ld.so.conf (or the file named) lists, in its order,
 * pinned (shared libc SP4 spec, section 7).  /etc/rc runs it after modload
 * has loaded ld.mod, the registry it fills.  A library listed above one it
 * needs is refused, naming both: cores stack in load order, and an
 * importer's core above its import's would waste the hole between them in
 * every process.  One line per library: version, banks, core base, time.
 *
 * Usage: ldload [conf]
 *
 * SunOS 4.1.3's ldconfig (lang/rtld/ldconfig.c) builds the cache rtld
 * reads at the same point in the boot; FGX has no cache -- the registry is
 * the resident set -- so ldload loads instead.
 *
 * FGX-Provenance: none
 */
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <sys/ldctl.h>

#define NLIB    16

static char lname[NLIB * 16];
static int lmajor[NLIB], skip[NLIB];
static int nlib, fails, nloaded, nresident;
static char buf[12288];
static struct ld_work w;
static struct timeval tv;

static long
ms()
{
    gettimeofday(&tv, (struct timezone *)0);
    return tv.tv_sec * 1000L + tv.tv_usec / 1000;
}

static int
load(name, major)
char *name;
int major;
{
    long t;
    int r, i;

    t = ms();
    r = ld_need(&w, name, major, 0, 1);
    if (r < 0) {
        fails++;
        return -1;
    }
    memset((char *)&w.blk, 0, sizeof w.blk);
    strcpy(w.blk.name, name);
    w.blk.major = major;
    ld_ctl(&w, LDS_LOOKUP);
    printf("ldload: %s.so.%d.%d: banks", name, major, w.blk.minor);
    for (i = 0; i < w.blk.nbanks; i++)
        printf(" %02X", w.blk.banks[i]);
    printf(", core $%04X", w.blk.core_base);
    if (r == 0) {
        printf(" (resident)\n");
        nresident++;
    } else {
        printf(", %ld ms\n", ms() - t);
        nloaded++;
    }
    return 0;
}

static void
readconf(path)
char *path;
{
    FILE *f;
    char line[80], nm[16], *p;
    int n, mj;

    f = fopen(path, "r");
    if (f == (FILE *)0)
        return;                         /* none is fine (spec section 7) */
    for (n = 1; fgets(line, sizeof line, f); n++) {
        if ((p = strchr(line, '#')) != 0)
            *p = 0;
        if (sscanf(line, "%15s", nm) != 1)
            continue;
        if (sscanf(line, "%15s %d", nm, &mj) != 2) {
            printf("ldload: %s: line %d: expected `library major'\n", path, n);
            continue;
        }
        if (nlib == NLIB) {
            printf("ldload: %s: more than %d libraries\n", path, NLIB);
            break;
        }
        strcpy(lname + 16 * nlib, nm);
        lmajor[nlib++] = mj;
    }
    fclose(f);
}

int
main(argc, argv)
int argc;
char **argv;
{
    struct ld_need need[4];
    int i, j, k, n, libcok;

    w.buf = buf;
    w.bufsz = sizeof buf;
    libcok = load("libc", 1) == 0;
    readconf(argc > 1 ? argv[1] : "/etc/ld.so.conf");
    for (i = 0; i < nlib; i++) {
        n = ld_needs(&w, lname + 16 * i, lmajor[i], need, 4);
        if (n < 0) {
            skip[i] = 1;
            fails++;
        }
        for (j = 0; j < n; j++)
            for (k = i + 1; k < nlib; k++)
                if (strcmp(need[j].name, lname + 16 * k) == 0) {
                    printf("ldload: %s needs %s, which is listed after it\n",
                           lname + 16 * i, need[j].name);
                    skip[i] = 1;
                }
    }
    for (i = 0; i < nlib; i++)
        if (!skip[i])
            load(lname + 16 * i, lmajor[i]);
    printf("ldload: %d loaded, %d resident\n", nloaded, nresident);
    if (!libcok)
        return 2;
    return fails != 0;
}
