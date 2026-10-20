/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libc (usr/lib/libc/gen/mktemp.c)
 *   Ported from mktemp.c 5.4 (Berkeley) 9/14/87.
 *   Copyright (c) 1987 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * mktemp(3) / mkstemp(3) — turn a "....XXXXXX" template into a unique name.
 *
 * Kept from upstream verbatim in shape: seed the trailing X's from the pid,
 * verify the target DIRECTORY exists, then loop open(O_CREAT|O_EXCL) and, on
 * EEXIST, advance the name with Berkeley's a..z-with-carry walk.
 *
 * FGX notes:
 *  - mkstemp's uniqueness IS O_EXCL.  FGX's SYS_OPEN honours it as of the
 *    novi port; before that, O_CREAT|O_EXCL on an existing file fell back to
 *    plain open and handed back the colliding file, which would have made
 *    this loop return someone else's fd on its first iteration.
 *  - ProDOS caps a filename at 15 chars and matches case-INSENSITIVELY.  The
 *    walk only ever writes digits and lowercase letters, so it cannot collide
 *    with itself through case folding, but a caller's template must leave the
 *    basename within 15 characters ("/tmp/fooXXXXXX" is 9).
 *  - S_ISDIR replaces upstream's `sbuf.st_mode & S_IFDIR`: FGX packs the mode
 *    16-bit (S_IFREG 0x8000, S_IFDIR 0x4000), not in the classic octal
 *    layout, so the type field is compared rather than masked.
 */

#define _MKTEMP_YES 1
#define _MKTEMP_NO  0

static int
_gettemp(char *as, int *doopen)
{
    char *start, *trv;
    struct stat sbuf;
    unsigned int pid;

    pid = (unsigned int)getpid();

    /* extra X's get set to 0's */
    for (trv = as; *trv; ++trv)
        ;
    while (*--trv == 'X') {
        *trv = (char)((pid % 10) + '0');
        pid /= 10;
    }

    /*
     * Check that the target directory exists; if you have six X's and the
     * directory is missing, the loop below would otherwise run for a *very*
     * long time.
     */
    for (start = ++trv; trv > as && *trv != '/'; --trv)
        ;
    if (*trv == '/') {
        *trv = '\0';
        if (stat(as, &sbuf) || !S_ISDIR(sbuf.st_mode))
            return _MKTEMP_NO;
        *trv = '/';
    } else if (stat(".", &sbuf) == -1)
        return _MKTEMP_NO;

    for (;;) {
        if (doopen) {
            /* 0600 IS UPSTREAM'S AND IT IS BACK.  It was dropped while
             * open(2) took two arguments and SYS_OPEN had nowhere to put a
             * mode; open(2) carries the third argument now and the kernel
             * masks and honours it.  A temporary file readable by anyone is
             * the reason upstream names 0600 rather than letting the umask
             * decide (2.11BSD lib/libc/gen/mktemp.c:72). */
            *doopen = open(as, O_CREAT | O_EXCL | O_RDWR, 0600);
            if (*doopen >= 0)
                return _MKTEMP_YES;
            if (errno != EEXIST)
                return _MKTEMP_NO;
        } else if (stat(as, &sbuf))
            return errno == ENOENT ? _MKTEMP_YES : _MKTEMP_NO;

        /* tricky little algorithm for backward compatibility */
        for (trv = start;;) {
            if (!*trv)
                return _MKTEMP_NO;
            if (*trv == 'z')
                *trv++ = 'a';
            else {
                if (isdigit(*trv))
                    *trv = 'a';
                else
                    ++*trv;
                break;
            }
        }
    }
    /*NOTREACHED*/
}

int
mkstemp(char *as)
{
    int fd;

    return _gettemp(as, &fd) ? fd : -1;
}

char *
mktemp(char *as)
{
    return _gettemp(as, (int *)0) ? as : (char *)0;
}
