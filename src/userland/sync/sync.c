/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1980 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD sync(8)
 *   Ported from sync.c 4.1 (Berkeley) 10/1/80 (usr/bin/sync.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * sync - force all dirty filesystem state to disk (SYS_SYNC, train-3 F4):
 * every open file's data + index + dir entry across every task, then the
 * allocation bitmap.
 */
static char *sccsid = "@(#)sync.c\t4.1 (Berkeley) 10/1/80";

void sync();

int main(int argc, char **argv)
{
    sync();
    return 0;
}
