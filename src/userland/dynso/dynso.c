/*
 * dynso -- shared libc SP3's machine probe: a program linked dynamically
 * (toolchain/src/ld/fgx_dyn.py) and bound on the host
 * (toolchain/src/ld/fgx_bind.py), run as an ordinary image.  One line per
 * check, `DSO <check> ok' or `DSO FAIL <check>', then `DSO ok'.  Built as
 * dynso (prebound), dynsomis (bound by name against a libc whose core
 * moved) and dynsonodata (the same without data-site patching, which must
 * fail).  Spec: docs/history/plans/2026-09-29-shared-libc-sp3-design.md,
 * section 5.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>
#include <sys/ldctl.h>

extern char *strtok(), *strerror(), *asctime(), *sbrk(), *strrchr();
extern struct tm *gmtime();
extern int open(), rand(), fork(), vfork(), wait(), alarm(), pause();
extern void srand(), _exit(), qsort();
extern unsigned __progname;
extern unsigned _libc_blktab[];
extern unsigned char _dyn_bits_libc[];

static int fails;
static char sigbuf[8];
static int anchor;
static char *words[] = { "pear", "apple", "fig" };
int *ep = &errno;               /* a data site in the data segment */
static int (*cmpf)() = strcmp;  /* a pointer cell holding a libc function */

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "DSO %s ok\n" : "DSO FAIL %s\n", what);
    if (!ok)
        fails++;
}

static unsigned long
bankof()
{
    return (unsigned long)(char *)&anchor & 0xFF0000L;
}

static unsigned
heaplim()
{
    return *(unsigned *)(bankof() | 0xFFF8L);
}

static unsigned
lo(p)
char *p;
{
    return (unsigned)((unsigned long)p & 0xFFFFL);
}

/* qsort calls back into the program across the far seam. */
static int
bystr(a, b)
char **a, **b;
{
    return strcmp(*a, *b);
}

static void
onalarm(sig)
int sig;
{
    sprintf(sigbuf, "%d", 42);
}

/* _lib_init's carve: the rows the bitmap reaches lie back to back from
 * HEAP_LIM up, below every libc core cell this program names, and add up
 * to what the bitmap asks for. */
static int
carved()
{
    unsigned *t, i, b, need, top, low;

    need = 0;
    top = 0;
    low = 0xFFFF;
    for (t = _libc_blktab, i = 0; t[0]; t += 4, i++) {
        if (!(_dyn_bits_libc[i >> 3] & (1 << (i & 7))))
            continue;
        b = *(unsigned *)(bankof() | t[0]);
        need += t[3];
        if (b < low)
            low = b;
        if (b + t[3] > top)
            top = b + t[3];
    }
    return need > 0 && low == heaplim() && top - low == need &&
        top <= lo((char *)&errno) && top <= lo((char *)_libc_blktab) &&
        top <= lo((char *)stdout);
}

int
main(argc, argv)
int argc;
char **argv;
{
    char b1[16], b2[16], b3[16], *me;
    char *s1, *s2;
    long t, q;
    int a, n, pid, st;
    unsigned lim;

    me = strrchr(argv[0], '/');
    me = me ? me + 1 : argv[0];
    say("argv", argc == 1 && strncmp(me, "dynso", 5) == 0);
    say("progname", strcmp((char *)(unsigned long)__progname, me) == 0);
    say("zero", strtok((char *)0, " ") == (char *)0);
    a = rand();
    srand(1);
    say("init", a == rand());
    errno = 0;
    say("errno", open("/nonexistent/x", 0, 0) < 0 && errno == ENOENT &&
        *ep == ENOENT);
    say("literal", strcmp(strerror(ENOENT), "No such file or directory") == 0);
    strcpy(b1, "a b c");
    s1 = strtok(b1, " ");
    s2 = strtok((char *)0, " ");
    say("strtok", strcmp(s1, "a") == 0 && strcmp(s2, "b") == 0 &&
        strcmp(strtok((char *)0, " "), "c") == 0);
    t = 0;
    s1 = asctime(gmtime(&t));
    say("asctime", strcmp(s1, "Thu Jan  1 00:00:00 1970\n") == 0);
    t = 86400L;
    s2 = asctime(gmtime(&t));
    say("again", s1 == s2 && strcmp(s2, "Fri Jan  2 00:00:00 1970\n") == 0);
    qsort(words, 3, sizeof words[0], bystr);
    say("qsort", strcmp(words[0], "apple") == 0 && strcmp(words[2], "pear") == 0);
    say("pointer", (*cmpf)("fig", "fig") == 0 && (*cmpf)("a", "b") < 0);
    say("stdout", fflush(stdout) == 0);     /* &_iob[1], a core address */
    q = 1000000L;
    n = 7;
    say("ldiv", q / (long)n == 142857L && -q / (long)n == -142857L);
    say("carve", carved());
    lim = heaplim();

    strcpy(b2, "p1 p2 p3");
    strtok(b2, " ");
    pid = fork();
    if (pid == 0)
        _exit(strcmp(strtok((char *)0, " "), "p2") == 0 ? 0 : 1);
    wait(&st);
    say("fork", st == 0 && strcmp(strtok((char *)0, " "), "p2") == 0);
    strcpy(b3, "v1 v2 v3");
    strtok(b3, " ");
    pid = vfork();
    if (pid == 0) {
        strtok((char *)0, " ");
        _exit(0);
    }
    wait(&st);
    say("vfork", strcmp(strtok((char *)0, " "), "v3") == 0);

    /* FGX's pause() is a 60-tick sleep and alarm(1) is 60 ticks, so one
     * pause can end before the alarm is delivered. */
    signal(SIGALRM, onalarm);
    alarm(1);
    for (a = 0; a < 5 && !sigbuf[0]; a++)
        pause();
    say("signal", strcmp(sigbuf, "42") == 0);

    s1 = sbrk(0);
    s2 = sbrk(lim - lo(s1));
    say("sbrk", s2 != (char *)-1 && sbrk(1) == (char *)-1 && heaplim() == lim &&
        strcmp(asctime(gmtime(&t)), "Fri Jan  2 00:00:00 1970\n") == 0);

#ifdef DSO_SHARED
    /* Bound on the machine (dynsodyn): the environment reached main, libc's
     * calls go to its resident banks, and an exec of another dynamic
     * program binds it too. */
    {
        extern char *getenv(), *execl();
        static struct ldblk lb;
        unsigned long la;
        int i, ok;

        say("env", getenv("DSO_ENV") != (char *)0 &&
            strcmp(getenv("DSO_ENV"), "yes") == 0);
        strcpy(lb.name, "libc");
        lb.major = 1;
        la = (unsigned long)(char *)&lb;
        __syscall(SYS_LDCTL, LDS_LOOKUP, (unsigned)la, (unsigned)(la >> 16));
        for (ok = 0, i = 0; i < lb.nbanks; i++)     /* cmpf's bank: the cell */
            ok |= lb.banks[i] == ((unsigned char *)&cmpf)[2];   /* the binder patched */
        say("shared", ok);
        pid = fork();
        if (pid == 0) {
            execl("/testbin/dyntrue", "dyntrue", (char *)0);
            _exit(9);
        }
        wait(&st);
        say("exec", st == 0);
    }
#endif
    printf(fails ? "DSO FAIL %d\n" : "DSO ok\n", fails);
    return fails != 0;
}
