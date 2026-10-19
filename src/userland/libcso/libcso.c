/*
 * libcso -- shared libc SP2's machine probe: a program statically linked
 * against libc's library-mode compile (toolchain/src/ld/fgx_static.py), whose
 * startup gave it its own copy of every libc block it reaches
 * (lib/libc_c/libc_init.c).  One line per check, `CSO <check> ok' or
 * `CSO FAIL <check> ...', then `CSO ok' if all passed.  Spec:
 * docs/history/plans/2026-09-28-shared-libc-sp2-design.md, section 8.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

extern char *strtok(), *strerror(), *asctime(), *sbrk();
extern struct tm *gmtime();
extern int open(), rand(), fork(), vfork(), wait(), alarm(), pause();
extern void srand(), _exit();
extern unsigned _libc_blk_strtok, _libc_blk_ctime;
extern unsigned __progname;
extern char *strrchr();
extern void _lib_init();
extern int _lib_copy();
extern int memcmp();

static int fails;
static char sigbuf[8];
static int anchor;
static unsigned bt[9], bt0[1], c0, c1;
static unsigned char bits[1];
static char t0[4] = { 'a', 'b', 'c', 'd' }, t1[6];

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "CSO %s ok\n" : "CSO FAIL %s\n", what);
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

static void
onalarm(sig)
int sig;
{
    sprintf(sigbuf, "%d", 42);
}

int
main(argc, argv)
int argc;
char **argv;
{
    char b1[16], b2[16], b3[16];
    char *s1, *s2;
    long t;
    int a, pid, st;
    unsigned lim;

    /* _libc_start read the kernel's frame at its fixed depth: argc and
     * argv[0] (typed as /testbin/libcso), and __progname, a bank-0 offset
     * into argv[0]'s string in the frame. */
    s1 = strrchr(argv[0], '/');
    say("argv", argc == 1 && strcmp(s1 ? s1 + 1 : argv[0], "libcso") == 0);
    say("progname", strcmp((char *)(unsigned long)__progname, "libcso") == 0);

    /* A zeroed static in a block: strtok's saved position starts NULL. */
    say("zero", strtok((char *)0, " ") == (char *)0);

    /* An initialised one: rand's state starts as srand(1) leaves it. */
    a = rand();
    srand(1);
    say("init", a == rand());

    /* The core: errno, and stdout (every line here). */
    errno = 0;
    say("errno", open("/nonexistent/x", 0, 0) < 0 && errno == ENOENT);

    /* A literal, from libc's banks. */
    say("literal", strcmp(strerror(ENOENT), "No such file or directory") == 0);

    /* A stateful member across calls. */
    strcpy(b1, "a b c");
    s1 = strtok(b1, " ");
    s2 = strtok((char *)0, " ");
    say("strtok", strcmp(s1, "a") == 0 && strcmp(s2, "b") == 0 &&
        strcmp(strtok((char *)0, " "), "c") == 0);

    /* ctime's member: the same result buffer, in THIS process's block. */
    t = 0;
    s1 = asctime(gmtime(&t));
    say("asctime", strcmp(s1, "Thu Jan  1 00:00:00 1970\n") == 0);
    t = 86400L;
    s2 = asctime(gmtime(&t));
    say("again", s1 == s2 && strcmp(s2, "Fri Jan  2 00:00:00 1970\n") == 0);
    /* _lib_init builds a row only when its bit is set: row 0 of a table of
     * the probe's own, not row 1.  And a table with no rows is a no-op. */
    lim = heaplim();
    bt[0] = lo((char *)&c0); bt[1] = lo(t0); bt[2] = (unsigned)((unsigned long)t0 >> 16); bt[3] = 4;
    bt[4] = lo((char *)&c1); bt[5] = lo(t1); bt[6] = (unsigned)((unsigned long)t1 >> 16); bt[7] = 6;
    bt[8] = 0;
    bits[0] = 1;
    _lib_init(bt, bits, _lib_copy);
    say("bitmap", heaplim() == lim - 4 && c0 == lim - 4 && c1 == 0 &&
        memcmp((char *)(bankof() | c0), t0, 4) == 0);
    lim = heaplim();
    _lib_init(bt0, (unsigned char *)0, _lib_copy);
    say("empty", heaplim() == lim);

    lim = heaplim();
    say("place", lim < 0xFFF8 && _libc_blk_ctime >= lim &&
        (unsigned long)(char *)s1 >> 16 == bankof() >> 16 &&
        lo(s1) >= _libc_blk_ctime && lo(s1) < 0xFFF8 &&
        strcmp(gmtime(&t)->tm_zone, "GMT") == 0 &&
        lo(gmtime(&t)->tm_zone) >= _libc_blk_ctime);

    /* fork: the child's blocks are its own. */
    strcpy(b2, "p1 p2 p3");
    strtok(b2, " ");
    pid = fork();
    if (pid == 0)
        _exit(strcmp(strtok((char *)0, " "), "p2") == 0 ? 0 : 1);
    wait(&st);
    say("fork", st == 0 && strcmp(strtok((char *)0, " "), "p2") == 0);

    /* vfork: the child borrows the parent's memory, blocks included. */
    strcpy(b3, "v1 v2 v3");
    strtok(b3, " ");
    pid = vfork();
    if (pid == 0) {
        strtok((char *)0, " ");
        _exit(0);
    }
    wait(&st);
    say("vfork", strcmp(strtok((char *)0, " "), "v3") == 0);

    /* A signal handler that calls libc. */
    /* FGX's pause() is a 60-tick sleep (libc_c/syscall_misc.c) and alarm(1)
     * is 60 ticks, so one pause can end before the alarm is delivered. */
    signal(SIGALRM, onalarm);
    alarm(1);
    for (a = 0; a < 5 && !sigbuf[0]; a++)
        pause();
    say("signal", strcmp(sigbuf, "42") == 0);

    /* Last, because it fills the heap: sbrk stops at the lowered limit. */
    s1 = sbrk(0);
    s2 = sbrk(lim - lo(s1));
    say("sbrk", s2 != (char *)-1 && sbrk(1) == (char *)-1 &&
        heaplim() == lim &&
        strcmp(asctime(gmtime(&t)), "Fri Jan  2 00:00:00 1970\n") == 0);

    printf(fails ? "CSO FAIL %d\n" : "CSO ok\n", fails);
    return fails != 0;
}
