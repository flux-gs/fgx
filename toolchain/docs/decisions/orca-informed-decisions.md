# ORCA-informed decisions

ORCA/C — the ORCA/C compiler and linker source, published as **"Opus ][: The
Source"** (Copyright (c) Byte Works, Inc. / Mike Westerfield) — is a **reference
oracle only**. We mine its design judgment to settle direction, not its formats
or runtime; we do not adopt OMF, GS/OS, or ProDOS conventions.

> **That source is copyrighted.** We do **not** include or redistribute any of
> it in this repo. The file cites below point into the ORCA source for *study*;
> everything fcc ships is an independent implementation of the *concepts*, never
> ORCA code. (You need your own copy of "Opus ][: The Source" to follow the
> cites — it isn't vendored here.)

Each decision: *Context / ORCA precedent (with file cites) / FGX decision / Status / backlog*.

---

## D1 — Multibank pointer model  (status: adopted in principle; backlog item filed)

**Context.** Cross-bank pointer bugs in the vi multi-bank port repeatedly surfaced only
at *runtime* (wrong bank byte, pointer read at the wrong depth), costing multi-hour
debug sessions.

**ORCA precedent.** ORCA represents far pointers as 4 bytes (bank : 16-bit offset) and
relocates the bank and the offset **independently**. Critically, its two-pass linker
*validates that a reference and its resolved address are consistent* and errors on an
unintended cross-bank reference rather than silently emitting a wrong bank byte:
- `Source/ORCA/Linker.2.0.3/pass2.asm` — the `BExpr` (bank-expression) path checks
  bank consistency while resolving a relocation.
- `Source/ORCA/Linker.2.0.3/exp.asm` — a postfix relocation-expression evaluator that
  resolves bank and offset as separate sub-expressions.

**FGX decision.** Add a **link-time bank-consistency check to `src/ld/fgx_ld.py`**: when
the FGX2 reloc table resolves a cross-segment reference, verify the target bank matches
the relocation's expectation and *fail the link* (not the runtime) on mismatch. Turn the
class of bug that ate the vi port into a linker error.

**Backlog.** Define the check precisely against the current FGX2 reloc-table model
(`src/ld/fgx_ld.py` xref entries: `FGX2_XREF_JSL_BANK`, `FGX2_IMPORT_JSL`,
`FGX2_LONG_PTR`). Its own follow-on spec.

---

## D2 — Pointer size  (status: adopted)

**Context.** FGX unified in-struct pointers to a single 4-byte representation
(project_fcc_uniform_in_struct_pointers_landed).

**ORCA precedent.** ORCA far pointers are 4 bytes (bank + 16-bit offset); near vs. far is
selected by the program's memory model (small/large). See the `cgPointer` type and
addressing-mode handling in `MPW-IIGS ORCA:C Source/CGI.p` and `ExpressionUnit.p`.

**FGX decision.** Ratify **uniform 4-byte (far) pointers** with a single memory model —
no near/far split. The simplicity (one pointer representation everywhere) outweighs the
density ORCA buys with a small model, given FGX's multibank-by-default userland. Document
so future contributors don't reintroduce a 2-byte/near pointer path.

---

## D3 — `long long` on the 65816  (status: deferred, directional only — no implementation)

**Context.** fcc currently has 32-bit `long` (A = low word, `_fcc_long_hi` DP = high word).
`long long` (64-bit) is not yet a type.

**ORCA precedent.** ORCA handles wide integers via software runtime routines (the 65816
has no 64-bit hardware path); wide arithmetic is open-coded / helper-called in the code
generator, not special-cased in silicon.

**FGX direction (when needed).** Implement `long long` as 64-bit via **runtime helper
routines** in `lib/fcc_runtime.s`, extending the existing 32-bit `long` pattern (low word
in A, additional high words in DP scratch / on the stack). No implementation now — this
records the intended shape so the eventual work doesn't relitigate the approach.
