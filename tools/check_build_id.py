#!/usr/bin/env python3
"""Check that the kernel and every module agree on the core build identity.

The identity is generated TWICE, from one term list, by two different routes:
the KERNEL side is a symbolic Merlin expression that the assembler resolves
(src/kernel/kernel_build_id.s -> `_kernBuildId`), the MODULE side is the same
sum resolved in Python from the kernel listing (KERN_BUILD_ID in each
kernel_exports.s, baked into the FGXM header at +34).  Both routes exist
because neither one alone can run at the right time -- see the header of
tools/gen_kernel_exports.py.

Two routes to one number is exactly the shape that drifts.  If they disagree,
the kernel refuses every module at boot and the machine comes up without its
filesystem module, its serial driver and its network stack -- a spectacular
failure a long way from its cause.  This check turns that into a build error
that names the number.

Also mints the deliberately-stale module the runtime test needs (--stale),
because a check nothing can make fail is not a check.

Usage:  check_build_id.py [<listing>]        verify (default listing/paths)
        check_build_id.py --stale <in> <out> copy a .mod with a WRONG id
        check_build_id.py --self-test
"""
import glob
import os
import re
import sys

LISTING = 'build/fgx_S01_KernelMain_Output.txt'
MODULE_BIN = 'disk_src/lib/modules'
FGXM_OFF_COREBUILD = 34         # keep in step with include/fgxm.s

# The listing line that defines _kernBuildId, e.g.
#   ... | 02/DE63 : 5C B2       | _kernBuildId  DA  ...
KBID_RE = re.compile(r'02/[0-9A-Fa-f]{4}\s*:\s*([0-9A-Fa-f]{2})\s+([0-9A-Fa-f]{2})'
                     r'\s*\|\s*_kernBuildId\b')
EQU_RE = re.compile(r'^KERN_BUILD_ID\s+EQU\s+\$([0-9A-Fa-f]{4})\s*$', re.M)


def kernel_id(listing):
    """The id the KERNEL will publish, read from its own emitted bytes."""
    with open(listing, errors='replace') as f:
        for line in f:
            m = KBID_RE.search(line)
            if m:                                   # little-endian DA
                return int(m.group(2), 16) << 8 | int(m.group(1), 16)
    sys.exit(f'check_build_id: no _kernBuildId definition in {listing} -- is '
             'src/kernel/kernel_build_id.s still PUT by main.s?')


def module_header_id(path):
    with open(path, 'rb') as f:
        hdr = f.read(FGXM_OFF_COREBUILD + 2)
    if len(hdr) < FGXM_OFF_COREBUILD + 2 or hdr[:4] != b'FGXM':
        sys.exit(f'check_build_id: {path} is not an FGXM image')
    return hdr[FGXM_OFF_COREBUILD] | hdr[FGXM_OFF_COREBUILD + 1] << 8


def make_stale(src, dst):
    """Write a copy whose build id is wrong -- the fixture for the red test.

    Deliberately picks a value that is neither the real id nor $0000, so the
    copy is BUILD-LOCKED and WRONG rather than merely unlocked: an unlocked
    module loads fine, which would make the test pass for the wrong reason.
    """
    with open(src, 'rb') as f:
        image = bytearray(f.read())
    if image[:4] != b'FGXM':
        sys.exit(f'check_build_id: {src} is not an FGXM image')
    real = image[FGXM_OFF_COREBUILD] | image[FGXM_OFF_COREBUILD + 1] << 8
    bogus = 0xDEAD if real != 0xDEAD else 0xBEEF
    image[FGXM_OFF_COREBUILD] = bogus & 0xFF
    image[FGXM_OFF_COREBUILD + 1] = bogus >> 8
    with open(dst, 'wb') as f:
        f.write(image)
    print(f'check_build_id: wrote {dst} (build id ${real:04X} -> ${bogus:04X})')


def self_test():
    import tempfile
    line = ('  1  kernel_build_id.s 25 | Data | 00 | | 2 | 02/DE63 : 5C B2'
            '       | _kernBuildId                  DA   ...\n')
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, 'listing.txt')
        open(p, 'w').write('noise\n' + line)
        assert kernel_id(p) == 0xB25C, hex(kernel_id(p))

        # A module whose header says $B25C, staled to something else.
        img = os.path.join(d, 'MOD')
        hdr = bytearray(b'FGXM' + bytes(FGXM_OFF_COREBUILD - 4) + b'\x5C\xB2')
        open(img, 'wb').write(hdr)
        assert module_header_id(img) == 0xB25C
        stale = os.path.join(d, 'STALE')
        make_stale(img, stale)
        assert module_header_id(stale) != 0xB25C
        assert module_header_id(stale) != 0, 'stale copy must stay build-LOCKED'
    print('check_build_id: self-test OK')


def main():
    if '--self-test' in sys.argv:
        return self_test()
    if sys.argv[1:2] == ['--stale']:
        if len(sys.argv) != 4:
            sys.exit(__doc__.strip().splitlines()[-2])
        return make_stale(sys.argv[2], sys.argv[3])

    listing = sys.argv[1] if len(sys.argv) > 1 else LISTING
    kid = kernel_id(listing)
    checked = 0

    for path in sorted(glob.glob('src/modules/*/kernel_exports.s')):
        m = EQU_RE.search(open(path).read())
        if not m:
            sys.exit(f'check_build_id: {path} has no KERN_BUILD_ID -- '
                     'regenerate it (tools/gen_kernel_exports.py)')
        mid = int(m.group(1), 16)
        if mid != kid:
            sys.exit(f'check_build_id: {path} says ${mid:04X}, the kernel '
                     f'publishes ${kid:04X}.  The two generators disagree; '
                     'every module built from this tree would be REFUSED at '
                     'boot.  Rebuild the kernel, then the modules.')
        checked += 1

    # And the same word as it actually landed in the shipped images.  A module
    # with no kernel_exports.s must carry $0000 (not build-locked) -- if it
    # ever carried a stale non-zero id it would refuse to load for no reason.
    for path in sorted(glob.glob(os.path.join(MODULE_BIN, '*'))):
        if not os.path.isfile(path):
            continue
        name = os.path.basename(path).lower()
        locked = os.path.isfile(f'src/modules/{name}/kernel_exports.s')
        hid = module_header_id(path)
        want = kid if locked else 0
        if hid != want:
            sys.exit(f'check_build_id: {path} header says ${hid:04X}, expected '
                     f'${want:04X} ' + ('(this build)' if locked else
                                        '($0000 -- it bakes no kernel addresses)'))
        checked += 1

    print(f'check_build_id: OK (core build ${kid:04X}, {checked} agreeing)')


if __name__ == '__main__':
    main()
