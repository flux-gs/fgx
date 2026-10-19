# BSD library family — P1 (library-level split) plan (2026-07-16)

**Campaign:** `2026-07-16-bsd-foundations-campaign.md`, train 1.
**Design basis:** `2026-07-13-multi-archive-linker-scoping.md` §4(A)/§5-P1.
**Ruling (the maintainer, 2026-07-16):** phased P1→P2, and P1 splits out **all**
non-libc functions — libfgx, termlib, curses, util as needed — following
**2.11BSD's library design** (`examples/2.11BSD/usr/{lib,usr.lib}/`) as the
placement authority for every function.

**Branches:** `feat/bsd-lib-family` (toolchain + FGX parent).

---

## 1. Current state (grounded 2026-07-16)

- `toolchain/lib/libc_c/libc_c.c` (2638 lines) → `fcc --pile` →
  `libc_c.s`, one blob; PUT into every tool's **seg2 KIND=LIBC** segment
  (`tools/fgx2/seg2.link.s.in`) along with `libc.s` (asm) +
  `fcc_libc_shims.s` + a pile-local `fcc_runtime.s` copy.
- seg2 is **byte-identical across all binaries** and share-keyed
  `{size, checksum}` — the kernel loads one copy system-wide (T5-A). Its
  data references resolve into seg1's **template-frozen prefix**
  (`libc_data + args_data + fcc_runtime_data`), which is what makes the
  bytes reproducible. This property must survive the split, per library.
- termcap is split across the pile (`tgetent/tgetflag/tgetnum/tgetstr`)
  and FGX-side `src/userland/lib/termcap.c` (`tgoto/tputs`, per-tool TU).
- curses is FGX-side per-tool TUs (`src/userland/lib/curses/` via
  `tu.list`), compiled into each tool's seg0/seg1 — not a library at all.

## 2. Target state (P1 deliverable)

**Architecture note (the P1 crux, found grounding this plan):** the shared
LIBC segment works *because* it is a closed call graph with **zero reloc
rows** — it is byte-identical across binaries, loaded once, and never
patched (banks are loader-relocated per process, so an outbound cross-seg
FARCALL from a shared segment would need per-process patching, which
sharing forbids; that's why seg2 carries its own `fcc_runtime.s` copy).
Therefore P1 does **not** create one physical segment per library.
Libraries are separate **source piles**, co-assembled (PUT) into the
single KIND=LIBC segment in canonical order, selected per tool — the
merlin co-assembly resolves cross-library calls as near JSRs inside the
closed segment, exactly like `libc.s`+`libc_c.s`+`fcc_runtime.s` today.
Zero new loader/linker machinery. P2's member extraction also feeds this
one segment (archives are a link-time concept; the runtime shape stays a
closed shared segment), so nothing here is throwaway.

- **Toolchain hosts the library family**, one `--pile` C file per library:
  `lib/libc_c/` (BSD-only), `lib/libfgx_c/`, `lib/libtermlib_c/`,
  `lib/libcurses_c/` (sources move from FGX `src/userland/lib/`), each
  compiled to its own checked-in `.s` pile + `_data.s`. New headers:
  `<fgx.h>` (+ curses/termlib headers move with their sources).
- **The build selects libraries by name.** `build_userbin_fgx2_c` gains a
  libs argument (default `"c,fgx"`; curses tools `"c,fgx,termlib,curses"`);
  the generated `seg2.link.s` PUTs the selected piles in canonical order,
  and the seg1 frozen prefix gains the selected libraries' `_data.s`
  blocks in the same canonical order (libc, fgx, termlib, curses —
  omitted libraries omit their block). Tools with the same library set
  share an identical library segment; different sets get different
  `{size, checksum}` share keys, which the loader already handles
  (sharing degrades to per-set, never breaks).
- **Link convention:** libfgx is the *platform library*, always selected
  (libc's `system` near-calls `spawnv`; like libgcc, it's part of the
  platform, not an app choice). True link-order semantics arrive with
  P2 extraction; at P1, "selection + canonical order" is the whole story.

## 3. Function placement (per the 2.11BSD map)

From today's pile inventory (~130 public names):

- **libc keeps** (ISO C / POSIX / 2.11BSD-libc names): mem*/str*/b*
  (bcopy/bzero), abs/atoi/atol/strtol, malloc/calloc/realloc/free, qsort,
  rand/srand/random/srandom, getopt/getenv/getcwd, time family (time,
  gmtime, ctime, asctime, gettimeofday, settimeofday, utimes), all stdio
  (`__lc_*` helpers included), perror/strerror, popen/pclose/system,
  opendir/readdir/closedir, the syscall wrappers with POSIX/BSD names
  (open/close/creat/read/write/lseek/unlink/stat/rename/mkdir/rmdir/
  readlink/access/chdir/dup/dup2/pipe/ioctl/isatty/kill/signal/wait/
  waitpid/exit/getuid/getpgrp/setpgid/nanosleep), sockets (socket/bind/
  listen/accept/connect/send*/recv*/setsockopt), stty/gtty (2.11BSD libc
  compat names), getfsstat (BSD name).
- **libfgx** (new `<fgx.h>`) — 18 confirmed in the pile: waitkey, pollkey,
  yield, ticks, border, setpal, fontload, fontname, fontrevert, slotscan,
  dmesg, meminfo, procs, listdir, spawnv, spawnvp, spawnve, spawnx; plus
  any FGX-only residents of asm `libc.s` (audit during carve; e.g. ifctl).
- **libtermlib**: tgetent, tgetflag, tgetnum, tgetstr (out of the pile) +
  tgoto, tputs (in from `src/userland/lib/termcap.c`). 2.11BSD home:
  `usr.lib/libtermlib`. The asm `tc_*` engines + tables stay libc.s/
  libc_data internals (the C wrappers near-JSR them at co-assembly).
  **UP/BC decision (2026-07-16):** the pile externs `UP`/`BC` always —
  clients own the definitions, exactly like 2.11BSD (libcurses defines
  them; standalone tgoto users add `char *UP, *BC;`; elvis's vendored
  curses.c keeps its UP untouched, its FGX seam supplies BC, and the
  `-DFGX_ELVIS_CURSES`/`FGX_TERMCAP_OWNS_BC` dance retires with the
  textual-include termcap TU). Consequence accepted: a client-data
  reference makes the termlib-bearing segment's bytes per-seg1-layout, so
  cross-tool sharing of that segment degrades to same-layout tools only —
  correct (content-keyed share keys), and P2's member-level dead-strip
  makes lib-segment bytes per-tool anyway. Also keep termcap.c's
  empty-paren forward decls for tgoto/tputs verbatim (the RTL-ABI flip
  that matches elvis's K&R `extern char *tgoto();` call sites).
- **libcurses**: `src/userland/lib/curses/*` relocated to the toolchain as
  a library pile. 2.11BSD home: `usr.lib/libcurses`.
  **Step-4 findings (2026-07-16):** (a) the pile is the textual aggregation
  `libcurses_c/libcurses.c` (`#include`s the 39 members; `-DNOSCCS` since
  every member's `static char sccsid[]` would collide); (b) the merged TU
  exposed and forced two additive fcc fixes — prototype-redecl-after-
  definition (fixture `M37/redeclafter`) and extern-redecl-after-definition
  silently demoting a defined global + wiping its initializer (dropped
  LINES/COLS/_tty_ch from the data seg; fixture `M37/externafter`);
  (c) **curses does NOT fit the shared LIBC segment** — libc+curses
  overflow the 64 KB bank (merlin: object code > 64 KB), so curses ships
  as the ONE aggregated TU in each curses tool's code segment
  (`tools/fgx2/libcurses.tulist` + `-DNOSCCS`, `libs="termlib"`) — exactly
  its pre-P1 per-tool footprint, now built from the relocated toolchain
  source. It joins the shared-segment world when P2 dead-strip shrinks it
  (or if inter-shared-segment reloc machinery ever lands); `make libcurses`
  still builds + stack-checks the pile form for that future.
- **libutil**: nothing qualifies today — created when a port first needs
  it, not speculatively.
- **Known residue (audited 2026-07-16):** asm `libc.s` exports only
  getpid/setjmp/longjmp (BSD — stay) + `today_init` (IIgs RTC ReadTimeHex
  wrapper, cal(1)'s helper) — FGX-specific but hand-asm; one function does
  not justify an asm libfgx pile. Move it when a second asm platform
  resident appears (or when it gets a C conversion). No collision risk
  (no BSD source defines the name).

Rule for future accretion: a function goes where 2.11BSD puts it; a
function 2.11BSD doesn't have goes to libfgx if FGX-specific, else to the
2.11BSD library whose manual section/role it matches.

## 4. Work plan

1. **Carve libfgx** out of `libc_c.c` → `lib/libfgx_c/libfgx.c` +
   `libfgx_data` block; write `<fgx.h>`; Makefile target; seg template +
   manifest + `build_userbin_fgx2_c` libs argument; frozen-prefix update.
   Prove the whole multi-library mechanism end-to-end with one native tool
   (e.g. `color` or `fontname` user) and one pure-BSD port (e.g. `cat`).
2. **Audit asm `libc.s` residents** for FGX-only names; migrate or tag.
3. **Carve libtermlib** (pile tget* + FGX-side tgoto/tputs) → toolchain.
4. **Relocate curses** → toolchain pile; retire the `tu.list` mechanism
   for curses users (curtest, worm, elvis's link model); elvis multibank
   gets per-library KIND=LIBC emit-once segments via `gen_elvis_link.py`.
5. **Repoint callers**: FGX-native tools include `<fgx.h>`; drop the
   FGX-specific prototypes from the BSD headers they currently squat in.
6. **Gates**: toolchain `run.sh` goldens + oracle green; FGX full MAME
   suite green; elvis smoke (multibank curses+termlib user); `fas`
   on-device (seg2 LIBC user) unaffected; multibank sweep green if any
   bank-adjacent linker code moved (`MULTIBANK_VERIFIED=1` if so).
7. **Docs/memory**: update ROADMAP item to P1-DONE, the project notes episode,
   man-page/header hygiene.

**Then P2** (separate plan): `.fgxa` archives + symbol index + extraction
loop + packing-after-extraction + member-level dead-strip; retire A1
app-vs-lib precedence.
**P2 design requirement (the maintainer, 2026-07-16: "each library should be its
own thing"):** give shared segments a legal way to call each other, so
each library becomes its OWN shared segment instead of co-assembling into
one closed 64 KB blob (the constraint that forced curses into per-tool
code segs). Two candidate designs: (a) one-shot inter-shared-segment
resolution — shared segs live at stable physical banks (loaded once), so
cross-refs between resident shared segs are process-invariant and the
loader can resolve them once at first load; (b) GOT/PLT-style indirection
— shared code calls out through per-process DATA-segment cells, keeping
the shared bytes pristine. Dead-strip only mitigates size; (a) or (b) is
the actual fix.

## 5. Risks

- **seg1 frozen-prefix ordering**: any tool whose seg1 prefix deviates
  breaks the byte-identity of the library segment — the canonical order is
  generated from one template, never hand-assembled.
- **fcc `--pile` cross-pile calls**: the carve assumes a pile's call to a
  function defined in a *different* co-assembled pile emits a plain near
  JSR that resolves at co-assembly (as `libc_c.s`→`libc.s` helpers do
  today). Verify with the libfgx pile first (`spawnv`→`strcpy`,
  `spawnvp`→`getenv`); if fcc special-cases known-libc names differently
  in pile mode, fix fcc (toolchain-first), not the library layout.
- **curses relocation churn**: mechanical but wide (elvis manifest is
  hand-written; `tu.list` users retire); elvis smoke test is the backstop.
- **cross-pile data references** (`spawnv`→`_libc_lstrBufA`, `args_env`,
  `sys_envp`): all piles' data lives in seg1 behind `seg1_layout.s`
  labels, same as today — but the carve moves which pile *references*
  which cells; the layout generator must keep exporting them all.
