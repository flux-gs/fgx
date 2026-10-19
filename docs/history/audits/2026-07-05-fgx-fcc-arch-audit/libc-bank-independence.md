# Follow-up: libc pile bank-independence probe (shared-libc prerequisite)

> Part of the 2026-07-05 FGX/fcc architecture audit. Question: is the
> per-bank-duplicated libc/runtime pile bank-independent enough to become ONE
> shared segment reached by cross-bank JSL?

## Scope verified

Per `tools/elvis-fgx2/gen_elvis_link.py`, each code bank gets:
`toolchain/lib/fcc_runtime.s` + `src/userland/lib/libc.s` +
`toolchain/lib/fcc_libc_shims.s` + `src/userland/lib/args.s` (bank 0 adds
`crt0_far.s`). Data-side files (`libc_data.s`, `args_data.s`,
`fcc_runtime_data.s`) already go ONCE into the DATA segment. The multi-bank
link uses the **src/userland** copies for libc/args and the **toolchain**
copies for runtime/shims (current copy divergence: 1 comment + the tc_ti/tc_te
alt-screen caps in libc_data.s).

## 1. Code-segment data scan — CLEAN except one item, and it's safe

Exhaustive directive sweep (DFB/DB/DA/DW/DDB/ADR/ADRL/HEX/ASC/DCI/STR/STRL/DS…)
over all four code files:

- `c_env_term` ASC 'vt100' (fcc_libc_shims.s:1130-1131): read via immediate
  offset + **PHK** bank (line 1117) and long-indirect deref — PHK yields the
  bank the string actually lives in. **Safe under emit-once.**
- Every other DFB (~50 sites) is the inline syscall-number byte immediately
  after `JSL SYS_TRAMP` (verified programmatically: zero DFBs not preceded by
  the trampoline JSL) — read PC-relative off the return address. Safe.

**Zero remaining pf_pow10-class instances.** Every loaded/stored symbol
resolves to: data-segment labels (DBR-relative into the binary's one data
bank — emit-once doesn't change that), DP-cell EQUs (`_fcc_ptr` $E8,
`LIBC_DP_*` $E4-$EB, `ARGS_DP_*` $E0-$E2 — per-process, bank-free), or pure
constant EQUs. printf varargs come from `libc_args*` in the DATA seg. Safe.

## 2. Near-JSR escape scan — ZERO escapes

66 unique JSR targets across the pile; **all 66 defined inside the pile**.
JSL targets: only `SYS_TRAMP` ($000328) and `$E10000` (toolbox) — fixed
addresses. No JML, no indirect JMP, no MVN/MVP, no symbolic long-absolute refs
to own code. The pile is a closed call graph.

## 3. PHK / self-modifying / DBR assumptions

- PHK ×2 total: shims:1117 (safe, above) and **`src/userland/lib/libc.s:2706`
  (setjmp) — the one real bank bug**: captures caller PB via PHK under an
  explicit "same-bank assumption" comment; under a shared libc bank, longjmp
  would RTL into the *libc* bank at the caller's PC. setjmp also reads the
  return PC at `4,S` assuming a 2-byte JSR frame (libc.s:2728). Under JSL
  entry the fix is cleaner — caller PB sits in the JSL frame. `longjmp`
  already builds an RTL frame and ends RTL (libc.s:2803) — cross-bank clean.
- All 24 shim PLB sites follow PHB-save → PLB-to-caller-pushed-arg-bank →
  PLB-restore — bank from the pushed far-ptr, never PHK. Stays correct.
- Self-modifying code: none. No routine reads its own code-bank constants
  DBR-relative.

## 4. Payload — ledger corroborated exactly

`tools/elvis-fgx2/_ov_bn` (pile only) = **11,303 B**; `_ov_b0` (+crt0_far) =
11,599 B (crt0_far = 296 B). Elvis: 4 redundant copies = **45,212 B**.

## 5. Verdict: mechanical fixes only — prerequisite MET

No structural bank-dependence. Required work is call-ABI conversion
(near-JSR entry → JSL entry), itemized:

1. **setjmp** — libc.s:2706 (PHK → read PB from JSL frame) + :2728 (frame
   offsets). ~10 lines. longjmp needs nothing.
2. **RTS→RTL on public entries** — the externally-called set is exactly 66
   symbols (measured from all 28 elvis TU `.code.s`): 31 `_fcc_*` helpers,
   ~31 `c_*` shims, plus `getpid`, `setjmp`, `longjmp`, `sprintf`.
   Internal-only helpers keep JSR/RTS.
3. **Stack-arg offset shift +1** (JSL pushes PB): **191 `n,S` sites in
   fcc_libc_shims.s**, 1 effective site in libc.s (setjmp), 0 in
   fcc_runtime.s and args.s (register/DP ABI).
4. **11 dual-use symbols** (both TU-called and internally JSR'd):
   `_fcc_mul16, _fcc_gts16, _fcc_gtu16, _fcc_lts16, _fcc_ltu16,
   _fcc_long_divs, _fcc_long_eq, _fcc_long_gts, _fcc_long_lts, _fcc_long_mul,
   _fcc_long_sub`. Register-ABI, so converting internal JSR callers to
   same-bank JSL lets one RTL exit serve both.
5. **fcc side**: emit linker-patched JSL for libc/runtime calls — mechanism
   exists (`FGX2_FARCALL` = `JSL $000000` patched by fgx_ld.py + loader bank
   reloc, include/macros.s:694).
6. **crt0_far (bank 0)** near-JSRs `_crt0_setup_argv` (crt0_far.s:77) —
   either JSL it or keep args.s resident beside crt0 (register-ABI, either
   works).
7. Reentrancy unchanged: pile state = per-process DP cells + per-binary
   data-seg statics; emit-once shares code across a binary's banks, not
   across processes.

Zero data items need moving; zero reads need LDAL conversion. The edit is
dominated by the +1 offset shift (191 sites) and RTS→RTL on the entry set —
both regex-assisted mechanical, verifiable with the existing multibank oracle.
