# yacc -- host parser generator for FGX

`yacc(1)` runs **on the host** (build time), not on the GS. It converts a `.y`
grammar into a C parser that is then compiled for FGX by `fcc` -- the same
cross-compilation model `fcc` itself uses. yacc never ships to the IIgs.

## Pieces

- **`yaccpar`** -- the parser skeleton (committed here). Copied **verbatim** from
  2.11BSD `usr/usr.bin/yacc/yaccpar` (Johnson/Berkeley yacc, BSD-3).
  It is embedded into every generated parser. No fcc-specific edits are needed:
  the Phase-0 probe sweep proved fcc handles every idiom it uses (signed `short`
  tables, `&yys[-1]` stack trick, switch fall-through, goto-into-case, K&R
  implicit-int), and the one gap found -- prefix `++/--` on a global scalar
  (`--yyerrflag;`, `++yynerrs;`) -- was fixed in fcc (`parse_stmt.c`).
- **`src/`** -- the yacc compiler sources `y{1..4}.c` + `dextern`, **verbatim
  2.11BSD** (Regents copyright), byte-identical to the committed
  `vendor/2.11BSD/usr/usr.bin/yacc/` copies; the build reads this copy. See
  `docs/PROVENANCE.md`.
- **`yacc`** -- the host binary (gitignored), built by `tools/ninja/yacc.sh host`
  (ninja rule `hostyacc`) from `src/` with `cc -std=gnu89 -w` plus K&R
  downgrade flags (zero source edits). Its compiled-in `PARSER` path points at
  `yaccpar` above (baked per-checkout).

## Build flow (`tools/ninja/yacc.sh gen <name>`, then the ninja tool build)

```
src/userland/<name>/<name>.y
   -> yacc            -> y.tab.c               (host)
   -> strip '#line' + bare '#' directives     (fcc has no #line; sed pass)
   -> <name>.c        -> the ordinary FGX2 tool build (fcc, link)
```

A tool is yacc-sourced when its `tools/ninja/manifest.json` entry has
`"yacc": true`; `tools/ninja/gen.py` then emits a `yaccgen` edge for the
`.c`. The intermediates (`y.tab.c`, `y.output`, `<name>.c`) are generated and
gitignored; only `<name>.y` is committed.

## Host yacc source quirks

The 2.11BSD yacc is K&R C; modern clang promotes several K&R patterns to hard
errors. `tools/ninja/yacc.sh host` demotes them with these flags (each probed
first, since gcc rejects the names), and needs **no source edits**:

```
-Wno-error=return-mismatch -Wno-error=int-conversion
-Wno-error=implicit-function-declaration -Wno-error=implicit-int
```

The host's own `/usr/bin/yacc` is bison, whose generated skeleton is fcc-hostile;
that is why we build the simpler 2.11BSD yacc locally and use its `yaccpar`.

## Status

`expr(1)` (`src/userland/expr/expr.y`) is the yacc-built tool in the tree.
Running yacc *on the GS* (self-hosting) is not done.
