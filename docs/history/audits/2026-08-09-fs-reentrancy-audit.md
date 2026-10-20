# FS reentrancy audit -- UFS campaign deliverable 1.0b

Measured 2026-08-09 against the tree at `1c706fe06`.  Enforced by
`tools/check_fs_sleep_invariant.py`, wired into `tools/gate.sh`.

The campaign plan schedules this **before** the buffer cache gains sleeping
locks, not after.  This document records what the audit found so 1.3 starts
from measurements rather than from the plan's prose, which has drifted.

## The invariant, stated out loud for the first time

Every shared singleton in the FS layer is safe today for exactly one reason:
**nothing in that layer ever sleeps or yields.**  A syscall that picks up the
directory buffer runs to completion before any other task can touch it, so
one buffer serves every process without a lock.

That safety was an emergent property of the call graph.  Nothing in the tree
asserted it, so nothing would have caught the change that breaks it.  It is
now a gate check.

**Measured:** zero `sleep`/`yield` across **eight** files --

```
src/drivers/fs/{fs,bitmap,path,inode,fcb}.s
src/drivers/block/{block,blkcache}.s
src/modules/prodos/prodos.s
```

The plan names three of these (`fs.s`, `bitmap.s`, `prodos.s`).  The other
five carry the same dependency, and `blkcache.s` is the one 1.3 modifies.

## What 1.3 breaks

Reno's `vfs_bio.c` brings sleeping buffer locks.  The moment `Blk_*` can
block, every singleton live across a `Blk_*` call becomes a cross-process
corruption:

> task A fills the shared directory buffer, sleeps inside the buffer cache,
> task B refills it, A resumes and reads B's block.

That is apple/fgx#41's exact shape -- a shared cell held across a sleep -- and
#41 took a long time to find because the symptom appears in the victim, not
the culprit.

## The exposure list

`tools/check_fs_sleep_invariant.py --exposure` prints it live.  As measured:
**>= 60 singletons at >= 138 sites.**

The first measurement said 51 at 108.  The difference is not new code; it is
an exclusion list that should never have existed.  Six direct-page cells were
held out as "documented caller-saved, every `Blk_*` caller already concedes
them", and that is false for every one of them: `Blk_Read` *preserves*
`_fsTmp0/1` (`block.s:217`) precisely because callers hold live state there
across the call, `bitmap.s:492-499` saves and restores `_fsCurDevIdx` across
a device retarget, and `_blkNum` is read straight from the direct page
throughout `Blk_Read` with no latch.  Caller-saved describes what the CALLEE
clobbers; sleep exposure describes what another TASK clobbers, and the kernel
direct page is one shared page.  Answering the second question with the first
is the same framing error recorded in finding 3 below.

The heaviest, and the ones to convert first:

| singleton | routines | note |
|---|---|---|
| `KAD_fsDirBuf` / `_fsDirBuf` | 9 + 7 | one 512 B directory block, shared by every FOP |
| `KAD_fsDirBuf_off` | 10 | the cursor into it -- travels separately, so it can desync |
| `KAD_fsPathScratch` | 4 | 288 B resolver work area, live across a whole path walk |
| `_fsBmVolDev` / `_fsBmReqDev` | 1 each | which volume's bitmap is resident; a swap mid-sleep silently retargets an allocation |
| `KAD_ulKeyBlk` | 5 | unlink/truncate cursor, live across block frees (`ulEntryBlk`/`ulEntryOff` 3 each) |
| `_blkCurHi` | -- | the 32-bit block number's high word, live for the WHOLE `Blk_*` call including read-ahead |
| `_blkNum` | -- | ...and the low word, which unlike the high word is never latched |

`_blkCurHi` deserves its own note: **deliverable 1.0 of this campaign created
it**, while this audit was being written, and the checker could not see it
because no `_blk*` name was in the singleton pattern.  1.0 latched the high
word at the block-layer entry so a caller could not clobber it mid-call --
good -- but the latch protects against the CALLER, not against another task.
If `Blk_*` ever blocks, a second task's latch overwrites the first task's high
word and it reads a block 64 K away.  The low word `_blkNum` has the same
exposure and not even the latch.  A campaign adding singletons to the layer it
is auditing for singletons is worth saying out loud.

**The count is a LOWER BOUND and the tool says so.**  The analysis is
intraprocedural; the dominant real case is cross-routine -- prodos reads a
block in one routine and consumes `KAD_fsDirBuf` in another -- and catching
that needs a call graph spanning two binaries and a module jump table.  Do not
quote 108 as the size of the job.

## Three findings that change how 1.3 should be approached

**1. The plan's singleton list is stale.**  It names `_fsDirBuf` and
`_fsPathScratch`.  `_fsDataBuf`, `_fsIndexBuf`, `_fsMasterBuf` and the whole
`_fsFileState` machine were **deleted** by P3.3-iv -- the singleton retirement
already did a large part of this job.  What remains is smaller than the plan
implies but differently shaped: it is concentrated in the *directory* path,
not the *file* path.

**2. `prodos.mod` is the largest holder and it is invisible to the obvious
search.**  It reaches the same bytes through `KAD_*` absolute EQUs and calls
the block layer through the module jump table (`JSL SYS_BLKREAD`), so a
checker written against the kernel's spelling reports a confident clean.  The
first version of this checker did exactly that -- 12 sites, none in prodos,
while `KAD_fsDirBuf` alone has 91 references.  Any future audit tooling has to
cover both spellings or it is measuring the wrong tree.

**3. The question is "who USES it", not "who writes it".**  A survey organised
around writers cannot express *whose bytes is another task running on right
now*, which is the question a sleeping lock actually poses.  That framing error
already cost this project once, on the bank-0 stack-swap campaign, where the
write-oriented survey was wrong by two and both misses were readers.

## First: does 1.3 have to add a sleep DOWN HERE at all?

Everything below assumes `Blk_*` becomes able to block.  That is an
assumption, not a requirement, and it is worth challenging before anyone
converts sixty singletons.

FGX's disk I/O is synchronous SmartPort PIO.  There is no interrupt-driven
completion to wait on, so a `biowait` has nothing to wait for -- the transfer
is already finished when the call returns.  The sleeps Reno's `vfs_bio.c`
genuinely needs are buffer LOCK waits (another task holds this buf), and
those live in `getblk`/`brelse`/`biowait`, strictly ABOVE the block driver.

If 1.3 keeps `Blk_Read`/`Blk_Write` run-to-completion and confines its sleeps
to the layer above, then:

- the eight legacy files never sleep, so the invariant in this document holds
  permanently rather than being a tripwire waiting to be disarmed;
- the sixty singletons never need converting -- they retire with ProDOS in
  phase 3 instead;
- what replaces the whole conversion campaign is one rule: **a device is
  cached by exactly one stack, legacy `blkcache` or `vfs_bio`, never both.**
  Two caches over one device would otherwise hold the same block twice with
  no coherence between them.

That trade -- one ownership guard instead of sixty conversions -- is the
cheaper side by a wide margin, and it costs nothing that a synchronous-I/O
machine was going to use anyway.  It is a design decision, so it is recorded
here as one rather than assumed in either direction.

Converting the singletons is also **mis-ordered against 1.2** as currently
scheduled: the prescribed target for `_fsDirBuf`/`_fsDirBuf_off` is "per-FCB",
and 1.2 deletes the FCB.  Doing the conversion first means doing it twice.

## If the answer is yes: what 1.3 must do before adding a sleep

Per the plan's risk table: **audit every FS singleton, and either make it
per-process or hold a lock across the sleep.**  Concretely, in order:

1. `_fsDirBuf` + `_fsDirBuf_off` -> per-FCB or per-process.  They are one
   logical object and must move together; a buffer that migrates while its
   cursor does not is a worse bug than either alone.
2. `_fsPathScratch` -> per-process.  It is live across an entire path walk,
   which is the longest span in the layer.
3. `_fsBmVolDev`/`_fsBmReqDev` -> a lock, not a split: bitmap residency is
   genuinely global state, so the fix is to hold it across the sleep.
4. Re-run the checker.  When the conversions are done, the sleep goes in and
   `check_fs_sleep_invariant.py` gets updated to encode the new rule --
   which routines may block, and which singletons are provably per-process by
   then.  The checker failing is the signal to do that work, not to delete it.

## What the checker does NOT enforce

Stated here because the checker's own docstring originally claimed otherwise
("it goes RED the moment 1.3 adds a sleep"), and a guard believed to cover
more than it does is worse than a guard known to be narrow.

It scans the eight files in `FS_LAYER` and nothing else.  Reno's `vfs_bio`
lands in a new file, in C, in a module bank: a sleeping buffer lock there is
invisible, and so is any sleep reached by calling out of these eight files
into a helper that lives elsewhere.  Getting the red when `Blk_*` itself
becomes able to block requires adding that file to `FS_LAYER` by hand.

What it does enforce is narrower and, under the section above, permanent:
**the legacy layer stays sleep-free.**

## Verification

The invariant check is mutation-tested.  Injecting each of `JSL
SYS_NETKC_SLEEP`, `JSL _FarSh_Sleep` and `JSR _Sys_Nanosleep` into `bitmap.s`
turns it red; the tree restores clean.  `--self-test` (run by the gate)
proves it recognises seven sleep spellings, both blocking-call spellings and
both singleton spellings, without firing on ordinary FS lines or on the
scheduler's sleeper COUNTERS.

Every spelling in that self-test was grepped out of this tree.  The previous
version tested five, of which **three (`_Sys_Sleep`, `_Sched_Yield`,
`Task_Yield`) exist nowhere in FGX** -- so the self-test passed while proving
the checker could detect names nothing would ever emit, and it missed every
spelling by which module and far-bank code actually sleeps.  Ported UFS code
sleeping through a jump-table slot is precisely the shape it was blind to.
The regex now matches by SHAPE (any identifier containing "sleep" or "yield")
with a three-name exemption list, so spelling number eight is covered before
someone invents it.
