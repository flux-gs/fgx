/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD cp(1)
 *   Ported from cp(1), 2.11BSD (4.13, Berkeley, 10/11/85).  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * cp - copy files.  Port of 2.11BSD cp(1).
 *
 * Supports the two BSD forms:
 *   cp f1 f2          - copy f1 onto f2
 *   cp f1 ... fn dir  - copy each fN into directory dir (as dir/basename(fN))
 *
 * Port-side patches (FGX / fcc):
 *  - ANSI prototypes (fcc has no K&R definitions); libc fns forward-declared.
 *  - Keeps the BSD open/stat/creat/read/write/close + rindex structure.  These
 *    are all real fcc libc functions (open/creat/stat/rindex/strrchr were added
 *    to the fcc binding table + toolchain/lib/fcc_libc_shims.s for this port —
 *    no per-tool syscall stub).
 *  - Directory test is S_ISDIR(st_mode) on a real `struct stat'.  It was a
 *    hand-counted byte offset into a 16-byte char array, and libc's stat()
 *    writes THIRTY-TWO -- so every cp run overflowed it by sixteen bytes,
 *    into `destname' immediately below it (apple/fgx#292).
 *  - creat() truncates with O_TRUNC.  It used to unlink first, on the
 *    reasoning that SYS_OPEN ignored O_TRUNC; that stopped being true and
 *    the unlink turned out to DELETE device nodes (apple/fgx#323).
 *  - Dropped vs 2.11BSD: -i/-r/-p flags, recursive rcopy (no opendir/readdir in
 *    fcc libc), setimes/utimes/fchmod (unavailable), the st_dev/st_ino
 *    "identical file" check (FGX stat exposes no dev/ino), copyright[]/sccsid[].
 *  - Large buffers are file-scope globals (fcc stack-local arrays are unsafe;
 *    see docs/fcc-known-issues.md).
 */
#include <stdio.h>
#include <string.h>             /* strrchr, strlen */
#include <sys/stat.h>          /* struct stat, S_ISDIR, stat(2) */

#define O_RDONLY        0x0000
/* c_stat returns a POSIX `struct stat` image (task #53): st_mode is the
 * SHORT at offset 4 — S_IFDIR $4000, S_IFREG $8000.  (The pre-#53 shim
 * exposed the NATIVE ST_* image whose mode BYTE sat at offset 0 with the
 * $80 dir bit; statbuf[0] & 0x80 read padding after the change and cp
 * stopped recognizing directory destinations — the cp_dot regression.) */
#define PATHMAX         256
#define COPY_BUFSZ      1024

/* fcc libc (see toolchain/src/cc/globals.c bindings + fcc_libc_shims.s):
   open/creat/stat are the POSIX file syscalls; read/write/close are the
   raw-fd builtins. */
int open(char *path, int flags);
int creat(char *path, int mode);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int close(int fd);

struct stat statbuf;                    /* the real one -- 32 bytes, sys/stat.h */
char destname[PATHMAX];                 /* composed dir/basename target */
char copybuf[COPY_BUFSZ];               /* I/O staging */

/* Copy `from` onto `to`.  If `to` is a directory, copy into it as
   to/basename(from).  Returns 0 on success, 1 on error. */
int copy(char *from, char *to)
{
    int fin, fout, n;
    char *last;

    fin = open(from, O_RDONLY);
    if (fin < 0) {
        fprintf(stderr, "cp: cannot open %s\n", from);
        return 1;
    }
    if (stat(to, &statbuf) == 0 && S_ISDIR(statbuf.st_mode)) {
        last = strrchr(from, '/');
        if (last)
            last++;
        else
            last = from;
        if (strlen(to) + strlen(last) + 2 > PATHMAX) {
            fprintf(stderr, "cp: %s/%s: name too long\n", to, last);
            close(fin);
            return 1;
        }
        sprintf(destname, "%s/%s", to, last);
        to = destname;
    }
    fout = creat(to, 0);
    if (fout < 0) {
        fprintf(stderr, "cp: cannot create %s\n", to);
        close(fin);
        return 1;
    }
    for (;;) {
        n = read(fin, copybuf, COPY_BUFSZ);
        if (n <= 0)
            break;
        if (write(fout, copybuf, n) != n) {
            fprintf(stderr, "cp: write error on %s\n", to);
            close(fin);
            close(fout);
            return 1;
        }
    }
    close(fin);
    close(fout);
    return 0;
}

int main(int argc, char **argv)
{
    int i, rc;

    if (argc < 3) {
        fprintf(stderr, "usage: cp f1 f2  |  cp f1 ... fn dir\n");
        return 1;
    }
    /* With more than two operands, the last must be a directory. */
    if (argc > 3 &&
        (stat(argv[argc - 1], &statbuf) < 0 || !S_ISDIR(statbuf.st_mode))) {
        fprintf(stderr, "cp: %s: not a directory\n", argv[argc - 1]);
        return 1;
    }
    rc = 0;
    for (i = 1; i < argc - 1; i++)
        if (copy(argv[i], argv[argc - 1]))
            rc = 1;
    return rc;
}
