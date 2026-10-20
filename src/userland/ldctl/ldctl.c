/*
 * ldctl -- drives SYS_LDCTL (shared libc SP4) directly, with no library:
 * the registry's services and the kernel's hooks.  One mode per argument;
 * prints `LDC FAIL <mode> <what>' per failed check, and `LDC <mode> ok' once,
 * after the last check, only if none failed -- so a hang shows no ok.
 *
 * FGX-Provenance: none
 *
 * Spec: docs/history/plans/2026-09-30-shared-libc-sp4-design.md, section 9.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <sys/ldctl.h>

/* The parameter block (spec section 4): a static, so the kernel can read
 * it -- an fcc local lives on the bank-0 stack, which a syscall cannot. */
static struct ldblk blk;
static int fails;

static int
ldctl(svc)
int svc;
{
    int r;

    r = (int)__syscall(SYS_LDCTL, svc, (unsigned)(unsigned long)(char *)&blk,
                       (unsigned)((unsigned long)(char *)&blk >> 16));
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    return r;
}

static void
say(mode, ok, what)
char *mode, *what;
int ok;
{
    if (!ok) {
        printf("LDC FAIL %s %s\n", mode, what);
        fails++;
    }
}

static void
name(s, major)
char *s;
int major;
{
    memset((char *)&blk, 0, sizeof blk);
    strcpy(blk.name, s);
    blk.major = major;
}

/* A hook selector from user code is refused, with or without ld.mod. */
static int
selector()
{
    name("libx", 1);
    say("selector", ldctl(0x80) == -1 && errno == ENOSYS, "hook selector");
    say("selector", ldctl(0x84) == -1 && errno == ENOSYS, "reclaim selector");
    return 0;
}

/* The arena's bottom as this boot left it: libc's base when ldload has
 * made it resident, else HEAP_LIM. */
static unsigned
arena()
{
    name("libc", 1);
    if (ldctl(LDS_LOOKUP) >= 0 && blk.state == LD_READY)
        return blk.core_base;
    return 0xFFF8;
}

/* The services in one process: acquire, grant (the arena), commit, a
 * second acquire, majors, lookup, the selector, the grant cap, and a slot
 * kept for one core size. */
static int
basic()
{
    int r, row, yrow, b0;
    unsigned top;

    top = arena();
    name("libx", 1);
    r = ldctl(LDS_ACQUIRE);
    say("basic", r == 1, "first acquire says load");
    row = blk.row;
    blk.nbanks = 2;
    blk.core_size = 100;
    r = ldctl(LDS_GRANT);
    say("basic", r >= 0 && blk.nbanks == 2 && blk.banks[0] && blk.banks[1] &&
        blk.banks[0] != blk.banks[1], "grant two banks");
    say("basic", blk.core_base == top - 100, "grant: a core under the arena's bottom");
    b0 = blk.banks[0];
    blk.pinned = 0;
    say("basic", ldctl(LDS_COMMIT) >= 0 && blk.core_base == top - 100,
        "commit keeps the base");
    name("libx", 1);
    say("basic", ldctl(LDS_ACQUIRE) == 0 && blk.users == 1 &&
        blk.banks[0] == b0 && blk.row == row, "acquire again: no double count");
    name("liby", 1);
    ldctl(LDS_ACQUIRE);
    yrow = blk.row;
    blk.nbanks = 1;
    blk.core_size = 50;
    ldctl(LDS_GRANT);
    say("basic", blk.core_base == top - 150, "second core stacks below");
    ldctl(LDS_COMMIT);
    name("liby", 2);
    say("basic", ldctl(LDS_ACQUIRE) == 1 && blk.row != yrow,
        "another major is another row");
    ldctl(LDS_ABORT);                   /* liby 2 holds no banks */
    name("libnone", 1);
    say("basic", ldctl(LDS_LOOKUP) == -1 && errno == ENOENT, "lookup absent");
    say("basic", ldctl(0x80) == -1 && errno == ENOSYS, "hook selector refused");
    name("libz", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 9;
    blk.core_size = 10;
    say("basic", ldctl(LDS_GRANT) == -1 && errno == EINVAL, "grant past 8");
    ldctl(LDS_ABORT);
    name("libw", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 1;
    blk.core_size = 20;
    ldctl(LDS_GRANT);
    ldctl(LDS_ABORT);                   /* FREE; its slot and bank kept */
    name("libw", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 0;
    blk.core_size = 30;
    say("basic", ldctl(LDS_GRANT) == -1 && errno == EINVAL,
        "a slot holds one core size");
    blk.core_size = 20;
    say("basic", ldctl(LDS_GRANT) >= 0 && blk.nbanks == 1, "the same size reloads");
    ldctl(LDS_ABORT);
    return 0;
}

/* Make a row READY in this process: acquire, grant n banks, commit. */
static int
ready(s, n, size, pinned, deps)
char *s;
int n, size, pinned;
unsigned deps;
{
    name(s, 1);
    if (ldctl(LDS_ACQUIRE) != 1)
        return -1;
    blk.nbanks = n;
    blk.core_size = size;
    if (ldctl(LDS_GRANT) < 0)
        return -1;
    blk.pinned = pinned;
    blk.deps = deps;
    return ldctl(LDS_COMMIT);
}

static int
look(s)
char *s;
{
    name(s, 1);
    return ldctl(LDS_LOOKUP);
}

/* A child that owns s LOADING until it is killed.  FGX's pause() is a
 * one-second sleep that returns, so it loops: a lone pause() would end, the
 * child would exit, and its exit hook would free the row. */
static int
owner(s)
char *s;
{
    int pid;

    pid = fork();
    if (pid == 0) {
        name(s, 1);
        if (ldctl(LDS_ACQUIRE) != 1)
            _exit(9);
        blk.nbanks = 1;
        ldctl(LDS_GRANT);
        for (;;)
            pause();
    }
    return pid;
}

static int
reap(pid)
int pid;
{
    int w, st;

    while ((w = wait(&st)) != pid && w >= 0)
        ;
    return st;
}

static int gotusr;

static void
onusr(sig)
int sig;
{
    gotusr = 1;
}

/* The child of a fork uses what its parent uses; its exit releases it. */
static int
forkm()
{
    int pid, st;

    say("fork", ready("libf", 1, 10, 0, 0) >= 0, "make libf ready");
    pid = fork();
    if (pid == 0) {
        look("libf");
        _exit(blk.users == 2 ? 0 : 1);
    }
    st = reap(pid);
    look("libf");
    say("fork", st == 0, "the child is a second user");
    say("fork", blk.users == 1, "the child's exit releases it");
    return 0;
}

/* An exec releases the old image's uses; a failed exec keeps them. */
static int
execm()
{
    int pid, st;

    say("exec", ready("libe", 1, 10, 0, 0) >= 0, "make libe ready");
    pid = vfork();
    if (pid == 0) {
        execl("/testbin/ldctl", "ldctl", "look", "libe", (char *)0);
        _exit(9);
    }
    st = reap(pid);
    say("exec", WIFEXITED(st) && WEXITSTATUS(st) == 1,
        "the exec'd image is not a user");
    pid = vfork();
    if (pid == 0) {
        execl("/nonexistent/x", "x", (char *)0);
        look("libe");
        _exit(blk.users);
    }
    st = reap(pid);
    say("exec", WIFEXITED(st) && WEXITSTATUS(st) == 2,
        "a failed exec keeps its uses");
    return 0;
}

/* Two first users: the second waits until the first's row is settled; the
 * first killed, the second takes the row over with its banks. */
static int
race()
{
    int a, b, sb, kept;

    a = owner("librace");
    sleep(1);
    look("librace");
    kept = blk.banks[0];
    say("race", blk.state == 2 && kept != 0, "the owner holds it loading");
    b = fork();
    if (b == 0) {
        name("librace", 1);
        if (ldctl(LDS_ACQUIRE) != 1)
            _exit(3);
        blk.core_size = 10;
        _exit(ldctl(LDS_COMMIT) >= 0 ? 0 : 4);
    }
    sleep(2);
    look("librace");
    say("race", blk.state == 2, "the second user waits");
    kill(a, SIGKILL);
    reap(a);
    sb = reap(b);
    look("librace");
    say("race", sb == 0, "the second user loads it");
    say("race", blk.state == 3 && blk.users == 0 && blk.banks[0] == kept,
        "ready, with the first owner's bank");
    return 0;
}

/* A signal ends a wait with EINTR. */
static int
intr()
{
    int a, b, sb;

    a = owner("libi");
    sleep(1);
    b = fork();
    if (b == 0) {
        signal(SIGUSR1, onusr);
        name("libi", 1);
        _exit(ldctl(LDS_ACQUIRE) == -1 && errno == EINTR ? 0 : 1);
    }
    sleep(2);
    kill(b, SIGUSR1);
    sb = reap(b);
    kill(a, SIGKILL);
    reap(a);
    look("libi");
    say("intr", sb == 0, "the waiter gets EINTR");
    say("intr", blk.state == 1 && blk.users == 0, "the owner's exit freed it");
    return 0;
}

/* A waiter killed asleep dies; the row is untouched. */
static int
killm()
{
    int a, b, sb;

    a = owner("libk");
    sleep(1);
    b = fork();
    if (b == 0) {
        name("libk", 1);
        ldctl(LDS_ACQUIRE);
        _exit(5);
    }
    sleep(2);
    kill(b, SIGKILL);
    sb = reap(b);
    look("libk");
    say("kill", WIFSIGNALED(sb), "the waiter died of the signal");
    say("kill", blk.state == 2 && blk.users == 0, "the row is still loading");
    kill(a, SIGKILL);
    reap(a);
    return 0;
}

/* A stopped child dies of SIGKILL: psignal() makes a stopped process
 * runnable for it (2.11BSD kern_sig.c).  A hang here shows no ok. */
static int
stopkill()
{
    int pid, st;

    pid = fork();
    if (pid == 0)
        for (;;)
            pause();
    sleep(1);
    kill(pid, SIGSTOP);
    sleep(1);
    kill(pid, SIGKILL);
    st = reap(pid);
    say("stopkill", WIFSIGNALED(st) && WTERMSIG(st) == SIGKILL,
        "a stopped child killed");

    /* ...and dies of it on resuming, before it runs another instruction of
     * its own: a child that stopped itself must not write after the kill.
     * It sleeps first: until a forked child's first sleep its parent is
     * held, so a child stopping before then would hold the parent too. */
    close(creat("/tmp/stopkill", 0644));
    pid = fork();
    if (pid == 0) {
        int fd;

        fd = open("/tmp/stopkill", 1);
        sleep(1);
        kill(getpid(), SIGSTOP);
        write(fd, "X", 1);
        _exit(0);
    }
    sleep(3);
    kill(pid, SIGKILL);
    st = reap(pid);
    say("stopkill", WIFSIGNALED(st) && WTERMSIG(st) == SIGKILL,
        "a self-stopped child killed");
    {
        char c;
        int fd;

        fd = open("/tmp/stopkill", 0);
        say("stopkill", fd >= 0 && read(fd, &c, 1) == 0,
            "no instruction after the kill");
        close(fd);
    }
    return 0;
}

/* A forked child stopped before its first sleep does not hold its parent
 * stopped with it: 2.11BSD leaves a stop pending while the child still
 * holds its parent (kern_sig.c issignal(), `mask &= ~stopsigmask'), and it
 * acts once the child lets go.  A hang here shows no ok. */
static int
vforkstop()
{
    int pid, st, w;

    pid = fork();
    if (pid == 0) {
        kill(getpid(), SIGSTOP);
        for (;;)
            pause();
    }
    sleep(2);
    w = waitpid(pid, &st, WUNTRACED);
    say("vforkstop", w == pid && WIFSTOPPED(st), "stopped once it let go");
    kill(pid, SIGKILL);
    reap(pid);
    return 0;
}

/* Only the loading owner may grant, commit or abort. */
static int
eperm()
{
    int a;

    a = owner("libp");
    sleep(1);
    look("libp");
    blk.nbanks = 1;
    say("eperm", ldctl(LDS_GRANT) == -1 && errno == EPERM, "grant");
    look("libp");
    say("eperm", ldctl(LDS_COMMIT) == -1 && errno == EPERM, "commit");
    look("libp");
    say("eperm", ldctl(LDS_ABORT) == -1 && errno == EPERM, "abort");
    kill(a, SIGKILL);
    reap(a);
    return 0;
}

/* Grant banks through throwaway rows until s's row holds none: the pool
 * runs dry, and Bank_Alloc's reclaim frees an unused row's banks. */
static int
drainm(s)
char *s;
{
    int pid, n;
    char dn[16];

    for (n = 0; n < 12; n++) {
        if (look(s) < 0) {
            say("drain", 0, s);
            return 1;
        }
        if (blk.nbanks == 0)
            return 0;
        sprintf(dn, "drain%d", n);
        pid = fork();
        if (pid == 0) {
            name(dn, 1);
            ldctl(LDS_ACQUIRE);
            blk.nbanks = 8;
            blk.core_size = 1;
            ldctl(LDS_GRANT);
            ldctl(LDS_COMMIT);
            _exit(0);
        }
        reap(pid);
    }
    look(s);
    say("drain", blk.nbanks == 0, s);
    return 0;
}

/* The pool runs dry through ld.mod's own grants; reclaim gives back an
 * unused row's banks, READY or FREE, never a pinned row's.  (malloc cannot
 * drain it: neither its sbrk nor its big blocks call Bank_Alloc.) */
static int
reclaimm()
{
    int pid, n, base;
    char dn[16];

    pid = fork();
    if (pid == 0)
        _exit(ready("librc", 3, 10, 0, 0) >= 0 ? 0 : 1);
    reap(pid);
    pid = fork();
    if (pid == 0)
        _exit(ready("libpin", 3, 10, 1, 0) >= 0 ? 0 : 1);
    reap(pid);
    pid = fork();
    if (pid == 0) {
        name("libab", 1);
        ldctl(LDS_ACQUIRE);
        blk.nbanks = 2;
        ldctl(LDS_GRANT);
        _exit(ldctl(LDS_ABORT) >= 0 ? 0 : 1);
    }
    reap(pid);
    look("librc");
    base = blk.core_base;
    say("reclaim", blk.nbanks == 3 && blk.users == 0, "librc unused, banks held");
    for (n = 0; n < 13; n++) {
        look("librc");
        if (blk.nbanks == 0) {
            look("libab");
            if (blk.nbanks == 0)
                break;
        }
        sprintf(dn, "drain%d", n);
        pid = fork();
        if (pid == 0) {
            name(dn, 1);
            ldctl(LDS_ACQUIRE);
            blk.nbanks = 8;
            blk.core_size = 1;
            ldctl(LDS_GRANT);
            ldctl(LDS_COMMIT);
            _exit(0);
        }
        reap(pid);
    }
    look("librc");
    say("reclaim", blk.nbanks == 0 && blk.state == 1 && blk.core_base == base,
        "librc reclaimed, its slot kept");
    look("libab");
    say("reclaim", blk.nbanks == 0, "an aborted row reclaimed too");
    look("libpin");
    say("reclaim", blk.nbanks == 3, "a pinned row kept");
    return 0;
}

/* Forty children forked and exited: every one counted in and out. */
static int
reuse()
{
    int i, pid;

    say("reuse", ready("libr", 1, 10, 0, 0) >= 0, "make libr ready");
    for (i = 0; i < 40; i++) {
        pid = fork();
        if (pid == 0)
            _exit(0);
        reap(pid);
    }
    look("libr");
    say("reuse", blk.users == 1, "users back to one");
    return 0;
}

/* A row a READY row imports from is reclaimed only after it: the
 * importer's bank bytes name the import's banks.  libdlo holds as many
 * banks as a drain takes, so without the rule its reclaim alone satisfies
 * a drain and libdhi, its importer, is seen still holding its bank.  A
 * pinned importer keeps its import for the boot.  Four, not eight: libc,
 * resident from boot, leaves the pool too few for eight. */
static int
depsm()
{
    int pid, n, lo, pb, after;
    char dn[16];

    pid = fork();
    if (pid == 0)
        _exit(ready("libdlo", 4, 10, 0, 0) >= 0 ? 0 : 1);
    reap(pid);
    look("libdlo");
    lo = blk.row;
    say("deps", blk.state == LD_READY && blk.nbanks == 4, "make libdlo ready");
    pid = fork();
    if (pid == 0)
        _exit(ready("libdhi", 1, 10, 0, 1 << lo) >= 0 ? 0 : 1);
    reap(pid);
    look("libdhi");
    say("deps", blk.state == LD_READY && blk.nbanks == 1, "make libdhi ready");
    pid = fork();
    if (pid == 0)
        _exit(ready("libpbase", 2, 10, 0, 0) >= 0 ? 0 : 1);
    reap(pid);
    look("libpbase");
    pb = blk.row;
    say("deps", blk.state == LD_READY && blk.nbanks == 2, "make libpbase ready");
    pid = fork();
    if (pid == 0)
        _exit(ready("libptop", 1, 10, 1, 1 << pb) >= 0 ? 0 : 1);
    reap(pid);
    look("libptop");
    say("deps", blk.state == LD_READY && blk.pinned, "make libptop ready, pinned");
    after = -1;
    for (n = 0; n < 12; n++) {
        look("libdlo");
        if (blk.nbanks == 0 && after < 0) {
            look("libdhi");
            say("deps", blk.nbanks == 0, "an importer goes before its import");
            after = n;
        }
        if (after >= 0 && n >= after + 2)
            break;
        sprintf(dn, "drain%d", n);
        pid = fork();
        if (pid == 0) {
            name(dn, 1);
            ldctl(LDS_ACQUIRE);
            blk.nbanks = 4;
            blk.core_size = 1;
            ldctl(LDS_GRANT);
            ldctl(LDS_COMMIT);
            _exit(0);
        }
        reap(pid);
    }
    say("deps", after >= 0, "the import reclaimed");
    look("libpbase");
    say("deps", blk.nbanks == 2, "a pinned importer keeps its import");
    return 0;
}

/* Hold `size' bytes of the arena for the boot: a slot taken, then aborted. */
static int
padm(size)
int size;
{
    name("libpad", 1);
    if (ldctl(LDS_ACQUIRE) != 1)
        return 1;
    blk.nbanks = 1;
    blk.core_size = size;
    if (ldctl(LDS_GRANT) < 0)
        return 1;
    ldctl(LDS_ABORT);
    printf("LDC pad %u\n", blk.core_base);
    return 0;
}

/* s's row: its state, users and banks, one line each, for a probe to
 * compare across runs. */
static int
rowm(s)
char *s;
{
    int i;

    if (look(s) < 0) {
        say("row", 0, s);
        return 1;
    }
    printf("LDC row state=%d users=%d nbanks=%d\n", blk.state, blk.users,
           blk.nbanks);
    printf("LDC base %04x\n", blk.core_base);
    printf("LDC banks");
    for (i = 0; i < blk.nbanks; i++)
        printf(" %02x", blk.banks[i]);
    printf("\n");
    return 0;
}

/* Poll until s's row is LOADING with banks granted -- a first user is
 * reading the library into them -- and stop that user, so a probe can
 * act while the load is in progress. */
static int
waitload(s, pid)
char *s;
int pid;
{
    unsigned n;

    for (n = 0; n < 20000; n++)
        if (look(s) >= 0 && blk.state == LD_LOADING && blk.nbanks > 0) {
            if (pid > 0)
                kill(pid, SIGSTOP);
            printf("LDC loading %s\n", s);
            return 0;
        }
    say("waitload", 0, s);
    return 1;
}

/* The loader refuses a library file (header flags bit 1).  Not through the
 * shell: 2.11BSD's sh runs a file that fails with ENOEXEC as a script
 * (vendor/2.11BSD/usr/bin/sh/service.c). */
static int
libexec()
{
    int pid, st;

    pid = vfork();
    if (pid == 0) {
        execl("/testbin/libtermlib.so", "libtermlib.so", (char *)0);
        _exit(errno == ENOEXEC ? 0 : 1);
    }
    wait(&st);
    say("libexec", pid > 0 && st == 0, "exec of a library is ENOEXEC");
    return 0;
}

int
main(argc, argv)
int argc;
char **argv;
{
    if (argc < 2)
        return 2;
    if (strcmp(argv[1], "selector") == 0)
        selector();
    else if (strcmp(argv[1], "basic") == 0)
        basic();
    else if (strcmp(argv[1], "libexec") == 0)
        libexec();
    else if (strcmp(argv[1], "fork") == 0)
        forkm();
    else if (strcmp(argv[1], "exec") == 0)
        execm();
    else if (strcmp(argv[1], "race") == 0)
        race();
    else if (strcmp(argv[1], "intr") == 0)
        intr();
    else if (strcmp(argv[1], "kill") == 0)
        killm();
    else if (strcmp(argv[1], "stopkill") == 0)
        stopkill();
    else if (strcmp(argv[1], "vforkstop") == 0)
        vforkstop();
    else if (strcmp(argv[1], "eperm") == 0)
        eperm();
    else if (strcmp(argv[1], "reclaim") == 0)
        reclaimm();
    else if (strcmp(argv[1], "reuse") == 0)
        reuse();
    else if (strcmp(argv[1], "deps") == 0)
        depsm();
    else if (strcmp(argv[1], "pad") == 0 && argc > 2)
        return padm(atoi(argv[2]));
    else if (strcmp(argv[1], "drain") == 0 && argc > 2)
        drainm(argv[2]);
    else if (strcmp(argv[1], "row") == 0 && argc > 2)
        rowm(argv[2]);
    else if (strcmp(argv[1], "waitload") == 0 && argc > 2)
        waitload(argv[2], argc > 3 ? atoi(argv[3]) : 0);
    else if (strcmp(argv[1], "look") == 0 && argc > 2) {
        look(argv[2]);
        printf("LDC look users=%d\n", blk.users);
        return blk.users;
    }
    else
        return 2;
    if (fails == 0)
        printf("LDC %s ok\n", argv[1]);
    return fails != 0;
}
