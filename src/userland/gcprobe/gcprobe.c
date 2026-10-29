/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * gcprobe -- the paths into libc that go through a function POINTER, which is
 * where a link that drops unreachable library code (toolchain/src/ld/fgx_gc.py)
 * could drop too much.
 *
 *   gcprobe        GC Q apple banana cherry ok   qsort calls the comparator,
 *                                                which calls strcmp
 *                  GC H ok                        SIGALRM runs the handler
 *                  (writes /tmp/gc.out without closing it, and exits: exit(3)
 *                  flushes stdio through _cleanup)
 *   gcprobe -r     GC F ok                        the bytes reached the file
 *                  GC VERDICT PASS
 */
#include <stdio.h>
#include <string.h>
#include <signal.h>

static char *words[] = { "cherry", "apple", "banana" };
static int fired;

static int
cmp(a, b)
    char **a, **b;
{
    return strcmp(*a, *b);
}

static void
h(sig)
    int sig;
{
    fired = sig;
}

main(argc, argv)
    int argc;
    char **argv;
{
    FILE *f;
    char buf[32];
    int ok;

    if (argc > 1) {                     /* -r: read back what exit flushed */
        f = fopen("/tmp/gc.out", "r");
        ok = f != NULL && fgets(buf, sizeof buf, f) != NULL &&
             strcmp(buf, "flushed at exit\n") == 0;
        printf("GC F %s\n", ok ? "ok" : "FAIL");
        printf("GC VERDICT %s\n", ok ? "PASS" : "FAIL");
        unlink("/tmp/gc.out");
        exit(!ok);
    }
    qsort((char *)words, 3, sizeof words[0], cmp);
    ok = strcmp(words[0], "apple") == 0 && strcmp(words[2], "cherry") == 0;
    printf("GC Q %s %s %s %s\n", words[0], words[1], words[2],
           ok ? "ok" : "FAIL");
    signal(SIGALRM, h);
    alarm(1);
    pause();
    printf("GC H %s\n", fired == SIGALRM ? "ok" : "FAIL");
    f = fopen("/tmp/gc.out", "w");
    fprintf(f, "flushed at exit\n");
    exit(0);
}
