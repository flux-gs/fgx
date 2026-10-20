# 2026-07-05 FGX/fcc architecture audit — evidence archive

Raw findings behind [`docs/history/plans/architecture-redesign.md`](../../plans/architecture-redesign.md)
(the ROADMAP adjunct). Point-in-time record; the redesign doc is the living
synthesis.

**Method.** A 46-agent research sweep (9 parallel survey readers → adversarial
verification of every load-bearing claim → completeness critic), followed by 4
targeted follow-up probes closing the critic's gaps. Claims marked CONFIRMED /
ADJUSTED (with corrected wording) / REFUTED; numbers were re-derived by
independent verifiers (grep/wc/git), not trusted from the surveys.

**Files.**

- `digest_skeleton.md` — the merged digest: all section summaries, verified
  claim verdicts, issue lists, open questions, critic gaps + contradictions.
- Survey sections (full issue detail + evidence refs):
  `fcc-frontend.md`, `fcc-backend.md`, `bug-taxonomy.md`, `fgx-banking.md`,
  `libc-runtime.md`, `bsd-shape.md`, `llvm-mos.md`, `gno-precedent.md`,
  `history.md`.
- Follow-up probes: `kernel-c-triage.md`, `syscall-abi-widening.md`,
  `libc-bank-independence.md`, `softstack-deletion.md`.

**Live defects surfaced by the audit itself** (also listed in the redesign
doc's Phase 0): the stmt-context struct-by-value `MVN $00,$00` miscompile
(parse_stmt.c:3400-3411), 9 latent wrong-bank libc shims (c_pipe, c_bind,
c_connect, c_sendto, c_recvfrom, c_send, c_recv, c_system, c_atoi), setjmp's
same-bank PHK (libc.s:2706), the c_signal/c_kill no-op stubs shadowing real
implementations, and the stale `n_data_segment` note in userland-abi.md:150.
