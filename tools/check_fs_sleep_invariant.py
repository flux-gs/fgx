#!/usr/bin/env python3
"""check_fs_sleep_invariant.py -- UFS deliverable 1.0b.

The FS and block layers hold their working state in SHARED SINGLETONS: one
directory buffer, one path-resolver work area, one bitmap-residency pair, and
several transient direct-page cells.  That is safe today for exactly one
reason -- nothing in those layers ever sleeps or yields, so a syscall that
picks up a singleton always runs to completion before another task can touch
it.  The safety is an emergent property of the call graph, not an enforced
one, and nothing in the tree says so out loud.

UFS deliverable 1.3 ports Reno's vfs_bio.c, which introduces SLEEPING BUFFER
LOCKS.  The moment Blk_* can block, every singleton that is live across a
Blk_* call becomes a cross-process corruption: task A fills the shared
directory buffer, sleeps inside the buffer cache, task B refills it, and A
resumes reading B's block.  That is the exact shape of apple/fgx#41 (a shared
DP cell held across a sleep).

So this checker does two things:

  1. INVARIANT.  Assert that no file in the FS/block layer contains a sleep or
     yield.  This is the property the singletons currently rely on.

     WHAT IT DOES NOT DO, stated plainly because the earlier wording here
     claimed otherwise: it does not "go red the moment 1.3 adds a sleep".  It
     scans the eight files in FS_LAYER and nothing else.  Reno's vfs_bio lands
     in a NEW file, in C, in a module bank; a sleeping buffer lock there is
     invisible to this check, and so is any sleep reached by calling out of
     these eight files into a helper that lives elsewhere.  What this enforces
     is narrower and permanent: THE LEGACY LAYER STAYS SLEEP-FREE.  If 1.3
     makes Blk_* itself able to block, adding that file to FS_LAYER is how you
     get the red -- it is not automatic.

     Keeping the legacy layer sleep-free is worth enforcing on its own terms.
     If the new stack confines its sleeps ABOVE Blk_* -- which costs nothing
     on a machine whose disk I/O is synchronous PIO -- then this invariant
     holds forever and the exposure list below never has to be converted.

  2. EXPOSURE.  Report which singletons are live across a Blk_* call, i.e.
     which ones the 1.3 work has to convert to per-process state or protect
     with a lock held across the sleep.  This is reported, not enforced --
     the count is expected to be large today and to shrink as 1.3 proceeds.

The exposure question is deliberately "who USES this across a Blk_* call",
not "who writes it".  A survey organised around writers cannot express "whose
bytes is another task running on right now", which is the question that
matters; that framing error already cost this project once, on the bank-0
stack-swap campaign.

Exit 0 = invariant holds.  Exit 1 = a sleep appeared in the FS/block layer
without this checker being updated to match the new locking design.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The layers whose safety rests on never sleeping.  MANUAL BY DESIGN, per the
# header -- and that cuts both ways.  Adding a file here is how a newly
# blocking layer gets caught; REMOVING one when it leaves the tree is not
# optional, because a name that no longer resolves stops this check dead before
# it has read a single line.  self_test() enforces that second half so the list
# cannot rot silently.
FS_LAYER = [
    "src/drivers/fs/fs.s",
    "src/drivers/fs/fcb.s",
    "src/drivers/block/block.s",
    "src/drivers/block/blkcache.s",
    # apple/fgx#330.  The raw disk stages ONE sector for all eight units rather
    # than one per unit, and the reason is this invariant: Reno needs a
    # per-unit buffer because physio sleeps waiting for B_DONE, and FGX's
    # transfer cannot sleep, so nothing can run between one block and the next.
    # Listing the file is what makes that enforced instead of reasoned -- this
    # checker's own header says a sleep reached by calling OUT of the listed
    # files is invisible to it, and the file is listed for exactly that reason.
    "src/drivers/block/rawdisk.s",
]

# ---------------------------------------------------------------------------
# The SECOND category, and it exists because the buffer cache breaks the first
# one on purpose.
#
# vfs_bio.c SLEEPS.  getblk waits on a busy buffer and getnewbuf waits for one
# to be freed, and those waits are the entire reason a cache can be shared
# between tasks -- forbidding them would forbid the deliverable.  So the rule
# for this file is not "never sleep", it is WHERE.
#
# What must stay true is that nothing sleeps BELOW the block driver.  Blk_Read
# and Blk_Write run to completion, which is what makes the legacy layer's sixty
# shared singletons safe without a lock; the moment something under them can
# block, every one of those becomes a cross-process corruption.  vfs_bio sits
# ABOVE Blk_*, so its lock waits cost nothing -- provided they stay in the
# routines that are supposed to have them.
#
# Hence an ALLOWLIST OF ROUTINES rather than a file exemption.  A sleep added
# to brelse, to bufinit, or to whatever wraps the strategy call is a sleep in a
# new place, and a new place is exactly what nobody will notice.  Naming the
# three that may sleep turns "somebody added a sleep" from invisible into a
# build failure.
#
# biowait is on the list and its sleep is UNREACHABLE today: the strategy
# routine is synchronous and sets B_DONE before returning, so the loop never
# runs.  It is allowed rather than forbidden because the loop is correct code
# that must survive until an asynchronous device exists -- but if it ever
# starts sleeping for real, that sleep IS below the driver and this whole
# design is void.  That cannot be caught statically; the fixture asserts it at
# runtime instead, by counting.
#
# vflushbuf AND vinvalbuf WERE ADDED BY UFS 1.4 (fgx#90).  This list was
# written at 1.3, when vfs_bio had three sleepers; the vnode layer brought two
# more and the list was not updated, so the checker went red on main and stayed
# red.  It was right to: a new sleeper is exactly what it exists to catch, and
# the question it forced -- are these two safe? -- is answered here rather than
# by widening the list quietly.
#
# Both are already in the two classes above, reached from a new caller:
#
#   vinvalbuf sleeps on a BUSY BUFFER (`bp->b_flags |= B_WANTED; kc_sleep(bp)`)
#   -- the identical wait getblk has, arrived at from the invalidate walk
#   instead of a lookup.  Allowed for the identical reason: it is a buffer lock
#   wait and it sits above the block driver.
#
#   vflushbuf sleeps on I/O COMPLETION (`while (vp->v_numoutput) kc_sleep(...)`)
#   -- the identical wait biowait has, and UNREACHABLE for the identical
#   reason: bio_strategy is synchronous and biodone runs inside it, so
#   v_numoutput is already zero before bwrite returns and the loop never
#   executes.  Kept, not deleted, for the reason biowait's loop is kept: it is
#   the code that has to be right the day a device can queue.
#
# THE RULE THIS LIST ENCODES, since five names now need one: a sleep in the
# vnode-keyed cache is allowed when it waits on BUFFER or VNODE state -- B_BUSY,
# B_WANTED, v_numoutput -- which is above the block driver and therefore cannot
# make Blk_Read/Blk_Write able to block.  It is not allowed anywhere else, and
# no name on this list may acquire a sleep of the other kind.  brelse, bufinit,
# bremfree, reassignbuf and whatever wraps the strategy call are still
# forbidden, which is the whole value of naming routines instead of the file.
#
# UFS 1.12d ADDED A THIRD CLASS, and it is not covered by the rule above: the
# INODE LOCK waits on INODE state.  ILOCKED/IWANT are neither buffer state nor
# vnode state, so widening the sentence would have been the quiet kind of
# widening this list exists to prevent.  The rule it needs is its own:
#
#   A SLEEP IN THE VNODE-KEYED CACHE IS ALLOWED WHEN IT WAITS ON BUFFER, VNODE
#   OR INODE OWNERSHIP STATE -- B_BUSY, B_WANTED, v_numoutput, VXLOCK, ILOCKED,
#   IWANT, sb_flock, sb_ilock -- because every one of those is released by
#   code running ABOVE the block driver, so none of them can make
#   Blk_Read/Blk_Write able to block.
#
# The load-bearing half is "released above the driver", not "named in this
# list".  A wait for something a DEVICE has to finish would be the other kind
# whatever it was called, and the two vendors' own answer is the check to
# apply: 2.11BSD and Reno both hold these locks across bread and neither holds
# one across the strategy call.
#
# WHICH IS ALSO WHY THE FILE LIST GREW HERE.  Until 1.12d this table named one
# file, vfs_bio.c, so the checker's report -- "no sleep/yield" -- covered eight
# assembly files and one C file, and the six C files of the VFS layer that
# could sleep were simply not looked at.  Three of them already did: ufs_alloc
# has held sb_flock and sb_ilock since 1.10b and dead_vnops has waited on
# VXLOCK since 1.4b, neither of them wrong and neither of them ever checked.
# Naming the routines is what makes the NEXT one a build failure.
SLEEP_ALLOWED = {
    "src/kernel/vfs/vfs_bio.c": (
        "getblk", "getnewbuf", "biowait", "vflushbuf", "vinvalbuf",
    ),
    # The superblock's two allocator locks (1.10b) -- fs_flock and fs_ilock in
    # 2.11BSD, guarding the windows where the in-core free lists disagree with
    # the platter.  ufs_alloc.c's header carries the argument.
    "src/kernel/vfs/ufs_alloc.c": (
        "ufs_balloc", "ufs_bfree", "ufs_ialloc",
    ),
    # The INODE lock, 1.12d.  ufs_lock is the wait itself; ufs_ihashget waits
    # on the same bit for a different reason -- construction, not ownership --
    # and its header is careful about the difference.
    "src/kernel/vfs/ufs_vnops.c": ("ufs_lock",),
    "src/kernel/vfs/ufs_inode.c": ("ufs_ihashget",),
    # VXLOCK, "this vnode is being torn down".  vgone's wait is 1.4b's; vget's
    # was added at 1.12d, when ufs_ihashget started RETRYING on a refusal and
    # a refusal without a sleep became a spin.
    "src/kernel/vfs/vfs_subr.c": ("vget", "vgone"),
    # chkvnlock, the dead-vnode vector's wait on the same VXLOCK.
    "src/kernel/vfs/dead_vnops.c": ("chkvnlock",),
}

# K&R function definitions start in column 0.  TWO shapes appear in this tree
# and both have to be recognised:
#
#   getblk(vp, blkno)      the return type on the line above -- vfs_bio, ufs_*
#   int vget(vp)           the return type on the SAME line   -- vfs_subr.c
#
# Matching only the first was right while vfs_bio.c was the only C file
# scanned, because it is written in that style throughout.  It stops being
# right the moment vfs_subr.c is scanned (UFS 1.12d): `int vget(vp)` would not
# open a routine, so vget's sleep would be attributed to whatever function
# happened to precede it in the file -- and an allowlist naming the wrong
# routine is worse than no allowlist, because it reads as considered.
#
# The `;` guard in c_routines is what keeps the forward declarations that
# share this shape (`void vrele();` in column 0) from opening a routine.
CFUNC_RE = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*\s+\**)*([a-z_][A-Za-z0-9_]*)\s*\(")

# A sleep by any of its spellings -- matched by SHAPE, not by a name list.
#
# The name list this replaced enumerated five spellings, and three of them
# (_Sys_Sleep, _Sched_Yield, Task_Yield) did not exist anywhere in the tree.
# The self-test then proved the checker recognised those three, so it read as
# thoroughly verified while missing every spelling that is actually reachable:
# _Sys_Nanosleep/SYS_NANOSLEEP, the module jump-table slot SYS_NETKC_SLEEP
# (with its kernel target _Net_KCall_Sleep), and the far shim _FarSh_Sleep --
# which is how module and far-bank code sleeps, i.e. exactly the shape ported
# UFS code will have.  That is the same defect as the first version of this
# file, which matched only the kernel's Blk_Read spelling and missed prodos.
#
# So: any identifier containing "sleep", "yield" or "wait", minus the names
# below that contain one without blocking.
#
# "wait" is here because the first shape-matching version of this regex still
# could not see the spelling this project has already written down as the one
# that is COMING.  The reentrancy audit names biowait as the genuine sleep that
# vfs_bio needs, and 2.11BSD spells that family biowait / iowait / bwait --
# not one of which contains "sleep" or "yield".  A JSR _FarSh_Biowait dropped
# into a scanned file would have sailed through green, which would have been
# the third round of this same defect: a guard that reads as thorough because
# it covers the spellings someone happened to think of.
SLEEP_RE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*"
    r"(?:[Ss][Ll][Ee][Ee][Pp]|[Yy][Ii][Ee][Ll][Dd]|[Ww][Aa][Ii][Tt])"
    r"[A-Za-z0-9_]*)\b")

# Identifiers that contain "sleep"/"yield" but do not block: sleeper COUNTERS
# read by the scheduler, and branch targets named after the yield they skip.
NOT_A_SLEEP = {
    "_nSelSleepers", "_nTimerSleepers", "je_noYield",
}

# Calls that will be able to block once vfs_bio's sleeping buffer locks land.
#
# BOTH spellings are required.  The kernel calls the block layer directly by
# label; prodos.mod is a separate binary and reaches it through the module
# jump table (JSL SYS_BLKREAD).  An earlier version of this checker matched
# only the kernel spelling and reported a confident "12 sites" while missing
# the single largest consumer in the tree -- prodos.s alone holds KAD_fsDirBuf
# across 91 references.  A checker that cannot see the worst offender is worse
# than no checker, because it reads as a clean bill of health.
BLK_CALL_RE = re.compile(
    r"\b(?:JSR|JSL)\s+("
    r"Blk_Read|Blk_Write|_BlkCache_PinGet|_BlkCache_PinAllocZ"
    r"|SYS_BLKREAD|SYS_BLKWRITE|SYS_BLKPIN|SYS_BLKPINZ"
    r")\b"
)

# Shared FS/block state, in both spellings: the kernel's own labels, and the
# KAD_* absolute-address EQUs prodos.mod uses to reach the same bytes.  Kept
# as patterns rather than a hand-listed inventory so a singleton added later
# is covered without editing this file.
#
# _blk* is here because deliverable 1.0 ADDED a singleton to this layer while
# this checker was being written and could not see it: _blkCurHi holds the
# high word of the 32-bit block number for the whole duration of a Blk_*
# call, read-ahead included.  If Blk_* ever blocks, a second task's latch
# clobbers the first task's high word mid-operation and it reads the wrong
# block -- a singleton created by the very campaign that added this check.
SINGLETON_RE = re.compile(
    r"\b("
    r"_fs[A-Z][A-Za-z0-9_]*|_bm[A-Za-z0-9_]*|_ul[A-Z][A-Za-z0-9_]*|_fw[A-Z][A-Za-z0-9_]*"
    r"|_blk[A-Z][A-Za-z0-9_]*"
    r"|KAD_[A-Za-z0-9_]+"
    r")\b"
)

# There is deliberately NO exclusion list.
#
# There was one: the direct-page transients (_fsTmp0/1/2, _fsCurDevIdx,
# _blkNum, _blkBuf), on the grounds that they are "documented caller-saved and
# every Blk_* caller already concedes them".  That grounds does not survive
# contact with any of its members:
#
#   _fsTmp0/1  Blk_Read PRESERVES them (block.s:217, 2026-07-18) for the
#              stated reason that callers hold live state there across the
#              call and "worked by luck" before.  Conceded is the opposite of
#              what they are.
#   _fsCurDevIdx  bitmap.s:492-499 saves it, retargets the device, and
#              restores it -- a span that brackets a blocking call.
#   _blkNum    read directly from DP throughout Blk_Read, never latched.
#              Deliverable 1.0 latched the HIGH word into _blkCurHi so it
#              could not be clobbered mid-call; the low word got no such
#              treatment and is exposed identically.
#
# Caller-saved is a statement about what the CALLEE clobbers.  Sleep exposure
# is a statement about what another TASK clobbers, and the kernel direct page
# is one shared page.  Those are different questions, and answering the second
# with the first is the "who writes it vs who uses it" framing error the audit
# for this deliverable warns about.  Over-reporting here is the safe
# direction; under-reporting is how this checker was wrong twice.

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s")


def routines(path):
    """Split a Merlin source into (name, lines).  A label in column 0 starts a
    routine; local labels (@foo) and directives do not."""
    text = (ROOT / path).read_text(encoding="utf-8", errors="replace").split("\n")
    cur, buf = "<file>", []
    for line in text:
        m = LABEL_RE.match(line)
        if m and not line.startswith(("*", ";")):
            if buf:
                yield cur, buf
            cur, buf = m.group(1), [line]
        else:
            buf.append(line)
    if buf:
        yield cur, buf


def _strip_c_comments(text):
    """Remove /* ... */ across line boundaries and // to end of line.  Done on
    the WHOLE file before splitting, because the block comments in this code
    are long and paragraph-shaped, and a single-line stripper leaves their
    prose to be matched as code -- which it duly was, on the word "biowait"."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def c_routines(text):
    """Split K&R C into (name, lines).  A name in column 0 followed by '(' opens
    a function, since the return type sits on the line above."""
    cur, buf = "<file>", []
    for line in text.split("\n"):
        m = CFUNC_RE.match(line)
        if m and not line.rstrip().endswith(";"):
            if buf:
                yield cur, buf
            cur, buf = m.group(1), [line]
        else:
            buf.append(line)
    if buf:
        yield cur, buf


def check_sleep_sites(path, allowed, violations):
    """A file that MAY sleep, but only in named routines.

    WHAT COUNTS AS SLEEPING HERE is narrower than in the assembly scan, and it
    has to be.  There the primitives are the only sleep-shaped names, so
    matching the shape is exactly right.  In C the file DEFINES biowait, so the
    same shape matches its definition, its forward declaration, and every call
    to it -- none of which is a sleep.  Calling biowait is not sleeping; biowait
    sleeping is sleeping, and biowait is on the allowlist.

    So a violation is a sleep-shaped CALL to something this file does not
    define: that is a blocking primitive coming from outside.  Transitive
    blocking is expected and fine -- bread blocks by calling biowait, and it is
    above the block driver, which is the whole point.
    """
    text = _strip_c_comments((ROOT / path).read_text(encoding="utf-8",
                                                     errors="replace"))
    routines = list(c_routines(text))
    defined = set(n for n, _ in routines)

    for name, lines in routines:
        if name in allowed:
            continue
        for line in lines:
            if "extern" in line:
                continue
            for m in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", line):
                sym = m.group(1)
                if sym in defined or sym in NOT_A_SLEEP:
                    continue
                if not SLEEP_RE.fullmatch(sym):
                    continue
                violations.append(
                    f"{path}:{name}: calls {sym}, and only "
                    f"{'/'.join(allowed)} may sleep: {line.strip()}")


def strip_comment(line):
    # Merlin: ';' starts a comment, and a full-line '*' comment too.
    if line.lstrip().startswith(("*", ";")):
        return ""
    return line.split(";", 1)[0]


def stale(path, listname):
    """A file this checker names has left the tree.

    NOT A FINDING ABOUT SLEEPING, and the exit code has to say so.  The caller's
    canned reason for a non-zero exit asserts that the FS layer sleeps; printing
    that when the check never read a line writes a false claim about the product
    into the gate receipt and into .gate/history.jsonl, where it outlives the
    run.  2 means "this checker is stale", 1 means "the invariant is broken".
    """
    print(f"error: {path} is missing -- remove it from {listname} in "
          f"{Path(__file__).name}.")
    print("       THE CHECK DID NOT RUN.  This says nothing about whether the "
          "FS layer sleeps.")
    return 2


def self_test():
    """Prove the invariant check can FAIL.  A guard that cannot go red is the
    defect it exists to catch -- and this one guards a property that is
    currently true everywhere, so without this it would pass identically
    whether it worked or did nothing at all."""
    # Every spelling below was grepped out of this tree, not invented.  The
    # list this replaced contained three names that exist nowhere in FGX, so
    # the self-test passed while proving nothing about a reachable sleep.
    for spelling in (
        "JSR     _sleep",               # kernel primitive
        "JSL     SYS_NETKC_SLEEP",      # module, via the jump table
        "JSR     _Net_KCall_Sleep",     # ...and its kernel target
        "JSL     _FarSh_Sleep",         # far-bank shim
        "JSR     _Sys_Nanosleep",       # timed sleep
        "LDA     _kYieldReq",           # cooperative yield flag
        "JSR     _Sys_Yield",
        "JSL     _FarSh_Biowait",       # the spelling 1.3 will actually add
        "JSR     _Buf_Wait",
    ):
        line = f"Fake_Routine\n                {spelling}\n"
        matched = [s for s in SLEEP_RE.findall(line) if s not in NOT_A_SLEEP]
        if not matched:
            print(f"self-test FAILED: sleep spelling not detected: {spelling!r}")
            return 1
    # ...that an ordinary FS line is NOT mistaken for one...
    for benign in ("                JSR     Blk_Read", "                LDA     _fsDirBuf"):
        if [s for s in SLEEP_RE.findall(benign) if s not in NOT_A_SLEEP]:
            print(f"self-test FAILED: false positive on {benign!r}")
            return 1
    # ...and that the names carrying the word without blocking are exempt, or
    # the shape-matched regex would fire on the scheduler's sleeper counters.
    for exempt in ("                INC     _nSelSleepers", "                BRA     je_noYield"):
        if [s for s in SLEEP_RE.findall(exempt) if s not in NOT_A_SLEEP]:
            print(f"self-test FAILED: NOT_A_SLEEP name flagged: {exempt!r}")
            return 1
    # ...and that the singleton 1.0 added is visible, since it was created by
    # this campaign while this checker was blind to its whole name family.
    if not SINGLETON_RE.search("                LDA    |_blkCurHi"):
        print("self-test FAILED: _blkCurHi not recognised as a singleton")
        return 1
    # ...and that both call spellings are recognised, since missing the
    # module spelling is exactly how this checker was wrong the first time.
    for call in ("                JSR     Blk_Read", "                JSL     SYS_BLKREAD"):
        if not BLK_CALL_RE.search(call):
            print(f"self-test FAILED: blocking call not detected: {call!r}")
            return 1
    for name in ("KAD_fsDirBuf", "_fsPathScratch", "_bmSyncIdx"):
        if not SINGLETON_RE.search(f"                LDA     {name}"):
            print(f"self-test FAILED: singleton not detected: {name}")
            return 1
    # ...and that the routine allowlist DISCRIMINATES: a sleep in an allowed
    # routine is fine, the same sleep one routine over is not.  Without this
    # the second category could allowlist everything and still look green.
    import tempfile
    td = tempfile.mkdtemp()
    fake = Path(td) / "fake.c"
    fake.write_text(
        "int\ngetblk(a)\n{\n    kc_sleep(x);\n}\n\n"
        "void\nbrelse(b)\n{\n    kc_sleep(x);\n}\n")
    global ROOT
    saved, ROOT = ROOT, Path(td)
    v = []
    check_sleep_sites("fake.c", ("getblk",), v)
    ROOT = saved
    import shutil
    shutil.rmtree(td, ignore_errors=True)
    if len(v) != 1 or "brelse" not in v[0]:
        print(f"self-test FAILED: routine allowlist wrong: {v}")
        return 1

    # ...and that NEITHER LIST HAS ROTTED.  Both are manual, so a file deleted
    # from the tree leaves a name here that resolves to nothing, and the main
    # run then stops at the first one having checked nothing at all.  Asserting
    # it HERE is what makes that arrive as "the checker is stale" before the
    # build, instead of as a verdict about the FS layer after it.
    missing = [p for p in list(FS_LAYER) + list(SLEEP_ALLOWED)
               if not (ROOT / p).exists()]
    if missing:
        for p in missing:
            print(f"self-test FAILED: {p} is listed here but not in the tree")
        return 1

    print("check_fs_sleep_invariant: self-test OK")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()

    violations = []
    exposure = {}

    for path in FS_LAYER:
        if not (ROOT / path).exists():
            return stale(path, "FS_LAYER")

        for name, lines in routines(path):
            code = [strip_comment(l) for l in lines]
            body = "\n".join(code)

            for line in code:
                if any(s not in NOT_A_SLEEP for s in SLEEP_RE.findall(line)):
                    violations.append(f"{path}:{name}: {line.strip()}")

            if not BLK_CALL_RE.search(body):
                continue

            # Which singletons does a routine touch in the same breath as a
            # blocking call?  Those are the ones whose contents have to
            # survive the sleep 1.3 will introduce.
            #
            # This is INTRAPROCEDURAL, so the count is a LOWER BOUND and is
            # reported as one.  The dominant real case is cross-routine --
            # prodos.s reads a directory block in one routine and consumes
            # KAD_fsDirBuf in another -- and catching that needs a call graph
            # across two binaries and a module jump table.  Widening the test
            # from "referenced on both sides of the call" to "referenced at
            # all alongside one" is the cheap approximation that stops the
            # report from being confidently wrong in the safe direction.
            for line in code:
                for s in SINGLETON_RE.findall(line):
                    sites = exposure.setdefault(s, set())
                    sites.add(f"{path}:{name}")

    # The second category: files that may sleep, but only where they should.
    for path, allowed in SLEEP_ALLOWED.items():
        if not (ROOT / path).exists():
            return stale(path, "SLEEP_ALLOWED")
        check_sleep_sites(path, allowed, violations)

    if violations:
        print("check_fs_sleep_invariant: FAILED -- the FS/block layer now sleeps.")
        print()
        print("  The shared FS singletons are safe today only because these")
        print("  layers run to completion.  A sleep here means every singleton")
        print("  listed by --exposure is a cross-process corruption (fgx#41's")
        print("  shape).  DECIDE WHICH THIS IS, and do not just widen the")
        print("  allowlist: a sleep that waits on BUFFER, VNODE or INODE")
        print("  ownership state sits above the block driver and belongs on it")
        print("  (see SLEEP_ALLOWED for the rule and its history).  A sleep")
        print("  that makes Blk_Read/Blk_Write able to block does not -- the")
        print("  singletons below must be per-process or lock-protected FIRST.")
        print()
        for v in violations:
            print(f"    {v}")
        return 1

    total = sum(len(v) for v in exposure.values())
    nallowed = sum(len(v) for v in SLEEP_ALLOWED.values())
    print(
        f"check_fs_sleep_invariant: clean "
        f"({len(FS_LAYER)} files no sleep/yield, "
        f"{len(SLEEP_ALLOWED)} may sleep in {nallowed} named routines; "
        f">= {len(exposure)} singletons exposed at >= {total} sites once Blk_* can block)"
    )

    if "--exposure" in sys.argv:
        print()
        print("Singletons touched in a routine that can block -- the 1.3 conversion")
        print("list.  INTRAPROCEDURAL, so this is a LOWER BOUND: the cross-routine")
        print("case (prodos reads a block in one routine, consumes the shared buffer")
        print("in another) is not counted and is the dominant one.")
        for s in sorted(exposure, key=lambda k: (-len(exposure[k]), k)):
            sites = exposure[s]
            print(f"  {s:<24} {len(sites):>3} routine(s)")
            for site in sorted(sites):
                print(f"      {site}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
