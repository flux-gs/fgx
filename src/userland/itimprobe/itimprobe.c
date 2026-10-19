/* itimprobe - setitimer(2) REPEATS, which is the whole of what it adds.
 *
 * FGX-Provenance: none
 *
 * alarm(2) already armed a one-shot SIGALRM, so a probe that merely saw one
 * signal arrive would pass on a kernel where setitimer had been wired to
 * `_Sys_Alarm' and the interval dropped on the floor.  What is asserted here is
 * therefore a COUNT: with a one-second interval, several SIGALRMs must arrive
 * from ONE call.  That is the arm the reload table and
 * `_Sys_AlarmTickAll's re-arm exist for, and nothing else in the tree covers it.
 *
 * The reload is copied unconditionally when the counter hits zero, which is
 * upstream's own rule (`p->p_realtimer.it_value = p->p_realtimer.it_interval',
 * vendor/2.11BSD/usr/sys/sys/kern_synch.c:50), so a zero interval must leave the
 * one-shot alarm(2) already was -- asserted too, because it is the arm that
 * tells a repeating timer from a broken one in the other direction.
 *
 * THE REFUSALS ARE HALF THE PROBE.  A kernel that accepted ITIMER_VIRTUAL and
 * never fired it, or truncated an over-long interval the way a masked seconds
 * count would, passes every "did it tick" assertion.  Both are asserted to FAIL
 * with the right errno.
 */
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/signal.h>
#include <time.h>

int fails = 0;
int nalrm = 0;
int sawterm = 0;
int term_inside = 0;

static void ok(what, good)
    char *what;
    int good;
{
    if (good)
        printf("IT ok   %s\n", what);
    else {
        printf("IT FAIL %s\n", what);
        ++fails;
    }
}

/* Burn wall-clock through SYSCALL EXITS rather than nanosleep.
 *
 * THE FIRST CUT USED sleep(1) AND MEASURED THE WRONG THING.  FGX's sleep(3) is
 * a loop of nanosleep(60) (libc_c/syscall_misc.c), and klogprobe already
 * records an unresolved observation next to its own alarm arm: a SIGALRM did
 * not arrive while a task was blocked, and "whether alarm(2) fails to interrupt
 * a sleeping task generally, or only this sleep, is not established".  A timer
 * probe that sleeps is therefore measuring delivery-to-a-sleeper, not the
 * timer.  time(2) in a tight loop leaves the kernel constantly, which is where
 * `_Sys_CheckSignal' delivers, so what is left under test is the timer itself.
 */
static void burn(secs)
    int secs;
{
    long t0;
    long t;

    t0 = time((long *)0);
    do {
        t = time((long *)0);
    } while (t - t0 < (long)secs);
}

static void onalrm()
{
    ++nalrm;
    signal(SIGALRM, onalrm);            /* BSD resets to SIG_DFL on delivery */
}

/* SIGTERM's handler, installed before anything raises it. */
static void onterm()
{
    sawterm = 1;
    signal(SIGTERM, onterm);
}

/* The SIGALRM handler whose sa_mask names SIGTERM.  It raises SIGTERM on itself
 * and then makes several syscalls: each exit is a delivery point, so if sa_mask
 * were ignored the SIGTERM handler would run BEFORE this one returns and
 * `term_inside' would come back set.
 *
 * AN EARLIER VERSION MEASURED RE-ENTRY BY BURNING TIME IN THE HANDLER, which
 * livelocks by construction and not because of any defect: a handler slower than
 * the timer's interval always finds another expiry pending when it returns, so
 * main() never advances.  That is equally true on BSD.  Two signals measure the
 * same property in a few syscalls.
 */
static void onalrm_mask()
{
    ++nalrm;
    signal(SIGALRM, onalrm_mask);
    kill(getpid(), SIGTERM);
    (void)time((long *)0);
    (void)time((long *)0);
    (void)time((long *)0);
    term_inside = sawterm;              /* must still be 0 */
}

main()
{
    struct itimerval itv;
    struct sigaction sa;
    struct sigaction sa2;
    sigset_t         aset;
    int              seen;

    printf("ITSTART\n");

    /* --- the refusals, before anything is armed ------------------------- */
    itv.it_interval.tv_sec = 0;  itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec    = 1;  itv.it_value.tv_usec    = 0;
    errno = 0;
    ok("ITIMER_VIRTUAL refused EINVAL",
       setitimer(ITIMER_VIRTUAL, &itv, (struct itimerval *)0) == -1 &&
       errno == EINVAL);

    /* 1024 s: one past the bound the s*64 intermediate imposes.  A kernel that
     * masked the seconds instead of refusing would arm a short timer here and
     * report success. */
    itv.it_interval.tv_sec = 1024; itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec    = 1;    itv.it_value.tv_usec    = 0;
    errno = 0;
    ok("interval past the bound refused EINVAL",
       setitimer(ITIMER_REAL, &itv, (struct itimerval *)0) == -1 &&
       errno == EINVAL);

    /* --- THE CONTROL, and it is alarm(2), which predates setitimer ------
     *
     * If a SECOND alarm(2) does not deliver, then "one SIGALRM per process,
     * ever" is a property of signal delivery here and nothing setitimer does
     * could show through it.  Running the older call first is what makes the
     * setitimer arms below interpretable at all. */
    signal(SIGALRM, onalrm);
    nalrm = 0;
    alarm(1);
    burn(2);
    printf("ITA1 %d\n", nalrm);
    ok("alarm(2) delivered once", nalrm == 1);
    alarm(1);
    burn(2);
    printf("ITA2 %d\n", nalrm);
    ok("alarm(2) delivered a SECOND time", nalrm == 2);

    /* --- the repeat, which is the point -------------------------------- */
    signal(SIGALRM, onalrm);
    nalrm = 0;
    itv.it_interval.tv_sec = 1; itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec    = 1; itv.it_value.tv_usec    = 0;
    ok("armed a 1 s repeating timer",
       setitimer(ITIMER_REAL, &itv, (struct itimerval *)0) == 0);

    /* Burn wall-clock without blocking in a way that could swallow the signal:
     * sleep(1) five times, re-checking between.  A one-shot yields nalrm == 1. */
    burn(3);
    seen = nalrm;
    printf("ITCOUNT %d\n", seen);
    ok("the timer REPEATED (more than one SIGALRM from one call)", seen >= 2);

    /* --- a zero interval is still a one-shot --------------------------- */
    itv.it_interval.tv_sec = 0; itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec    = 0; itv.it_value.tv_usec    = 0;
    (void)setitimer(ITIMER_REAL, &itv, (struct itimerval *)0);   /* disarm */
    nalrm = 0;
    itv.it_interval.tv_sec = 0; itv.it_interval.tv_usec = 0;
    itv.it_value.tv_sec    = 1; itv.it_value.tv_usec    = 0;
    ok("armed a one-shot",
       setitimer(ITIMER_REAL, &itv, (struct itimerval *)0) == 0);
    burn(2);
    printf("ITONCE %d\n", nalrm);
    ok("a zero interval did NOT repeat", nalrm == 1);

    /* --- sigaction(2)'s sa_mask, which is the only thing it adds ---------
     *
     * A handler whose sa_mask names SIGTERM must run with SIGTERM blocked for
     * its duration, so a SIGTERM raised INSIDE it stays pending until it
     * returns.  Without sa_mask the second handler runs at the first syscall
     * exit inside the first, which is what `term_inside' catches. */
    sigemptyset(&aset);
    ok("sigemptyset cleared the set", aset == 0L);
    sigaddset(&aset, SIGTERM);
    ok("sigaddset named SIGTERM", sigismember(&aset, SIGTERM) == 1);

    signal(SIGTERM, onterm);
    sa.sa_handler = onalrm_mask;
    sa.sa_mask    = aset;
    sa.sa_flags   = 0;
    ok("sigaction installed a handler with sa_mask",
       sigaction(SIGALRM, &sa, (struct sigaction *)0) == 0);

    sa2.sa_handler = (void (*)())0;
    sa2.sa_mask    = 0L;
    sa2.sa_flags   = 0;
    ok("sigaction reported sa_mask back through osa",
       sigaction(SIGALRM, (struct sigaction *)0, &sa2) == 0 &&
       sa2.sa_mask == aset);

    ok("SIGKILL refused a new action",
       sigaction(SIGKILL, &sa, (struct sigaction *)0) == -1);

    nalrm = 0;
    sawterm = 0;
    term_inside = 0;
    alarm(1);
    burn(3);
    printf("ITMASK n=%d inside=%d after=%d\n", nalrm, term_inside, sawterm);
    ok("the sa_mask handler ran", nalrm >= 1);
    ok("sa_mask held SIGTERM OFF until the handler returned", term_inside == 0);
    ok("the held SIGTERM arrived once the handler returned", sawterm == 1);

    /* Leave nothing armed for whatever runs next. */
    itv.it_value.tv_sec = 0; itv.it_value.tv_usec = 0;
    itv.it_interval.tv_sec = 0; itv.it_interval.tv_usec = 0;
    (void)setitimer(ITIMER_REAL, &itv, (struct itimerval *)0);

    printf("ITDONE fails=%d\n", fails);
    return (fails ? 1 : 0);
}
