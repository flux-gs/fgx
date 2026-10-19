/* softfork - does a fork child's soft frames leave the PARENT'S intact?
 *
 * FGX-Provenance: none
 *
 * Bank-0 stack campaign 1.3 puts a recursion cycle's locals in a DEDICATED bank
 * (SE_SoftBank).  Snapshot-fork's pair 1 walks that slot -- it is the slot that
 * used to be SE_SbrkBank, and reusing it is why the child's frames are safe:
 * the parent's bank is snapshotted before the child runs and restored at the
 * child's exec/_exit.  The child DOES overwrite the parent's live activation
 * records; it writes into a bank whose pristine copy sits in a spare.
 *
 * That is a correct-by-accident-of-slot-reuse argument, which is exactly the
 * kind that needs a test rather than a paragraph.  So: recurse, fork from the
 * BOTTOM of the recursion, have the child recurse too (clobbering the shared
 * bank), reap it, then unwind the parent checking every frame on the way out.
 * If pair 1 ever stops covering SE_SoftBank, the parent's locals come back
 * wrong and this fails.  apple/fgx#12.
 *
 * Portable C: clang returns 42.
 */
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>

int forked;

int
chain(n)
int n;
{
    int mine;                   /* must survive the child's whole life */
    int pid;
    int st;

    mine = n * 3 + 1;           /* a value unique to THIS activation */
    if (n > 0) {
        if (chain(n - 1) < 0)
            return -1;
    } else if (!forked) {
        forked = 1;
        pid = fork();
        if (pid == 0) {
            chain(6);           /* child scribbles the shared soft bank */
            _exit(0);
        }
        if (pid < 0)
            return -1;
        wait(&st);
    }
    if (mine != n * 3 + 1)      /* the frame the child ran over */
        return -1;
    return mine;
}

int
main()
{
    printf("SFSTART\n");
    if (chain(8) != 25) {       /* 8*3+1 */
        printf("SFBAD\n");
        return 1;
    }
    printf("SFOK\n");
    return 42;
}
