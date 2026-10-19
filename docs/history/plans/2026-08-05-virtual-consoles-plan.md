# Virtual consoles (slice D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alt-N switchable virtual consoles, each running its own
getty/login/shell as an independent terminal.

**Architecture:** Append two tty lines at `tty[3..4]`, give each VC its own
framebuffer bank (allocated lazily), switch by re-running the existing
`_ConBankPatchTbl` relocation loop plus a per-VC state swap, and route keystrokes
into the active VC at the point the heartbeat enqueues them. The switch itself
runs as a deferred request drained at a safe point, never in the ISR.

**Tech Stack:** 65816 assembly (Merlin32), fcc K&R C, the existing chardev and
tty-discipline machinery.

Scope, evidence and the rejected alternatives:
`docs/history/plans/2026-08-05-virtual-consoles-scope.md`. **Read it before
Task 1.** This plan does not repeat its analysis.

## Global Constraints

- **65816 assembly is reviewed line by line by the controller.** Subagents are
  unreliable here (recorded rule). Make the assembly reviewable: explicit `MX`
  directives at every arm, no implicit mode assumptions across branches, a
  comment on anything subtle.
- **Watch the imm-in-m8 trap** -- a 16-bit-looking immediate assembled in 8-bit
  mode. A known FGX bug class.
- **DBR discipline.** Absolute stores are DBR-relative. Two bugs this year --
  `_Mod_RegistryAppend` corrupting a loaded module, and the loader's stale-B
  `TAX` writing into kernel code -- were both this. If a routine can run with DBR
  not the kernel bank, say so at the top and use `PHB/PHK/PLB` or long
  addressing.
- **ASCII only** in every source file, comment, commit message and doc.
- **Generated + checked in:** `src/kernel/far/kernel_exports.s` (absolute kernel
  addresses -- never hand-edit or `git checkout` in isolation), the far
  patchsites, `w5100_patchsites.s`, `toolchain/lib/libc_c.s` and friends.
  `build.ninja` is gitignored.
- **Every check must go red without the change it guards.**
  `tools/check_vacuous_assertions.py` now fails any MAME assertion whose needle
  appears in its own command -- build markers by shell expansion or emit them
  from the program under test.
- **Bugs go to GitLab** (`glab issue create`, project `apple/fgx`), not into
  `docs/ROADMAP.md`.

### Commands

```bash
ninja -f build.ninja all
tools/gate.sh
python3 tools/mame_test/run.py --headless --fresh NAME   # --fresh ALWAYS
python3 tools/check_kernel_ceiling.py
python3 tools/bank_pressure.py
python3 tools/check_stack_budget.py -v
```

**`run.py` CACHES passes.** A full run will report the expected baseline having
executed nothing. Any test cited as evidence must be run `--fresh`.

### Baselines

| Measure | Now |
|---|---|
| MAME corpus | 45 passed / 3 failed (`shell_smoke`, `floppy_boot` = #21; `wide60` = #18) |
| fcc fixtures | 549 passed / 0 failed |
| kernel bank | 49,828 of 57,968 used, **8,140 free** |
| `gate.sh` | GREEN |

---

## Task 1 (D0): append the tty lines

**Files:** `include/kernel.s` (`NTTY`), `src/kernel/signal.s` (`_ttyNames`),
`src/kernel/chardev.s` (registration), `src/kernel/main.s` (boot zeroing bound).

**Produces:** `tty[3]`=ttyv1, `tty[4]`=ttyv2, registered as `/dev/ttyv1`,
`/dev/ttyv2`. No switching, no VC banks, no keyboard change.

- [ ] **Step 1: the regression test FIRST**

The failure this phase can cause is misdirecting the ptys. Establish the guard
before touching anything:

```bash
python3 tools/mame_test/run.py --headless --fresh logintest inithup
```

**Measured 2026-08-05: 2 passed, 0 failed.** These must still pass at the end of
the task; they are what goes red if the tty indices move.

There is no `ptyshell` test -- an earlier draft named one. The manifest was
deleted in `2bbf4cca3` ("delete the MAME suite; the gate is one smoke test"). The
binary is still built and staged at `disk_src/testbin/ptyshell`, but
`ptyshell.c:90` hardcodes `/bin/jsh`, which no longer exists (`/bin/sh` is bsh),
so it would fail at PS1 spawn. Resurrecting it is worth doing and is NOT this
task -- file it, do not detour.

Note what the guard actually discriminates: pair 0 -> tty[1] and pair 1 -> tty[2]
are hardcoded at `pty.s:94-102`, while `_ptySlaveIdx0/1` are CHARDEV indices
captured at registration (`chardev.s:541,553`). Appending keeps the first
correct; registration ORDER keeps the second correct. Both are live failure modes
for this task.

- [ ] **Step 2: grow the table**

`NTTY` 3 -> 5 (`include/kernel.s:677`). Append two 8-byte records to `_ttyNames`
(`signal.s:1340`) -- `ttyv1`, `ttyv2`, NUL-padded to 8 exactly as the existing
rows are. Register both in `_Chardev_InitBuiltins` (`chardev.s:502-566`) -- that
is where the builtins register, NOT `pty.s`. **Register AFTER the pty slaves**,
so the `_ptySlaveIdx0/1` captures at `chardev.s:541,553` keep their values. The
registry is 5 of 16 used, so there is room.

**Do NOT insert before the ptys.** The pair->tty mapping is baked at
`pty.s:94-102`, `syscall.s:3144-3160` (READ dispatch), `syscall.s:2804-2811`
(ioctl arm) and pty slave-open. Appending leaves all four correct.

- [ ] **Step 3: check the ceiling**

```bash
python3 tools/check_kernel_ceiling.py
```

`TTY_SIZE` is 298 B, so this adds ~596 B plus names. Report free bytes before and
after. This is the bank that sat 1 byte from its ceiling in July.

- [ ] **Step 4: prove the new lines are openable**

Extend `ttysprobe` (or add a probe) to `open("/dev/ttyv1", O_RDWR)` and assert it
succeeds and that `/dev/ttyv3` does not exist. Prove it discriminates: with the
registration removed, the open must fail.

**`ttyname()` is deliberately NOT asserted here.** ttyname(3) is FIODGNAME, and
the ioctl chardev arm maps only `_ptySlaveIdx0/1` to tty offsets
(`syscall.s:2800-2811`); any other chardev falls through to `_Chardev_Ioctl` and
gets ENOTTY. The ttyv idx->offset mapping is built in Task 3 Step 2, so the
ttyname assertion belongs there -- asserting it in D0 would be a test that cannot
pass, which is exactly the shape this project's rules forbid. **Task 3 owns it**:
`login` reads `TERM` and the `TTY_SECURE` gate by whatever `ttyname()` returns,
so a `_ttyNames` mismatch is a silent security-relevant wrong answer.

- [ ] **Step 5: regression + commit**

`logintest` and `ptyshell` `--fresh` green, full corpus at baseline.

---

## Task 2 (D1): per-VC state and a deferred switch

**Files:** `include/memmap.s` (per-VC state blocks, VC registry),
`src/kernel/far/console/console_switch.s` (new),
`src/kernel/far/console/console_init.s` (extract the patch loop),
`src/kernel/sched.s` or the syscall-exit path (the drain point).

**Produces:** `Con_SwitchVC(n)` callable from a test hook. No keyboard yet.

- [ ] **Step 1: extract the patch loop**

`Con_Init` (`console_init.s:35-49`) walks `_ConBankPatchTbl` writing
`_kConsoleBank` into 97 bytes across 75 sites (`_ConBankPatchBytes EQU 194`).
Extract it as `Con_RepatchBank(A = bank)` and have `Con_Init` call it. Verified
re-runnable -- no one-shot assumption, and `_kConsoleBank`'s only consumers are
`main.s` and this loop.

**The loop reads the `_kConsoleBank` static, not a register** (`console_init.s:42`).
Decide explicitly whether `Con_RepatchBank` takes the bank in A and stores it to
`_kConsoleBank` first, or whether the caller stores and the routine stays
argument-free -- and say which in the header comment. An extraction that silently
keeps reading the static while appearing to take A is the bug this note exists to
prevent.

Commit this alone and prove it inert: boot must be byte-for-byte unaffected.

- [ ] **Step 2: define the per-VC state block**

**~110 bytes, not the 14 `Con_EnterAltScreen` saves.** That set is NOT
sufficient -- see the scope doc, section 4. The block must carry:

`_conWritePtr`, `_conTopRow`, `_conCurRow`, `_conCurCol`, `_conFollow`,
`_conFg`, `_conBg`, **`_conAttr`**, the whole of `CON_VT_STATE` (parser state
`VT_STATE/INT1/INT2/PRIVATE/NPARAMS/PARAM_CUR/PARAMS`, `VT_SGR_*`, `VT_SAVED_*`,
`VT_SR_TOP/BOT`, `VT_CURSOR_VISIBLE`, `VT_AUTOWRAP`, `VT_PENDING_WRAP`,
`VT_CURS_RENDERED/SAVED_ATTR/ROW/COL`), `VT_TAB_STOPS`, and **`CON_ALT_SAVE`
plus a new in-alt-screen flag**. ~126 B.

`_conAttr` is the live attribute byte every erase/fill handler applies
(`console_vthandler.s:295,325,393,442,463`) and is one of the bytes alt-screen
does not round-trip. Omit it and session B erases with session A's reverse-video.

`CON_ALT_SAVE` is a SINGLE far-bank static (`far.s:313`, 16 B reserved / 14
used) and there is no in-alt flag anywhere. The alt *buffers* become per-VC for
free -- they live at `$8000+` in each VC's own bank -- but the saved state words
do not. Without this, vi on VC1 and vi on VC2 clobber each other's
`Con_ExitAltScreen` restore.

Three explicit rulings to record in the code, not leave implied:
- `_conRenderState` -- reset on switch, since the switch repaints anyway. **But
  state 3 means SUSPENDED for a direct-SHR screen claim, not a pending scroll**
  (`syscall.s:696-745`); resetting that would un-suspend a live claim. See the
  `_screenOwner` ruling below.
- `_screenOwner` -- one global, no VC binding, and a direct-SHR app's pixels are
  in no CharBuf, so a switch away and back cannot restore them. **Rule: the
  drain refuses (or defers) the switch while `_screenOwner != 0`.** Exit
  auto-releases it (`process.s:1371,2319`), so this cannot wedge permanently.
- `_conMode` -- if no userland changes console mode per session, rule "modes are
  global for now" and defer the `Con_LoadMode`/SCB/palette work. Check first.

- [ ] **Step 3: the VC registry, with lazy banks**

A small table: per VC, its framebuffer bank (0 = not yet allocated) and its state
block. VC0 uses the existing `_kConsoleBank`.

`Bank_Alloc` on first use. **Decide and record WHERE "first use" is** -- the
scope doc shows first-*switch* is defeated at boot by D3, because gettys write
their prompts before anyone switches. First-*write* is the honest choice if the
lines ship `on`.

Bank exhaustion has no user-visible channel today. Decide what a failed switch
does on screen and write it down.

- [ ] **Step 4: `Con_SwitchVC(n)` as a DEFERRED REQUEST**

Detection and execution are different problems. The switch -- repatch 97 bytes,
swap ~110 B of state, `Con_RenderAll` -- **must not run in an ISR**. A task
preempted inside the console engine would resume with half its bank operands
retargeted: the wrong-bank smear class of #20/!58, which cost two sessions.

Follow the pattern already adjacent in this code: `_kTtySigReq` is set in the ISR
and drained at a safe point (`signal.s:657-662`, `sched.s:314-319`). A switch
request needs the same shape, plus a "nobody is inside the console engine"
condition.

Sequence when drained: save live state to the outgoing VC's block -> allocate the
incoming VC's bank if needed -> `Con_RepatchBank` -> load the incoming block ->
`Con_RenderAll`.

- [ ] **Step 5: test via a hook, reading banks at runtime**

Write distinguishable text to VC0, switch, write to VC1, switch back, assert both
`CharBuf`s. Markers must be script-emitted. **Bank numbers are runtime-allocated,
so read them from the VC registry** -- fgxdebug assertions cannot use fixed
addresses.

- [ ] **Step 6: commit**

---

## Task 3 (D1.5): background-VC output routing

**This is the largest chunk of engineering in the slice and the phase the first
draft of the scope did not have.**

**Files:** `src/kernel/syscall.s` (the console write path, the ttyv chardev
read/write/ioctl arms), `src/kernel/far/console/` as needed.

**Produces:** a process writing to `tty[3]` while VC0 is displayed lands in VC1's
buffer, with the visible screen untouched.

- [ ] **Step 1: the test FIRST -- it is the most valuable assertion in the plan**

A process writes to `/dev/ttyv1` while VC0 is active. Assert VC1's `CharBuf`
received the text AND VC0's screen did not change. This goes red on every hard
mistake in this slice.

- [ ] **Step 2: the per-VC input rings**

**Nothing creates them yet.** The scope prices them (256 B each, core bank,
heartbeat-filled) and Task 4 fills them, but the read arm in Step 3 needs a byte
source, so they are built HERE. Two rings, ~512 B, plus a `TTY_Backend`-style
selector so the read arm knows which ring a tty draws from.

Add the 512 B to the ceiling accounting and re-run
`python3 tools/check_kernel_ceiling.py`.

- [ ] **Step 3: the ttyv chardev arms**

Read, write and ioctl for the new lines. Cooked defaults at open -- pty slave-open
does this and ttyv must too, or the line comes up in an undefined discipline.

The ioctl arm needs the ttyv idx->tty-offset mapping alongside the existing
`_ptySlaveIdx0/1` cases (`syscall.s:2800-2811`), captured at registration the
same way. **This is what makes `ttyname()` work on the new lines**, which Task 1
Step 4 deferred to here: assert `ttyname(fd)` on `/dev/ttyv1` returns
`/dev/ttyv1`, and prove it discriminates by shortening `_ttyNames` by one record
and watching it read the wrong name.

Rule `TIOCISCONS` (`syscall.s:2485`) while you are here -- with real logins on
ttyv it decides whether a shell uses the console SYS_GETKEY editor or plain byte
reads, so it is user-visible. Record the ruling.

- [ ] **Step 4: per-writer state swap on the write path**

Today there is exactly one console output path: `@sw_console` -> per-byte
`Con_Write` into whatever bank the patched operands currently point at, reading
`_ttyTable+TTY_SgFlags` -- **literal tty[0]** -- for ONLCR (`syscall.s:2096`).

A write to a non-active VC must: patch to the writer's bank, swap in the writer's
VT state, write with **rendering suppressed**, then patch back. And ONLCR must
read the WRITER's `TTY_SgFlags`, not tty[0]'s.

- [ ] **Step 5: measure the cost**

A repatch-per-background-write is a 194-byte loop plus a state swap per write
syscall. Plausibly fine; unmeasured. **Measure it.** If it is not fine,
background writes need buffering, which is a different design -- report rather
than improvise.

- [ ] **Step 6: commit**

---

## Task 4 (D2): alt-N and key routing

**Files:** `src/kernel/toolbox.s` (heartbeat enqueue + inject encoding),
`src/kernel/syscall.s` (the tty[0] hardcodes below).

- [ ] **Step 1: extend the inject encoding first, or the test cannot exist**

`_kKbdInjectRaw` (`toolbox.s:352-361`) encodes only "bit 8 = Ctrl", and injected
keys bypass the live `$C025` read. Add an Option bit and teach the harness.
Without this there is no way to test alt-N at all.

- [ ] **Step 2: route keys to the active VC at enqueue**

Keys go into the active VC's tty input, not a shared ring drained by whoever
reads first. Intercept Option-1/2/3 at the same point (`$C025` bit 6 =
Closed-Apple = Option, Firmware Reference p.298) and post a switch REQUEST --
never the switch itself.

- [ ] **Step 3: re-gate the SEVEN tty[0] / shared-ring consumers**

An earlier draft listed five and misattributed one. All seven assume a single
shared ring or hardcode tty[0]. Each needs the ACTIVE VC:

1. **`sched.s:156-161` and `sched.s:333-345` -- the keyboard wake gate. THE ONE
   THAT KILLS THE MACHINE.** `swtch` wakes `WCHAN_KBD` sleepers only when
   `_kKbdRingCount != 0`, on every switch and in the idle loop. Step 2 moves keys
   out of the shared ring; the moment it does, `_kKbdRingCount` stays 0, the wake
   never fires, and **every shell blocked in `read()` sleeps forever**. The D2
   test would hang rather than fail cleanly. The condition must become "any
   pending input on the active VC's ring". Fix this in the same commit as Step 2,
   not after.
2. `toolbox.s:466` -- the ^C/^Z check reads `_ttyTable+TTY_FgPgrp` (tty[0]), and
   `_kTtySigReq` carries no tty index. Both drains hardcode 0
   (`signal.s:657-662`, `sched.s:314-319`).
3. **`pipe.s:794-806` -- `_Pipe_PollIntr` does NOT call `_Tty_CurIsFg`.** It reads
   `_ttyTable+TTY_FgPgrp` directly at `pipe.s:804` and then peeks
   `KFAR_CON_POLLKEY` -- a key-stealing consumer of the shared ring in its own
   right. It is the pre-job-control fallback: when no pgrp owns the tty, this peek
   is the ONLY ^C path, and deleting it made a blocked pipe read
   un-interruptible under bsh. Re-gate it; do not remove it.
4. `_Tty_CurIsFg` (`signal.s:360-373`) -- compares against tty[0]. It has exactly
   TWO callers: `_Sock_PollIntr` (`net_dispatch.s:158`) and `_Sys_PollKey`
   (`syscall.s:4556`). Not the pipe path.
5. `SYS_GETKEY` (`syscall.s:4533-4543`) -- **no foreground gate at all**, and its
   callers (fractal, more, elvis, ptyshell) are exactly what a user leaves on a
   background VC. Binding it to the caller's VC needs a controlling-tty notion,
   which does not exist. **If this turns out to need a new per-task field, STOP
   and report** -- that is a design change, not an implementation detail.
6. `select()` console readiness -- `_kKbdRingCount != 0` (`syscall.s:1212, 1267`).
7. `_Sel_SigPending` (`syscall.s:1076-1078`) -- treats any `_kTtySigReq` as
   pending regardless of which tty.

- [ ] **Step 4: test and commit**

Inject Option-N and assert the switch. Note the recorded trap: injection before
the child is foregrounded does nothing.

---

## Task 5 (D3): turn the consoles on

**Files:** `disk_src/etc/ttys`, kernel output pinning, `docs/`, `CHANGELOG.md`.

- [ ] **Step 1: flip `ttyv1`/`ttyv2` to `on`, against a stated bank budget**

init then starts gettys on them. Lazy allocation is defeated on every boot here:
getty writes `/etc/issue` within seconds, so both VC banks plus two getty
processes -- each holding a private libc bank per #37 -- land at boot. Roughly
+4 to +6 banks out of 24 before the user types anything.

**Set the threshold before measuring, not after.** State the free-bank count
below which this does not ship, and the fallback: ship `ttyv2` `off` and keep two
consoles. `python3 tools/bank_pressure.py` decides it.

`BANK_USER_COUNT` is **24** (`include/loader.s:735`). The "22 banks" comment at
`bank.s:3` is stale -- do not "correct" the pool size from it.

- [ ] **Step 2: pin kernel output to the console line; panic force-switches there**

tty[0] is named `console`, not `ttyv0` -- there is no such device
(`_ttyNames`, `/etc/ttys`). So a panic is never on a console nobody is looking at.

- [ ] **Step 3: full verification**

The "a getty prompt appears on ttyv1" assertion is a vacuity trap: that prompt
lands in a BACKGROUND VC's CharBuf, and the harness's `screen_contains` reads the
visible screen. Either read the VC's bank through the registry (Task 2's
mechanism) or inject Option-2 first and then read the screen. Say which in the
manifest. Asserting it against the visible screen passes or fails for reasons
unrelated to the feature.

```bash
python3 tools/mame_test/run.py --headless --fresh    # expect baseline + new
tools/gate.sh
python3 tools/bank_pressure.py
python3 tools/check_stack_budget.py -v
python3 tools/check_kernel_ceiling.py
```

Three consoles at a login prompt is a NEW co-residency, which is exactly when
`check_stack_budget.py`'s own rule says to add a scenario. Note #30: that checker
currently under-counts (init IS in the arena; `pages_for` omits argv-frame pages),
so report its numbers as indicative.

- [ ] **Step 4: docs and close-out**

`CHANGELOG.md` narrative -- what a user sees: Option-1/2/3 switch between three
independent consoles, each with its own login. `docs/ROADMAP.md` gets at most a
one-paragraph pointer. Update the scope doc with what was measured.

---

## Self-Review

**Coverage:** scope section 2 -> Task 1; section 4 -> Task 2 Step 2; section 5 ->
Task 2 Step 3; section 6's D1.5 -> Task 3; section 3 -> Task 4; the feature ->
Task 5.

**The load-bearing checks:** Task 1's `logintest`/`ptyshell` (pty misdirection is
the failure appending exists to avoid), Task 2 Step 1's inert-repatch proof, and
Task 3 Step 1's background-write assertion, which is the one that goes red on
every hard mistake here.

**Deliberately unanswered, to be decided during the work and RECORDED:** where
"first use" is for lazy bank allocation; what a failed switch shows on screen;
whether `_conMode` is per-VC or global; what `TIOCISCONS` (`syscall.s:2485`)
answers on a ttyv; whether `SYS_GETKEY` needs a controlling-tty field (a
STOP-and-report if so).

**Reviewed 2026-08-05** (Fable, against the sources). Nine findings folded in;
three were Critical: the `ttyv0`/`ptyshell` guard test does not exist, the D0
ttyname assertion could not pass until Task 3's ioctl mapping, and Task 4's
consumer list omitted `sched.s`'s keyboard wake gate -- which would have shipped
a system where no shell ever wakes for a keystroke. Verified independently at the
source before folding in.

**Out of scope:** serial getty on the SIM port; apple/fgx#37, #34's siblings,
#30.
