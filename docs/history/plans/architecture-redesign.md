# FGX + fcc: Architecture Review & Redesign Path

> **STATUS 2026-07-30 — much of this has LANDED; read it as history plus
> open items, not as a live defect list.** Verified fixed since writing: the
> five "live defects" in Part I.6 (MVN $00,$00, wrong-bank/missing shims,
> setjmp PHK, signal/kill stubs, the doc-drift trio); the libc indictment
> (single source under `toolchain/lib/`, real varargs printf, real errno);
> the T4 soft-stack deletion (locals are hw-stack frame-base now); the D1
> link-time bank-consistency gate (`toolchain/src/ld/fgx_ld.py`); and most of
> the "missing wholesale" syscalls (mkdir/rmdir/rename/select/brk/fork/kill,
> epoch time, real signal delivery, environ). Phase gating that references
> "the MAME suite" predates its deletion — the gate is now `tools/gate.sh`.


> **Adjunct to [ROADMAP.md](../../ROADMAP.md).** The ROADMAP says what's next; this
> document says what's *structurally wrong*, what the target architecture is,
> and the staged path from here to there. Written 2026-07-05 from a verified
> audit of both repos, the memory ledger, `examples/65816-llvm-mos`,
> `examples/gno`, and 2.11BSD. Evidence archive (per-claim verdicts, full
> tables): [`docs/history/audits/2026-07-05-fgx-fcc-arch-audit/`](../audits/2026-07-05-fgx-fcc-arch-audit).
>
> Standing constraints honored throughout: **clean break allowed** (all
> software is in-tree; the ABI may change wholesale), **fcc remains the
> compiler** (self-hosting north star; llvm-mos is a design reference only),
> goals remain a multitasking Unix on the IIgs with active 2.11BSD porting.

---

## Part I — Diagnosis

### I.1 The disease: the bank byte is nobody's job

The 65816 splits every address into a 16-bit offset plus an 8-bit bank, and
FGX/fcc handle the two halves with different machinery at every level. Offsets
are first-class values (they travel in A, in slots, in structs); **banks are
ambient state** — recomputed, assumed, or stashed in shared scratch at each
site that needs one. Every recorded "multibank bug" is a specialization of
that one fact. The same design pattern — *correctness by per-site discipline
rather than by construction* — repeats at four independent layers:

1. **fcc codegen.** The type word (`tword.h`) carries no address-space
   attribute, and the IR carries no pointer semantics, so the bank source is
   chosen independently at each emission site from context: 68 lines of
   PHK/PHB across the three emitter files (21 "clean" decision sites per the
   flip matrix), 52 distinct writes of a bank byte into the single shared DP
   slot `_fcc_ptr+2`, 13 forced-bank-0 `LDAL/STAL` emissions, one hardcoded
   `MVN $00,$00`. A pointer rvalue travels as A = 16-bit offset with its bank
   in that one global slot, so **any nested evaluation clobbers the bank
   half** — sites defensively re-stage it ("parse_expr may have clobbered
   _fcc_ptr+2", emit.c:2218). ~98% of emission is the `IR_TEXT` escape hatch
   (1,600 `ir_emitf` sites vs 36 structured-op sites), so no compiler pass can
   even see a bank decision, let alone verify one.
2. **libc/runtime.** Five bank-correctness rules exist only as prose comments
   memorializing past runtime bugs (data-read-via-DBR must live in
   `libc_data.s`; shims filling caller buffers must use the pushed far-ptr
   bank; `LIBC_DP_LP0` marshalling; crt0-scratch-in-pad; DP-map partitioning).
   24 hand-rolled PHB/PLB swap sequences implement the discipline — and the
   audit found **9 shims that don't** (§I.8).
3. **Kernel ABI.** Pointer args cross the syscall boundary as bare 16-bit
   offsets; the kernel captures exactly **one** bank per call
   (`_Sys_CallerBank` = caller's DBR at the JSL). Multi-pointer syscalls whose
   pointers live in different banks (stat path + soft-stack buf) are
   *inexpressible*; the workarounds (argblk families, `TCB_DataBank` for
   deferred waitpid writes) are themselves evidence of the missing primitive.
4. **Kernel internals.** `calling-conventions.md` is a hand-maintained
   clobber-list discipline ("anything that allocates eats `_libcTmp2`")
   enforced by header comments — the same correctness-by-discipline pattern,
   pre-dating multibank entirely.

**Why the bugs keep coming:** every wrong bank choice is *byte-identical to
the right one* in a single-bank build (PB == DBR makes PHK ≡ PHB; bank-0
aliasing is write/read-symmetric). Multibank is an opt-in mode
(`--far-calls`/`--data-segment`) layered over a single-bank default, and the
golden/oracle harness passed no `--data-segment` until the task-#56 oracle
landed 2026-07-05 — so for seven weeks, **real ports were the test suite**,
one crash per mole.

### I.2 The quantified whack-a-mole

The recorded corpus: **~45–55 distinct bank/far-pointer miscompile fixes in
48 days** (2026-05-18 → 2026-07-05), touching >90 sites, with a flat arrival
rate (7 landed in the final week). A flat rate is the signature of a
structural defect population being *sampled by workload*, not a finite bug
tail being exhausted. The corpus collapses into ~10 root-cause classes (full
taxonomy in the archive), all reducible to four structural facts: bank not in
the value; bank source per-site; single-bank invisibility; and a width/model
retrofit (2-byte → 4-byte pointers, then far-calls, then data-segment, then
soft-stack) where **each workaround layer created its own bug
sub-population**. The soft stack alone minted the caller-buffer-bank shim
rule, the bank-0 local-aggregate class, and the Y-clobber family.

### I.3 One running C function spans four banks

Under FGX2 + soft stack, a single executing function's state lives in: the
**code** bank (PB), the **data** bank (DBR), the **soft-stack** bank (locals,
via `[_fcc_ssp],Y` into a kernel heap bank), and **bank 0** (return addresses
and stack-passed args) — with the heap (malloc'd objects in kernel banks
$07–$09) as a fifth class. Every codegen site, every libc shim, and every
kernel handler must pick correctly among them. This is the state-space
explosion that makes the per-site convention untenable: the convention has
~70 emission sites × 4+ bank sources to get right, forever.

The soft stack — the newest layer — was **policy, not hardware** (verified,
archive `softstack-deletion.md`): elvis `add()`'s 4.2KB frame tripped fcc's
own 4KB slot cap, which mirrored a 4KB arena-window knob. The measured frame
distribution is median 4 B, 82% ≤ 16 B. GNO ran NPROC≈32 with *all* C locals
on bank-0 hardware stacks (D = frame) on identical hardware, with per-binary
declared stack sizes — a mechanism FGX already has (`stack_pages_hint`).

### I.4 fcc front-end: no tokens, no AST — replay and duplication

The front-end is single-pass parse-and-emit with **no token stream and no
AST**: `scan_tok()` lexes directly from a mutable stack of raw text buffers
that pop *and free* as they exhaust; tokens point into live buffers
(`Tok.id_ptr`). Every right-context decision is save-position / scan-forward /
**re-lex the source** — ~17 such sites, protected by three accreted
generations of machinery (raw pos saves → `LexPeek` frame checkpoints → a
32-slot deferred-free retire ring), each generation added after a shipped
crash (six distinct UAF/replay bugs in the record). The for-step is re-lexed
after the body; switch bodies are lexed twice; paren-lvalue statements go
through a raw *character-level* mini-parser that walks pp-frame internals.

Because code is emitted during parsing, statements are dispatched by
leading-token shape, which forced **eight duplicated call-marshalling
emitters** (six in parse_expr.c, two in parse_stmt.c — fcc.h itself calls the
stmt path "a full duplicate of the call handlers") plus mirrored deref-store,
member-store, and printf-family handlers. The arms have *diverged before*
(the L-to-R/R-to-L varargs drift) and are **diverged right now** (§I.8, bug
#1). Symbol identity is a mutable array index; prototype promotion renumbers
every function and requires remap sweeps that were missed once (vikeys).

The "memory frugality" rationale for single-pass is false: fcc's static
tables are already ~1MB, far beyond any 65816 budget, while `ir.c`'s
per-function record/replay buffer already proves per-function buffering
works. The front-end rewrite is not blocked by the self-hosting north star —
the tables need a redesign for self-hosting *either way*.

### I.5 The libc pile: two hand-synced sources, N copies at runtime, fakes

- **Dual source copies:** `src/userland/lib/libc.s` and
  `toolchain/lib/libc.s` are hand-synced (9 syncs in 17 days) with live
  semantic drift *today* (the tc_ti/tc_te alt-screen caps disagree — one of
  them is lying to elvis). Every FGX binary links the FGX-side libc plus the
  toolchain-side runtime/shims, so both copies are pinned to one ABI.
- **Per-bank duplication:** the ~11.3KB runtime pile (crt0 + fcc_runtime +
  libc + shims + args) is PUT into **every code bank** of a multi-bank binary
  — measured 45,212 B of pure redundancy in elvis (4 extra copies).
- **Double implementation:** every libc function exists twice in the same
  binary — a bank-blind register-ABI core plus a `c_*` stack-ABI shim where
  all bank correctness lives.
- **The surface is baked into the compiler:** an 83-entry `g_libc_bindings`
  table in fcc source maps C names to shims; printf-family varargs compile to
  stores into non-reentrant static slots (9-arg cap) — the four printf names
  can never be written in C under this ABI.
- **Fakes shipped as libc:** `getenv` returns `"vt100"` for any name starting
  with 'T'; `signal`/`kill` are no-op *success* stubs that **shadow real
  implementations in libc.s** (elvis's machine layer believes the opposite);
  `tgetent` accepts anything; `popen`/`fgets` return NULL; `alarm` returns 0.
- **errno is a fiction:** declared in errno.h ("libc defines and sets it"),
  defined nowhere in libc, never written; kernel-computed errnos are flattened
  to −1 and discarded at the C boundary.

### I.6 The kernel ABI bakes in accidents

- **fcc's 2-byte-per-struct-member layout is the wire format**: `sgttyb` is
  10 bytes of all-shorts (BSD: 6), `tchars` 12 — by explicit design, "to
  match fcc". No byte-exact BSD struct can exist, and fixing fcc's layout
  later breaks the kernel ABI. This must be unwound *before* more wire
  structs accumulate.
- **No brk/sbrk** — malloc is a syscall returning `{bank,offset}` into kernel
  heap banks, so heap/data/stack/code are cross-bank *by construction*.
- **Missing wholesale:** mkdir/rmdir/rename/link/chmod/chown/utime/truncate/
  access/sync/fsync at every layer (editors can't do atomic rename-save); no
  epoch time (`time`/`gettimeofday` absent, stat times zeroed while the
  kernel *holds* ProDOS dates); signals delivered only at syscall exit with a
  register+RTL handler ABI no fcc function can satisfy; ioctl = 7 tty
  requests, no TIOCGWINSZ/FIONREAD; no fcntl/O_NONBLOCK; no select/poll (and
  SYS_POLLKEY's destructive read makes emulation impossible); envp is staged
  on the child stack by the loader **and never read by crt0** — the
  environment is half-built, not absent.
- **Four hand-synced copies of the syscall surface** (loader.s EQUs,
  fgx_syscalls.inc, inline DFBs, doc table), with visible drift.

### I.7 The memory system: whole-bank granularity, zero sharing

- A running elvis pins **~414KB (29% of the 22-bank user pool)** for 350KB of
  content: 5 code banks + 1 data bank (whole-bank granularity; one 26KB-dead
  tail bank), a 16KB soft stack, bank-0 slivers. Waste ≈ 104KB/instance
  (~25%): 45KB duplicate libc + 43KB bank tails + a mostly-idle soft stack.
- On a 4MB machine, banks $20–$3F (2MB — half of RAM) are "kernel-managed,
  not user-allocatable today". The scarce pool is artificially small.
- **The loader shares nothing**: every spawn re-reads the binary from disk,
  relocs are patched *into the code image in place* (1,728 sites for elvis),
  the `RODATA` segment-kind byte is defined and never read. Two shells = two
  full copies of everything.
- Kernel modules each burn a whole bank (~187KB dead across NET/SERIAL/BPF);
  the kernel itself sits at 45,237B of a 55,040B one-bank box, with the DP
  page full — both fronts at their ceilings.
- The single 64KB data segment caps every big program's globals: elvis is at
  53.3KB (83%). The next big port hits this wall.

### I.8 Live defects found *by this audit* (fix regardless of redesign)

1. **fcc miscompile (drift class, active):** statement-context struct-by-value
   argument copy still emits `MVN $00,$00` + PHK/PLB (parse_stmt.c:3400-3411)
   while the expression-context twin was made bank-aware (48b83d4). Wrong
   source bank for soft-stack/data structs and leaves DBR=PB. The flip matrix
   graded this site "inert" because only the PHK was flipped, never the MVN
   banks. Needs a stmt-context oracle construct (c26) + the fix.
2. **9 latent wrong-bank shims** (archive `syscall-abi-widening.md`): c_pipe,
   c_bind, c_connect, c_sendto, c_recvfrom, c_send, c_recv, c_system, c_atoi
   all drop the caller's pushed bank today (soft-stack/bank-0 callers break).
   c_getcwd/c_listdir/c_gets/c_fstat/c_wait have no bindings at all.
3. **setjmp same-bank PHK** (libc.s:2706) — breaks under any shared-libc
   layout; ~10-line fix.
4. **signal/kill no-op shims shadow real libc.s wrappers** — elvis's signal()
   installs silently vanish (contradicts system.c:98-103's belief).
5. **Doc drift:** userland-abi.md:150 ("n_data_segment pinned to 0") vs
   fgx_ld.py:318-320 and gen_elvis_link.py:120 (data = last segment;
   gen_elvis_link.py has since retired, SP5 step 3);
   `_Sys_CallerBank` comment at syscall.s:378 says "PB", code says DBR;
   tc_ti/tc_te copy divergence.

### I.9 How it got here (so the redesign doesn't re-learn it)

Every multibank layer was adopted under a specific port's deadline, in days,
and every recorded "revisit later" alternative was never revisited: the FGX2
spec gated multi-segment on measurement and was implemented the same evening;
the shared-libc alternative was recorded twice (2026-05-18, 2026-05-31) and
never costed; the ORCA-informed **D1 link-time bank-consistency check was
adopted in principle 2026-06-01 and never implemented** — the one cheap
deterministic guard on this bug class, shelved for a month of runtime
whack-a-mole. Lessons already paid for, to carry forward verbatim: JML [abs]
indirects through bank 0 only; DBR-read libc data lives in the data segment;
shims use the pushed far-ptr bank; and *any bank rule that is a convention
rather than a checked contract will be violated by the next port*.

---

## Part II — What the references teach

**GNO/ORCA (same hardware, shipped, self-hosted):** every C pointer is 4
bytes with the bank *in the value* — no near/far split exists anywhere in the
tree; locals/params live on the bank-0 hardware stack with D as the frame
pointer, so `&local` is bank-0 by construction and deref uses the 65816's one
bank-agnostic primitive (DP-indirect). DBR is a single global invariant with
one annotated escape hatch (`#pragma databank`) at foreign entry points.
Large programs are OMF segments relocated by the System Loader; **libc is
linked once per program** into named segments and reached by uniform JSL/RTL
— per-bank duplication exists nowhere. The kernel is called in the caller's
context with full 24-bit pointers; errno returns via a caller-supplied
pointer. It ran 32 BSD signals, job control, select, ptys, preemptive
scheduling, NPROC=32 — and ported vi, less, make, awk, sed. Avoid-list: fd
0/1/2 remapped to 1/2/3, environment-in-shell-variables leaking across exec,
the GS/OS big lock, all stacks sharing bank 0's 64KB, no symlinks. ORCA/C
self-hosted on the IIgs: **the uniform-4-byte-pointer model and self-hosting
are compatible — proven on this machine.**

**llvm816 (`examples/65816-llvm-mos`, actively developed):** same four
structural moves, modern form — (1) bank in the pointer VALUE end-to-end
(datalayout `p:32:16`; deref stages lo/hi at DP and executes `lda [dp],Y` so
the *hardware* reads the bank from the value); (2) **exactly one lowering
funnel** per pointer-kind × operation — their one recorded bank-drop bug
(7f0c503) occurred precisely where a local AsmPrinter hack made a second bank
decision, and was fixed once at the chokepoint; (3) symbol banks as
link/load-time relocations (BANK16/IMM24 → OMF cRELOC/cINTERSEG) — note
honestly: the BANK16 path is **designed but dormant** in the reference (a
GS/OS 6.0.4 loader patch-formula limitation forces a runtime `lda $BE`
fallback), but FGX owns its loader, which already streams 1,728 relocs for
elvis, so the constraint that forced their fallback does not exist here; (4)
unsafe modes (deref-assumes-DBR "Layer 2", ~20% size win) are per-function
attributes **hard-gated at link** — mode mixing is a link error, not a
runtime heisenbug. Cross-bank function pointers are solved in the *linker*
(deduplicated 4-byte JML trampolines; one near indirect-dispatch path through
`JML [$00B8]`). There is ONE libc, written in C, compiled by the backend
itself (ORCA/C fully dropped). Cost honesty: value-carried banks are
expensive per deref; they recover it with three cheap folds
(constant-offset-into-Y, staging CSE across consecutive derefs, increment
fold) plus inline retuning.

**Convergent verdict.** Two independent systems, decades apart, targeting
this exact CPU, landed on the same architecture: *bank in the value, one
lowering path, banks patched by the linker/loader, one libc, locals on the
hardware stack, unsafe assumptions gated at link time*. FGX's current model
is the null hypothesis those systems already falsified.

---

## Part III — Target architecture

### T1. fcc: bank-in-the-type, one funnel, one mode

> **★LANDED 2026-07-07 (P3-2.0–2.7, toolchain main under the release
> hold).**  Pointer values ride per-expression DP far-pointer registers
> (`_fcc_fpr0..7`; FPR0 = the pointer-return home, shims included); one
> lowering (far + stored-bank + data-seg); `_fcc_ptr` survives only as
> private one-statement deref scratch in the postinc/member-incdec
> lowerings (they convert with P3-3's soft-stack rewrite).  Record:
> docs/history/plans/2026-07-07-fcc-p32-pointer-model.md.

- **Uniform 32-bit pointers as values** (GNO/ORCA model). `tword` grows an
  address-space/width property; a pointer rvalue is a self-contained
  offset+bank pair, never "A plus a shared global". Generalize the one shape
  that already works — the DP-IMG promoted pointer pair (contiguous
  offset+bank in a private DP register, deref via `lda [dp],Y`) — into
  per-expression DP far-pointer registers, retiring `_fcc_ptr/_fcc_ptr+2` as
  a shared carrier.
- **One lowering funnel per operation.** All loads/stores/derefs/address-ofs
  route through single emission routines that receive the pointer kind from
  the type; the 8 call emitters collapse to 1 (§T2). PHK/PHB/#0/stored-bank
  choices exist in exactly one place each.
- **Multibank is the only mode.** Retire `--far-calls`/`--data-segment` as
  flags; single-bank FGX1 output becomes a degenerate case of the same model
  (one code segment, data folded in), not a separate emission mode with dead
  branches at every site. This kills single-bank invisibility at the root.
- **Cost control** (the llvm816 lesson, scaled to fcc): constant-offset-into-Y
  fold, deref staging reuse across consecutive accesses, and the existing
  DP-IMG promotion. Accept that pure size regresses somewhat on pointer-heavy
  code; Phase 0 measures the real delta.

### T2. fcc front-end: tokenize → AST → existing backend

> **★COMPLETE 2026-07-10 (T2-0..T2-4; released through toolchain v1.1.0,
> remainder on feat/t22-pp-token-pass).**  Token vector + whole-TU pp
> pre-pass (Increment 1, Phase 2); IR_TEXT lift −61% with CFG/width/cell/
> deref/const-arith ops (T2-3, stop-rule closed); ALL name lookups —
> nine symbol tables + the pp macro table — on dedup-interned pointer
> scans (T2-1 + rider); **pp as a token pass** (T2-2): macro bodies =
> token slices, expansion = token splice, token-level #if evaluator,
> #include = recursion, g_pp_stack/text-frame machinery DELETED; behavior
> pinned by tests/M36 adversarial fixtures, byte-identity proven on
> goldens 386/386 + elvis 29-TU corpus.  Front-end memory measured on the
> largest elvis TUs (FCC_MEM_STATS): toks ≤486KB + macro-body toks
> ≤262KB + intern ≤10KB + AST peak ≤117KB ≈ **0.9MB worst-TU front-end
> footprint at host sizeof(Tok)=56** — the self-host BUDGET decision
> (Part V) reads these numbers; fcc's own parse_stmt.c is ~2.7× the
> largest elvis TU by lines.  Record:
> docs/history/plans/2026-07-09-fgx-t2-frontend-completion.md.

Full tokenize into a token vector (tokens own/intern their text — no
pointers into live buffers), preprocessor as a token-stream pass (retiring
the 16-deep text-frame stack, the retire ring, and the three parallel
expression evaluators), parse to a per-function AST, then feed the existing
Stack-IR backend. For-step and switch emission become tree traversals — the
entire source-replay class (and its three generations of band-aids) is
deleted, not patched. One call-marshalling emitter. Stable symbol handles
(no index renumbering on prototype promotion). Per-function windowing keeps
the memory budget self-host-compatible (ir.c's per-function buffer is the
existing proof).

### T3. Toolchain contracts: relocations by construction + link gates

- **Banks are link/load-time facts.** Every stored pointer initializer and
  every cross-segment reference emits a typed relocation (BANK16/IMM24
  analogs in the fgx_ld object model) *by construction from the type*, ending
  the per-construct-shape `FGX2_LONG_PTR` accretion. FGX's loader already
  does streamed bank patching; this formalizes the source of those records.
- **The D1 gate, finally:** fgx_ld validates bank consistency at link time
  (segment-kind vs reference-kind, mode stamps, cross-bank PCREL = error).
  Every object carries an ABI/mode stamp; mixing is a **link error**
  (llvm816's Layer2Gate pattern). This lands in Phase 0 — it guards the *old*
  model while the new one is built.
- **Function pointers:** linker-synthesized, deduplicated JML trampolines for
  cross-bank targets + one indirect-dispatch primitive, replacing the 3-layer
  runtime dispatch.
- **Dead-stripping / emit-once** become linker properties (the PUT model
  can't express either).

### T4. Runtime: delete the soft stack (hybrid)

Locals return to the bank-0 hardware stack (`n,S`, 2 bytes/5 cycles for the
82%-of-frames case; `&local` = bank 0 *by construction*), with
**compiler-owned heap-boxing for large aggregate locals** (>~1KB: frame slot
holds a far pointer, prologue allocates, epilogue frees) so elvis-class
frames compile unmodified. Per-binary stack sizing via `stack_pages_hint` +
a call-graph frame-sum (linker-assisted cross-TU), and the FGX2/FGX3 manifest
grows the stack field FGX2 never had. `TASK_STACK_MAX_PAGES` 16→32; reclaim
$0800/$2000/$3000 (+10KB → 38KB arena) when NPROC pressure appears; prologue
stack-limit guard on big frames. The four-bank function state collapses to
three (two on FGX1-class binaries); the caller-buffer-bank rule disappears
*for locals*; the 16KB-per-task heap tax (128KB at NPROC=8) is refunded.
Gate: measure elvis's real soft-stack high-water first (Phase 0) — the 5–6KB
figure is a design-doc estimate, and the hard-frame model must be resurrected
from git (deleted at v0.21.0), so the golden churn should be spent once, with
data.

### T5. libc: one source, one copy per binary, then one copy per system, then C

- **Phase A (no ABI break): emit-once shared libc segment per binary.** The
  bank-independence prerequisite is **verified met** (archive
  `libc-bank-independence.md`): zero data-in-code DBR reads remain, the pile
  is a closed call graph (66/66 JSR targets internal). The edit is
  mechanical: RTS→RTL on the 66 public entries, +1 stack-offset shift at 191
  shim sites, 11 dual-use symbols get JSL-internal callers, setjmp's PHK fix,
  fcc emits FGX2_FARCALL for libc calls (mechanism exists). Payoff: ~45KB per
  elvis-class binary, and every future big C program.
- **Phase B: load-once, system-wide.** The kernel loader loads the libc
  segment once, refcounts it, and maps it into every process's bank list
  (per-process state is already isolated in the data segment + DP cells; the
  currently-ignored RODATA kind byte finally earns its keep). Two shells stop
  costing two libcs.
- **Phase C: single source, in C.** Unify the two hand-synced trees into the
  toolchain (FGX consumes, never forks), then convert function-by-function to
  fcc-compiled C. Compiler prerequisites (the closure list): a `__syscall`
  builtin (JSL SYS_TRAMP + inline DFB is not C-expressible; 54 sites), real
  `va_list` varargs (retiring the static-slot printf ABI and its 9-arg cap),
  and the T1 pointer model (which makes shims mostly evaporate — a C wrapper
  passing a 32-bit pointer needs no hand PLB discipline). The
  `g_libc_bindings` table shrinks to the genuinely-primitive set.

### T6. Kernel ABI v2: hybrid pointer widening + real errno

Per the enumeration (archive `syscall-abi-widening.md`):

- **Widen the 9–11 genuinely multi-pointer calls** — STAT/FSTAT, LISTDIR,
  EXECVE, POSIX_SPAWN/SPAWNX (far-ptr arg-blocks; argv/file_action entries
  widen to far ptrs), the socket argblk family (add bank fields), and
  WAIT/WAITPID status (far ptr in TCB, subsuming `TCB_DataBank`). Additive:
  spare register bytes (MALLOC precedent) and extended argblks — no flag day
  required, though Phase 3's recompile-world absorbs it anyway.
- **Keep `_Sys_CallerBank` for the 22 single-pointer calls** — one pointer,
  one bank; the contract is exact there.
- **One `SYSCALL_PTRARG` macro** replaces the 12 hand-rolled swap sequences
  and implements the 9 broken + 5 missing shims. This kills the shim bug
  class *now*, at zero ABI cost (Phase 0).
- **errno becomes real:** a per-task cell the dispatcher writes on every
  failing syscall (the kernel already computes the codes it currently
  discards), `perror`/`strerror` over it.
- **Wire structs stop mirroring fcc's layout quirk:** fcc gets correct C
  struct layout (char members byte-sized) as part of T1's type work, and the
  kernel structs get defined shapes independent of compiler accidents —
  before any more wire formats accrete.

### T7. BSD-shape completion tier (unblocks the port queue)

In dependency order for the known queue (elvis task #28, curses): errno (T6);
**environ** — finish the half-built pipeline (loader already stages envp;
crt0 reads it; `getenv/setenv/putenv` + shell `export` + `/etc/profile` seed
for TERM/PATH/HOME — retiring the `"vt100"` booby trap); **signals** — an
fcc-compatible handler trampoline (register→stack adapter), un-shadow the
real signal/kill wrappers, SIGCHLD; **FS namespace** — mkdir/rmdir/rename
(atomic save!), access, utime, truncate, fsync/sync (pairs with the task-#55
crash-safety work); **epoch time** — time/gettimeofday from the ProDOS dates
the kernel already holds; **tty** — TIOCGWINSZ + FIONREAD ioctls, then the
termcap/terminfo layer already roadmapped; fcntl/O_NONBLOCK; a readdir-shaped
directory iterator (SYS_LISTDIR's bulk snapshot doesn't scale). Explicitly
*not* BSD-shaped, kept deliberately: spawn-only process model (GNO precedent;
fork stays ENOSYS; the seam is a documented per-port recipe + popen/system in
libc over pipe+dup2+spawnx — all kernel primitives exist today).

### T8. Memory system: sharing and granularity

Enabled by T3/T5: loader text-sharing for multi-instance binaries (reloc
records applied via per-task tables instead of patched into the image — the
FGX3 format decision), module co-location for sub-bank modules, user-pool
widening past 22 banks (the 3-byte BankBitmap and dynamic floor already
exist; the $20+ region needs an ownership audit), and multi-segment data
(primary DBR-home data bank + overflow far-data segments, placement chosen by
the compiler per-object — this is where FGX can beat both references, since
llvm816 explicitly leaves scattered data unsolved and elvis is at 83% of the
single-segment ceiling).

### T9. Kernel-in-C: through the module system, not the bank-$02 box

Verdict from the triage (archive `kernel-c-triage.md`): **FGXM modules are
the multi-bank kernel** — conversion happens by modularizing, not by growing
the one-bank kernel (which has 9.8KB of headroom total; fcc expansion would
eat it all for ~5KB of asm). Path: (1) a **kernel-C seam spike** on
`bitmap.s` or `path.s` — deliverable is the seam itself: a kernel-C DP page
(fcc's $BC–$FF register file collides with the full kernel DP), a boot-seeded
kernel stack story, PHD/TCD entry macro, carry/errno thunk pattern; (2)
**prodos.mod op-by-op in C** — 3,700 lines of pure FST logic, own bank,
vtable dispatch, per-FOP fallback — the strategic conversion and the real
test of fcc as a systems compiler; (3) net.mod state machines; (4) in-bank
pure-algorithmic files (console_vthandler) only as modularization frees
room. Never: sim.s, block.s, serial.s hardware cores, boot, dispatcher head.

---

## Part IV — Migration path

Each phase lands green (goldens + multibank oracle + MAME suite) and
shippable. Ports stay unblocked on the current model until Phase 3's
coordinated break.

**Phase 0 — Measure, gate, and stop the bleeding** *(tactical; no ABI
change)*
- Fix the live defects (§I.8): the stmt-context MVN miscompile + c26 oracle
  construct; the `SYSCALL_PTRARG` macro + 9 broken + 5 missing shims; setjmp
  PHK; un-shadow signal/kill; the doc-drift items.
- **Implement the D1 link-time bank-consistency gate** in fgx_ld (five weeks
  overdue by its own record).
- Measure: profiler baseline on an elvis redraw (attributes the slow-render
  pathology between fcc-runtime/libc/kernel-console — this is also audit goal
  6's baseline); soft-stack high-water via the `_fcc_ssp` tap; golden size
  delta vs pre-soft-stack fcc; per-binary call-graph frame sums.
- Extend the multibank oracle to the enumerated non-PHK/PHB bank sources and
  the shim population (its own README's honest-coverage list).

**Phase 1 — Shared libc segment (emit-once)** *(toolchain + link model; no
kernel ABI change)*
The mechanical edit from T5-A, gated by the oracle. Immediate ~45KB/binary.
Also: unify the two libc source trees (single source of truth in the
toolchain; FGX-side copy becomes a build artifact or disappears).

**Phase 2 — fcc front-end rewrite** *(the multipass milestone)*
T2 in full: token vector → AST → existing backend, one call emitter, pp as a
token pass, stable symbol handles. Sequenced *before* the pointer-model flip
so T1 lands in one funnel instead of eight duplicated emitters. Goldens +
oracle green throughout; the ROADMAP already names this item — this plan
gives it its place in the critical path.

**Phase 3 — The clean break (one coordinated flag day, recompile world)**
- T1: uniform 32-bit pointer values through single lowering funnels;
  dual-mode flags retired.
- T4: soft stack deleted (hardware stack + heap-boxing), informed by Phase-0
  measurements.
- T6: kernel ABI v2 (hybrid widening, real errno, layout-corrected wire
  structs).
- T3: **FGX3 binary format** — typed relocations by construction, mode
  stamp, stack-size field, per-task reloc tables (text sharing), linker
  fn-ptr trampolines.
- FGX1 retires: legacy tools recompile as single-segment FGX3.
This is one release train: toolchain first, FGX re-pinned, world rebuilt —
the standard discipline, at maximum amplitude. Everything before it keeps
shipping; everything after it stops paying the four-bank tax.

**Phase 4 — libc load-once + libc in C**
T5-B (kernel refcounted libc segment) and T5-C (C conversion behind the
`__syscall` builtin and va_list), function-by-function with the oracle as
the harness. The hand-asm libc and its sync ritual end here.

**Phase 5 — Kernel-in-C + BSD completion (rolling)**
T9's spike → prodos.mod → net.mod; T7's completion tier lands opportunistically
from Phase 0 onward (errno/environ/signals early — they unblock elvis task
#28; FS namespace + time with the task-#55 FS work; tty ioctls with the
termcap layer). T8's sharing/granularity items ride the FGX3 loader work.

**Sequencing rationale.** Phase 0 makes the current model safe to keep
shipping (gate + oracle + shim macro). Phase 1 is pure win with no coupling.
Phase 2 before Phase 3 is the critical ordering: the pointer-model flip is a
*type-system* change, and it must land in a front-end where each construct
has one emitter — flipping eight drifted emitters would recreate the drift
class under a new model. Phase 3 bundles every ABI-breaking change into one
recompile-world event instead of three. Phases 4–5 are then incremental
paydown on a stable substrate.

---

## Part V — Risks and open decisions

- **Code-size tax of uniform far pointers.** The known counter-levers: 82% of
  accesses are locals (bank-0 `n,S` after T4 — *cheaper* than today's soft
  stack), DBR-relative stays the fast path for home-data-bank globals, and
  the three llvm816 folds. Net effect is workload-dependent; Phase 0's
  measurements make it a decision with data, and jsh/FGX1-class tools get
  *smaller*. Watch: elvis-class pointer-chasing code.
- **Front-end rewrite scale.** parse_expr+parse_stmt ≈ 8,600 lines of
  load-bearing single-pass logic. Mitigation: the backend IR interface stays;
  the golden suite (347) + oracle + MAME tier is unusually strong; the
  rewrite is the ROADMAP's own precondition for the deeper optimizing
  backend, so the cost buys two items.
- **Soft-stack resurrection churn** (hard-frame model was deleted at
  v0.21.0). Mitigation: it returns in Phase 3's already-total churn, with
  Phase-0 data sizing the windows.
- **Self-host memory budget** for token-vector/AST: per-function windowing +
  interning; the current ~1MB static tables must shrink regardless. Measure
  peak tokens/AST on the largest elvis TU during Phase 2 design.
- **Phase-3 blast radius** is the largest single event in project history.
  Mitigation: it is strictly a *toolchain + kernel-ABI* event — the FS, net,
  console, and scheduler are untouched; the oracle and MAME suite run the
  same binaries before/after; and the FGX3 loader can co-exist with FGX2
  loading during bring-up (loader dispatches on magic, as it already does for
  FGX1 vs FGX2).
- **Open:** exact FGX3 reloc record shapes (design with the D1 gate so
  link-time validation is native); whether text-sharing's per-task
  indirection costs more than it saves at NPROC=8 (decide on Phase-0 profiler
  data); how far the $20–$3F pool widening can go before colliding with
  kernel-managed handles.

## Part VI — Quick wins (any time, independent of everything above)

The Phase-0 §I.8 fixes, plus: finish environ (loader half exists), TIOCGWINSZ,
epoch time from ProDOS dates, waitpid C shim, `-?` usage sweep, retire the
~35 staged toolchain fixtures from the FGX disk (already roadmapped), correct
userland-abi.md §9's stale COP references and the memory-map.md bank-0 table
(superseded by include/kernel.s — noted stale during this audit).

---

*Provenance: 46-agent verified audit + 4 follow-up probes, 2026-07-05.
Numbers in this document are the post-verification values; where a survey
claim was corrected by its verifier, the corrected value appears here.
Full trail: [`docs/history/audits/2026-07-05-fgx-fcc-arch-audit/`](../audits/2026-07-05-fgx-fcc-arch-audit).*
