/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- flock(2): SYS_FLOCK (128) --------------------------------------------
 * A = fd, X = how.  0, or C=0 with the errno.
 */
int flock(int fd, int how)
{
    int r = (int)__syscall(128, fd, how, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
