/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- execle(3): execl with the environment after the terminating 0 --------
 * FGX-Provenance: 2.11BSD lib/libc/pdp/sys/execle.s, vendored at
 *   vendor/2.11BSD/usr/lib/libc/pdp/sys/execle.s.  Copyright (c) 1987
 *   Regents of the University of California.  All rights reserved.
 *
 * Upstream walks its own argument list on the stack to the 0 that ends argv,
 * takes the word after it as envp, and calls execve with the address of the
 * first argument as argv.  This is the same walk through <stdarg.h>, into a
 * vector bounded by the kernel's argument cap as execl.c's is.
 */
int execle(char *path, ...)
{
    va_list ap;
    char   *argv[17];
    char  **envp;
    int     n;

    va_start(ap, path);
    for (n = 0; n < 16; n++) {
        argv[n] = va_arg(ap, char *);
        if (argv[n] == (char *)0)
            break;
    }
    if (n == 16)
        while (va_arg(ap, char *) != (char *)0)
            ;
    envp = va_arg(ap, char **);
    va_end(ap);
    argv[n] = (char *)0;
    return execve(path, argv, envp);
}
