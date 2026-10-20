/*
 * spinner - a killable target task: loops forever, yielding the CPU.
 *
 * Cooperative scheduling has no preemption, so a CPU-bound loop with no syscall
 * would never reach the kernel's signal-delivery hook (_Sys_CheckSignal runs at
 * syscall exit).  yield() IS a syscall, so every loop iteration gives the
 * kernel a syscall exit at which a pending signal (e.g. SIGTERM from killtest or
 * `kill`) is delivered — terminating this task.  Used to validate Phase 5.1
 * signal default actions.
 */
int yield(void);       /* spin_stubs.s: SYS_YIELD = 79 */

int main(int argc, char **argv)
{
    for (;;)
        yield();
    return 0;
}
