# Shared libc, sub-project 2: building libc.so -- design

Status: approved in conversation 2026-09-28, section by section; revised the
same day for an adversarial review (Fable), all nine findings adopted.  Parent:
[`2026-09-28-shared-libc-design.md`](2026-09-28-shared-libc-design.md) (the
umbrella), whose section 6 item 2 this is.  Branch `feat/shared-libc`.

## 1. Goal and how it is proven

Build `libc.so.1.0`: 2.11BSD's libc, compiled once in an fcc library mode,
laid out by fgx_ld across several 64 KB banks with an export table, and able
to run.

**Proof (the maintainer, 2026-09-28: route A).** There is ONE compiled form of libc.
Static programs link that same library-mode output into their own banks, and
their startup runs the same per-process data setup the binder will run in
sub-project 4.  So this sub-project is proven on the machine by a statically
linked probe, not only on the host.  Rejected: host-only checks until
sub-project 4 (two sub-projects of unexecuted compiler changes); merging
sub-projects 2-4 into one slice.

## 2. Already done: the library boundary

Landed first, under today's piles (gate green, 635 s):

- `9bb5c1f4e` login(3), logout(3), logwtmp(3) move to a new libutil
  (`toolchain/lib/libutil_c`, `util.fgxa`), as 2.11BSD
  `usr.lib/libutil/Makefile` has them.  ttyslot(3) stays in libc
  (`lib/libc/gen/ttyslot.c`).  dkcksum(3) is not ported (no disklabels).
- `c3abf805f` the resolver is libc member `libc_c/netdb.c` again (2.11BSD
  `lib/libc/net`); the `libc_net` pile and `resolv.fgxa` are gone.  syslogd,
  ntp and ntpd put `netdb` in their libc overlay to stay within one pile
  bank.
- `llong` needs no change under today's piles (every pile already selects
  it); in this sub-project its members are simply libc members.
- `toolchain/tests/ld/test_lib_boundary.py` holds the line.

**libfgx is not libc** (the maintainer, 2026-09-28).  It becomes an ordinary
per-program library, like termlib, linked into the calling program's own
code.  libc makes no call into libfgx.  apple/fgx#501 lists the twelve
BSD-named tools that call libfgx where upstream uses a BSD mechanism.

## 3. The file and the build

**Inputs**, which are libc and nothing else: the C members (compiled once in
fcc library mode), `libc.s`, `fcc_libc_shims.s`, the core data (section 5),
the `llong` members, `d_stub.s` (the glue printf and atof use to reach the
fpsim module; no floating-point code), and the fcc runtime helpers section 6
selects.  Out: libfgx, libutil, curses, termlib, the soft double.

**Output: `libc.so.1.0` in the FGX3 container** -- FGX2's layout, the `FGX3`
magic and the mandatory ABI stamp at header byte 13, as every FGX3 binary
(176 of 180 on the disk; only sh, tcsh and vi are still FGX2, fixed in
sub-project 5).  The stamp is the kernel syscall ABI libc was built against;
libc's own `MAJOR.MINOR` is in the export-table trailer.

- Segments: N code banks (functions, and the read-only literals they use),
  and one core-template segment assembled at the address the core occupies
  in every process.
- Relocs: the existing 4-byte `<src seg, offset, tgt seg>` record, patching
  each internal `JSL`'s bank byte, and each pointer to a literal or function
  in the core template and block templates, once at load.
- Trailer, flagged in the header: the export table (name, code/data,
  segment, offset; index = ordinal), its checksum (for prebinding in
  sub-project 3), the member-block table (per stateful member: block size,
  location of its initial bytes), and the per-process fixup list (section 4).

**Bank packing.**  fgx_ld places function sections and keeps each literal in
the bank of the functions that use it, so a function pushes a literal's bank
with `PHK` (one byte, no reloc) where today it pushes the data bank with
`PHB`.  A literal used from two banks is placed in both; the copy in the
first bank in packing order is the canonical one, and data-template pointers
(`FGX2_LONG_PTR _Sg`, e.g. `tzname[] = {WILDABBR, WILDABBR}` in `ctime.c`)
point at it.  Nothing in libc compares literal addresses, and K&R A.2.6
leaves the distinctness of identical literals implementation-defined.

What this takes, all delivered in steps 2 and 3 (none of it exists today):
fcc emits the string pool into the code output as `FGX_SECT` sections (today
it goes to the data file, `emit.c:5578-5584`, which fgx_gc does not place);
the three `PHB` literal sites (`emit.c:1412-1425`, `3838-3845`, `6152`) emit
`PHK` in library mode; fgx_ld builds the literal-to-function map from the
`LDA #<tu>_S<n>` operands.

**Static programs.**  The same library-mode `.s`, collected by fgx_gc to what
the program reaches, assembled into the program's own code segments
(`toolchain/src/ld/fgx_static.py`).  The core stays in the data segment,
where the loader places it (at offset 0 of the bank -- a core at the top
would put ~60 KB of zeros in every static file); the blocks go at the top,
below `HEAP_LIM`, which is what the heap's ceiling and fork's
`[HEAP_LIM, $FFFF]` range need.  A static
program has no `LIBC` segment kind, so under `fgx_ld.py:686-688`'s ninth-
segment rule it is capped at eight segments including data; a static
program whose libc slice spans two banks is tested (section 8).

**Startup: `_libc_init`, and its order.**  crt0 fills core cells before
`main` -- argv, `environ`, `args_optind` (`_crt0_setup_argv`,
`crt0_far.s:165, 204-359`), the signal-trampoline offset and `_fcc_dbr`
(`:156-161, 175-176`) -- so nothing may overwrite the core after crt0 starts.

- Static program: the loader has already placed the core image (it is part
  of the program's data segment), so there is no template copy.  The
  program enters at `_crt0_libso` (`toolchain/lib/crt0_libso.s`), named by
  the manifest's entry offset, which calls `_libc_init`
  (`lib/libc_c/libc_init.c`) and jumps to crt0's usual start -- crt0 cannot
  test a flag only these links define (Merlin32's `DO` on an undefined
  symbol is an error), so crt0 and every other binary stay as they are.
  `_libc_init` walks the link's `_libc_blktab` (per reached member: cell,
  far pointer to the template, size), carves each block below `HEAP_LIM`,
  copies the template in (its zeros are K&R A.8.7's), points the cell at it
  and lowers `HEAP_LIM`.  The linker writes the table; a static program has
  no per-process fixups (its data segment is its own, so the loader
  relocates `stdin`/`stdout`/`stderr`).  Then crt0's argument and signal
  setup run as today.
- Dynamic program (sub-project 4): the binder copies the core template
  before it enters crt0, then crt0 calls the same `_libc_init`.

If the blocks do not fit above the program's break, `_libc_init` writes a
message to fd 2 and exits 1 -- at startup, never later.

## 4. libc's data in library mode

Three tiers.

**Core: the data programs can name, and libc's hot state.**  Rule: *core is
every data export, plus the state named in `toolchain/lib/libc_c/core.list`;
nothing else.*  fgx_ld's library link enforces both halves: a data export
missing from core is refused, and so is a `core.list` name no member
defines.

- Exports: the `extern` data in the public headers -- `errno`, `environ`,
  `stdin`/`stdout`/`stderr`, `optarg`/`optind`/`opterr`/`optopt`/`optreset`,
  `_ctype_`, `sys_siglist`, `tzname`, `h_errno`.
- `core.list`, starting set: the buffered-stdio state (`stdio_core.c:92-108`
  `_lc_buf`, `_lc_bpos`, `_lc_blen`, `_lc_bfail`, `_lc_bfd`, `_lc_btty`,
  `_lc_small`; `:242-248` `_lc_wfd`, `_lc_wbuf`, `_lc_wcnt`, `_lc_wline`,
  `_lc_wready`, `_lc_wnomem`) and the printf engine (`printf.c:26-41`
  `__lc_pf_*`).  `__lc_getcb`'s fast path touches about ten of these per
  byte and `__lc_pfc` about four per character, so as blocks they would cost
  ~250 cycles per `getc` byte.  Every program that uses stdio carries this
  state today, so making it core costs no program anything new.
- The hand-written cells section 5 assigns to core (~1.25 KB): the kernel's
  path/time staging buffers, the FILE table, argument and environment state,
  signal and vfork state, fcc runtime scratch.

Core is fixed in size per libc build, sits at the top of the data bank below
`HEAP_LIM`'s cell, and is addressed 16-bit absolute through the data bank
register as today.

This corrects the umbrella spec, section 5.1, which listed "the ctype table,
signal names" as read-only: `<ctype.h>`'s macros index `_ctype_` from program
code and `<signal.h>` exports `sys_siglist[]`, so both are core.  Only the
strings `sys_siglist` points at are read-only.  (2.11BSD's libc has no
`sys_errlist`: `strerror` asks `syserrlst()`, section 5.)

**Per-member blocks: every other static.**  Each file-scope and
function-local static belongs to the member (source file) that defines it.

- fcc does not know that today: its preprocessor swallows the line markers
  (`lex_pp.c:493`) and `Global` (`fcc.h:309-345`) has no source-file field.
  Step 2 adds both.  No header or umbrella-prologue line defines storage
  (`libc_c.c:88-102` is declarations only), so every static has exactly one
  owning member.
- `_libc_blk` in the core is a table of **2-byte** block addresses, one per
  stateful member: blocks are always in the data bank, so a bank byte would
  only double the table and the bytes fork copies.
- In library mode fcc rewrites each block static in the AST into a
  dereference of `_libc_blk[slot] + off` -- a near pointer read with
  `LDA (dp),Y`, about 16 cycles against 5 for an absolute access.  The rewrite
  feeds fcc's pointer-dereference shapes, which are narrower than its direct-
  global shapes (91 `gname()` emission sites across `emit.c` and
  `parse_stmt.c`), so step 2 budgets emitter work for whatever shapes it
  exposes.  Done means: all 103 members compile in library mode, and every
  function with no block static assembles byte-identical to today.
- `sizeof` of a block array stays the array's size -- K&R A.7.4.8: "when
  applied to an array, the result is the total number of bytes in the
  array" -- because `sizeof` resolves through the `Global` entry, which the
  rewrite keeps.
- The slot is emitted as one symbolic label per member (`_libc_blk_<member>`),
  not a number, so fgx_ar's operand scan still sees a member that reads
  another member's statics (`fltpr.c` reads printf's `__lc_pf_gbuf`) and
  keeps the owner in its closure.
- fgx_gc drops unreferenced statics (`static char sccsid[]`) before blocks
  are laid out, so no program pays for them.

This refines the umbrella spec, section 5.2, which proposed
`LDX slot / LDA off,X`: fcc holds an array index in X
(`toolchain/src/cc/emit.c:3902`), so an `off,X` access collides with every
indexed static.

**Read-only: string literals**, in libc's code banks, pushed with `PHK`
(section 3).  K&R A.2.6: a string literal "has type array of characters and
storage class static ... the behavior of a program that attempts to alter a
string literal is undefined."  A character array initialised from a literal
(`char a[] = "..."`) is a writable static, not a literal, and stays in its
block.  K&R A.8.7: "A static object not explicitly initialized is initialized
as if it (or its members) were assigned the constant 0" -- `_libc_init`
zeroes every block before copying its initial bytes.  `const` stays parsed
and ignored; nothing in 2.11BSD's libc depends on it.

**Pointer initialisers**, measured in today's libc:
- ~70 pointers to literals (`sys_siglist`, `tzname`, ...) and 4 function
  pointers: relocated once when libc.so loads (their targets are in libc's
  banks).
- 3 pointers to per-process data (`stdin`/`stdout`/`stderr` into the FILE
  table): the bank differs per process, so `_libc_init` writes them from the
  fixup list.
- A pointer from one block into another: refused by the library link (none
  exist today).

## 5. libc's hand-written parts

Rule: assembly only where 2.11BSD itself uses assembly; everything else from
BSD's C.  The three hand-written data files (`libc_data.s` 211 labels,
`args_data.s` 10, `fcc_runtime_data.s` 69; ~3.5 KB in every program today)
shrink to the true core.

**Code:**

| Today | 2.11BSD | Change |
|---|---|---|
| `vfork` (`libc.s`) | asm, `lib/libc/pdp/sys/vfork.s` | keep (frameless by necessity, as upstream) |
| `setjmp`/`longjmp` | asm, `lib/libc/pdp/gen/setjmp.s` | keep |
| `getpid` | asm syscall stub (`lib/libc/pdp/sys/Makefile`) | keep |
| `_libc_strerr` + table + strings | C, `lib/libc/string/strerror.c`, which calls `syserrlst()` (`gen/syserrlst.c`) | port `strerror.c` verbatim; `syserrlst()` returns from a message table in libc.so's read-only banks |
| `today_init` | none | delete, with `cal` ported (below) |
| `_libc_alloc_FILE`, `_libc_FILE_to_fd` | -- | delete (no callers) |

**`cal`.**  FGX's `src/userland/cal/cal.c` is an ANSI rewrite that defaults
to the current month; 2.11BSD `usr.bin/cal.c` prints
`usage: cal [month] year` with no arguments and never reads the clock.  Port
the real one (`vendor/2.11BSD/usr/usr.bin/cal.c`) as it is -- K&R
declarations, `char dayw[] = { "..." };` -- fixing fcc if it rejects any of
it (toolchain-first), and retire the rewrite and its stale `cal.s`.

**Data, by where each label goes** (sizes from a built layout; the
label-by-label list is step 1's first deliverable):

| Group | Bytes | Goes to |
|---|---|---|
| `_libc_lstrBufA/B` -- path and time staging the kernel names (`syscall.s:4806-4807`) | 256 | core |
| FILE table, `stdin`/`stdout`/`stderr`, `errno` | 46 | core |
| `args_data.s`: argc/argv/env/envv, `environ`, `optind`/`optarg`/`optopt`, `__progname` | 468 | core |
| signal state `_sig_c_tab`, `_sig_curmask`, `_sig_tramp_off`, `_sig_act_maskoff` (crt0 trampoline, libc.s, the kernel's `process.s`) | 136 | core |
| vfork and setjmp cells `_vfork_*`, `_setjmp*` (libc.s) | 148 | core |
| fcc runtime scratch (`fcc_runtime_data.s`), `__sys_c/y`, `__asm_p*/w*` | ~150 | core (shared by every code bank's helpers and by compiled code) |
| `_sock_argblk`, `_sel_argblk`, `_sysctl_argblk` | 66 | the owning members' blocks |
| baked termcap entries `tc_*`, `_tc*Tbl` | ~330 | termlib |
| `sys_envp` | 68 | libfgx (its only user) |
| strerror table and messages `_libc_strerr_tab`, `_se_*` | ~1,400 | libc.so read-only, behind `syserrlst()` |
| `today_*` | 12 | delete |
| hand-asm printf, atoi/atol/itoa, fopen/freopen/fio/fseek cells, `sys_pathSh/argv/status`, `libc_args_hi`, `_libc_perror_*`, `_libc_ticks_buf`, `pf_fdBuf` (comments only) | ~700 | delete (no code references) |
| `libc_args`, `libc_args_bank` | 30 | only old hand-asm tools (`tput.s`, `man.s`, `cat.s`, `cmp.s`); delete with them if unbuilt, else core |

Core is then ~1.25 KB of hand-written cells, plus the stdio/printf state
from `core.list`, plus the block table.

Divergence, stated: 2.11BSD's `gen/syserrlst.c` reads error messages from a
file (`/etc/syserrlst`) to save PDP-11 memory.  FGX's `syserrlst()` keeps the
same interface and returns from a table in libc.so's read-only banks, where
the messages cost no per-process memory.

`libc.s`'s header comment describes routines retired long ago; it is
rewritten to describe what remains.

## 6. Calls and the fcc runtime

**Calls inside libc.**  Library mode emits every call as `FGX2_FARCALL` (a
`JSL`, bank byte relocated at load), building on the existing
`--pile-far-extern` path (`main.c:535-537`).  fcc's inline pile call
(`PHK/PEA/PHK/PEA/RTL`, 23 cycles against `JSL`'s 8; 787 sites in libc)
leaves libc.  The `PILE_CALL` macro stays for fpsim, a module with its own
fixed vector (22 hand-written sites).  DBR stays the caller's data bank, as
today.

**Hand-written asm and llong** go in as they are: `libc.s`'s exports return
with `RTL` and reach the kernel through `SYS_TRAMP`; `llong`'s members are
already `RTL`-returning.

**fcc runtime helpers.**  Inside libc.so, each code bank carries the helpers
its own functions use.  libc.so's link splits `fcc_runtime.s` in memory --
the file also feeds the kernel's `fcc_rt.s` and every link template, so it
carries no section markers -- into 67 units at its `_fcc_` labels, a unit
that falls through absorbing the next, and charges each bank, like a string
literal, for every unit its functions reach, through other helpers too.
For programs, libc.so also exports the big, cold helpers through a far entry
(`JSL` to a stub that `JSR`s the helper and `RTL`s: 26 cycles against a near
call's 12, so ~14 more), so programs stop carrying them.  The helpers read
no caller-pushed stack arguments, so the extra return address is harmless;
but the 16-bit helpers take their right operand in the data cell
`_fcc_tmp_b`, which a far entry would read from libc.so's core, so they
stay near until sub-project 3 resolves a program's runtime cells to that
core.  Which helpers: `tools/helper_census.py` measures each helper's size,
its callers and the bytes the banks that carry the whole runtime today
(about 410: every program code segment and every shipped pile) spend on it, against the recorded PC-sample shares of the 2026-09-27 and
2026-09-10 profiles (no tool yet attributes samples across a program's
banks), and exports far a helper of at least 48 bytes with no recorded
share of 0.1% or more, not reached by one that has, exchanging nothing
through a data cell -- neither one compiled code names nor one a NEAR
helper that calls it shares (`_fcc_long_modu` JSRs `_fcc_long_divu` and
reads the remainder divu leaves in `_fcc_long_div_rem_*`, so divu stays
near; `_fcc_long_mods` is far itself, so `_fcc_long_divs` may be): ten,
2,074 bytes -- fsub, fdiv, fmul, long_divs, ftol, ftoi, ffloor, fcmp,
itof, long_mods (`lib/libc_so_helpers.s`).  Long multiply stays near: it is 1.92% of a
measured run.  The program-side switch is sub-project 3's link mode; this
sub-project delivers the exports and the measured list.

## 7. Order of work

Each step lands on its own, gate green where it touches shipped binaries.

1. **libc's hand-written parts** (section 5), under today's piles: the
   label-by-label list; dead code and data deleted; `strerror` from 2.11BSD
   C with `syserrlst()`; termcap tables to termlib; `sys_envp` to libfgx;
   the real 2.11BSD `cal`.  Useful at once: every program's fixed data
   prefix shrinks by roughly 2 KB.
2. **fcc library mode**: per-member attribution in lex/symtab; calls as
   `JSL`; the literal pool as code sections with `PHK`; the block rewrite
   with symbolic slots and whatever deref shapes it exposes; the core list.
   Host fixtures.
3. **fgx_ld library output**: bank packing with the literal map and
   canonical copies, export table and checksum, member-block table, fixups,
   `core.list` enforcement; `tools/libc_so_check.py`.
4. **`_libc_init`, the static link path, and the `libcso` probe** in MAME.
5. **Runtime-helper measurement** and the exports it chooses.

## 8. Testing and measurement

FGX rules: small tests aimed at what changed, a positive control for every
check, nothing added to the gate without something coming out.

Host (`make test-archives`):
- `tools/libc_so_check.py` on the built libc.so: every export resolves; the
  boundary holds; no pile call remains; every internal `JSL` has a reloc;
  every data export is core and every `core.list` name exists; no
  block-to-block pointer; every member whose code names slot S has S's owner
  in its closure.  Reports core and block sizes.  Control: a libc.so with one
  reloc removed must fail.
- fcc library-mode fixtures.  Single shapes: scalar, array element, struct
  field (read and store, as `pwent.c:94`), `&static`, `++`, compound
  assignment, zero-initialised array, `sizeof` of a block array, a
  function-local static (`strtok.c:25`).  Mixed shapes, where scratch reuse
  bites: `blk[i] = blk2[j]`, `blk[i] += f()`, `p[blk_idx]`.  Plus a
  cross-member static (fltpr reading printf's), `char a[] = "..."` staying
  writable, a literal pushed with `PHK`, and a pointer-to-literal inside a
  block's initial bytes.  Control: with the rewrite disabled the fixtures
  must go red.
- All 103 members compile in library mode, and every function without a
  block static is byte-identical to today's output.

Machine (probe `libcso`, not in the gate), a statically linked program built
through the new path:
- core: `errno`, `stdout`, `printf`;
- a stateful member across calls: `strtok`, `ctime`;
- a literal: `strerror`;
- a non-zero initialised static and a zero-initialised one;
- fork isolation of a block static: the child changes it, the parent's copy
  does not move (blocks are above `HEAP_LIM`, sub-project 1's fork range);
- a vfork child that touches a block static before `_exit`;
- a C signal handler that calls into libc (the trampoline saves P/X/Y/A
  only, `crt0_far.s:441-470`);
- a libc slice that spans two code segments;
- out of room: a program whose data leaves no room for its blocks exits at
  startup with its message.

Measurement:
- a byte loop -- `cat` of a 64 KB file through `getc`/`putc`, built today
  and through the new path -- which is where a wrong core/block split would
  show;
- the per-access cost of a block static against a core one;
- the helper-usage count for section 6.

Everyday-workload numbers wait for the cut-over (sub-project 5).

## 9. Divergences, stated

| FGX | Source | Why |
|---|---|---|
| block statics reached through a table of block addresses | SunOS: library data at fixed offsets in a per-process mapping | no MMU; only reachable members' data is allocated |
| stdio and printf state is per-process core, not per-member | SunOS: all library data is per-process | the hot path cannot afford the table indirection; every stdio user carries it today |
| error messages in libc.so | 2.11BSD: `/etc/syserrlst` file | shared read-only banks cost no per-process memory |
| libfgx is a per-program library outside libc | (no counterpart) | libc is exactly 2.11BSD's libc |
| static programs capped at eight segments | (no counterpart) | the ninth slot is reserved for the `LIBC` kind a static program no longer has |

## 10. Open items

- Step 1 landed 2026-09-28 (plan `2026-09-28-shared-libc-sp2-step1-plan.md`):
  the fixed data prefix every program carries went from 3,528 bytes
  (`$0100`-`$0EC8`) to 1,182 (`$0100`-`$059E`).  `tools/check_libc_data.py`
  holds it: every label in the three hand-written data files is named by
  code.  `libc_args` went with the stale checked-in `tput.s`, its last user.
- Step 2 landed 2026-09-28 (plan `2026-09-28-shared-libc-sp2-step2-plan.md`):
  `make libc_so` compiles all of libc with `--libso`.  37 members have
  blocks, 9,443 bytes in all (ctime 3,182, the resolver 1,824, syslog 1,298);
  88 code sections reach a block and the other 478 are byte-identical with
  blocks off.  Block offsets are numbers fcc knows at compile time, asserted
  in each template.  Found on the way: a static program's data segment is
  already per-process, so `--libso-inplace` (each block cell pointing at its
  own template) may be all step 4's static path needs; and read-only tables
  (`syserrlst`'s pointer table, `strcasecmp`'s charmap) sit in blocks because
  fcc ignores `const` -- K&R A.8.2 lets a `const` object live in read-only
  storage, a follow-up.
- Step 3 landed 2026-09-29 (plan `2026-09-29-shared-libc-sp2-step3-plan.md`):
  `make libc_so` links `lib/libc.so.1.0` (187,030 bytes) through
  `toolchain/src/ld/fgx_libso.py` and fgx_ld's library link.  Three code
  banks (65,535, 65,535 and 40,706 bytes), a 2,071-byte core at `$F7E1`
  ending at `HEAP_LIM`, 9,443 bytes of block templates for 37 members, 333
  exports (319 code, 14 data), three fixups (stdin, stdout, stderr);
  `tools/libc_so_check.py` holds it.  Found on the way: fcc's data sectioning
  split every block template (fixed); Merlin32 refuses an object over 64 KB,
  so sections are measured in several runs; fcc's string members name the
  shims' direct-page cells `c_strcmp_a`/`c_strcmp_b`, so every bank defines
  them; a segment assembled at an `org` has listing addresses to subtract
  and pointers into it to add back; the data exports are held to section
  4's list in `lib/libc_c/data.exports`, so libc's ~290 internal core cells
  stay out of the checksum.  Every section assembled in its bank at exactly
  its measured size.
- Step 4 landed 2026-09-29 (plan `2026-09-29-shared-libc-sp2-step4-plan.md`):
  `_libc_init`, `fgx_static`, `_crt0_libso`, and the probe `libcso` (with
  `libcsofull`) passing headless in MAME.  libcso's libc slice: 64 functions
  in five banks at an 8 KB cap, 3,542 bytes of blocks for 7 members; on the
  machine `HEAP_LIM` came down to `$F222` and asctime's buffer sat at
  `$FFDE`, its offset in the process's ctime block.  libc.so's core now
  carries `_libc_blktab` (2,369 bytes, was 2,071); a pointer from the core
  into a template is an ordinary reloc, from code or a template still
  refused.  The packer places literals only data points at before it
  accepts a bank count.  Deviations: section 8's byte-loop and per-access
  measurements moved to step 5; its "every member whose code names slot S
  has S's owner in its closure" is not in libc_so_check (vacuous for
  libc.so, which ships every member) and holds for a static program by
  construction (a template is kept exactly when its cell is).  Found:
  `gmtime()`'s `tm_zone` reads `-00` on the machine -- the zoneinfo `GMT`
  file's first abbreviation, which `zic -r @0/...` makes a pre-range
  placeholder and Reno's `gmtsub` takes as the zone.  A tz defect,
  independent of this campaign.
- Step 5 landed 2026-09-29 (plan `2026-09-29-shared-libc-sp2-step5-plan.md`):
  each libc.so bank carries only the helpers it reaches (banks 65535,
  65535, 41640 bytes -> 65535, 65535, 33756; 65535, 65533, 35753 with the
  far entries); the census's ten far entries (section 6), checked by
  libc_so_check.
  The byte loop -- `/bin/sh` (96 KB, not 64) copied through getc/putc and
  cmp'd, primary_input inject -- takes 3,757 frames as programs link libc
  today and 3,613 statically against libc's library-mode compile (3.8%
  faster, identical over two fresh runs).  stdio's state is core, so no
  block indirection is in the loop; the likely cause is libc's calls as
  JSL where the pile made them PHK/PEA/PHK/PEA/RTL, but the two builds also
  differ in which libc code they carry and where, and 144 frames over ~196K
  getc/putc calls is ~34 cycles a call, more than the ~15 the call forms
  differ by -- the difference is measured, its attribution is not.  Per access,
  computed not measured: an isolated block-static store is ~37 cycles (the
  bank byte 16, the cell plus offset 14, the long-indirect store 7) against
  a core static's 5 -- the section 4 estimate of ~16 left out the bank
  byte.  Found on the way: bank 0's fixed overhead is measured with its
  starting helpers and their bytes taken back out.
- SP2 is complete.  Next is sub-project 3: the dynamic link mode.
- sh, tcsh and vi are FGX2: moved to FGX3 in sub-project 5.

## 11. Sources read

- K&R 2nd ed. A.2.6 (p. 156), A.7.4.8 (p. 165), A.8.7 (pp. 179-180), via
  gs-mcp `kr_c`.
- `examples/2.11BSD/usr/usr.lib/libutil/Makefile`,
  `examples/2.11BSD/usr/lib/libc/{net,gen/ttyslot.c,string/strerror.c,
  gen/syserrlst.c,pdp/sys/vfork.s,pdp/gen/setjmp.s,pdp/sys/Makefile}`,
  `vendor/2.11BSD/usr/usr.bin/cal.c`.
- FGX: `toolchain/src/cc/{emit.c,main.c,lex_pp.c,fcc.h,parse_expr.c,
  parse_stmt.c}`, `toolchain/src/ld/{fgx_ld.py,fgx_ar.py,fgx_gc.py}`,
  `toolchain/Makefile`, `toolchain/lib/{libc.s,libc_data.s,args_data.s,
  fcc_runtime_data.s,fcc_libc_shims.s,libc_c/libc_c.c,libc_c/stdio_core.c,
  libc_c/printf.c,libc_c/public.syms,libfgx_c/libfgx.c}`,
  `toolchain/lib/crt0_far.s`, `toolchain/include/{ctype.h,signal.h}`,
  `src/kernel/syscall.s`, `src/userland/cal/cal.c`, `tools/ninja/gen.py`.
- Adversarial review by Fable, 2026-09-28: nine findings, all adopted
  (hot state as core; honest fcc scope; literal mechanism; symbolic slots;
  `_libc_init` order; data-label dispositions; untested shapes; cost
  figures and the 2-byte table; stated divergences).
