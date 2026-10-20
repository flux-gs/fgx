/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * dblind - a read through the DOUBLE INDIRECT block, which nothing exercised.
 *
 * apple/fgx#322 recorded the gap in its own words: "nothing has ever read one
 * through the vnode path: bigread -- the only test that goes past the direct
 * blocks at all -- is 48 KB, which is single indirect."  With FS_BLKSIZE 1024,
 * NDADDR 4 and NINDIR 256 (ufs_fs.h), the direct blocks cover 4 KB and the
 * single indirect reaches 266,240 bytes.  Past that, ufs_bmap must descend two
 * levels or answer with a hole.
 *
 * /root/ntp/beatbox.ntp is 379,464 bytes, so an offset of 300,000 is
 * unambiguously in double-indirect territory -- 33,760 bytes past the ceiling,
 * which is not a boundary case that a fencepost could reach by accident.
 *
 * IT SEEKS RATHER THAN READS THE WHOLE FILE, and that is the point of doing it
 * this way: a sequential read to 300 KB would exercise the same blocks but take
 * minutes of guest time, while a seek + one read touches exactly the bmap
 * descent under test.  It therefore also depends on lseek reaching the VFS
 * (apple/fgx#322's other half), which is deliberate -- both are the same fix.
 *
 * THE EXPECTED BYTES ARE THE HOST TOOL'S ANSWER, not this program's.  fgxfs.py
 * is the tree's INDEPENDENT implementation of the format, so the sum below is
 * two implementations agreeing about the same 16 bytes rather than FGX
 * agreeing with itself:
 *
 *     python3 tools/fgxfs.py cat disk/fgxroot.fs /root/ntp/beatbox.ntp
 *       [300000:300016] = 6B 67 66 62 5F 58 52 52 54 5A 65 70 75 77 7F 8B
 *       sum = 1646
 *
 * A SUM AND NOT A LENGTH, because a short read, a hole and the wrong block all
 * return bytes: only the VALUES say the descent landed where it was asked.  A
 * hole reads as zeros and sums to 0, which is the failure this is most likely
 * to meet.
 */
#include <stdio.h>

int open();
int close();
int read();
long lseek();

#define PATH   "/root/ntp/beatbox.ntp"
#define OFF    300000L
#define WANT   1646

static char buf[16];

main()
{
    int  fd;
    long pos;
    int  n;
    int  i;
    int  sum;

    fd = open(PATH, 0);
    if (fd < 0) {
        printf("dblind: FAIL cannot open %s\n", PATH);
        return (1);
    }
    pos = lseek(fd, OFF, 0);
    n = read(fd, buf, 16);
    close(fd);

    sum = 0;
    for (i = 0; i < n; i++)
        sum = sum + (buf[i] & 0xFF);

    printf("dblind: pos=%ld n=%d sum=%d\n", pos, n, sum);
    if (pos != OFF)
        printf("dblind: FAIL seek landed at %ld, wanted %ld\n", pos, OFF);
    else if (n != 16)
        printf("dblind: FAIL short read %d\n", n);
    else if (sum != WANT)
        printf("dblind: FAIL sum %d, wanted %d\n", sum, WANT);
    else
        /* THE CEILING IS NOT PRINTED AS A NUMBER.  int is SIXTEEN BITS
         * here, and 266240 & 0xFFFF is 4096 -- so `printf("%d", 266240)'
         * announced the DIRECT-block ceiling while the test was proving it
         * had gone far past it.  The offset above is a long and prints
         * correctly; this one is a string. */
        printf("dblind: OK double-indirect read past 266240 bytes\n");
    return (0);
}
