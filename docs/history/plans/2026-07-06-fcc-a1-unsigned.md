# A-1 audit: unsigned semantics — drop sites, missing runtime, fix plan

*2026-07-06. Probe-verified + two exhaustive sweeps (fcc lifecycle map;
FGX exposure inventory). Precedes the implementation.*

## What A-1 actually is (registry headline was stale)

`unsigned` is NOT "silently treated as signed" wholesale — it is **partially
landed** (M23-era): `is_unsigned` flags exist on Global/Local/param/Field,
the transient `g_expr_unsigned` feeds `g_binop_unsigned = lhs||rhs`, and the
16-bit unsigned runtime exists and is selected in tracked positions
(`_fcc_{ltu,gtu,leu,geu,divu,modu}16`). Simple locals, globals, dot-members,
and params compare/divide correctly today — MAME-validated by M23/u_cmp,
u_div, u_param. There is no branch-fused compare path; every comparison
routes through the `emit_cmp_*` selectors, so fixes concentrate there.

## The silent-wrong surface (verified)

1. **Array/indexed element loads drop the flag** (~15 A-1-marked reset
   sites in emit.c/parse_expr.c) → `u_arr[i] > x` compares signed.
2. **Function returns**: STRUCTURAL — neither `Func` nor `FnSig` has a
   return `is_unsigned`; every call-result site resets to 0.
3. **`ptr->field`** (`emit_deref_ptr_field` resets; callers hold the Field).
4. **`(unsigned)` casts** — the single cast-result site defaults signed.
5. **`unsigned long` = LT_LONG + an ignored flag**: the compare/div/mod
   selectors short-circuit on LT_LONG before the unsigned check, AND the
   unsigned long runtime does not exist (no `long_{ltu,gtu,leu,geu}`, no
   `long_divu/modu`, no logical long shr). `unsigned long >> n` uses the
   ARITHMETIC `long_shr` (sign-fills).
6. **Compound assigns** hard-force `g_binop_unsigned = 0` (emit.c:3254).
7. **No unsigned-literal concept** (lexer has `is_long` only) — 0xFFFF
   compares signed.
8. **Signed `>>` is LOGICAL** — `_fcc_shr16` is a bare LSR loop and the
   selector never consults signedness; a negative `x >> n` zero-fills.
   (The registry framed ">> was already logical so unsigned-correct" —
   true, but the signed side is the bug.)
9. **Postfix `++`/`--` results** reset to signed.

Also verified: `eq/ne` and `*` are signedness-free (correct to ignore);
char loads ALWAYS zero-extend (`AND #$00FF` — signed char is effectively
unsigned in promotion, a separate latent quirk, out of scope);
`short`/`unsigned short` collapse to `LT_INT`(+flag); widening picks
zero- vs sign-extend correctly off `g_expr_unsigned` — it is only fed
garbage by the drop sites above.

## FGX exposure (inventory)

- **One live miscompile**: `dhclient.c u32dec()` — `unsigned long v / 10`
  emits SIGNED `long_divs`; wrong digits for lease ≥ 0x80000000 (RFC 2131
  infinite-lease 0xFFFFFFFF). Display-only. Fixes itself once unsigned-long
  selection lands and dhclient rebuilds.
- **Load-bearing-but-correct** (tracked positions): ping's checksum
  end-around carry (`sum < w`, both simple unsigned locals), dhclient's
  timer-wrap guard, ed's `nlall` cap. Fragile to refactoring into a
  dropped position; fixture coverage added by this batch.
- **Deliberate signed workarounds** that become deletable once unsigned
  long lands: `df.c u16()` widen-with-fixup, `od.c icvt()` signed-emulated
  unsigned long div/mod. LEFT IN PLACE (working code); registry notes them.
- **Zero fixture coverage** existed for any drop site.

## Fix plan (this batch)

- **P1 unsigned long**: add `_fcc_long_{ltu,gtu,leu,geu}` (hi-word unsigned
  compare, tie → lo), `_fcc_long_divu/_fcc_long_modu` (signed cores minus
  sign fixup), `_fcc_long_shru` (logical); selectors gain
  `LT_LONG && g_binop_unsigned` arms.
- **P2 drop sites**: array-elem loads set the flag from the array symbol's
  `is_unsigned`; `->field` callers restore from the Field after
  `emit_deref_ptr_field`; `(unsigned)` cast sets the flag; **fn returns**
  get `ret_unsigned` on Func + FnSig, populated at decl/def parse, read at
  the call-result sites.
- **P3 compound assigns**: `emit_binop_for_compound` takes the LHS
  signedness instead of forcing 0.
- **P4 signed `>>`**: new `_fcc_shrs16` (arithmetic); selector picks
  logical for unsigned, arithmetic for signed. (`long >> ` signed stays
  arithmetic `long_shr`; unsigned long gets `long_shru` per P1.)
- **P5 postfix `++`/`--`** result keeps the operand's flag.
- **DEFERRED, registry-noted**: unsigned literals (hex ≥ 0x8000 as
  unsigned int per C89). Highest behavior-change blast radius on existing
  signed code for the least port value; revisit with the multipass
  front-end.

Fixtures (all red-first): M34 family — u_elem (array-elem compare),
u_ret (fn-return compare), u_arrow (ptr->field compare), u_cast,
u_long (compare + div + mod + shr on 0xFFFFFFFF-class values),
u_comp (compound /=, >>=), sar (signed -16 >> 2 == -4).
Gates: goldens regen (shr16→shrs16 churn expected) AFTER behavior-green,
runtime + calibrate new fixtures, multibank sweep (parse/emit are
MB_FILES). Land: merge to main, NO release (hold).
