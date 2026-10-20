/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD closei()
 * (sys/sys_inode.c) as the behaviour under test.
 *
 * cdtwo - the chardev Close op means the last close of the DEVICE, not of one
 * file handle (apple/fgx#76).
 *
 * BSD's closei() calls the driver's d_close only after scanning the file table
 * for another inode on the same i_rdev and finding none.  FGX gated on
 * FCB_RefCount instead, which covers fds SHARING one FCB (dup2, spawn
 * inheritance) and not two separate open(2)s -- those produce two FCBs each
 * with refcount 1, so closing either ran the device teardown under the other.
 *
 * THE PTY SLAVE IS WHERE IT BITES, because _PtyS_Close clears PTYF_SOPEN
 * unconditionally:
 *
 *   1. open /dev/ttyp0 twice   -> two FCBs, PTYF_SOPEN set
 *   2. close the first         -> refcount 1, so the op fires, SOPEN CLEARED
 *   3. write to the master     -> EIO, though the second fd still holds it
 *
 * So the test is step 3: after closing ONE of two slave fds, a master write
 * must still succeed.  A write that returns EIO is the bug; a short write is
 * not tolerated either, since the ring is empty and nothing else is draining.
 *
 * THE MASTER IS OPENED FIRST AND KEPT OPEN throughout: opening /dev/ttyp0
 * directly always fails, because the pair only exists once the master side has
 * created it.
 */
#include <stdio.h>

int open(char *path, int flags);
int close(int fd);
int write(int fd, char *buf, int n);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char msg[]    = "x";

int
main()
{
	int m, s1, s2, n;

	m = open(master, 2);
	if (m < 0) {
		printf("CDTWO FAIL master\n");
		return 1;
	}
	s1 = open(slave, 2);
	s2 = open(slave, 2);
	if (s1 < 0 || s2 < 0) {
		printf("CDTWO FAIL slave s1=%d s2=%d\n", s1, s2);
		return 1;
	}
	printf("CDTWO OPENED s1=%d s2=%d\n", s1, s2);

	/* Two separate opens -> two FCBs, each refcount 1.  Closing one must
	 * NOT tear the device down under the other. */
	(void) close(s1);
	printf("CDTWO CLOSED1\n");

	n = write(m, msg, 1);
	printf("CDTWO WROTE n=%d\n", n);
	if (n == 1)
		printf("CDTWO OK\n");
	else
		printf("CDTWO BAD n=%d\n", n);

	(void) close(s2);
	(void) close(m);
	return 0;
}
