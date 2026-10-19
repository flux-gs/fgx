char *getenv(char *name)
{
    /* POSIX contract: getenv reads the environment THROUGH `environ`, so a
     * program that edits its environment (tcsh Setenv repoints environ at a
     * heap vector) sees its own changes.  The old walk read args_env -- the
     * crt0-captured EXEC-TIME block -- so every post-exec change was
     * invisible (tcsh's %m prompt escape read a HOST that Setenv had set,
     * and got nothing, 2026-07-27).  _libc_start (libc_start.s) points
     * environ at args_envv (whose entries point into args_env), so the
     * fresh-process behavior is unchanged; the args_env fallback keeps near-crt0 (FGX1) binaries,
     * whose environ stays 0, working. */
    extern char **environ;
    int x = 0;

    if (environ != (char **)0) {
        char **e;
        char *ep;
        int  y;

        for (e = environ; (ep = *e) != (char *)0; e++) {
            y = 0;
            while (name[y] != 0 && name[y] == ep[y])
                y++;
            if (name[y] == 0 && ep[y] == '=')
                return &ep[y + 1];
        }
        return (char *)0;
    }
    while (args_env[x] != 0) {
        int y = 0;
        while (name[y] != 0 && name[y] == args_env[x + y])
            y++;
        if (name[y] == 0 && args_env[x + y] == '=')
            return &args_env[x + y + 1];
        while (args_env[x] != 0)
            x++;                      /* skip the rest of this entry */
        x++;                          /* and its NUL */
    }
    return (char *)0;
}

