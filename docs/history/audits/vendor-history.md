# vendor/ -- history

Moved from `vendor/README.md`, which now describes only what is vendored and
why.  The text below is the record as it stood, including statements that
were true when written (for example the vintage note's newest stamp, which
predates the vendored ntp sources).

## WHICH VINTAGE THIS IS, AND WHY IT IS NOT THE ORACLE'S

**`2.11BSD/` is a ~1999 snapshot: its newest source stamp is `1999/11/26`,
which puts it at roughly patch level 429** (patch 429 is dated 1999-09-24,
patch 430 is 1999-12-11).  **The live 2.11BSD machine the campaign uses as its
conformance oracle is NEWER**, and the difference is observable rather than
theoretical -- apple/fgx#277:

* the machine's `fsck -y` prints `Marking file system clean` and writes
  `fs_flags` `0x0000 -> 0x6000`.  Neither the message nor the behaviour exists
  anywhere in this tree: `grep -rn "Marking file system clean" vendor/` finds
  nothing, `usr/sbin/fsck/*.c` never mentions `clean`, and `fs_flags` is never
  referenced by the tool.  `h/mount.h` here names `0x0001`-`0x0080` plus
  `MNT_UPDATE 0x1000` under a `MNT_VISFLAGMASK` of `0x0fff`, so `0x6000` is
  outside what these headers can describe;
* two patches this tree predates have already been found in ported code by
  reading the patch archive against it -- **patch 433** (`ufs_ialloc` rescans
  without discarding what it found, apple/fgx#278, fixed here in `67ff5cb95`)
  is the one that reached the shipping kernel.

**SO THE TWO ARE FOR DIFFERENT THINGS, and saying which is the point of this
section.**  `vendor/2.11BSD/` is the PORT SOURCE: what FGX's code is derived
from, what a `docs/PROVENANCE.md` row names, and what the standing rule means
by "read the counterpart in `vendor/`".  The live machine is the CONFORMANCE
ORACLE: what judges FGX's bytes.  A claim about what 2.11BSD *does* belongs to
the machine and should name it; a claim about what FGX's code *derives from*
belongs here.  Citing this tree for the first kind is what #277 exists to stop.

**AND SEARCH THE PATCH ARCHIVE BEFORE CONCLUDING THIS TREE IS RIGHT.**
`examples/2.11BSD-Patches/` (gitignored) holds 480 of them and is four patches
ahead of this snapshot at minimum.  It has produced two findings already: #278
above, and `df -h`, which was declared an FGX extension after checking five
vendored trees and turns out to be patch 466.

**ONE THING IS NO LONGER UNTESTED.**  #277 worried that "a clean-flag feature
means the live kernel may EXPECT `fs_flags` to carry something FGX does not
write.  FGX writes zero there.  Nothing has complained, and this volume mounted
nowhere, so that is untested rather than fine."  It is tested now: on
2026-09-06 the live machine MOUNTED an FGX-written volume (`mount /dev/ra3a
/mnt`) and read all sixteen entries of its root, with `fs_flags` zero.  A
newer kernel accepts a volume this tree's format produces.

## The kernel sources are here too, and they were not, and that cost real work

`2.11BSD/usr/sys/` and `4.3BSD-Reno/` arrived on 2026-08-12 for the same reason
the userland source did, one campaign later. The UFS campaign ports its VFS
from **4.3BSD-Reno** (`vfs_lookup.c`, `vfs_cache.c`, `vfs_subr.c`,
`spec_vnops.c`, `dead_vnops.c`, and `vfs_vnops.c`/`vfs_syscalls.c`/`ufs/` still
to come) and takes its architecture from 2.11BSD's `h/file.h`, `h/user.h` and
`sys/`. Those files lived ONLY under gitignored `examples/`, and this README
used to describe that directory as *"disk images, reference trees, the llvm-mos
oracle -- not a build input and not needed to build or test FGX."*

That sentence was true of most of `examples/` and badly wrong about the part
that mattered, and the cost was not hypothetical: **two VFS slices were written
from memory while the real source sat unread in the tree.** The 1.4a pass
diverged from Reno in four ways -- a dropped vnodeops argument, the wrong reuse
condition, the wrong return value, a misspelled routine -- and **not one of them
would have failed a test.** The 1.6b pass repeated it. Both times the author
checked `vendor/`, found no kernel source, and concluded there was none.

`docs/PROVENANCE.md` now registers every VFS port with a row naming its file
**in this directory**, and `tools/check_provenance.py` covers `src/kernel/vfs/`
as well as `src/userland/`. You cannot land a port without filling in that
column, and you cannot fill it in without opening the file.

`examples/` still exists locally and stays gitignored -- it holds the FULL
upstream distributions (144 MB of Reno, 183 MB of 2.11BSD) plus disk images and
the llvm-mos oracle. What is vendored here is the port-source SUBSET: 2.7 MB,
against 18 MB of userland already tracked. If you need something from upstream
that is not here, take it from `examples/` **and add it here in the same
commit**.

