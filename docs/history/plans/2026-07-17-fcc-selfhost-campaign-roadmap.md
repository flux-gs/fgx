# fcc self-host campaign — sub-roadmap (chartered 2026-07-17, planned at train-3 close)

**Goal:** "build FGX software inside FGX" — `cc hello.c && hello` works
on-device, and ultimately fcc compiles ITSELF on FGX, byte-matching the
host-built artifact. `fas` already self-hosts; fcc (+ the linker) is the
missing half. Sequenced AFTER the preemption campaign per the standing
north-star ordering (doesn't need multitasking, benefits from a stable base).

**Train order (Fable-reviewed 2026-07-17):** S0 → S1.5 (catalogued compiler
gaps, toolchain-first) → S1 ∥ S2-audit → S2 (+S2a execution venue) → S4 →
S5.  This supersedes the roadmap's earlier "gaps deferred until self-host
demands them" phrasing: the demand has now arrived, so they land as
ordinary correctness trains BEFORE any source-bending.

## Inventory (2026-07-17)

- **fcc**: ~9 TUs of K&R-flavored C on the host; multi-pass front end
  (whole-TU token vector → AST) since toolchain v1.0.0 — the source-replay
  class a self-host would have tripped is already retired.
- **fas**: self-hosts on-device today (assembles hello.s on FGX).
- **fgx_ld: 950 lines of HOST PYTHON** (`toolchain/src/ld/fgx_ld.py`) —
  segment layout, manifest, FGX2/FGX3 emit, reloc. Previously buried inside
  "the on-device pipeline"; this is a first-class port, not a footnote.
- **Memory shape** (T2-4 report): worst front-end footprint ≈1 MB at a
  packed 16-byte Tok for fcc's own largest TU. The multi-bank 32-bit
  `malloc` this needed SHIPPED in train 2 (toolchain v1.13.0 / FGX v1.8.0)
  — a major prereq quietly cleared.
- **Capacity ceilings** (fcc-known-issues §G): globals 64 / functions 64 /
  structs 32 / string literals 64 … — fcc's own source exceeds most.
  Fail-loud today; lifting is mechanical (sizes → config + arena-backed).
- **Single-TU model (F-1)**: `extern` parsed-and-ignored; fcc is 9 TUs.
- **`#`/`##` token paste + unsigned hex literals**: known gaps, catalogued.

## The sequencing insight: self-compile on the HOST first — with one caveat

"fcc compiles fcc" and "fcc runs on FGX" are separable risks. The subset
audit, the ceilings, and the multi-TU decision all de-risk on the Mac with
full debuggability. **The caveat (Fable review): fcc targets 65816 only, so
fcc-built-fcc is a 65816 BINARY — it cannot execute on the Mac.** The
correctness oracle ("fcc-built-fcc produces byte-identical output across
the golden corpus") requires an execution venue: either the toolchain's
65816 oracle/simulator harness grown enough libc/syscall surface to run
fcc itself (fopen/printf/malloc — nontrivial), or MAME+FGX with scripted
file I/O (which drags part of S4 forward). Naming and costing that venue
is an explicit S2 deliverable (S2a below), and S0's wall-time projection
must cover the harness leg too.

## Trains

- **S0 — measurement spike (small, do first).** (a) On-device throughput
  proxy: time fas assembling a large listing + a synthetic byte-crunch tool
  at 2.8/7 MHz → tokens/sec model → projected fcc self-build wall-time
  (hours is acceptable for a bootstrap; DAYS is a showstopper — measure,
  don't guess). (b) Host-side arena accounting: instrument fcc's allocators,
  compile fcc's own TUs, get the true peak at packed-Tok → the on-device
  budget number the T2-4 report deferred.
- **S1 — fgx_ld → C.** Port the 950-line linker to fcc-subset C. Dual-target
  from day one: clang-host build IS the oracle (same source, byte-compare
  emitted binaries across the whole build corpus), fcc build proves the
  subset. Ships host-side value immediately (one less Python dependency)
  and is the on-device linker later.
- **S1.5 — the catalogued compiler gaps FIRST (toolchain-first rule).**
  `#`/`##` token paste + unsigned hex literals + any other KNOWN fcc gap
  land as ordinary correctness trains with fixtures BEFORE the source
  audit — bending fcc's own source around known compiler bugs and fixing
  the compiler afterwards is precisely the anti-pattern the standing rule
  forbids. S2's audit then handles only genuine subset-distance items
  (constructs fcc legitimately doesn't do).
- **S2 — fcc-hosted-fcc.** Bend fcc's source into the fcc-accepted subset
  (the M12 notes seed the audit; only legitimate-subset items after S1.5),
  lift the capacity ceilings, decide multi-TU: true `extern` cross-TU
  linking vs the disciplined concatenation build (S0's arena number
  decides). **S2a — the execution venue** (see caveat above): stand up the
  harness that RUNS fcc-built-fcc — oracle-sim vs MAME, decided by the
  libc-surface cost. MILESTONE: fcc-built-fcc passes the full golden
  corpus byte-identically in that venue. The campaign's center of gravity.
- **S4 — on-device pipeline.** Stage fcc.bin + fas + ld + headers + libc
  piles on the disk; a `cc` driver (jsh script or small C tool) runs
  compile → assemble → link; `cc hello.c` on FGX. Needs: file sizes/paths
  within ProDOS limits, tmp-file hygiene (the FS crash-safety history),
  and the S0 time budget to set expectations.
- **S5 — the flip.** fcc-on-FGX compiles fcc's own source; artifact
  byte-compares against the host build. FGX is self-hosting; toolchain
  releases can thereafter be BUILT on FGX (even if development stays
  host-side for speed).

## Showstopper register

1. **Build wall-time at 7 MHz** — the one risk that could kill the goal
   outright; S0 measures it FIRST. Mitigations if bad: compile per-TU with
   on-disk intermediates (already the pipeline shape), overnight builds,
   or scope self-host to "can rebuild any single tool" rather than "rebuilds
   the whole toolchain routinely."
2. **fgx_ld port fidelity** — 950 lines of layout/reloc subtlety; the
   byte-compare oracle across the corpus is the answer (S1's design), plus
   it runs host-side long before it must run on-device.
3. **Front-end memory on-device** — believed ~1 MB packed vs 8 MB machine
   (minus kernel/FS/screen claims); S0(b) replaces belief with a number.
   Per-function AST windowing already caps the parse side.
4. **Subset distance** ("can fcc parse fcc") — unmeasured since M12 was
   parked; chained assignment already landed; S2's audit quantifies the
   rest. History says each gap is small and additive (six fcc fixes in one
   compress port week).
5. **stdio/host-API surface of fcc itself** — fcc uses host libc (fopen,
   printf, malloc); FGX libc now covers the set, but S2 must pin fcc to the
   PORTABLE subset (no host-isms) — enforced by the dual-build from S1 on.

## Acceptance (campaign)

`cc -o hello hello.c && hello` on FGX prints; fcc-built-fcc (host) is
golden-corpus byte-identical; fcc-on-FGX-built fcc byte-matches the host
artifact; the toolchain release notes carry the measured on-device build
time as the headline number.
