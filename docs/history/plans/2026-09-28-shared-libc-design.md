# Shared libc -- design (umbrella)

Status: design approved in conversation 2026-09-28; this document is the
written spec for review.  Each sub-project below gets its own short spec and
implementation plan when it starts.

## 1. Why

Measured 2026-09-27/28 on main 75f05713f (MAME, `FGX_MAME_PRIMARY=inject`,
retronet card, 8 MB).  Instruments and manifests:
`docs/history/wip-2026-09-28-cache/` (untracked).

- An everyday shell session (`cd /etc; ls; cat motd; grep root passwd; head -5
  services; date; who` then `ls -l /tmp; wc -l rc; sed -n 1,5p rc; ps; df;
  pwd; echo done`, run twice) reads 828 KB from disk in round 1 and 744 KB in
  round 2.  Mapping every block to its file: **376 KB per round is libc pile
  files** (`/lib/libc.so.<size><sum>`), re-read in full every round; 307 KB is
  program binaries; the rest is metadata and data.
- 157 pile classes exist and **142 are used by exactly one binary**: the
  function-level libc GC (apple/fgx#457) made every tool's pile unique.  A
  resident pile costs a whole 64 KB bank; the user bank pool is 49 of 56 in
  use at an idle prompt.
- Per command: fork 80 ms, exec 90 ms (20x repetitions, equal-length lines).
- libc already exceeds one bank: the union of its members is >= 76 KB.

A shared libc removes the per-process pile bank, the per-exec pile read and
copy, and the class explosion, and gives libc room to grow past one bank.  The
working-set buffer cache (a separate project) is sized after this one lands.

## 2. Requirements (the maintainer, 2026-09-28)

1. Design for libc growth.  FGX libc today: 103 archive members, 380 exports;
   2.11BSD's libc has 271 source files; later BSDs more.
2. A binary carries only what it needs and reaches shared copies of libc.
3. No per-process cost for libc functions a program does not use.
4. Divergence from BSD must fit the BSD pattern and not lock in a shape that
   is hard to extend.
5. SunOS `ldd` works.

## 3. Model

SunOS 4.1.3 a.out shared libraries, adapted to 64 KB banks and no MMU.

- A library is `libc.so.MAJOR.MINOR`.  A program records the library, its
  major, and the minor it was linked against.  Binding uses the installed
  library with the same major and the highest minor, and warns when that
  minor is older than the program's
  (`examples/SunOS-4.1.3/lang/rtld/cache_rtld.c:143-183`, `ask_db`:
  "ld.so: warning: %s has older revision than expected %d").
- Minor versions add; a major version is any incompatible change.
- The binder runs in user space before `main`, entered by crt0 at a fixed
  point, as SunOS's `ld.so` is (`rtld.c:47-68`, `struct crt_i1`).
- `ldd` (`examples/SunOS-4.1.3/bin/ldd.c`, 117 lines) execs the target with
  `LD_TRACE_LOADED_OBJECTS` set; the binder prints the bindings and exits.
  It ports as-is.

Rejected:
- **Per-tool pile consolidation (apple/fgx#390 as written).**  A class is
  still one 64 KB bank, programs carry unused functions, every libc edit
  re-keys every class, and there is no growth path.  Also rejected as a
  stopgap.
- **A fixed-ordinal jump vector** (IIgs toolset / System V static shared
  library style).  Ordinals are frozen forever and there is no clean path for
  an incompatible change.  (The `fpsim` module is a fixed-vector service and
  stays one; the two shapes coexist.)
- **SunOS's whole-library data per process.**  SunOS maps a library's data
  copy-on-write and its bss from `/dev/zero` (`rtld.c:62`), paying only for
  pages touched.  Without an MMU every byte would be copied and zeroed on
  every exec and fork, and the cost would grow with libc.
- **A fixed, append-only libc data map as ABI.**  Fragile: every libc change
  becomes an ABI decision and a violation corrupts old binaries silently.
- **Binding in the kernel loader.**  The kernel bank has 163 B free and the
  far bank 187 B (`tools/check_kernel_ceiling.py`, 2026-09-28); a kernel has
  no user stream for `ldd`'s output.

## 4. What libc contains

**libc.so contains exactly what 2.11BSD's libc contains; everything else is
its own library.**  Three corrections to today's archives (sub-project 2):

| Code | 2.11BSD | FGX today | Change |
|---|---|---|---|
| `logwtmp` | `libutil.a` (`login.o logout.o logwtmp.o dkcksum.o`) | libc member | move to a new `libutil` |
| `gethostbyname`, `gethostbyaddr`, `getservbyname`, resolver | libc (`usr/lib/libc/net`: `getsbyname.c`, `res_*.c`, `named/`) | separate `resolv` archive (split 2026-07-20 for one-bank pressure only) | back into libc |
| long arithmetic runtime | libc (`usr/lib/libc/pdp/crt`: `lmul.s ldiv.s lrem.s uldiv.s ulrem.s ...`) | `llong` archive, selected per tool | into libc |

Floating point is NOT libc: 2.11BSD simulates it in the kernel
(`usr/sys/pdp/mch_fpsim.s`) and FGX mirrors that with the `fpsim` module.
`double` stays there.

`curses` and `termlib` stay separate archives (2.11BSD `libcurses.a`,
`libtermlib.a` = `termcap.o tgoto.o tputs.o`).  Whether they become shared
libraries is decided in sub-project 3; SunOS's first release shared only libc.
Unported 2.11BSD libraries (`libm`, `libdbm`, `libmp`, ...) are separate
archives when ported.

## 5. Architecture

### 5.1 libc.so

- One library across N 64 KB code banks, loaded once system-wide and never
  unloaded before reboot.  Upgrading libc means a reboot.
- An export table: name, bank, offset, and the export's kind (code or data).
  A checksum of the table identifies the build for prebinding (5.3).
- Calls between libc functions are ordinary `JSL`s whose bank bytes are
  patched once when the library is loaded.  `PILE_CALL`
  (`toolchain/lib/macros.s:749-756`, 23 cycles against `JSL`'s 8) exists
  only because the pile is relocation-free; it retires.
- Most of fcc's runtime moves into libc.so.  Today `fcc_runtime.s` is 3,554 B
  in every code segment (tcsh: 7 code segments, 24.9 KB of identical bytes).
  Only helpers hot enough to need a near `JSR` stay per segment; that set is
  decided by measurement in sub-project 2.
- Read-only data (string literals, `strerror` messages, the ctype table,
  signal names; ~3.5 KB today) lives in libc.so's banks and is read with long
  addressing, not copied into processes.
- Built by an fcc/fgx_ld libc-build mode (sub-project 2).  BSD sources stay
  verbatim.

### 5.2 Per-process data

libc's code and data are built together, so libc's internal data addresses
only need to agree within one libc build.  They are not ABI.

Three tiers:

1. **Core**: data nearly every program uses or can name -- `errno`,
   `environ`, the `stdin`/`stdout`/`stderr` structures, argument and `getopt`
   state, the printf engine, fcc runtime scratch, and **every data object a
   program can bind to by name** (e.g. `tzname`, which programs read before
   any `ctime` call, `ctime.c:104-110`; the resolver's `_res`).  Fixed size
   per libc build (~2 KB expected), at the top of the data bank.  libc
   reaches it absolute through the data bank register.
2. **Per-member blocks**: each libc source file's statics are one block.
   The linker records the libc members a program can reach (the closure
   `fgx_gc` already computes for #457) as a bitmap in the program (13 B at
   103 members).  At startup the binder allocates exactly those blocks, below
   the core, and records each in a per-process block table in the core
   (2 B per stateful member).  libc reaches a block through the table
   (`LDX slot / LDA off,X`, ~4 cycles over a direct access).  Deterministic:
   the program fits or fails at startup, never later.  Precedent: tzcode's
   `ALL_STATE` (in `toolchain/lib/libc_c/ctime.c`) moves state out of static
   storage the same way.
3. **Read-only**: in libc.so's banks (5.1).

Data bank (every dynamic process):

```
$0000  pad / crt0 scratch                  (unchanged)
$0100  program data + bss
       heap -> grows up to the break
       ... free ...
LIM    per-member blocks (this program's reachable set)
LO     core (fixed size per libc build)
$FFF8  HEAP_LIM  (new: first byte the heap may not reach)
$FFFA  HEAP_BASE / $FFFC HEAP_HWM / $FFFE HEAP_BRK   (unchanged)
```

`LIM` is the value the binder stores in `HEAP_LIM`: the bottom of this
program's per-member blocks.

**The fit rule**, one rule checked twice: a program's data + bss must end
below `LIM`.  `fgx_ld` checks it at link time against the libc it links with;
the binder re-checks at startup against the installed libc and exits with a
message, as SunOS's `ld.so` does, if it fails.  `sbin/ac` is the first
program the rule catches (2.11BSD `tbuf[6242]` is ~49.9 KB with fcc's 4-byte
pointers); its fix is ordinary port work (upstream's commented-out
`TSIZE 1000`).

### 5.3 Binding

- A dynamic program carries an import table: each libc name it uses, with
  its export-table **ordinal** and the libc build's table checksum at link
  time (prebinding).  Code references go through per-import site lists; data
  references and function-pointer cells get their own reloc kind (today
  `FGX2_LONG_PTR` targets a segment, `macros.s:757-770`).
- At startup the binder:
  1. finds libc.so through a fixed bank-0 vector set when libc.so was loaded
     (the `FPSIM_TRAMP` pattern);
  2. checks the major and minor (5.4);
  3. resolves each import: if the checksum matches, `table[ordinal]` with no
     string compares; otherwise by name, SunOS-style;
  4. patches the program's call operands (full 24-bit), data operands and
     function-pointer cells in the program's own banks;
  5. copies the core template from libc.so into the data bank, allocates and
     zeroes the reachable per-member blocks, writes `HEAP_LIM`;
  6. if `LD_TRACE_LOADED_OBJECTS` is set, prints the bindings and exits.
- **Interposition**: a program's definition of a libc export shadows it for
  the program's own calls only.  libc's internal calls always reach libc.
  SunOS resolves every reference through a global lookup, libraries included
  (`rtld.c:836-841`); shared banks cannot be patched per process, so FGX is
  effectively `-Bsymbolic`.  `fgx_ld` warns when a program defines a libc
  export (known today: `ul` defines `fflush` and `puts`, `od` defines
  `puts`).
- **ABI**: export names, plus the sizes and layouts of exported data objects
  (`FILE`, `struct tm`, ...).  Changing either is a major bump.

### 5.4 Loading and versions

- `/etc/rc.in` runs a small user-space loader (`/sbin/ldload`) early in boot.
  It picks the highest installed minor of each major once (the `ldconfig`
  role), allocates banks through a `SYS_MODLOAD`-shaped call, relocates the
  library's internal calls, and registers it: one registry row per library
  (name, major, minor, first bank, bank count, export table).
- `LD_LIBRARY_PATH` has no meaning with one resident libc per major; stated,
  not implemented.
- Per-process libc tracking (`TCB_LibcBank`, refcounts, `_libcShTab`'s
  per-bank slots, `_LibcSh_Reclaim`) retires in sub-project 5.

### 5.5 Kernel changes

Kept small on purpose (the kernel and far banks are nearly full):

- `_Sys_Brk`'s ceiling becomes `HEAP_LIM` instead of the constant
  `HEAP_TOP+1` (`src/kernel/process.s:2628`).
- Fork's snapshot and restore copy `[0, break]` and `[HEAP_LIM, $FFFF]`
  (`_Fork_CopyBank`, `_Img_Extent`, `_Img_Brk`, `process.s:1218-1300`).
- The loader seeds `HEAP_LIM = $FFF8` (the cell's own address) for every
  program.  The cell occupies $FFF8-$FFF9, which the heap could reach before,
  so the highest break drops by one byte ($FFF9 to $FFF8); nothing else
  changes for a program with no shared libc.
- The `ldload` bank grant and registry.  Where its bytes come from is a
  sub-project 3 constraint (candidates: a module, or the pile path's code
  freed in sub-project 5).
- Retired in sub-project 5: the pile registry and `/lib/libc.so.<key>` open
  path (`src/kernel/far/loader.s:287-360`, `1030-1290`).

### 5.6 Static programs

`fgx_ld` keeps a static mode (SunOS `-Bstatic`, `lang/ld/ld.c:793-805`).
Boot-critical programs stay static so a missing or broken libc.so cannot
stop the machine reaching a shell: today's `PILE_CARRIES_OWN` set (`init`,
`getty`, `login`, `fsck`; `tools/ninja/gen.py:154`) plus `sh`, `mount`,
`ifconfig`.  A dynamic program started with no libc.so resident prints
`ld.so: libc.so.N not loaded` on fd 2 and exits 1; the kernel is not
involved.

## 6. Sub-projects and order

1. **Heap limit and fork** (kernel; lands alone).  **DONE 2026-09-28**:
   1f5e257 (fgx_ld fit rule), 5e16ae2 (the cell and the ceiling), 4fc1baa
   (fork's top range); plan `2026-09-28-shared-libc-sp1-plan.md`.  `HEAP_LIM` cell seeded to
   $FFFA, `_Sys_Brk`, fork's second range, libc `brk`/`sbrk`, `ps`,
   `sbrktest`/`heapkill`.  No behaviour change for any shipped program.
2. **libc.so** (toolchain).  libc-build mode in fcc/fgx_ld: multi-bank
   layout, export table and checksum, load-time-relocated `JSL`s (retire
   `PILE_CALL`), per-member block access, read-only data in libc banks, core
   data rule, fcc runtime fold-in.  The library-boundary fixes of section 4.
   Its own spec: [`2026-09-28-shared-libc-sp2-design.md`](2026-09-28-shared-libc-sp2-design.md),
   which also corrects this document: `_ctype_` and `sys_siglist` are core,
   not read-only (5.1); block statics are reached through a pointer table,
   not `off,X` (5.2); the container is FGX3; libfgx is a per-program
   library outside libc.so.  The library-boundary fixes landed 2026-09-28
   (9bb5c1f4e, c3abf805f).  **DONE 2026-09-29** (feat/shared-libc
   09d186399): all five steps -- libc's hand-written parts, fcc `--libso`,
   the `lib/libc.so.1.0` link (fgx_libso + fgx_ld's library trailer),
   `_libc_init` with the static link path (fgx_static) and the `libcso`
   probe passing in MAME, per-bank fcc helpers and ten far helper exports;
   results in that spec's section 10.
3. **Dynamic link mode in fgx_ld** (toolchain; alongside 2).  Import tables,
   prebind ordinals and checksum, reachability bitmap, data and
   function-pointer reloc kinds, the fit rule, the shadowing warning, static
   mode.  No new segment kinds (tcsh is at the 9-segment cap,
   `fgx_ld.py:105`).  Its own spec:
   [`2026-09-29-shared-libc-sp3-design.md`](2026-09-29-shared-libc-sp3-design.md),
   which also makes termlib and curses shared libraries (the maintainer,
   2026-09-29) and proves the link mode through a host binder.  **DONE
   2026-09-30** (feat/shared-libc c1f3e9a6e): libc.so, libtermlib.so and
   libcurses.so with import tables and core-relative sites; `_libc_start`
   and the crt0 split; `fgx_dyn.py` (the dynamic link: FGXD trailer, thunks,
   commons, shadows, bitmaps, fit rule, stack sizing); `fgx_bind.py` (the
   host binder) with `dynso`, `dynsomis`, `dynsonodata` and `cursso`
   passing in MAME; results in that spec's section 8.
4. **Binder, loader and boot** (user space + small kernel).  crt0 entry,
   binder, `ldload`, registry, bank-0 vector, `ldd`, `rc.in`.
5. **Cut-over**.  Relink everything dynamic except section 5.6's static set;
   FGX3 binaries (ls, cat, ps, date, grep) move to the new form; the libc
   overlay (docs/fgx2-linker.md) and content-keyed piles retire; the pile
   registry and pile staging (`tools/stage_piles.py`) go; `ac` is fixed.
   Then measure (section 7).

Then the working-set buffer cache, sized to what remains.

## 7. Testing and measurement

FGX testing rules apply: small tests aimed at what changed, every check with
a positive control that must go red, and nothing added to the gate without
something coming out (`gate_budget.py`).

Host-side:
- `fgx_ld`: import tables, prebind checksum, fit rule (`ac` as the known-bad
  case), shadowing warning (`ul` must trigger it), no new segment kinds.
- `fgx_gc`: the reachability bitmap equals the members a program calls; a
  member a known program does not use must be absent.
- libc.so build: every export resolves; the section 4 boundary holds
  (`logwtmp` absent, resolver and `llong` present, `double` absent); no
  `PILE_CALL` remains.

On the machine (probes, not gate):
- Heap: `sbrktest`/`heapkill` assert the loader-set ceiling.
- Fork isolation: a child changes `errno` and writes through `stdout`'s
  buffer; the parent sees neither.  Control: a build without fork's second
  range must fail it.
- Binding: `ldd /bin/ls` prints the libc it bound; an older-minor program
  runs; a newer-minor program warns; a changed export table forces the name
  fallback and still runs.
- Boot resilience: with libc.so renamed away the static set boots to a
  single-user prompt and a dynamic exec prints its reason.
- The existing gate and suite stay green unchanged.

The proof, before and after, with this session's instruments:

| Measure | Today | Expected |
|---|---|---|
| Everyday session, pile reads per round | 376 KB | ~0 |
| User bank pool in use at idle | 49 / 56 | about one bank fewer per process |
| exec (`true`) | 90 ms | lower (no pile read or copy) |
| fork (`( : )`) | 80 ms | within +/- 3 ms |
| tcsh on disk | today | ~22 KB smaller (fcc runtime fold-in) |

Results are reported as measured, including anything worse.

## 8. Divergences from the sources, stated

| FGX | Source | Why |
|---|---|---|
| libc reaches its data absolute through the data bank register, not position-independent code with a GOT | SunOS relocates each library's GOT per process (`rtld.c:47-56`) | each process's data bank is already its private copy; a GOT would add a long-pointer load to every access |
| per-member blocks allocated at startup from a link-time bitmap | SunOS maps all library data, paying per touched page (`rtld.c:62`) | no MMU: whole-library data would be copied and zeroed per exec and fork |
| libc-internal calls cannot be interposed (`-Bsymbolic`) | SunOS resolves library references through a global lookup (`rtld.c:836-841`) | shared banks cannot be patched per process |
| libraries never unload before reboot | SunOS maps per process | no per-process room to track instances (the TCB is 64 B and full) |
| one resident libc per major; no `LD_LIBRARY_PATH` | SunOS searches paths per process | a single system-wide copy is the point |

## 9. Risks and open items

- Kernel bytes for `ldload` (5.5) must be found before sub-project 4 (binder,
  loader and boot).
- The per-segment fcc runtime set (which helpers stay near `JSR`) is chosen
  by measurement in sub-project 2.
- sh's `blok` allocator grows the break to the ceiling in ordinary use
  (`blok.c`); with per-member blocks fixed at startup this is safe, and the
  heap-limit probes cover it.
- Programs that write a libc export's storage directly (e.g. assigning
  `optind`) bind by name to the core copy; the relink in sub-project 5 finds
  any that depended on a private copy.
- K&R A.8.7 (static initialisation) was not checked against the text during
  the review; check it in sub-project 2's spec before changing how libc's
  initialised data is emitted.

## 10. Sources read

- `examples/SunOS-4.1.3/lang/rtld/rtld.c`, `cache_rtld.c`,
  `examples/SunOS-4.1.3/lang/ld/ld.c`, `examples/SunOS-4.1.3/bin/ldd.c`
- `examples/2.11BSD/usr/lib/` (library set; `libutil.a`, `libtermlib.a`,
  `libm.a` members), `examples/2.11BSD/usr/lib/libc/net`, `.../pdp/crt`
- `examples/4.3BSD-Reno/vax/machdep.c:144-154` (buffer sizing, for the later
  cache)
- `vendor/2.11BSD/usr/usr.sbin/ac/ac.c` (`TSIZE`)
- FGX: `src/kernel/far/loader.s`, `src/kernel/process.s`, `include/kernel.s`,
  `include/loader.s`, `toolchain/src/ld/fgx_ld.py`, `toolchain/lib/macros.s`,
  `toolchain/lib/libc_data.s`, `tools/ninja/gen.py`, `tools/stage_piles.py`,
  `src/modules/fpsim/fpsim.s`
- Adversarial review by Fable, 2026-09-28 (findings adopted: user-space
  binder, exec-time reachable allocation, double stays in fpsim, exported data
  is core, stated interposition rule, per-library registry, fcc runtime
  fold-in, PILE_CALL retirement, prebinding, FGX3/overlay handling, no new
  segment kinds, static set).
