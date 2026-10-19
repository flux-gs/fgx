# 65816 native-mode lessons learned

Strong suggestions for IIgs native-mode (e=0) programming, beyond what the
WDC datasheet and the IIgs manuals spell out. Symptoms → mechanism →
recommended pattern.

---

## 1. `JML [abs]` (opcode `$DC`) reads its 24-bit target from BANK 0, not DBR

**Symptom:** Indirect long jump lands in random memory; PB ends up wherever
the bytes at `bank-0:operand` happen to point. The compiled code looks fine
because Merlin32 emits `JML [longjmp_target]` correctly; the data structure
the operand points at is in the binary's own bank, but the CPU fetches it
from bank 0.

**Mechanism:** WDC datasheet specifies that `JML [abs]` does its indirect
read at `00:operand`, NOT at `DBR:operand`. This is asymmetric with most
other `[abs]` modes and easy to miss when the binary's data is in a non-zero
bank.

**Recommended pattern:** for cross-bank "jump to (variable target)", build
a synthesized RTL frame on the stack and RTL into it:

```
            ; Want: jump to long ptr at `target`.
            ; Stack layout RTL wants (low to high): PCL, PCH, PB.
            ; Push PB first, then PC, then RTL.
            SEP   #$20
            LDA   target+2          ; target.bank
            PHA
            REP   #$20
            LDA   target             ; target.lo16
            DEC                      ; RTL increments by 1
            PHA
            RTL
```

Bit FGX's setjmp/longjmp on its first run — `longjmp` stored its
target as `DA jmpbuf+4` in the binary's bank and used `JML [jmpbuf+4]`. The
indirect read returned $0047 from random bank-0 junk; PC jumped to wild
address.

---

## 2. `MVN` and `MVP` clobber DBR as a side effect

**Symptom:** Firmware or kernel calls after an `MVN` execute with the wrong
DBR; abs and abs,X loads/stores hit the wrong bank. Typically manifests as
"the routine ran fine in isolation but corrupted memory when called after
a block-move."

**Mechanism:** WDC datasheet: `MVN src,dst` and `MVP src,dst` set
DBR=dst_bank as part of their semantics — the operand becomes "live" in
DBR after the move. This is rarely emphasized in tutorial material.

**MVN/MVP also clobber X and Y**: after the move, X=src_end+1 and Y=dst_end+1.

**MVP walks BACKWARD**: initial X = src_END, not src_start. For N bytes
from src_start to dst_start: `LDX #src_start+N-1`, `LDY #dst_start+N-1`,
`LDA #N-1`, `MVP src_bank,dst_bank`.

**Recommended pattern:**
- After any `MVN`/`MVP`, immediately reset DBR with `PHK / PLB` (or to a
  saved value if not kernel-bank).
- Never use X/Y as a loop counter spanning `MVN/MVP` — put counters in DP
  or on the stack.
- When transitioning emulation→native (e=0), explicitly `TCD` to a known
  DP value before any DP-relative addressing — emulation mode forces DP=0
  and that doesn't carry into native.

---

## 3. The D (direct page) register can only point into bank 0

**Symptom:** Set D to `$02:0000` and the next DP-indirect access fails or
hits bank 0 anyway.

**Mechanism:** The 65816 D register is 16 bits, and DP-relative addressing
mode hard-wires the high byte of the effective address to bank 0. There is
no way to put DP in bank $01+.

**Recommended pattern:** allocate DP pages in bank 0 only. On the IIgs with
Memory Manager active, use
`NewHandle(size=$100, attr=attrPage|attrLocked|attrBank|attrNoCross, bank=$00)`
to get a tracked bank-0 page-aligned handle.

---

## 4. Stale flags after STA / PLY / etc. silently invalidate the next BNE/BEQ

**Symptom:** A `CMP / BEQ` test that should pass takes the wrong branch.
Code looks correct; the comparison value is right.

**Mechanism:** `STA`, `STX`, `STY` **do not** set N/Z flags. `PLA`, `PLX`,
`PLY`, `PLB`, `PLD`, `PLP` (and `LDA/LDX/LDY`) **do** set N/Z based on the
pulled/loaded value. If a CMP is followed by any of those before the
branch, the branch tests the wrong condition.

**Recommended pattern:** keep CMP and its dependent branch adjacent. If
you must pull/load something between them, re-test before branching (re-do
the CMP, or `ORA #0` to set Z from A without changing A). When debugging a
wrong-going branch, audit the 3–4 instructions before it for any flag-
setting pull/load.

---

## 5. Native-mode dispatch setup — the four traps

**Symptom:** First few syscalls/dispatches after entering native mode
(`CLC / XCE`) work, then a subsequent call BRKs or jumps wild.

**Mechanism:** Native mode's defaults are NOT clean — they inherit
emulation-mode state in surprising ways.

**Four invariants to set explicitly after `CLC / XCE`**:

1. **DBR is undefined at native-mode entry.** Set it: `PHK / PLB` to track
   PB, or load a known value via PHA/PLB with a constant.

2. **DP is 0 after emulation→native transit** — emulation mode forces D=0.
   `TCD` to your intended DP before any DP-relative access.

3. **`JMP (abs)` always reads from bank 0**, like JML[abs] in lesson #1.
   Build indirect cross-bank jumps via synthesized RTL frames or use
   `JMP ($00xx,X)` if the dispatch table genuinely is in bank 0.

4. **The COP vector at $00:E4-E5 (bank-1 in some configs) may be in ROM
   or LC RAM** that you can't write through `STA $00FFE4`. If you need a
   custom COP handler, install it through the IIgs soft-vector system
   ($00:0100-$00:01FF) — or use `JSL` + a signature byte trampoline
   instead of COP for "syscall" patterns. (FGX uses the latter — a
   trampoline at `$00:0328` containing `JML kernel_dispatcher`, called
   as `JSL $000328 / DFB syscall_num`.)

---

## 6. Toolbox calls' 4-byte arguments and results: hi-word first on stack,
lo-word on top after PLA

**Symptom:** PLAing what should be a long pointer returns garbage; or
calling a Toolbox routine that takes a 4-byte arg crashes.

**Mechanism:** IIgs Toolbox convention for 4-byte (long) values on the
stack is "high word pushed first, low word pushed second, so the low word
sits on TOP." On a `PLA` (16-bit), you get the low word back. Subsequent
`PLA` gives the high word.

This is consistent with Apple's pascal-style stack but easy to invert if
you're thinking C-style (little-endian byte order in memory).

**Recommended pattern when reading 4-byte results back:**

```
            ; Toolbox call that returns a 4-byte handle:
            PEA   0                  ; reserve hi word
            PEA   0                  ; reserve lo word
            _NewHandle               ; or whatever
            PLA                      ; lo word
            STA   handle             ; in memory: handle.lo
            PLA                      ; hi word
            STA   handle+2           ; handle.hi
```

**Watch out:** `PLX` after a 4-byte result pops the result's LOW word,
NOT a previously-saved X. Save caller registers BEFORE the toolbox stack
frame, and read them back via `n,S` indexing while results are still on
the stack.

---

## 7. SmartPort 16-bit buffer overlaps bank-0 $2000-$21FF

**Symptom:** Task stacks or other data structures below $2200 in bank 0
get clobbered on every SmartPort I/O call.

**Mechanism:** SmartPort's 16-bit dispatch routine uses `$00:2000-$00:21FF`
as a staging buffer for block reads/writes. Any user data in that range
is overwritten on every disk access.

**Recommended pattern:** keep task/user stacks and any per-call state
above `$00:2200`. The range `$00:0000-$00:1FFF` is generally free for
direct-page allocations, soft-vector use, and stage-2 loaders before
SmartPort is invoked.

---

## Cross-references

- 65816 architecture: WDC W65C816S datasheet sections 7-8 (addressing
  modes) and 16 (instruction set summary).
- `firmware_ref:46-49` (IIgs Firmware Reference) — soft vector layout.
- `programming_iigs_part1:83-86` — soft switches including 80STORE which
  affects auxiliary text-page writes (see also `lessons_iigs_hardware_firmware.md`).
