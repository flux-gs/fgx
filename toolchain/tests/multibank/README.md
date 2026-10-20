# Multi-bank far-pointer sweep (task #56)

A CI/pre-release gate for fcc's **DBR≠PB far-pointer bank class** — the recurring
"wrong bank byte" bug that is INVISIBLE in single-bank programs (where the data
bank register DBR equals the program bank PB, so every wrong bank choice is
byte-identical) and only manifests in multi-bank programs like the vi/elvis port.
Historically each instance was found by a real port crashing at runtime
("whack-a-mole"); this makes the whole class test-visible in one binary.

## What it is

One FGX2 **multi-bank binary shaped like vi** — ≥5 code banks + 1 data bank +
a soft-stack bank, linked by fgx_static as any static program is (`crt0_lib`,
`FGX2_FARCALL`, `FGX2_LONG_PTR`; `toolchain/tests/fixture_link.py`) and
padded with real port TUs (cat/cmp/df/cp/cal) so scale-dependent bugs reproduce.
Its `main()` (`driver.c`) runs N self-checking far-pointer **construct** fixtures
(`cNN_*.c`, one per far-pointer construct), each placed by `bankmap.json` so its
pointers cross a bank boundary, and exits:

| exit | meaning |
|------|---------|
| **43** | all constructs pass (GREEN) |
| **99** | preflight failed — the binary is not genuinely multi-bank; NO result is trustworthy |
| **100+id** | first failing construct's ID |
| other | harness/boot failure, not a construct verdict |

The driver prints `=MBi <id> P|F` per construct and `=MBEND <code>` to the screen.

Trust is guarded three ways (a false green is worse than no test): a fail-closed
**runtime preflight** (exit 99 unless data-bank≠code-bank, soft-stack≠DBR,
heap≠DBR), a per-build **anti-coincidence scan** (no fixture tag repeats at the
same offset in another bank), and ≥4-byte tags.  Cross-bank call/fn-ptr constructs
put their callee in a **separate extern-linkage TU** pinned to a different segment
(a `static` callee would be intra-bank = a false green); `gen_sweep_link.py` lints it.

## How to run

```sh
python3 tests/run_runtime.py --multibank      # build + boot; PASS iff exit 43
python3 tests/multibank/run_multibank.py      # same, direct (--no-rebuild to reuse the bin)
```

Needs local MAME + merlin32 (it boots an FGX2 binary).  Not CI-runnable as-is.

## Coverage instrument — the site-flip sweep

`flip/flip_sweep.py` flips each of fcc's PHK/PHB bank-emission decision sites
(`flip/enumerate_sites.py` → `flip/sites.json`), rebuilds fcc, boots, and records
which constructs go red → a **measured** site→construct matrix (`flip/MATRIX.md`,
raw `flip/matrix.json`).  A site that reds a construct is guarded; a site that reds
nothing is an enumerated coverage gap.  Run default + `FCC_NO_REGALLOC=1`.

```sh
python3 tests/multibank/flip/enumerate_sites.py    # regenerate after any fcc line-number shift
python3 tests/multibank/flip/flip_sweep.py --mode default   # ~8 min; --mode noregalloc for the 2nd pass
```

**Honest coverage claim:** the constructs regression-guard the known mole shapes
and the flip sweep *measures* which of the ~21 clean PHK/PHB sites each construct
reaches (see `flip/MATRIX.md`).  It does NOT cover the non-PHK/PHB bank *sources*
(`_fcc_ptr+2`, `#0`, soft-stack, heap) — those need per-kind mutations (follow-on) —
nor the libc/shim DBR-relative caller-buffer writes.  So "green" means "not one of
the covered construct shapes," **not** "no bank bug anywhere."

## Gates

- `tools/gate.sh` runs the sweep (via `toolchain/tests/multibank/run_multibank.py`)
  together with the runtime fixture oracle whenever the fcc and toolchain sources
  change, as tracked by a content hash covering emit.c, parse_expr.c, parse_stmt.c,
  macros.s, crt0_lib.s, and libc.
- Run it locally whenever you touch those files.

## Gotchas

- `run_runtime.py` rmtree's `disk_src/tests/fcc` on exit; the sweep runners recreate
  it each boot AND clear the stale `dump.txt` first — else a boot that fails to
  stage returns the previous run's markers (a silent stale-dump false green).
- Ballast is compiled PLAIN (no `--far-calls`/`--data-segment`) so its symbols stay
  segment-local (real tools share `FGX2_EXPORT` fn names + data-segment globals);
  it is inert, so its wrong-bank runtime behavior is moot.
