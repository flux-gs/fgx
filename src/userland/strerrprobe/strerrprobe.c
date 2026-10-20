/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD string/strerror.c.
 */
/* strerrprobe - strerror(3) for two known errnos and numbers with no message,
 * a shorter one after a longer one so a stale digit would show.  2.11BSD string/strerror.c answers an unknown number with
 * "Unknown error: <n>" built by hand, unsigned. */
#include <stdio.h>
#include <string.h>
#include <errno.h>

int main()
{
    printf("A[%s]\n", strerror(ENOENT));
    printf("B[%s]\n", strerror(EACCES));
    printf("C[%s]\n", strerror(99));
    printf("D[%s]\n", strerror(1234));
    printf("E[%s]\n", strerror(99));    /* shorter after longer */
    printf("F[%s]\n", strerror(0));
    printf("SEDONE\n");
    return 0;
}
