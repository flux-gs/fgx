/* forkpair -- concurrent fork (apple/fgx#494).  One mode per run:
 *   order   the parent runs while its child sleeps:        FP ORDER ok
 *   bytes   each side keeps its own global, heap byte and stack local
 *           across alternating sleeps:                      FP BYTES ok
 *   orphan  the parent exits at once; the sleeping child is reparented to
 *           init, then execs echo:                          FP ORPHAN ok
 *   three   parent, child and grandchild each keep their own bytes:
 *                                                            FP THREE ok
 *   hwm     ps's heap high-water mark for a parked member is its own:
 *                                                            FP HWM ok
 *   lim     the break stops at the HEAP_LIM cell ($FFF8, include/kernel.s),
 *           and an exec'd program starts with the cell at its seed:
 *                                                            FP LIM ok
 *   irq     a fork child and a vfork child each resume in user mode with
 *           interrupts enabled, as any syscall returns:     FP IRQ ok
 * bytes and three also require that the parent ran while the others slept:
 * the parent creates a marker after its own sleeps, and the last sleeper
 * looks for it.  Every mode prints FP ... FAIL on a wrong answer. */
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <fgx.h>

int fork();
int vfork();
int wait();
int getppid();
int getpid();
char *sbrk();
void _exit();
int execl();
int sleep();
int brk();
int open();
int close();
int unlink();
int access();

int g;
static struct procinfo plist[16];

/* Set all three tiers to v, sleep s seconds, then check them. */
static int pflag;

/* The processor status byte, as user code sees it. */
static void
getp()
{
    __asm("PHP", "SEP #$20", "PLA", "STA _forkpair_pflag", "REP #$30");
}

static int
tiers(char *h, int v, int s)
{
    int loc;

    g = v;
    h[0] = v;
    loc = v;
    if (s)
        sleep(s);
    return g == v && h[0] == v && loc == v;
}

static void
mark(char *path)
{
    close(open(path, O_WRONLY | O_CREAT, 0644));
}

/* An address in this process's data bank: the bank of any heap address. */
static char *
at(char *h, unsigned off)
{
    return (char *)(((unsigned long)h & 0xFF0000L) | (unsigned long)off);
}

/* The heap limit cell, HEAP_LIM (include/kernel.s). */
static unsigned *
limp(char *h)
{
    return (unsigned *)at(h, 0xFFF8);
}

static unsigned
hwm_of(int pid)
{
    int n, i;

    n = procs((char *)plist, 16);
    for (i = 0; i < n; i++)
        if (plist[i].pid == pid)
            return plist[i].heaphwm;
    return 0;
}

int
main(int argc, char **argv)
{
    char *h, *m;
    int pid, st, ok, kid;
    unsigned mine, its;

    m = argc > 1 ? argv[1] : "";
    h = sbrk(64);
    if (h == (char *)-1) { printf("FP FAIL sbrk\n"); return 1; }

    if (strcmp(m, "limcell") == 0)
        return *limp(h) == 0xFFF8 ? 0 : 4;
    if (strcmp(m, "lim") == 0) {
        unsigned *lp;
        char *r;
        int i;

        lp = limp(h);
        if (*lp != 0xFFF8) { printf("FP LIM FAIL seed %x\n", *lp); return 1; }
        *lp = 0xE000;
        if (brk(at(h, 0xDF00)) != 0) { printf("FP LIM FAIL park\n"); return 1; }
        if (brk(at(h, 0xE000)) != 0) { printf("FP LIM FAIL reach\n"); return 1; }
        if (brk(at(h, 0xE001)) == 0) { printf("FP LIM FAIL ceiling\n"); return 1; }
        *lp = 0xFFFF;                   /* garbage above the seed reads as it */
        if (brk(at(h, 0xFFF9)) == 0) { printf("FP LIM FAIL clamp\n"); return 1; }
        *lp = 0xE000;
        if (brk(h + 64) != 0) { printf("FP LIM FAIL unpark\n"); return 1; }
        r = at(h, 0xE000);
        for (i = 0; i < 256; i++)
            r[i] = 'P';
        /* Deferred: the child never sleeps, so the parent is parked and
         * restored around it (_Img_BankMove). */
        pid = fork();
        if (pid == 0) {
            for (i = 0; i < 256; i++)
                r[i] = 'C';
            _exit(0);
        }
        wait(&st);
        for (i = 0; i < 256 && r[i] == 'P'; i++)
            ;
        if (i != 256) { printf("FP LIM FAIL deferred %d\n", i); return 1; }
        /* Concurrent: the child sleeps and the parent runs, so the two
         * images are exchanged (Img_Swap); each must see only its own. */
        unlink("/tmp/fp.lim");
        pid = fork();
        if (pid == 0) {
            for (i = 0; i < 256; i++)
                r[i] = 'C';
            sleep(2);
            ok = access("/tmp/fp.lim", 0) == 0;
            for (i = 0; i < 256; i++)
                if (r[i] != 'C')
                    ok = 0;
            _exit(ok ? 0 : 5);
        }
        for (i = 0; i < 256 && r[i] == 'P'; i++)
            ;
        ok = i == 256;
        mark("/tmp/fp.lim");
        wait(&st);
        if (!ok || st != 0) {
            printf("FP LIM FAIL concurrent %d %x\n", i, st);
            return 1;
        }
        /* An odd limit with the break on it: the last heap byte and the
         * first reserved byte share a word, which the exchange must swap
         * once, not once per range. */
        *lp = 0xE001;
        if (brk(at(h, 0xE001)) != 0) { printf("FP LIM FAIL oddbrk\n"); return 1; }
        for (i = 0; i < 256; i++)
            r[i] = 'P';
        unlink("/tmp/fp.odd");
        pid = fork();
        if (pid == 0) {
            for (i = 0; i < 256; i++)
                r[i] = 'C';
            sleep(2);
            ok = access("/tmp/fp.odd", 0) == 0;
            for (i = 0; i < 256; i++)
                if (r[i] != 'C')
                    ok = 0;
            _exit(ok ? 0 : 7);
        }
        for (i = 0; i < 256 && r[i] == 'P'; i++)
            ;
        ok = i == 256;
        mark("/tmp/fp.odd");
        wait(&st);
        if (!ok || st != 0) { printf("FP LIM FAIL odd %d %x\n", i, st); return 1; }
        *lp = 0xE000;
        if (brk(h + 64) != 0) { printf("FP LIM FAIL unpark2\n"); return 1; }
        pid = fork();
        if (pid == 0) {
            execl("/testbin/forkpair", "forkpair", "limcell", (char *)0);
            _exit(6);
        }
        wait(&st);
        if (st != 0) { printf("FP LIM FAIL exec seed %x\n", st); return 1; }
        printf("FP LIM ok\n");
        return 0;
    }
    if (strcmp(m, "irq") == 0) {
        ok = 1;
        if ((pid = fork()) == 0) {
            getp();
            _exit(pflag & 4 ? 1 : 0);   /* the 65816's I flag */
        }
        wait(&st);
        if (st != 0) { printf("FP IRQ FAIL fork\n"); ok = 0; }
        if ((pid = vfork()) == 0) {
            getp();
            _exit(pflag & 4 ? 1 : 0);
        }
        wait(&st);
        if (st != 0) { printf("FP IRQ FAIL vfork\n"); ok = 0; }
        if (ok)
            printf("FP IRQ ok\n");
        return 0;
    }
    if (strcmp(m, "order") == 0) {
        unlink("/tmp/fp.order");
        pid = fork();
        if (pid == 0) {
            sleep(2);
            _exit(access("/tmp/fp.order", 0) == 0 ? 0 : 1);
        }
        mark("/tmp/fp.order");
        wait(&st);
        printf("FP ORDER %s\n", st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "bytes") == 0) {
        unlink("/tmp/fp.bytes");
        pid = fork();
        if (pid == 0) {
            ok = tiers(h, 22, 1) && tiers(h, 23, 3);
            ok = ok && access("/tmp/fp.bytes", 0) == 0 && tiers(h, 24, 0);
            _exit(ok ? 0 : 3);
        }
        ok = tiers(h, 11, 1) && tiers(h, 12, 1) && tiers(h, 13, 0);
        mark("/tmp/fp.bytes");
        wait(&st);
        printf("FP BYTES %s\n", ok && st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "orphan") == 0) {
        pid = fork();
        if (pid == 0) {
            sleep(2);
            if (getppid() != 1)
                execl("/bin/echo", "echo", "FP ORPHAN FAIL", (char *)0);
            else
                execl("/bin/echo", "echo", "FP ORPHAN ok", (char *)0);
            _exit(127);
        }
        _exit(0);
    }
    if (strcmp(m, "three") == 0) {
        unlink("/tmp/fp.three");
        pid = fork();
        if (pid == 0) {
            kid = fork();
            if (kid == 0) {
                ok = tiers(h, 33, 1) && tiers(h, 34, 4);
                ok = ok && access("/tmp/fp.three", 0) == 0 && tiers(h, 35, 0);
                _exit(ok ? 0 : 5);
            }
            ok = tiers(h, 22, 1) && tiers(h, 23, 1) && tiers(h, 24, 0);
            wait(&st);
            _exit(ok && st == 0 ? 0 : 4);
        }
        ok = tiers(h, 11, 1) && tiers(h, 12, 1) && tiers(h, 13, 0);
        mark("/tmp/fp.three");
        wait(&st);
        printf("FP THREE %s\n", ok && st == 0 ? "ok" : "FAIL");
        return 0;
    }
    if (strcmp(m, "hwm") == 0) {
        pid = fork();
        if (pid == 0) {
            sleep(2);                   /* parked while the parent measures */
            _exit(0);
        }
        sbrk(8192)[8191] = 1;           /* the parent's break rises */
        its = hwm_of(pid);
        mine = hwm_of(getpid());
        ok = its != 0 && mine != 0 && its != mine;
        wait(&st);
        printf("FP HWM %s\n", ok ? "ok" : "FAIL");
        return 0;
    }
    printf("usage: forkpair order|bytes|orphan|three|hwm|lim|limcell|irq\n");
    return 2;
}
