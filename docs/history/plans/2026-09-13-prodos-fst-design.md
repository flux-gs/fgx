# A ProDOS filesystem type: `mount -t prodos`, read and write

Scoped by the maintainer 2026-09-13.  This is the sanctioned return of ProDOS: the
2026-09-04 decision that removed the in-core ProDOS layer said FGX "will not
touch ProDOS again UNTIL AN FST IS CREATED for mount_prodos / `mount -t
prodos'", and the 2026-09-01 decision that set full-UFS as the goal ended with
"ProDOS survives only as a mountable FST for encountering an actual ProDOS
volume (campaign phase 3)".  This is that phase.

It is NOT a step back toward ProDOS as a root or boot filesystem.  The UFS
campaign's own goal 3 is "support external filesystem types (`mount -t
prodos`, `mount -t fat`), consistent with BSD", and its note that "goals 1 and
4 are not in tension: ProDOS stops being THE filesystem and becomes A loadable
type, required neither for boot nor for root" is the frame for everything
below.


## 1. Scope: read AND write

The maintainer, 2026-09-13: "isofs is a good starting point, but we need to write to
the prodos filesystem as well."

That one decision changes the design in exactly one structural place -- how a
file is identified -- and section 4 is about nothing else.  It is worth
reading before the rest, because the read-only answer is more elegant and is
wrong here.


## 2. Two upstream models, and why it takes both

**4.3BSD-Reno has no foreign filesystem.**  It ships `nfs` and `ufs` only, and
NFS is REMOTE rather than foreign -- it carries Unix semantics end to end.
Reno's `kern/vfs_conf.c` reserves `vfssw[]` slot 4 as `MOUNT_PC` and leaves it
null.  So Reno is the model for the SWITCH (section 5.2) and for nothing else
here.

**isofs is the skeleton.**  `examples/netbsd-0-9/sys/isofs`, 3,102 lines:

    isofs_rrip.c   675    Rock Ridge: Unix semantics over a format with none
    isofs_vfsops.c 580    mount / unmount / root / statfs
    isofs_vnops.c  574    the vnode operations
    isofs_lookup.c 412    name lookup
    isofs_node.c   318    the in-core node, and identity
    isofs_util.c   135    conversions
    headers        408

Rock Ridge deserves its own sentence: ~800 of those 3,102 lines exist to
synthesize owner, mode, real names and symlinks over a format that carries
none of them.  THAT IS THE ProDOS PROBLEM with a different on-disk format
underneath, and it is the best available reference for how much to synthesize
versus how much to refuse.

**pcfs is the write reference, and isofs cannot be.**  ISO-9660 is read-only,
so `isofs` answers NONE of the questions a writable foreign filesystem has:
block allocation, directory entry creation and removal, identity across
mutation, or sync.  `examples/netbsd-0-9/sys/pcfs` (5,406 lines) answers all
four, and `denode.h` states the shared problem in its own words:

> My extensions to make this house of cards work.  These apply only to the in
> memory copy of the directory entry.  - A reference count for each denode
> will be kept since dos doesn't keep such things.

**Both are ADVISORY.**  `vendor/netbsd-0-9/` is consulted for "behavior
questions, interface archaeology, a second reading of ambiguous code" and is
never the porting source.  These two are SHAPE.  The ProDOS code is ours,
because no BSD ever wrote one.

**prodosfs (github.com/nexvium/prodosfs) is a semantic cross-check, not a
source.**  C++ against a K&R C compiler, FUSE rather than a kernel VFS, MIT
against this tree's BSD-2-Clause provenance discipline, and read-only.  Where
it earns its keep is in what a modern implementer CHOSE: ProDOS file type and
auxtype surfaced as extended attributes, text-format translation, a synthetic
`.CATALOG`.  Vendor it marked consulted-not-ported if it is used at all.


## 3. What FGX already has

More than a green field:

- `struct vfsops` and the `VFS_MOUNT`/`UNMOUNT`/`ROOT`/`STATFS`/`SYNC` macros
  (`src/kernel/vfs/vfsops.h`), with `MOUNT_NONE` and `MOUNT_UFS` type numbers.
- `vfs_mountat` ALREADY takes a `type` parameter (`vfs_syscalls.c:939`).
- `mount(8)` is the vendored BSD one and ALREADY parses `-t`
  (`src/userland/mount/mount.c:112,137`), defaulting to `ufs`.
- **~8,500 lines of ProDOS implementation recoverable from git:**

      src/modules/prodos/prodos.s  5,797   at 2b4b06ad5^   FOP module, read+write
      src/drivers/fs/write.s       1,077   at 4c872b44c^   the write path
      src/drivers/fs/bitmap.s        646   at 756402f87^   volume bitmap allocator
      src/drivers/fs/inode.s         490   at 756402f87^   directory entries
      src/drivers/fs/path.s          459   at 756402f87^   path resolution

  This is the part no upstream can supply: ProDOS's on-disk format, its
  seedling/sapling/tree storage types, and a write path that took several
  rounds of real bug fixes to get right.  WHAT DOES NOT CARRY OVER IS THE
  INTERFACE -- all of it implements the old `_fop_*` FOP vtable, so this is a
  re-expression behind vnodeops rather than a rewrite of a filesystem.
- `cadius` is installed and already used by the build
  (`tools/ninja/gen.py:1023`), which gives the write path an INDEPENDENT
  oracle from day one.  See section 7.


## 4. Identity, which is the decision write forces

**isofs's answer is elegant and wrong here.**  ISO-9660 has no inodes, so
isofs uses the file's EXTENT -- its starting block -- as the inode number:

    ip->iso_extent = isonum_733 (isodir->extent);
    ip->i_number   = ino;                    /* ino == the extent */

ProDOS's KEY BLOCK is the exact analogue, and for a read-only mount it would
be the right answer: unique, stable, and independent of the directory, so it
survives rename for free.

**It does not survive growth, and FGX's own retired code says so.**  From
`_pfw_promoteSeedToSap`:

    Pre:  Storage=$10, KeyBlk = old seed
    Post: Storage=$20, KeyBlk = new index block

and `_pfw_promoteSapToTree` moves it again -- the old sapling index becomes
sub-index 0 and a freshly allocated master index becomes the key.  So a file's
key block changes TWICE over its life, and both changes happen on the write
path.  A key-block inode number would be stable exactly until someone wrote to
the file.

**So the key is the directory entry's location: (directory block, entry
index).**  That is pcfs's `(dirclust, diroffset)`, chosen for pcfs's reason.
It is stable across both promotions, because the entry does not move when the
file's storage type changes -- only the `key_pointer` field inside it is
rewritten.

Two consequences to carry:

- **Rename in place preserves identity.**  ProDOS rewrites the entry where it
  sits, so the key is unchanged.  A move BETWEEN directories does not, and
  needs pcfs's fixup: the in-core node's key is updated when the entry moves.
- **This is a thing not to "simplify" later.**  Keying the in-core node on
  the key block will look like an obvious cleanup to someone reading section
  2's isofs reference without section 4.  It is the read-only answer, and this
  filesystem writes.  (The inode NUMBER is the key block, for a 16-bit reason
  given below; that is a separate choice from the key.)

**Refined in P2 (decided 2026-09-13): a DIRECTORY is keyed on its own key
block.**  pcfs's `deget` converts a directory to canonical form -- its own
start cluster, offset 0 -- because more than one thing leads to a directory.
ProDOS has the same shape: a subdirectory is reached from its entry in the
parent AND from every child's `header_pointer`, which names the parent's key
block.  So a file is (directory block, entry index 0-12); a directory is (its
key block, 0), which is its header slot and itself an entry location; the
volume root is (2, 0).  A directory's key block never moves (a directory grows
by linking blocks), `..` needs no read, and moving a directory between parents
needs no re-hash.  The two forms cannot collide: a directory's key block is
never another directory's continuation block.  The retired code confirms the
original concern directly -- it keyed on (dev, key block) and its own comment
records that a promotion "RE-KEYS the inode in the same stroke"
(`756402f87^:src/drivers/fs/inode.s:292-296`).

**The inode number is not the key (apple/fgx#434).**  The key is 20 bits of
entry location and `ino_t`, `st_ino` and `d_ino` are 16, so no projection of
it is unique: `(block << 4) | index` aliased past block 4096, and truncated
to 0 -- which every readdir consumer skips -- at 4096's multiples.  `st_ino`
is therefore isofs's number after all: the KEY BLOCK, a directory's own and a
file's `key_pointer`, 2 for the root.  A block number is 16 bits on ProDOS, a
key block belongs to one file, and ProDOS 8's create allocates one for every
entry (`MliSrc.aii` `cralcblk`), so it is unique and never 0; readdir takes it
from the entry with no read.  What it gives up is the stability this section
argues for, and only for FILES: promotion (`swapdown`) and a shrinking
set_eof (`detree`) move the key block, so once P5 writes, a file's `st_ino`
changes when it grows past 512 bytes or 128 KB.  The node key does not change,
so the in-core identity write depends on is unaffected.  The stable 16-bit
alternative is the block holding logical block 0, which promotion keeps; it
costs an index-block read per sapling or tree in readdir and stat, and a hole
at block 0 (cadius writes zero blocks as holes) would need a fallback.


## 5. The plumbing gaps

**5.1 `mount(2)` has no type argument.**  `SYS_MOUNT` is 2.11BSD's
`smount(spec, dir, flags)`, and `src/kernel/syscall.s:5989` hardcodes
`PEA $0001 ; type = MOUNT_UFS`.  The comment there says why: "2.11BSD's smount
has no type argument because a 2.11BSD kernel has one filesystem, and so does
this one".  Reno's is `mount(type, dir, flags, data)`.

This is a which-BSD-wins decision and Reno wins it, because the whole point is
a second type.  It changes the syscall ABI, so it wants its own increment and
its own rebuild of everything that calls mount(2).

**5.2 The type is validated, not dispatched.**  `vfs_syscalls.c:929-936`:

> THE TYPE IS VALIDATED AND NOT DISPATCHED ON ... Reno does `mp->mnt_op =
> vfssw[type]' and then calls VFS_MOUNT through it; `&ufs_vfsops' is an
> address inside ufs.mod and this bank calling through it is apple/fgx#178 ...
> a second one adds an arm here rather than a row in a table nobody can
> dispatch through.

**CORRECTED DURING P1: the comment was right and this section was wrong.**
This section originally said the reason had expired because apple/fgx#178 is
closed.  #178's fix was the `--module-bank` arm ONLY; `--kernel-bank`, which
the far bank compiles with, still took an indirect call's bank from PHK, so the
far bank still could not call through `&ufs_vfsops`.  Reading `emit.c` rather
than the issue's state is what showed it.

Two ways through were measured.  A `vfs_mount1` in vfs.mod doing the dispatch
added ~29 bytes to mount(2)'s kernel stack, which on main was already the
deepest chain at 488 of 512: it measured 510, and in `mount(8)`'s vfork child
it overran into the sleeping parent's slice and wedged the machine.  So P1
fixed fcc instead: `--kernel-bank` indirect calls read the pointer's bank and
carry #178's DBR bracket, and `Far_BankInit`/`Tty_BankInit` stamp every
`KFAR_FN_PTR` cell with their bank as `_Mod_StampFnPtrs` does for modules.
`vfs_mountat` then runs Reno's two lines itself, reading the row through
`vfs_getvfsops` (the table is vfs.mod's because its writers are modules), and
mount(2) peaks at 472 of 512.

**5.3 The node layer.**  Section 4's key, a hash, a reference count ProDOS
does not keep, and the `iget`/`iput` equivalents.  `isofs_node.c` (318 lines)
is the shape; pcfs's `denode.c` (619) is the shape once mutation is in scope.

**5.4 Semantics.**  Section 6.


## 6. Semantics that need a decision, not a translation

Each of these is a place where ProDOS and Unix disagree and somebody has to
choose.  Writing makes several of them live that a read-only mount could have
ducked.

- **Names.**  15 characters, uppercase, `A-Z 0-9 .` and a letter first.  A
  Unix name that does not fit MUST BE REFUSED AT CREATE, not silently
  mangled: a filesystem that quietly renames what you asked it to write is
  worse than one that says EINVAL.  Read-side conversion is a separate and
  safer choice.  SETTLED (the maintainer, 2026-09-14): readdir shows the display case
  GS/OS records (GS/OS Technical Note #8, the word at +$1C), lowercase where
  none is recorded; lookup folds, as GS/OS's does.  P5's create writes the
  case word for the name it was given.
- **Ownership and mode.**  ProDOS has none.  CORRECTED IN P4: this said pcfs
  takes `-u`, `-g` and a mask as mount options.  netbsd-0-9's does not --
  `mount_msdos` takes only `-F`, and `pcfs_getattr` reports uid 0, gid 0 --
  and isofs without Rock Ridge reports the same (`isofs_rrip.c:67-69`).  The
  options are later BSDs'.  SETTLED (the maintainer, 2026-09-14): every node is uid 0
  and gid 0, with no mount options.
- **The access byte.**  ProDOS has destroy / rename / backup / write / read
  enable bits.  The mapping to rwx is a decision to state in the man page, not
  a natural correspondence.  SETTLED (the maintainer, 2026-09-14), and in
  mount_prodos(8): read ($01) is r for all, write ($02) is w for the owner, a
  directory is x wherever it is r, and a file is never x.  Destroy ($80) and
  rename ($40) are enforced by P5/P6's unlink and rename with EPERM when
  clear; pd_access checks the mode as ufs_access does.
- **Hard links.**  None.  `link()` answers EOPNOTSUPP and `st_nlink` is
  synthesized (1 for files, 2 for directories).
- **Dates.**  ProDOS date/time words against `time_t`.  One direction already
  exists -- `c_stat` synthesizes `st_mtime` from the raw ProDOS words -- and
  write needs the other.
- **`.` and `..`.**  ProDOS directories have a header entry, not `.` and `..`
  entries.  Lookup synthesizes both; readdir must too, or every Unix program
  that walks a tree breaks.
- **Storage type on create.**  A new file is a seedling; growth promotes it.
  That is the retired write path's own behaviour and it should stay.
- **The backup bit.**  ProDOS sets it on modification for the benefit of
  backup utilities.  Whether FGX honours it is a decision; doing nothing is
  also a decision and should be written down.  SETTLED (the maintainer, 2026-09-14):
  P5 sets $20 on every change it makes, as the MLI does.


## 7. Safety, because this writes to somebody's real disk

A bug in the UFS write path corrupts a volume this project generated.  A bug
in THIS write path corrupts an Apple II disk image somebody may have had since
1988.  The risk is not symmetrical and the plan should not pretend it is.

- **Read-only is the default mount.**  Write behind an explicit option until
  the fixtures have run against it for a while.  `MNT_RDONLY` already exists.
- **`cadius` is the independent oracle.**  It is installed, the build already
  uses it, and it is an implementation nobody here wrote -- which is exactly
  the property that made `fgxfs fsck` worth having for UFS and exactly the
  lesson of "when an independent reader says the artifact is fine, suspect the
  reader" in reverse.  Every write fixture should end by handing the volume to
  cadius and asserting it reads back what FGX thinks it wrote.
- **Fixtures write to a SCRATCH volume**, created by `cadius CREATEVOLUME` in
  the build, never to a vendored or user image.


## 8. Increments

**P1.  `mount(2)` grows a type, and `vfssw[]` dispatches.**  apple/fgx#428.  Sections 5.1 and
5.2.  Lands with UFS still the only type, so it is provable by `mount -t ufs`
continuing to work and a type with no row answering ENODEV from the TABLE
rather than from a compare.  The discriminating mutation is a SECONDARY mount
(`tests/ufsmount`, `tests/mountupd`), not boot: the root mount calls
`ufs_mountfs` directly, as Reno's `ufs_mountroot` does, and never reads the
table.  `mount -t <type>` cannot test the kernel either -- 2.11BSD's
`mount(8)` execs `mount_<type>` for anything but ufs, so it answers ENOENT
before a syscall is made.

**P2.  The node layer.**  apple/fgx#429.  Section 4's key, hash and refcount, against a
mounted-but-inert filesystem.  As landed: `prodos.mod` in the shared module
bank, loaded from `/etc/rc`; `MOUNT_PRODOS` is 10, past every BSD's MOUNT_
range (Reno 0-4, netbsd-0-9 0-9), with BSD names in `INITMOUNTNAMES` for the
gap; a read-only mount only, refusing a writable one with EROFS as
`isofs_mount` does.  `access` and `getattr` came forward from P3, because
chdir(2) stats its target and asks VEXEC before it reaches the VFS, and nothing
can stand in a mount without both.  A ProDOS block is half of the buffer
cache's 1024-byte buffer (block n is buffer n>>1, offset (n&1)*512), so the
cache needs no change.  Found on the way: `vfs_unmountdev` matched mounts by
reading UFS's private data, fixed to match `mnt_stat.f_fsid`.  Test:
`tests/pdmount`, whose PDIDENT case is the one that proves identity -- a
fileid read from the volume would print the same for a hash that built a new
node per walk.

**P3.  Read-only vnodeops.**  apple/fgx#430.  lookup, getattr, read, readdir, and the `.`/`..`
synthesis.  First increment where `mount -t prodos` does something, and the
point at which a real ProDOS image can be read.  As landed: `prodos_vnops.c`,
and `mount_prodos(8)` in mount_ufs's shape, exec'd by the unchanged mount(8).
- **`..` reads parent_pointer as ProDOS 8 writes it**: the block holding the
  directory's entry, with the entry's slot there counted from 1.  The MLI's
  create copies `d_entblk`/`d_entnum` into the header rather than `d_head`
  (`MliSrc.aii` `cmvparnt`), GS/OS's FST rejects anything else (`ProDOS.FST`
  `verify_dir`), and cadius agrees.  "Beneath Apple ProDOS" p. 4-30 describes
  it as the parent's key block, which coincides while the entry is in that
  key block.  So `..` reads the named block: a zero previous-block link means
  it is the parent's key block, otherwise the entry's header_pointer names it
  -- which reads a book-style pointer too.  The test volume places one
  directory under each arm and its generator asserts the placement.
- **readdir renders**: Unix directory block k is ProDOS chain block k as
  DIRBLKSIZ bytes of `struct direct`, `.` and `..` leading block 0, so
  ufs_readdir's offset rules hold unchanged.  A directory's size is its chain.
- **Names**: the retired resolver's rule -- fold to uppercase, A-Z 0-9 `.`
  with a letter first, at most 15, EINVAL otherwise -- and readdir lowercases.
  Its `.x` -> `DOT.X` mapping is dropped (the maintainer): it served ProDOS as FGX's
  root, which a mounted foreign volume is not.
- **read**: seedling/sapling/tree by storage type; a zero index entry is a hole;
  a Pascal area answers ENOTSUP.  A GS/OS extended file is `NAME` (its data
  fork) and `._NAME` (AppleDouble: Finder info and resource fork), section 9;
  `._NAME` is numbered by its resource fork's key block, and each ProDOS
  directory block renders as two Unix directory blocks so that thirteen
  entries and their sidecars fit.
- **Found on the way**: `st_ino` and `d_ino` are 16 bits, so the key aliased
  above block 4096 and one that truncated to 0 vanished from listings --
  apple/fgx#434, fixed by numbering nodes by key block (section 4).  The test
  volume grew to 4800 blocks so that INNER's key block is 4096.
- **Test**: `tests/pdmount` gains a populated volume (`tools/mkpdscratch.py`)
  and the shell half: mount(8), ls, `pwd` from two directories down (which
  proves `..`, readdir numbering and getattr agree), and sums of a seedling, a
  sapling with holes and a tree.  Four mutations each went red on the
  assertion predicted.

**P4.  The name and metadata layer.**  apple/fgx#431.  Section 6's conversions and refusals.
As landed: the four decisions in section 6 (names, ownership, the access
byte, the backup bit), with no mount options -- netbsd-0-9 has none to follow.
- **Case**: `pd_direct` lowercases a character unless the entry's case word
  is valid and marks it uppercase.
- **Mode**: `pd_mode` maps the access byte, and `pd_access` checks it against
  the caller's ids as `ufs_access` does, so vn_open's VREAD check refuses a
  non-root read of a file whose read bit is clear.
- **mount_prodos(8)** gets a page stating all of it, the dates and the forks.
- **Test**: the generator writes case words (Hello, TREE) and access bytes
  (SAP $01, F02 $00).  `pdmount -s` prints each mode, and `pdmount -U`
  repeats reads as uid 1.  Ignoring the case word and skipping the mode check
  each went red.
- Dates came forward into P3 (`pd_stamp`); only their write direction is left,
  to P5.

**P5.  Write: allocation and mutation.**  apple/fgx#432.  The volume bitmap, entry creation
and removal, seedling promotion.  This is where `bitmap.s` and `write.s` come
back, re-expressed.  DECIDED (the maintainer, 2026-09-14): writable only under
`mount_prodos -o write` until P6 and the fixtures settle; C in prodos.mod with
ProDOS 8's MliSrc.aii as the on-disk authority; three MRs; forked files write
their data fork only, `._NAME` never.
- **P5a, as landed**: the writable mount, the allocator, and write(2) to
  files that exist (`prodos_write.c`).
  - `pd_balloc` is alc1blk: the leftmost set bit of the first map byte with
    one, zeroed on allocation.
  - `pd_bmapw` promotes as swapdown does; the key block moves and the entry
    does not.
  - `pd_revise` writes storage type, key, blocks used, EOF, date and the
    backup bit, as drevise does.  An extended file's data fork does the same
    on its mini-entry.
  - `pd_ripple` re-dates every directory up to the volume at close, which is
    drevise's ripple.
  - Every write is synchronous and ordered bitmap, then index, then entry, so
    a crash leaks a block but never shares one.
  - On a writable mount, lookup refuses a delete or rename with ENOTSUP until
    P5c, and a create misses with ENOENT until P5b.
  - Test `tests/pdwrite` covers promotion to sapling and to tree, holes, an
    overwrite, a data fork, O_APPEND, a subdirectory's ripple, EPERM, EACCES,
    EISDIR, EROFS, and ENOSPC.  Its checker requires cadius CHECKVOLUME silent
    (after a control), cadius's extraction byte-identical to the writes
    replayed, and each entry's storage type, blocks used, backup bit and date.
    Leaving the bitmap unwritten, dropping the old key at promotion and
    removing the ripple each went red.
  - Ad hoc, on a copy of a 32 MB GS/OS volume: appends to a forked file's
    data fork and to a 1 MB tree, and an extend of a sapling, all read back
    exactly by cadius, with CHECKVOLUME silent.
- **P5b, as landed**: create and mkdir, one `pd_create` in both slots,
  choosing by va_type.
  - lookup's create miss is ufs_lookup's: a removed directory takes no name,
    VWRITE of the directory is asked, and ENOENT returns with the directory
    unlocked unless LOCKPARENT.  A create of `._NAME` is EPERM.
  - `pd_slot` finds the first entry whose first byte is zero across the whole
    chain.  looknam stops at file_count and offers the next block's slot 1,
    which is the same slot on any volume whose count is right.  A full
    subdirectory grows as xtndir grows it, with the new block written before
    anything links it; the volume directory's dirfull is ENOSPC.
  - The entry is creat1's: a zeroed key block, blocks used 1, EOF 0 (512 for
    a directory), creation and modification now, header_pointer, file type $00
    (the FST's default) or $0F.  Three fields are decided here rather than
    taken from a caller: access $C0|backup plus read and write from the
    owner's mode bits ($E3 for 0644), a case word always valid (the FST
    leaves an all-uppercase name without one), and version 0.
  - A directory's header is cmvheadr's, cmvpass's reserved bytes
    ($75 00 00 C3 27 0D 00 00), access $C3, and cmvparnt's parent_pointer and
    parent_entry from 1.  credone's file_count, then the ripple.
  - prodos.mod reached 52,327 bytes against its 47,872-byte slot in the shared
    bank, so it moved to bank ordinal 5 of its own and MOD_BANK_MAX became 6
    (the maintainer, 2026-09-14).
  - fcc rejected `&(*bpp)->b_addr[off]`; its `&(*p)` arm took only a
    subscript, and now takes the member chain its cast arm already reads.
  - Test `tests/pdwrite` grows: a mixed-case create, EINVAL, EEXIST, EPERM for
    `._ext`, EACCES for uid 1, mkdir and EEXIST, a new seedling promoted, 20
    files in the new directory (which grows a block), `pwd` out of it, and
    creates until the volume directory's 51 entries are full.  The checker
    adds every directory's file_count, parent pointers, previous links and
    entry size against its chain, and each new entry's fields.  Those
    invariants hold on the generator's volume and on a GS/OS-written 32 MB
    volume.  Three mutations each went red: file_count not incremented
    (the checker's count), parent_entry one low (the ripple out of the new
    directory reads EIO, so its creates fail), and an extension not recorded
    in the parent entry (cadius: the new block is used and unreferenced).
- **P5c, as landed**: unlink and rmdir, one `pd_remove` in both slots.
  - pcfs's shape: the name goes now and the blocks at the last reference.
    pd_remove zeroes the entry's first byte (destroy's zap_entry, which the
    FST's destroy matches), takes one from the directory's file_count and
    ripples, and drops pd_refcnt on the node and its twin.  pd_inactive frees
    (pcfs_inactive's detrunc), unless the twin is still in use.  A file
    unlinked while open keeps working; its writes update only the in-core
    entry, because its slot may already be a new file's.
  - Freeing is destroy's and the FST's kill_*: every data block to the
    bitmap, each index block (sapling key, tree master, sub-index) written
    back with every entry's bytes swapped and then freed, a GS/OS extended
    file's two forks then its extended key block (FST only; ProDOS 8's
    destroy refuses the type), and a directory's header byte zeroed and its
    chain freed.
  - Refused: destroy bit clear (EPERM), a directory with files (ENOTEMPTY),
    `._NAME` (EPERM: the fork goes only with its file), `rmdir .` (EINVAL).
    lookup asks VWRITE of the directory on a delete hit, ufs_lookup's :396.
  - The order diverges from destroy, which frees blocks and then zaps the
    entry: here the entry goes first, so an interruption leaks blocks rather
    than leaving an entry that names freed ones.
  - Test `tests/pdremove` on a fresh volume: EPERM for `._ext`, SAP and F02;
    ENOENT; EACCES for uid 1; a seedling, a tree, an extended file; ENOTEMPTY,
    ENOTDIR, EPERM for unlink of a directory, then rmdir of the emptied one;
    a file unlinked while open written and read back; and a new file.  Its
    checker requires cadius CHECKVOLUME silent, the removed entries gone and
    every directory whole, every surviving file byte-identical, the new file
    entirely in freed blocks, and each unreused removed index block flipped.
  - prodos.mod is 57,920 bytes of its 65,536-byte bank.

**P6.  Write: the rest.**  apple/fgx#433.  rename (with section 4's cross-directory fixup),
truncate, sync, and the backup bit decision.
- **P6, as landed**: rename(2), and truncate(2), ftruncate(2) and O_TRUNC.
  - THE SPLIT.  prodos.mod reached past its 65,536-byte bank with rename and
    truncate in it, so the write half moved to prodosw.mod in bank ordinal 6
    of its own, and MOD_BANK_MAX became 7 (the maintainer, 2026-09-14).  prodos.mod
    exports VT_PDCORE (pdget, pd_fork, pd_entsync, pd_twin, pd_rekey, pd_bmap,
    pd_unlock, pd_setwriteops); prodosw.mod imports it and vfs.mod's buffer
    calls.  At load prodosw_init hands over `struct pdwops` and an empty
    vnodeops of its own, which pd_setwriteops fills from prodos.mod's vector
    and the write half's entry points; pdget gives that vector to every node
    from then on.  prodos.mod's own vector is never written, so modimage
    still compares its image exactly -- the first version patched it in
    place, and modimage caught the write.  Without prodosw.mod a writable
    mount is EROFS and mount_prodos retries read-only.  prodos.mod is 37,284
    bytes and prodosw.mod 36,207.
  - Rename within a directory is ProDOS 8's rename (rname9, and mvrotnam for
    a directory's header); between directories it is the ProDOS FST's
    change_path (move_file, fix_subdir).  The entry keeps its key block,
    dates and access, takes the new name's case word and the backup bit, and
    a file's node is refiled under its new slot (pd_rekey), or a create in
    the old slot would find the moved file's node.  The old entry goes
    first, so an interruption leaks rather than names blocks twice.
  - Refused: a clear rename bit, EPERM, unless only the directory changes
    (change_path's narrowing of the MLI's accserr); a directory moved beneath
    itself, EINVAL, by walking header_pointers up from the target as
    ufs_rename's checkpath walks `..`; `._NAME` either side, EPERM.  A target
    that exists is removed first, which neither ProDOS does and rename(2)
    requires, so its destroy bit and emptiness decide.  lookup asks VWRITE of
    the directory on a RENAME hit and returns EISDIR for `.`, Reno's
    ufs_lookup :101 and :440 -- and ufs_lookup lacked the hit's VWRITE, fixed
    on the same branch.
  - Truncate is set_eof's detree: every data block past the end freed, each
    index entry cleared before its block goes (not flipped: swapme without
    delflag), the last block's tail zeroed, and a tree that fits one index
    demoted to a sapling and a sapling that fits one block to a seedling, the
    dropped index block freed after the entry stops naming it.  Longer
    allocates nothing.  chmod, chown and utimes stay ENOTSUP.
  - sync has nothing to flush: every write is a synchronous bwrite.
  - Test `tests/pdrename` on a fresh volume: renames in a directory, across
    directories, of a directory twice (the second across), onto an existing
    name; EPERM for a clear rename bit and for `._ext`; EINVAL for a
    directory beneath itself; a tree, a sapling and an extended file's data
    fork truncated, a seedling extended to 70,000 bytes with no block
    allocated, and O_TRUNC.  Its checker requires cadius CHECKVOLUME silent, every directory
    whole with no name twice, each moved entry at its new name with its old
    key block, case word and backup bit, the truncated shapes' storage type,
    EOF and blocks used, and every file byte-identical.

P1 is useful on its own even if nothing follows it -- it is the thing that
makes ANY second filesystem type possible, and it corrects a comment that is
currently wrong.


## 9. Open questions

- ~~Whether `mount_prodos(8)` is a separate binary or an arm inside
  `mount(8)`.~~  SETTLED BY UPSTREAM: the vendored 2.11BSD `mount(8)` already
  calls `mount_ufs()` in-process for ufs and execs `<dir>/mount_<type>` for
  every other type (`mount.c:298-305`), so `mount_prodos(8)` is a separate
  binary and `mount(8)` does not change.
- Whether the recovered code is re-expressed incrementally behind vnodeops or
  read as a reference and rewritten.  The retired module is 5,797 lines of
  working format knowledge, but it is also written against a vtable that no
  longer exists; a straight port may cost more than it saves.
- ~~GS/OS extended (forked) files: a data fork and a resource fork under one
  name.~~  SETTLED (the maintainer, 2026-09-14) by what macOS and netatalk already do
  on a filesystem with no extended attributes: `NAME` is the data fork, and a
  synthesized `._NAME` is an AppleDouble v2 file (RFC 1740) holding exactly
  Finder Info (entry 9) then the Resource Fork (entry 2) -- xnu's layout
  (`bsd/vfs/vfs_xattr.c`, "._" AppleDouble Header File), which netatalk's
  `ea = sys` also writes and macOS's copyfile insists on.  Finder info is the
  volume's own when the extended key block carries it (ProDOS Technical Note
  #25), otherwise what GS/OS's HFS FST makes of the ProDOS type
  (`hfs.fst.main`: creator `pdos`, its conversion table, else `p` + type +
  aux type).  No ProDOS name starts with `.`, so `._NAME` cannot collide, and
  tar and cp carry the pair as two files.  Rejected: NAPS `#ttaaaa` suffixes
  (they rename the file), AppleSingle (the data fork stops being readable as
  itself), netatalk 2's `.AppleDouble/` directory (a synthesized directory per
  directory), `..namedfork/rsrc` alone (a vfs_lookup change, and invisible to
  tar), and a sidecar for every file to carry its type (doubles every listing
  and pushes large directories past libc opendir's 2,048-byte snapshot).
  Plain files' types stay P4's.
