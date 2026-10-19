# Library function-level GC -- design

- **Status:** designed and accepted 2026-09-25 with the maintainer; implemented
  2026-09-25 on feat/457-libc-gc (plan Tasks 1-6).  apple/fgx#457.
- **Goal:** a tool links only the library FUNCTIONS and DATA ITEMS it can
  reach, not whole library source files.  Every library pile is collected:
  libc, libfgx, libc_net and the optional archives (curses, termlib, resolv).
  Tools' own code is out of scope.
- **Why now:** libc time zones (`2026-09-25-libc-time-zones-design.md`) put
  4.3BSD-Reno's `ctime.c` into libc: about 22 KB of 65816 code under fcc, and
  six tools (su, syslogd, fsck, reboot, slogprobe, tcsh) no longer fit their
  64 KB libc bank.  #457 had already measured 19,097 of su's 55,710 libc bytes
  (34%) as unreachable.  That work is parked on the local branch
  `wip/libc-tz-task3` and resumes on top of this.

## 1. Decisions (the maintainer, 2026-09-25)

- **Function-level GC over BSD's one-function-per-file layout.**  BSD's `ld`
  picks whole `.o` members, and BSD's libc is laid out one function per file
  so that works.  It would not solve the case at hand: Reno's `ctime.c` is
  one file in BSD too (as is modern FreeBSD's `localtime.c`), so BSD links
  all of it for any program that calls `syslog`.  GC is finer than BSD,
  needs no source churn, and leaves ported upstream files as upstream wrote
  them.  Rejected alternatives: one function per file (large churn, blocked
  by shared statics, every future port re-split by hand); splitting hot
  files now and GC later.
- **GC now; true shared libraries later**, in their own design.  A
  Linux-style shared libc is on the table, but libc is about 126 KB of code
  (the union of the 330 libc functions today's tools use), so it would span
  three or more banks and need far calls within libc, a loader mapping and a
  stable jump table.  GC's reference graph is what that design would use to
  cut libc into bank-sized pieces, so it is not thrown away.
- **Scope: every library pile**, not tool code.

## 2. What the link does today

Read 2026-09-25 on `main` at `d5b0cb0d8`.

- **Three segments per FGX2/FGX3 tool** (`tools/fgx2/seg{0,1,2}.link.s.in`,
  materialised per tool):
  - seg0: the tool's code, `crt0_far.s`, `<tool>_stubs.s`, `fcc_runtime.s`;
  - seg1: all data -- `libc_data.s`, `args_data.s`, `fcc_runtime_data.s`,
    `libc.sel.data.s`, the `llong`/`double` selections' data,
    `libfgx_data.s`, `<tool>.data.s`;
  - seg2: library code -- `libc.s`, `fcc_libc_shims.s` (hand asm),
    `libc.sel.s`, `llong.sel.s`, `double.sel.s`, `libfgx.s`,
    `fcc_runtime.s`.
  - Optional archives go in seg3 (`seg3libs.link.s.in`, `tools/ninja/seg3.py`).
- **Selection is per source FILE.**  `fgx_ar select` (`toolchain/src/ld/
  fgx_ar.py`) walks `libc.fgxa/index.json` from the tool's references, then
  compiles a filtered copy of the umbrella `libc_c.c` that `#include`s only the
  chosen member files; fcc emits every function in each of them.  The index
  comes from `toolchain/tools/mk_fgxa_carve.py`.
- **fcc's pile output is already regular.**  A function is an optional
  `FGX2_EXPORT name`, `name ENT`, its body with `name_*` local labels, then
  `name_FRAMESIZE EQU` and `name_STKGUARD EQU`.  Data items are consecutive
  labels in `.data.s` (globals, then the string pool).
- **Sharing:** identical seg2 contents are shared as content-addressed
  `/lib/libc.so.<key>` (`SEG_KIND_LIBCREF`): 63 classes on disk, resident once
  (#376, #390).

## 3. The mechanism

1. **fcc marks sections.**  `fcc --sections` (used when building library piles)
   wraps every function and every data item in `FGX_SECT <label>` ...
   `FGX_ENDS`, two empty Merlin macros defined in `toolchain/lib/macros.s`
   that emit no bytes.  A function's section spans its export line to its
   trailing equates; a data item's spans its label to the next.  Without
   `--sections`, output is unchanged.
2. **References are label occurrences.**  In Merlin source every symbol
   reference is spelled as its label: `PEA target-1`, `JSR`, `JSL`, `DA`,
   `ADRL`, the `FGX2_*` macros' `;`-separated arguments, and `__asm` bodies.
   So the identifier tokens inside a compiler-delimited section are its
   relocation list.  Tokenising the whole line, comments included, can only
   keep MORE -- the safe direction.  Taking a function's address always leaves
   its label in live code or data, which closes #457's "indirect call" gap:
   function-pointer tables are data items, and a live one keeps its targets.
3. **Roots** are every section label named by the tool's fixed text: its own
   segments (tool code, stubs, crt0, runtime, the tool's data) and the
   unmarked hand-written library files (`libc.s`, `fcc_libc_shims.s`,
   `fcc_runtime.s`, `libc_data.s`, `args_data.s`, `fcc_runtime_data.s`, and the
   `llong`/`double` asm selections), each of which is one always-live node.
4. **`fgx_gc`** (`toolchain/src/ld/fgx_gc.py`) runs per tool after selection
   and before assembly.  It reads every file the tool's link files `PUT`, marks
   reachable sections from the roots, and writes pruned copies of the marked
   files beside the tool (`libc.sel.gc.s`, `libfgx.gc.s`, their data halves,
   the seg3 archives').  The link files `PUT` the pruned copies.  `fgx_ar`'s
   member selection stays as the coarse first pass.
5. **Failure is loud.**  A dropped section still referenced by label is an
   undefined symbol at merlin32; `fgx_gc` checks the same thing itself and
   names the missing label before merlin32 runs.  `FGX_NO_GC=1` links the
   unpruned files, so a behaviour difference bisects to GC in one build.

## 4. Data, sharing, the checkers

- **Data is collected with code.**  Dead globals, statics and string-pool
  entries leave the data bank; tcsh's is nearly full.
- **Sharing is measured, not assumed.**  Finer pruning makes more distinct
  seg2 images, so more `/lib/libc.so.<key>` classes.  The campaign reports the
  class count and libc bytes on disk before and after.  Rounding selections up
  to share a class is a later knob if disk grows materially.
- **Every checker that reads a library `.s` reads the pruned copy**
  (`stack_measure`, `check_stack_budget`, `check_libc_piles`, the stack
  baseline): what is linked is what is checked.

## 5. Measurement

Before and after, for every tool: seg2 code bytes and banks
(`tools/bank_pressure.py`), data-bank statics (`tools/check_data_budget.py`),
and the pile class count.  su's seg2 is the headline against #457's 19,097.

## 6. Testing

- **Build level:** every tool assembles.  That is the main net, because a
  wrong prune is an undefined label.
- **`fgx_gc --self-test`:** a synthetic pile with a function reached only
  through a function-pointer table, a static shared by two functions, a string
  literal reached only through a live function, and one truly dead function.
  The first three must be kept and the last dropped; a mutated collector that
  ignores data references must fail it.
- **Runtime:** the gate (boot/heap/fork/shell, the fixture oracle) and the
  MAME suite run on collected binaries.
- **`gcprobe`**, one MAME test: a program that reaches libc only through
  `qsort`'s comparator, a `signal` handler and `atexit`, so the indirect paths
  run on the machine.

## 7. Out of scope

- Tools' own code; the fcc fixture suite, which keeps linking the whole libc
  pile so its goldens do not churn.
- Not out of scope, but LAST: tcsh, elvis and bsh generate their own link
  files, so they are a task of their own once the template path is proven.
  tcsh is one of the six tools time zones broke, so the campaign is not done
  without it.
- Shared libraries (a later design).
