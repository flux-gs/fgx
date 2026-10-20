# Scoping: fcc/ld → BSD-era link-time symbol resolution

**Date:** 2026-07-12
**Status:** SCOPING (design only — no code)
**Supersedes:** the TEMPORARY arity-guarded libc binding (`g_libc_user_overrides`,
merged 2026-07-12, toolchain `f26f0a1c` / FGX `57a02941`). This is the "true fix"
The maintainer deferred when approving the temporary one.
**Trigger:** elvis defined its own `getkey(when)` and fcc's compile-time libc
table silently rewrote every call to the `c_getkey` pile primitive → vi never
painted. That is one instance of a 116-name hazard class.

---

## 1. The problem

fcc binds libc names to pile symbols at **compile time, unconditionally**, before
the linker runs. A user program that legitimately defines a function whose name
collides with a libc-table entry is silently overridden by the library. This is
**non-standard C** — K&R/2.11BSD and every era-appropriate Unix toolchain give the
user definition precedence, because the compiler emits plain symbol references and
the *linker* resolves them: user `.o` files first, archive (`libc.a`) members
pulled only for still-undefined symbols. The collision cannot happen there.

Goal: move FGX to that model — the compiler stops knowing about libc; the linker
resolves a plain name to the user's definition when one exists, falling back to the
shared libc pile otherwise. This deletes the entire hazard class (and the temporary
override table) rather than patching names one at a time.

---

## 2. Current architecture (three coupled layers)

**(a) fcc binding table** — `src/cc/globals.c` `g_libc_bindings[]`, 116 entries
mapping C source name → `c_`-prefixed pile symbol (`{"getkey","c_getkey",0}`),
plus a variadic bit. `libc_bindings_lookup()` (symtab.c) is consulted at BOTH call
emitters (`parse_expr.c` ~3528, `parse_stmt.c` twin). When a name is in the table
the emitter emits `FGX2_FARCALL <c_name>` and forces variadic marshalling from the
table bit; otherwise `FGX2_FARCALL <plain name>`.

**(b) the pile** — one shared code segment (`KIND=LIBC`, a kernel-registered
singleton, T5-A emit-once). C-implemented entries live in `lib/libc_c.c` →
`lib/libc_c.s`, whose functions are literally *named* `c_getkey`, `c_read`, … in
the C source and exported `FGX2_EXPORT c_getkey`. Hand-asm entries live in
`lib/libc.s`, exported `LIBC_EXPORT <name>`.

**(c) fgx_ld** — `src/ld/fgx_ld.py`. `FGX2_FARCALL <name>` is resolved
**globally**: it searches *every* segment's exports (main() ~752). Unresolved →
fatal; **exported by >1 segment → fatal ("ambiguous")**. That ambiguity-death is
*exactly why the `c_` prefix exists*: it guarantees a libc symbol can never share a
name with a user symbol, so the global search is always unambiguous.

## 3. Findings that de-risk the change (verified in-tree 2026-07-12)

1. **Plain-name libc already works.** `{"getpid","getpid",0}` maps to a *plain*
   name; the pile exports `getpid` via `LIBC_EXPORT getpid`; user programs
   `FGX2_FARCALL getpid` and the global resolver finds the pile. The only reason it
   doesn't collide is that no user defines `getpid`. **The target model is already
   in production for one symbol** — we are generalizing the `getpid` shape to all.
2. **Near/far does not depend on the table.** Emission farness is `!g_pile`
   (`emit_call(name, len, !g_pile)`) — every call in a user program is already far.
   Dropping the table does not change near/far; libc calls just become ordinary
   extern far calls, which fcc already emits for cross-TU user functions.
3. **Zero external `c_` callers.** No kernel/tool/hand-asm file references any `c_*`
   symbol outside `lib/libc_c.s`. Renaming the pile's C entries is fully contained
   to pile source + the fcc table — no kernel ripple.
4. **Only 4 variadic entries** (printf/fprintf/sprintf/snprintf) — BUT the table's
   is_variadic bit is doing more than it looks: it *normalizes* the marshalling ABI
   for all 116 names irrespective of the caller's declaration. Removing it shifts
   that decision to the local decl, which regresses K&R empty-paren externs and
   undeclared variadic calls. This is the plan's #1 risk, not a footnote — see §6.

## 4. Target design — archive emulation via weak/strong precedence

**Compiler:** emits plain `FGX2_FARCALL getkey` for every non-local call. No libc
knowledge. (The binding table, the override table, and the `lb` emit branch all
delete.)

**Pile:** every libc entry exports its **plain** name (rename `c_*` → `*`,
following the `getpid` precedent), marked **weak** — "library-provided, yields to a
user definition."

**Linker:** `FGX2_FARCALL`/`FGX2_LONG_PTR` global resolution gains precedence:
- partition the matching exports into **weak** (from the `KIND=LIBC` singleton) and
  **strong** (from **every other segment, regardless of kind** — CODE *and*
  DATA/RODATA);
- ≥1 strong → require exactly one (≥2 strong is a genuine duplicate-symbol error,
  as today) and bind it — **user wins**;
- 0 strong, 1 weak → bind the pile — **library fallback**.

**The partition is "weak = the LIBC segment; strong = everything else" — NOT
"strong = CODE".** DATA/RODATA segments export named symbols too: `FGX2_LONG_PTR`
resolves user globals and the string pool against them (fgx_ld.py ~691). A user
global that happens to share a libc name (e.g. old code with `long time;`) must
resolve to the *variable*, so a data-seg export has to count as strong. Keying
"strong" off `KIND=CODE` would drop data exports into neither bucket → wrong bind.

No new "weak" macro is strictly required: the LIBC segment is already a linker-known
singleton (main() ~804), so "exported by the LIBC segment ⇒ weak" is a free
classifier. (A `LIBC_WEAK_EXPORT` marker is an option if we ever want weak symbols
outside the pile; not needed now.)

**Scope limit — this is caller-side archive emulation, not full BSD.** The pile is
*prebound*: `libc_c.s` contains zero FARCALL/LONG_PTR rows (pile-internal calls are
near-JSRs fixed at pile-assembly time) and the LIBC gate forbids any reloc patching
into the shared image. So a user's strong definition wins at the **user's own call
sites**, but the pile's *internal* calls never rebind — `strdup`→pile-`malloc`
forever. A program that overrides `malloc`/`free` therefore gets a **split-brain
heap** (pile allocates a FILE buffer, user frees it). Real BSD would rebind the
archive member's ref too; we cannot, without breaking emit-once sharing. This is an
accepted limitation, not a bug — but §6/Phase 0 must flag any user-defined name the
pile calls internally (malloc/free/realloc/read/write/strlen/…).

Result: elvis's `getkey(when)` (strong, in its own bank) wins over the pile's weak
`getkey` at every one of its call sites, across all TUs, with **zero** special
cases — and `more.c`/`unix.c`, which define no `getkey`, fall back to the weak pile
primitive. The temporary override table is deleted.

## 5. Touch points

| Component | Change | Size |
|---|---|---|
| `src/ld/fgx_ld.py` | strong-over-weak precedence in the FARCALL + LONG_PTR resolve loops; LIBC-seg = weak | ~25 lines |
| `lib/libc_c.c` | rename `c_*` fns → plain names, BOTH the definitions AND every internal call (source mixes `strlen(s)` and direct `c_malloc(...)` — catch both directions) | mechanical, ~110 fns |
| `lib/libc.s` | **NOT no-change**: hand-asm `printf`/`fprintf`/`sprintf` are plain-`LIBC_EXPORT`ed *register-ABI* entries that will DUPLICATE the renamed `c_printf`→`printf` (scan_listing dies on dup name, fgx_ld ~389) — the hand-asm trio must be deleted/retired first, and their remaining pile-internal callers audited. `setjmp`/`longjmp`/`getpid`/`ticks`/`today_init` are plain with no `c_` twin → fine. | medium |
| `src/cc/globals.c` | delete `g_libc_bindings[]` + `g_libc_user_overrides[]` | −130 lines |
| `src/cc/symtab.c` | delete `libc_bindings_lookup` + `libc_user_override_argc` | −40 lines |
| `src/cc/parse_expr.c` / `parse_stmt.c` | delete the `lb` lookup + emit branch; collapse to plain path | −40 lines |
| `src/cc/fcc.h` | delete `LibcBinding` / `LibcUserOverride` decls | small |
| headers (`include/`) | ensure the 4 variadic fns declare `...`; audit any libc fn relying on the table for correct marshalling | audit |
| tests | new fixtures (§8); full golden REGEN (the `c_*` → plain rename changes EVERY libc-calling golden) | large regen |

**Net: fcc gets simpler** (a whole subsystem deleted); the linker gains one small
precedence rule; the pile is a mechanical rename. This is a subtraction, not an
addition.

## 6. Risks & mitigations

- **★ #1 RISK — the binding table is an ABI *normalizer*, not just a name map.** At
  emission fcc uses `lb ? lb->is_variadic : g_funcs[fn_idx].is_variadic_expl` to pick
  the marshalling layout (parse_expr.c:3534). Today the table **forces** the layout
  for all 116 names regardless of the declaration in the caller's scope; delete it
  and the layout comes from the local decl — and `is_variadic_expl` flips on
  `saw_ellipsis || empty_parens`, which **reverses push order and callee param
  offsets**. Two works→garbage regressions open up:
  - a TU-local **K&R empty-paren extern** — `char *malloc();`, `int read();`, the
    single most common 2.11BSD idiom — makes the caller `expl=1` → **swapped args
    for every ≥2-arg libc call in that TU** (1-arg calls are layout-invariant, so
    breakage is sparse and maximally confusing);
  - **calling a variadic libc fn with no declaration at all** (implicit decl →
    `expl=0`) works today only because the table forces `1`; post-change it silently
    reverses args.
  *Mitigation (this is the real Phase 0):* grep **every userland TU** for (a)
  empty-paren `extern` declarations of any of the 116 names, and (b) call sites of
  the 4 variadic names with no `...` prototype in scope. Fix each to a proper ANSI
  prototype (usually: include the right header) BEFORE fcc stops normalizing. This
  is the largest concrete risk in the plan.
- **Split-brain heap (see §4 scope limit).** Because the pile is prebound, a user
  who defines `malloc`/`free`/`realloc` overrides only its *own* call sites; the
  pile keeps calling its internal `malloc`. Allocator ownership can cross the seam
  (pile allocates, user frees). *Mit:* Phase 0 census flags every user-defined name
  the pile calls internally; document as a known limitation; if a real port needs to
  override the allocator, that is a separate (harder) design question.
- **Hand-asm printf trio collision.** `lib/libc.s`'s plain register-ABI
  `printf`/`fprintf`/`sprintf` duplicate the renamed pile names → loud link death.
  *Mit:* retire/rename them in the same phase as the rename (§5, §7).
- **Golden churn.** Renaming `c_*`→plain rewrites every libc-calling golden. *Mit:*
  one full `REGEN=1 tests/run.sh` at the end; runtime oracle is the real gate. Do
  rename + regen as one commit.
- **A second user-defined strong collision** (two userland objects both export the
  same plain libc name in one link) now surfaces as a hard "duplicate symbol" error
  instead of silently taking the pile. Correct BSD behavior, but a new failure mode
  — the Phase 0 census (below) surfaces it.
- **Stricter than the temporary fix.** The temp arity-guard deliberately KEPT the
  pile binding for *matching*-arity user redefs and only diverted mismatched-arity
  calls. The weak rule flips ALL user-defined-name sites to the user def. The
  census must diff exactly these newly-flipped same-arity sites.
- **`system.c` latent collisions** (access/ioctl/geteuid) the temp fix did NOT
  address are resolved *for free* here (user def wins) — acceptance checks, not work.

## 7. Phasing (each phase independently green)

- **Phase 0 — audit/census (the load-bearing phase).**
  (a) confirm zero external `c_` callers — DONE: zero.
  (b) **ABI-decl audit (the big one):** grep every userland TU for empty-paren
  `extern` decls of any of the 116 names, and for variadic-name calls with no `...`
  prototype in scope; fix each to a proper ANSI prototype. Without this, deleting the
  table swaps args (see §6 #1).
  (c) **collision census:** grep all userland `.c` for *definitions* of any of the
  116 names (not just the known elvis/system.c/more.c cases) → name list + expected
  resolution (user-strong vs pile-weak) + explicit diff of same-arity sites the temp
  fix kept pile-bound and the weak rule now flips.
  (d) **pile-internal-override census:** list the names the pile calls internally
  (malloc/free/realloc/read/write/strlen/…) and flag any that userland also defines
  → split-brain-heap watch (§4).
- **Phase 1 — linker precedence (additive, inert).** Add weak(LIBC)/strong(everything
  else) precedence to the FARCALL + LONG_PTR resolve loops. While the pile still
  exports `c_*` and fcc still emits `c_*`, behavior is unchanged. Land with fixtures:
  (i) user redefines a libc name → user wins; (ii) two users define it →
  duplicate-symbol error; (iii) only pile → pile. **Fixture (i)/(iii) need a
  hand-built `KIND=LIBC` segment exporting a plain name** (the real pile exports only
  `c_*` until Phase 2) — build a tiny synthetic pile in the fixture harness.
- **Phase 2+3 — pile rename + fcc-emits-plain, as ONE atomic toolchain commit.**
  These CANNOT be cleanly separated: 0-byte export markers are one-name-per-label and
  dup-per-listing is fatal, so there is no free "dual-export" — and the pile's own
  internal plain calls (`strlen`) only resolve once the source is renamed, which is
  the same rename fcc's plain emission needs. So do it together: rename `libc_c.c`
  `c_*`→plain (defs + both call directions), retire the hand-asm printf trio, delete
  the fcc binding + override tables and the `lb` emit branch. fcc now emits plain
  `FGX2_FARCALL <name>`; the weak rule engages. (Alternative if atomicity is too big:
  add a transitional `g_pile`-only **dual-export** capability to fcc so the pile can
  emit both `c_foo` and `foo` markers — more fcc work, but lets Phase 2 land before
  Phase 3. Recommend the atomic commit unless the diff proves unmanageable.) Full
  golden REGEN + runtime oracle + elvis paints with the override table DELETED.
- **Phase 4 — cleanup + verify.** Delete any residual `c_*` names/aliases. Final
  REGEN; whole-userland runtime sweep; MULTIBANK_VERIFIED run (bank-emission path
  changed). Update ledgers; the temporary override table is gone; `getkey_shadow`
  fixture passes with the table absent (proves the true fix subsumes the temp one).

## 8. Acceptance tests

- **Regression fixtures** (Phase 1): `ld_weak_user_wins`, `ld_weak_dup_strong_err`,
  `ld_weak_pile_fallback`. Plus keep/retarget `tests/M37/getkey_shadow.c` (it should
  pass with the table *deleted*, proving the true fix subsumes the temporary one).
- **printf-arg-order fixture** (Phase 0/3): variadic marshalling from header only.
- **elvis** (Phase 3/4): `vi /etc/hostname` paints; editing/save/`:wq` exercised;
  the `access`/`ioctl`/`geteuid` system.c collisions resolve to elvis's own with no
  override entries.
- **Whole-userland runtime sweep** (Phase 4): every shipped binary still exits its
  oracle code; no unresolved/ambiguous link failures.

## 9. Open questions for the maintainer

1. **Weak marker granularity** — implicit "LIBC segment ⇒ weak" (zero pile-source
   change beyond the rename), or an explicit `LIBC_WEAK_EXPORT` macro (documents
   intent, allows weak symbols elsewhere)? Recommendation: implicit now, macro later
   only if needed.
2. **Duplicate-strong policy** — hard error (BSD `ld` behavior; recommended) vs
   first-wins with a warning. Error is safer and matches the era.
3. **Rename vs alias in the pile** — rename `c_*`→plain outright (cleaner, bigger
   diff) vs keep `c_*` as internal labels with plain `LIBC_EXPORT` aliases (smaller
   diff, leaves dead names). Recommendation: outright rename in Phase 4.
4. **Release shape** — one toolchain release at the end of Phase 4, or a
   checkpoint release after Phase 1 (linker precedence is independently useful)?
   Given the campaign hold, likely all local until the userland-ports campaign
   closes.
