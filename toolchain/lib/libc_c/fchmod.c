/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- fchmod(2): SYS_FCHMOD (130) ------------------------------------------
 * A = fd, X = mode.  0, or C=0 with the errno.
 */
int fchmod(int fd, int mode)
{
    int r = (int)__syscall(130, fd, mode, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
