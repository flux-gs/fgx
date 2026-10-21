#!/usr/bin/env python3
"""mkfixture -- write rrtest.hdv, the Rock Ridge volume tests/isofs mounts.

THE VOLUME IS MADE BY AN INDEPENDENT WRITER, pycdlib, and committed: a
fixture made by code written beside the reader would share its mistakes.
Regenerate with pycdlib (pip install pycdlib) after changing what it holds:

    python3 tools/testdata/isofs/mkfixture.py tools/testdata/isofs/rrtest.hdv

WHAT IT HOLDS, and what tests/isofs reads of each:
  ReadMe.txt                       a mixed-case Rock Ridge name (NM)
  A Long File Name With Spaces.txt a long one, with spaces
  <70 x's>.txt                     longer than MAXNAMLEN: the ISO name shows
  runme                            mode 0755 (PX)
  link -> ReadMe.txt               a symbolic link (SL)
  big.txt                          3000 lines, across seven 2048-byte sectors
  many/                            40 files: a directory of several blocks
  level1/.../level9/deep.txt       nine levels, so Rock Ridge relocates one
                                   directory (CL, PL, RE) under rr_moved

16 ZERO SECTORS FOLLOW THE VOLUME, padding as mkisofs and xorriso add it: a
volume's last sector reads as an I/O error on MAME's Apple SCSI CD-ROM
(flux-gs/fgx#17), which a pressed disc never meets.

The image goes in a SmartPort spindle as well as a CD, so its extension is
.hdv, which MAME takes for a raw hard disk.
"""
import io
import sys

import pycdlib


def main(out):
    iso = pycdlib.PyCdlib()
    iso.new(interchange_level=3, rock_ridge='1.09', vol_ident='FGXRR')

    def f(path, rr, data, mode=0o100644):
        b = data.encode()
        iso.add_fp(io.BytesIO(b), len(b), path, rr_name=rr, file_mode=mode)

    f('/README.TXT;1', 'ReadMe.txt', 'hello from rock ridge\n')
    f('/LONGNAME.TXT;1', 'A Long File Name With Spaces.txt', 'long name\n')
    f('/TOOLONG.TXT;1', 'x' * 70 + '.txt', 'too long\n')
    f('/RUNME.;1', 'runme', '#!/bin/sh\necho hi\n', 0o100755)
    f('/BIG.TXT;1', 'big.txt', ''.join('%d\n' % i for i in range(1, 3001)))
    iso.add_symlink('/LINK.;1', rr_symlink_name='link', rr_path='ReadMe.txt')
    iso.add_directory('/MANY', rr_name='many')
    for i in range(40):
        f('/MANY/F%02d.TXT;1' % i, 'file-%02d.txt' % i, 'file %d\n' % i)
    p = ''
    for d in range(1, 10):
        p += '/D%d' % d
        iso.add_directory(p, rr_name='level%d' % d)
    f(p + '/DEEP.TXT;1', 'deep.txt', 'nine levels down\n')

    buf = io.BytesIO()
    iso.write_fp(buf)
    iso.close()
    with open(out, 'wb') as fp:
        fp.write(buf.getvalue())
        fp.write(bytes(16 * 2048))


if __name__ == '__main__':
    main(sys.argv[1])
