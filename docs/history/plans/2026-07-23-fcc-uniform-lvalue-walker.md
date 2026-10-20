# fcc uniform lvalue-address walker (K&R-canonical) — design + plan

**Decision (the maintainer 2026-07-23):** build the uniform lvalue-address computation
instead of continuing per-shape whack-a-mole. K&R Appendix A (§A.7.3 postfix,
§A.7.4 unary, §A.7.17 assignment) shows `.`/`->`/`[]`/`++` are ONE recursive
postfix production and assignment/`&`/`++` take ANY modifiable lvalue — so the
~11 lvalue-cluster FAIL TUs are ONE structural gap, not 11 bugs.

## Core model — `emit_lvalue_addr(chain)` -> (fpr kd, pending byte offset)

Invariant: the lvalue's address == `kd + off`.  Track `cur_type`/`cur_sid` (the
type of the sub-object at kd+off).  Steps:
- **base** named struct/array var `v`  -> kd = fpr_addr_sym(v); off=0
  named pointer var `p` (base for ->/[]/*) -> kd = fpr_load_sym(p); off=0
  computed `(expr)` -> kd = walk_fpr(expr); off=0
- **`.field`** (cur is struct): off += field.offset; cur = field.type
- **`->field`** (cur is struct-PTR): emit_fpr_deref_field(kd, LT_STRUCT_PTR, off)
  [kd = *(kd+off) = pointee addr]; off = field.offset; cur = field.type
- **`[i]`**: ptr cur -> deref (emit_fpr_deref_field(kd,cur,off)); walk idx->A;
  scale by elem_size (ASL/…); emit_fpr_add_a(kd); off=0; cur=DECREF.
  array cur -> flush off (emit_fpr_add_const); scale+add idx; off=0; cur=DECREF.
- **`*`** (unary deref): emit_fpr_deref_field(kd,cur,off); off=0; cur=DECREF.

Final: address = kd + off.  Leave `off` for the store primitive's offset arg
(emit_fpr_deref_store_{word,byte,long,ptr}(kd, off)) or flush it for `&`.

**Bank correctness for free:** emit_fpr_* only touch the offset word; the fpr
carries the bank byte through every deref/add.  So `&p[i]` on a ptr-to-ptr keeps
the bank -> the "hard multibank" gap (group 4) dissolves here too.

## Uses (all just "compute addr, then …")
- `lvalue = rhs` : addr; store by leaf type (word/byte/long/ptr).
- `lvalue op= rhs` / `++`/`--` : addr; deref-load leaf; combine; store.
- `&lvalue` : addr (flush off) -> pointer value (bank included).
- read `lvalue` : addr; deref-load leaf.

## Safety / rollout
NEW path is a FALLBACK: only shapes the existing special-cased emitters DON'T
match route here, so existing goldens stay byte-identical (no mass REGEN).  Each
increment: fixture + host-C-reference (42) + FGX-runtime + full golden gate +
commit.  Increments:
1. Chain representation (step linked-list in AST pool) + emit_lvalue_addr +
   wire into statement `chain [op]= rhs` / `chain ++/--` fallback.
   Target: sh.sem (`t->L.T_dcar->t_dflg |=`), tc.who (`->…->arr[i]=`), alloc11
   (`(q+n)->ptr=` computed base).
2. Expression-context stores/reads/postfix via the same walker (sh.parse,
   sh.func, sh.set, sh.lex, sh.misc, sh.exp, ed.inputl).
3. `&lvalue` via the walker -> sh.glob, tc.func (&p[i] multibank).

Leaves separate: M22 struct-init (emit 1-slot/field model, §A.8.7) and the
grouping declarator (§A.8.6, declarator-refactor Inc 5).
