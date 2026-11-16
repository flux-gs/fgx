/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- vhangup(2): SYS_VHANGUP (133) ----------------------------------------
 * No arguments.  0, or C=0 with the errno (EPERM).
 */
int vhangup()
{
    int r = (int)__syscall(133, 0, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
