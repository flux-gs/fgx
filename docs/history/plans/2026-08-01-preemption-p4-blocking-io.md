# Preemption P4 — blocking-I/O completion: implementation plan

**Chartered:** `docs/history/plans/2026-07-17-preemption-campaign-roadmap.md` (P4).
**Planned:** 2026-08-01, for execution in a later session.
**Base:** `main` @ `559a74dd3` or later.

**Goal.** Every place a task waits, it sleeps — and every sleep is interruptible
by a signal. Then preemption and sleep compose into real concurrency, and the
TCP-server payoff demo becomes possible.

**Prerequisites: ALL MET.** P0/P1/P2'/P3 shipped in v1.10.0 (toolchain v1.15.0).
The BSD-foundations campaign supplied per-task fd tables, WCHAN sleep/wakeup,
per-task kernel stacks and user DP pages, and FS state proven safe across
arbitrary syscall-boundary interleaving. Nothing blocks this train.

---

## What changed on 2026-08-01, and why it shrinks this train

Issue #2 (`^C` killed no blocked reader) was fixed by making **`_sleep` itself**
signal-aware rather than patching `Con_GetKey`:

```
_sleep   In:  A = chan, X = pri
         Out: C=1  -> a signal will act on this task at the next dispatcher
                      boundary.  ABANDON the wait and return (EINTR).
              C=0  -> ordinary wake; re-test the condition and carry on.
         Checked BEFORE blocking and AFTER waking.  A/X/Y unchanged.
```

`_Sig_PendingActionable` (`signal.s`) is the predicate: pending AND unblocked AND
not ignored, per BSD. Cheap fast path (one 32-bit OR) when nothing is pending.

**This is the primitive P4 was going to have to build first.** It already exists,
it is tested, and two of the tasks below are now "consume a carry flag" rather
than "design interruptible waiting".

---

## The finding that should drive task ordering

`recv`/`accept` and pipe reads are **already asleep** — they are not busy-polls.
The charter's "sleep instead of poll" framing is therefore only half right, and
the half that is wrong is the more urgent half.

Both blocking helpers are structurally identical twins:

| | net.mod | pipe |
|---|---|---|
| helper | `@spi_block` (`src/modules/net/net_xport.s:~1140`) | `_Pipe_PollIntr` (`src/kernel/pipe.s:~780`) |
| interrupt check | `JSL SYS_NETKC_CONPOLLKEY`, `CMP #$03` | `JSL KFAR_CON_POLLKEY`, `CMP #$03` |
| sleeps via | `JSL SYS_NETKC_SLEEP` -> `_Net_KCall_Sleep` -> `_sleep` | `JSR _sleep` |
| after sleep | `CLC` unconditionally | `CLC` unconditionally |

Both **peek the keyboard ring for a literal `$03` byte**. That check cannot fire
when a shell owns the tty: the heartbeat consumes `^C` as a SIGNAL
(`_kTtySigReq`) and never enqueues the byte. This is the exact bug class fixed in
the console on 2026-08-01 — **still live in these two paths**.

And both already call a `_sleep` that now returns the answer in carry, and throw
it away.

So: `recv`, `accept` and a pipe read **cannot be interrupted by `^C` under tcsh
or bsh-with-job-control today**. T1 and T2 fix that by deleting code.

---

## Task order and rationale

T1/T2 first: highest value, smallest diff, and they retire the bespoke ^C peeking
that would otherwise have to be carried through the rest of the train.

---

### T1 — net.mod: consume `_sleep`'s carry, delete the `^C` peek

**Files:** `src/modules/net/net_xport.s` (`@spi_block` and its callers).

**Steps**

- [ ] Confirm carry survives the module thunk. `_Net_KCall_Sleep`
      (`net_dispatch.s:~166`) is `JSR _sleep / RTL`, and `MOD_JT` dispatch does not
      touch carry. **Verify by reading the JT gateway** before relying on it; if
      it does clobber carry, stage the result in a module static instead.
- [ ] Replace the `SYS_NETKC_CONPOLLKEY` + `CMP #$03` prologue with nothing. The
      whole "peek a key, ignore it unless it is `$03`" block goes away, including
      `@spi_intr`'s separate exit — *keep* the `SEC` return, it becomes the
      signal-interrupt exit.
- [ ] After `JSL SYS_NETKC_SLEEP`, branch on carry: C=1 -> restore scratch, `SEC`
      (interrupted); C=0 -> restore scratch, `CLC` (caller re-checks and retries).
      **The scratch restore must run on BOTH paths** — the `_sock*` save/restore
      brackets the sleep and is not optional.
- [ ] Confirm the callers of `@spi_block` (`net_xport.s` recv/accept loops) treat
      `SEC` as "return EINTR to userland" and not as a generic error.

**Test:** a probe that `nc`s to a dead port under tcsh and sends `^C`; the tool
must exit rather than hang. Model it on `tools/mame_test/probes/ntp_ctrlc_tcsh.json`.
**Inject the bug to prove the probe fails without the fix** — see "Testing traps".

---

### T2 — pipe: the same change, same shape

**Files:** `src/kernel/pipe.s` (`_Pipe_PollIntr`).

Identical to T1 but simpler: `_Pipe_PollIntr` calls `_sleep` directly (no module
thunk), so carry is already in hand.

- [ ] Delete the `_Tty_CurIsFg` + `KFAR_CON_POLLKEY` + `CMP #$03` prologue.
- [ ] Branch on `_sleep`'s carry after the `_pipe*` scratch restore; `SEC` =
      interrupted, `CLC` = retry.
- [ ] `_kfp110` disappears with the poll call. **Regenerate the far patch tables**
      (`gen_far_bankpatch.py`, both invocations) — the guard will catch staleness,
      but only after the fact.

**Test:** `yes | head -1` style pipeline, or a reader blocked on an empty pipe,
interrupted with `^C`.

---

### T3 — serial: decide whether it needs anything at all

**Investigation task — do not assume it does.**

`serial_read` (`src/modules/serial/serial.s:~289`) is documented
*"one-byte non-blocking read"*, returning `EAGAIN` when the RX register is empty.
`tip`/`cu` is FGX-native and *deliberately* spins: *"one non-blocking poll loop
bridges the console and the line."*

- [ ] Decide the question: is a **blocking** serial read wanted (a `WCHAN_SERIAL`
      sleeper woken by the SCC RX IRQ), or is the non-blocking + poll model
      correct for a terminal program that must service two sources?
- [ ] If blocking is wanted: add `WCHAN_SERIAL` to `include/kernel.s`, wake it
      from the SCC RX interrupt handler, and give `serial_read` a blocking mode.
      Note the constraint from the campaign's showstopper register: **the
      heartbeat and any IRQ-level code must stay switch-free** — the ISR may call
      `_wakeup`, never `_sleep`.
- [ ] If not: record the decision in the roadmap and close this task. A poll loop
      that services two sources is a legitimate design, not a defect.

**My reading:** `tip` genuinely needs to watch console *and* line, so it wants
`select` (which landed) rather than a blocking read. Likely outcome is "no kernel
work; consider porting `tip` to `select`."

---

### T4 — retire the `_kYieldReq` keyboard special-case

**Files:** `src/kernel/toolbox.s` (`:332`, `:451`), `src/kernel/sched.s` (`:547`),
`src/kernel/syscall.s` (`:290-293`), `include/memmap.s` (the
`KFGX_YIELD_MIRROR` note).

The charter's second deliverable. `_kYieldReq` is set from two places — quantum
expiry (`sched.s`) and a keypress (`toolbox.s:451`) — and consumed at the
dispatcher boundary. The keypress arm is the F5 hack; the quantum arm is the
general mechanism.

- [ ] Establish what the keypress arm still buys once a blocked reader is woken
      properly. `swtch` already blanket-wakes `WCHAN_KBD` on every switch
      (`sched.s:~149-170`), which is the other half of the same hack.
- [ ] Retire the keypress `_kYieldReq` write, keeping the quantum one.
- [ ] Only then consider the blanket-wake. **These two are a pair** — removing
      one without the other risks a foreground shell that never wakes under a
      busy background task, which is exactly what the F5 comment says the hack
      exists to prevent.
- [ ] Regression: `spin_yield` (bg spinner must not freeze the fg) and
      `spin_sigint` (`^C` kills a hung fg loop) were P2''s acceptance probes.
      **Recreate them if absent** — they are the tests that make this task safe.

---

### T5 — the blanket-wake cost (do only with measurement)

`swtch` wakes every `WCHAN_KBD`/`WCHAN_SOCK` sleeper on **every** switch. At the
current 66 ms quantum that is ~15 wake-poll-sleep cycles/sec per sleeper —
harmless today, and the campaign doc explicitly says *"nobody tightens the
quantum without re-checking that cost."*

- [ ] Treat as a **precondition on any future quantum change**, not as work in
      its own right. Measure before touching.

---

### T6 — the payoff demo: a TCP server

The charter's stated deliverable. `SYS_LISTEN`/`SYS_ACCEPT` and `echod` already
exist; what P4 adds is that a blocked `accept` does not stall the machine.

- [ ] Demonstrate `echod` serving a connection while the foreground shell stays
      interactive.
- [ ] Probe under `tools/mame_test/probes/` (gitignored), not `tests/` — it needs
      a real network peer, like `boot_netstart`.

---

## Testing traps — all three produced FALSE results on 2026-08-01

Read these before writing a probe. Each cost a wrong conclusion.

1. **`raw_inject`'s ctrl flag does not map `'c'` to `$03`.** It only disambiguates
   the four arrow-collision keys (`$08/$0A/$0B/$15`). **Inject key `3`.** On real
   hardware the Mega II latch already delivers the control code.
2. **Never sentinel with a literal string a still-running program could echo.**
   `cat` echoes stdin, so a literal sentinel "passes" whether or not it died. Use
   shell expansion (`echo X${HOME}X` -> `X/rootX`) — only a live shell produces it.
3. **Ordering:** the `^C` injection must land *between* the child starting and the
   sentinel being typed, or the sentinel is merely echoed by the still-live child.
4. **Prove the probe FAILS without the fix.** Every probe in this train guards a
   path that is currently broken, so each one must be demonstrated red first.

## Build hygiene

- Kernel layout changes require regenerating `w5100_patchsites.s` and **both**
  `gen_far_bankpatch.py` invocations. Guards catch staleness after the fact.
- `tools/gate.sh` must stay green; it invokes `smoke` by name, so adding files
  under `tests/` does not lengthen it.
- Existing probes to re-run as regressions: `ntp_ctrlc_tcsh`, `ntp_ctrlc_bsh`,
  `ntp_q_bsh`, `tcsh_ctrlc_cat`, `vtvi`, `vtbell`, `vtclear`, `vtcolor`.

## Out of scope

- `poll()` — no customer; zero files in the vendored 2.11BSD tree call it.
- Model B (kernel-preemptible) — one shared kernel DP page rules it out; Model A
  is ratified.
- Connected-UDP `connect()`/`getpeername` — independent, gated on a socket-record
  resize.
