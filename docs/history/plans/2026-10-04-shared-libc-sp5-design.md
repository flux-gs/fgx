# Shared libc, sub-project 5: the cut-over -- design

Status: approved in conversation 2026-10-04, decision by decision (section
2); revised the same day for an adversarial review of the written spec
(Fable), three Critical, four Important and one Minor finding, all
adopted; revised again for a second review of the revision (Fable), five
Important and three Minor findings, all adopted; revised after step 1
landed for three more of the maintainer's decisions, libfgx.so, libutil.so and
what runs before the libraries are resident (sections 2, 6.1-6.3), and
for a review of that revision (Fable), one Critical, three Important and
eight Minor findings, all adopted.  Parent: [`2026-09-28-shared-libc-design.md`](2026-09-28-shared-libc-design.md)
(the umbrella), whose section 6 item 5 this is; it builds on
[`2026-09-29-shared-libc-sp3-design.md`](2026-09-29-shared-libc-sp3-design.md)
(the formats and the dynamic link) and
[`2026-09-30-shared-libc-sp4-design.md`](2026-09-30-shared-libc-sp4-design.md)
(the binder, `ld.mod`, `ldload`, library reclaim).  Branch
`feat/shared-libc`, after main's shared text was merged into it
(2f40a0fa0).

## 1. Goal and how it is proven

Every program on the system that is not boot-critical runs as a dynamic
program against the one resident libc.so (and libtermlib.so and
libcurses.so where it needs them), and the per-program libc piles, the
libc overlay and everything that serves them are removed from the kernel,
the build and the toolchain.

It is proven by:

- `manyproc` going green.  It is red on this branch today, and stays red
  until this sub-project lands (the maintainer, 2026-10-03): libc.so's four
  resident banks sit on top of the per-program piles, and with 21 sleeps
  the 23rd exec gets ENOMEM because the Memory Manager has no whole bank
  left (FREE 158K, MAXBLK 63K; measured 2026-10-03).
- Exec time within 10% of today's (`exectime`, SP4's landing gate, kept).
- The full gate green.
- The binder tests of section 5.5, each with a control that must fail.
- Before and after, measured: free banks at idle, the boot's bank count,
  and the disk bytes the 164 pile files take.

## 2. Decisions (the maintainer, 2026-10-04)

| Question | Decided | Rejected, and why |
|---|---|---|
| apple/fgx#509, the binder's load buffer | folded into this spec, no separate prototype round; it is already fixed on the branch (section 5.4) | a prototype first: the prototype is 37efeeea5, already on the branch |
| Where a program's binder tables go | the tail of the code segment with the most room; if none has room, the link adds a code segment holding only the tables; a relocated 3-byte pointer in segment 0 tells crt0 where they are; the link fails only at the nine-segment cap | per-segment tables (a binder that walks several, a format change, no measured gain); always a separate table segment (a 64 KB bank for a few KB of tables) |
| How the binder behaves on shared text | every patch is repeatable -- a data site stores a final value computed from its original word, kept in the table -- and a bind record lets a later exec skip patching the shared code segments; everything per-process still runs every exec (section 5.2) | only the first process binds, others wait on a `TSB` flag (waiters must sleep, and a binder killed mid-bind is a hang unless its pid is tracked); the loader reports a text hit (far-bank bytes, the far bank has 19 free, and two loads can still race) |
| What stops a cached text's code pointing into a reclaimed library | the bind record keeps each library's banks, core base and export CRC as bound; the binder repatches the shared code when they no longer match (section 5.3; unreachable through today's reclaim order, kept as insurance) | a cached text holding a user on each library it is bound to, as 2.11BSD's text holds its inode (tty-bank code and a new path into `ld.mod`, and cached texts would keep their libraries resident, making reclaim a two-stage chain); SunOS 4.1.3's rtld, the upstream for shared libraries, pins nothing either: it binds every exec into a per-process GOT (`lang/rtld/rtld.c`, "relocate the _GOT_ for both user and shared libraries") |
| libfgx | its own shared library, `libfgx.so`, above libc as libtermlib is: libfgx calls into libc, libc never into libfgx; loaded on first use like libtermlib and libcurses (section 6.2) | a per-program library linked into each caller's code (the maintainer, 2026-09-28, carried by the umbrella and SP2, superseded): one copy of libfgx in every program that uses it |
| libutil (`login`, `logout`, `logwtmp`) | its own shared library, `libutil.so`, built and loaded as libfgx.so is (section 6.3) | linking it statically into its four users (init, login, fsck, telnetd): telnetd, which is to be dynamic, would carry its own copy, or join the static set for a library's sake |
| What runs before the libraries are resident | SunOS 4.1.3's shape: a small static set, `/etc/rc` makes the libraries resident before it runs anything else and stops if they cannot be, and every other program is dynamic; `test` and `echo` are static, standing in for the two builtins SunOS's sh has and FGX's lacks (section 6.1) | keeping static whatever rc happens to run before `ldload` (date, echo, test, adjkerntz, rm, chmod, cat, reboot today): the static set would follow rc's text, and every rc edit would have to check it; SunOS's `shcat` shell function in place of cat: FGX's sh is 2.11BSD's, which has neither `echo` nor `[` built in (`vendor/2.11BSD/usr/bin/sh/msg.c:132-155`, `[` commented out), so the function could not be written |

## 3. Starting state (feat/shared-libc 2f40a0fa0, measured 2026-10-04)

- **Nothing shipped is dynamic.**  Only the SP3/SP4 probes are (dynsodyn,
  dynsomisdyn, dyntrue, curssodyn, fitover, fitunder unbound; dynso,
  cursso, dyntruebound host-bound; `tools/dynso-fgx2/build_dynso.sh`).
  Of the 192 tools in `tools/ninja/manifest.json`, 188 are
  pile-by-reference (`tools/ninja/gen.py:681-682` rewrites `LIBC` to
  `LIBCREF` unless the name is in `PILE_CARRIES_OWN`, `gen.py:176`) and
  four (init, getty, login, fsck) carry their own pile; sh, tcsh and
  elvis carry their own through their own link scripts; five use the libc
  overlay (syslogd, cron, ntp, ntpd, crontab).  `tools/fas` links by
  reference outside the manifest (`tools/ninja/fasfgx.sh:53-56`).
- **The dynamic link handles one code segment.**  `fgx_dyn.py` refuses a
  segment 0 over 64 KB (`toolchain/src/ld/fgx_dyn.py:247-249`) and a
  segment 0 with no room for the tables (`:282-285`), both naming this
  sub-project.  So tcsh, sh, elvis, frotz, fsck, ntpd and the tools that
  link termlib, curses or util cannot link dynamically today.
- **Table sizes**, estimated over the 111 FGX images under `disk_src/bin`,
  `sbin`, `usr` and `libexec` that carry a libc segment, from their
  relocations (each reference into the libc segment becomes an import
  site; a record costs 16 bytes plus its name, a site 3): 109 programs'
  tables fit segment 0's free room (median 348 bytes); tcsh (837
  call/pointer sites, 86 records, 615 bytes free in segment 0, 11,152 in
  its emptiest code segment) and vi (1,214 free, 42,621) fit another code
  segment.  Data sites are not in that count: a reference to libc's data
  is a plain 16-bit address in today's images, with no relocation.  The
  probes' real tables put them at 18% (dynsodyn, 13 against 72) to 160%
  (curssodyn, 27 against 17) of the call sites, so tcsh's tables are
  about 6-9 KB.
- **Bytes free** after the merge: core 1,163, far 19, tty 969.
- **Shared text records the pile.**  `src/kernel/tty/text.s` keeps a
  `TX_PILE` byte per text and `_Tx_PileAdj`; `KTTY_TEXT_REG` takes eight
  text banks and then the pile bank.
- **A text hit skips the shared segments' loads and relocs**
  (`src/kernel/far/loader.s:1303-1307`, `:1458-1462`): a code segment's
  long-pointer cells keep the values the first load gave them.
- **Libraries are reclaimed.**  `hook_reclaim` (`src/modules/ld/ld.s:897`)
  frees the banks of a loaded library row with no users and no pin.
  `disk_src/etc/ld.so.conf` lists libfgx (step 2, section 6.2), which
  ldload makes resident and pinned at boot; libtermlib, libcurses and
  libutil load on first use and are reclaimable once their last user
  exits.  (The umbrella's "libraries never unload before reboot", its
  section 8, is superseded by SP4.)
- **sh, tcsh and vi are FGX2**; every manifest tool is already FGX3
  (`gen.py:546`).  FGX3 is FGX2's layout with the `FGX3` magic and an ABI
  stamp at header byte 13 (`fgx_ld.py:111-122`).

## 4. The dynamic link, through the tool build

The build that lays out a program's segments (`materialize_links`, the
`tools/fgx2/manifest.json.in` template, `fgx_ld.py`) gains a dynamic mode,
so every program links dynamically the way it links today, however many
code segments it has.  What fgx_dyn does for one segment it does for all:

- The libraries' code exports are bound by fgx_ld into import tables
  (fgx_ld's `dynamic`/`imports` manifest fields, which fgx_dyn already
  drives, `fgx_dyn.py:253-259`).
- Data sites are found by difference, as fgx_dyn finds them: a second link
  with the libraries' data EQUs moved by `fgx_sites.DELTA`, compared site
  for site over every segment (`fgx_dyn.py:417-421`), including the data
  segment (an initialiser such as `FILE *f = stdout`, or a function
  pointer in initialised data, is a site there).
- The far fcc helpers are thunks to libc.so's far entries, and the
  program's data segment gets one reachability bitmap per library, as
  fgx_dyn lays them out (`fgx_dyn.py:63-98, 174-205`).
- The fit check (`fit_error`) runs as it does for fgx_dyn.

The table format changes (sections 4.1, 5.1, 5.2), so whatever else
happens to fgx_dyn its table emission changes in step 1, and so do
`toolchain/src/ld/fgx_imports.py` and the host binder
`toolchain/src/ld/fgx_bind.py`, which unpacks today's 3-byte sites
(`fgx_bind.py:243`) and finds the tables at segment 0's tail; dynso, cursso
and dyntruebound are host-bound through it, and the `--digest` test
compares it with `LD_BIND_DIGEST`.  Whether fgx_dyn then becomes a thin
front end to the tool build's mode for the probes' links is decided by the
plan, by what is less code.

### 4.1 Where the tables go

- The tables (the segment count and cells, IMPS's length, IMPS, and the
  bind record of section 5.2) are appended to the code segment with the
  most free room.
- If no code segment has room, the link adds a code segment holding only
  the tables.  It costs a bank, once per program rather than per process,
  because the code banks are shared text.  No program on the system needs
  it today (section 3).
- Segment 0 carries a 3-byte cell, a word and a bank byte the loader
  relocates (the `FGX2_LONG_PTR` shape, `fgx_ld.py:299-342, 575`),
  pointing at the tables.  crt0_dyn reads it instead of `_dyn_loc`'s
  immediate operand, which could only give an offset into crt0's own bank.
  It names a code segment, so the value the first load gives it is right
  for every sharer.
- The link fails only if the program already has nine segments and none
  has room.  The LIBC segment kind retires (section 7), so the ninth slot
  is free for code; tcsh, the largest program, has eight.

## 5. The binder

### 5.1 Repeatable patches

Today `_ld_patch` STORES a call or pointer site's value but ADDS a delta
to a data site (`toolchain/lib/ld_bind_asm.s:56-72`), and the binder runs
in every new process (`toolchain/lib/libc_c/ld_bind.c:383-385`).  With
shared text a second process runs code banks the first already patched,
so a data site would take the delta twice.  The delta is nonzero for an
unbound program whenever a library sits at banks other than the ones its
link assumed (`ld_bind.c:360-371`); on this machine it happens to be zero,
which is why dynsodyn run twice in one boot passes today.

So a data site's entry in IMPS carries its original word (2 bytes more per
data site), and the binder stores `original + delta`.  That holds for the
prebound delta (`ld_bind.c:360-361`), the by-name delta (`:372`) and the
block table's address (`:375`); call and pointer sites are stores already
(`ld_bind_asm.s:58-64`).  Every patch then writes the same bytes however
many times it runs.

**`_lib_copy`** (`toolchain/lib/crt0_lib.s:60-92`) writes MVN's two bank
bytes into itself, in segment 0, on every call -- different bytes per
process, in what is now shared text.  Its comment ("Segment 0's only
sharers are fork children") predates the shared-text merge.  The MVN moves
into the per-process data bank:

- A 4-byte cell, `MVN $00,$00` then `RTL`, is initialised data in the data
  segment at $0100 or above (in `fcc_runtime_data.s`, which every link
  mode PUTs), so it is in the file image and reloaded by every exec, and
  a fork child gets its own copy with the data bank.  Not in the $0000
  pad: a label below $0100 assembles as a direct-page operand
  (`tools/fgx2/seg1.link.s.in`, `fgx_dyn.py:229-230`).
- `_lib_copy` stores the two bank bytes into the cell through DBR, which
  is the process's data bank, and reaches it by a JSL built at run time
  from DBR (push the return, push the data bank and the cell's address
  less one, `RTL`), as crt0_dyn builds its call into the binder.  It is
  not an `FGX2_FARCALL`: fgx_ld refuses a JSL whose target is not a CODE
  segment (`fgx_ld.py:299-302`), and a relocated bank byte in shared
  segment 0 would keep the first process's data bank.
- The copier then no longer depends on nothing preempting between its
  stores and the MVN, and the comment is corrected.

A byte loop (`LDA [p],Y` / `STA [q],Y`) would need no self-modifying code at
all, at about 3 ms per exec more over libc's 2.4 KB core; the MVN is kept
for the exec-time gate.

### 5.2 What a later exec skips, and what it never skips

The **bind record** is a word and, per library, the banks, core base and
export CRC the code was bound against, in the tables; zero in the file.
The CRC is there because a by-name patch depends on the export table
(`at`, `sg`, `abase`, `ld_bind.c:363-372`), not only on where the library
sits.

Skipped when the record matches (section 5.3): the `_ld_patch` calls for
**code-segment** sites, and nothing else.  The walk over the import
records still runs, because it sets `L->blktab` (`ld_bind.c:374-375`),
which the fit check reads (`:431-441`), and it runs `lb_find` for by-name
imports (`:363-366`).

Never skipped, every exec, because each is per process:

- ACQUIRE of each library through `ld_need` (`ld_bind.c:311`), which
  counts this process as a user -- what keeps the library from being
  reclaimed while the process runs (SP4 section 4);
- each non-libc core copied into this data bank, and its fixups
  (`ld_bind.c:411-416`);
- `HEAP_LIM` computed and stored, and the fit check (`ld_bind.c:402-452`);
- **data-segment** import sites, which are read fresh from the file on
  every exec; their bank is the binder's own data bank (`ld_bind.c:259`),
  never the data segment's cell in the tables -- that cell is relocated
  once, by the first load, and holds the first process's data bank for
  every later sharer (`fgx_dyn.py:287`, `loader.s:1458-1462`).  The tables
  carry the data segment's index (in the header word's high byte, or the
  data cell's pad byte, which the synthetic relocs of `with_tables` do not
  touch), and `ld_bind` sets that `seg[]` entry's bank from its own data
  bank before the site loop; today `seg[]` is filled only from the cells
  (`ld_bind.c:281-284`) and `_ld_patch` takes every site's bank from it
  (`ld_bind_asm.s:31-44`);
- `LD_TRACE_LOADED_OBJECTS` and `LD_BIND_DIGEST`, which ignore the record,
  so `ldd` reports a program that has run before, and the trace says
  whether the code was patched or skipped (`text bound` and the count of
  sites skipped) -- the observable for section 5.5's skip test.

**The record's protocol.**  Model A never preempts kernel code and the
dispatcher preempts only between syscalls (`src/kernel/toolbox.s:448-453`),
and the site loop makes no syscall after `ld_need`, so a bind's patches and
its record are written with no other process running in between: no
process sees a half-written record, and two processes never patch one text
at the same time.  The one exit from the middle of the loop is `lb_die`
(`ld_bind.c:366, 381`), which would leave the code half-repatched under the
old record; so a repatch zeroes the record word first and writes the record
last.  A text reclaimed and reloaded comes from the file with the record
clear.

### 5.3 A library reclaimed under a cached text

A cached text (no process running it) keeps the bank bytes its code was
patched with.  If a library it uses is reclaimed (section 3) and later
loaded into other banks, those bytes point into banks given back.  The
binder compares the record's banks, core base and CRC for each library
with the rows it has just ACQUIREd; on any difference it patches the code
segments again (repeatable, section 5.1) and writes a new record.

That is safe because a library is reclaimable only with no users, and
every process that could be running a text bound to it holds a user: exec
takes them after its commit (`process.s:3158`), fork and vfork copy them
past every failure path (`process.s:1182-1192`, `src/modules/ld/ld.s:850-870`),
and exit drops them.  Nobody is executing the stale code when a later exec
repatches it.  Section 7 retires `TX_PILE`, which guarded the same hazard
for piles; this record is its replacement.

**Unreachable today, kept as insurance.**  Bank_Alloc's dry-pool chain
frees one unused text per call and rescans (`src/kernel/bank.s:152`,
`_Tx_Reclaim` in `src/kernel/tty/text.s:140-185`), and reaches a library
(`KTTY_LD_RECLAIM`, `bank.s:233`) only when no unused text is left; `ldctl`
has no unload (`toolchain/include/sys/ldctl.h`).  So a library is reclaimed
only after every cached text has gone, and a cached text bound to a
reclaimed library cannot exist through any path the kernel has.  The record
costs a few bytes per program and guards that ordering if it ever changes;
its test is a host unit test, because no machine test can reach the
mismatch (section 5.5).

### 5.4 The load buffer (apple/fgx#509), as built

37efeeea5, on the branch before 891af5c36: nothing is read into the
program's data bank past the binder's 294-byte `struct ld_work`.  `/lib`
is read through a descriptor in 96-byte windows, as 2.11BSD's readdir(3)
does; a library's banks are granted first (`ld.mod` GRANT with a core size
of 0 means banks alone) and its trailer is read by readv(2) into the top of
its own last bank; relocs are read 24 at a time.  Cores are still placed
in the order the libraries need each other.  `ldfit` passes on 2f40a0fa0.
#509 closes when this branch merges.

### 5.5 Tests

Each prints the value it checks, so a failure is a wrong value on screen
rather than a guess.

- **Repeat bind with a nonzero delta:** a dynamic program linked against a
  library base the machine will not give it prints a libc data value (one
  reached through a code-segment data site) and is run twice in one boot;
  the second exec hits the text table and must print the same value.
  Control: disable the record check and restore the ADD in `_ld_patch`;
  the second run prints the wrong value.
- **A data-segment site:** the same program also prints through a pointer
  initialised in its data (`FILE *f = stdout`-shaped), twice.  Control:
  take the data bank from the tables' cell; the second run's write lands
  in the first process's bank and the value is wrong.
- **The skip:** under `LD_TRACE_LOADED_OBJECTS` the second exec of a cached
  text reports `text bound` with its skipped-site count, the first exec
  does not.  Control: zero the record word in the binder before the
  compare; the second exec reports patching.
- **The record's compare and repatch** (section 5.3), as a host unit test
  in the style of the existing `test_dyn.py` tests, since no machine path
  reaches a mismatch: a bound image, a library moved (banks, base, CRC each
  in turn), and the repatched bytes equal a fresh bind's.  Control: skip
  the compare; the bytes differ.
- **Tables in an added segment:** a synthetic program whose code segments
  are all full links with the extra segment and runs (no real program
  needs it, so the link path and crt0's pointer read have no other test).
- **termlib first use** under the new link, **fork** of a dynamic program
  (the child shares the bound text, `KTTY_TEXT_FORK`), and **exec from a
  dynamic tcsh** (every exec after step 3 of section 8).
- `ldfit` and the SP4 probes stay green.

Like ldfit, exectime and the SP4 probes, none of these joins `GATE_TESTS`
(`tools/gate.sh:633-639`, held to its seconds budget by
`tools/gate_budget.py`): they are probes run at their step and before the
merge.

## 6. Relinking the system

- **Dynamic:** every program except the static set below, including tcsh,
  vi (elvis), the five overlay users and `tools/fas`.
- **Static:** the umbrella's set (section 5.6), init, getty, login, fsck,
  sh, mount and ifconfig; the two programs that run before the libraries
  are resident, modload and ldload; `test` (and its `[` link) and `echo`;
  and SunOS's disaster-recovery set as far as FGX ships it, hostname,
  mv, tar and ln (all section 6.1).  They link statically against libc,
  and against libfgx and libutil where they use them (fgx_static and
  crt0_lib, as `ldload` and `libcso` are today, `gen.py:1528-1561`), not
  through a pile.  fgx_static takes only `--code`, `--data` and `--out`
  today (`toolchain/src/ld/fgx_static.py:309-315`); it gains the
  libraries' inputs at step 2, because init, getty, login and ifconfig
  use libfgx and init and login use libutil.
- **FGX3:** sh, tcsh and vi move from FGX2 (`"format":"FGX3"` in their
  link scripts); sh stays static.
- **`ac`** keeps `TSIZE 6242`.  Upstream's commented-out `TSIZE 1000`, which
  the umbrella planned to take, is not a fix: 2.11BSD's `ac.c`
  (`vendor/2.11BSD/usr/usr.sbin/ac/ac.c:136-161`, the "correction
  contributed by Phyllis Kantar @ Rand-unix") indexes the table by
  `ut_line[3] * 79 + ut_line[4]`, and the lines FGX writes (init.c:466
  from `/etc/ttys`: console, ttyv1-3, ttyp0-1; login.c:226) index from
  5,056 (`ttyp0`) to 5,533 (`ttyv3`), so under 1000 they would all be
  `ac: Bad tty name`.  Whether ac
  fits as a dynamic program is measured at step 3: its shipped data
  segment is 60,529 bytes but includes the pile's libc data, which leaves
  under a dynamic link, against a ceiling of libc's core base ($F6A3 for
  libc.so.1.0) less the blocks it reaches and `struct ld_work`.  If its
  own data fits, it goes dynamic; if not, it joins the static set.  Its
  test's description (`tools/mame_test/tests/ac.json`) claims three FGX
  deltas where `src/userland/ac/ac.c:18` declares one, and is corrected,
  as is `ac.c:28-29`'s claim that the lines are "console, ttyp0, ttyp1".

### 6.1 What runs before the libraries are resident

A dynamic program started before libc.so is resident prints `ld.so:
libc.so.1 not loaded` and exits 1 (`crt0_dyn.s:171-179`).  Today `/etc/rc`
runs `[`, echo, date, fsck, reboot, mount, adjkerntz, rm, chmod, cat and
modload before `/sbin/ldload` (`disk_src/etc/rc.in:26-144`).  init does
not look at rc's exit status (`src/userland/init/init.c:702-705`); it
then starts `/bin/sh` on the console (`disk_src/etc/ttys:2`) and
getty on ttyv1-3, and getty execs login.

SunOS 4.1.3 has no load step: ld.so maps the libraries from `/usr/lib`
at each exec, so they are reachable once `/usr` is mounted.  It answers
the same question like this:

- **A small static set.**  Every `-Bstatic` outside the kernel,
  `lang`, and the install and upgrade media (`usr.etc/suninstall`,
  `sundist`, `release`): `etc/Makefile:32` (`STD = init intr`, linked
  `-Bstatic` at `:94`), `:182` (mount), `bin/sh/Makefile:20`,
  `etc/fsck/Makefile:15`, `etc/ifconfig/Makefile:8`,
  `etc/restore/Makefile:17`, `usr.etc/hostconfig/Makefile:8`,
  `ucb/Makefile:96-97` (rcp), `usr.bin/Makefile:98` (`STATIC= ln`), and
  `bin/Makefile:79-81`: "Programs built "static" for disaster recovery
  and startup", `STATIC= bar hostname mv tar`.  Everything else, cat,
  date, chmod, rm and reboot (`etc/Makefile:28-30`, `STD_SHRD`) included,
  is dynamic.
- **Its sh has `test` and `echo` built in** (`bin/sh/Makefile:16` lists
  `test.o` and `echo.o`), so rc.boot's conditions and messages never
  depend on a library.
- **The libraries become reachable as early as they can.**
  `etc/files/rc.boot` runs only static programs and shell builtins until
  `intr mount -n -r /usr` (`:130`), and mounts `/usr` read-only BEFORE
  fsck checks it (`:140-145`), so reboot, at the end of the fsck case
  (`:187-190`), already runs with the libraries reachable.  Where it
  wants cat before that point it uses `shcat` (`:27-36`), a `read`/`echo`
  loop, unset once it is done (`:113`).  (The one exception is upstream's:
  `cat` at `:110`, inside the `/sbin/route` guard.)

FGX takes the same shape:

- **`ldload` runs first, and rc stops if it fails.**  The first two
  commands in `rc.in`, ahead of the autoboot block, become `/sbin/modload
  ld` and `/sbin/ldload`, and rc stops (`case $? in 2) exit 1;; esac`, a sh
  builtin) when ldload exits 2, which it does when libc is not resident; it
  exits 1 when only a library `/etc/ld.so.conf` lists failed, which does not
  stop the boot, both to `/dev/console`.  modload
  opens `/lib/modules/*` read-only (`modload.c:74`) and ldload reads
  `/etc/ld.so.conf` and the library (`ldload.c:78,110`), so both run on
  the root as the kernel mounts it, read-only (`rc.in:13-15`).  That is
  SunOS's `mount -r /usr` before fsck: fsck checks a filesystem that
  libraries were loaded from, and nothing has written to it.  If ldload
  fails, rc exits with the root still read-only and unchecked: without
  the `exit`, every later dynamic command would fail, and the static
  `mount -u -w /` would still make an unchecked root writable.  init
  ignores the status and starts the console's `/bin/sh`, which is the
  recovery shell; logins on ttyv1-3 fail, because tcsh is dynamic.
- **`test` and `echo` are static.**  They stand in for the builtins
  SunOS's sh has and FGX's does not, so rc, `/etc/netstart` and any
  script's conditions and messages never depend on libc.so being
  resident.  Every other program rc runs after `ldload` is dynamic, and
  no `shcat` is needed (section 2).
- **Dynamic programs now run before fpsim loads**, between `ldload` and
  the main modload line.  That is safe: ld.mod, ldload and the binder use
  no floating point (`src/modules/ld/ld.s` names fpsim only in a comment,
  `:104`; `tools/ldload-fgx2/ldload.s` and `ld_bind.c` not at all), and
  date, echo and `[` already run before fpsim today.
- **`ld` leaves the main modload line**, which loads the rest in
  modload.conf's order as before.  modload.conf moves `ld` from
  second-to-last (`disk_src/etc/modload.conf:28`) to first, and
  `tools/check_modload_lists.py`, which today requires exactly one
  modload line (`:56`, `len(hits) != 1`, with the complaint at `:79-81`),
  reads rc's modload lines in order as one list.  Its self-test case "two
  modload invocations" (`:117,128`), which must disagree today, must
  agree after, and `rc.in`'s comment block at `:126-137` ("ONE PROCESS,
  NOT SIX", "THE LIST IS /etc/modload.conf's") is reworded.  A module's
  placement does not depend on its load order (`tools/gen_modplace.py:51`,
  "the order modules are placed in, not the order they are loaded"), and
  the kernel latches the shared module bank from whichever module lands
  first (`src/kernel/modload.s:96-98`), so ld.mod lands where it does
  today; it registers no device (`include/devnodes.s`).  This costs one
  more process on the path to the first prompt.
- **The static set** is section 6's: what init starts (sh for rc and the
  console, getty, and login, which getty execs); what rc runs before
  `ldload` (modload, ldload); the two builtins sh lacks (test, echo); the
  programs SunOS also keeps static, fsck, mount and ifconfig; and
  SunOS's recovery set as far as FGX ships it: hostname, mv, tar and ln.
  bar, restore, rcp and hostconfig are not FGX programs.  With libc.so
  unloadable the console shell has sh's builtins, test, echo, mount (to
  make the root writable), fsck, modload, ldload, mv (which copies across
  filesystems in-process, `mv.c:14-17`), tar (to carry a replacement in),
  ln, hostname and ifconfig: enough to check the root, make it writable
  and put back a good `/lib/libc.so.1.0`, which is a plain file, so ln is
  a convenience rather than a need.  It has no cat, ls, cp or editor.
- **`reboot` stays dynamic**, as SunOS's does.  On fsck's exit 4
  (`rc.in:44`) it binds against a libc.so loaded before fsck repaired the
  root, as SunOS's reboot (`rc.boot:190`) runs on a `/usr` mounted before
  its check (section 9).

### 6.2 libfgx.so

- libfgx becomes `lib/libfgx.so.1.0`, built as libtermlib.so and
  libcurses.so are (fcc `--libso` and fgx_libso, whose LIBS entry for
  libtermlib, with its data files and `below=["libc"]`, is the precedent,
  `fgx_libso.py:426-447`), with one dependency, libc.  libc makes no calls
  into libfgx (`system.c:65` forks; libc.s and libc_so.s name no `spawn*`),
  so the layering stays libfgx -> libc, with no cycle.  `libfgx.c:7-9`'s
  header, which says libc calls in ("system->spawnv"), is corrected.  No
  libfgx export collides with a libc export.
- **libfgx stops reaching into libc's private data.**  libfgx's spawn
  family passes `environ`, a libc.so data export, as 2.11BSD's `execv`
  does (`mov	_environ,-(sp)	/ pass default environment,`,
  `pdp/sys/execv.s`), so `sys_envp`, `__fgx_build_envp` and the
  `args_env` reach go, and so does the unused `_libc_lstrBufA`
  declaration.
- It is listed in `/etc/ld.so.conf`, so ldload makes it resident at boot,
  right after libc.  Measured at step 2: the boot's own daemons use it
  (dhclient, which `/etc/netstart` runs, and inetd), so it is resident from
  the first seconds of every boot either way.  Loaded on first use it went
  wherever the first daemon happened to put it; listed, its core is always
  directly below libc's, which is where fgx_libso assembles it, and every
  library loaded after it on first use lands at its assembled base when
  nothing outside the stacking order was loaded before it (a first use of
  libutil before termlib displaces termlib; binding is by name and correct
  either way).
  The assembled stacking is libc, libfgx, libtermlib, libcurses, libutil,
  and the host models (fgx_bind's placement, fgx_lddigest) place the boot
  set, libc and the libraries `/etc/ld.so.conf` lists, first.
- A dynamic program that uses libfgx imports it as it imports libtermlib
  (fgx_ld's `dynamic`/`imports` manifest fields).  A static-set program
  that uses libfgx links it statically, as it links libc.
- libfgx's GC pruning into each program's pile retires with the piles
  (section 7).

### 6.3 libutil.so

- libutil (`toolchain/lib/libutil_c/`: `login`, `logout` and `logwtmp`,
  from 4.3BSD-Reno and 2.11BSD's `libutil`) becomes `lib/libutil.so.1.0`,
  built and loaded as libfgx.so is: one dependency, libc (its members
  include only libc's headers), loaded on first use, not pinned.
- Its users are init and login, which link it statically (section 6),
  and telnetd, which imports it (fsck does not use it).  A static link
  compiles libutil's and libfgx's sources as a program's own (with
  `--sections`) and fgx_static keeps the functions the program reaches;
  `util.fgxa` serves only pile links and retires with them (section 7).

## 7. What retires

Removed only once nothing staged uses it, in their own commits:

- **Far bank** (`src/kernel/far/loader.s`): the pile state and path
  (`:44-95`; `_ldDataSegIdx` and `_ldCurSeg` above it stay),
  `_Ld_PileOpen`/`Close`/`HexDigits`/`Nib` (`:287-435`), the
  LIBC/LIBCREF registry arm (`:1095-1395`), the pile handling in text
  registration (`:1515-1545`, `:1576-1595`) and in `_FreeExtras`
  (`:1863-1920`); `PILE_PATH_*` and `SEG_KIND_LIBCREF` in
  `include/loader.s`.  About 1 KB, in the bank with 19 bytes free.
- **Core bank:** `_libcShTab`, `_libcShLast`, `_ldPileCorePath` (161 bytes
  of data, `include/memmap.s`); `_LibcSh_Slot`, `_LibcSh_Reclaim` and the
  reference-count sites in `process.s`, `task.s` and `main.s` (about
  0.2 KB of code); `TCB_LibcBank`.  `_FarSh_TextReclaim` goes with the
  registry, its only caller.
- **Tty bank:** `TX_PILE`, `_Tx_PileAdj` and its calls in `text.s`, and the
  ninth byte of `KTTY_TEXT_REG`'s bank list (replaced by section 5.3).
- **Build:** libfgx's pile pruning (`libfgx.s` in `LIBC_SEED_ROOTS`,
  `gen.py:178`; the `libfgx.gc.s` and `libfgx_data.gc.s` GC_PUTS,
  `:607-608`; `gc_code`/`gc_data`, `:2527-2530`);
  `tools/stage_piles.py` and its rule and its use in
  `tools/gate.sh`; `PILE_PREFIX`, `PILE_CARRIES_OWN` and the
  LIBCREF rewrite; the overlay rules; `tools/fgx2/seg2.link.s.in` and
  `segovl.link.s.in`; `fasfgx.sh`'s `--pile-dir`; the pile handling in
  `tools/helper_census.py`, `check_libc_link_sites.py`,
  `libc_so_check.py` and `dp_sleep_ranges.py`; `util.fgxa` and its
  Makefile target (`toolchain/Makefile:158-159`), the only `.fgxa`
  archive this retires -- the other five stay, since the toolchain's
  own tests use them; and the 164 `/lib/libc.so.<key>` files.
- **Toolchain:** fgx_ld's LIBC and LIBCREF segment kinds, `write_pile`,
  `--pile-dir` and the "ninth segment must be LIBC" rule; `fgx_gc
  --overlay` and its section of `docs/fgx2-linker.md`; `crt0_far.s`, the
  pile path's crt0, once what PUTs or names it -- 42 toolchain fixtures'
  `toolchain/tests/M*/_seg0.link.s`, 42 `_seg1.link.s`, one per M-dir,
  `toolchain/tests/run.sh`, `multibank/gen_sweep_link.py` and the bench
  corpus -- is moved to crt0_lib and fgx_static and the goldens
  regenerated.  Step 4 moved them (the fixture link is
  `toolchain/tests/fixture_link.py`); the goldens are fcc's output and did
  not move -- a REGEN run over the new link rewrote none.
- **Tests:** `textchurn.json` and `textreclaim.json` read `_libcShTab`
  through `memory_regions` (`tools/mame_test/textchurn_check.py:13`); their
  checks lose the pile column.  `manyproc.json`'s description ("plus a
  libc bank shared by identical binaries") is corrected.

**Kept:**

- fcc's `--pile`, which kernel-bank C uses (`gen.py:1209, 1215`).
- `tools/check_libc_piles.py`, its rule and its targets in
  `toolchain/Makefile`: not pile-only despite its name, it is the
  freshness guard for `libc_so.s`, `libfgx.s`, `libcurses.s`,
  `libtermlib.s` and the `.fgxa` archives against their sources and fcc.
- The `PILE_CALL` macro (`toolchain/lib/macros.s:738-749`): a same-bank
  JSL-shaped call that fpsim (`src/modules/fpsim/fpsim.s`, 11 sites) and
  `toolchain/lib/libdouble/d_glue.s` (12) use; it is not the pile path.
- Bank_Alloc's dry-pool chain: `KTTY_TEXT_RECLAIM` (`src/kernel/bank.s:152`)
  stays, and `KTTY_LD_RECLAIM`, reached today only from
  `_LibcSh_Reclaim`'s tail (`bank.s:233`), moves into the chain in its
  place, so a dry pool still frees an unused text first and then an
  unused library.

## 8. Order of work

1. **The build mode and the binder** (sections 4 and 5), proven on a
   handful of manifest tools of different shapes (one segment, several,
   one needing termlib, one with a data-segment site) while everything
   else stays on piles.  The table format changes land in fgx_dyn,
   `fgx_imports.py` and `fgx_bind.py` together (section 4), and the
   section 5.5 tests land here.
2. **The boot order and libfgx.so first** (sections 6.1 and 6.2):
   `modload ld` and `ldload` move to the top of `rc.in`, modload.conf and
   its checker and `rc.in`'s comment follow, and `ldload || exit 1`;
   libfgx's own staging cells (6.2); `lib/libfgx.so.1.0` and
   `lib/libutil.so.1.0` built and staged; fgx_static taking libfgx and
   libutil.  Then **relink the manifest tools**, the overlay users and
   fas, with the static set of section 6 (except sh, step 3) moved to
   fgx_static.
3. **tcsh, vi and sh**: FGX3, tcsh and vi dynamic, sh static and on
   fgx_static; ac measured (section 6).
4. **Move the toolchain fixtures off `crt0_far.s`**, goldens regenerated.
   (done: plan `2026-10-05-shared-libc-sp5-step4-plan.md`.)
5. **Retire the pile path** (section 7), one area per commit, each after a
   check that nothing staged still carries a LIBC or LIBCREF segment.
6. **Measure** (section 1) and update ROADMAP.

The branch boots at the end of every step.  `manyproc` is expected red
until step 5.

## 9. Divergences, stated

- The binder patches shared code in place; SunOS's rtld relocates a
  per-process GOT and PLT instead and never writes the program's text
  (umbrella, section 8).  Here the patched values are system-wide: the
  repeatable patches, the bind record's bank check and the per-process
  user count make that safe.
- Whatever ac's measurement decides (section 6) is recorded in the commit
  that makes it.
- `/etc/rc` has no `shcat`, because 2.11BSD's sh has no `echo` or `[`
  builtin; it loads the libraries before its first test instead
  (section 6.1), and keeps `test` and `echo` static in their place.
  SunOS's bar, restore, rcp and hostconfig are not in the static set: FGX
  does not ship them.
- reboot is dynamic and, on fsck's exit 4, runs against a libc.so loaded
  before fsck repaired the root.  SunOS accepts the same (reboot is in
  `STD_SHRD`, `etc/Makefile:28-30`; `rc.boot:190`).
- libfgx.so has no SunOS counterpart; it is FGX's own library, and the
  layering rule (libfgx -> libc, never back) is what makes it a library
  rather than part of libc.  SunOS has no shared libutil either; FGX's is
  a shared library so that telnetd can be dynamic.
- Section 4.1 says the ninth slot is free for code once the LIBC segment
  kind retires.  `FGX2_MAX_SEGS` and fgx_ld's cap stay at 8 instead: a
  ninth code segment needs a ninth `TCB_BankList` row, and without the
  LIBC-only rule nothing would stop a ninth segment that leaks its bank
  at exit.  tcsh, the largest program, has eight, so the cost is a TCB
  restructure if a ninth is ever needed.

## 10. Open items

- Whether fgx_dyn stays for the probes or becomes a front end to the tool
  build's dynamic mode (section 4) -- decided by the plan.
- The exact data-site count per program is known only once the tool build
  links them; section 3's 6-9 KB for tcsh is an estimate.

## 11. Sources read

- `vendor/2.11BSD/usr/usr.sbin/ac/ac.c` (TSIZE, the tty index);
  `vendor/2.11BSD/usr/bin/sh/msg.c` (the builtin table);
  `examples/SunOS-4.1.3/etc/files/rc.boot`, `etc/Makefile`,
  `bin/Makefile`, `bin/sh/Makefile`, `etc/fsck/Makefile`,
  `etc/ifconfig/Makefile` (the static set and the boot order);
  `disk_src/etc/rc.in`, `tools/check_modload_lists.py`,
  `tools/gen_modplace.py` (FGX's boot order);
  `examples/SunOS-4.1.3/lang/rtld/rtld.c` (what rtld does per exec).
- `toolchain/lib/libc_c/ld_bind.c`, `toolchain/lib/ld_bind_asm.s` (the
  patch kinds), `toolchain/lib/crt0_lib.s` (`_lib_copy`),
  `toolchain/src/ld/fgx_bind.py` (the host binder's site format),
  `toolchain/src/ld/fgx_dyn.py` (the one-segment limits, `with_tables`,
  data sites over every segment).
- `src/modules/ld/ld.s` (`hook_reclaim`), `src/kernel/far/loader.s` (what
  a text hit skips), `src/kernel/bank.s` (the dry-pool chain).
- Commit 37efeeea5 and apple/fgx#509.
- The shipped images in `disk_src` and the probes' tables in
  `disk_src/testbin` (section 3's census).
- The adversarial review (Fable, 2026-10-04) and each code reference it
  cited.
