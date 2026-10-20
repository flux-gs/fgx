/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- fchown(2): SYS_FCHOWN (129) ------------------------------------------
 * A = fd, X = uid, Y = gid; -1 leaves an id alone.  0, or C=0 with the errno.
 */
int fchown(int fd, int uid, int gid)
{
    int r = (int)__syscall(129, fd, uid, gid);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

