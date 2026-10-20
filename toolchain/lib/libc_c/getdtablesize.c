/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- getdtablesize(2): the size of a process's descriptor table ----------
 * 2.11BSD's is a system call whose whole body is `u.u_r.r_val1 = NOFILE;'
 * (getdtablesize, vendor/2.11BSD/usr/sys/sys/kern_descrip.c:31).  The table's
 * size is a compile-time constant on both sides, so the answer is NOFILE here,
 * which <sys/param.h> keeps equal to the kernel's FS_MAX_FDS.
 */
int getdtablesize()
{
    return (NOFILE);
}
