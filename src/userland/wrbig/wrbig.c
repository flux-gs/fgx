/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; the sequence under test is
 * elvis's tmpstart() (vendor/netbsd-0-9/usr.bin/elvis/tmp.c:216-233).
 *
 * wrbig - a WHOLE-BLOCK write(2) onto a UFS root, which is what `vi' does and
 * what a 7-byte shell redirection does not.
 *
 * apple/fgx#318 made open(O_CREAT) reach the root, and `echo x > /tmp/f'
 * proved create + write + read back.  It proved them for SEVEN BYTES.  vi
 * still fails, and its failure is one line further on than the create:
 *
 *     close(creat(tmpname, 0600));
 *     tmpfd = open(tmpname, O_RDWR);
 *     if (write(tmpfd, hdr.c,    (unsigned)BLKSIZE) < BLKSIZE
 *      || write(tmpfd, tmpblk.c, (unsigned)BLKSIZE) < BLKSIZE)
 *             FAIL("Error writing headers to \"%s\"", tmpname);
 *
 * BLKSIZE is 1024 (config.h:615).  So the question this answers is whether a
 * single write of a full FS_BLKSIZE block returns the count it was given --
 * and it reports the COUNT rather than a verdict, because a SHORT write and a
 * FAILED write are different defects: elvis's `< BLKSIZE' cannot tell them
 * apart and neither could the bug report.
 *
 * IT WRITES TWICE, as elvis does.  The second write starts at offset 1024 --
 * exactly the first block boundary -- which is the first place a block-mapped
 * write can go wrong without the first one noticing.
 *
 * The sizes climb so the answer brackets itself: if 512 passes and 1024 does
 * not, the boundary is the block; if both fail, the size is not the variable
 * and the 7-byte case was passing for some other reason.
 */
#include <stdio.h>

int open();
int close();
int creat();
int write();
int read();
long lseek();
int unlink();
char *fopen();
int fclose();
int fputs();

extern int errno;

#define PATH "/tmp/wrbig.t"

static char buf[1024];
static char buf2[256];

static int
try(label, path, flags, docreat)
char *label;
char *path;
int   flags;
int   docreat;
{
    int fd;
    int a;

    unlink(path);
    if (docreat) {
        fd = creat(path, 0600);
        if (fd < 0) {
            printf("wrbig: %s creat FAILED\n", label);
            return (0);
        }
        close(fd);
    }

    fd = open(path, flags);
    if (fd < 0) {
        printf("wrbig: %s open FAILED\n", label);
        return (0);
    }

    errno = 0;
    a = write(fd, buf, 64);
    close(fd);

    printf("wrbig: %s fd=%d wrote=%d errno=%d %s\n", label, fd, a, errno,
           (a == 64) ? "ok" : "BAD");
    return (a == 64);
}

main()
{
    int i;

    for (i = 0; i < 1024; i++)
        buf[i] = 'a';

    /* ORDER IS THE EXPERIMENT: the failing case runs FIRST now.  If it
     * passes here and failed when it ran fourth, the variable is not the
     * open mode at all -- it is how many descriptors came before it, i.e. a
     * leak in the file pool.  fallocat returns ENFILE when no slot has
     * f_count == 0, and _Fcb_Alloc's mirror SWALLOWS that error. */
    try("C_creat_reopen", "/tmp/wc", 2, 1);
    try("D_creat_reopen_wr", "/tmp/wd", 1, 1);
    try("A_wronly_creat", "/tmp/wa", 1 | 0x200 | 0x400, 0);
    try("B_rdwr_creat",   "/tmp/wb", 2 | 0x200 | 0x400, 0);
    try("E_again",        "/tmp/we", 1 | 0x200 | 0x400, 0);
    try("F_again",        "/tmp/wf", 1 | 0x200 | 0x400, 0);

    /* G: THE resolv.conf SHAPE.  Lay down a long line, then fopen(,"w") a
     * SHORT one over it and read back what is actually on disk.  This is
     * dhclient rewriting /etc/resolv.conf: it wrote 41 bytes over an 83-byte
     * file and the old tail survived, because "w" was relying on an unlink
     * that answers EIO on a UFS root.  The assertion is the LENGTH -- a file
     * that is still 83 bytes long has not been truncated, whatever its
     * front looks like. */
    {
        char *f;
        int   fd;
        int   n;

        unlink("/tmp/wg");
        fd = creat("/tmp/wg", 0600);
        write(fd, buf, 83);
        close(fd);

        f = fopen("/tmp/wg", "w");
        if (f == (char *)0) {
            printf("wrbig: G fopen FAILED\n");
        } else {
            fputs("short", f);
            fclose(f);
            fd = open("/tmp/wg", 0);
            n = read(fd, buf2, 200);
            close(fd);
            printf("wrbig: G_fopen_w len=%d %s\n", n,
                   (n == 5) ? "ok" : "NOT TRUNCATED");
        }
    }

    /* H: THE elvis garbage() SHAPE -- apple/fgx#322.  Write two blocks,
     * REWIND with lseek(fd, 0, SEEK_SET), and read the first one back.  That
     * is recycle.c:60-62 exactly: elvis lays down two header blocks, rewinds
     * and re-reads the first, and answered "garbage() failed to read
     * oldhdr??" because the seek never reached the offset the reads use --
     * the VFS file pool's f_offset -- so the read continued from EOF and
     * returned 0.  The assertion is the BYTE COUNT of the read after the
     * seek; a seek that silently did nothing leaves it at 0. */
    {
        int  fd;
        long pos;
        int  n;

        unlink("/tmp/wh");
        fd = open("/tmp/wh", 1 | 0x200 | 0x400);
        write(fd, buf, 1024);
        write(fd, buf, 1024);
        close(fd);

        fd = open("/tmp/wh", 0);
        n = read(fd, buf2, 200);
        pos = lseek(fd, 0L, 0);
        n = read(fd, buf2, 200);
        close(fd);
        printf("wrbig: H_seek_reread pos=%d got=%d %s\n", (int)pos, n,
               (n == 200) ? "ok" : "SEEK BROKEN");
    }

    /* I: THE ERRNO FOR A NAME THAT IS NOT THERE.  It must be ENOENT (2) and
     * nothing else, because callers BRANCH ON IT: elvis keeps the filename it
     * was given only when a failed open reports exactly ENOENT
     * (tmp.c:112) -- any other errno makes it print "Can't open" and restart
     * with NO NAME, which is why `vi /tmp/vt' then answers "Don't know a name
     * for this file -- NOT WRITTEN" to :wq.  fopen(,"r") and access(2) read
     * the same way. */
    {
        int fd;

        unlink("/tmp/wi_absent");
        errno = 0;
        fd = open("/tmp/wi_absent", 0);
        printf("wrbig: I_absent fd=%d errno=%d %s\n", fd, errno,
               (fd < 0 && errno == 2) ? "ok" : "NOT ENOENT");
    }

    /* J: THE DEVICE NODE, flag by flag -- apple/fgx#323.  `echo x > /dev/console'
     * writes nothing while `>>' writes fine, and the shell cannot say WHY: the
     * errno is what separates a permission refusal (EACCES/EPERM) from
     * anything else.  The three opens differ only in the bits named. */
    {
        int fd;

        errno = 0; fd = open("/dev/console", 1);
        printf("wrbig: J1 wronly        fd=%d errno=%d\n", fd, errno);
        if (fd >= 0) close(fd);

        errno = 0; fd = open("/dev/console", 1 | 0x200 | 0x400);
        printf("wrbig: J2 wronly+cr+tr  fd=%d errno=%d\n", fd, errno);
        if (fd >= 0) close(fd);

        errno = 0; fd = open("/dev/console", 1 | 0x200 | 0x008);
        printf("wrbig: J3 wronly+cr+ap  fd=%d errno=%d\n", fd, errno);
        if (fd >= 0) close(fd);

        errno = 0; fd = open("/dev/console", 1 | 0x400);
        printf("wrbig: J4 wronly+tr     fd=%d errno=%d\n", fd, errno);
        if (fd >= 0) close(fd);

        /* AND THE WRITE, which is what the shell actually could not do.  The
         * opens all succeed, so if a byte does not land the refusal is further
         * on than #323's first reading assumed. */
        errno = 0; fd = open("/dev/console", 1 | 0x200 | 0x400);
        if (fd >= 0) {
            int n;
            errno = 0;
            n = write(fd, "J5-TRUNC-WROTE\n", 15);
            close(fd);
            printf("wrbig: J5 trunc write   n=%d errno=%d\n", n, errno);
        }
        errno = 0; fd = open("/dev/console", 1 | 0x200 | 0x008);
        if (fd >= 0) {
            int n;
            errno = 0;
            n = write(fd, "J6-APPEND-WROTE\n", 16);
            close(fd);
            printf("wrbig: J6 append write  n=%d errno=%d\n", n, errno);
        }
    }

    printf("wrbig: done\n");
    return (0);
}
