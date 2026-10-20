/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/gen/getwd.c
 *   Ported from usr/lib/libc/gen/getwd.c, 2.11BSD
 *   (@(#)getwd.c 5.2 (Berkeley) 3/9/86).  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* getwd(3) -- the pathname of the current working directory, and the ONLY
 * current-directory call libc provides.  There is deliberately no getcwd():
 * 2.11BSD tar.c defines its OWN one-arg getcwd(buf) wrapper around getwd(), so
 * a libc getcwd was never the BSD interface at all.
 *
 * THE KERNEL DOES NOT ANSWER THIS ANY MORE, AND THAT IS THE POINT.  It used to
 * be SYS_GETCWD (#42) reading a per-task cwd STRING the kernel maintained --
 * a string table, a scheduler cell repointed on every context switch, a
 * fork-time copy, and src/drivers/fs/path.s to canonicalise into it.  BSD keeps
 * the cwd as a VNODE and nothing else, and answers "what is my cwd" up here, by
 * walking the tree.  Retiring the string is apple/fgx#344; this is what had to
 * exist first.
 *
 * IT WALKS UP THROUGH `..' AND MATCHES EACH LEVEL BY INODE, which is why
 * apple/fgx#358 blocked it: readdir(3) reported a synthesized d_ino of 1 for
 * every entry, so `while (dir->d_ino != cino)' ran to end-of-directory and this
 * answered "getwd: read error in ..".
 *
 * Error convention (unusual, and callers depend on it): returns NULL and leaves
 * a HUMAN-READABLE MESSAGE in pathname.  That is why 2.11BSD pwd.c and tar.c
 * both print `%s' with the very buffer they passed in; an implementation that
 * left it untouched would print garbage.
 *
 * buf MUST be at least MAXPATHLEN.
 *
 * DIVERGENCE: upstream declares `dev_t cdev, rdev' and `ino_t cino, rino'.
 * FGX's struct stat carries st_dev as short and st_ino as unsigned short
 * (sys/stat.h), and fcc has no dev_t/ino_t, so those are spelled out here.  The
 * comparisons are unchanged.
 */
#define GETWDERR(s) strcpy(pathname, (s));

static int pathsize;                    /* pathname length */

static char *__getwd_prepend();

char *getwd(pathname)
char *pathname;
{
    char pathbuf[MAXPATHLEN];           /* temporary pathname buffer */
    char *pnptr = &pathbuf[(sizeof pathbuf) - 1];
    char curdir[MAXPATHLEN];            /* current directory buffer */
    char *dptr = curdir;
    short cdev, rdev;                   /* current & root device number */
    unsigned short cino, rino;          /* current & root inode number */
    DIR *dirp;
    struct direct *dir;
    struct stat d, dd;

    pathsize = 0;
    *pnptr = '\0';
    if (stat("/", &d) < 0) {
        GETWDERR("getwd: can't stat /");
        return ((char *)0);
    }
    rdev = d.st_dev;
    rino = d.st_ino;
    strcpy(dptr, "./");
    dptr += 2;
    if (stat(curdir, &d) < 0) {
        GETWDERR("getwd: can't stat .");
        return ((char *)0);
    }
    for (;;) {
        if (d.st_ino == rino && d.st_dev == rdev)
            break;                      /* reached root directory */
        cino = d.st_ino;
        cdev = d.st_dev;
        strcpy(dptr, "../");
        dptr += 3;
        if ((dirp = opendir(curdir)) == (DIR *)0) {
            GETWDERR("getwd: can't open ..");
            return ((char *)0);
        }
        fstat(dirp->dd_fd, &d);
        if (cdev == d.st_dev) {
            if (cino == d.st_ino) {
                /* reached root directory */
                closedir(dirp);
                break;
            }
            do {
                if ((dir = readdir(dirp)) == (struct direct *)0) {
                    closedir(dirp);
                    GETWDERR("getwd: read error in ..");
                    return ((char *)0);
                }
            } while (dir->d_ino != cino);
        } else
            do {
                if ((dir = readdir(dirp)) == (struct direct *)0) {
                    closedir(dirp);
                    GETWDERR("getwd: read error in ..");
                    return ((char *)0);
                }
                strcpy(dptr, dir->d_name);
                lstat(curdir, &dd);
            } while (dd.st_ino != cino || dd.st_dev != cdev);
        closedir(dirp);
        pnptr = __getwd_prepend("/", __getwd_prepend(dir->d_name, pnptr));
    }
    if (*pnptr == '\0')                 /* current dir == root dir */
        strcpy(pathname, "/");
    else
        strcpy(pathname, pnptr);
    return (pathname);
}

/*
 * prepend() tacks a directory name onto the front of a pathname.
 *
 * RENAMED from upstream's `prepend'.  libc here is ONE pile translation unit
 * (lib/libc_c/libc_c.c #includes every file), so a static named `prepend' would
 * collide with any other file's, and the name is common enough to be worth
 * spending the divergence on.
 */
static char *__getwd_prepend(dirname, pathname)
register char *dirname;
register char *pathname;
{
    register int i;                     /* directory name size counter */

    for (i = 0; *dirname != '\0'; i++, dirname++)
        continue;
    if ((pathsize += i) < MAXPATHLEN)
        while (i-- > 0)
            *--pathname = *--dirname;
    return (pathname);
}
