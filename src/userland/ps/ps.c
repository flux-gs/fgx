/*
 * ps - list processes.  Calls procs(buf, max) (SYS_PROCS=87), which fills a
 * caller buffer with fixed 32-byte {pid, ppid, pgid, state, name[16], stksize,
 * stkhwm, arena_used, arena_free} records for the kernel (pid 0) plus every
 * live task, and prints a column table.
 *
 * The two stack columns exist because the bank-0 stack arena is FGX's tightest
 * resource and the only way to read it used to be a doc or the kernel log ring:
 *
 *   STK  pages this task RESERVED out of the arena, guard page included.  This
 *        is the number that fills the arena up, and the one docs/bank0-stack-
 *        status.md tabulates per program.
 *   HWM  bytes the task has actually TOUCHED, measured (not modelled) by the
 *        STK_PAINT scan the kernel already runs at exit.  `-` means the region
 *        is outside the arena, so it was never painted -- init, which runs on a
 *        static stack.
 *
 * A reservation whose HWM sits near it is one deep call away from the guard
 * page; a reservation many times its HWM is arena that some other task could
 * have had.  Both readings are the point.
 */
#include <stdio.h>
#include <fgx.h>              /* struct procinfo, the kernel's PI_* layout */

/* Data-bank buffer (NOT a stack local): SYS_PROCS writes via the caller DBR. */
struct procinfo plist[24];

static char stchar(int s)
{
    if (s == 1 || s == 2) return 'R';   /* READY / RUNNING */
    if (s == 3) return 'S';             /* BLOCKED (sleeping) */
    if (s == 4) return 'Z';             /* ZOMBIE */
    if (s == 5) return 'T';             /* STOPPED */
    return '?';
}

/* Bytes the heap had left at its tightest.  The break may reach HEAP_LIM
 * ($FFF8, the heap limit cell) but not the descriptor above it.  Built by
 * wraparound rather than written as a literal, which would not fit fcc's
 * 16-bit signed int. */
static unsigned
heapfree(hwm)
    unsigned hwm;
{
    unsigned top;

    top = 0;
    top -= 8;                   /* $FFF8 = HEAP_LIM, the heap limit cell (kernel.s) */
    return top - hwm;
}

int main(void)
{
    int n, i, used, total;

    n = procs((char *)plist, 24);
    used = 0;
    total = 0;
    printf("  PID  PPID ST   STK    HWM   HEAP CMD\n");
    for (i = 0; i < n; i++) {
        if (plist[i].pid == 0) {
            used = plist[i].arena_used;
            total = used + plist[i].arena_free;
        }
        printf("%5d %5d  %c ", plist[i].pid, plist[i].ppid,
               stchar(plist[i].state));
        if (plist[i].stksize == 0)
            printf("    -      -");
        else if (plist[i].stkhwm == 0)
            printf("%5d      -", plist[i].stksize >> 8);
        else
            printf("%5d %6d", plist[i].stksize >> 8, plist[i].stkhwm);
        if (plist[i].heaphwm == 0)
            printf("      -");
        else
            printf(" %6u", heapfree(plist[i].heaphwm));
        printf(" %s\n", plist[i].name);
    }
    if (total != 0)
        printf("stack arena: %d/%d pages used\n", used, total);
    return 0;
}
