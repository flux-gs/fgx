/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD arch(1)
 *   Ported from arch(1), 2.11BSD.  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * arch - print the machine architecture.  Port of 2.11BSD arch(1).
 * FGX is 65816 (Apple IIgs); arch prints the bare CPU arch (cf. uname -m).
 */
#include <stdio.h>

int main(int argc, char **argv)
{
    printf("65816\n");
    return 0;
}
