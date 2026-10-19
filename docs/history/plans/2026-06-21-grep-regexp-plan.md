# grep + reusable regexp engine — implementation scope (Phase 2)

Date: 2026-06-21.  Status: **DONE 2026-06-21** — 2a (engine+grep), 2b (flags +
-l fix), 2c (engine factored to src/userland/lib/regexp.c).  grep MAME 5/5;
clang-vs-real-grep batteries green; fcc 264/264.  Surfaced+fixed 2 fcc gaps
(paren-subscript c70e94d, array-dim-const-expr b2f3086).  vi seams (same()/struct
regexp/MAGIC) deferred to Phase 4.3.  Supersedes the Phase 2 sketch in
`2026-06-19-userland-roadmap-grep-vi-man.md` with concrete findings.

Prereq DONE: Phase 0 (getchar/getc/freopen) — grep's I/O loop is literally
`freopen(file,"r",stdin)` + `getchar()`, the exact primitives just built.

---

## Architecture: reusable engine + thin front-end

Two authentic 2.11BSD sources, two provenance rows:

1. **Engine** — port `usr/lib/libc/gen/regex.c` (`re_comp`/`re_exec`/`advance`/
   `backref`/`cclass`, ~300 LOC).  The clean reusable API (vi/ex reuse it in
   Phase 4.3).  Crucially it stores char classes as a **length-prefixed linear
   byte list** scanned by `cclass()` — NOT a bitmap — so the Phase 0.3
   bitmap-codegen worry never applies.  `re_comp(s)` → NULL or err-string;
   `re_exec(s)` → 1 match / 0 no / -1 internal-error.  Recursive `advance()`
   is the matcher core; `*` closures and `\(\)*` recurse.

2. **Front-end** — derived from `usr/bin/grep.c` `main`/`execute`/`succeed`
   (4.6 Berkeley).  Take its flag set, `-i` pattern-rewrite, file loop and
   output formats; DISCARD its private `compile`/`execute`/`advance` engine
   (and its `bittab[]` bitmap) — call `re_comp`/`re_exec` instead.  `execute()`
   collapses to: freopen(file) (or stdin) → read a line with getchar() to
   `\n`/EOF → `re_exec(linebuf)` → `succeed()` on (match XOR vflag).

Why regex.c over porting grep.c whole: reusability for vi (the strategic goal),
linear cclass (no bitmap), smaller.  Cost: regex.c lacks `\<`/`\>` word
boundaries (grep.c's CBRC/CLET) — see `-w` decision below.

---

## fcc risk inventory — the structural risks are CLEARED

Probed against fcc 2026-06-21 (all compiled exit 0):

| Construct | regex.c use | fcc status |
|---|---|---|
| `goto` + labels | `goto star` / `goto defchar` shared by 4 switch cases | ✓ emits `BRL <label>` |
| function-like macro | `#define comerr(msg) {expbuf[0]=0;numbra=0;return(msg);}` | ✓ expands args + block body |
| K&R mixed-ptr param | `cclass(set,c,af) register char *set,c;` (set=char*, c=char) | ✓ parses |
| neg pointer index | `ep[-1]`, `ep[-2]`, `*ep = ep[-1]+1` (read-mod-store) | ✓ compiles (`cp[-1]` runtime-proven by strings) |
| assign-in-cond | `if (rv = advance(...))`, `if ((c=*sp++)=='\0')` | ✓ (od/strings) |
| switch on OR'd opcodes | `case CCHR|CSTAR:` (compile-time const) + fall-through | ✓ (od) |

Remaining to validate IN the engine battery (not blockers, just verify on MAME
vs the clang oracle):
- **Recursive `advance()` stack depth** — depth ∝ number of `*`/backtrack
  points ≈ line length.  The FGX1 `stack_pages_hint` (od port) auto-sizes the
  stack; pathological `a*a*a*…` on a long line is the stress case.  Watch for
  stack overflow → bump `fcc_stack_pages` in the link header if needed.
- **char signedness on high bytes** — `cclass`/`advance` compare `char c`;
  high-bit bytes (≥0x80) in pattern or text.  strings hit the same class
  (`c > 0200`); validate ranges + classes with 0x80+ inputs.
- Cosmetic: a bare `#` (cpp null directive) on regex.c line 11 — drop it.

---

## Phasing

### 2a — engine + minimal grep, oracle-gated
- Port regex.c → `src/userland/grep/regexp.c` (or inline in grep.c for 2a;
  factor to a lib in 2c).  Strip the LIBC_SCCS guard / bare `#`.
- Minimal front-end: `grep PATTERN [file...]`, no flags except implicit stdin.
  freopen+getchar line loop; print matching lines; exit 0/1/2.
- Gate: a **clang-built-from-the-ported-source** oracle (the strings lesson —
  same source is the authoritative reference; macOS grep only sanity-checks
  standard BRE).  Battery of (pattern,input): literals, `^ $ . *`,
  `[abc] [^abc] [a-z]`, `\(\)\1` backref, anchored, empty match, the
  pathological `a*a*a*` backtracker, high-byte classes.  Diff stdout+exit on the
  ACTUAL ported source, host vs FGX (CR↔LF normalized).

### 2b — flags
- Easy / front-end only: `-v` (invert), `-n` (line #, %ld), `-c` (count),
  `-l` (list files; uses `fseek(stdin,0,2)` to stop early — FGX fseek works on
  the freopen'd file), `-h` (no filename prefix), `-s` (silent), `-e PATTERN`,
  filename prefix when >1 file.
- `-i` — pattern-rewrite (lowercase letter → `[Xx]` class), faithful to grep.c
  lines 122-144; no engine change.
- `-x` (whole line) — front-end pattern-rewrite `^…$` (cheap), even though this
  grep.c lacks it; the roadmap lists it.
- **`-w` (word match) — DECISION below.**
- `-b` (block #) — DROP (no Unix block concept for FGX files; note it, don't
  fake an offset).

### 2c — factor engine to a shared lib + vi seams
- Move regexp.c into the `src/userland/lib` ↔ `toolchain/lib` dual-copy
  discipline.  Pre-install the vi seams the roadmap names: a `same(a,b)` compare
  hook (vi IGNORECASE), caller-owned `struct regexp { char Expbuf[ESIZE+2];
  char Circf; short Nbra; }` (ex_re.h shape, vi's three REs), separable compile
  front-end (vi's MAGIC/QUOTE layer drops on top).  Re-validate grep vs oracle
  after the refactor.

---

## Open decisions (need the maintainer)

1. **`-w` word match.**  → DECIDED 2026-06-21 (the maintainer): **add `\<`/`\>` (CBRC/CLET
   word-boundary ops) to the engine NOW** — the "implement properly" path that
   also pre-pays the vi `\<`/`\>` feature.  `-w` then wraps the pattern as
   `\<pattern\>`.  (Rejected: deferring `-w`.)
2. **2a packaging** — port the engine inline in grep.c first (simplest, one
   binary) and factor to the dual-copy lib in 2c, OR build the lib up front.
   Recommend inline-first (validate the engine before committing to lib layout).
3. **Oracle** — confirm: clang-built ported source is the authoritative oracle
   (per strings); real `grep` BRE only for standard-pattern sanity.  Edge
   behaviors (high-byte, empty match) follow the ported source, not GNU/BSD grep.

## Effort
2a (engine + minimal grep + battery): ~3-5 days.  2b (flags): ~1-2 days.
2c (lib factor + vi seams): ~1-2 days.  Total ~1-1.5 weeks (engine port is
lower-risk than feared now that goto/macros/K&R-params are confirmed).
