# fcc front-end refactor: one recursive declarator (retire the K&R whack-a-mole)

## Status
- **Increment 1 — DONE** (toolchain `feat/fcc-declarator`, `9f7c4f45`):
  `Declarator` struct + `parse_declarator` (pointer chain + NAME/abstract);
  the CAST context converted. Gate: 475/475 byte-identical.
- **Increment 2 — DONE** (`d3fe1387`): struct/union members converted;
  size/offset switch kept, fed dims[0]/n_elems from the declarator. 475/475.
- **Increment 3 — DONE** (`aea2e4fc` 3a/3b + `1ac73514` 3c): parse_declarator
  extended to the full array grammar (multidim `[a][b]`, sizeless outer `[]`,
  and the G27 `T *name(...)` function-declaration shape via `is_func_proto`
  with params left unconsumed). `build_decl` (locals) and `parse_global_decl`
  (globals) both routed through it; the local sizeless-`[]` prescan moved to the
  post-pass, globals' sizeless→size_from_init deferral preserved (placeholder
  dim reproduced). Storage sizing / row_stride / every initializer unchanged.
  Gate: 475/475 byte-identical at each sub-step.
- **Increment 4 — DONE (the payoff)** (`348f8d1f`): the function return-type
  declarator + NAME routed through parse_declarator (is_func_proto); the
  **return-type whitelist DELETED**. Return types now derive via the same
  type_for_decl as every other context, so any base is legal (typedef'd pointer
  returns, union/enum returns — the tcsh `sh.h` class). struct-return-by-value
  reject kept as an explicit codegen-limit check. Gate: 475/475 byte-identical
  + new fixture `tests/M8/ret_typedef` (typedef'd + union pointer returns)
  compiles, links, and **runs 42 on FGX** (run_runtime oracle-validated).
- **Increment 5 — PENDING, and now a PROVEN tcsh dependency (2026-07-22, NOT
  just cleanup)**. tcsh P0 first-compile fails ~18/46 TUs at `parse_stmt.c:5527`
  "expected ';' after fn-ptr global decl", tripped by `ed.h:74 extern PFCmd
  CcFuncTbl[];` — an ARRAY of an fn-ptr typedef the scalar-only typedef-resolved
  global branch can't parse. So the earlier "no functional gap remains" framing
  is superseded: Inc 5 unblocks a real tcsh construct. It needs NEW productions
  in parse_declarator (grouping `(*fp)()` + function `(params)` + array-of-fn-ptr
  with in-band FnSig interning) to retire `parse_fn_ptr_declarator` (9 call
  sites) + `g_fnptr_decl_arr` + the cast's private fn-ptr parser. Real
  byte-identical risk across the interning sites, best done with fresh context.
  Resume: teach parse_declarator the grouping+function+array+FnSig-intern path,
  then convert the fn-ptr call sites one context at a time, each gated
  **477/477** byte-identical (the count on the integrated `feat/fcc-tcsh`
  branch). See `2026-07-22-tcsh-port-plan.md` P0 gap map.
- **Side item — PENDING**: `parse_typedef_def` char** fix (route through
  parse_declarator; today's single-`is_ptr`-flag caps typedefs at depth-1).
  A behavior change (newly-enables `char**`/derived typedefs) with
  typedef-resolution blast radius — needs its own fixture + hardware run.

**Release**: Increments 1-4 are a shippable toolchain (return-type class fixed,
byte-identical, hardware-validated). tcsh P1 can proceed against it. Increment 5
+ the typedef fix can ship in a later toolchain bump.

**Goal.** Replace fcc's ~5 copy-pasted ad-hoc declarator recognizers + 7
`parse_fn_ptr_declarator` call sites + the separate cast parser with ONE
recursive `parse_declarator(base) → Declarator`, conforming to the pcc K&R
grammar (`examples/2.11BSD/usr/lib/mip/cgram.y`; see
`docs/history/plans/fcc-knr-grammar-reference.md`). This deletes the return-type whitelist
and subsumes the whole class: fn-ptr params, `char **` returns, array-of-fn-ptr,
grouping `(*fp)()`, union/enum/typedef returns, and every not-yet-hit K&R shape.

**Non-goal.** Not a type-model change. `tword` already encodes ptr/ary/fn
derivations (INCREF/DECREF, 8 deep) and is pcc-shaped. `parse_type_spec`
(`parse_stmt.c:253`) already parses the base specifier and is already shared.
This refactor is **parser consolidation only** — the representation stays.

**Hard constraint.** The ~470-test golden suite (`tests/run.sh`) and the fcc
oracle stay **byte-identical / green at every increment**. Never a big-bang;
each phase is independently shippable and gated.

## The one impedance mismatch (design decision)

Functions are typed **out-of-band**: a `fn_sig_id` into the `FnSig` table
(`fcc.h:308`), NOT via the tword's `DERIV_FTN` (which is currently only a
sentinel). pcc puts arg types in the type node; fcc keeps them in a side table
that `emit_call_*`, fn-ptr load/store, and `Func/Global/Local.fn_sig_id` all
key on.

**Decision: keep the FnSig side-table; do not unify function types into the
tword.** The recursive declarator builds a proper `PTR<FTN<…>>` tword AND
interns a FnSig, returning **both** (`{tword type; int fn_sig_id}`). That is
the compatibility bridge that keeps codegen byte-identical while the front-end
becomes uniform. (Unifying arg types into the tword is a much larger, codegen-
touching change — explicitly out of scope; revisit only if ever needed.)

## The new core (Increment 0 — no behavior change yet)

```c
typedef struct {
    tword       type;        /* full derived type: PTR/ARY/FTN over base    */
    const char *name;        /* declared identifier, or NULL (abstract)     */
    int         name_len;
    int         struct_id;   /* BTYPE(type)==BT_STRUCT ? spec.struct_id : -1 */
    int         fn_sig_id;   /* interned FnSig if the declarator is/returns
                              * a function or fn-ptr; else -1                */
    int         n_dims;      /* array dimensionality (>=1)                   */
    int         dims[MAX_DIMS];
    int         row_stride;  /* multidim inner-stride (elems)               */
    int         is_unsigned; /* threaded from the base spec                  */
} Declarator;

/* Recursive, mirrors cgram.y nfdeclarator/fdeclarator:
 *   declarator := '*'* direct-declarator
 *   direct     := NAME | '(' declarator ')'          (grouping)
 *   direct     := direct '(' params ')'              (function)
 *   direct     := direct '[' e? ']'                  (array, repeatable)
 * abstract form: NAME optional (casts, params, sizeof).            */
Declarator parse_declarator(TypeSpec base, int allow_abstract);
```

Plus generalize the merge — extend `type_for_decl` (`main.c:214`) into a
`tymerge(base, deriv_chain)` that applies `DERIV_FTN` and *multiple*
`DERIV_ARY` levels (today it does pointer-depth + one array only). Keep the
existing pointer-depth output byte-identical (goldens depend on
depth-1 == old `LT_*_PTR`; `tword.h` guarantees this by construction).

Increment 0 lands the struct + `parse_declarator` + generalized merge as **new,
unused** code with unit exercises, plus a self-check that `parse_declarator`
reproduces `type_for_decl`'s tword for the pointer/array cases. Zero call-site
changes ⇒ zero golden churn.

## Incremental order (least blast-radius first)

Each increment: convert one context to `parse_declarator`, delete its ad-hoc
recognizer, run the full golden suite (must stay green), add/keep regression
fixtures, commit. Ship-able at each step.

### Increment 1 — casts / sizeof abstract declarators  *(most isolated)*
Context (e). `build_primary_ast` cast path (`parse_expr.c:1490-1614`) +
`sizeof` (`349-493`). Today a *completely separate* hand-rolled type parser
(own base handling, own INCREF loop, own inline fn-ptr cast). Convert to
`parse_type_spec` + `parse_declarator(…, allow_abstract=1)`. No name binding,
no storage/offset side effects ⇒ smallest blast radius, exercises the new
recursive parser against goldens first. Fixture: casts to `char**`,
`int(*)()`, `int(*)[4]`.

### Increment 2 — struct / union members
Context (d). `parse_struct_def` (`parse_stmt.c:90-226`). Bounded single loop.
Replace its own star-count / one-dim array / fn-ptr-field recognizers with
`parse_declarator`; **keep** the size/offset `switch` (`164-212`) and feed it
`dims[]`/`n_elems`/`struct total_size` from the declarator. Subsumes fn-ptr
member fields. Fixture: struct with `char **p; int (*fp)(); int m[3][4];`.

### Increment 3 — locals + globals  *(they already mirror each other)*
Contexts (b)+(a). `build_decl` (`parse_stmt.c:1802`) and `parse_global_decl`
(`5398`). Unify their declarator recognition through `parse_declarator`;
keep the two thin storage post-passes (local-slot vs global-byte:
`1997-2020` / `5501-5511`) consuming the declarator's `dims[]/n_elems/
row_stride`. Subsumes the sizeless-`[]` init prescan, the multidim locals,
and the `parse_typedef_def` single-star bug (`5893`, loses `char**` typedefs)
— route typedef through `parse_declarator` too. Keep the fn-ptr-global-init
path (`parse_fnptr_global_init/array`) as-is (it's initializer semantics, not
declarator shape). Fixtures: `char **envp;`, `int (*tbl[N])();`,
`typedef char **argv_t;`.

### Increment 4 — parameters + function definitions  *(highest risk, the payoff)*
Context (c) + the file-scope func path. `parse_func_decl_with_spec`
(`4572-4860`), the K&R type block (`4873-4955`), and `parse_program`'s
func-vs-var peek (`5980-5990`). The recursive `parse_declarator` naturally
subsumes: the **return-type whitelist** (deleted — the declarator's `()` says
"function", the base says "of what", any base legal), the `char **` return,
the K&R fn-ptr param, the array-of-fn-ptr `g_fnptr_decl_arr` side-channel
(now returned in-band), and multidim-param→pointer+row_stride. Keep the
K&R-vs-ANSI param dispatch, the `(void)`-vs-`()` unspecified-args rule
(G27), the RTL-ABI variadic flags, and struct-by-value-return reject (that's
a *codegen* limit, not a grammar one — keep it as an explicit post-merge
check, not a whitelist). This is where tcsh's `bad return type` dies for good.
Fixtures: `union wait *f()`, `enum e g()`, `sigret_t (*h())()`, plus the tcsh
`sh.h` construct that started this.

### Increment 5 — cleanup + close-out
Delete `parse_fn_ptr_declarator` (all 7 call sites gone), `g_fnptr_decl_arr`,
the per-context star/array loops, and the cast's private parser. Fold the old
whack-a-mole regression fixtures (K&R fn-ptr param, char** return) — they must
still pass, now via the unified path. Update `docs/history/plans/fcc-knr-grammar-reference.md`
with "done". Release the toolchain.

## Verification per increment
- `bash tests/run.sh` (full golden suite) green + **byte-identical** (the
  refactor is behavior-preserving; any `.s` diff is a bug unless it's a
  *newly-enabled* construct in a new fixture).
- `bash tests/farcalls/run_farcalls.sh` green.
- The multibank sweep (`python3 tests/run_runtime.py --multibank`) unchanged.
- New fixture(s) for the increment compile + run 42 on FGX (oracle).

## Sequencing vs. other work
- Independent of `feat/fcc-bsd-large` (dynamic tables + BSD headers), which
  ships first (v1.20.0) and unblocks tcsh's non-return-type gaps.
- This refactor is its own branch `feat/fcc-declarator` and its own release
  (v1.21.0), delivering the return-type fix + retiring the class.
- tcsh P1 (link the port) can proceed against v1.20.0 for everything except
  the `sh.h` return-type construct, which waits on Increment 4.
