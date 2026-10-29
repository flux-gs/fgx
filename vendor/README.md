# vendor/ — third-party source, committed

Upstream source FGX ports from, tracked in-tree rather than fetched.

## Why this is committed

Some of it is a build input (below), so it has to be present in every clone,
`git worktree`, CI run and `tools/cleanroom.sh` build.  `examples/`, where the
full upstream distributions live, is gitignored and local-only, so source read
from there makes the build depend on one machine.  Redistribution of this
source is unproblematic (see the licence notes below), so it is simply shipped.

## What is here

    2.11BSD/usr/{bin,usr.bin,ucb,sbin,old}   the userland port SOURCE
    2.11BSD/usr/{usr.sbin,libexec,usr.lib,lib,include,etc}
                                              more port source, headers and
                                              stock /etc files
    2.11BSD/usr/sys/{h,sys}                   the KERNEL port source + headers
    2.11BSD/usr/man                           upstream man pages (sources and
                                              cat pages) for ported tools
    2.11BSD/patches                           individual 2.11BSD patches ported from
    2.11BSD/README                            upstream's own README
    4.3BSD-Reno/{kern,sys,ufs}                the VFS port SOURCE
    FreeBSD-2.2.8/{sbin/adjkerntz,sys}        adjkerntz(8) and the kernel time
                                              files it pairs with
    netbsd-1-5/lib/libcurses                  keypad(3), ported into the 2.11BSD
                                              curses pile
    netbsd-0-9/usr.bin/elvis                  elvis (vi)
    netbsd-0-9/sys/isofs, sbin/mount_isofs    the ISO 9660 filesystem, ported to
                                              src/kernel/vfs/isofs_*
    4.4BSD-Lite2/sys/isofs/cd9660             cd9660, the same code grown: its
                                              node numbering, name handling and
                                              Rock Ridge support
    SunOS-4.1.3/bin/ldd.c                     ldd(1), ported to src/userland/ldd
    SunOS-4.1.3/usr.bin/eject.c, man1/eject.1 eject(1), ported to src/userland/eject
    frotz-2.44/                               Frotz, ported to src/userland/frotz
                                              (its README)
    65816-llvm-mos/                           the soft double runtime behind
                                              toolchain/lib/libdouble (its README)
    tzcode-2026d/, tzdata-2026d/              host zic and the zone files
                                              (tools/ninja/tz.sh)
    docvu2/                                   DOCVu 2.0, a desk accessory BINARY
                                              staged to /usr/fgx/cda (its README)

`2.11BSD/usr/bin/{sh,tcsh}` and `netbsd-0-9/usr.bin/elvis` are BUILD INPUTS —
`tools/sh-fgx2/`, `tools/tcsh-fgx2/` and `tools/elvis-fgx2/` compile them. The
rest is the port-source corpus the standing policy draws from: userland ports
take their source from the 2.11BSD tree, because it is a 16-bit-int PDP-11
codebase that matches fcc's `int == 16` exactly, and its K&R C is fcc's proven
path.

### Which vintage this is

The base `2.11BSD/` tree is a ~1999 snapshot, roughly patch level 429: its
base stamps end at `1999/11/26` (patch 429 is dated 1999-09-24, patch 430
1999-12-11).  Later material is added where a port needs it: individual
patches under `2.11BSD/patches/`, and `usr/usr.sbin/ntp`, whose `ntp.h`
carries a `2000/04/11` revision.

The live 2.11BSD machine used as the conformance oracle runs a NEWER system
(apple/fgx#277).  So the two answer different questions:

* `vendor/2.11BSD/` is the PORT SOURCE: what FGX's code derives from, what a
  `docs/PROVENANCE.md` row names, and what "read the counterpart in
  `vendor/`" means.
* The live machine is the CONFORMANCE ORACLE: what 2.11BSD *does*, and what
  judges FGX's on-disk bytes.  A claim of that kind should name the machine,
  not this tree.

Search the patch archive before concluding this tree is right:
`examples/2.11BSD-Patches/` (gitignored, local) holds 480 patches, newer than
this snapshot.

### Registering a port, and where the full distributions are

Every port gets a `docs/PROVENANCE.md` row naming its upstream file **in this
directory**; `tools/check_provenance.py` checks that each named `vendor/` path
resolves and scans `src/userland/` and `src/kernel/vfs/` for unregistered
ports.

The FULL upstream distributions, plus disk images and the llvm-mos oracle,
live under gitignored, local-only `examples/`.  What is vendored here is the
port-source subset.  If you need something from upstream that is not here,
take it from `examples/` **and add it here in the same commit**.

The history of this directory (when the kernel sources arrived, the cost of
porting without them, the oracle mount test) is in
`docs/history/audits/vendor-history.md`.

## Licence and attribution

2.11BSD and NetBSD-0.9 are BSD-licensed; the sources carry their original UCB
copyright and SCCS headers, which are preserved verbatim. Nothing here has been
relicensed.

FGX code *derived* from these sources carries an `FGX-Provenance:` header and a
row in `docs/PROVENANCE.md`; `tools/check_provenance.py` gates that on every
kernel build. This directory is the upstream side of that relationship — the
pristine originals, unmodified.

## Do not edit

Treat everything here as read-only upstream. FGX changes live in
`src/userland/<tool>/` or as an explicitly attributed derived file. Editing in
place would silently fork FGX from upstream with no record of the divergence.
