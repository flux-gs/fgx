/* softexec - does a NON-FORK exec work, and does it leak?
 *
 * FGX-Provenance: none
 *
 * `exec cmd` -- the shell builtin that does NOT fork -- was broken disk-wide
 * until apple/fgx#14: it took a "replace the caller in its own bank" arm that
 * called Load_Binary with A=0, "honor the header's bank", which _LoadFGX2
 * (shared by FGX3) rejects with EINVAL because it requires a caller-supplied
 * override bank.  Every binary this OS builds is FGX2/FGX3, so that arm could
 * not load a single one.  #14 deleted it; all execs now take the bank-swapping
 * path, which frees the outgoing image on the commit when the caller owns it.
 *
 * Reaching the non-fork path takes a little care, which is why this is a binary
 * and not a shell line.  The shell fork+execs us, and THAT exec is a fork
 * child's -- it clears the child flags -- so our own execv below is the first
 * one to run with them clear.
 *
 * TWO things are checked, because they fail independently:
 *
 *   CORRECTNESS -- deep(55) runs 55 levels of SOFT (data-bank) frames in every
 *   generation, so each freshly exec'd image must have been granted its own
 *   soft-frame bank and a DP page clean enough that crt0 seeds _fcc_sfp instead
 *   of inheriting a stale mid-recursion one from the dead image.
 *
 *   LEAKS -- and this is the half a functional test cannot see.  The reclaim
 *   added in #14 frees the outgoing banks and user stack; get it wrong and the
 *   FIRST exec still works perfectly.  The machine just starves later, in some
 *   unrelated program, long after the change that caused it.  So exec in a LOOP
 *   until an exhausted pool turns the leak into an ENOMEM the test can see.
 *
 *   GENERATIONS is CALIBRATED, not guessed.  Mutation-tested 2026-08-04 by
 *   disabling each free in turn and finding the round it dies on:
 *
 *     leak the outgoing BANKS  -> ENOMEM at generation 12  (pool is ~22)
 *     leak the outgoing STACK  -> ENOMEM at generation 29  (arena is 149 pages)
 *
 *   The first draft used 20, which caught the bank leak and let the STACK leak
 *   through green.  60 is ~2x the worse case; do not lower it without re-running
 *   both mutations, and if softexec's own stack footprint ever shrinks, the
 *   stack threshold moves further out.
 *
 * The countdown rides in argv (globals do not survive an exec) and is copied
 * into a file-scope buffer before being passed on: the FGX exec ABI wants
 * strings in the caller's DATA bank, and an incoming argv string has been
 * staged onto the bank-0 stack.
 *
 * Portable C: prints SXOK either way on a host.
 */
#include <stdio.h>
#include <unistd.h>
#include <errno.h>

#define GENERATIONS "............................................................"   /* 60 dots = 60 more execs */

char *argv2[3];
char  nextgen[80];              /* file scope = data bank; see above */

int
deep(int n)                     /* soft: named in src/softscc/softexec.txt */
{
    int acc;

    acc = n;
    if (n > 0)
        acc = acc + deep(n - 1);
    return acc;
}

int
main(argc, argv)
int argc;
char **argv;
{
    char *p;
    int i;

    if (argc < 2) {
        printf("SXEXEC\n");

        /* A FAILED exec must leave the caller RUNNING -- execve(2) returns -1
         * and the process continues.  This is not a formality here: the fix
         * has to allocate a DP page for the new image, that page is FIXED per
         * pid, and a plain exec does not change pid -- so the obvious
         * implementation zeroes the page we are still using, BEFORE the load
         * can fail.  fcc keeps its frame pointer, soft-frame pointer and stack
         * floor in DP.  deep(55) below is the detector: if the DP were wiped,
         * _fcc_sfp reads 0 and the very next soft frame traps.  Nothing after
         * this point would print at all. */
        argv2[0] = "softexec";
        argv2[1] = (char *)0;
        if (execv("/testbin/nosuchthing", argv2) >= 0) {
            printf("SXBADRET\n");       /* exec of a missing file "succeeded" */
            return 4;
        }
        if (deep(55) != 1540) {
            printf("SXFAILWRECK\n");    /* survived, but damaged */
            return 5;
        }
        printf("SXSURVIVED errno=%d\n", errno);

        argv2[0] = "softexec";
        argv2[1] = GENERATIONS;
        argv2[2] = (char *)0;
        if (execv("/testbin/softexec", argv2) < 0)
            printf("SXEXECFAIL errno=%d\n", errno);
        else
            printf("SXEXECFAIL ret\n");   /* execv returned 0: impossible */
        return 1;
    }

    /* Every generation: soft frames must work in THIS image. */
    if (deep(55) != 1540) {         /* 55*56/2 */
        printf("SXBAD\n");
        return 2;
    }

    /* One dot shorter each round; empty = done. */
    p = argv[1];
    if (*p != '\0') {
        i = 0;
        p++;
        while (*p != '\0' && i < 78)
            nextgen[i++] = *p++;
        nextgen[i] = '\0';
        argv2[0] = "softexec";
        argv2[1] = nextgen;
        argv2[2] = (char *)0;
        if (execv("/testbin/softexec", argv2) < 0)
            printf("SXLEAK left=%d errno=%d\n", i, errno);
        else
            printf("SXLEAK ret\n");
        return 3;
    }

    printf("SXOK\n");
    return 0;
}
