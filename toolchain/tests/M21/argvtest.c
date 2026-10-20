/* main's argv[i] binding: rewrites argv[N] -> c_argv_get(N).
 *
 * argv[0] is always populated by args.s with the binary's invocation
 * path.  Test: check that argv[0] is non-null and its first byte is
 * the '/' that starts /BIN/ARGVTEST or similar.  Returns 42 on
 * success.
 */
#include <stdio.h>

int main(int argc, char **argv)
{
    char *p;
    p = argv[0];
    if (p == 0) return 1;
    if (*p == '/') return 42;
    return 2;
}
