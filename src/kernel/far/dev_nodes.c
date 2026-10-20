/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  GENERATED, do not edit.
 */
/* dev_nodes.c -- the /dev volume's nodes, as the build made them.  UFS 1.7d I3.
 *
 * WRITTEN BY tools/ninja/gen.py FROM DEV_NODES.  Edit the list there; this
 * file is regenerated whenever build.ninja is, and the same list writes the
 * mknod commands that put these numbers on the volume -- so the image and
 * this table cannot disagree with each other.  The built-in and raw-disk
 * indices are the kernel's registration order, which is fixed; a module's
 * is the number it registers AT (CDF_FIXED, from the same list through
 * include/devnodes.s), so modload.conf's order cannot move it.
 */

/* dev_nodeat -- the i'th node's name, with its rdev through `rdevp'.
 * Returns 0 past the end, which is how the caller's loop terminates. */
char *
dev_nodeat(i, rdevp)
int  i;
int *rdevp;
{
    if (i ==  0) { *rdevp =  0; return ("null"); }
    if (i ==  1) { *rdevp =  1; return ("ptyp0"); }
    if (i ==  2) { *rdevp =  2; return ("ttyp0"); }
    if (i ==  3) { *rdevp =  3; return ("ptyp1"); }
    if (i ==  4) { *rdevp =  4; return ("ttyp1"); }
    if (i ==  5) { *rdevp =  5; return ("ttyv1"); }
    if (i ==  6) { *rdevp =  6; return ("ttyv2"); }
    if (i ==  7) { *rdevp =  7; return ("console"); }
    if (i ==  8) { *rdevp =  8; return ("tty"); }
    if (i ==  9) { *rdevp = 18; return ("tty01"); }
    if (i == 10) { *rdevp = 19; return ("bpf0"); }
    if (i == 11) { *rdevp =  9; return ("ttyv3"); }
    if (i == 12) { *rdevp = 10; return ("rsd0"); }
    if (i == 13) { *rdevp = 11; return ("rsd1"); }
    if (i == 14) { *rdevp = 12; return ("rsd2"); }
    if (i == 15) { *rdevp = 13; return ("rsd3"); }
    if (i == 16) { *rdevp = 14; return ("rsd4"); }
    if (i == 17) { *rdevp = 15; return ("rsd5"); }
    if (i == 18) { *rdevp = 16; return ("rsd6"); }
    if (i == 19) { *rdevp = 17; return ("rsd7"); }
    if (i == 20) { *rdevp = 20; return ("cda"); }
    if (i == 21) { *rdevp = 21; return ("tty00"); }
    if (i == 22) { *rdevp = 22; return ("klog"); }
    return ((char *)0);
}
