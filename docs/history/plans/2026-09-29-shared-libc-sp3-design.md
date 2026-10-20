# Shared libc, sub-project 3: the dynamic link mode -- design

Status: approved in conversation 2026-09-29, section by section; revised the
same day for an adversarial review (Fable), sixteen findings adopted.
Parent: [`2026-09-28-shared-libc-design.md`](2026-09-28-shared-libc-design.md)
(the umbrella), whose section 6 item 3 this is; it builds on
[`2026-09-28-shared-libc-sp2-design.md`](2026-09-28-shared-libc-sp2-design.md)
(libc.so).  Branch `feat/shared-libc`.

## 1. Goal and how it is proven

fgx_ld links a program against shared libraries instead of copying them in:
an import table, prebind ordinals and checksums, the reachability bitmap,
reloc kinds for data references and function pointers, the fit rule, the
shadowing warning.  Static mode stays `fgx_static` (SP2).  No new segment
kinds: a dynamic program has no `LIBC` segment, so it is capped at eight
segments, which tcsh's seven code segments plus data fit.

**Three shared libraries, not one** (the maintainer, 2026-09-29; the umbrella, section
4, left it to this sub-project): `libc.so.1.0` (SP2), `libtermlib.so.1.0`
and `libcurses.so.1.0`.  termlib users today: clear, more, tctest, tput, ul,
robots, worm, and tcsh and vi through their own link scripts; curses users:
robots and worm.

**Proof (the maintainer, 2026-09-29): a host binder feeding MAME.**  The binder that
reads these tables arrives in sub-project 4, so this sub-project adds a
Python binder (`toolchain/src/ld/fgx_bind.py`) that does on the host what
SP4's `ldload` does once per boot (bind the libraries) and what its binder
does before `main` except the copy step (resolve and patch the program), and
writes an ordinary FGX3 image the existing loader runs.  The copy step --
cores into place, `HEAP_LIM` -- runs on the machine, in a small startup
routine the image carries, as SP4's binder will run it.  The probes run
headless in MAME.  fgx_bind is the reference SP4's 65816 binder is checked
against, so it implements the version rules and the trace output too
(section 4).  Rejected: host-only checks until SP4 (the case route A was
chosen to avoid in SP2); merging SP3 and SP4.

**Nothing this sub-project stages carries header flags bit 1 or 2.**  The
kernel loader reads no header flags today (`src/kernel/far/loader.s` never
names `FGX2_OFF_FLAGS`), so a library or an unbound dynamic program would
exec and jump through an unpatched `JSL $000000`.  libc.so and the dynamic
link outputs stay build products; only fgx_bind's images (both bits clear,
checked by fgx_bind) go on the disk.  The loader's refusal of bits 1 and 2,
with the umbrella's `ld.so: libc.so.N not loaded` message for a dynamic
program with no library resident, is sub-project 4's.

## 2. Libraries, and who binds them

Every library is built by SP2's path, generalised by library name: fcc
`--libso`'s static prefix (`_libc_c_`), block cells (`_libc_blk_<member>`)
and block table (`_libc_blktab`), fgx_libso's inputs, `core.list` and
`data.exports` all become per-library.  Each library's per-process state
takes SP2's tiers: a core (its data exports plus its hot state) and
per-member blocks.

**Each library's data, measured from today's sources:**
- *libc*: SP2's core (2,369 bytes with `_libc_blktab`), 14 data exports,
  plus the startup exports section 3 adds.
- *termlib*: exports `UP`, `BC`, `PC` and `ospeed`, which it now defines --
  2.11BSD's libtermlib does (`usr.lib/libtermlib/tgoto.c:14-15`
  `char *UP; char *BC;`, and SunOS's `tputs.c` has `PC` and `ospeed`), where
  FGX's `libtermlib.c:20-25` made them client-owned.  Its hand-written
  helpers (`lib/libtermlib_helpers.s`) go into its code and the baked
  entries they read DBR-relative (`lib/libtermlib_helpers_data.s`, ~330 B)
  into its core, so the helpers are unchanged; that data's 16-bit table
  words (`tc_str_table DA tc_cm`) are core-relative sites like any other.
  `libtermlib.c:51-52, 171` recovers the data bank from libc's private
  `args_env`; it takes it from `&UP` instead, whose address fcc builds with
  `PHB`, the process's data bank.
- *curses*: its data is nearly all extern-linkage -- the capability flags
  `AM`..`XN` and strings `AL`..`VS`, `LINES`, `COLS`, `stdscr`, `curscr`,
  `_tty`, `ttytype`, `My_term` and the rest -- so its `data.exports` is
  every extern object `curses.h` and `curses.ext` declare, read as whole
  declarations (98 names; the Makefile's `curses.fgxa.public` rule reads
  only each declaration's first line), and its core is 3,536 bytes: with
  the exports it holds `cr_tty.c`'s extern-linkage `char _tspace[2048]`
  and `_unctrl`'s 128 pointers.  `_tspace` as a block would cost every
  curses program the same bytes, since each reaches `cr_tty`.  `cr_tty.c`'s `sflags[]`, `sstrs[]` and `_PC` are
  in its `core.list`: the arrays hold the addresses of core cells (`&AM`,
  `&_PC`), which a block template cannot (fcc refuses `&_PC` of a block
  static in an initialiser), and core-to-core pointers are per-process
  fixups as `stdin` is in libc.  Its other statics are blocks: 1,657 bytes
  in five members (cr_tty 1,028, printw 512, scanw 100, cr_put 12,
  refresh 5; measured 2026-09-29).  `curses.c`'s tentative `UP`, `BC` and
  `PC` yield to termlib's under the common rule (section 2a);
  `cr_tty.c`'s `short ospeed = -1` loses its initialiser, since an
  initialised definition in curses would be a second owner of termlib's
  export -- `gettmode` assigns `ospeed` before anything reads it
  (`cr_tty.c:69`), so the -1 is never seen.
Each library's core carries its own copy of the fcc runtime cells
(`fcc_runtime_data.s`): its code's near helpers and inline `__asm` (termlib's
`__asm_p0`, `__asm_w0`) name them, and a library may not name libc's private
cells.  Each library's core size and export count are reported by the build
and held by the checks (section 5).

## 2a. Common symbols (the maintainer, 2026-09-29)

termlib defining `UP`, `BC`, `PC` and `ospeed` meets programs that define
them too: elvis's vendored `curses.c` (`vendor/netbsd-0-9`) has
`char *UP;`, curses has `char *BC, PC;`, and five FGX tools define
`UP`/`BC`.  2.11BSD links these because its linker merges common symbols.
K&R A.10.2 (p. 187): "Some implementations relax it by generalizing the
notion of tentative definition.  In the alternate formulation, which is
usual in UNIX systems and recognized as a common extension by the Standard,
all the tentative definitions for an externally linked object, throughout
all the translation units of the program, are considered together ... If a
definition occurs somewhere in the program, then the tentative definitions
become merely declarations."  FGX already applies this to multi-TU builds
(`fcc --commons` and `toolchain/tools/gen_commons.py`, used by sh and tcsh);
this sub-project applies it wherever a library is involved:

- *Static links, pruned library data*: fgx_gc treats a pruned section that
  holds only `<name> DS <n>` -- fcc's emission of a tentative definition --
  as a common.  It yields to a definition of the same name in a root file
  or in an initialised pruned section; of several commons, one survives
  (the largest).  Two initialised definitions are still refused.
- *Static links, whole-pile library data* (elvis, tcsh): the `gen_commons`
  pass with the library data as `--extern-defs`, as tcsh has; elvis gains
  it, so its vendored `curses.c` stays as it is.
- *Library builds*: a library's tentative definition of an export of a
  library below it is an import of that export (curses's `BC`, `UP`, `PC`).
- *Dynamic links* (step 3): a program's tentative definition of a needed
  library's data export is an import of it, not a shadow.  Only an
  initialised definition, or a function, shadows.

**One import format for every object that uses a library.**  termlib calls
libc; curses calls termlib and libc.  A library's imports and a program's
are the same table (section 3); only the binder and the time differ:

| Object | Applied by | When | Patches |
|---|---|---|---|
| a library (termlib, curses) | `ldload` (SP4); fgx_bind here | once per boot | its own shared banks and core template |
| a dynamic program | the binder (SP4); fgx_bind here | every exec | the program's own banks |

**A library may import only exports of libraries below it in the load
order, and only exports** -- never a private core cell, never a name from a
library above it.  A library's patches are made once for every process, so
an upward reference (a name a program or a later library defines) has no
single value.  fgx_ld refuses both.  This is why termlib owns `UP`/`BC`.

**Per-process data: stacked cores, relocated once at load** (the maintainer,
2026-09-29).  Libraries load in dependency order -- libc, termlib, curses --
and each core sits directly below the one before:

```
$0100  program data + bss, heap -> grows up to the break
       ... free ...
LIM    blocks of the members this program reaches, every library
       curses core    (a program that uses curses)
       termlib core   (a program that uses termlib or curses)
       libc core      (at the address libc.so was assembled for)
$FFF8  HEAP_LIM
```

libc's core stays where SP2 assembled it (`HEAP_LIM` minus its size), so its
load delta is zero.  termlib and curses are assembled with their core at the
base it stacks at under the libraries they were built against (so a boot
with those libraries patches nothing; at offset 0 Merlin would also
assemble operands below `$100` direct-page) and carry, in their trailer, the list of their 16-bit core-relative
sites, in code and in the core template alike; when a library's base is
known -- once per boot, since every process runs the same installed
libraries -- those sites are patched in its shared banks and in the resident
core template the binder copies.  Library code keeps absolute access (5
cycles).  A program pays for the cores of the libraries it uses and of those
below them in the order, which it also uses.

The startup order in a process: the copy step writes every core and sets
`HEAP_LIM` to the lowest core's base; each library's init then carves that
library's reached blocks below the current `HEAP_LIM` and lowers it
(`_libc_init`'s fit test, `libc_init.c:45`, is against the break the loader
set at the end of data + bss).  Fork's `[HEAP_LIM, $FFFF]` range (SP1) then
covers the cores and the blocks.

Precedent: SunOS's `ld.so` relocates a library's text when it must and
write-protects it again (`examples/SunOS-4.1.3/lang/rtld/rtld.c:436-447`,
`lm_rwt`); FGX does it once per boot rather than once per process.
Rejected: termlib/curses data all in blocks through a fixed anchor (every
access ~37 cycles, and a new fixed address); a fixed window per library (the
fixed data map the umbrella rejects, and a cap on libc's core).

**Static mode** is `fgx_static` as SP2 left it, libc only: the umbrella's
section 5.6 boot set (init, getty, login, fsck, sh, mount, ifconfig) uses
neither termlib nor curses.

## 3. Formats and the dynamic program

**Library trailer.**  SP2's `FGXL` trailer (`fgx_ld.library_trailer`) is a
fixed struct with no version.  It gains:
- a size in each data export record (kind 1), so an import's storage is
  known from the `.so` alone;
- a version byte, and a length word before each block, so a reader skips
  what it does not know.
The CRC-32 still covers the export records only (name, kind, bank, offset,
size), in ordinal order: it identifies the export table, and two builds
with the same CRC bind identically.  After the export, member-block and
fixup blocks, a library that imports carries an `IMPS` block -- the import
table a dynamic program's `FGXD` trailer also carries (below) -- and a
`CSIT` block of its core-relative sites.  `read_trailer` and
`tools/libc_so_check.py` follow.

**Dynamic program.**  The FGX3 file as today, program segments only.  Header
flags bit 2 marks it dynamic (bit 0 is strict-single-bank, bit 1 library).
A trailer after the relocs, magic `FGXD`, version byte (1), then tagged
length-prefixed blocks laid out as the library trailer's
(`fgx_ld.dyn_trailer`, `read_dyn_trailer`); its one block is `IMPS`, which
holds:

- **Needed libraries**, in dependency order: name, major, the minor linked
  against, the export table's CRC-32, the core base assumed, and the
  reachability bitmap over that library's block-table rows.
- **Imports**: library, ordinal, name, kind (code or data), and the prebound
  value (code: bank within the library and offset; data: 16-bit address
  and size).
- **Sites of each import**, three kinds:
  1. *call sites* -- an `FGX2_FARCALL` or `FGX2_FARJUMP` row whose name the
     object does not define.  The binder writes the 24-bit operand; the
     bank byte always changes, since library banks are granted at boot.
  2. *pointer cells* -- an `FGX2_LONG_PTR` row naming an import: fcc takes a
     function's address from such a cell (`int (*t[])() = { strcmp };` and
     `p == strcmp` both emit `FGX2_LONG_PTR _Fa;strcmp;0`).  The binder
     writes 24 bits.
  3. *data sites* -- every 16-bit operand or cell word that names a data
     import: `LDA errno`, `LDA stdout+2`, `LDA #errno` (with `PHB`, for
     `&errno` in code), the offset word of `LIBC_DATA_PTR _Spg;errno` (for
     `&errno` in data).  The binder adds (actual - prebound).

**Finding data sites without parsing operands.**  The driver (`fgx_libso`
for a library, `fgx_dyn` for a program) assembles and links twice: once with every data import at its prebound address, once
with all of them moved DOWN by one fixed delta (`$1010`, so both bytes of
every site change).  Down, because the
core sits at the top of the bank: an upward move would wrap past `$FFFF`,
and an operand that wrapped below `$100` would be assembled direct-page (fcc
emits `LDA errno` without Merlin's `:` force), changing instruction lengths.
Rules:
- the two builds must be the same length, or the link fails;
- every 16-bit word that differs by exactly the delta is a data site,
  attributed to the import whose storage `[address, address + size]`
  holds its first value -- one past the end included, as C allows a
  pointer to one past an object (`&sys_siglist[NSIG]`);
- any other difference -- a lone changed byte, a word whose first value lies
  in no import -- fails the link with its segment and offset;
- the data segment and, for a library, the core template are diffed as well
  as the code.
fcc never emits a bank-byte operand of a data address (the bank comes from
`PHB`), so a hand-written `LDA #>errno` serves only as the positive control.
The same method, with the library's own core moved, finds a library's
core-relative sites.

**The fcc runtime.**  Each code segment keeps its near helpers and the
program keeps its own runtime cells (`_fcc_tmp_b` and the rest), as today;
libc.so's code uses its core's copies.  For each far helper
(`lib/libc_so_helpers.s`), a segment carries a 5-byte thunk in place of the
helper -- `_fcc_fdiv MX %00` / `FGX2_FARCALL _fcc_fdiv_far` / `RTS` --
so fcc emits the same
`JSR` it does today; the far helpers are cold by the census's rule, so the
thunk's `JSR`/`RTS` is not on a measured path.  **fsub leaves the far
list**: `_fcc_fsub` falls through into `_fcc_fadd` (`fcc_runtime.s:1639-
1655`), fcc calls `_fcc_fadd` directly (`emit.c:2375, 4566`), and fsub
qualified only because the census sized the fall-through unit, not fsub
itself (10 bytes).  `tools/helper_census.py` sizes a fall-through unit as
its first label's own bytes and never chooses a unit whose other labels fcc
names; the list becomes nine (step 1, its own commit).  SP2's "lift"
(resolving the program's runtime cells to libc's core so the 16-bit helpers
could go far) is not taken.

**crt0 splits.**  Programs cannot name libc's private cells, and crt0 does.
- *New data exports* (libc's `data.exports`): `args_argc` and `args_argv`,
  which every compiled `main` names (`parse_stmt.c:8723, 8742`: `LDA
  args_argc`, `LDA #args_argv`), and `__progname`, which BSD sources
  declare extern.
- *libc's start*, a libc.so export `_libc_start`, called with
  `FGX2_FARCALL` from crt0 as crt0's first act after the copy step, with A =
  the offset of the program's signal stub.  It finds the kernel's argv frame
  at a fixed depth from its own entry -- the far call's three bytes plus
  its own pushes, stated in its header comment and checked by the probe's
  argv test -- and fills argc/argv/environ/`__progname`, `args_optind`,
  `_sig_tramp_off` (from A), `_SIG_DATA_DP` and libc's `_fcc_dbr`.
- *The trampoline*: the kernel delivers signals into segment 0
  (`crt0_far.s:169-173`), so the program keeps `_sig_tramp` as
  `JML _libc_sigtramp`, which leaves the delivery frame untouched;
  `_libc_sigtramp` is today's `_sig_tramp` body, in libc.so's bank 0 with
  the `_fcc_stkoflow` it jumps to near (`crt0_far.s:674`).
- *crt0's scratch cells* (`crt0_far.s:74-107`: `_crt0_callerS`,
  `_crt0_kernArgc`, `_crt0_walkIdx`, `_crt0_strBank0Ptr`, `_crt0_envIdx`,
  `_crt0_envOff`, `_crt0_baseOff`, `_crt0_dataBank`, `_crt0_sigbit`,
  `_crt0_sigbitHi`) work today only because they sit below `$100` in
  segment 0 and so alias the data bank's pad.  The code that uses them moves
  to libc.so, so they move into libc's core.
The program's crt0 is `lib/crt0_lib.s`; libc's half is `lib/libc_start.s`
(its scratch cells in `lib/libc_start_data.s`, core).  crt0 seeds its own
runtime cells, then (after the copy step, which the bound image's startup
routine or SP4's binder does first) `JSL`s `_libc_start` before pushing
anything, with A = its `_sig_tramp`'s offset; `_libc_start` finds the
kernel's argv frame at `S+4` behind its `JSL` and `PHP`.  crt0 then calls
the link's `_crt0_inits`, which calls `_lib_init(tab, bits)` for each
library in load order -- its block table (a data export: `_libc_blktab`,
`_libtermlib_blktab`, `_libcurses_blktab`) and the program's bitmap for
it, NULL for every row; a row whose bit is clear is skipped -- then `main`,
the stdio flush, exit.  `crt0_far.s` stays the pile path's until
sub-project 5: Merlin32 does not follow a `PUT` inside a `PUT` file, so the
two cannot share one body.

**Link-time checks:**
- The fit rule: data + bss end at or below `LIM` = `HEAP_LIM` - the cores
  used - the blocks reached, against the libraries linked with.  Refused
  with the three numbers.  `ac` (2.11BSD `tbuf[6242]`) is the known-bad
  case.
- The shadowing warning: a program that defines a function or an
  initialised object a needed library exports is warned, naming both.  Its
  own references bind to its definition; the library's internal ones reach
  the library (`-Bsymbolic`, umbrella 5.3).  `ul` (`fflush`, `puts`) and
  `od` (`puts`) trigger it.  A tentative definition does not (section 2a):
  the termlib users' `char *UP;` binds to termlib's, so `tgoto` and the
  program share one cell.
- The bitmap: fgx_gc's closure from the program's imports through every
  needed library's library-mode `.s`, so libc members curses reaches count
  in libc's bitmap.  fgx_gc resolves a shadowed name to the library's
  section too (it sections only pruned files), so a shadowed member counts
  as reached: an over-approximation, stated, costing only that member's
  block.
- Stack sizing: the library code the program reaches -- the live code
  sections of the bitmap pass, written to `<lib>_reach.s` in the link
  directory -- is passed to `stack_measure` as frames beside the program's
  `.s`, as fgx_static passes libc's banks, so a call into a library is
  priced from its code, not the 384-byte fallback.  Not the whole
  library-mode `.s`: libc's own `syslog`/`vsyslog` cycle would warn on
  every link.

**The driver.**  `toolchain/src/ld/fgx_dyn.py --lib libc[,libtermlib,...]`
does for a dynamic program what `fgx_static.py` does for a static one.  It
adds the libraries below those named and orders them for loading, and
links two segments: segment 0 holds `macros.s`, `seg1_layout.s`,
`imports_layout.s` (the data exports as `EQU`s at their prebound
addresses, less any the program shadows), `crt0_lib.s`, the program's
code, the fcc runtime units it reaches with the far helpers as thunks, and
`_crt0_inits`; segment 1 holds the 256-byte pad, the `LIBC_DATA_PTR`
macro, the program's own runtime cells, its data with tentative
definitions of library exports dropped, and `_dyn_bits_<lib>`, one bitmap
per library, which `_crt0_inits` passes to `_lib_init`.  All of a
program's code is one segment until sub-project 5 links the multi-bank
tools (tcsh, vi, frotz) through the tool build; the trailer and fgx_ld's
binding are per segment already.

## 4. The host binder

`fgx_bind.py` takes a dynamic program and the `.so` files it needs and
writes an ordinary FGX3 image (header flags bits 1 and 2 clear, checked):

- **Versions** (umbrella 5.4): a library whose major differs from the
  program's record is refused; an older minor than recorded binds with
  `ld.so: warning: <lib> has older revision than expected <minor>`, the
  SunOS text (`cache_rtld.c:143-183`).
- **Segments**: the program's, then each library's code banks as `CODE`
  segments; each library's block templates are appended to the free tail of
  its last code bank (libc's bank 2 has ~30 KB free; its templates are
  9,443 B), so a library costs its code banks and nothing more.  The
  library's internal `JSL` relocs and its template pointers become image
  relocs.
- **Binding**, done offline as SP4 will do it: each library's imports and
  core-relative sites at the stacked bases; then the program's three site
  kinds.  The prebound path when a library's CRC and base match the
  program's record -- no name looked up; the by-name path when they do not.
  `--trace` prints each binding the way `ldd` will (umbrella requirement 5)
  and says which path each library took.
- **Cores**: the data segment stays as fgx_ld wrote it, so the loader sets
  the break at the end of data + bss.  The image adds, at the end of segment
  0, a startup routine that copies each library's core template (carried in
  that library's last bank) to its stacked base and writes `HEAP_LIM`, then
  enters crt0 -- SP4's binder step 5, running on the machine.

**As built** (`toolchain/src/ld/fgx_bind.py`, step 4).  The loader needs
nothing new: it gives each segment its own bank at offset 0, treats CODE,
DATA and RODATA alike and applies a reloc by writing one bank byte, unchecked
(`src/kernel/far/loader.s:1224, 1545, 1044-1046, 1370-1393`), so fgx_bind
checks every reloc offset itself.  A library's core template and block
templates go on the end of its last bank (libc's becomes 47,890 bytes); a
pointer into the templates -- a block-table row -- gains their offset; a
per-process fixup is a reloc to the program's data segment, placed on the
template copy.  The startup routine is `PHP` / `REP #$30`, per library
`LDX #template` / `LDY #base` / `LDA #size-1` / `MVN`, then `LDA #lowest` /
`STA $FFF8` / `PLP` / `JMP _crt0_lib`.  `MVN`'s operand bytes are the
destination bank, then the source (*Programming the Apple IIgs* part 2,
pp. 157-158; Merlin writes `MVN src,dst`), relocs to the data segment and
to the library's last bank; it leaves DBR = the data bank, and `PHP`/`PLP`
leave S and P as the loader set them.  A needed library's IMPS record
carries the row count of the block table its bitmap was built over; a
library whose table has another count is refused, prebound or by name --
the table carries no names to remap the bitmap by.

Limit, stated: the image holds at most nine segments (the ninth `LIBC` only,
`fgx_ld.py:839-853`), and libc costs three, termlib and curses one or two
each, so a program with all three libraries can have about two code
segments, and with libc alone about four.  tcsh-sized programs wait for
SP4's loader, which maps library banks without file segments.

## 5. Testing and measurement

FGX rules: small tests aimed at what changed, a positive control for every
check, nothing added to the gate.  Nothing shipped is relinked until SP5, so
the gate and suite must stay green unchanged.

Host (`make test-archives`):
- the site finder: a hand-written `LDA #>errno` and a planted odd difference
  are refused; two builds of different length are refused; `LDA stdout+2`
  and `&sys_siglist[NSIG]` attribute to their imports;
- every unresolved `FGX2_FARCALL` in a dynamic link has a call site;
- a library naming a private core cell or an upward name is refused
  (`args_env` from termlib is the known-bad case);
- the fit rule refuses a program whose bss leaves no room;
- the shadowing warning fires on `ul`'s source;
- the bitmap equals fgx_gc's closure; a member the program neither reaches
  nor shadows is absent;
- `tools/libc_so_check.py` generalised to libtermlib.so and libcurses.so:
  export counts and core sizes held, each library's imports resolve against
  the libraries below it;
- helper_census: fsub is not chosen, and a fall-through unit is sized by its
  first label.

Machine (headless MAME, testbin, not the gate):
- **`dynso`**: libcso's checks (SP2 section 8) linked dynamic and host-bound,
  plus argv and `__progname` (the start's frame depth), `qsort(..., strcmp)`
  (a pointer cell), `&errno` and `stdout+2` (data sites with and without an
  addend), a signed `long` divide (`_fcc_long_divs_far` through its thunk),
  a signal through the `JML` stub, sbrk up to the lowered limit, and
  `HEAP_LIM` equal to the cores plus the reached blocks exactly.  As
  built, the exact value is checked on the host (the startup routine's
  `LDA #` operand is the lowest core base, `tests/dyn/test_bind.py`); on
  the machine a dynamic program cannot name a block cell, so `dynso` checks
  the carve through `_libc_blktab` and its own `_dyn_bits_libc`: the
  reached blocks lie back to back from `HEAP_LIM`, below libc's core, and
  add up to the bitmap's need.
- **`dynso`, prebound**: fgx_bind's trace shows the prebound path taken with
  no name lookups.  **`dynso`, mismatched**: bound against a libc.so rebuilt
  with one extra core cell, so its CRC and every data address differ; the
  trace shows the by-name path and the probe still passes.  Control: the
  same bind with data-site patching off must fail.
- **`cursso`**: a small curses program linked against all three libraries:
  `initscr`/`addstr`/`refresh`/`endwin` on a dumb terminal, `LINES`,
  `COLS` and `stdscr` read by the program (curses core data), `tgetent`,
  `tgoto` and `UP` (termlib's).

Measured and reported: each probe's file and per-process sizes against its
static link, and the number of sites of each kind.

## 6. Order of work

Each step lands on its own; the gate stays green.

1. **Libraries generalised.**  helper_census's fall-through rule and the
   nine-helper list (own commit); common symbols in fgx_gc and elvis's
   link; termlib owning `UP`/`BC`/`PC`/`ospeed` and dropping `args_env`
   (shipped: gate); the `FGXL` version, sizes and blocks; fcc `--libso`
   naming per library; the site finder; fgx_libso per library;
   `libtermlib.so.1.0` and `libcurses.so.1.0` with their imports and
   core-relative sites; `libc_so_check` for all three.
2. **Startup.**  The new data exports, `_libc_start`, `_libc_sigtramp`,
   crt0's scratch cells in libc's core, library init with a bitmap.
   `libcso` (static) stays green.
3. **fgx_ld dynamic mode.**  The `FGXD` trailer, the three site kinds, the
   thunks, the fit rule, the shadowing warning, the bitmap, stack sizing.
4. **fgx_bind and the probes** in MAME, including the prebound and
   mismatched binds.

## 7. Divergences, stated

| FGX | Source | Why |
|---|---|---|
| a library's text is relocated once per boot for its core base | SunOS relocates text per process when it must (`rtld.c:436-447`) | one resident copy system-wide; every process has the same bases |
| library cores stack in dependency order below `HEAP_LIM` | SunOS maps each library's data where it maps the library | no MMU; a library's code reaches its data absolute |
| a library imports only downward, only exports | SunOS resolves library references through a global lookup (`rtld.c:836-841`) | a library is patched once for every process |
| the program's signal trampoline is a `JML` to libc's | SunOS: signals go through libc's `sigtramp` in the library | the kernel delivers into the program's segment 0 |
| far fcc helpers reached through per-segment thunks | (no counterpart) | fcc emits the same code for static and dynamic links |
| curses's `ospeed` has no `-1` initialiser; termlib owns it | 2.11BSD `libcurses/cr_tty.c:48` `short ospeed = -1;` beside termlib's tentative one | a library cannot import from the library above it; `gettmode` assigns it before any read |

## 8. Open items

- Step 4 landed 2026-09-30 (plan `2026-09-30-shared-libc-sp3-step4-plan.md`);
  with it sub-project 3 is done.  `fgx_bind.py` binds a dynamic program to
  its libraries on the host.  In headless MAME:
  - `dynso` (libc, prebound, no name looked up): every check passes --
    libcso's, a pointer cell holding `strcmp`, `qsort` calling back into
    the program, `&errno` in data, `stdout`, a `long` divide through the
    far helper's thunk, the carve.  5 segments, 189,263 bytes (the
    program's own 5,250 + 746; libc's banks 178,959), 1,063 relocs, 63 call,
    1 pointer and 13 data sites, LIM `$E8CD`; per-process data 6,677 bytes
    (746 + libc's core 2,389 + blocks 3,542).  With the routine's `PLP`
    dropped it fails `argv`.
  - `dynsomis`: bound by name (all 34 imports) against a libc.so built
    with `fgx_libso.py --core-pad 2` (core `$F6A1`, another CRC): passes.
    `dynsonodata`, the same bind without data-site patching: `_lib_init`
    reads a table two bytes off and refuses before main, status 1.
  - `cursso` (libcurses, libtermlib, libc, all six bindings prebound):
    `initscr`/`addstr`/`refresh`/`endwin` on the console, `LINES`, `COLS`,
    `stdscr`, termlib's `UP` as curses's `setterm` filled it, `tgoto`,
    `tgetent` -- all pass.  7 segments, 234,450 bytes, 1,433 relocs, 17 call
    and 27 data sites, LIM `$E2AD`; per-process data 7,995 bytes (496 +
    cores 6,374 + blocks 1,125).
  - Host: `tests/dyn/test_bind.py` binds tctest against a libc two bytes
    larger: both libraries by name, termlib's base `$F4E0`, its 220 core
    sites and the program's 10 `UP` sites moved by -2.
  - Against its static counterpart: libcso (the same checks, linked by
    fgx_static) is 53,529 bytes with the libc it reaches in its own banks;
    a bound image carries all of libc until SP4 shares the banks.
  - Build: the `libso` ninja edge (termlib and curses, ~4 s when they
    change), each probe ~0.8 s, dynsomis's padded libc 26 s when libc or
    the linker changes.

- Step 3 landed 2026-09-30 (plan `2026-09-30-shared-libc-sp3-step3-plan.md`).
  `fgx_dyn.py` links a program against the shared libraries; fgx_ld writes
  the `FGXD` trailer.  Measured (hello links in 0.36 s):
  - `tests/dyn/hello.c` (libc): segment 0 415 bytes, data 419, 12 imports
    with 8 call, 1 pointer and 6 data sites (`stdout`'s two words hold its
    address and its address + 2), LIM `$F69D`; `malloc` and `proc` reached,
    `ctime` not.  Its stack is 0 pages from its own code and 3 with libc's
    reached code (0.02 s to measure).
  - `ul` (libc, libtermlib): segment 0 9,223 bytes, data 2,314, 25 imports
    (40 call, 16 data sites), LIM `$F382`; warned for `fflush` and `puts`,
    neither imported.
  - `tctest` (libc, libtermlib): segment 0 1,598 bytes, data 1,536, 14
    imports (18 call, 14 data sites), LIM `$F492`; `UP` a data import from
    libtermlib with 10 sites, `BC` dropped and not imported.
  - `tests/dyn/fit.c` (64,000 bytes of bss): data ends at `$FB85`, above
    LIM `$F6A3`, refused; with 1,000 bytes it links.
  With the commons pass off, tctest's case fails; with the fit check off,
  fit's does.

- Step 2 landed 2026-09-30 (plan `2026-09-30-shared-libc-sp3-step2-plan.md`).
  libc.so: 3 code banks (65,534, 65,535, 36,058 bytes), a 2,389-byte core at
  `$F6A3`, 349 exports (331 code, 18 data); termlib's and curses's cores
  stack 20 bytes lower ($F4E2, $E712).  The static path starts through
  `crt0_lib.s`; `crt0_libso.s` is gone.  In MAME, libcso passes every check,
  among them argv, `__progname`, `_lib_init`'s bitmap and an empty table,
  and a signal through the `JML` stub to `_libc_sigtramp`; libcsofull,
  bytecatso and bytecat pass.  With `_libc_start` reading the frame at
  `S+3`, libcso fails argv and progname.

- Step 1 landed 2026-09-29 (plan `2026-09-29-shared-libc-sp3-step1-plan.md`).
  `libtermlib.so.1.0`: 1 code bank (3,264 bytes), a 449-byte core at
  `$F4F6`, one 74-byte block, 3 code imports from libc (strcat, strcmp,
  strcpy; 7 call sites), 220 core sites.  `libcurses.so.1.0`: 1 code bank
  (38,891 bytes), a 3,536-byte core at `$E726`, 5 blocks (1,657 bytes), 98
  data exports, 27 imports -- 21 code (83 call sites), and data `UP`, `BC`,
  `PC`, `ospeed` from termlib and `stdout`, `_ctype_` from libc (31 data
  sites) -- 1,712 core sites, 82 per-process fixups (`sflags`, `sstrs`).
  libc.so's far helpers are nine (1,591 bytes): fsub runs into fadd.
  termlib owns `UP`/`BC`/`PC`/`ospeed` in the shipped archive and pile
  too; fgx_gc merges common data symbols, and elvis runs the gen_commons
  pass.  Found on the way: tcsh's data link, the M37-M39 fixture wraps and
  the bench corpus wrap hand-defined `UP`/`BC`; fgx_gc's row count missed
  `LIBC_DATA_PTR`; fgx_ld's D1b refused an import's `JSL $000000`.

- `ldload`'s bytes, the binder's, and the loader's refusal of flags bits 1
  and 2 are sub-project 4's; this sub-project's formats are what they read.
- The host binder's segment limit (section 4).
- SP2's deferred minors stand (RESUME-2026-09-29b).

## 9. Sources read

- `examples/SunOS-4.1.3/lang/rtld/rtld.c` (text relocation, `lm_rwt`,
  lines 436-447; global lookup 836-841), `cache_rtld.c:143-183`.
- `examples/2.11BSD/usr/usr.lib/libtermlib/tgoto.c:14-15`; SunOS
  `ucblib/libtermlib/{tgoto.c,tputs.c}`.
- FGX: `toolchain/src/ld/{fgx_ld.py,fgx_static.py,fgx_libso.py,fgx_gc.py,
  stack_measure.py}`, `toolchain/lib/{crt0_far.s,crt0_libso.s,
  fcc_runtime.s,fcc_runtime_data.s,libtermlib_helpers.s,
  libtermlib_helpers_data.s,libc_c/data.exports,libc_c/libc_init.c}`,
  `toolchain/lib/libtermlib_c/libtermlib.c`,
  `toolchain/lib/libcurses_c/curses.ext`, `toolchain/include/curses.h`,
  `toolchain/src/cc/{emit.c,parse_stmt.c}`, `toolchain/Makefile`,
  `src/kernel/far/loader.s`, `tools/helper_census.py`,
  `tools/ninja/manifest.json`, `src/userland/{ul/ul.c,od/od.c}`, fcc's
  output for function and data addresses of externs (measured 2026-09-29).
- Adversarial review by Fable, 2026-09-29: sixteen findings, all adopted
  (the bound image's cores; termlib owning `UP`/`BC`; the segment count;
  `args_argc`/`args_argv` as exports; export sizes; fsub/fadd; crt0's
  scratch cells; `_libc_start`'s contract; header flags; the trailer's
  extension; the site finder's rules; stack sizing; versions and trace;
  per-library data; the shadowed bitmap; the tests).
