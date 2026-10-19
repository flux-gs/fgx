# T5-C — libc in C (2026-07-10)

Redesign §T5 Phase C / migration Phase 4.  Prereq state at start:

- **T5-A/B shipped** (v1.0.0 train): emit-once pile per binary, kernel
  refcounted load-once segment.  Pile is bank-independent (caller's DBR),
  closed call graph, RTL entries.
- **Dual-tree retired** (T5-A A2): `toolchain/lib` is the single source;
  the FGX-side copies are gone.  FGX `src/userland/lib` holds only the
  crt0 twins + headers.
- **T1 pointer model landed** (P3-0/1/2): 32-bit far pointers through
  single funnels, FPR return.  A C wrapper passing a far ptr needs no
  hand PLB discipline — the shim class "mostly evaporates".
- **Soft stack deleted** (P3-3): locals/args on the bank-0 HW stack —
  real stack varargs are now natural.

Survey numbers (2026-07-10): `SYS_TRAMP` mentions — 40 fcc_libc_shims.s,
22 libc.s, 5 args.s, 2+2 crt0s, 1 fcc_runtime.s; 42 carry checks with
BOTH senses in use (read/write BCS=ok; realloc/lseek BCC=fail).
`g_libc_bindings` = 90 entries.  Variadic ABI today: `N_CALL_PRINTF`
AST node → stores into `libc_args` (10 word slots, **9-vararg cap**) +
parallel `libc_args_bank`/`libc_args_hi` arrays in libc_data; asm
printf walks the slots.

## The landmine — NO CALLEE_ENTER in the pile

`FGX2_CALLEE_ENTER` patches DBR to a link-time-fixed data bank.  The
shared pile runs on the **caller's** DBR (libc_data lives in each
binary's own data segment; T5-B shares only text).  fcc-compiled libc
functions therefore need a **pile codegen mode**: no CALLEE_ENTER reloc,
no DBR repatch, RTL far return, DBR-relative statics resolve into the
caller's data segment (the libc_data discipline survives as-is).

## Increments

- **C0 — site survey.**  Enumerate every SYS_TRAMP site: syscall
  number, register marshalling (A/X/Y packing), carry sense, DBR
  discipline (buffer-bank ABI swaps), return shape (A / A+Y hi).  The
  table drives the builtin design and the conversion order.
- **C1 — `__syscall` builtin.**  C-expressible trampoline: emits
  `JSL SYS_TRAMP / DFB n` inline with args marshalled to A/X/Y.
  Shape decided by C0 (carry capture + buffer-bank DBR variant are the
  open questions).  Fixture: clang-cross-checked + MAME-calibrated
  wrapper that round-trips read/write/lseek through the builtin.
- **C2 — real va_list.**  Stack varargs (caller pushes, `va_start` =
  addr past last named param), `<stdarg.h>`; retire `N_CALL_PRINTF`,
  `libc_args` slots, and the 9-arg cap.  printf core converts to C over
  va_arg (the G-PF2 sign/pad semantics become fixture pins).
- **C3 — pile codegen mode.**  fcc flag/attribute for libc-pile TUs:
  no CALLEE_ENTER, RTL, pile-segment emission compatible with fgx_ld's
  emit-once layout.  Oracle: multibank sweep + libcshare refcount test.
- **C4+ — conversion by batches**, syscall wrappers first (kills the
  shim bug class; bindings table shrinks toward the primitive set),
  then stdio over C2's printf, str/mem last (hand-asm is fine there —
  convert only when touched).  Per-batch: goldens no-REGEN + differential
  + MAME fast group.

## Execution status (2026-07-10 — C1+C2 COMPLETE, unreleased)

- **[x] C0 survey** (in this doc): 60 SYS_TRAMP sites enumerated with
  registers/carry-sense/DBR discipline; open(A=path,X=flags,Y=mode,
  DBR=path-bank) and isatty(A=fd, C=1 always) are the calibration pair.
- **[x] C1 __syscall builtin** (tc 77dddefc): __syscall / __syscall_db /
  __syscall_c / __syscall_y; latch cells in fcc_runtime_data.s (COSTS a
  394-bin golden regen — lib-pile data moves every binary); M37/sysc
  MAME-42.  Shared parser in BOTH call arms (dual-emitter rule).
- **[x] C2 real va_list** (tc 332e521f): <stdarg.h> pure header over the
  K&R R-to-L HW-stack ABI (va_list = char*, &last anchor, upward walk,
  2-byte slot granule).  FORCED two fcc fixes: paren-wrapped lvalue
  assignment in expression position (va_arg's `(ap) += slot` — was an
  artificial reject) and the multi-star cast depth-1 FLATTEN — a
  fail-OPEN miscompile (`*(char **)x` = one-byte read, bank 0) that
  M37/vasum caught LIVE on MAME (40 vs clang 42).  M37/vasum+parenlv
  both MAME-42.  libc_args static slots still in place (die with the
  printf conversion).
- **[ ] C3 pile codegen mode — SURVEYED, design settled.**  How the
  pile stays canonical (from tools/fgx2/seg2.link.s.in): ALL pile data
  refs resolve into seg1's TEMPLATE-FROZEN PREFIX (libc_data +
  args_data + fcc_runtime_data, offsets generated into seg1_layout.s
  BEFORE seg2 assembles); fgx_ld GATES zero reloc rows into seg2; DBR
  is established per-entry from pushed far-ptr arg banks (this is the
  NO-CALLEE_ENTER rule's real meaning); the pile is a closed call
  graph with its OWN fcc_runtime copy (near JSRs stay in-segment).
  What fcc needs for a pile TU (`--pile` flag):
  (a) entries: LIBC_EXPORT shape — arg offsets ALREADY match (FGX2
      calls are JSL/RTL, same 3-byte frame as LIBC_FAR=1);
  (b) calls to other pile functions: near JSR `c_<name>` instead of
      FGX2_FARCALL (a FARCALL emits a reloc row = gate violation);
  (c) the TU's data + string pool routed into the frozen prefix
      (its .data.s output joins the seg1 template head, in fixed
      template order).
  ★DONE (tc 9c0487b4 + 823b1eda): `--pile` flag (near calls; all else
  was already pile-shaped) + c_isatty CONVERTED — lib/libc_c/isatty.c
  → checked-in lib/libc_c.s (`make libc_c` regenerates), hand shim
  retired, 48 toolchain wraps + multibank generator + FGX
  seg2.link.s.in gain the PUT.  PROOF: goldens 397/0, differential
  397/397, FGX fast 21/0 incl. libcshare — the fcc-compiled TU kept
  the pile byte-identical across binaries (checksum share key
  matched).  The seam is OPEN.
- **[x] C4 batch 1** (tc 797e01fd): close/dup/dup2/yield/getkey/
  pollkey/pipe join isatty in lib/libc_c/libc_c.c (ONE TU — the PUT
  chains never change again).  errno contract preserved (fail carry →
  A is the errno code).  pipe() = the T1 payoff: buffer-bank
  discipline is one __syscall_db line, no hand PHB/PLB.  8 converted,
  74 hand exports left in the shims pile.
- **[x] C4b __asm** (tc 82f757c1): verbatim statement-position escape
  hatch for the str/mem class (MVN, width tricks).  '@' lines at col 1,
  ops indented; peephole opacity via ;__ASM markers + sentinel labels
  (every pattern treats labels as barriers).  Contract at the parse
  arm: M=16/X=16 in/out, preserve S/D/DBR, @-locals only, non-static
  symbols only.  M37/asmblk MAME-42.
- **[x] C4 batch 2 — memcpy/memset over __asm** (the first __asm
  consumers): C wrappers stage args into dedicated __asm_p0/p1/w0/w1
  cells (fcc_runtime_data.s — NOT _fcc_* scratch, which codegen may
  clobber between the store and the block), the block lifts them into
  the pile's c_strcmp_a/b DP long-pointers for [dp],Y loops.  One M8
  window per loop (the hand shims toggled width PER BYTE — the C
  versions are faster).  M37/memops MAME-42 (cross-bank stack→data,
  n=0 edge, return-dst; first calibration ran 40 — fixture lacked
  <string.h>, so fcc defaulted memset to int-return and the compare
  was a bank-zeroed word: declare your protos).  GOTCHA: the pile PUT
  sweep must ALSO cover ~19 hand-maintained FGX link files (tools/fas,
  elvis + its generator, fswbig, *-fgx2 specials) — the seg2 template
  only covers build_userbin_fgx2_c tools; build.sh fails LOUDLY
  (unresolved c_memcpy) on any missed file.
- **[x] C4 batch 3 — the full str* family + memcmp over __asm**:
  strlen/strcmp/strncmp/strcpy/strncpy/strcat/strchr/strrchr/memcmp
  (19 functions converted total, 63 hand exports left).  Same staging
  pattern; search fns return s+idx built in C (FPR conventions stay
  fcc's business); the sign pick rides the M8 CMP's carry across REP.
  The shared c_strcmp_a/b DP EQUs relocated to the shims file head
  (they outlive the hand users — the __asm loops need them).
  M37/strops MAME-42 (cross-bank, strncpy padding, c==0 terminator
  semantics).  GOTCHA: merlin32 rejects duplicate @-local names ACROSS
  PUT files — the hand shims' per-function label prefixes were load-
  bearing; __asm labels need globally-unique prefixes (@lcc<fn>_).
- **[x] C4 batch 4 — buffered syscall wrappers**: read/write/open/
  creat/lseek/unlink/getcwd.  The whole hand PHB/DBR-swap/PLB
  discipline is one __syscall_db line computed from the pointer.
  FGX conventions preserved: read/write return 0 (not -1) on error;
  lseek packs (whence<<8)|fd and returns the 32-bit position as a
  long.  FORCED an fcc fix: **ptr<->long casts dropped the BANK in
  both directions** (tc 8ea757cd) — (unsigned long)p promoted only
  the offset; caught by M37/fileops (write()'s buffer bank arrived 0;
  earlier sysc "pass" was spurious).  M37/fileops MAME-42.
- **[x] C4 batch 5 — misc wrappers + first PURE-C conversions**:
  kill/waitpid/getfsstat/slotscan/ticks in C over __syscall;
  atoi/atol/getenv in PLAIN C (no asm at all).  FORCED the second
  fundamental --pile fix: **intra-pile C-to-C calls** (atoi -> atol)
  near-JSR'd a JSL-shaped entry — frame misaligned, hung.  Pile calls
  now use the zero-reloc PHK/PEA/RTL two-frame trampoline (segments
  load bank-aligned, so PEA target-1 is position-independent).
  M37/miscops MAME-42.  LESSONS: (1) missing-prototype AGAIN — no
  <stdlib.h> defaulted atol to int-return, truncating the long
  compare (a phantom "codegen bug" until the normal-vs-pile emission
  diff came back IDENTICAL); (2) run_runtime chunks carry NO env —
  getenv's positive path belongs to envtest in the FGX fast group;
  (3) waitpid(-1,WNOHANG) with no children at all is ECHILD -1 (0 is
  children-but-none-reaped); (4) bare wait with no children BLOCKS.
- **[x] C4 batch 6 — socket family** (9 fns): _sock_argblk written
  as extern-int-array stores from C; T6 bank wart survives as-is.
  M37/sockops MAME-42 (socket() = LAZY fd alloc headless; bad-fd errno
  paths for the rest; live-net stays human-gated).
- **[x] C4 batch 7 — kernel heap**: malloc/free/realloc (own-bank far
  returns compose through the fixed long->ptr cast); realloc proto
  ADDED to stdlib.h.  M37/heapops MAME-42 (heap cross-bank strcpy,
  realloc content preservation).  46/82 in C, 36 hand exports left.
  PROCESS RULE: never stage shim deletions while a differential is
  mid-run (3 spurious fails from the stale window; fresh 403/403).
- **[x] C4 batch 8 — spawn family** (spawnv/spawnve/popen/pclose):
  path staged via one C strcpy; envp built in C; spawnops MAME-42
  (C spawnv → /bin/true → C waitpid).  c_system deferred to the
  data-plumbing tier.
- **[x] C4 batch 9 — ioctl/gtty/stty/signal**: ttyops MAME-42; §6A
  handler contract preserved.  **54/82 in C, 28 hand exports left.**
- **[ ] C4 remaining batches**: spawn family (spawnv/spawnve/system/
  popen/pclose), signal (trampoline!), stat + sgtty/
  ioctl/gtty/stty, exit/time (delegate into libc.s internals), stdio
  FILE layer + strerror/perror, termcap tget*, then printf-in-C over
  va_list (frozen-prefix data plumbing) — retires libc_args + the
  9-arg cap.: syscall wrappers first (shim bug
  class dies), stdio over C2's va_list printf (retires libc_args +
  N_CALL_PRINTF), str/mem only when touched.  Per-TU: add
  lib/libc_c/<fn>.c, wire into the `make libc_c` recipe + a PUT is
  NOT needed (single libc_c.s per TU today — new TUs emit their own
  .s and join the PUT chains like isatty; data-bearing TUs must join
  seg1's frozen prefix).

- **[x] 2026-07-11 cast-defect DISSOLVED — was never an fcc bug**: the
  "two ptr<->long cast shapes drop the bank" known-issue was the
  CALLERS' missing prototypes — m10c/m10d/m10e probes AND tcops.c all
  called tgetstr with no declaration, so K&R implicit int-return made
  the caller rebuild the returned pointer with bank 0 (all three probe
  values decode exactly; the asm shim "passed" only because it ALSO
  returns the offset in A and the bank-0 deref landed on a nonzero
  byte).  Fixes: (a) c_tgetstr UN-PARKED (C version live, asm shim
  retired); (b) tcops.c declares `extern char *tgetstr()` and the
  deref check sharpened to `*cm == 27` (bank-sensitive: a bank-0
  misread can't fake the vt100 ESC) — MAME 42; (c) fcc now WARNS on
  implicit function declarations (once per name per TU, both call
  emitters, `warn_implicit_decl`) — the trap that bit three times
  (memset, atol, tgetstr) is fail-loud; it immediately caught
  libc_c.c's own undeclared strcpy (string.h added).  Goldens stayed
  407/407 byte-identical under the warning; differential 406/406.
- **[x] C4 batch 11 — stat surface**: c_stat fully in C (native 15-byte
  ST_* image -> POSIX struct stat translate; path staged via C strcpy
  into BufB; struct written through the caller's far ptr — bank-0
  HW-stack locals exercised); epoch math IN C (__lc_epoch mirrors the
  retired _libc_epoch: leap=year&3, pre-leaps=(yp+1)>>2, no seconds;
  _libc_epoch asm stays for c_time until its conversion); c_strerror
  as bank-recovering wrapper (message-table engine stays asm until the
  data tier).  M37/statops MAME-42 incl. bank-sensitive
  `*strerror(2)=='N'`.  **60/82 in C, 22 hand exports left.**

- **[x] DATA-PLUMBING TIER (2026-07-11)**: every seg1-side link now PUTs
  lib/libc_c_data.s after fcc_runtime_data (template-frozen offset —
  identical in every binary, so the shared pile code resolves its data
  everywhere): 50 toolchain link/wrap files + tests/multibank/
  dataseg.link.s + FGX tools/fgx2/seg1.link.s.in + tools/fas +
  fswbig + the gitignored generated per-tool copies.  Wiring proven
  byte-inert first (goldens 408/408 with NO regen while the data seg
  was empty).
- **[x] C4 batch 12 — system + time in C (FIRST pile-data users)**:
  c_system rides the C spawn surface with its argv table + "/bin/sh"/
  "sh"/"-c" literals as PILE STATICS (the tier proof); c_time =
  ReadTimeHex via __asm (new __asm_w2 lane) + the C epoch.  RETIRED
  asm: c_system, c_time, _libc_build_envp, _libc_epoch + _ep_mdays.
  M37/sysops MAME-42 — which first calibrated 31 and exposed a REAL
  FGX bug: **jsh -c returned 0 unconditionally**, so system() could
  never report failure; jsh -c now exits with last_status ($?).
  **62/82 in C, 20 hand exports left.**

- **[x] C4 batch 13 — the ENTIRE stdio FILE layer in C (2026-07-11)**:
  all 20 remaining hand exports converted in one tier — fopen/freopen/
  fclose/fread/fwrite/fgetc/getchar/fgets(REAL now, was a NULL stub)/
  fputc/fputs(127-byte staging cap GONE — direct far-ptr writes)/
  putchar/feof/ferror/clearerr/fflush/fileno/fseek/ftell/exit/perror.
  Same _libc_FILE_table (libc_data frozen prefix); entry access REBASES
  the FILE* offset onto our own far view (legacy 2-byte stdin/stdout/
  stderr DA cells make incoming banks untrustworthy — widening them is
  a noted later fix).  fopen("w") now TRUNCATES (unlink-first, the
  c_creat model — SYS_OPEN ignores O_TRUNC; the asm engine silently
  never truncated).  **fcc_libc_shims.s has ZERO hand exports left.**
  M37/stdioops MAME-42.
- **[x] fcc STRUCTURAL FIND (batch 13): ptr-subscript compound assign
  miscompiled** — `p[i] op= v` through a pointer VARIABLE pushed the
  element address as 2 bytes while the deref store-back read a bank at
  3,S and popped 4: garbage-bank write (fail-open) + a NEGATIVE
  emitter depth ledger (later locals read stack garbage, emitted
  literal `-3,S`).  Found live: __lc_getc1's `e[1] |= _IOEOF` never
  signaled EOF → jsh's /etc/profile fgetc loop WEDGED THE BOOT (every
  MAME test no-markered).  Fixed (emit_push_ptr + deref_store_byte
  routing); M37/ptrsub pins word+byte+post-op-local-read.  stack_check
  now also scans lib/libc_c.s (its underflow rule catches the class;
  the pile just wasn't in its net).  Debug lesson: run.py does NOT
  rebuild the disk — ./build.sh disk first, or the experiment is void.
  **82/82 entries in C.**

### C5 — printf-family finale (2026-07-11, second session)

- **[x] c_printf/c_fprintf/c_sprintf/c_snprintf in C** (lib/libc_c/
  libc_c.c, ~330 lines): ordinary variadic C over <stdarg.h>.  The
  engine is a faithful transcription of the pf_ asm engine — G-PF2
  sign/pad order, %s-only precision, 16-bit %d/%u/%x + 'l' 32-bit,
  %c ignores width, unknown spec emits '%'+char, truncating %f/%e
  digit loops over the SAME softfloat runtime ops ((long)f ==
  ftol(ffloor(f)) exactly at every float magnitude), %g P+1 digits +
  round-half-up + (-4 <= X < P) layout pick + trailing-zero strip.
  fd sink batches 64 bytes per SYS_WRITE; sprintf writes the caller's
  buffer bank-aware.  **snprintf is REAL now** (old binding aliased
  sprintf, size ignored; zero in-tree users — free upgrade).
  M37/pfvar pins the new surface (>9 args, snprintf truncation, '*'
  width, %.Ns, %c promotion, float VARIABLES through va_arg).
- **[x] fcc printf special path RETIRED**: N_CALL_PRINTF + both
  parse-arm intercepts, libc_args slot staging, the 9-arg cap
  (FCC_MAX_VARARGS), emit_printf_family_jsr, emit_pf_fmt_bank/
  emit_pf_out_bank, fpr_out.  Bindings map printf->c_printf etc.;
  the crux is one condition at the N_CALL_NAMED emit:
  `rtl_begin(&rtl, lb ? lb->is_variadic : ...)` so BOUND printf calls
  marshal right-to-left even from callers that never saw stdio.h.
  The pf_ asm engine + libc_args cells STAY in lib/libc.s — ~30
  hand-asm tools (cat, man, ping, od, ...) use the register ABI.
- **[x] fcc FIND: statement-position `arr[i]++` was an artificial
  reject** ("expected '='") while the same shape compiled as an
  expression.  Hit live by the %g carry loop (__lc_pf_dig[i]++).
  Statement subscript arm now reuses N_ARR_POSTINC (same gate:
  single subscript, int/char arrays).  M37/arrpost pins it.
- **[x] fcc STRUCTURAL RETIREMENT: RTL record-and-reverse GONE.**
  Routing every printf through the RTL marshaller instantly tripped
  its fail-loud guard (abiprobe.c `printf("%d", sb.st_mode)` — a
  struct-local field in a variadic arg is a raw n,S bake the
  reversal's u0-adjust can't reach).  Fix: walk_call_args now WALKS
  the arg subtrees in REVERSE source order when rtl->active (the
  whole-TU AST makes it free; record-and-reverse predated it), so
  every offset — raw bake or structured u0 snapshot — records at its
  true depth.  DELETED: ir_reverse_call_args, ir_op_carries_s_delta,
  g_rtl_marshalling/g_rtl_raw_param + the local_offset latch,
  rtl_arg_start/end, MAX_RTL_ARGS bounds/weights.  RtlArgs is now
  {active, has_struct}; only the by-value-struct-vararg die survives.
  Evaluation order was already R-to-L under the old replay, so no
  observable change.  M37/rtlraw pins the once-dying shapes (long
  param/local, struct-param/local fields, ptr-param deref in variadic
  args).
- Gates this session: goldens 414/414 + pile stack_check clean (x2
  regens); full MAME differential relaunched after the rtlraw find
  (first attempt died in build_userbin on abiprobe — the guard find).

## Branch

toolchain `feat/t5c-libc-in-c` off main (post-v1.2.0); FGX branch only
when the pile/bindings changes need FGX-side staging.  Standard train:
no release until the maintainer green-lights.
