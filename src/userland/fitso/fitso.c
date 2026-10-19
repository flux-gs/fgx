/*
 * fitso -- a dynamic program needing termlib whose data ends a fixed
 * margin below the limit fgx_dyn computes from the libraries' assembled
 * core bases (build_dynso.sh sizes PAD1 and PAD2 from fgx_dyn's own
 * report).  Run where termlib's core landed lower than that, the binder
 * must refuse it.  `FIT ok' when it runs and termlib answers.
 *
 * FGX-Provenance: none
 *
 * Spec: docs/history/plans/2026-09-30-shared-libc-sp4-design.md, 9.6.
 */
#include <stdio.h>

extern int tgetent();

static char pad1[PAD1];
static char pad2[PAD2];
static char tbuf[1024];

int
main()
{
    pad1[PAD1 - 1] = 1;
    pad2[PAD2 - 1] = 1;
    printf(tgetent(tbuf, "vt100") == 1 && pad1[PAD1 - 1] == 1 &&
           pad2[PAD2 - 1] == 1 ? "FIT ok\n" : "FIT FAIL\n");
    return 0;
}
