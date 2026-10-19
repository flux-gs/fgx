# Slice A: boot + tty blockers -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/etc` able to hold arbitrary files, and make `ttyname(fd)` report the
real tty, so the BSD login stack (slice C) and virtual consoles (slice D) have
somewhere to put their config and a way to name a line.

**Architecture:** Two independent fixes. (1) `src/boot/stage2.s`'s `find_in_dir`
scans only a directory's first ProDOS block; teach `walk_path` to follow the
`next_block` chain, with a back-pointer validation and a hop cap. (2) `ttyname()`
is a stub returning `"/dev/tty"` for everything; add one `FIODGNAME` op to the
kernel's existing tty ioctl dispatch and have libc call it. Neither fix depends on
the other; they share this plan only because both are prerequisites for slice C.

**Tech Stack:** Merlin32 65816 assembly (kernel, boot), K&R C compiled by `fcc`
(libc, userland), ninja build, MAME headless harness.

Scope source: `docs/history/plans/2026-07-31-bsd-login-stack-scope.md` sec 3.

## Global Constraints

- **ASCII only in anything that ships to disk.** `disk_src/**` text, man pages, and
  any string a userland tool prints. No em-dash, curly quotes, ellipsis, or arrows.
  The FGX console font has no glyphs and they render as garbage. Host-only files
  (this plan, `docs/history/**`) are exempt.
- **Feature branch only, never commit to `main`.** Work lands on
  `feat/bsd-login-stack`. Do not push; work is held local per standing practice.
- **Stage specific files in `git add`**, never `git add -A` or `git add .`.
- **Merlin32 MX discipline.** Every routine documents its entry/exit M and X width.
  `tools/check_mx.py` runs as a build edge and fails the build on leaks. When you
  change register widths, update the `MX` pseudo-op so the assembler's tracking
  matches the real runtime state.
- **The kernel bank is at its ceiling.** Code room is `FGX_DATA - ORG`; every byte
  of static data added to the kernel bank costs a byte of code room. Task 2 has an
  explicit headroom check and a fallback.
- **Toolchain-first.** If `fcc` or libc lacks something, fix it in `toolchain/`,
  add a regression fixture, and keep goldens green. Never work around it with a
  per-tool stub or a local reimplementation of a standard function.
- **Do not run `git commit` with a heredoc body containing non-ASCII.**

## Build and test commands

```bash
# Full build (regenerates build.ninja first if manifests changed)
python3 tools/ninja/gen.py && ninja all

# The gate: build + boot smoke test (boot -> prompt -> ls). ~33 s.
tools/gate.sh

# The smoke test alone, once the image is built
python3 tools/mame_test/run.py --headless --no-state --fresh smoke
```

`tools/gate.sh` also runs the kernel source checks (MX leaks, baked addresses,
provenance, syscall-table drift, W5100 patch-site drift) as build edges, and fcc's
544 fixture goldens when `toolchain/` changed.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `src/boot/stage2.s` | `find_in_dir` scan window becomes a parameter; new `next_dir_block` helper; `walk_path` scan loop | 1 |
| `disk_src/etc/passwd` | The staged file that both proves the fix and gives slice C its database | 1 |
| `toolchain/include/sys/ioctl.h` | `FIODGNAME` number + `FIODGNAME_MAX` | 2 |
| `src/kernel/syscall.s` | `FIODGNAME` dispatch entry + `@si_dgname` handler | 2 |
| `src/kernel/signal.s` | `_ttyNames` table beside `_ttyTable` | 2 |
| `toolchain/lib/libc_c/libc_c.c` | `ttyname()` rewrite | 3 |
| `src/userland/ttytest/ttytest.c` | Test that a pty slave names itself, not the console | 3 |

---

## Task 1: stage 2 follows the ProDOS directory chain

**Files:**
- Modify: `src/boot/stage2.s:490-493` (the `find_in_dir` call site in `walk_path`)
- Modify: `src/boot/stage2.s:574-581` (`find_in_dir` scan-window init)
- Modify: `src/boot/stage2.s:625-630` (the static-byte block after `_fid_entChar`)
- Create: `disk_src/etc/passwd`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a `/etc` that can hold arbitrary files. Slice C relies on this to stage
  `/etc/ttys`, `/etc/group`, `/etc/issue`. No callable interface.

### Background the implementer needs

A ProDOS directory block is 512 bytes: `prev_block` at offset 0-1, `next_block` at
offset 2-3, then 13 entries of 39 bytes each starting at offset 4 (4 + 13*39 = 511,
one spare byte). The **key block** spends entry 0 on the volume/subdir header, so it
holds 12 files; **continuation blocks** have no header and hold all 13.

That is why `find_in_dir` currently starts at `DIR_FIRST_OFF` (43 = 4 + 39) with
`ZP_SPCNT` = 1 and loops while `ZP_SPCNT < DIR_ENTRIES` (13): twelve slots. It then
returns C=0, and `walk_path` treats that as fatal.

Stage 2 looks up `ETC/PRELOAD.CONF` and `ETC/BOOT.CONF`. `/etc` already spans two
blocks with `PRELOAD.CONF` in the last slot stage 2 can see. Any file staged before
it in the directory pushes it into block 2, the PRODOS FST never pre-stages, and the
kernel comes up with no FS dispatch -- **before any console exists**, so the symptom
is a black screen with no diagnostic. Probe `PRESTAGED_ABS` (`$00:1FE8`): all zeros
means no module staged.

`BlkRead` (`stage2.s:1800`) is `MX %11` (8-bit A and X/Y), reads the block named by
`SPBlk` into the buffer named by `SPBuf`, and returns **C=0 on success, C=1 on
error**. It **clobbers zero page `$5B/$5C`** (`ZP_PATH_LO`/`ZP_PATH_HI`), which is
why `walk_path` stashes them to `_path_save_lo`/`_path_save_hi` around the call.
Any new `BlkRead` call must do the same, because `find_in_dir` compares against
`(ZP_PATH_LO),Y`.

`walk_path` runs in `MX %11` (inherited from `LoadDispatch MX %11` at line 377).
Zero page `$50-$5F` is stage 2's while running, and `$60-$65` belongs to the conf
parser that runs later -- but rather than take more ZP, this task uses absolute
static bytes in the existing `_fid_entChar` block, matching local style.

`ZP_DIR_BLK_LO/HI` is safe to use as the scan cursor: after `find_in_dir` succeeds,
`@wp_descend` overwrites it from the entry's `key_ptr` and `@wp_leaf` never reads it.

- [ ] **Step 1: Establish the negative control -- prove the bug is real on this tree**

This must come first. Without it, a passing boot after the fix proves nothing,
because the probe file could simply have landed in block 1.

Create `disk_src/etc/passwd` with exactly this content (ASCII only, note the
comment lines are an FGX tolerance the libc parser already honors):

```
# name:passwd:uid:gid:gecos:dir:shell
root:*:0:0:Charlie Root:/root:/bin/sh
```

Then build and boot:

```bash
python3 tools/ninja/gen.py && ninja all
python3 tools/mame_test/run.py --headless --no-state --fresh smoke
```

Expected: **FAIL.** A black screen / no prompt / smoke timeout. This is the
2026-07-26 breakage reproduced deliberately.

If it *passes*, STOP and report. It means `passwd` landed inside block 1 on this
tree and the probe is not exercising the bug. Do not proceed on a green negative
control -- pick a name that sorts earlier (the directory fills in staging order;
check what `_populate` emits) and re-run until you observe the failure.

- [ ] **Step 2: Make the scan window a parameter of `find_in_dir`**

`find_in_dir` has exactly one caller (`stage2.s:490`), so this is safe.

Replace lines 574-581, which currently read:

```
find_in_dir
                LDA     #DIR_FIRST_OFF          ; $2B = lo byte of $0C2B
                STA     ZP_ENT_LO
                LDA     #>DIR_BUF
                STA     ZP_ENT_HI
                LDA     #1
                STA     ZP_SPCNT
```

with:

```
find_in_dir
                ; Scan window is set by the caller: ZP_ENT_LO/HI = first entry
                ; to test, ZP_SPCNT = its slot number.  Key blocks start at
                ; slot 1 / DIR_FIRST_OFF (slot 0 is the vol/subdir header);
                ; continuation blocks have no header, so they start at slot 0 /
                ; offset 4 and yield all 13 entries.
```

Also update the header comment at lines 562-573 -- delete the line
`; Single-block scan only -- multi-block dirs (>13 entries) not handled.` and add
the scan-window inputs to the `Input:` block.

- [ ] **Step 3: Add the `next_dir_block` helper and its statics**

Insert `next_dir_block` immediately after `find_in_dir`'s `JMP @fid_slotL` (line
624), before the `_fid_entChar` static block:

```
;==============================================================================
; next_dir_block - follow the current directory's next_block link and read the
; successor into DIR_BUF, leaving find_in_dir's scan window set for a
; CONTINUATION block (no header entry: slot 0 at offset 4, 13 usable slots).
;
; Input:  DIR_BUF holds the block just scanned.
;         ZP_DIR_BLK_LO/HI = its block number.
;         _fid_hops = remaining hops (decremented here).
; Output: C=1 + DIR_BUF holds the next block, ZP_DIR_BLK_LO/HI updated,
;              ZP_ENT_LO/HI + ZP_SPCNT set to the continuation window.
;         C=0 = chain exhausted, hop cap reached, I/O error, or the successor
;              failed back-pointer validation.  Caller must treat as not-found.
;
; VALIDATION: a probe during the reverted 2026-07-26 attempt showed DIR_BUF can
; hold non-directory bytes on some scan-failure path, so the successor must
; point BACK at the block we came from before we trust its entries.  The hop cap
; is belt-and-braces: a corrupt pair of mutually-referencing blocks would
; otherwise satisfy the back-pointer check forever.
;
; Preserves nothing but the ZP the caller needs; saves/restores ZP_PATH_LO/HI
; across BlkRead exactly as walk_path does (SmartPort firmware clobbers $5B/$5C).
; MX %11 in/out.
;==============================================================================
next_dir_block  MX      %11
                ; --- Hop cap.
                DEC     _fid_hops
                BNE     @ndb_hopsOK
                CLC
                RTS
@ndb_hopsOK
                ; --- next_block == 0 means end of chain.
                LDA     DIR_BUF+2
                STA     _fid_nextLo
                LDA     DIR_BUF+3
                STA     _fid_nextHi
                ORA     _fid_nextLo
                BNE     @ndb_haveNext
                CLC
                RTS
@ndb_haveNext
                ; --- Remember the block we came from, for validation.
                LDA     ZP_DIR_BLK_LO
                STA     _fid_fromLo
                LDA     ZP_DIR_BLK_HI
                STA     _fid_fromHi

                ; --- Read the successor into DIR_BUF.
                LDA     _fid_nextLo
                STA     ZP_DIR_BLK_LO
                STA     SPBlk
                LDA     _fid_nextHi
                STA     ZP_DIR_BLK_HI
                STA     SPBlk+1
                LDA     #0
                STA     SPBlk+2
                LDA     #<DIR_BUF
                STA     SPBuf
                LDA     #>DIR_BUF
                STA     SPBuf+1
                ; SmartPort firmware clobbers ZP $5B/$5C (ZP_PATH_LO/HI), which
                ; find_in_dir compares against -- stash and restore, as
                ; @wp_compLoop does around its own BlkRead.
                LDA     ZP_PATH_LO
                STA     _path_save_lo
                LDA     ZP_PATH_HI
                STA     _path_save_hi
                JSR     BlkRead
                PHP                             ; preserve C across the restore
                LDA     _path_save_lo
                STA     ZP_PATH_LO
                LDA     _path_save_hi
                STA     ZP_PATH_HI
                PLP
                BCC     @ndb_readOK
                CLC                             ; I/O error -> not found
                RTS
@ndb_readOK
                ; --- Validate: successor's prev_block must be where we came from.
                LDA     DIR_BUF+0
                CMP     _fid_fromLo
                BNE     @ndb_bad
                LDA     DIR_BUF+1
                CMP     _fid_fromHi
                BNE     @ndb_bad

                ; --- Continuation window: slot 0 at DIR_BUF+4, all 13 usable.
                LDA     #4
                STA     ZP_ENT_LO
                LDA     #>DIR_BUF
                STA     ZP_ENT_HI
                LDA     #0
                STA     ZP_SPCNT
                SEC
                RTS
@ndb_bad        CLC
                RTS
```

Then extend the static block at line 625. It currently begins:

```
_fid_entChar    DFB     $00                     ; 1-byte stash for compare
```

Add immediately after that line:

```
_fid_hops       DFB     $00                     ; remaining next_block hops
_fid_nextLo     DFB     $00                     ; successor block number
_fid_nextHi     DFB     $00
_fid_fromLo     DFB     $00                     ; block we came from (validation)
_fid_fromHi     DFB     $00
```

- [ ] **Step 4: Turn the `walk_path` call site into a scan loop**

Replace lines 488-493, which currently read:

```
                ; Find component in DIR_BUF.  ZP_NAME_LEN set; component
                ; chars at (ZP_PATH_LO),0..ZP_NAME_LEN-1.
                JSR     find_in_dir
                BCS     @wp_found
                CLC
                RTS
```

with:

```
                ; Find component in DIR_BUF.  ZP_NAME_LEN set; component
                ; chars at (ZP_PATH_LO),0..ZP_NAME_LEN-1.
                ;
                ; The directory may span several blocks.  Scan the key block's
                ; 12 slots, then chase next_block for as long as the chain
                ; holds, scanning 13 slots per continuation block.  Real ProDOS
                ; chases this chain (Beneath Apple ProDOS p.25); stage 2 used
                ; not to, which put /etc one file away from unbootable.
                LDA     #DIR_FIRST_OFF          ; key block: slot 1 at $0C2B
                STA     ZP_ENT_LO
                LDA     #>DIR_BUF
                STA     ZP_ENT_HI
                LDA     #1
                STA     ZP_SPCNT
                LDA     #16                     ; hop cap (see next_dir_block)
                STA     _fid_hops
@wp_scan        JSR     find_in_dir
                BCS     @wp_found
                JSR     next_dir_block          ; C=1: successor in DIR_BUF
                BCS     @wp_scan
                CLC                             ; chain exhausted -> not found
                RTS
```

- [ ] **Step 5: Rebuild and run the positive test**

```bash
python3 tools/ninja/gen.py && ninja all
python3 tools/mame_test/run.py --headless --no-state --fresh smoke
```

Expected: **PASS** -- boot reaches a prompt and `ls /` returns a listing, with
`disk_src/etc/passwd` still staged. Same probe, same tree, opposite result: that
pair is the proof.

If it fails, probe `PRESTAGED_ABS` (`$00:1FE8`). All zeros still means no module
staged, i.e. stage 2 still cannot find `ETC/PRELOAD.CONF`.

- [ ] **Step 6: Confirm the file is genuinely reachable, not just harmless**

Boot and read it back, which exercises the kernel FS rather than stage 2 and
proves the file is present and well-formed:

```bash
python3 tools/mame_test/run.py --headless --no-state --fresh smoke --command "cat /etc/passwd"
```

Expected: the two lines written in Step 1. If `run.py` does not accept
`--command` on this tree, run the smoke test and type the command interactively
per `feedback_fgx_runtime_debugging_method`.

- [ ] **Step 7: Run the full gate**

```bash
tools/gate.sh
```

Expected: green. This also runs `tools/check_mx.py`, which will fail if the
`MX %11` annotation on `next_dir_block` does not match its real register widths.

- [ ] **Step 8: Commit**

```bash
git add src/boot/stage2.s disk_src/etc/passwd
git commit -F - <<'EOF'
fix(boot): stage2 follows the ProDOS directory chain -- /etc is no longer one file from unbootable

find_in_dir scanned only a directory's FIRST block and returned "not found" for
anything past it; its own comment admitted it. Real ProDOS chases the next_block
link (Beneath Apple ProDOS p.25), and the kernel's own FS already does -- /bin
has 60+ files -- so the defect was confined to the minimal pre-console reader in
stage 2.

Why it mattered: stage 2 looks up ETC/PRELOAD.CONF and ETC/BOOT.CONF. /etc
already spanned two blocks with PRELOAD.CONF in the last slot stage 2 could see,
so ANY file staged before it pushed it into block 2, the PRODOS FST never
pre-staged, and the kernel came up with no FS dispatch. That happens before a
console exists, so the symptom was a black screen with no diagnostic and every
test failing identically. Staging /etc/passwd did exactly this on 2026-07-26.

The scan window is now a parameter of find_in_dir (key block: slot 1 at
DIR_FIRST_OFF, 12 usable; continuation: slot 0 at offset 4, all 13), and
walk_path loops over the chain via a new next_dir_block helper. Two guards: the
successor must point BACK at the block we came from before its entries are
trusted (a probe during the reverted 2026-07-26 attempt showed DIR_BUF can hold
non-directory bytes on some failure path), and a 16-hop cap so a corrupt pair of
mutually-referencing blocks cannot spin. next_dir_block saves/restores ZP $5B/$5C
across BlkRead exactly as walk_path does, since SmartPort firmware clobbers them
and find_in_dir compares against ZP_PATH_LO.

/etc/passwd ships as part of this change: it is the exact file that broke the
boot, so its presence is the standing regression guard, and libc's getpwent
already parses this 7-field format. Verified by negative control -- the same
probe file fails the smoke test on the unfixed tree and passes on the fixed one.

EOF
```

---

## Task 2: `FIODGNAME` -- the kernel can name a tty

**Files:**
- Modify: `toolchain/include/sys/ioctl.h` (after the `FIOCLEX` block, ~line 36)
- Modify: `src/kernel/syscall.s:2411-2414` (dispatch chain tail, at `@si_ck_lbic`)
- Modify: `src/kernel/syscall.s` (new `@si_dgname` handler, beside `@si_iscons`)
- Modify: `src/kernel/signal.s:1047` (`_ttyNames` beside `_ttyTable`)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `ioctl(fd, FIODGNAME, buf)` fills `buf` with the tty's device name,
  NUL-terminated, at most `FIODGNAME_MAX` (8) bytes including the NUL. Returns 0 on
  success, -1 with `errno = ENOTTY` if `fd` is not a tty. Task 3 consumes this.

### Background the implementer needs

The kernel's tty ioctl dispatch is a `CMP`/`BNE`/`JMP` chain at `syscall.s:2366`
(`@si_ttyX`), entered with **X = the tty's byte offset into `_ttyTable`**
(`idx * TTY_SIZE`; 0 for the console, `TTY_SIZE` and `2*TTY_SIZE` for the two pty
slaves). Every handler starts with `JSR @si_argp`, which sets `_libcTmp2` to a far
pointer to the caller's argument, then reads/writes through `[_libcTmp2]`.
`@si_getp` (`syscall.s:2442`) is the template for a multi-byte copy out. All
handlers finish with `JMP @si_ok0`, the shared `A=0, C=1` tail.

`_ttyTable` is declared at `signal.s:1047` as `DS NTTY*TTY_SIZE`, with
`NTTY EQU 3` and `TTY_SIZE EQU *` at `include/kernel.s:589,662`.

FGX's ioctl numbers follow BSD's low-16 convention: the `'t'` group is `0x74xx`
(`TIOCGETP` 0x7408 ...) and the `'f'` group is `0x66xx` (`FIOCLEX` 0x6601,
`FIONBIO` 0x667e, `FIONREAD` 0x667f). FreeBSD's `FIODGNAME` is `_IOW('f', 120, ...)`,
low 16 = **0x6678**, which is free here.

- [ ] **Step 1: Check kernel-bank headroom BEFORE writing any code**

The kernel bank has previously sat one byte under its ceiling. This task adds ~24
bytes of static data (which costs code room, since the ceiling is
`FGX_DATA - ORG`) and ~45 bytes of code.

```bash
python3 tools/ninja/gen.py && ninja all 2>&1 | grep -i "ERR\|ceiling\|overflow\|KGlobals" || echo "build clean"
python3 tools/bank_pressure.py 2>/dev/null || true
```

Record the current headroom. **If fewer than ~100 bytes are free, use the fallback
in Step 4 instead of the name table**, and note the choice in the commit message.
Do not proceed by shrinking something unrelated -- that is a separate change.

- [ ] **Step 2: Define the ioctl number**

In `toolchain/include/sys/ioctl.h`, after the `FIOCLEX` block:

```c
/* FIODGNAME: fill the caller's buffer with this fd's device name, NUL-terminated
 * and WITHOUT a "/dev/" prefix (e.g. "console", "ttyp0").  FreeBSD spells this
 * _IOW('f', 120, struct fiodgname_arg); FGX takes a bare char* because the tty
 * ioctl dispatch has no struct-arg convention and the name is bounded.
 *
 * This exists because BSD's ttyname(3) -- fstat, then readdir /dev matching
 * st_rdev -- cannot work on FGX: /dev is a synthetic short-circuit in
 * Path_Resolve (_fsResolveIsChardev), not an enumerable directory, and stat has
 * no st_rdev.  Asking the tty directly is the available answer.
 *
 * Returns -1/ENOTTY for any fd that is not a tty, so callers need no separate
 * isatty() probe. */
#ifndef FIODGNAME
#define FIODGNAME  0x6678       /* get device name ('f'<<8|120, BSD low 16) */
#endif
/* Buffer bytes the caller must supply, NUL included.  MUST equal the kernel's
 * TTYNAME_MAX (src/kernel/signal.s, beside _ttyNames) -- the kernel truncates at
 * that width, so a smaller buffer here overflows the caller.  The two numbers
 * are separate only because the kernel cannot see this header. */
#define FIODGNAME_MAX 8
```

- [ ] **Step 3: Add the name table**

In `src/kernel/signal.s`, immediately after the `_ttyTable DS NTTY*TTY_SIZE`
declaration at line 1047:

```
; Device names for FIODGNAME, one TTYNAME_MAX-byte record per tty, in tty-index
; order -- tty[0] = the console, tty[1..2] = the pty slaves.  Kept parallel to
; _ttyTable rather than as a field inside it: the kernel bank is at its ceiling
; and a per-entry field would cost NTTY*TTYNAME_MAX inside a struct that every
; tty ioctl indexes, for data only one op reads.  Names carry NO "/dev/" prefix;
; libc's ttyname() adds it.  Grows with NTTY when virtual consoles land.
;
; TTYNAME_MAX MUST equal FIODGNAME_MAX in toolchain/include/sys/ioctl.h -- the
; kernel truncates to this width and the caller sizes its buffer from that one.
; It must also stay a POWER OF TWO: @si_dgname converts index -> record offset
; with three ASLs rather than a multiply.  Changing it means changing both.
TTYNAME_MAX     EQU     8               ; 7 chars + NUL
_ttyNames       ASC     'console',00
                ASC     'ttyp0',00,00,00
                ASC     'ttyp1',00,00,00
```

- [ ] **Step 4: Add the dispatch entry and handler**

In `src/kernel/syscall.s`, the chain currently ends:

```
@si_ck_lbic     CMP     #TIOCLBIC
                BNE     @si_notty
                JMP     @si_lbic
@si_notty       LDA     #ENOTTY
```

Change it to:

```
@si_ck_lbic     CMP     #TIOCLBIC
                BNE     @si_ck_dgname
                JMP     @si_lbic
@si_ck_dgname   CMP     #FIODGNAME
                BNE     @si_notty
                JMP     @si_dgname
@si_notty       LDA     #ENOTTY
```

Then add the handler immediately after `@si_iconsW`'s `JMP @si_ok0`
(`syscall.s:2440`), so it sits with the other small handlers:

```
@si_dgname      ; FIODGNAME: copy tty[X]'s device name to *arg, NUL-terminated,
                ; at most TTYNAME_MAX bytes.  X is a BYTE OFFSET (idx*TTY_SIZE),
                ; so recover the index by repeated subtract -- the same trick
                ; _Sig_TtyOffset uses in the other direction, and NTTY is small
                ; enough that this runs at most NTTY-1 times.
                JSR     @si_argp
                MX      %00         ; argp returns REP'd (assembler state, not code)
                TXA                                 ; A = tty byte offset
                LDY     #0
@si_dgnIdx      CMP     #TTY_SIZE
                BCC     @si_dgnHave
                SEC
                SBC     #TTY_SIZE
                INY
                BRA     @si_dgnIdx
@si_dgnHave     TYA                                 ; A = tty index
                ASL                                 ; * TTYNAME_MAX (8)
                ASL
                ASL
                TAX                                 ; X = record offset
                SEP     #$20
                MX      %10
                LDY     #0
@si_dgnL        LDA     _ttyNames,X
                STA     [_libcTmp2],Y               ; STA preserves LDA's Z flag
                BEQ     @si_dgnDone                 ; copied the NUL: done
                INX
                INY
                CPY     #TTYNAME_MAX-1
                BCC     @si_dgnL
                LDA     #0                          ; oversized name: terminate
                STA     [_libcTmp2],Y
@si_dgnDone     JMP     @si_ok0
```

**Fallback if Step 1 showed no headroom.** Drop `_ttyNames` and synthesize the
name instead, which costs no static data: emit `console` for index 0, else
`ttyp` followed by `'0' + (index - 1)`. Same output, ~20 bytes more code and ~24
bytes less data. Take this only if measured headroom demands it, and say so in the
commit message -- the table is the more maintainable form once slice D adds
virtual-console names that are not a single digit apart.

- [ ] **Step 5: Build and check for MX leaks**

```bash
python3 tools/ninja/gen.py && ninja all
```

Expected: clean. `tools/check_mx.py` runs as a build edge; if it reports a leak in
`@si_dgname`, the `SEP #$20 / MX %10` pairing does not match the real widths. Note
that X and Y stay 16-bit throughout -- only M narrows -- so `_ttyNames,X` and
`[_libcTmp2],Y` are both 16-bit-indexed.

- [ ] **Step 6: Verify the syscall table did not drift**

```bash
tools/gate.sh
```

Expected: green. This runs the syscall-table drift check. `FIODGNAME` adds no
syscall number -- it rides `SYS_IOCTL` -- so the table must be **unchanged**. If
the drift check fires, something other than this change moved.

- [ ] **Step 7: Commit**

```bash
git add toolchain/include/sys/ioctl.h src/kernel/syscall.s src/kernel/signal.s
git commit -F - <<'EOF'
feat(kernel): FIODGNAME -- ask a tty its device name, so ttyname(3) can stop guessing

libc's ttyname() returned "/dev/tty" for every tty fd, with the comment "FGX has
one console; there is no fd->device-name map". The map does exist in the kernel;
it just was not reachable from userland.

BSD's implementation is not available here: real ttyname(3) does fstat then
readdir("/dev") matching st_rdev, but /dev is a synthetic short-circuit in
Path_Resolve (_fsResolveIsChardev), not an enumerable directory, and stat has no
st_rdev. So ask the tty directly.

FIODGNAME rides the EXISTING SYS_IOCTL tty dispatch, which already resolves
fd -> tty byte offset at @si_ttyX -- no new syscall number, and therefore no
corollary-syscall question. Non-tty fds get ENOTTY from the same @si_notty tail
as every other op, so callers need no separate isatty() probe. Number is 0x6678
= FreeBSD's _IOW('f', 120) low 16, consistent with FIOCLEX/FIONBIO/FIONREAD.

Names live in a _ttyNames table parallel to _ttyTable rather than as a field
inside it: the kernel bank is at its ceiling, and a per-entry field would cost
NTTY*TTYNAME_MAX inside a struct every tty ioctl indexes, for data one op reads.
The table is indexed by tty INDEX, recovered from the byte offset by repeated
subtract -- so it grows for free when NTTY rises for virtual consoles.

EOF
```

---

## Task 3: `ttyname()` tells the truth

**Files:**
- Modify: `toolchain/lib/libc_c/libc_c.c:2043-2052`
- Modify: `src/userland/ttytest/ttytest.c`

**Interfaces:**
- Consumes: `ioctl(fd, FIODGNAME, char *buf)` from Task 2; `FIODGNAME` and
  `FIODGNAME_MAX` from `<sys/ioctl.h>`.
- Produces: `char *ttyname(int fd)` returning a pointer to a static buffer holding
  `"/dev/"` + the device name, or `NULL` if `fd` is not a tty. The buffer is valid
  until the next call -- the BSD contract, so callers that `strcpy` out of it are
  unchanged. Slice C's `login` consumes this for `ut_line`.

- [ ] **Step 1: Write the failing test**

Add to `src/userland/ttytest/ttytest.c`. This is the discriminating case: a
console-only implementation returns the console name for *everything*, so testing
against the console alone would pass on the old stub. Open a pty slave and check
it names itself.

```c
/* ttyname(3) must name the ACTUAL line, not "the console".  A pty slave is the
 * discriminating case: the old stub returned "/dev/tty" for every tty fd, so a
 * console-only check would have passed against it. */
static int test_ttyname()
{
	int	fd;
	char	*n;

	n = ttyname(0);
	if (n == (char *)0) {
		printf("ttyname: FAIL console fd 0 returned NULL\n");
		return 1;
	}
	if (strcmp(n, "/dev/console") != 0) {
		printf("ttyname: FAIL fd 0 = %s, want /dev/console\n", n);
		return 1;
	}

	fd = open("/dev/ttyp0", 2);
	if (fd < 0) {
		printf("ttyname: FAIL cannot open /dev/ttyp0\n");
		return 1;
	}
	n = ttyname(fd);
	if (n == (char *)0 || strcmp(n, "/dev/ttyp0") != 0) {
		printf("ttyname: FAIL ttyp0 = %s, want /dev/ttyp0\n",
			n ? n : "(null)");
		close(fd);
		return 1;
	}
	close(fd);

	/* A non-tty fd must return NULL, not a stale buffer. */
	fd = open("/etc/hostname", 0);
	if (fd >= 0) {
		n = ttyname(fd);
		close(fd);
		if (n != (char *)0) {
			printf("ttyname: FAIL regular file = %s, want NULL\n", n);
			return 1;
		}
	}

	printf("ttyname: ok\n");
	return 0;
}
```

Call `test_ttyname()` from `main` and fold its return into the exit status, matching
however the existing tests in that file are wired.

- [ ] **Step 2: Run it and watch it fail**

```bash
python3 tools/ninja/gen.py && ninja all
python3 tools/mame_test/run.py --headless --no-state --fresh smoke --command "/bin/testbin/ttytest"
```

Expected: `ttyname: FAIL fd 0 = /dev/tty, want /dev/console` -- the old stub. If
`ttytest` is staged somewhere other than `/bin/testbin/`, check `disk_src/testbin/`
and adjust the path.

- [ ] **Step 3: Implement**

Replace `libc_c.c:2043-2052` -- currently:

```c
/* ttyname(fd): FGX has one console; there is no fd->device-name map, so report
 * the console for any fd that is actually a tty and NULL otherwise.  Callers use
 * this for display ("logged in on ...") rather than for opening. */
char *ttyname(fd)
    int fd;
{
    if (!isatty(fd))
        return (char *)0;
    return "/dev/tty";
}
```

with:

```c
/* ttyname(fd): ask the kernel which line this fd is bound to (FIODGNAME), and
 * prefix "/dev/".  BSD's implementation -- fstat, then readdir("/dev") matching
 * st_rdev -- is not available: /dev is a synthetic short-circuit in
 * Path_Resolve, not an enumerable directory, and stat has no st_rdev.
 *
 * No isatty() probe: FIODGNAME returns ENOTTY for a non-tty fd, so the ioctl IS
 * the check, and doing both would cost a second syscall to learn the same thing.
 *
 * The returned pointer is a static buffer valid until the next call -- the BSD
 * contract, so callers that strcpy out of it are unchanged. */
static char _tty_name[5 + FIODGNAME_MAX];   /* "/dev/" + name + NUL */

char *ttyname(fd)
    int fd;
{
    strcpy(_tty_name, "/dev/");
    if (ioctl(fd, FIODGNAME, &_tty_name[5]) < 0)
        return (char *)0;
    return _tty_name;
}
```

Confirm `libc_c.c` already includes `<sys/ioctl.h>`; if not, add it with the other
includes at the top rather than declaring `FIODGNAME` locally.

- [ ] **Step 4: Run the test and watch it pass**

```bash
python3 tools/ninja/gen.py && ninja all
python3 tools/mame_test/run.py --headless --no-state --fresh smoke --command "/bin/testbin/ttytest"
```

Expected: `ttyname: ok`.

If the console line fails with an empty name, the tty-index recovery in
`@si_dgname` is wrong -- check that `TXA` really sees the byte offset and that
`TTY_SIZE` is what the subtract loop compares against.

- [ ] **Step 5: Full gate**

```bash
tools/gate.sh
```

Expected: green, including fcc's 544 fixture goldens -- this task touches
`toolchain/`, so the goldens run (~5 min).

- [ ] **Step 6: Commit**

```bash
git add toolchain/lib/libc_c/libc_c.c src/userland/ttytest/ttytest.c
git commit -F - <<'EOF'
fix(libc): ttyname(3) names the real line instead of always saying the console

The stub returned "/dev/tty" for every tty fd. It is now an FIODGNAME ioctl plus
a "/dev/" prefix, so a pty slave reports /dev/ttyp0 and the console reports
/dev/console. slice C's login needs this for utmp's ut_line, and tty(1)/who need
it to mean anything at all.

The isatty() probe is gone deliberately: FIODGNAME returns ENOTTY for a non-tty
fd, so the ioctl IS the check and keeping both would spend a second syscall
learning the same thing.

Tested via ttytest against a pty slave, which is the discriminating case -- a
console-only assertion would have passed against the old stub.

EOF
```

---

## Definition of done

- `tools/gate.sh` green.
- `disk_src/etc/passwd` staged, disk boots, `cat /etc/passwd` returns its contents.
- The negative control from Task 1 Step 1 was **observed to fail** before the fix.
  A green boot alone does not close this task.
- `ttytest` reports `ttyname: ok`, including the pty-slave case.
- Three commits on `feat/bsd-login-stack`, nothing pushed.

## Notes for the reviewer

- The riskiest step is Task 1 Step 1. If the negative control passes, the whole
  task's evidence is void and the plan says to stop rather than continue.
- Task 2 Step 1's headroom check can legitimately change the implementation. A
  commit that took the fallback should say so.
- Nothing here touches `init`, `/etc/ttys`, or `NTTY`. Those are slices C and D.
