/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 */
/* spawnenv -- the spawn family passes the current environment.
 *
 * setenv(3) edits environ after exec; a spawnv child must see the edit, as an
 * execv child does on 2.11BSD (pdp/sys/execv.s passes _environ).  Then
 * spawnvp finds a bare name along PATH.  Prints, in order:
 *     child FGXENV=ok / vp found / SPAWNENV done */
#include <stdio.h>
#include <stdlib.h>
#include <fgx.h>

int wait();

static char *sh_argv[] = { "sh", "-c", "echo child FGXENV=$FGXENV", 0 };
static char *echo_argv[] = { "echo", "vp found", 0 };

int main()
{
    int st;

    setenv("FGXENV", "ok", 1);
    if (spawnv("/bin/sh", sh_argv) < 0)
        printf("spawnv failed\n");
    else
        wait(&st);
    if (spawnvp("echo", echo_argv) < 0)
        printf("spawnvp failed\n");
    else
        wait(&st);
    printf("SPAWNENV done\n");
    return 0;
}
