# T5-A/B — shared libc segment: emit-once (A) then load-once (B)

**Branches:** `feat/t5a-shared-libc` (both repos) off the P3-5 heads
(toolchain `f2213b7d` / FGX `e3758dba`). RELEASE HOLD in force.
**Status:** design → Fable review → execute.

## Ground truth (verified in-tree 2026-07-09, post-P3-5)

The **call-ABI half of the audit's T5-A work list is ALREADY LANDED** (P3-0
"far flavor" + Phase-0 setjmp fix — the ROADMAP item predates this):

- `LIBC_RET` macro = RTL under `LIBC_FAR=1` on every public entry;
  `LIBC_EXPORT` markers on the entry set; **209** `n+LIBC_FAR,S` offset
  sites in fcc_libc_shims.s; setjmp reads PB from the JSL frame behind
  `DO LIBC_FAR`; fcc emits `FGX2_FARCALL` for every libc/runtime call
  (`emit_libc_call`, one-mode).

**What remains is purely the LINK MODEL**: the pile (`fcc_runtime.s` +
`libc.s` + `fcc_libc_shims.s`) is still PUT into EVERY code segment — seg0
of all 76 shipped 2-seg C tools, and every one of elvis's 5 code banks
(11,303 B/copy; 45,212 B redundant on elvis).

Other verified facts:
- crt0_far near-JSRs `_crt0_setup_argv` / `_crt0_copyToInput` /
  `_crt0_set_progname` → **args.s stays in seg0 beside crt0** (audit item 6).
- The pile's data references resolve into the **template-frozen seg1 prefix**
  ([256 pad][libc_data][args_data][fcc_runtime_data]) — same offsets for
  every binary; tool data appends after. ⇒ **the assembled pile segment is
  byte-identical across binaries** (the T5-B sharing precondition; verify
  mechanically during A).
- OPEN to verify at implementation: near-JSRs INTO the pile from other seg0
  residents (crt0/args/`<name>_stubs.s`) — TU code already FARCALLs.

## The economics (drives the phasing — this is the design fork)

| Case | Today | A alone | A+B |
|---|---|---|---|
| 2-seg tool (×76) | pile inside seg0 (1 copy) | pile = own seg → **+1 runtime bank/process, no win** | seg0 shrinks 11.3KB; pile bank **shared fleet-wide (+1 bank TOTAL)**; disk −11.3KB×76 ≈ −860KB |
| elvis-class (multi-code-bank) | 5 pile copies (45KB waste) | **−45KB** (4 copies gone) | same + shared |

⇒ **A alone is only a win for multi-code-bank binaries.** Applying the
3-seg template to all tools before B lands would *cost* runtime banks.
Phasing that follows the value:

## Fable design review (2026-07-09) — verdict: proceed-with-changes

Corrections to the ground truth above (verified by the reviewer, file:line):
- **A1's −45KB is ALREADY BANKED**: `gen_elvis_link.py:110-118` (P3-0) puts
  the pile ONCE in seg0; banks 1..N carry only fcc_runtime (~3.5KB/bank).
  Remaining elvis duplication ≈ 13.6KB of fcc_runtime — and it is REQUIRED:
- **fcc_runtime.s cannot leave the code banks** — emitted near `JSR _fcc_*`
  by design (emit.c:1858 "stays per-bank and near — do NOT route through
  FARCALL") + STKGUARD's same-bank `JMP _fcc_stkoflow`.  The shareable pile
  = **libc.s + fcc_libc_shims.s (+ args.s)**; the LIBC segment carries its
  OWN fcc_runtime copy (shims near-JSR the 11 dual-use helpers), seg0 keeps
  another for TU code.
- **Sharing is CONFIRMED viable**: zero FGX2 reloc macros in the pile files;
  the pile's only JSLs are SYS_TRAMP/$E10000; DBR is register-established
  (24 PLB-from-arg-bank sites); the 2 PHK sites return pile-bank RO data.
  ⇒ the loaded pile bank is byte-identical to disk, zero per-process bytes.
  **T5-C landmine recorded**: fcc-compiled libc must NOT use CALLEE_ENTER
  (a loader-patched prologue immediate would break sharing).
- **Share key corrected**: length+abi degenerates to length-only (the loader
  already rejects abi≠2).  Key = {length, **24-bit content checksum** in the
  seg-table entry's 3 reserved bytes (FGX2_SEG_RESERVED)}.  Fail-soft private
  copy on mismatch + a console/MODLOG line (observable, not silent).
- **B1: the shared bank must NOT enter TCB_BankList** — `_Task_FreeBanks`
  frees every nonzero entry (process.s:467-478) and the list is 8-wide
  (elvis would hit the cap).  Separate kernel refcount table + TCB marker;
  ~6 spawn-abort paths must decrement too.  RED-proofs ×3: (a) spawn-2/
  exit-1 survivor intact; (b) spawn-abort-after-map decrements (no free, no
  strand); (c) first loader exits, second lives.
- **crt0/args stale note**: `_crt0_setup_argv` etc. are defined INSIDE
  crt0_far.s; args.s code is effectively dead weight in C-tool seg0s (no
  getopt binding; grep clean) — drop or ride the pile at B2 (verify first).
- **Timing**: the WIRE definition (kind byte, checksum field) is effectively
  Phase-3 work — FGX3 is unreleased under the hold, so defining it now is
  free; after first release it becomes a migration.

Review-adopted decisions (the maintainer may veto any before release — all local
under the hold): **kind byte 3 = LIBC_SHARED**; **key = {length, 24-bit
checksum} in FGX2_SEG_RESERVED**; **fail-soft + logged** on mismatch; B1
lands under the hold per the "proceed with all remaining items" directive.

## Increment ladder (corrected)

- **A0 ✅** — ground truth corrected (this section).
- **A2** — libc source-tree unification (toolchain = source of truth;
  src/userland/lib copies become build artifacts).  Precedes A3's identity
  freeze.
- **A3+W** — byte-identity proof (incl. elvis pile assembly) + fgx_ld emits
  the checksum into SEG_RESERVED for kind=LIBC_SHARED segments + the
  pile-seg reloc-count==0 mechanical gate.
- **B1** — kernel: refcount table + TCB marker (NOT BankList); load-once +
  map + skip-copy; decrement on exit AND all ~6 spawn-abort paths; free at
  0.  RED-proofs ×3 above.
- **B2** — 3-seg standard template flip (tool code+fcc_runtime | data |
  LIBC shared = libc+shims+own fcc_runtime); elvis link folds in here (its
  regen is forced by FGX3 stamps anyway); args.s dropped from C links if
  the deadness check holds.  Full battery.
- **B3** — old 2-seg FGX2/FGX3 binaries stay loadable (kind byte ignored on
  non-shared segs); pre-B1 kernels degrade B2 binaries to private-copy
  gracefully (kind byte unread there).

## Execution status (2026-07-09)

- **[x] A2 — source-tree unification** (FGX `70055897` / tc `16a07eee`): dual
  tree DELETED, ~75 PUT lines repointed (incl. toolchain multibank tests, now
  intra-repo; incl. The maintainer's untracked fgx2heap), drift guard retired.  Zero
  content change → byte-identical outputs.  Oracle 381/381 + MAME GREEN.
- **[x] W — wire** (tc `42562d89` / FGX `4afba81a`): SEG_KIND_LIBC=3, 24-bit
  byte-sum checksum in the segtab reserved bytes, LIBC gates (zero relocs
  into; singleton; not seg0; not the data seg).  Proven inert for non-LIBC
  manifests (old-vs-new byte-identical); GREEN stamps matching cksum; RED
  reloc-into dies.  D1 widened: call relocs may target CODE or LIBC.
- **[x] B1 — kernel** (this commit): loader registry {bank,ref,len,sum} +
  F7 kind==LIBC branch (match → map + ref++ + Fs_Lseek past the bytes;
  first → load + register at segOK; mismatch → Kern_LogStr warn +
  private copy), post-reloc extras-slot blank (the shared bank NEVER
  reaches TCB_BankList), _FreeExtras refcount-aware rollback,
  TCB_LibcBank (= ex-TCB_Reserved1, zero TCB growth), _Task_FreeBanks
  drops the ref (frees + deregisters at 0), and ALL EIGHT spawn-abort
  paths converted from childBank-only Bank_Free to _Task_FreeBanks —
  **also fixing a pre-existing leak: post-load aborts stranded FGX2
  extra banks** (Task_Free never walked the list).  Kernel +353 B.
- **[x] B2 — 3-seg template flip**: seg2.link.s.in (pile = libc.s + shims +
  OWN fcc_runtime copy + hand-declared FGX2_MODE/RELOC_COUNT stamps);
  seg0 keeps crt0 + TU + stubs + its runtime copy, args.s DROPPED from C
  tools (deadness verified: zero refs; ARGS_* EQUs crt0 needs moved into
  the link); seg1 UNTOUCHED (frozen prefix — abiprobe tap intact);
  manifest 3-seg with kind LIBC.
- **PROOFS**: byte-identity across binaries — cat/wc/grep pile segs all
  {12328 B, cksum bf9d12}; libcshare (12 spawn/reap refcount cycles +
  second-loader mapping; leak → pool exhaustion → FAIL, double-free →
  resident-pile corruption → no PASS) GREEN; libcmiss (doctored checksum →
  fail-SOFT private copy, program works, warn line in dmesg) GREEN; MAME
  battery (fgx3probe/fgx3reject/abiprobe/tctest) GREEN on the shared world.
  Free-at-refcount-0: code-reviewed (jsh holds a ref for the session, so
  the path only fires when the last mapper dies — not reachable in a
  battery with a resident shell; loader-abort variant covered by
  _FreeExtras when a first-load fails mid-flight).

**Measured economics (honest — differs from the review's projection):**
per-binary DISK grows ~+3.1KB (the pile still ships in every binary, plus
seg2's own fcc_runtime copy; cat 19,816 → 22,937 B) ≈ +240KB across 76
tools — disk is 32MB, cheap.  Bought: **seg0 content −11.3KB per tool**
(jsh's seg0 ~50KB→~39KB, sed's similar — real headroom under the 64KB
segment ceiling), **spawn copies 12.3KB less** after the first load, ONE
shared pile bank fleet-wide (+1 pool bank total vs +0 — the review's
prediction held), and the **T5-C substrate**: exactly one pile instance
system-wide to convert to C later.

## Gates (every increment)

Toolchain goldens (+REGEN only if legitimate) + stack_check + run_runtime
oracle; FGX build.sh disk + MAME battery incl. abiprobe (tap-durability
re-derivation if seg1 layout shifts — **it does NOT under A/B**: the prefix
order is untouched); D1/MODE/COUNT link gates apply to the new segment
automatically. RED-proofs: B1 gets a refcount-abuse probe (spawn 2 sharers,
exit one, verify the survivor's pile bank intact + freed only at 0).
