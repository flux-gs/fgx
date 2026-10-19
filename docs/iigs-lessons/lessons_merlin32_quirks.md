# Merlin32 quirks — lessons learned

Strong suggestions when writing 65816 assembly in Merlin32 (v1.1.10, the
2015 release widely installed on macOS and Linux). The Merlin32
documentation (`merlin32:1-29` in iigs-mcp) covers syntax but doesn't
flag these traps explicitly.

These apply to ANY 65816 project in Merlin32 — not IIgs-specific.

---

## 1. `ASC` strings are HIGH-ASCII (bit 7 set)

**Symptom:** Font rendering rejects every character from your ASC-defined
strings as ">127, unprintable." Direct character literals (`#'0'`,
`#'A'`) work fine, but string data doesn't.

**Mechanism:** Merlin32's `ASC "Hello"` directive encodes 'H' as `$C8`
(bit 7 set), not `$48`. The high bit is the historical Apple "negative
ASCII" convention. Character literals via `#'0'` produce standard ASCII
($30) — inconsistent with the string directive.

**Recommended pattern:** when loading bytes from ASC-encoded strings for
font lookup, comparison, or any code path that doesn't ignore bit 7,
`AND #$7F` after the load. Or use `DCI` for the mixed-case "last byte
negative" convention if your reader expects that.

---

## 2. Merlin tracks MX state statically; branches don't update its view

**Symptom:** Code that looks correct (correct REP/SEP placement, correct
register sizes) BRKs at runtime with PC in bank `$FF` (kernel reset to
ROM). Or wild execution through what looks like valid code.

**Mechanism:** Merlin32's M/X state tracker is purely linear through the
source. A `REP #$20` mid-function makes Merlin think M=0 for every line
after it. But a branch (BEQ/BNE/BRA/JMP) from an earlier M=1 region INTO
that range leaves runtime M=1 while Merlin emits 3-byte immediates.
Off-by-one operand decode → BRK → reset.

**Recommended pattern:** put `MX %10` (or `MX %00`) directives at every
label Merlin could reach with a stale view. `MX` is a directive — emits
no code — it just tells Merlin's tracker the runtime state at that point.

**Anti-pattern:** don't add real `REP`/`SEP` at branch targets to "make
runtime match Merlin's view." That changes runtime state and breaks the
rest of the block. Use the bare `MX %xx` directive when runtime state is
already correct — fix the tracker, not the runtime.

**Symptom-to-diagnosis:** BRK/COP at a PC = label + N where N matches
the operand-byte offset of an immediate-mode instruction at the
mis-assembled width. The MX column of the assembler listing shows
Merlin's per-line view — compare against intended runtime state.

**Don't strip MX directives** in any build-system text processing
(grep-based source concatenation, etc.). If you must strip directives,
keep `MX`. (Strip only `PUT`/`ORG`.)

---

## 3. `STA $0000,X` / `LDA $0000,X` silently fold to direct-page X mode

**Symptom:** You write `STA $0000,X` in M=0 expecting `STA abs,X`
(`$9D ll hh`). Merlin emits `STA dp,X` (`$95 oo`). With DP=0 and X
non-zero, you hit `$00:00xx` instead of the intended `DBR:0000+X`.

**Mechanism:** Merlin picks the smallest addressing mode that fits the
operand. `$0000` fits in DP, so it picks dp,X. The 4-digit literal
doesn't override this.

**Recommended pattern:**
- Force absolute: `STA: $0000,X` (trailing colon) → `$9D ll hh`.
- Force long: `STAL $NN0000,X` when you want the bank in the operand.
- **Never use `LDA $0000,X` / `STA $0000,X` in Merlin32** — always pick
  `:` or `L` explicitly. The default folds to bank 0 with DP=0.

---

## 4. `STA` at M=0 into a 1-byte cell stores 2 bytes

**Symptom:** A subsequent function entry BRKs because its first opcode
was overwritten with `$00` (BRK).

**Mechanism:** `_someByte DS 1` followed immediately by code or another
field. `STA _someByte` at M=0 writes A.hi to the next address (the first
byte of the following code/data).

**Recommended pattern:** wrap single-byte stores in `SEP #$20` / `REP #$20`,
even when the value "obviously" fits in 8 bits. Merlin's encoding doesn't
change with the cell width — only the runtime M flag controls write size.

Same applies to `STAL/LDAL ,X` in M=0: those move 2 bytes per access.
Loops like `LDX #0 / STAL buf,X / INX / CPX #80 / BCC` write bytes at X
AND X+1 each iter; last iter at X=79 overruns the buffer by 1.

---

## 5. DP "word" slots holding byte values read garbage in M=0

**Symptom:** A dispatch-chain `CMP` against a state-machine slot
silently fails — every CMP falls through, no handler runs.

**Mechanism:** `_slot DS 2` populated by M=1 `STA _slot` leaves the
high byte stale. Reading at M=0 gets that low byte + whatever junk was
in the high byte. `CMP #'7'` at M=0 against `$XX37` (where XX is junk)
doesn't match `$0037`.

**Recommended pattern:**
- Prefer M=1 for byte-sized state compares.
- If you must read at M=0: `STZ _slot+1` after the M=1 STA, or read at
  M=0 + `AND #$00FF` (which only helps after the load, not for CMP).
- PHA/PLA across SEP/REP boundaries is a stack-skew minefield — stay
  in one mode, or save to a DP scratch slot instead of the stack.

Related trap: a byte-sized DP slot that aliases the LOW byte of another
module's word slot. The byte STA leaves the prior word-writer's high
byte intact. A subsequent 16-bit `LDX` against that slot pulls that
stale high byte into X.hi, indexing kilobytes past the intended table.

---

## 6. Indexed-long addressing is X-only; `label+N,X` rejected

**Symptom:** Merlin won't assemble `LDAL _fsDirBuf+4,X` ("Impossible to
decode address mode") or you tried `STAL addr,Y` and got the same.

**Mechanism:** The 65816 has NO `LDAL/STAL addr,Y` — only `,X` exists
(`$BF`/`$9F`). Merlin also won't compute compound bases for indexed-
long; the operand must be a single symbol.

**Recommended pattern:**
- Use X as the index for any LDAL/STAL.
- Define `_fsDirBuf4 EQU _fsDirBuf+4` for offset bases.
- Under `MX %10`, `CPX dp_byte_cell` reads a 16-bit word from DP — the
  high byte is garbage if the cell is byte-sized. Use `MX %11` (8-bit
  X) for byte-scoped inner loops, or store the compare as a full word.

---

## 7. `CMP abs,X` in M=0 reads a WORD; word-tables need X-step-2

**Symptom:** A decimal-print routine prints only some digits correctly.
2-digit numbers print as 0; 3-digit numbers print only the hundreds.

**Mechanism:** `DecTable DW 10000,1000,100,10,1` (a word table) + `CMP
DecTable,X` at M=0 reads 16 bits at `Table+X`. Iterating X by 1: X=0
reads $2710 (10000) ✓; X=1 straddles two entries (`$0327`/$03E8` →
$03E8 hi + $03 from prior, but the wrong word); X=2 reads $03E8 (1000)
✓; X=3 garbage; X=4 reads $0064 (100) ✓. Only even-X entries hit, and
only "obvious" multi-digit cases (1, 10, 100, 1000, 10000) print
correctly.

**Recommended pattern:** step X by 2 against word tables. `INX INX` per
iter, `CPX #2*table_length` for the bound.

---

## 8. Left-to-right expression evaluation, no precedence, 16-bit wrap

**Symptom:** A bound computed in an assembler expression turns out to be
a different value than you intended. Clean build, no warning, runtime
bug looks like "fix wasn't applied."

**Mechanism:** Merlin32 evaluates strictly left-to-right with NO operator
precedence and NO parentheses support. `A+B*C` becomes `(A+B)*C` and
wraps at 16 bits.

Example: `CPX #FGX_TASK_TBL_OFF+TASK_MAX_SLOTS*TCB_SIZE` with `$0800,
16, $40` computes `($0800+16)*$40 = $20400` truncated to `$0400` — the
exact OLD bound, masking the intended change.

**Recommended pattern:**
- Reorder so multiplication/shift folds first: `A*B+C` is fine.
- Or define an intermediate EQU with a single operator: `END EQU
  TBL_OFF+SIZE` → `CPX #END`.
- Spot-check the assembler listing whenever an expression mixes `+`/`-`
  with `*`/`/`/`<<`. The listing renders the expression structure (e.g.,
  `{A}+{B}*{C}`) showing operand-order without precedence.

---

## 9. `MVN`/`MVP` clobber X and Y unconditionally; MVP walks backward

**Symptom:** An outer loop using X as a counter runs ~40000 iterations
when it should run 24, because MVN clobbered X mid-loop.

**Mechanism:** After block move, X = src_end+1, Y = dst_end+1. MVP
walks backward, so MVP's initial X must be src_END (not src_start).

**Recommended pattern:**
- Never use X/Y as a loop counter spanning MVN/MVP. Stash in DP or on
  the stack.
- MVP setup for N bytes start_to_start: `LDX #src_start+N-1 ; LDY
  #dst_start+N-1 ; LDA #N-1 ; MVP src_bank,dst_bank`. Off-by-$80 or
  off-by-1 in src_end gives subtle sub-scanline shifts.

(See also `lessons_65816_native_mode.md` §2 — MVN clobbers DBR too.)

---

## 10. `ENT` is a label definition, not a forward declaration

**Symptom:** `Blk_Init ENT` followed by a later `Blk_Init MX %00` errors
with "duplicate label."

**Mechanism:** `ENT` marks the label as externally visible (for link
files to cross-reference), but it IS the label definition. You can't
re-declare the label below it.

**Recommended pattern:**

```
Blk_Init    ENT        ; the label is defined here
            MX  %00
            PHP
```

NOT:
```
Blk_Init    ENT
            ; ... separator ...
Blk_Init    MX  %00     ; ERROR: duplicate
            PHP
```

---

## 11. Link-file path resolution: ASM relative to link, PUT relative to source

**Symptom:** `ASM ./src/foo.s` works from one directory but not another.
`PUT ../include/bar.s` works in one source file but not in its sibling.

**Mechanism:**
- `ASM` paths in a `.link` file resolve from the link file's directory,
  not cwd.
- `PUT` paths resolve from the directory of the source containing the
  PUT (standard #include semantics).

**Recommended pattern:** keep the link file at the repo root so `ASM
src/kernel/main.s` etc. work cleanly. Use `PUT ../include/foo.s` style
in source files for cross-file includes.

Each `ASM` in a link file is a separate assembly unit with its own
symbol table. Cross-segment symbols need `ENT` in the owner + `EXT` in
the consumer. Same-named EQUs in different segments don't conflict.

**Note:** older guidance saying "LNK doesn't work, use combined source"
applies to Merlin 16+, NOT Merlin32. Merlin32 (v1.1.10 and later) does
real multi-source assembly via link files. Don't fall back to grep-based
source concatenation — it silently breaks MX-state tracking (lesson 2)
and ORG handling (lesson 13).

---

## 12. `@local` labels collide across PUT'd files

**Symptom:** Build errors with "Found label name '@xxx' in both source
files 'a.s' and 'b.s'" even though each `@xxx` is local to its own
preceding global label.

**Mechanism:** `@local` labels are scoped to the previous global label
within a file, BUT Merlin32 also enforces global uniqueness across the
union of PUT'd files and rejects duplicates.

**Recommended pattern:** when PUTting shared libs (utility functions),
prefix local labels with a short module tag: `@rm_L`, `@cat_L`, `@ls_L`,
etc. The extra characters cost nothing and immunize against silent
collision with library locals.

---

## 13. Non-contiguous `ORG` doesn't pad — the binary covers only emitted regions

**Symptom:** Code-section + data-section assembly with two `ORG`s; the
emitted binary is smaller than `last_address - first_address`. DS cells
past the second ORG turn out to be uninitialized at boot.

**Mechanism:** Merlin32 fixed-address binary output covers ONLY the
regions you emit. A second `ORG` past the first emitted region doesn't
pad the gap — DS cells after the second ORG are LABEL-ONLY reservations;
no bytes are emitted; the loader's MVN-from-image leaves that RAM
uninitialized.

**Recommended pattern:** either
- Keep data inline with code (no ORG jump), so it's in the binary image
  and boots zero-initialized as part of the image; OR
- Place data via ORG, but have an explicit zero-init (BSS clear) routine
  run at boot before anyone reads from that range.

Each subsystem then owns zero-init of its own reserved region.

---

## 14. `DUM/DEND` for struct layouts; `ERR` overflow check uses `expr-1/LIMIT`

**`DUM base / ... DS N ... / DEND`** computes label offsets from a base
address without emitting code. Perfect for memory maps, DP scratch, struct
fields. `DS N` advances the offset; labels become absolute addresses.

Replaces scattered hand-numbered EQUs — adding a region is one `DS` line.

**`ERR` fires on any non-zero expression — INCLUDING negative.** So
`ERR end-LIMIT` fires even when `end < LIMIT` (you wanted "ERROR if
end > LIMIT"). The right overflow-guard idiom is `ERR expr-1/LIMIT`:
Merlin's `/` operator (per the Merlin docs) acts as a comparison —
`A/B = 1 iff A >= B`, else 0. So `expr-1/LIMIT` is `1 iff expr > LIMIT`,
`0` otherwise — fires only on overflow.

**Recommended pattern:** comment the `ERR expr-1/LIMIT` idiom inline
where used; it's not obvious without explanation.

---

## 15. Save/restore X/Y in subroutines that use them as indices

**Symptom:** Caller's loop counter survives one iteration but is gone
after the JSR — only the first of N items in a loop renders/computes
correctly.

**Mechanism:** Merlin doesn't enforce or warn about register clobbering
across JSR. Any subroutine using X or Y as indices for LDAL/STAL/STA,X
overwrites the caller's value.

**Recommended pattern:** any subroutine using X/Y as indices must
PHX/PLX (or PHY/PLY) at entry/exit if the caller might be using those
registers — especially inner-loop helpers.

This combines badly with rule #2 (MX tracker drift) — PHA/PLA across
SEP/REP boundaries already creates stack-skew bugs; same applies to
PHX/PLX if X width changes between push and pop.

---

## 16. `TAY`/`TAX` at M=8 X=16 doesn't reliably zero-extend (MAME-specific)

See `lessons_mame_iigs_workflow.md` §3 — this is an emulator-specific
issue, not a Merlin32 bug, but it affects code that compiles correctly
under Merlin32 and runs correctly on real W65C816S hardware.

---

## 17. DP equate overlap silently when a 16-bit counter aliases an 8-bit var

**Symptom:** A 24-iteration loop runs ~6168 iterations before "coincidentally"
hitting 0. Looks like an infinite loop or a stuck wait.

**Mechanism:** `_scrollCnt EQU $FA` (intended as a 16-bit counter) and
`_scbCounter EQU $FB` (intended as 8-bit). `LDA #24 ; STA _scrollCnt ;
DEC _scrollCnt` at M=0 writes the WORD at `$FA-$FB` and decrements it
as a word. `INC _scbCounter` inside the loop bumps the high byte of
the counter. Net step per iter is +$FF instead of -1.

**Recommended pattern:** leave a full 2-byte gap after any 16-bit DP
variable, even when you only "used" the low address. Put 8-bit vars
at the END of the DP block or in the explicit gaps between 16-bit
words:

```
_word_a   EQU  $FA
_word_b   EQU  $FC
_byte_c   EQU  $FE          ; tail of the block
```

---

## 18. Default-assume MX directive on routines that start with immediates

**Symptom:** A new routine added to a source file misbehaves immediately
on first call. Bytes look right in the listing but PC doesn't end up
where you expected.

**Mechanism:** Merlin's MX state flows forward through the source file,
not through control flow. If routine A ends with `SEP #$20 ; BRA @loop ;
RTS` (common in VBL-polling delays), the RTS is assembled under M=1 —
AND SO IS EVERY SOURCE LINE AFTER IT until the next REP. If routine B
follows in source order and is entered at M=0 at runtime, immediate-
mode instructions get assembled at the wrong size.

**Recommended pattern:** at the start of any routine whose expected
entry MX differs from "wherever the assembler currently thinks we are,"
put an explicit `MX %00` (or `MX %10`) directive. Default-assume this
hint is required for any routine that uses immediate-mode instructions
AND isn't the first routine in its file.

Quick grep test: if a routine body starts with `AND #imm`, `LDA #imm`,
`CMP #imm`, `SBC #imm`, etc., AND the preceding code ends in SEP or REP
mid-function, the MX directive is mandatory.

---

## Cross-references

- `merlin32:1-29` — Merlin32 official documentation.
- WDC W65C816S datasheet — for 65816 addressing-mode semantics
  underlying many of these rules.
- Example corpus: `ddiigs`, `gno_kern` for real Merlin32 IIgs projects.
  Many of these patterns are visible in their source (with comments
  noting the quirks they avoided).
