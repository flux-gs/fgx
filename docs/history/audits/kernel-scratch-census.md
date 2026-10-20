# Deliverable 1 -- the kernel scratch census

Phase 1 of the bank-0 / kernel-scratch assessment
(`docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md`).

**Generated, not written.** Run the tool; do not quote this file:

    python3 tools/dp_scratch_census.py
    python3 tools/dp_scratch_census.py --json build/census.json

Numbers below were produced on `assess/bank0-and-kernel-scratch` at the commit
that added the tool. They will drift. The tool is the deliverable; this is its
reading.

---

## 1. The headline: most of the scratch problem is NOT a stack-size problem

| class | cells | sites | can it become a kernel-stack automatic? |
|---|---:|---:|---|
| **DP-IRREDUCIBLE** | 33 | **2,276** | **No -- at any stack size** |
| DP-INDIRECT-16 | 8 | 418 | Yes -- `(sr,S),Y` exists |
| DP-REDUCIBLE | 65 | 1,050 | Yes |

**61% of kernel direct-page sites are on cells whose DEREFERENCE cannot be done
from a stack slot as the code is addressed today.**

**CORRECTED after adversarial review -- the original wording said "cannot move
to the stack, at any stack size", and that was too strong.** Two mechanisms
defeat it, and both are already used in this kernel:

- **`D` is a retargetable 16-bit bank-0 pointer, and the kernel stack is in
  bank 0.** Point the direct page at the task's own kernel stack page and
  `[dp],Y` dereferences a *stack-resident* far pointer. The dispatcher already
  swaps `D` every syscall (`syscall.s:92-95`), and kernel C already runs its
  frames on those same per-task kernel stack pages
  (`sched.s:855-858`). Stack-and-DP coexistence in bank 0 is not hypothetical.
- **`PLB` + `(sr,S),Y`** dereferences a stack-held far pointer in about six
  instructions by swapping the data bank.

So the honest claim is **cost, not impossibility**: migrating 2,276 sites to
stack-relative addressing is not worth it, and `sr,S` alone cannot express the
dereference. That practical conclusion stands. "The hardware forbids it" does
not, and the overstatement propagated into Phase 4 and Phase 5 -- see
`docs/history/audits/bank0-assessment-review-response.md`.

Note also that the 61% counts **whole cells**: a cell with one `[cell],Y` and
100 direct `LDA`/`STA` contributes all 101 sites. Irreducibility applies at the
dereference, not at every use.

The underlying instruction-set fact is real: the 65816 has `sr,S` and
`(sr,S),Y` but **no stack-relative indirect LONG mode**, so `sr,S` alone cannot
express a 24-bit dereference. What does not follow is that no per-task home
exists -- see the two mechanisms above.

**What survives, and it still retires the charter's hypothesis:** "make the
per-task kernel stack bigger and put transients in automatics" does not address
these sites, because the blocker is the *addressing mode*, not the byte count.
More stack does not help. A different direct page does.

## 2. The count that has been circulating is wrong

`_libcTmp2` has been described as "~694 uses across ~25 files". That is a raw
grep line count. The real figure is **554 code sites in 24 files**; the other
148 hits are **comments**. Verified two ways, occurrence count and line count,
which agree exactly at 554.

## 3. The census is tractable, and the reason is a measured number

**There are 24 sleep/yield sites in 12 files.**

**CORRECTED: the first pass found 20 in 10 files and was wrong**, because
sleeps have two spellings and the census only knew one:

1. the primitive as a **jump operand** -- `JSR _sleep`;
2. the service **selector in a register** -- `LDX #KSVC_SLEEP` / `JSL
   SYS_KCALL`.

**Form 2 is how every module sleeps.** `pty.mod` (`pty.s:176-178`) and
`vfs.mod` (`kc_sys.s:121-127`) put the number in X and call the one multiplexed
entry, so the sleep's name never appears as a jump target and a name-only regex
reports those files as sleep-free. **`pty` is where apple/fgx#41 -- this bug
class's other historical defect -- actually lived.** Both tools now match both
forms.

| sites | file |
|---:|---|
| 4 | `src/kernel/jumptable.s` |
| 4 | `src/kernel/syscall.s` |
| 3 | `src/kernel/process.s` |
| 3 | `src/kernel/sched.s` |
| 2 | `src/kernel/far_shims.s` |
| 2 | `src/modules/net/net_loop.s` |
| 1 | `src/kernel/signal.s` |
| 1 | `src/kernel/net_dispatch.s` |
| 1 | `src/modules/vfs/kc_sys.s` |
| 1 | `src/modules/net/net_xport.s` |
| 1 | `src/modules/net/pipe.s` |
| 1 | `src/modules/pty/pty.s` |

A range is only at risk if it **crosses one of these 24**. Walking 554 use sites
forward was never the job; walking 24 sleep sites backward is. The charter's
"seed from the sleep sites" method is now a measurement, not a preference.

## 4. The risk shortlist

19 DP-IRREDUCIBLE cells (1,794 sites) are used in a file that also contains a
sleep site. **This is a candidate list, not a verdict** -- file-level
co-occurrence does not prove a live range crosses the sleep. Each still has to be
walked. It is ranked by exposure, so it is the order to walk them in.

| cell | sites | files that also sleep |
|---|---:|---|
| `_libcTmp2` | 554 | process, signal, syscall, net_loop, net_xport, pipe |
| `_fcbPtr` | 211 | process, syscall, net_loop, pipe |
| `_shTmp0` | 161 | process, signal, syscall |
| `_kHeapCur` | 127 | sched |
| `_kmallocResult` | 116 | jumptable, process, syscall, pipe |
| `_schedTblPtr` | 116 | process, sched, signal, syscall |
| `_sockTablePtr` | 108 | syscall, net_loop, net_xport |
| `_libcSrcPtr` | 59 | syscall |
| `_pipeTablePtr` | 57 | net_loop, pipe |
| `_fd_table_ptr` | 48 | process, syscall, net_loop |
| `fs_mount_ptr` | 43 | syscall |
| `_kCopyPtr` | 41 | syscall, pipe |
| `_sigHndPtr` | 36 | process, signal |
| `dev_table_ptr` | 29 | syscall |
| `_cdTablePtr` | 22 | jumptable |
| `_u` | 20 | process, syscall |
| `_fsCwdPtr` | 19 | sched, syscall |
| `_fsPathPtr` | 17 | far_shims |
| `_kLogBufPtr` | 10 | syscall |

### Separating base pointers from transients

Counting writes **to** the cell (`STA _cell`) rather than **through** it
(`STA [_cell],Y`) splits the list. Eight of the nineteen are written exactly
twice, in one file, at boot -- table bases every task sees identically, so
holding one across a sleep is harmless:

`_schedTblPtr` (116 sites), `_sockTablePtr` (108), `_pipeTablePtr` (57),
`fs_mount_ptr` (43), `_sigHndPtr` (36), `dev_table_ptr` (29), `_cdTablePtr`
(22), `_u` (20). Spot-verified by hand: `_schedTblPtr` is written at
`main.s:1194`/`:1197` and nowhere else; `_sockTablePtr` at `socket.s:44`/`:47`.

That takes the register from 19 cells / 1,794 sites to **11 cells / 1,363
sites**.

**One of the eight is mislabelled, and the reason matters.** `_u` points at the
*current* task's u-area, so it must change per task -- and it does, through
`_Uarea_FromSeOff` (`task.s:1535-1545`), the single funnel all nine callers go
through. Its write count is low because the code is **well factored**, not
because the value is stable. So the heuristic conflates "one writer" with "one
value", and the tool says so rather than pretending otherwise.

Chasing that turned up a second false comment: `include/kernel.s:745` says
"swtch swaps `_u`". **`sched.s` does not mention `_u` at all.** It is re-derived
on demand at each use instead, which is the safer design -- derive from the
index rather than preserve a pairing -- but the comment describes a mechanism
that does not exist. Third instance of that shape in this campaign, after the
`_Sock_PollIntr` header and the `KSVC_SLEEP` routing claim.

## 5. Tool validation

The classifier was checked in both directions before any of the above was
believed:

- **No false DP-REDUCIBLE.** All 65 cells so classified were independently
  searched for a `[cell` dereference anywhere in `src/` and `include/`.
  **0 found.** This is the dangerous direction -- a false REDUCIBLE would route
  a far pointer to a stack slot that cannot hold it.
- **No unearned DP-IRREDUCIBLE.** All 33 cells so classified have a verified
  `[cell]` dereference in the tree. **33 of 33.**
- **Count cross-checked** against an independently written occurrence counter,
  agreeing exactly (554).

A partial mutation (breaking the `[cell],Y` pattern) did **not** flip
`_libcTmp2`, because the classifier ORs that against bare `[cell]` and the bare
form is also present. That is correct behaviour, and it is recorded here so the
next reader does not mistake it for an insensitive probe -- the two independent
direction checks above are what establish soundness, not that mutation.

## 6. The range walk: no live range crosses a sleep, and that is the finding

    python3 tools/dp_sleep_ranges.py --callers

**Result: zero.** Not within a routine, and not across the kernel call graph
either. Every routine that can sleep holds no DP scratch across the switch, or
saves it.

Exactly **three** save sites exist in the whole tree, and the tool locates
precisely those and nothing else:

| routine | cell | why |
|---|---|---|
| `_Sock_PollIntr` | `_libcTmp2` | apple/fgx#100, fixed |
| `_Tty_GetByte` | `_kTtyRdPtr` | apple/fgx#41, fixed |
| `_kfp120` | `_kTtyRdPtr` | same fix, far-call arm |

`_Tty_GetByte` is worth reading as the model: `PEI (_kTtyRdPtr)` before and
`STA _kTtyRdPtr` after **all three** of its sleeps, with the reasoning written
out at each -- including that `_sleep` may return in 8-bit M/X, so the restore
needs `REP #$30` first or the pointer's high byte goes stale.

### The blind spot is where the defect was, and that is not a coincidence

The call graph is name-based, so it **cannot cross the module jump-table
dispatch seam**. Concretely, after the closure is computed:

| routine | reaches a sleep? |
|---|---|
| `_Tcp_RecvCore` | yes |
| `_Sys_Read` | yes |
| `_Sys_Ioctl` | **no** |
| `_W5_RxCopy` | **no** |

**apple/fgx#100 lived exactly there** -- staged in the dispatcher, slept in
`_Sock_PollIntr` inside `net.mod`, read back in `_W5_RxCopy`. Three routines,
two files, one module boundary. A checker built the obvious way would have been
blind to the one live defect of the class it exists to catch.

**This is the governing constraint on Phase 5's "what enforcement makes it
stick" answer.** Whatever checker is proposed must model the module seam
explicitly -- the seam is not an edge case, it is where the hazard concentrates,
because it is the one place where staging, sleeping and reading are guaranteed
to be in different compilation units.

### Tool notes -- two corrections made while building it

- **The closure must follow tail calls.** `JMP`/`JML`/`BRL` propagate "can
  sleep" exactly as `JSR`/`JSL` do; `_Net_Xport_Recv` reaches the sleeping
  `_Tcp_RecvCore` by `JMP` and was invisible until that was fixed. The closure
  went from 40 routines to 55. Under-reporting is the dangerous direction.
- **SAVED detection must be positional.** The first version matched a push and
  a store anywhere in the routine, which would mark an ordinary
  read-modify-write *across* a sleep as its own protection -- exactly backwards.
  It now requires the push before the sleep and the store after it.

Both tools were positive-controlled: a synthetic routine that stores a cell,
sleeps, and reads it back **is** flagged, so the zero above is a measurement
rather than a broken query.

## 7. What this deliverable does NOT yet contain

- **The module seam.** Both tools stop at the jump table. Extending the closure
  across it is the next increment, and Phase 5 cannot cost enforcement without
  it.
- **The IRQ column.** Which cells interrupt-time code touches is not yet
  measured. Interrupt handlers share the per-task kernel stack, so an RTC
  classification is only safe against *task* switches -- #91 is the precedent.
- **The kernel re-entry bound.** Whether any path re-enters the kernel while a
  task already holds live kernel frames is unanswered, and it bounds what a
  fixed-top per-task stack can support at any size.
