# Virtual consoles (slice D) -- scope (2026-08-05)

Delivers what the campaign was originally asked for: **alt-N switchable
consoles, each running its own getty/login/shell, behaving as independent
terminals.**

Slice C shipped the login chain (`init` respawn engine, `getty`, `login`,
`passwd`, `halt`) but only ONE active line. `/etc/ttys` carries `ttyv1` and
`ttyv2` marked `off`, because the devices they name do not exist. This slice
makes them exist.

Scoping doc, not an implementation plan. Supersedes section 2 of
`docs/history/plans/2026-08-04-login-stack-vc-design.md`.

**Revised 2026-08-05 after an adversarial review.** That review found the two
decisions this doc argues hardest for are correct and better supported than the
doc knew, and that two things it treated as settled were the weak ones. Both
corrections are folded in below and marked.

---

## 1. State this builds on (verified on `main` at `dc7b1db2b`)

| Piece | State |
|---|---|
| `init` respawn engine over `/etc/ttys` | shipped; skips lines lacking `TTY_ON` |
| `/bin/getty`, `/bin/login` | shipped, proven end to end over a pty by `logintest` |
| `/etc/ttys` `ttyv1`/`ttyv2` entries | present, `off`, awaiting this slice |
| `NTTY` | **3** -- `tty[0]`=console, `tty[1]`=ttyp0, `tty[2]`=ttyp1 |
| tty name table (`_ttyNames`, `signal.s:1340`) | `console`, `ttyp0`, `ttyp1`; chardev registration itself is in `chardev.s` + `pty.s` |
| console framebuffers | one bank, `_kConsoleBank`, 4 x 8000 B + 4 x 2000 B alt-screen = 40,000 of 65,536 |
| bank relocation mechanism | **proven** -- `Con_Init` re-runs a loop over `_ConBankPatchTbl`; verified re-runnable with a different bank, no one-shot assumption |
| user bank pool | `$0A..$21` = **24 banks** |
| kernel bank headroom | **49,828 of 57,968 used, 8,140 free** |

**Patch-table arithmetic, corrected twice.** The table is **75 sites** patching
**97 bytes**: 53 L-sites (`STAL`/`LDAL`, one bank byte each) plus 22 M-sites
(`MVN`, two bank bytes each) = 97 `DA` entries, and `_ConBankPatchBytes EQU 194`
is the table's own size in bytes (97 x 2-byte pointers), which is the loop bound.
An earlier revision of this doc "corrected" the 2026-08-04 design's 75 to 97;
**that was wrong** -- it conflated sites with patched bytes. The original 75 was
right.

**A VC costs 40,000 B**, not the 16,000 the 2026-08-04 sketch implied: four
buffers (char/attr/fg/bg) plus four alt-screen snapshots, not two buffers. The
alt-screen snapshots live inside the console bank at `$8000+`, so they become
per-VC for free.

## 2. Appending the tty lines

`pty.s:94-102` bakes *pair 0 -> tty[1], pair 1 -> tty[2]*. Inserting the VCs at
`tty[1..2]` would silently point the ptys at the wrong tty. **The VCs append at
`tty[3..4]`; `NTTY` 3 -> 5.**

The review found the pair->tty[1..2] mapping baked in **four** places, not the
one this doc originally cited -- all of which insertion breaks and appending
leaves intact:

- `pty.s:94-102` -- `_Pty_Init` bakes idx and offset per pair.
- `syscall.s:3144-3160` -- the READ dispatch maps `_ptySlaveIdx0/1` to literal
  `#_ttyTable+TTY_SIZE` / `+TTY_SIZE+TTY_SIZE`.
- `syscall.s:2804-2811` -- the ioctl chardev arm maps the same chardev indices
  to `LDX #TTY_SIZE` / `#TTY_SIZE*2`.
- `pty.s` slave-open installs sgttyb defaults into the pair's baked `PTYR_TtyOff`.

Everything else indexes generically and grows clean: `_Tty_DeliverSig`
(`signal.s:167-197`) converts index to offset by an add loop; `FIODGNAME`
(`syscall.s:2498-2530`) recovers the index by repeated `SBC #TTY_SIZE`; boot
zeroing (`main.s:198-202`) is `NTTY*TTY_SIZE`-scaled and stays BPL-safe at 1488.

**`_ttyNames` must gain two records in lockstep** or `ttyname(3)` on a ttyv fd
reads past the table -- and `login` looks up `TERM` and the `TTY_SECURE` gate by
whatever `ttyname()` returns, so a mismatch there is a silent security-relevant
wrong answer, not a cosmetic one.

**Cost:** `TTY_SIZE` is 298 B (dominated by the 256-byte `TTY_CanonBuf`), so
NTTY 3 -> 5 adds ~596 B of kernel-bank statics plus ~16 B of names, plus any
per-VC input rings (256 B each, and they must live in the core bank because the
heartbeat ISR fills them). Against 8,140 B free that fits -- but this is the bank
that sat 1 byte from its ceiling in July, so the number belongs in the plan and
in `check_kernel_ceiling`'s output at each phase.

**Open question:** `TIOCISCONS` (`syscall.s:2485`) answers "is tty offset 0". A
shell on ttyv1 would be told "not the console" despite being a physical
screen+keyboard console. Decide deliberately; it changes what full-screen tools
believe about their terminal.

## 3. Keyboard routing -- the surface is 3x what this doc first named

One ring (`_kKbdRing`), filled by the heartbeat (`toolbox.s:363-498`), drained by
`Con_PollKey`/`Con_GetKey`. Two VC shells are each foreground **on their own
tty**, so the SIGTTIN gate (`syscall.s:3378-3390`) passes both and they race for
the ring. Keys must be routed **at enqueue time** into the active VC's tty input.
That mirrors the proven pty pattern (per-pair rings + a `TTY_Backend` selector),
and the discipline above it is already pointer-driven via `(_kTtyRdPtr)`, so the
seam exists. Pty slaves are untouched -- their byte source is the pair ring.

**Five further consumers assume one ring or hardcode tty[0].** None was in the
first draft; all must be routed or re-gated:

1. **The ^C/^Z path carries no tty index.** The heartbeat checks
   `_ttyTable+TTY_FgPgrp` -- literal tty[0] (`toolbox.s:466`) -- and sets
   `_kTtySigReq`, a bare signum. Both drain sites hardcode index 0
   (`signal.s:657-662`, `sched.s:314-319`). ^C must target the ACTIVE VC.
2. **`_Tty_CurIsFg`** (`signal.s:360-373`) compares against tty[0], gating the
   cooperative ^C poll in `_Pipe_PollIntr`/`_Sock_PollIntr` and `_Sys_PollKey`.
3. **`SYS_GETKEY` has no foreground gate at all** (`syscall.s:4533-4543`). Its
   callers -- fractal, more, elvis, ptyshell -- are exactly the full-screen tools
   a user leaves running on a background VC. Binding GETKEY to the caller's VC
   requires answering "which tty does this task belong to", and **there is no
   controlling-tty field**; today it is inferred from pgrp vs tty[0]. This is the
   single largest unknown in the slice.
4. **`select()`** console readiness is `_kKbdRingCount != 0`
   (`syscall.s:1212, 1267`), and `_Sel_SigPending` treats any `_kTtySigReq` as
   pending (`syscall.s:1076-1078`) regardless of which tty it was for.
5. **The D2 test cannot run as first written.** `_kKbdInjectRaw`
   (`toolbox.s:352-361`) encodes only "bit 8 = Ctrl"; injected keys bypass the
   live `$C025` read. Injecting Option-N needs the encoding and the harness
   extended first.

Modifier fact confirmed: `$C025` bit 6 is Closed-Apple, which is the Option key
(Firmware Reference p.298); bit 1 Ctrl matches existing code. TN IIGS #58's
`$C025` anomaly affects Ctrl/Shift during auto-repeat only.

## 4. The per-VC state block -- this doc's original claim was WRONG

The first draft said `Con_EnterAltScreen`'s 14 saved bytes are "proven
sufficient, because alt-screen round-trips through them". **That argument does
not hold.** `CON_VT_STATE` (`include/console.s:72-118`) is an ~$56-byte block
plus 10 bytes of tab stops, and alt-screen saves **3 bytes of it**. It survives
because enter/exit happen at escape-sequence boundaries in the SAME app and
session, and because the leakage it does have is a tolerated same-app quirk.
Neither holds between two independent login sessions.

State that must be per-VC and is NOT in the 14:

- **parser state mid-sequence** -- `VT_STATE/INT1/INT2/PRIVATE/NPARAMS/
  PARAM_CUR/PARAMS`, 32+ B. A background writer preempted mid-CSI whose parse
  state is clobbered gives corrupted escape handling. Alt-screen never exercises
  this.
- **SGR** -- `VT_SGR_FG/BG/FLAGS` (bold/reverse/underline); `_conFg`/`_conBg` are
  base colours only.
- **DECSC saved cursor** -- `VT_SAVED_ROW/COL/ATTR/PAL/G0/G1/GL`.
- **scroll region** -- `VT_SR_TOP/BOT`; vi sets it and the other VC must not
  inherit it.
- **`VT_CURSOR_VISIBLE`**, **`VT_AUTOWRAP`**, **`VT_PENDING_WRAP`** (the
  deferred-wrap flag, i.e. column-80 correctness), **`VT_TAB_STOPS`**.
- **cursor-render state** -- `VT_CURS_RENDERED/SAVED_ATTR/ROW/COL`; the
  saved-attr-under-cursor refers to a specific VC's AttrBuf, so swapping buffers
  without it restores the wrong byte.
- **`_conRenderState`** -- deferred scroll-coalescing, a kernel-bank global
  outside the VT block (`syscall.s:2070-2143`). Arguably resettable on switch
  since the switch repaints anyway -- but that is a decision to record, not an
  omission to inherit.
- **`_conMode`** -- a 20-byte descriptor. Applying a per-VC mode difference means
  the `Con_LoadMode`/`Con_InitMode` + SCB/palette path, not a byte copy. If no
  userland changes console mode per session, rule "modes are global for now" and
  defer -- but rule it explicitly.

Honest size: **~110 bytes**, not 15. Cheap either way. The danger was believing
the 14-byte set was proven.

## 5. Bank allocation: LAZY (the maintainer, 2026-08-05), with consequences

A VC gets its bank on first use rather than at `Con_Init`, so the common
single-console case costs nothing new against the 24-bank pool that apple/fgx#37
is already about.

The review found three consequences this doc had not thought through:

- **D3 defeats lazy at boot.** Once `ttyv1`/`ttyv2` are `on`, gettys spawn and
  write their prompts within seconds -- before anyone switches. So either the
  bank is allocated at **first write** (both banks taken on every boot, and lazy
  buys nothing while the lines are on -- the honest framing is *"lazy helps only
  if the ttys ship off by default"*), or pre-switch prompt output is dropped and
  the user switches to a blank VC whose getty has already spoken. **Decide which,
  and say so in the plan.**
- **The ENOMEM path is not where this doc claimed.** `login`'s fallback covers
  exec/arena ENOMEM, not bank exhaustion. Bank exhaustion surfaces either at
  getty's first write/open -- getty exits, init respawns, and the throttle
  (`init.c:251`) disables the line until a HUP, i.e. a quietly dead console -- or
  at switch time inside the kernel, where **there is no user-visible error
  channel at all**. What the screen does when a switch fails is undefined today
  and needs designing.
- **D1's assertions cannot use fixed addresses.** Banks are discovered at
  runtime, so the test must read the VC registry to find them.

## 6. Phasing -- revised; the two hardest problems now have a home

The first draft's phase table had no phase for either of the two things most
likely to sink the slice.

| Phase | Delivers | Proves |
|---|---|---|
| **D0** | `NTTY` 3 -> 5, `_ttyNames` grows, `/dev/ttyv1`/`ttyv2` registered, no switching | the tty table and chardev registry take the new lines **without disturbing the ptys** -- `logintest` and `ptyshell` green is the regression that index reordering would cause |
| **D1** | per-VC state block + `Con_SwitchVC(n)` **as a deferred request drained at a safe point**, driven by a test hook | the relocation and state round-trip, AND the atomicity design |
| **D1.5** | ttyv chardev read/write/ioctl arms, cooked defaults at open, per-writer state swap, per-tty ONLCR | **background-VC output routing** -- the largest chunk of engineering in the slice |
| **D2** | alt-N interception and key routing at the enqueue point, after extending `_kKbdInjectRaw` with an Option bit | the human-facing half |
| **D3** | flip `ttyv1`/`ttyv2` `on`; init starts gettys; kernel output pinned to ttyv0 with panic force-switch | the actual feature |

**Why switch atomicity moves into D1.** Alt-N is detected in the heartbeat ISR,
but the switch -- repatch 97 bytes, swap ~110 B of state, `Con_RenderAll` --
cannot RUN there. A task preempted **inside** the console engine would resume
with half its bank operands pointing at a different VC: exactly the wrong-bank
smear class of #20/!58, which cost two sessions. The established pattern is
adjacent in the same code: `_kTtySigReq` is set in the ISR and drained at a safe
point. The switch needs that request/drain shape plus a "nobody is inside the
console engine" condition. Detection and execution are different problems and
the first draft conflated them.

**Why D1.5 exists.** D3 flips the gettys on, and `init` opens `/dev/ttyv1` onto
the child's 0/1/2 (`init.c:283-290`); getty then writes `/etc/issue` and `login:`
**while VC0 is on screen**. That write must land in VC1's buffer with rendering
suppressed. Today console output has exactly one path -- `@sw_console` ->
per-byte `Con_Write` into whatever bank the patched operands currently point at,
reading `_ttyTable+TTY_SgFlags` (literal tty[0]) for ONLCR (`syscall.s:2096`).
None of the plumbing for a second writer exists, and nothing between D0 and D3
built it.

**The test that goes red on every hard mistake in this slice:** a process writes
to `tty[3]` while VC0 is active; assert VC1's `CharBuf` received it AND VC0's
screen did not change. That belongs in D1.5 and is the single most valuable
assertion in the plan.

## 7. Verification

Every check must go red without the change it guards.
`tools/check_vacuous_assertions.py` now catches assertions satisfiable by the
echoed command line, and every new manifest here is subject to it -- markers must
be script-emitted or expansion-built.

| What | How |
|---|---|
| D0 | `logintest` + `ptyshell` green (the pty-misdirection regression), and `check_kernel_ceiling` reported at each phase |
| D1 | switch via test hook, assert both VCs' `CharBuf` via fgxdebug, reading bank numbers from the VC registry rather than fixed addresses |
| D1.5 | the background-write test above |
| D2 | inject Option-N (needs the inject encoding extended first); note the recorded trap that injection before the child is foregrounded does nothing |
| D3 | boot with `ttyv1` `on`; assert a `login:` prompt on it and that `ps` shows the gettys |
| Banks | `tools/bank_pressure.py` before/after, stating the number not the direction |
| Arena | `tools/check_stack_budget.py` -- three consoles at a login prompt is a new co-residency, which is exactly when that file's own rule says to add a scenario. Note #30: the checker currently under-counts (init IS in the arena; `pages_for` omits argv-frame pages) |

**Known ceiling, unchanged:** three concurrent `tcsh` is 168 pages against a
149-page arena; `login`'s ENOMEM fallback to `/bin/sh` is the backstop, and slice
B3 is what would lift it.

## 8. Out of scope

- Serial getty on the SIM port -- cheaper and independent; needs no console work,
  only an `/etc/ttys` entry and a `TERM` type.
- apple/fgx#37 (libc bank pressure), #34's sibling cleanups, #30.

## 9. What could not be established

- Whether any current userland changes console *mode* per session. If nothing
  does, per-VC `_conMode` can be deferred behind an explicit ruling.
- The cost of a repatch-per-background-write (194-byte loop + state swap per
  write syscall). Plausibly fine; a guess until measured. If it is not fine,
  background writes need buffering, which is a different design.
- Whether `Con_RenderAll` fully reconstructs palette state from the buffers on
  switch. Alt-screen exit suggests yes since it relies on exactly that, but the
  per-row auto-palette path was not traced end to end.
