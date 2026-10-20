# fcc vs. K&R C: the authoritative grammar, and the root of the whack-a-mole

> **Path note.** These `usr/lib/**` grammar sources live ONLY in the
> **gitignored, local-only** `examples/2.11BSD/` tree — `usr/lib` is NOT in
> `vendor/`, which carries just the userland port dirs
> (`usr/{bin,usr.bin,ucb,sbin,old}`). A fresh clone will not have these files.

**Why this doc exists.** fcc keeps hitting one-off K&R declaration gaps — K&R
fn-ptr parameters, `char **` returns, far fn-ptr-in-data-initializers, K&R
literal-substitution, and now a function-definition *return-type whitelist*
that rejects `union`/`enum`/typedef returns. Each has been fixed as a special
case. They are not independent bugs: they are all the same missing abstraction.
This doc pins the authoritative K&R grammar and the fundamental correction.

## Authoritative references

1. **The executable grammar (primary, local, vendored):**
   `examples/2.11BSD/usr/lib/mip/cgram.y` — the PCC (Portable C Compiler)
   machine-independent yacc grammar. This is how the era's real C compiler
   *actually parsed* K&R C. It matches our port source (2.11BSD) exactly. The
   preprocessor grammar is `examples/2.11BSD/usr/lib/cpp/cpy.y`.
2. **The prose spec (companion):** Dennis Ritchie, *C Reference Manual*
   (Bell Labs) — §8 Declarations, §10 Function definitions; reprinted as
   Appendix A of K&R 1st ed. (1978). Online:
   `https://www.nokia.com/bell-labs/about/dennis-m-ritchie/cman.pdf`
   (and studylib/academia mirrors).

## The model, in three rules (from cgram.y)

K&R parses **every** declaration as *specifier ⊗ declarator*, with no
per-case whitelist:

**(a) Specifiers are one nonterminal, `type`, and it is open** (cgram.y:152):
```
type:  TYPE                     /* any built-in / typedef keyword         */
    |  TYPE TYPE | TYPE TYPE TYPE   /* long int, unsigned long, ...        */
    |  struct_dcl               /* struct/union                            */
    |  enum_dcl                 /* enum                                    */
```
There is no notion of "types allowed as a function return." Any `type` is a
legal base.

**(b) The declarator is recursive** — it builds the derivation, not the type
(cgram.y:253):
```
nfdeclarator:  MUL nfdeclarator          -> pointer   (bdty UNARY MUL)
            |  nfdeclarator LP RP         -> function  (bdty UNARY CALL)
            |  nfdeclarator LB RB
            |  nfdeclarator LB con_e RB   -> array     (bdty LB)
            |  NAME                       -> the name
            |  LP nfdeclarator RP         -> grouping
```
So `char **f()` = `*`,`*`,`f`,`()` over base `char`; `sigret_t (*p)()` =
grouped `*p` then `()` over base `sigret_t`; `union wait w()` = `w`,`()` over
base `union`. One grammar, all cases.

**(c) Merge applies the derivation to the base type — for a function
definition too** (cgram.y:76):
```
data_def:  oattributes fdeclarator { defid( tymerge($1,$2), ...) } function_body
```
`tymerge(base_type, declarator)` is the single operation that turns
"base + derivation" into the final type. A function definition is *literally*
`type ⊗ declarator ⊗ body` — the return type is whatever `type` yielded, with
**zero** restriction.

## Why fcc keeps whack-a-moling

fcc does not have (a)+(b)+(c). It hand-recognizes declarator shapes in
`parse_func_decl_with_spec` / the K&R param loop, and gates the base type
against a hardcoded allow-list, e.g.:
```
if (ret_t.base != LT_VOID && != LT_INT && != LT_CHAR &&
    != LT_LONG && != LT_FLOAT && != LT_STRUCT)  die("bad return type");
```
Every gap we've fixed is a shape or base that fell outside a hand-list:

| fcc gap (all "fixed" as special cases) | Really a missing… |
|---|---|
| K&R fn-ptr parameter decl | declarator recursion in the param loop |
| `char **` (multi-level ptr) return | declarator `*` depth on the return |
| far fn-ptr in data initializer | declarator applied in initializer context |
| function-def return-type whitelist | *specifier openness* — any base is legal |
| (analogous casts / abstract declarators) | declarator recursion in `cast_type` |

## The fundamental correction

Give fcc the pcc model, one time, and the class closes:

1. **`parse_decl_specifiers()`** — consume a run of storage-class + type
   keywords + `struct`/`union`/`enum`/typedef into a single base `TypeSpec`.
   No context cares which base it is.
2. **`parse_declarator(base)`** — recursive: `*` (pointer), `( declarator )`
   (grouping), trailing `( params )` (function), `[ n ]` (array). Returns the
   derived type + the declared name. This is the `nfdeclarator`/`fdeclarator`
   recursion, and the *abstract* form (no name) covers casts and params.
3. **Merge** base ⊗ derivation (the `tymerge` step) — uniformly, in every
   context: file-scope decl, function definition, parameter, struct member,
   cast, `sizeof`. Delete the return-type whitelist; the declarator already
   says "function", the base says "of what".

This is a real refactor of fcc's front end, but it is the *last* one of this
kind: it subsumes the fixed special cases (keep their regression fixtures as
proof) and every not-yet-hit K&R declaration shape. cgram.y (933 lines) is the
spec to conform to; it is small enough to port rule-by-rule.

## Scope note

Not every fcc/BSD gap is a declaration-grammar gap. The K&R
*preprocessor* substitution-inside-literals gap (`CTRL(])` → `']'&037`) lives
in `cpy.y`/`lex_pp.c`, not cgram.y, and was fixed separately. Header
provision (BSD-shaped system headers) is libc plumbing, not grammar. This doc
is specifically about the *declaration/declarator* class, which is the bulk of
the recurring whack-a-mole.
