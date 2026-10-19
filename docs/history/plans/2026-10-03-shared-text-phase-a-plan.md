# Shared text (coremap spec, phase A) -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A program's code banks are loaded once and shared by every running instance of it, as 2.11BSD shares text, so 21 `sleep`s hold 22 banks for their images instead of 42.

**Architecture:** The bank spawn and exec allocate before the load becomes the process's DATA bank; the loader puts the code segments in banks it allocates on a miss, or maps from a cached text on a hit.  A text table in the tty bank (behind new KTTY slots) records each text by the file's identity and change time, its code banks, the libc pile it was relocated against, and a reference count; a per-pid byte array says which text each process uses.  Fork takes a reference, exit and exec drop one, and `Bank_Alloc` frees unused cached texts before it asks the Memory Manager for a bank, as `malloc(coremap)` calls `xuncore()`.

**Tech Stack:** Merlin32 65816 (`src/kernel/far/loader.s`, `process.s`, `task.s`, `bank.s`, `main.s`, a new tty-bank file), fcc K&R C (`src/kernel/vfs/vfs_syscalls.c`, far bank), Python 3 check scripts, 2.11BSD sh scripts under `disk_src/testdata/`, ninja, headless MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-10-03-coremap-shared-text-design.md`, sections 3, 4, 5, 8, 9 (steps A1, A2).  2.11BSD: `vendor/2.11BSD/usr/sys/h/text.h`, `sys/vm_text.c` (`xalloc`, `xfree`, `xuntext`, `xuncore`), `sys/kern_fork.c`, `sys/kern_exec.c`.

## Global Constraints

- Branch `feat/shared-text` (off `feat/mem-quick-wins`; rebase onto main once !405 merges).  No push and no MR until the maintainer asks; pushes need `ALLOW_FEAT_PUSH=1`.  Each commit ends with the session's attribution trailers; bodies are the changelog (informational, no names or process).  Announce every `ninja` rebuild and every MAME run before it starts.
- ASCII only; comments describe the current state only.  Merlin32 has no operator precedence (braces, not parens); explicit `MX` at every label reached in another width (`check_mx`).
- Toolchain-first: a gap in fcc or libc is fixed there, never worked around.
- A kernel behaviour with a BSD counterpart: read it in `vendor/2.11BSD/usr/sys/` and name file and function in the commit; quote the deciding line.
- Byte budgets, measured on this branch before Task 1 (`python3 tools/check_kernel_ceiling.py`): core 134 bytes free, far 187, tty 2,329.  Every task that adds code records the new free counts in its commit body.  On `feat/shared-libc` the core has 4 bytes free and the tty bank about 1,976; the merge into that branch is a later step that must find core bytes there (Ruling 6).
- KTTY slots: main uses up to 48, `feat/shared-libc` up to 55.  This plan takes **56 onward**, so the merge does not collide.
- Every MAME verdict is a fresh run (`--fresh`; "(1 cached)" did not run).  A typed command is at most 255 characters; a longer probe is a `sh /testdata/<name>` script (a new testdata file needs `python3 tools/ninja/gen.py` before ninja).
- Never `git checkout` a tracked-but-generated file (`kernel_exports.s`, patch-site tables); regenerate them with the command the kernel checks print.
- Tests are the tail: one discriminating probe per mechanism, each shown RED before the change it proves.  The gate has a seconds ratchet; this plan adds no gate test.
- Before the last commit, run every manifest: `python3 -c "import os;print('\n'.join(sorted(f[:-5] for f in os.listdir('tools/mame_test/tests') if f.endswith('.json'))))" | xargs python3 tools/mame_test/run.py --fresh`.  Known failures on main: none expected after !403/!404; record any.

## Rulings this plan makes against the spec (each lands in the spec in Task 6)

1. **The pre-allocated bank becomes the data bank; exec and spawn keep their order** (spec 5.3 said "open and look up first").  Spawn (`process.s:111-119`), exec (`process.s:2926-2937`) and init's boot load (`main.s:932-987`) allocate one bank and pass it to the loader as the override.  The loader loads the DATA segment (`n_data_segment`) there instead of segment 0, and code segments into banks it allocates (miss) or maps from the text (hit).  The override stays the one bank the caller owns, so every rollback that frees `_ps_childBank` / `TCB_BankList[0]` stays correct without reordering anything.  This answers Fable's C1 with less change.
2. **The text's identity is `(va_fsid, va_fileid, va_ctime)` from `VOP_GETATTR`, and no vnode reference is held** (spec 5.2 said a `v_usecount` reference and `v_id`).  Holding a vnode per cached text would take one of only 64 (`VNODE_POOL`, `fsparam.h:121`) for as long as the text is cached, make unmount answer EBUSY, and keep an unlinked file's blocks allocated until the text went.  `va_ctime` changes on every write, truncate, chmod and link change, so a rewritten or replaced file never matches its old text; a removed file's text is never matched again and is freed by reclaim.
3. **Step A2 (ETXTBSY and the unlink/chmod flush) is not done; writing a running program stays allowed** (spec 5.3/9 had it).  2.11BSD refuses the write because its text is read from the inode and the swap area on demand (`vm_text.c` `xalloc` -> `xexpand`/`swapin`), so a write would change running code.  FGX's text is a complete in-memory copy made at load, so writing the file cannot change a running program; Ruling 2's key keeps the cache from serving a stale copy.  `vn_writechk`'s `VTEXT` test (`vfs_vnops.c:172`) stays unreachable, as it is today.  Confirmed by the maintainer, 2026-10-03 -- the one ruling that removes a behaviour the spec promised.
4. **The text table and its code live in the tty bank behind KTTY slots 56-60** (spec 5.3 said the far bank).  The far bank has 187 bytes free; the tty bank 2,329, and it already hosts core-side logic behind KTTY slots (#511's precedent on `feat/shared-libc`).  The loader (far bank) reaches the table through two core `_FarSh_*` shims; fork, exit and exec reach it directly through the slots.
5. **A program read through a descriptor with no vnode is never cached**, as a ProDOS-hosted binary is today (`ld_fd_is_vnode`, `vfs_syscalls.c:1470`): it loads as before, into banks it owns.  So is a FGX1 binary (no segment table).
6. **The merge into `feat/shared-libc` is not part of this plan.**  It needs core bytes there (4 free); the plan records the core cost of each hook so that merge can be planned against it.

## Review Focus

1. **The same program rewritten in place between two runs** -- the second run executes the new code, not a cached copy.  Test: `textfresh` (Task 5).
2. **Pool pressure with many cached texts** -- a spawn that finds the pool dry frees an unused cached text before asking for a grant, and runs.  Test: `textreclaim` (Task 5).
3. **An exec that fails after a text hit** (for example, no room for its stack) -- the text's count returns to what it was, nothing leaks.  Test: the ownership scan in `textchurn` after a forced failure (Task 5).
4. **A fork child that execs or exits** -- the parent's text keeps its count; the child's reference goes.  Test: `textchurn` (Task 5).
5. **A program on a ProDOS mount** -- runs as before and is not cached.  Test: `pdmount`'s existing run of a ProDOS-hosted binary still passes (Task 6 runs every manifest), and `textshare`'s checker counts no text for it.

---

### Task 1: The probes, RED

**Files:**
- Create: `tools/mame_test/tests/textshare.json`, `tools/mame_test/textshare_check.py`, `disk_src/testdata/textshare`

**Interfaces:**
- Consumes: the task table (`addr_equ FGX_TASK_TBL`, `kbank: true`, 2048 bytes, 64 bytes per slot, pid = slot + 1; `TCB_TaskID` +0, `TCB_CodeBank` +20, `TCB_BankList` +54..+61 -- offsets from `include/kernel.s:651-711`).
- Produces: `textshare_check.py`, which Task 6 turns GREEN.

- [ ] **Step 1: Write the script**

`disk_src/testdata/textshare`:

```sh
# Two spawned instances of one program, and a different program beside them.
/bin/sleep 60 &
A=$!
/bin/sleep 60 &
B=$!
/bin/sleep 60 &
echo TS A=$A B=$B
echo TS SH=$$
```

- [ ] **Step 2: Write the manifest**

`tools/mame_test/tests/textshare.json` (one line per key as other manifests are; the description says what each needle proves):

```json
{
 "name": "textshare",
 "description": "SHARED TEXT: two spawned instances of /bin/sleep run from ONE code bank, and the shell, a different program, from another.  A fork child shares its parent's code bank already, so the instances are SPAWNED (sh runs each with its own fork+exec); the checker reads TCB_CodeBank for the two pids the script prints and for the shell.  RED before the text table: each spawn loads its own code bank.",
 "command": "sh /testdata/textshare",
 "timeout_s": 90,
 "memory_regions": [{"name": "tcbs", "addr_equ": "FGX_TASK_TBL", "kbank": true, "len": 2048}],
 "expect": {"screen_contains": ["TS A=", "TS SH="], "screen_lacks": ["PANIC", "BRK"], "check_script": "textshare_check.py"}
}
```

- [ ] **Step 3: Write the checker**

`tools/mame_test/textshare_check.py` (the `forkcost_check.py` shape: read `dump.json`, exit 0 pass / 1 fail / 2 inconclusive):

```python
#!/usr/bin/env python3
"""textshare_check -- two spawned sleeps share one code bank; the shell's differs.

Reads the pids the script printed (`TS A=<a> B=<b>`, `TS SH=<s>`) from the
screen text and TCB_CodeBank (+20) for each from the task table (64-byte
slots, pid = slot + 1).  Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import re
import sys

TCB = 64
CODEBANK = 20


def screen_text(d):
    sa = d.get("screen_analysis", {})
    rows = [v for k, v in sorted(sa.items()) if k.startswith("text_row_")]
    return "\n".join(rows) if rows else d.get("screen", "")


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = d.get("memory", {}).get("tcbs")
    text = screen_text(d)
    a = re.search(r"TS A=(\d+) B=(\d+)", text)
    s = re.search(r"TS SH=(\d+)", text)
    if not r or not r.get("hex") or not a or not s:
        print("textshare: no task table or no pids on the screen")
        return 2
    t = binascii.unhexlify(r["hex"])

    def bank(pid):
        return t[(pid - 1) * TCB + CODEBANK]

    pa, pb, ps = int(a.group(1)), int(a.group(2)), int(s.group(1))
    ba, bb, bs = bank(pa), bank(pb), bank(ps)
    print(f"textshare: sleep {pa} ${ba:02X}, sleep {pb} ${bb:02X}, sh {ps} ${bs:02X}")
    if ba == 0 or bb == 0 or bs == 0:
        print("textshare: a pid has no code bank -- not running?")
        return 2
    if ba != bb:
        print("textshare: FAIL -- the two sleeps have different code banks")
        return 1
    if ba == bs:
        print("textshare: FAIL -- sh shares sleep's code bank (control)")
        return 1
    print("textshare: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
```

Before relying on `screen_text`, read one existing `dump.json` (`/tmp/fgx_test_*/dump.json`) and confirm where the screen text lives (`screen_analysis` rows, or the `screen text:` block of `dump.txt`); adjust the function to the real key.

- [ ] **Step 4: Run it -- RED**

Announce, then: `python3 tools/ninja/gen.py && ninja && python3 tools/mame_test/run.py --fresh textshare`
Expected: FAIL with "the two sleeps have different code banks" (each spawn loads its own code bank today).  If it says PASS, the probe is wrong: stop and fix the probe.

- [ ] **Step 5: Commit**

```bash
git add tools/mame_test/tests/textshare.json tools/mame_test/textshare_check.py disk_src/testdata/textshare
git commit   # "test(text): textshare -- two spawned instances should share one code bank"
```

---

### Task 2: The text key from the descriptor

**Files:**
- Modify: `src/kernel/vfs/vfs_syscalls.c` (beside `ld_exec_sugid`, about line 1532), `src/kernel/far/loader.s` (a `_Ld_TextKey` frame beside `_Ld_ExecCheck` at about :465, and a call right after the existing `_Ld_ExecCheck` call at about :552-569)

**Interfaces:**
- Consumes: `getf()`, `vnops`, `vn_getattr()` (`vfs_syscalls.c:87`), `struct vattr` (`va_fsid` long, `va_fileid` long, `va_ctime` time_t -- `vnode.h:374-380`).
- Produces: `int ld_text_key(int fd)` -- 1 and the key filled in `ld_tkey` when the descriptor has a vnode, 0 when it does not (legacy fd), -1 on a getattr error.  `struct ld_tkey { long fsid; long fileid; long ctime; }` as a far-bank static `ld_tkey` (12 bytes), read by the loader through a 24-bit pointer.  Loader cells `_ldTextKeyOk` (1 byte: 1 = cacheable) and `_ldTextKey` (12 bytes, copied from `ld_tkey`).

- [ ] **Step 1: Measure the far bank**

Run `python3 tools/check_kernel_ceiling.py` and record the far bank's free bytes (187 expected).  If Step 3's code does not fit, move a cold far-bank routine out first, as `loader.s` once left the core: name it in the commit.  Do not shrink anything to make room by deleting checks.

- [ ] **Step 2: Write the C helper**

In `vfs_syscalls.c`, after `ld_exec_sugid`:

```c
/* ld_text_key -- the identity of the file behind this descriptor, for the
 * shared-text table: its device, inode number and change time.  ctime moves
 * on every write, truncate, chmod and link change, so a file rewritten or
 * replaced never matches the text loaded from it before.  A legacy
 * descriptor has no vnode and is not cached (0). */
struct ld_tkey {
    long fsid;
    long fileid;
    long ctime;
} ld_tkey;

int
ld_text_key(fd)
int fd;
{
    struct file *fp;
    struct vattr va;

    fp = getf(kc_curpid(), fd);
    if (fp == (struct file *)0 || fp->f_ops != &vnops)
        return (0);
    if (vn_getattr((struct vnode *)fp->f_data, &va))
        return (-1);
    ld_tkey.fsid = va.va_fsid;
    ld_tkey.fileid = va.va_fileid;
    ld_tkey.ctime = va.va_ctime;
    return (1);
}
```

Check `vn_getattr`'s real signature at its definition in vfs.mod (`grep -n "^vn_getattr" src/kernel/vfs/*.c`) and the far-bank import shim for it in `src/kernel/far/vfs_import.s`; match both.  `struct vattr` on the kernel C stack: confirm the size against an existing far-bank caller of `vn_getattr` (the L_XTND path at `vfs_syscalls.c:1375`) and do as it does.

- [ ] **Step 3: Write the loader frame and call**

Copy `_Ld_ExecCheck`'s frame (loader.s about :465: same-bank `PHK`/`PEA ret-1`/`JMP` into the C, `D = FGX_DP_KERNELC`, the fd pushed as one word) as `_Ld_TextKey`, calling `ld_text_key`.  After `_Ld_ExecCheck` in the open path (about :552-569), call `_Ld_TextKey`; on a return of 1 copy the 12 bytes of `ld_tkey` to `_ldTextKey` and set `_ldTextKeyOk` = 1, otherwise 0.  `_ldTextKeyOk` is zeroed at the top of `Load_Binary` with the other per-load cells (where `_ldDataSegIdx` is zeroed, about :540).

- [ ] **Step 4: Build and boot**

Announce, then `ninja` and `python3 tools/mame_test/run.py --fresh ufsboot smoke catsmoke`.
Expected: 3 passed (the key is captured and not yet used).  Record the far bank's free bytes.

- [ ] **Step 5: Commit**

`feat(loader): the loader records the executable's device, inode and change time` -- the body names Reno's `vn_stat` (`kern/vfs_vnops.c`) as the source of the getattr shape and states the far bank's free bytes before and after.

---

### Task 3: The text table

**Files:**
- Create: `src/kernel/tty/text.s` (PUT from the tty bank's root, `src/kernel/tty/ttybank.s` -- check the name with `grep -n "PUT" src/kernel/tty/*.s | head`), slots in the tty bank's slot table and in `include/ktty.s`
- Modify: `include/ktty.s` (`KTTY_TEXT_FIND` 56, `KTTY_TEXT_REG` 57, `KTTY_TEXT_REF` 58, `KTTY_TEXT_UNREF` 59, `KTTY_TEXT_RECLAIM` 60), `tools/gen_kernel_exports.py` if it lists slots, the patch tables the kernel checks name

**Interfaces:**
- Consumes: `Bank_Free` (core, through the tty bank's existing core-call route -- `grep -n "JSL.*Bank_Free\|_KTty.*Bank" src/kernel/tty/*.s` for the pattern), `_libcShTab` refcount (`include/memmap.s:438-447`: `LIBCSH_REF` +1, 1 byte).
- Produces, all called with JSL to the slot, `MX %00`, DBR = core bank on entry (as the existing KTTY slots are; read one -- `KTTY_KC_TTSELECT` -- for the exact entry contract and copy it):
  - `KTTY_TEXT_FIND`: in `_ldTextKey` (12 bytes, read through a 24-bit pointer the caller passes in A/X -- or a fixed far-bank cell; choose one and state it in the slot's header); out C=1 + A = text index (1..NTEXT) and the entry's `x_count` incremented, or C=0 (miss).
  - `KTTY_TEXT_REG`: in A = text index 0 (new) with the key at the same place, X = pointer to an 8-byte bank list (0 = not a text segment), Y.lo = the libc pile bank (0 = none); out C=1 + A = index with `x_count` = 1 and the pile's refcount incremented once for the text; C=0 when the table is full (the caller then keeps the banks as owned, uncached).
  - `KTTY_TEXT_REF`: in A = index; `x_count++`.
  - `KTTY_TEXT_UNREF`: in A = index (0 = no-op); `x_count--`; at 0 the text stays cached (it is the LRU tail).
  - `KTTY_TEXT_RECLAIM`: frees one cached text with `x_count` 0 -- its banks (`Bank_Free` each) and its pile reference (refcount decrement) -- and returns C=1; C=0 when none.  Oldest first (a 16-bit use stamp per entry, set at FIND/REG).
  - Per-pid array `_kTextOf` (NPROC bytes, in the tty bank's statics; exported cell for the core's LDAL): the text index each pid uses, 0 = none.

- [ ] **Step 1: Read BSD**

Read `vendor/2.11BSD/usr/sys/h/text.h:18-29` and `sys/vm_text.c` `xalloc` (:139-200), `xfree` (:87-120), `xuntext` (:344-360), `xuncore` (:367-390).  The entry below is `struct text` without the swap fields (`x_daddr`, `x_caddr`: FGX has no swap and the banks are the core address).  Quote `xfree`'s "all text under 2.10 is sticky in an LRU cache" in the commit.

- [ ] **Step 2: Write the table and the five routines**

`NTEXT EQU 16`; an entry (24 bytes, a DUM block in `text.s`):

```
TX_KEY      DS 12   ; va_fsid, va_fileid, va_ctime (0 fsid+fileid = free)
TX_BANKS    DS 8    ; bank per segment index; 0 = not a text segment
TX_PILE     DS 1    ; libc pile bank the code was relocated against, or 0
TX_COUNT    DS 1    ; x_count: processes using it
TX_STAMP    DS 2    ; use stamp for reclaim order
```

Write the five routines with explicit `MX` at each label; a free entry is one whose fsid and fileid are both zero (a real file never has inode 0 on UFS).  `KTTY_TEXT_RECLAIM` clears the entry after freeing.  The pile refcount decrement in reclaim mirrors `_LibcSh_Reclaim`'s slot handling (`bank.s:190-230`): find the slot by bank (`_LibcSh_Slot`, `process.s:1261`), decrement, and leave the bank's freeing to `_LibcSh_Reclaim` when it reaches 0.

- [ ] **Step 3: Wire the slots**

Add the five slots (56-60) to the tty bank's slot table and `include/ktty.s`, regenerate the tty patch tables with the commands `ninja`'s kernel checks print, and confirm `check_ntty`, `check_far_calls` and `gen_far_bankpatch --check` are clean.

- [ ] **Step 4: Build and boot**

Announce; `ninja`; `python3 tools/mame_test/run.py --fresh ufsboot smoke catsmoke`.  Expected: 3 passed (nothing calls the slots yet).  Record the tty bank's free bytes.

- [ ] **Step 5: Commit**

`feat(kernel): a shared-text table in the tty bank` -- names `struct text` (`h/text.h`) and `xalloc`/`xfree`/`xuncore` (`sys/vm_text.c`), states which fields were dropped and why, and the tty bank's free bytes.

---

### Task 4: The loader shares text

**Files:**
- Modify: `src/kernel/far/loader.s` (`_LoadFGX2` Steps F3-F7 at :947-1300, `_BankForSeg` and `_FreeExtras` at about :1690-1730, the reloc pass at :1315-1410, `_Loader_StageArgs`'s data-bank read at :1969-1984), `include/kfar.s` (`KFAR_LD_EXTRABANKS` becomes `KFAR_LD_SEGBANKS`, 8 bytes, and `KFAR_LD_TEXT`, 1 byte; update the `ERR` checks in `far.s`), `src/kernel/process.s` (spawn :200-216, exec :2958-2975), `src/kernel/main.s` (:960-987), two core `_FarSh_*` shims for `KTTY_TEXT_FIND`/`KTTY_TEXT_REG` (in `src/kernel/far_shims.s`)

**Interfaces:**
- Consumes: Task 2's `_ldTextKeyOk`/`_ldTextKey`; Task 3's slots.
- Produces: after `Load_Binary`, `KFAR_LD_SEGBANKS[0..7]` = the bank each segment is in that the PROCESS owns (the data segment's slot holds the override bank; a text segment's slot holds 0; a pile slot holds 0 as today), and `KFAR_LD_TEXT` = the text index the load took a reference on (0 = uncached).  `_ldSegBank[0..7]` (loader-private) = every segment's bank, text or owned, for `_BankForSeg`.

- [ ] **Step 1: Segment banks as a table**

Replace `_ldExtraBanks` with `_ldSegBank` (8 bytes, segment-indexed).  `_BankForSeg` becomes `LDA _ldSegBank,X` for X = segment (bounds-checked as now).  The data segment (`_ldDataSegIdx`) is loaded into `_ldOverrideBank`; every other non-pile segment into a bank from `Bank_Alloc` (miss) or from the text (hit).  The entry bank (`_ldUserBank`, used for `_ldEntry`, :1411-1418) becomes `_ldSegBank[0]` -- segment 0 is CODE in every program (`fgx_ld.py` manifests; refuse a binary whose segment 0 is not CODE with ENOEXEC, which no shipped binary is).  `_FreeExtras` frees only the banks this load allocated (a per-load mask, `_ldOwnMask`, bit i = segment i's bank came from `Bank_Alloc` here), never the override and never a text's banks.

- [ ] **Step 2: The hit path**

After Step F5 reads the segment table, if `_ldTextKeyOk`: call the `KTTY_TEXT_FIND` shim.  On a hit, fill `_ldSegBank` from the entry's `TX_BANKS` for the text segments; for each text segment, skip its file bytes with `Fs_Lseek(fd, SEEK_CUR, size)` as the pile hit does (`loader.s:1127-1143`) instead of loading it; load the data segment into the override bank; in the reloc pass apply only entries whose SOURCE segment is the data segment (a text segment's patches are already in its shared banks), with targets resolved through `_ldSegBank` as now.  The libc pile path is unchanged: the same binary has the same pile key, and the text holds a pile reference, so the registry maps the same bank.

- [ ] **Step 3: The miss path**

Load as today but with code segments into fresh banks (`_ldOwnMask`), then, after the reloc pass and only if `_ldTextKeyOk`: call the `KTTY_TEXT_REG` shim with `_ldSegBank` masked to the text segments and the pile bank (`_libcShLast` when a pile segment was loaded, else 0).  On success the text segments' banks now belong to the text: clear their bits in `_ldOwnMask` and their slots in the published `KFAR_LD_SEGBANKS`.  On a full table keep them owned (uncached) and publish them in `KFAR_LD_SEGBANKS` as today.  Publish `KFAR_LD_TEXT` (0 when uncached).

- [ ] **Step 4: The callers**

Spawn (`process.s:200-216`) and exec (`:2958-2975`) copy `KFAR_LD_SEGBANKS[0..7]` into `TCB_BankList[0..7]` (all eight, replacing "override in [0], extras in [1..7]"), set `TCB_CodeBank` = the entry bank (`KFAR_LD_*` output for `_ldSegBank[0]`, add a 1-byte `KFAR_LD_CODEBANK`), `TCB_DataBank` = the override, and store `KFAR_LD_TEXT` in `_kTextOf[pid-1]` (LDAL/STAL through the tty bank's exported cell).  Init's boot load (`main.s:960-987`) does the same.  `_Loader_StageArgs` (:1969-1984) reads `TCB_BankList[_ldDataSegIdx]`, which is the override now -- unchanged, and correct.

- [ ] **Step 5: Build, boot, and textshare GREEN**

Announce; `ninja`; `python3 tools/mame_test/run.py --fresh textshare ufsboot smoke catsmoke wuptime`.
Expected: textshare PASS (same bank for the two sleeps, sh different); the rest pass.  Record core/far/tty free bytes.

- [ ] **Step 6: Commit**

`feat(loader): a program's code banks are loaded once and shared` -- names `xalloc` (`sys/vm_text.c:139`), states Rulings 1, 2, 5, the core/far/tty bytes, and textshare RED->GREEN.

---

### Task 5: Fork, exit, exec, reclaim -- and the probes that prove them

**Files:**
- Modify: `src/kernel/process.s` (fork's TCB copy at :759-761; exec commit :3128-3165 and failure :3288-3330), `src/kernel/task.s` (`_Task_FreeBanks`, :283-345), `src/kernel/bank.s` (`Bank_Alloc`'s pool-dry path, :146-157)
- Create: `tools/mame_test/tests/textfresh.json` + `disk_src/testdata/textfresh`, `tools/mame_test/tests/textreclaim.json` + `disk_src/testdata/textreclaim`, `tools/mame_test/tests/textchurn.json` + `tools/mame_test/textchurn_check.py` + `disk_src/testdata/textchurn`

**Interfaces:**
- Consumes: Task 3's slots; Task 4's `_kTextOf`.
- Produces: balanced references on every path of the spec's 5.3 table.

- [ ] **Step 1: Write textfresh (RED or not, it must discriminate)**

`disk_src/testdata/textfresh`:

```sh
cp /bin/echo /tmp/tf
/tmp/tf TF FIRST
cp /bin/pwd /tmp/tf
cd /etc
/tmp/tf
echo TF DONE
```

Manifest needles: `screen_contains` `TF FIRST`, `/etc`, `TF DONE`; `screen_lacks` `PANIC`.  `cp` writes /tmp/tf in place (same inode), so a cache keyed by inode alone would run echo again and print an empty line instead of `/etc`.  Discrimination check before Task 5's code: temporarily build the text key without `ctime` (one-line change in Task 2's helper), run `textfresh`, confirm it FAILS, restore, confirm it passes.  Record both runs in the commit.

- [ ] **Step 2: Write textchurn and its checker**

`disk_src/testdata/textchurn` runs, in order: ten `/bin/true` in a loop; a background `/bin/sleep 5 &` and `wait`-free pause (`/bin/sleep 8`); a fork child that execs (`sh -c /bin/true`); an exec that fails for want of a file (`exec /nonexistent` in a subshell: `( exec /nonexistent ) 2>/dev/null`); then `echo TC DONE`.  The manifest dumps the task table, `BankBitmap` (7 bytes), `_kUserFirstBank`, `_libcShTab` (128), `_kVcBank` (8), `_kHomeBank` (2), `_uiPoolBank` (4), `_modBankTab` (7), and the text table and `_kTextOf` (symbols from Task 3).  `textchurn_check.py` passes when (a) every used pool bank has an owner -- a task's `TCB_BankList`, `SE_SoftBank` (SE table through `CFG_DP_KKERN+A4`, +$1F per 32-byte slot), a libc pile, a text's `TX_BANKS`, a screen, the home or swap banks, or a module -- and (b) every text's `TX_COUNT` equals the number of pids whose `_kTextOf` names it.  This is the ownership scan run by hand on 2026-10-03 (`docs/history/plans/2026-10-03-coremap-shared-text-design.md` section 2); copy its decoding.

- [ ] **Step 3: Run textchurn -- RED**

Announce; `python3 tools/ninja/gen.py && ninja && python3 tools/mame_test/run.py --fresh textchurn`.  Expected: FAIL on (b) (Task 4 takes references at load but nothing drops them, so counts exceed live pids), or on (a) if a path leaks.

- [ ] **Step 4: Fork, exit, exec**

- fork (`process.s:759-761`, where the child copies `TCB_CodeBank`): copy `_kTextOf[parent]` to `_kTextOf[child]` and call `KTTY_TEXT_REF` (2.11BSD `newproc` keeps `p_textp` and counts it -- read `sys/kern_fork.c` and quote the line).
- exit (`_Task_FreeBanks`, `task.s:283`): before the list walk, `KTTY_TEXT_UNREF` with `_kTextOf[pid]` and zero it.  This covers spawn failure, exit and the snapshot child, which all call `_Task_FreeBanks` (spec 5.3 table).
- exec commit (`process.s:3128-3165`): drop the OLD text (`KTTY_TEXT_UNREF` with the saved old `_kTextOf`, saved beside `_ev_oldBankList` at :2915-2922), then store the new one.  Exec failure (`:3288-3330`): drop the NEW reference the load took (`KFAR_LD_TEXT`) and restore the old `_kTextOf`.
- `Img_HandOff` (`process.s:2148-2200`) needs no change: code banks are no longer in `TCB_BankList`.  Confirm by reading it and say so in the commit.

- [ ] **Step 5: Reclaim**

In `Bank_Alloc`'s pool-dry path (`bank.s:146-157`), before `_LibcSh_Reclaim`: call `KTTY_TEXT_RECLAIM`; on C=1 rescan the bitmap (as the pile reclaim does).  2.11BSD `malloc(coremap)` -> `xuncore()` (`sys/vm_text.c:367`).

- [ ] **Step 6: Write textreclaim**

`disk_src/testdata/textreclaim`: run each of about 25 distinct small programs once (`/bin/true`, `/bin/echo x`, `/bin/pwd`, `/bin/date`, `/bin/hostname`, ... -- 25 that exit at once; list them from `disk_src/bin`), leaving 25 cached texts, then the manyproc spawn of 22 `/bin/sleep 25 &`, then `echo TR=done`.  Needles: `TR=done`; lacks `too big`.  Before Step 5 it must FAIL with `too big` (cached texts hold banks nothing frees); after, pass.  Run it before and after and record both.

- [ ] **Step 7: Run all three GREEN, plus manyproc**

Announce; `ninja`; `python3 tools/mame_test/run.py --fresh textshare textfresh textchurn textreclaim manyproc initthrottle wuptime ufsfork`.  Expected: all pass.  Add to manyproc's description (not its needles) the measured bank count with 22 sleeps, read from a `blkcount`/bitmap dump.

- [ ] **Step 8: Commit**

Two commits: the lifecycle (Step 4 + 5, naming `kern_fork.c` and `vm_text.c` `xfree`/`xuncore`), and the probes (textfresh, textchurn, textreclaim with their RED evidence).

---

### Task 6: Gate, every manifest, measurements, the spec

**Files:**
- Modify: `docs/history/plans/2026-10-03-coremap-shared-text-design.md` (sections 5 and 9: the six rulings; "A2 not done" and why), `docs/ROADMAP.md` (one paragraph: phase A done, what it saves, phase B next)

- [ ] **Step 1: Gate**

Announce; `tools/gate.sh > $S/gate.log 2>&1; tail -3 $S/gate.log`.  Expected: GATE GREEN.

- [ ] **Step 2: Every manifest**

Run the Global Constraints' every-manifest command.  Expected: everything passes; any failure is either fixed (its own commit, systematic-debugging) or shown to fail identically on main.

- [ ] **Step 3: Measure**

With the measurement manifests used on 2026-10-03 (the `kacct` ownership dump and the `vm` vmstat check, re-created under `$S`): idle pool use (46 of 56 before), Memory Manager FREE at idle (2,847 KB before), and banks held with 21 sleeps (42 for their images before).  Record in the spec's section 2.1 table and the ROADMAP paragraph.

- [ ] **Step 4: Commit**

`docs(spec): shared text as built -- six rulings and the measurements`.

## Self-review notes

- Spec 5.1-5.3 (what is shared, the table, lifecycle) -> Tasks 3-5; 5.4 (binder) is the shared-libc merge, Ruling 6; A2 -> Ruling 3 (confirmed); 8's texshare/manyproc/ownership-scan -> Tasks 1, 5; textbusy is dropped with A2.
- Names used across tasks: `_ldTextKey`, `_ldTextKeyOk`, `ld_text_key`, `ld_tkey`, `KTTY_TEXT_FIND/REG/REF/UNREF/RECLAIM`, `_kTextOf`, `_ldSegBank`, `_ldOwnMask`, `KFAR_LD_SEGBANKS`, `KFAR_LD_TEXT`, `KFAR_LD_CODEBANK`.
