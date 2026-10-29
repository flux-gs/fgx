/* _exit(2): 2.11BSD's is the syscall stub pdp/sys/_exit.s, ENTRY(_exit)
 * SYS(exit).  It does not flush stdio; exit() (exit.c) does, through
 * _cleanup.  A vfork child calls _exit so the parent's held output is not
 * written twice. */

void _exit(int code)
{
    __syscall(1, code & 0xFF, 0, 0);
    for (;;) ;                                   /* not reached */
}
