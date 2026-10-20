/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- fcntl(2): SYS_FCNTL (127) ---------------------------------------------
 * A = fd, X = cmd, Y = arg.  The answer is the value for F_DUPFD, F_GETFD and
 * F_GETFL and 0 otherwise, or C=0 with the errno.  <fcntl.h> declares the
 * third argument `...', as 2.11BSD's callers pass it or not; it is read as an
 * int, the way open(2)'s mode is (syscall_file.c).
 */
int fcntl(int fd, int cmd, int arg)
{
    int r = (int)__syscall(127, fd, cmd, arg);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}
