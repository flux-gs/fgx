/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/gen/fstab.c
 *   Ported from usr/src/lib/libc/gen/fstab.c, 2.11BSD
 *   (@(#)fstab.c 8.1.1 1996/1/15).  Original work:
 *   Copyright (c) 1980, 1988, 1993
 *   The Regents of the University of California.  All rights reserved.
 */
/* fstab(3) -- /etc/fstab, for fsck(8).  UFS 2.1.
 *
 * Ported line for line.  BOTH LINE FORMATS ARE KEPT, because upstream keeps
 * both and the choice is made per line rather than per file: a line with no
 * space or tab is the OLD colon-separated form (`spec:file:type:freq:passno'),
 * anything else is the whitespace form.  The old form is why strsep(3) had to
 * land with this -- its fields may be EMPTY, and strtok would silently merge
 * `a::b' into two fields instead of three.
 *
 * FGX DELTAS, both in the error path and neither changing what is parsed:
 *   - upstream's error() calls warn(3) via __progname; FGX libc has neither,
 *     so a bad line or a missing file sets errno and stays quiet.  The callers
 *     that care all report for themselves -- fsck's is "Can't open checklist
 *     file: %s".
 *   - getfstype() is not ported.  Upstream 8.1.1 does not define it either;
 *     only the 5.1 header declared it.
 */

#include <errno.h>
#include <fstab.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <stdlib.h>

#define MAXLINELENGTH   256

static FILE        *_fs_fp;
static struct fstab _fs_fstab;
static char         _fs_line[MAXLINELENGTH];
static char         _fs_subline[MAXLINELENGTH];

/* EFTYPE is upstream's "bad fstab line" errno and FGX has no such code; the
 * line is unusable either way, and EINVAL is the nearest thing the tree
 * already defines. */
#ifndef EFTYPE
#define EFTYPE EINVAL
#endif

static int
fstabscan()
{
    char *cp;
    char *bp;
    char *colon = ":";
    int   typexx;

    for (;;) {
        if (!fgets(_fs_line, sizeof(_fs_line), _fs_fp))
            return (0);
        bp = index(_fs_line, '\n');
        if (!bp)
            return (0);
        *bp = '\0';
        cp = _fs_line;

        /* OLD_STYLE_FSTAB: no whitespace anywhere -> colon-separated. */
        if (!strpbrk(cp, " \t")) {
            _fs_fstab.fs_spec = strsep(&cp, colon);
            _fs_fstab.fs_file = strsep(&cp, colon);
            _fs_fstab.fs_type = strsep(&cp, colon);
            if (_fs_fstab.fs_type) {
                if (!strcmp(_fs_fstab.fs_type, FSTAB_XX))
                    continue;
                _fs_fstab.fs_mntops  = _fs_fstab.fs_type;
                _fs_fstab.fs_vfstype =
                    strcmp(_fs_fstab.fs_type, FSTAB_SW) ? "ufs" : "swap";
                if ((bp = strsep(&cp, colon)) != (char *)0) {
                    _fs_fstab.fs_freq = atoi(bp);
                    if ((bp = strsep(&cp, colon)) != (char *)0) {
                        _fs_fstab.fs_passno = atoi(bp);
                        return (1);
                    }
                }
            }
            goto bad;
        }

        _fs_fstab.fs_spec = strtok(cp, " \t");
        if (!_fs_fstab.fs_spec || *_fs_fstab.fs_spec == '#')
            continue;
        _fs_fstab.fs_file    = strtok((char *)0, " \t");
        _fs_fstab.fs_vfstype = strtok((char *)0, " \t");
        _fs_fstab.fs_mntops  = strtok((char *)0, " \t");
        if (_fs_fstab.fs_mntops == (char *)0)
            goto bad;
        _fs_fstab.fs_freq   = 0;
        _fs_fstab.fs_passno = 0;
        if ((cp = strtok((char *)0, " \t")) != (char *)0) {
            _fs_fstab.fs_freq = atoi(cp);
            if ((cp = strtok((char *)0, " \t")) != (char *)0)
                _fs_fstab.fs_passno = atoi(cp);
        }
        /* The mount options are re-split on ',' in their OWN buffer: strtok
         * keeps one static cursor, so scanning them in _fs_line would lose the
         * outer scan's position.  Upstream copies for the same reason. */
        strcpy(_fs_subline, _fs_fstab.fs_mntops);
        typexx = 0;
        for (cp = strtok(_fs_subline, ","); cp; cp = strtok((char *)0, ",")) {
            if (strlen(cp) != 2)
                continue;
            if (!strcmp(cp, FSTAB_RW)) { _fs_fstab.fs_type = FSTAB_RW; break; }
            if (!strcmp(cp, FSTAB_RQ)) { _fs_fstab.fs_type = FSTAB_RQ; break; }
            if (!strcmp(cp, FSTAB_RO)) { _fs_fstab.fs_type = FSTAB_RO; break; }
            if (!strcmp(cp, FSTAB_SW)) { _fs_fstab.fs_type = FSTAB_SW; break; }
            if (!strcmp(cp, FSTAB_XX)) {
                _fs_fstab.fs_type = FSTAB_XX;
                typexx++;
                break;
            }
        }
        if (typexx)
            continue;
        if (cp != (char *)0)
            return (1);

bad:    /* no way to distinguish between EOF and syntax error */
        errno = EFTYPE;
    }
    /* NOTREACHED */
}

int
setfsent()
{
    if (_fs_fp) {
        rewind(_fs_fp);
        return (1);
    }
    if ((_fs_fp = fopen(_PATH_FSTAB, "r")) != (FILE *)0)
        return (1);
    return (0);
}

void
endfsent()
{
    if (_fs_fp) {
        (void)fclose(_fs_fp);
        _fs_fp = (FILE *)0;
    }
}

struct fstab *
getfsent()
{
    if ((!_fs_fp && !setfsent()) || !fstabscan())
        return ((struct fstab *)0);
    return (&_fs_fstab);
}

struct fstab *
getfsspec(name)
char *name;
{
    if (setfsent())
        while (fstabscan())
            if (!strcmp(_fs_fstab.fs_spec, name))
                return (&_fs_fstab);
    return ((struct fstab *)0);
}

struct fstab *
getfsfile(name)
char *name;
{
    if (setfsent())
        while (fstabscan())
            if (!strcmp(_fs_fstab.fs_file, name))
                return (&_fs_fstab);
    return ((struct fstab *)0);
}
