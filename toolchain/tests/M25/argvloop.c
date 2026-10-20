/* Real 4-byte char **argv with no shim: bare argv, char** indexing,
 * pointer arithmetic, and a for-loop over argc.  argv[0] is the only
 * reliably-populated entry under the test harness (argc==1), so the
 * checks exercise the pointer mechanics around it.  Returns 42 on full
 * success; a distinct small code identifies the first failing check. */
int main(int argc, char **argv)
{
    char **q;
    char  *a;
    int    i;

    q = argv;                               /* bare argv (was a die) */
    a = q[0];                               /* char** index */
    if (a != argv[0]) return 1;             /* bare-copy index == direct index */
    if (a == 0) return 2;
    if (*a != '/') return 3;                /* argv[0] path starts with '/' */
    if (*(argv + 0) != argv[0]) return 4;   /* pointer arithmetic == index */
    for (i = 0; i < argc; i++) {            /* loop over argc (>=1) */
        if (argv[i] == 0) return 5;         /* no NULL before argc */
    }
    return 42;
}
