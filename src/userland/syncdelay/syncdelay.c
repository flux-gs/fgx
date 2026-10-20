/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* syncdelay -- does sync(2) push a delayed write out to the platter?
 * apple/fgx#398.
 *
 * THE ONLY DELAYED WRITE IN THE SYSTEM has to be manufactured, and only one
 * thing makes one: spec_write's partial-block arm.  A write to a BLOCK DEVICE
 * NODE that does not fill a whole FS_BLKSIZE buffer takes `bdwrite' and leaves
 * the buffer dirty; every other writer in the tree -- ufs_write, ufs_bmapx,
 * fsck -- writes whole blocks and takes `bawrite', which is already on its way
 * to the disk.  So a test cannot use fsck to produce the condition, and one
 * that tried would be green whatever sync(2) did.
 *
 * READING IT BACK THROUGH THE SAME NODE WOULD PROVE NOTHING.  The buffer cache
 * is keyed by (vnode, logical block), so a read through the fd that made the
 * write is answered from the dirty buffer itself -- the new bytes, whether or
 * not they ever reached the platter.  The raw character face of the same
 * spindle is the second opinion: /dev/rsd<n> goes through the block driver
 * directly and never consults the vnode cache, so what it returns is what is
 * ON the disk.
 *
 * AND THE BLOCK FD STAYS OPEN ACROSS THE SYNC, which is load-bearing rather
 * than incidental: spec_close's VBLK arm flushes (`vflushbuf(vp, 0)' then
 * `vinvalbuf(vp, 1)'), so a close would push the write out and the test would
 * pass on a kernel that never implemented sync at all.
 *
 * MEASURED DISCRIMINATING: with ufs_sync's `bflush' removed, the raw read
 * returns the volume's original bytes and this exits 1.
 *
 * usage: syncdelay /dev/sd1 /dev/rsd1
 */
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

/* A block boundary well past the small filesystem these spindles carry, so a
 * failed run leaves no filesystem worse off: ufsbadspin.fs is about 4,000
 * blocks of an 8,192-block unit.  1024000 is 1000 * FS_BLKSIZE and 2000 * the
 * 512-byte sector, so it is aligned for both faces of the device -- and the
 * write starts AT the boundary, which is what makes it a partial block rather
 * than the tail of a whole one. */
#define OFF     1024000L
#define NB      16

main(argc, argv)
int argc;
char **argv;
{
    int  bfd, rfd, i;
    char out[NB], in[NB];

    if (argc != 3) {
        printf("usage: %s blockdev rawdev\n", argv[0]);
        return (2);
    }
    for (i = 0; i < NB; i++)
        out[i] = (char)('A' + (i & 15));

    bfd = open(argv[1], O_RDWR);
    if (bfd < 0) {
        printf("SYNCDELAY open %s: %s\n", argv[1], strerror(errno));
        return (2);
    }
    if (lseek(bfd, OFF, 0) < 0 || write(bfd, out, NB) != NB) {
        printf("SYNCDELAY write %s: %s\n", argv[1], strerror(errno));
        return (2);
    }

    sync();

    /* The block descriptor is deliberately still open here. */
    rfd = open(argv[2], O_RDONLY);
    if (rfd < 0) {
        printf("SYNCDELAY open %s: %s\n", argv[2], strerror(errno));
        return (2);
    }
    for (i = 0; i < NB; i++)
        in[i] = 0;
    if (lseek(rfd, OFF, 0) < 0 || read(rfd, in, NB) != NB) {
        printf("SYNCDELAY read %s: %s\n", argv[2], strerror(errno));
        return (2);
    }
    close(rfd);
    close(bfd);

    for (i = 0; i < NB; i++) {
        if (in[i] != out[i]) {
            printf("SYNCDELAY STILL DIRTY at byte %d: raw %02x, wrote %02x\n",
                   i, in[i] & 0xFF, out[i] & 0xFF);
            printf("SYNCDELAY FAILED\n");
            return (1);
        }
    }
    printf("SYNCDELAY ON PLATTER\n");
    return (0);
}
