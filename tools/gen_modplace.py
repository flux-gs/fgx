#!/usr/bin/env python3
"""Place a module inside the shared module bank, densely, at build time.

WHY THERE IS A LAYOUT AT ALL.  One module per bank was costing a 64 KB bank for
a 2 KB driver: measured 2026-08-11, the five modules total 17,084 bytes and
occupied FOUR banks -- 262 KB of address space for 17 KB of code.  They now
stack into ONE bank, which also leaves room for the drivers still to be
migrated out of the core bank (pty, ttyv, pipe, ramdisk, dev, console, VFS).

WHY IT IS DECIDED AT BUILD TIME.  Module code is ORG-dependent: every internal
absolute reference is a 16-bit offset from the module's ORG base, so a module
must be loaded at exactly the offset it was assembled for.  There is no
relocation table and there should not be one -- Merlin32 emits no relocation
information, and a tool that reconstructed it by parsing the listing would have
to tell module-internal addresses from constants and hardware registers, which
is the kind of generated table this tree has repeatedly watched go stale.

HOW THE CIRCULARITY IS BROKEN.  A module's size is known only after assembling
it; its ORG must be known before.  So placement is a CHAIN rather than a table:
module N's offset is the running cursor over the MEASURED footprints of modules
1..N-1, each of which was assembled exactly once, at its own final ORG.  Nothing
is estimated and nothing is budgeted, so there is no slack to tune and no
hand-maintained table to drift.  The cost is that modules build serially and
that growing an early module rebuilds the ones after it -- both cheap at this
scale, and both preferable to a layout a human keeps in their head.

A KNOCK-ON WORTH KNOWING: net and bpf carry TRACKED w5100_patchsites.s
tables of placement-ABSOLUTE addresses, generated from their own build
listings.  Because placement is a chain, a granule-crossing size change in
ANY module earlier in ORDER shifts them, and the `modcheck` build edge then
fails on a file whose module nobody touched.  The fix is to regenerate:
  python3 tools/gen_w5100_patchsites.py build/module_<m>_Output.txt \
          --bank 05 src/modules/<m>/w5100_patchsites.s
and it may take two passes, since that table is an input to the very
assembly whose listing generates it.

NOTHING IS PINNED AT OFFSET 0 ANY MORE.  prodos.mod was, because the boot
loader pre-staged it by MVN to <bank>:$0000 before the kernel ran, and that pin
was what let this scheme leave the boot loader alone.  Stage 2 carries its
pre-staged segments inside the kernel image now and tells the kernel about them
through PRESTAGED_ABS, so the modules this file places are all post-boot LKMs
and the first of them may sit wherever the chain starts.

Usage:  gen_modplace.py <module> <out.s> [<earlier-module-image> ...]
        gen_modplace.py --verify <module-image> ...
        gen_modplace.py --collide <in-image> <target-image> <out-image>
"""
import os
import sys

# Placement order: the order modules are placed in, not the order they are
# loaded in.  It is fixed rather than sorted by size because sizes are not known
# until the modules are built -- and with 23 KB in a 64 KB bank there is nothing
# for a size-ordered fit to win.
# pty appended LAST deliberately: placement is a chain, and inserting
# anywhere earlier would shift net's and bpf's tracked, placement-absolute
# w5100_patchsites.s tables and fail a check on modules nobody touched.  That is
# also what removing prodos from the head of this list cost: both tables were
# regenerated in the same commit, in two passes, because each is an input to
# the assembly whose listing generates it.
# hello, hellofail and hellokc left on 2026-09-07 (test fixtures).  Only `pty'
# moved: the three sat at or after index 4, so net's and bpf's placement-
# absolute w5100_patchsites.s tables -- the tables the note above is about --
# were ahead of them and did not shift.
ORDER = ('net', 'serial', 'bpf', 'ramdisk', 'pty',
         'vfs', 'ufs', 'ufsprobe', 'ufsdir', 'prodos', 'prodosw', 'cda',
         'sscon', 'klog', 'fpsim', 'ld', 'isofs')
# fpsim (the soft double, apple/fgx#447) packs after klog, appended.
# klog packs after sscon.  APPENDED, never inserted: net's and bpf's
# placement-absolute w5100_patchsites.s tables sit at indices 0 and 2, and an
# insertion anywhere ahead of them would move the offsets those tables bake in.
# cda packs into the shared bank after pty.  Appended, so nothing already
# placed in any bank moves.

# WHICH BANK each module packs into.  Absent = 0, the shared module bank, which
# is every module that existed before this table.
#
# A SEPARATE BANK IS FOR SIZE, NOT FOR ISOLATION.  Stacking exists because a
# 64 KB bank for a 2 KB driver is indefensible; the answer to a module that is
# most of a bank on its own is not to abandon stacking but to give that one its
# own chain.  vfs is ~36 KB today and UFS 1.6b (namei) adds ~10 KB, so it would
# crowd the shared bank out of room for the drivers still to migrate -- and a
# module that outgrows its bank mid-campaign is a rebuild of every module placed
# after it.  Decided BEFORE it is wired rather than after it overflows.
#
# Each ordinal is its OWN chain starting at 0, so adding a module to a new bank
# shifts NOTHING in bank 0 -- including net's and bpf's placement-absolute
# w5100_patchsites.s tables.  ufs proved that in the cheapest possible way
# (apple/fgx#169): it arrived as one entry here and moved nothing.
#
# ufs is ordinal 2 for the reason stated above rather than for isolation.  UFS
# 1.10b filled vfs's bank -- the shipping side alone reached 54,893 of 65,536
# and a probe gate stopped assembling -- and 1.11-1.13 (read path, write
# path, directory ops) all land in the same module.  Putting it in the shared
# bank would have crowded out the drivers still to migrate and then overflowed
# anyway, which is the exact failure this comment already warned about.
OWN_BANK = {'vfs': 1, 'ufs': 2, 'ufsprobe': 3, 'ufsdir': 4, 'prodos': 5,
            'prodosw': 6, 'isofs': 7}
# isofs is ordinal 7, for prodos's reason: a filesystem is most of a bank, and
# appended here and to ORDER it moves nothing already placed.
# prodos is ordinal 5 for size.  It packed last in the shared bank, where its
# slot ran from $4500 to the end of the bank, 47,872 bytes; create and mkdir
# took it to 52,327, and unlink, rmdir, rename and truncate are still to come.
# It was last in ORDER, so leaving the shared chain moved nothing.
# prodosw is ordinal 6, also for size: rename and truncate took prodos.mod past
# a whole bank, and its write half (prodos_write.c) moved out.  Appended, so
# again nothing already placed moves.
# ufsdir is the NAME half of UFS, split off at the UFS bank split because ufs.mod's SHIPPING
# code reached 60,211 bytes of 65,536 with 1.13 and 2.6 still ahead -- and the
# escape used at 1.12c, moving the probes out, was already spent.  The seam was
# MEASURED: 42 call sites cross from the name half into the block half and zero
# the other way.  Appending here is the safe direction this file's own comment
# argues for -- a new chain shifts nothing already placed.
# ufsprobe is TEST CODE IN ITS OWN BANK, which reads like an extravagance and is
# the cheapest option that was left.  At UFS 1.12c ufs.mod's SHIPPING code
# reached 50,992 bytes of its 65,536 and two of its three probe gates stopped
# fitting beside it; the gates had already been split twice for the same reason,
# and a third split would have bought one increment.  A bank ordinal costs
# address space, which this machine has, rather than bank space, which it does
# not -- and it means test code never competes with shipping code again.  The
# module is only ever LOADED when a probe gate is on; at the shipping config it
# assembles to a header and nothing else.


def bank_of(module):
    return OWN_BANK.get(module, 0)


def chain_for(module):
    """The modules placed before `module` IN ITS OWN BANK, in ORDER order."""
    b = bank_of(module)
    return [m for m in ORDER[:ORDER.index(module)] if bank_of(m) == b]

BANK_BASE = 0x050000        # modules assemble in bank $05; the low 16 bits are
                            # the offset, and the BANK byte is the ORDINAL --
                            # $05 = the shared bank, $06 = the second, and so
                            # on.  The loader maps ordinal -> a real bank it
                            # allocates; nothing here knows the runtime bank.
BANK_SIZE = 0x10000
GRANULE = 0x100             # round each module up to a page, so one module
                            # growing by a byte does not reshuffle the rest by
                            # an odd amount and listings stay readable
FGXM_HEADER_SZ = 40


def footprint(path):
    """Bytes this module occupies in the bank: header + text + bss."""
    with open(path, 'rb') as f:
        image = f.read()
    if image[:4] != b'FGXM':
        sys.exit(f'gen_modplace: {path} is not an FGXM image')
    bss = image[12] | image[13] << 8
    return len(image) + bss


def load_offset(path):
    """The offset the module's FGXM header tells the loader to place it at."""
    with open(path, 'rb') as f:
        hdr = f.read(8)
    if hdr[:4] != b'FGXM':
        sys.exit(f'gen_modplace: {path} is not an FGXM image')
    return hdr[4] | hdr[5] << 8


def load_bank_ord(path):
    """The BANK ORDINAL from the header's load-address high byte.

    $05 is the assembly convention for the shared bank, so ordinal 0; $06 is
    the second module bank, and so on.  Read from the built image rather than
    from OWN_BANK, so this check tests what was BUILT instead of restating
    what the table says.
    """
    with open(path, 'rb') as f:
        hdr = f.read(8)
    if hdr[:4] != b'FGXM':
        sys.exit(f'gen_modplace: {path} is not an FGXM image')
    return hdr[6] - (BANK_BASE >> 16)


def verify(images):
    """Prove the built images actually pack, rather than trusting the chain.

    The chain places each module from its predecessors' sizes, so overlap
    should be impossible -- but "should be impossible" is what a mis-wired
    build edge looks like from the inside, and two modules at the same offset
    would silently overwrite each other's code with no symptom until whichever
    ran second jumped into the wrong bytes.  Cheap to check, so check.
    """
    banks = {}
    for path in images:
        name = os.path.basename(path).lower()
        banks.setdefault(load_bank_ord(path), []).append(
            (load_offset(path), footprint(path), name))

    summary = []
    for bank in sorted(banks):
        placed = sorted(banks[bank])
        end = verify_one(bank, placed)
        used = sum(size for _o, size, _n in placed)
        summary.append(f'bank {bank}: {len(placed)} module(s), {used} B used, '
                       f'{BANK_SIZE - end} free ('
                       + ', '.join(f'{n}@${o:04X}' for o, _s, n in placed) + ')')
    print('gen_modplace: OK -- ' + '; '.join(summary))


def verify_one(bank, placed):
    """Overlap + fit for ONE bank's chain.  Returns the end cursor."""
    end, prev = 0, None
    for entry in placed:
        off, size, name = entry
        if off < end:
            # `prev` is carried rather than re-derived: searching back for
            # `p[0] < off` finds NOTHING when two modules claim the SAME
            # offset, and [-1] of that empty list raised IndexError -- a
            # traceback instead of the diagnostic, on the one input this
            # check most needs to describe.
            sys.exit(f'gen_modplace: {name} at ${off:04X} OVERLAPS '
                     f'{prev[2]} (${prev[0]:04X}+{prev[1]}) in module bank '
                     f'{bank}. The placement chain and the built images '
                     'disagree.')
        end, prev = off + size, entry
    if end > BANK_SIZE:
        sys.exit(f'gen_modplace: module bank {bank} overflows '
                 f'(${end:04X} > ${BANK_SIZE:04X}). Give one of its modules '
                 'its own bank via OWN_BANK in this file.')
    # Only bank 0 has the pinned-at-zero requirement: the boot loader MVNs the
    # PRE-STAGED module to <bank>:$0000, and only bank 0 is ever pre-staged.
    # A later bank's chain starts at 0 too, but because a chain starts at 0 --
    # not because anything MVNs to it.
    if bank == 0 and placed and placed[0][0] != 0:
        sys.exit('gen_modplace: nothing is placed at offset 0 of the shared '
                 'bank, but the boot loader MVNs the pre-staged module to '
                 '<bank>:$0000.')
    return end


def collide(src, target, dst):
    """Write a copy placed on top of `target`, which must be a LOADED module.

    The fixture for the runtime test that Mod_Load REFUSES an image whose
    placement collides with something already loaded.  The copy stays a
    well-formed FGXM image, so the refusal is attributable to the placement
    check and not to a malformed header tripping something earlier.

    THE TARGET IS PASSED IN, AND IT USED TO BE HARDCODED $0000.  Offset 0 was
    where prodos sat, pinned and always loaded first -- so on a
    ProDOS root the overlap was guaranteed rather than size-dependent.  A UFS
    root does not load prodos at all (campaign phase 2), so $0000 collided
    with NOTHING and the fixture loaded cleanly: the test went red saying the
    refusal was missing, when what was missing was the module it was meant to
    land on.  Naming the target as a build input keeps the offset MEASURED
    from the image the boot actually loads instead of restated here.
    """
    with open(src, 'rb') as f:
        image = bytearray(f.read())
    if image[:4] != b'FGXM':
        sys.exit(f'gen_modplace: {src} is not an FGXM image')
    where = load_offset(target)
    if load_bank_ord(target) != load_bank_ord(src):
        sys.exit(f'gen_modplace: {target} is in bank ordinal '
                 f'{load_bank_ord(target)} and {src} in '
                 f'{load_bank_ord(src)} -- a different chain cannot overlap')
    if where == load_offset(src):
        sys.exit(f'gen_modplace: {src} is ALREADY at ${where:04X}; the '
                 'fixture would be a byte-for-byte copy and the test would '
                 'pass on the duplicate-load path instead of the header one')
    was = image[4] | image[5] << 8
    # ONLY the offset.  Byte 6 is the BANK ORDINAL and must be left alone: this
    # fixture exists to prove the PLACEMENT check refuses an overlapping image,
    # and zeroing the ordinal instead makes it $00-$05, an out-of-range chain
    # that Mod_Load refuses EARLIER -- so the test still went red, for the
    # wrong reason, and stopped covering what it names.
    image[4] = where & 0xFF
    image[5] = (where >> 8) & 0xFF
    with open(dst, 'wb') as f:
        f.write(image)
    print(f'gen_modplace: wrote {dst} (placement ${was:04X} -> ${where:04X}, '
          f'overlapping {os.path.basename(target)})')


def main():
    if sys.argv[1:2] == ['--verify']:
        return verify(sys.argv[2:])
    if sys.argv[1:2] == ['--collide']:
        if len(sys.argv) != 5:
            sys.exit(__doc__.strip().splitlines()[-1])
        return collide(sys.argv[2], sys.argv[3], sys.argv[4])
    if len(sys.argv) < 3:
        sys.exit(__doc__.strip().splitlines()[-1])
    module, outpath, earlier = sys.argv[1], sys.argv[2], sys.argv[3:]
    if module not in ORDER:
        sys.exit(f'gen_modplace: {module!r} is not in ORDER -- add it')

    # The cursor is the sum of the page-rounded footprints of everything placed
    # before this module IN ITS OWN BANK.  The build edge passes the images of
    # the modules built before this one, in placement order, whatever bank they
    # are in -- the edge cannot know the table -- and each is named by its path
    # (disk_src/lib/modules/<name>).  A module the build leaves out (ufsprobe,
    # with every probe gate off) is simply absent.  What a mis-wired edge must
    # not do is place two modules at one offset, so every predecessor in this
    # module's bank has to be there, and the order has to be ORDER's.
    names = [os.path.basename(p) for p in earlier]
    before = ORDER[:ORDER.index(module)]
    if names != [m for m in before if m in names]:
        sys.exit(f'gen_modplace: {module}: the earlier images {names} are not '
                 'in ORDER\'s order, or name a module placed after it.  The '
                 'build edge and ORDER disagree.')

    bank = bank_of(module)
    same = {m: p for m, p in zip(names, earlier) if bank_of(m) == bank}
    missing = [m for m in chain_for(module) if m not in same]
    if missing:
        sys.exit(f'gen_modplace: {module} sits after {missing} in its bank and '
                 'the build edge passed no image for them -- it would be '
                 'placed over them.')

    offset, rows = 0, []
    for name in chain_for(module):
        size = footprint(same[name])
        rows.append(f'*   {name:8s} ${offset:04X} + {size:5d}')
        offset += (size + GRANULE - 1) & ~(GRANULE - 1)

    limit = BANK_SIZE - offset
    if limit <= 0:
        sys.exit(f'gen_modplace: module bank {bank} is full at {module} '
                 f'(cursor ${offset:04X}). Give a module its own bank by '
                 'adding it to OWN_BANK above.')

    where = ('the shared module bank' if bank == 0
             else f'module bank {bank} (its own)')
    text = ('* AUTO-GENERATED by tools/gen_modplace.py -- DO NOT EDIT.\n'
            f'* Where {module}.mod sits in {where}, from the\n'
            '* MEASURED footprints of the modules placed before it THERE:\n'
            '*\n'
            + ('\n'.join(rows) + '\n' if rows else '*   (first -- at 0)\n')
            + '*\n'
            f'* MODP_LIMIT is the rest of the bank, so the guard in {module}.s\n'
            '* fires if this module would run off the end -- it cannot collide\n'
            '* with its neighbours, whose offsets are derived from its size.\n'
            '*\n'
            '* The BANK byte of MODP_ORG is the ORDINAL, not a real bank: $05 is\n'
            '* the shared bank, $06 the second, and so on.  It reaches the loader\n'
            "* as the FGXM header's load-address high byte, which is the one\n"
            '* place a module can say which bank it wants without knowing which\n'
            '* bank it will get.\n'
            f'MODP_ORG                EQU     ${BANK_BASE + (bank << 16) + offset:06X}\n'
            f'MODP_LIMIT              EQU     ${limit:04X}\n')

    # Write only on change: this file is an INPUT to the module's assembly, and
    # rewriting it unconditionally would relink the module (and everything
    # placed after it) on every build.
    try:
        if open(outpath).read() == text:
            print(f'gen_modplace: {outpath} unchanged '
                  f'({module} at ${offset:04X})')
            return
    except FileNotFoundError:
        pass
    with open(outpath, 'w') as f:
        f.write(text)
    print(f'gen_modplace: wrote {outpath} ({module} at ${offset:04X}, '
          f'${limit:04X} left in the bank)')


if __name__ == '__main__':
    main()
