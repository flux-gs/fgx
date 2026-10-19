# Optional-tier pile retirement — scoping (2026-07-19)

**Context.** The multi-archive-linker P2 (2026-07-19, `feat/multi-archive-linker`)
gave the optional per-tool library tier real member-level `.fgxa` archives:
curtest/worm/robots now compile a *filtered subset* of curses via `fgx_ar select`
instead of the whole `libcurses.c` aggregate. That raised the question: can the
old whole-pile `.s` artifacts (`lib/libcurses.s`, `lib/libtermlib.s` + their
`_data.s`) now be **deleted**? This doc scopes that. It is a design, not an
implementation.

**Bottom line up front: mostly NO — retirement is low-value right now.** Each
surviving pile still earns its keep, and the archives do **not** subsume those
uses. The one real smell is *dual-maintenance* (pile `.s` AND archive built from
the same `.c`), which is cheaply managed without deleting anything. `libc_c.s`
/ `libfgx.s` are the **shared object** and are explicitly out of scope (the .so
lineage — never member-stripped; see the multi-archive-linker scoping doc).

---

## 1. Grounded consumer inventory (2026-07-19)

| Pile | Linker consumers | Gate / other |
|------|------------------|--------------|
| `libcurses.s` / `libcurses_data.s` | **NONE.** curtest/worm/robots migrated to the `curses.fgxa` archive; elvis has its **own** `curses.c` TU (`gen_elvis_link.py` `TUS`), it does **not** link `libcurses.s`. | `tests/run.sh:245` `stack_check` |
| `libtermlib.s` / `libtermlib_data.s` | **elvis** — whole-pile PUT via `gen_elvis_link.py` `EXTRA_PILES={"__termlib":[LIBTERM_H,LIBTERM]}` → `seg3.link.s` / `_m___termlib.link.s` / `dataseg.link.s`. | `tests/run.sh:241` `stack_check`; `build.sh:309` elvis freshness dep |
| `libc_c.s` / `libfgx.s` | every tool (shared seg2) + elvis | gate; **OUT OF SCOPE** (shared object) |

---

## 2. Per-pile assessment

### 2.1 `libcurses.s` — keep as the gate's whole-graph stack-check unit
No tool links it, so "delete it" is tempting. But the toolchain gate
`stack_check`s it, and that check is **more complete than the alternatives**: the
aggregate walks the *entire* curses call graph in one unit, catching cross-member
recursion depth that per-member `.s` checks would miss (a member calling another
member is a same-unit near-JSR in the aggregate; split across 39 member `.s`, no
single check sees the composed depth). The per-tool filtered aggregates
(`curtest`'s `curses.sel.s`) are transient build artifacts, not checked in, and
each covers only one tool's subset.

So `libcurses.s` is **not dead — it is the curses stack-safety oracle.** Deleting
it means replacing that coverage:
- **Option A (weaker):** `stack_check` the 39 `curses.fgxa/*.s` members — loses
  cross-member depth composition.
- **Option B (equivalent):** keep generating the aggregate *purely* for the gate
  — i.e. exactly what we have. Rename intent: it's a "stack-check aggregate," not
  a link pile.
**Recommendation: keep it, relabel it a gate artifact.** Zero code, full coverage.

### 2.2 `libtermlib.s` — keep for elvis; retirement buys nothing
elvis links the whole termlib pile through its bespoke multi-bank linker
(`gen_elvis_link.py`). Retiring it would mean teaching elvis's linker to consume
the `termlib.fgxa` archive via `fgx_ar select`. But **termlib is a single-member
archive** — `select` would pull the one member, i.e. the whole pile. **Zero
dead-strip benefit, real integration cost.** Not worth it until (a) termcap is
split into multiple members *and* (b) elvis's linker speaks the archive protocol
— neither is on the horizon.
**Recommendation: keep it.**

### 2.3 `libc_c.s` / `libfgx.s` — out of scope
The shared object (T5-A/B: one system-wide copy, byte-canonical). Never
member-stripped. Not a retirement candidate.

---

## 3. The one real issue — dual-maintenance / drift

The genuine smell: `libcurses.s` (gate) and `curses.fgxa/*.s` (what tools link)
are **two artifacts generated from the same `lib/libcurses_c/*.c`**. Edit a curses
member and regenerate only one, and they **drift** — the gate would stack-check a
`libcurses.s` that no longer matches the archive members the tools actually link.
Today `make libcurses` and `make archives` are independent targets; nothing
enforces they regenerate together.

**Fixes, cheapest first:**
1. **Couple the targets (recommended, tiny):** make `archives` also regenerate
   the gate aggregate (or make the gate `stack_check` the archive's own members —
   accepting §2.1 Option A's weaker coverage). One `make` command, one source of
   truth.
2. **Derive the aggregate from the archive:** the gate's stack-check aggregate is
   just a concatenation of `curses.fgxa/*.s`; generate it from the archive so the
   archive is the single source and the aggregate is trivially derived. Removes
   drift by construction.
3. **CI drift guard:** a `--check` that fails if `libcurses.s` is stale vs the
   members (mirrors the syscall-table / w5100-patchsite `--check` pattern).

---

## 4. Recommendation & phasing

**Do now (in/after the P2 release, small):**
- Relabel `libcurses.s` in `tests/run.sh` + the Makefile as the **curses
  stack-check aggregate**, not a link pile (comment only — prevents a future
  reader "deleting the dead pile" and breaking the gate, exactly this doc's trap).
- Couple regeneration (§3.1) so `libcurses.s` cannot drift from `curses.fgxa`.

**Defer (no payoff yet):**
- Deleting `libtermlib.s` — blocked on elvis's linker speaking the archive
  protocol AND termcap being multi-member. Revisit only if a *second* termcap
  consumer or a real termcap split appears.
- Deleting `libcurses.s` outright — only if the gate moves to per-member
  stack-check (§2.1 A) and accepts the weaker cross-member coverage. Not worth
  the coverage loss now.

**Never:**
- `libc_c.s` / `libfgx.s` (shared object).

Net: the "retire the piles" cleanup that motivated this doc is ~one comment + one
coupled make target. The piles themselves stay — they are not dead, they are the
elvis termcap link and the curses stack-safety oracle. Ledger:
`project_fgx_multi_archive_linker`.
