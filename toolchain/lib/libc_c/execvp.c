/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- execvp(3), execlp(3): execv and execl with a $PATH search ------------
 * FGX-Provenance: 2.11BSD lib/libc/gen/execvp.c (5.2 (Berkeley) 3/9/86)
 *   vendored at vendor/2.11BSD/usr/lib/libc/gen/execvp.c.  Copyright (c)
 *   1980 Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * Upstream's search: each $PATH element in turn (":/bin:/usr/bin" when PATH is
 * unset), a name containing `/' tried as given, ENOEXEC handed to /bin/sh as a
 * script, ETXTBSY retried with a growing sleep, and EACCES remembered so a
 * later ENOENT does not hide it.
 *
 * Two deltas.  execlp gathers its arguments with <stdarg.h> as execl.c does,
 * where upstream passes `&argv', the address of its first stack argument, which
 * is only an argument vector on a machine that pushes them in that order.  And
 * the script vector is sized by the kernel's argument cap (LSARGV_MAX, 16, in
 * src/kernel/far/loader.s) plus the "sh" and the terminator, where upstream
 * reserves 256: SYS_EXECVE answers E2BIG past the cap, so slots beyond it could
 * never be passed, and this runs on a 65816 stack.
 */
#define EXECVP_NEWARGS  (16 + 2)

static char __lc_execvp_shell[] = "/bin/sh";

static char *
execat(s1, s2, si)
register char *s1, *s2;
char *si;
{
    register char *s;

    s = si;
    while (*s1 && *s1 != ':')
        *s++ = *s1++;
    if (si != s)
        *s++ = '/';
    while (*s2)
        *s++ = *s2++;
    *s = '\0';
    return (*s1 ? ++s1 : 0);
}

int
execvp(name, argv)
char *name, **argv;
{
    char *pathstr;
    register char *cp;
    char fname[128];
    char *newargs[EXECVP_NEWARGS];
    int i;
    register unsigned etxtbsy = 1;
    register int eacces = 0;

    if ((pathstr = getenv("PATH")) == NULL)
        pathstr = ":/bin:/usr/bin";
    cp = index(name, '/') ? "" : pathstr;

    do {
        cp = execat(cp, name, fname);
    retry:
        execv(fname, argv);
        switch (errno) {
        case ENOEXEC:
            newargs[0] = "sh";
            newargs[1] = fname;
            for (i = 1; newargs[i + 1] = argv[i]; i++) {
                if (i >= EXECVP_NEWARGS - 2) {
                    errno = E2BIG;
                    return (-1);
                }
            }
            execv(__lc_execvp_shell, newargs);
            return (-1);
        case ETXTBSY:
            if (++etxtbsy > 5)
                return (-1);
            sleep(etxtbsy);
            goto retry;
        case EACCES:
            eacces++;
            break;
        case ENOMEM:
        case E2BIG:
            return (-1);
        }
    } while (cp);
    if (eacces)
        errno = EACCES;
    return (-1);
}

int
execlp(char *name, ...)
{
    va_list ap;
    char   *argv[17];
    int     n;

    va_start(ap, name);
    for (n = 0; n < 16; n++) {
        argv[n] = va_arg(ap, char *);
        if (argv[n] == (char *)0)
            break;
    }
    va_end(ap);
    argv[n] = (char *)0;
    return (execvp(name, argv));
}
