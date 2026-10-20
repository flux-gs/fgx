# Shared libc, sub-project 4: the binder, loader and boot -- design

Status: approved in conversation 2026-09-30, section by section, after an
adversarial review of the architecture and data flow for performance and
scalability (Fable); revised the same day for a second adversarial review
of the written spec (Fable), sixteen findings adopted.  Parent: [`2026-09-28-shared-libc-design.md`](2026-09-28-shared-libc-design.md)
(the umbrella), whose section 6 item 4 this is; it builds on
[`2026-09-29-shared-libc-sp3-design.md`](2026-09-29-shared-libc-sp3-design.md)
(the formats, the dynamic link, the host binder).  Branch `feat/shared-libc`.

## 1. Goal and how it is proven

Dynamic programs run on the machine with each shared library resident
**once** and shared by every process that uses it, instead of the per-image
copies sub-project 3's host binder (`toolchain/src/ld/fgx_bind.py`) wrote.
A library is loaded when a program that needs it first runs (SunOS,
Solaris and Linux alike), counted per process, kept cached when no process
uses it, and reclaimed when the bank pool needs the banks.  libc is
resident from boot; `/etc/ld.so.conf` makes others resident from boot.

Proven in headless MAME (section 9): `dynso` and `cursso` as dynamic
programs with no host binding, two processes sharing libc's banks, a
first-use load, two first users racing, a first user killed mid-load, a
reclaim, and the error paths -- each with a control that must fail -- and
the machine binder's patched bytes equal to fgx_bind's for the same bases.
Exec time is a landing gate: a small dynamic tool's `exec` within 10% of
today's.

Nothing shipped changes bytes -- checked, not assumed: moving `_lib_init`'s
copy (5.4) changes `libc_init.c`, which is also in the static pile, so each
step compares the shipped binaries before and after.  The cut-over is
sub-project 5.

## 2. Decisions (the maintainer, 2026-09-30)

| Question | Decided | Rejected, and why |
|---|---|---|
| Who owns library banks for the boot | a kernel module, `ld.mod`, holding the registry | a resident `ldload` process (kill -9 would free banks in use); the registry in the kernel proper |
| Where the binder reads a program's import table | in the program's image, loaded with it (section 5.1) | the data segment for the process's life; re-reading the file (no path: `argv[0]` is a convention, `process.s:34`) |
| Where the binder's code lives | libc.so, in C, with asm for its hot loops | 65816 in `ld.mod`; a binder in every program's crt0 |
| When libraries load | libc at boot; **every** other library on first use; `/etc/ld.so.conf` makes more resident at boot | every library at boot (not how SunOS, Solaris or Linux behave) |
| Where a library's core goes | stacked in load order below `HEAP_LIM`, fixed for the boot once loaded | a build-time core map (ties placement to builds); relocation on collision (two rules) |
| Prebinding | a matching export CRC binds code from the recorded values with no name looked up, and moves data by the core's base delta; names only when the CRC differs | prebound only when CRC and base both match (most first-use loads would bind by name) |
| Who arbitrates residency | the kernel, through `ld.mod` reached by a syscall (sleep/wakeup, per-process counts, reclaim) | user-space arbitration with polling and `kill(pid, 0)`; never unloading |

Kernel room is not a constraint on this design: the far bank, the tty bank
and modules are kernel banks, and more can be added (the maintainer, 2026-09-30).
Each kernel piece goes where it fits (section 6).

This supersedes, in the umbrella: 5.4's "`SYS_MODLOAD`-shaped call" and its
registry row (section 4 here); 5.6's "the kernel is not involved" for a
dynamic program with no libc (here `SYS_LDCTL` answers ENOSYS or "not
resident"); and section 8's "libraries never unload before reboot" (here
zero-user libraries are reclaimed).

## 3. Architecture

- **`ld.mod`** (a module, 65816, in the shared module bank): the registry,
  the per-process use table, and the services of `SYS_LDCTL`.  Kernel
  context, so it can sleep a waiter and see who is running.
- **`SYS_LDCTL`** (syscall 8, today a stub, `syscall.s:1009`): the kernel
  handler jumps through a cell `ld.mod` sets at init; until then it returns
  ENOSYS.
- **`lib/libc_c/ld_load.c`** (libc, C): reads a library file into granted
  banks and relocates it (section 5.2).  Used by the binder and by
  `/sbin/ldload`.
- **`lib/libc_c/ld_bind.c`** (libc, C) with **`lib/ld_bind_asm.s`** (libc,
  65816): the binder; the asm is its site-patching loop.  The copier every
  template copy uses is in each program's crt0, not in libc (section 5.4).
- **`/sbin/ldload`** (static, fgx_static): at boot, makes libc resident,
  then each library `/etc/ld.so.conf` lists.
- **`crt0_dyn.s`**: a dynamic program's crt0 -- the MVN copier stub (5.4),
  `SYS_LDCTL` to reach the binder, then `crt0_lib.s`'s path
  (`_libc_start`, `_crt0_inits`, `main`).
- **`fgx_dyn`**: places the program's tables, the segment-bank table and the
  locator (section 5.1).
- **`ldd`**: runs a program with `LD_TRACE_LOADED_OBJECTS` set, as SunOS's
  does (`examples/SunOS-4.1.3/bin/ldd.c`).
- **Kernel**: `SYS_LDCTL`'s entry cell, `KSVC_BANKGRANT`/`KSVC_BANKFREE`,
  exit, fork and exec hooks, a reclaim step, and the loader refusing a
  library file (section 6).
- **Unchanged**: fgx_bind stays the host reference; the pile registry and
  `TCB_LibcBank` stay until SP5.

## 4. `ld.mod`: the registry and its services

**A registry row**: library name, major, minor, export CRC, the banks, the
core base and size, where the core template, block templates and EXPT sit
(the last bank), the block table's row count, the binder's entry (libc's
row), a state, a user count, and a pin flag.

- **State**: FREE, LOADING (owner pid), READY.
- **Pinned** (libc, and `ld.so.conf`'s list): never reclaimed.
- **Arena slot**: a row's core base is assigned once per boot, at the
  library's first GRANT (the loader moves its core sites and binds imported
  data before it commits, so the base comes first), and kept for the boot
  even if its banks are reclaimed -- a reload lands at the same base, so no
  core ever moves under a process.  A slot holds one core size for the
  boot; a GRANT with another is EINVAL.  The arena starts at `HEAP_LIM`
  ($FFF8) and moves down.
- **Imports**: COMMIT records the rows a library imports from, a 2-byte
  mask.  Its relocated bytes hold their banks, so reclaim skips a row while
  a READY row names it: an unused importer goes first, and a pinned one
  keeps its imports for the boot.
- **Two majors** of one library are two rows.  The binder is always
  libc.so.1's; the registry and IMPS formats are the binder's ABI, versioned
  by the FGXD version byte, not by libc's major.

**`SYS_LDCTL` services.**  A = the service; X and Y the offset and bank of
a parameter block, which names every string by offset **and bank** (as
`KSVC_CDLOOKUP` does, `include/modules.s:264`): a library name lives in the
program's IMPS table, which may be in a code bank (5.1), so nothing is
taken from the caller's data bank implicitly.

| Service | Effect |
|---|---|
| `ACQUIRE(name, major)` | READY: count this process as a user, return the row.  Absent or FREE: make the row LOADING owned by this process, return "load it".  LOADING by a live process: sleep on the row (`KSVC_SLEEP`, interruptible) until COMMIT or ABORT, then retry; a signal ends the wait with EINTR (the sleep returns at once when a signal is pending, `jumptable.s:640-652`, `sched.s:588-620` -- retrying would spin), and the binder exits `ld.so: <lib>: interrupted`.  Never `KSVC_SLEEPUN`: a killed waiter must die.  There is no dead-owner case: every death reaches `_Exit_Core`, whose hook aborts the row and wakes the waiters.  The owner asking again gets "load it" again. |
| `GRANT(row, n, core size)` | the LOADING owner only (else EPERM), at most 8 banks a row in all (else EINVAL; `ld.mod` cannot know the file's segment count): banks granted to the **row**, so an interrupted load loses none; the core base assigned (the first time) and returned |
| `COMMIT(row, fields)` | the owner only (else EPERM): minor, CRC, offsets, block rows, binder entry, pin, and the rows it imports from; READY, the owner a user; wake waiters |
| `ABORT(row)` | the owner only (else EPERM): FREE, its granted banks kept on the row for the next loader; wake waiters |
| `LOOKUP(name, major)` | read-only, for the trace and `ldd` |

Every service answers in A (-1 and errno on failure; ACQUIRE 1 = "load
it", 0 = READY) and copies the row back into the caller's 50-byte block
(`<sys/ldctl.h>`): name 16, major, minor, CRC 4, row, bank count, banks 8,
core base, core size, template, EXPT, block rows (words), binder entry 3,
state, users, pinned, imports (a word).  The bank in Y is taken as given, as any 65816 program can store
to any bank.

**Sixteen rows a boot.**  A row keeps its arena slot when it is reclaimed
or aborted and is never handed to another name, so the seventeenth distinct
library of a boot gets ENOMEM.  The arena has no floor check in `ld.mod`:
the binder's fit rule (section 5) is what keeps it above the heap.

**The binder's entry.**  crt0 calls `SYS_LDCTL`'s `ACQUIRE` for libc
itself; READY copies back, in the block, libc's binder
entry (24-bit), its core template's address, base and size -- the only
registry values crt0 needs before C runs.  crt0 passes the binder the
locator's offset (its bank is crt0's PB) and the copier stub's address.

**`ld.mod`'s reentrancy rules.**  It is entered again while a call is in
progress in two real ways: a GRANT's `KSVC_BANKGRANT` calls `Bank_Alloc`,
whose pool-dry path reaches `ld.mod`'s reclaim (section 6.4); and a process
asleep in ACQUIRE lets every other process's calls and exit hooks in.  So:
no scratch in `ld.mod`'s statics lives across a `KSVC_SLEEP` or a
`Bank_Alloc`; reclaim never selects a LOADING row; reclaim never sleeps and
is pure, since `Bank_Alloc` may run with IRQs masked (`bank.s:158-166`).

**Per-process use**: a table indexed by process slot, one bit per row.
The exit, fork and exec hooks (section 6) keep it and the rows' counts, and
`Task_Alloc` zeroes a slot's row when it hands the slot out -- as it zeroes
`TCB_BankList` (`task.s:126-132`) -- because a child freed by `Task_Free` on
a fork or spawn rollback never reaches `_Exit_Core` (`process.s:1057-1068,
1204-1215`), and slots are reused.  A row at zero users stays cached.

## 5. Loading and binding

### 5.1 What `fgx_dyn` adds to a dynamic program

- The **tables go at segment 0's tail, and only there** (step 3): a `u16`
  segment count, one 4-byte cell per segment (a word, offset 0 of the
  segment, and a loader-relocated bank byte: the `FGX2_LONG_PTR` shape
  fgx_ld already checks, `fgx_ld.py:205-207, 278-355`), a `u16` IMPS length,
  then IMPS.  A program whose segment 0 has no room for them is refused,
  naming sub-project 5: fgx_dyn links one code segment today, and putting
  them in the data segment would move its bss.  tcsh's segment 0 has 541
  bytes free and its tables would be 10-15 KB, so the programs sub-project 5
  exists for need another home.
- The **locator** is the operand of `_dyn_loc`'s `LDA #` in `crt0_dyn.s`,
  which fgx_dyn patches with the tables' offset: crt0 reads it with no data
  access and no reloc, and the tables' bank is segment 0's, crt0's own
  (`PHK`).  The header's entry offset is not in memory at run time, so
  nothing is found "after the entry".
- The trailer gains **`ENTR`**, the offset of `_crt0_lib`, which
  `fgx_bind`'s host startup enters at.
- `stack_frames` includes the binder and the load path, which every dynamic
  program calls through `SYS_LDCTL`, not by name: its stack is sized for a
  first-use load.  Measured on `dynsodyn`: a stack hint of 6 pages without
  the binder's root, 11 with it.
- **`_crt0_inits` calls `_lib_init` only for a library with blocks to
  copy**: fgx_dyn knows each library's reached block bytes at link time,
  and a library whose total is 0 gets no call, and so no import of its
  block table.  `true(1)` reaches none of libc's.

### 5.2 Loading a library (`ld_load.c`)

1. Open `/lib/<name>.so.<major>.<highest minor>` (the highest minor of the
   major, SunOS `cache_rtld.c:145-183`), matching `<name>.so.<major>.` and
   then digits only: a pile file is `libc.so.<4 hex><6 hex>`
   (`fgx_ld.py` `pile_name`), which a looser match would take.
2. `GRANT` its code banks and read them in with `readv(2)`: an iovec's
   base is a far pointer, bank included (`syscall.s:3893-3897`,
   `kernel.s:1448`), so no new primitive is needed to read into a bank that
   is not the reader's.  One call carries at most 32767 bytes
   (`_Sys_UioVec`, the read(2) return word), so a bank goes in 16 KB runs.
   The core template and the block templates go on the end of the last bank
   (fgx_bind's layout, SP3 spec section 4), and after them the trailer's
   EXPT and FIXS blocks, tagged as in the file, then `XIDX` (built at load:
   the library's assembled core base, the export count and the `u16` offset
   of each EXPT record, so by-name binding can index EXPT's variable-length
   records), ended by an `END` tag, at the row's `expt_off`: FIXS is what
   the binder sets at each core copy.  `fgx_libso` charges XIDX's 36 + 2n
   bytes to the last bank's tail.
   `fgx_libso` packs a library's code with that tail's room kept on its
   last bank.
3. Core base = what GRANT returns: the arena's bottom less the core size,
   or the row's slot if it had one.
4. Relocs: each reloc's bank byte gets the granted bank of its target; a
   pointer into the templates gains their offset; a per-process fixup (a
   core pointer into the core) is left for the binder to set to the
   process's data bank at each core copy.
5. Core sites (CSIT) move by `base - assembled base`.
6. The library's own imports bind against the rows it needs, which are
   READY first: the needed lists (a program's, a library's) are ordered
   transitive closures, so an absent one is loaded, and the library after
   it, and nothing recurses.  Until step 3's by-name binding, a library
   whose needed library's CRC differs from the one recorded is refused; the
   build relinks termlib and curses when libc changes.
7. `COMMIT`, with the rows it imports from, and for libc its `_ld_bind`
   export as the binder's entry when it has one.

One listing of `/lib` and one read of the file a library: each listing of
164 entries costs about 0.35 s in MAME, and the relocs stream through the
buffer's room after the trailer.  Measured in MAME: libc (188 KB, four
code banks, 959 relocs) 3.3 s, 2.5 s of it the read; termlib 0.5 s;
curses 1.5 s.

### 5.3 Binding a program (`ld_bind.c`)

For each needed library, in the IMPS order: `ACQUIRE` (loading it on
first use); an older minor warns (5.5); then bind -- with the record's CRC
equal to the row's, code imports take the recorded values and data sites
move by `row base - recorded base`, no name looked up; otherwise by name
through EXPT, trying the recorded ordinal first, then a binary search.
Then each needed library's core is copied from its template to its base in
this data bank, and its fixups set to this data bank; `HEAP_LIM` = the
lowest needed core base; the fit is checked (data end <= that base less the
bitmap's blocks); return to crt0.  Under `LD_TRACE_LOADED_OBJECTS` the
binder prints each library and exits 0, in SunOS's shape with FGX's fields:

    	-lc.1 => /lib/libc.so.1.0 (core $f6a3, prebound, resident)
    	0 bytes of unused cores between them

Under `LD_BIND_DIGEST` it prints `LDB sites xxxx n=N` (9.7) and exits 0,
so a probe compares it with `cmp`.

As built: crt0_dyn ACQUIREs libc into `_dyn_blk`, copies libc's core with
`_lib_copy` and enters the binder through the row's binder address as
`_ld_bind(frame, tab, copy, blk)`, handing it libc's row as ACQUIRE left it;
every other row comes from the ACQUIRE or COMMIT that made it resident, so
a program needing only libc makes one `SYS_LDCTL` per exec.  `_ld_bind`
(`ld_bind_entry.s`, libc.so's bank 0 only, so static programs never carry
it) seeds libc's `_fcc_dbr` -- a core cell only libc's own code can find --
and jumps to `ld_bind`.  The binder keeps its state in a `struct ld_work`
above the break, the room up to libc's core its buffer.  A library's block
table is the program's own import of `_<lib>_blktab`; a program that
imports none for a library must want none of its blocks, or it is "a bad
import table".

A process's blocks are carved below its lowest needed core, overlaying any
unused core lower down harmlessly; only unused cores **between** its needed
cores cost it bytes (and fork copies them).  `ld.so.conf`'s order decides
that; ldload refuses an order that lists a library above one it depends on.

### 5.4 What is in assembly, and why

Measured on fcc's output (Fable, 2026-09-30): a C byte copy is ~50
instructions a byte, about 25 times `MVN`; a C site-patch loop is ~410
cycles a site, about 10 times asm.

- **The template copy is a stub in each program's crt0, not a routine in
  libc.**  `MVN`'s two bank bytes are immediates in the instruction, and
  libc's code bank is shared by every process, so no routine there can
  name a per-library source and a per-process destination -- the kernel
  meets the same limit with a self-modified stub (`process.s:1218-1222,
  1348`).  The stub, `_lib_copy(dst, src, n)`, writes both of `MVN`'s
  bank bytes into itself from its two far-pointer arguments per call: every
  caller passes full pointers, and no FGX2 reloc shape names an `MVN`
  operand byte.  Segment 0 is per exec; its only sharers are fork children,
  which never run in those banks concurrently with the parent's startup.
  Every core copy and every block copy in `_lib_init` (whose C byte loop it
  replaced) calls it; `_crt0_inits` passes it to `_lib_init` as its third
  argument, as crt0 passes it to the binder -- a libc core cell would cost
  every exec's core copy 4 bytes for no reader the argument does not
  serve.  `crt0_lib.s` (fgx_static's crt0) carries it today; crt0_dyn will
  carry the same.
- **libc's own core first**: crt0, not libc, copies libc's core into this
  data bank with that stub (from the values ACQUIRE returned) and seeds
  libc's `_fcc_dbr` before entering the binder.  The C binder runs in libc
  before `_libc_start`, and `_fcc_dbr` is 0 in the template: any
  int-to-pointer conversion would otherwise make a bank-0 pointer.  SunOS's
  rtld relocates itself first for the same reason (`rtld.c:50-55`).  The
  binder uses no stdio (its blocks do not exist yet); its output is
  `write(2)`.
- **The site loop** (in libc's asm, `ld_bind_asm.s`): the three site kinds
  are all "write 2-3 bytes at (segment, offset) through the bank table",
  with no bank immediate of its own, so it can be shared.  As built,
  `_ld_patch(sites, n, segs, kind, val, bank)` walks `n` (segment, offset)
  records: kind 0 (code) writes `val` and the bank byte, kind 1 (data) adds
  `val`.  ld_load's library imports and the binder's program imports both go
  through it, each taking only the site class its kind allows.

### 5.5 Versions and errors

SunOS texts where rtld has one:

| Case | Message, result |
|---|---|
| `SYS_LDCTL` ENOSYS, or libc not resident | `ld.so: libc.so.1 not loaded`, exit 1 (umbrella 5.6) |
| no file for a needed major | `ld.so: lib<name>.so.<major>: not found`, exit 1 (`rtld.c:612-615`) |
| an older minor than recorded | `ld.so: warning: <lib>.so.<major>.<minor> has older revision than expected <minor>` (`cache_rtld.c:178-181`), continues |
| CRC differs and a name is missing | `ld.so: Undefined symbol: <name>`, exit 1 (`rtld.c:839`) |
| no banks | `ld.so: <lib>: out of memory`, exit 1; the row ABORTs |
| data does not fit below its lowest needed core | `ld.so: <prog>: no room for its data (ends $XXXX, LIM $XXXX)`, exit 1 |
| a malformed table: more segments or libraries than the binder holds, an import whose kind does not match its sites, or no block table where the bitmap wants blocks | `ld.so: <prog>: too many segments`, `: needs too many libraries`, `: a bad import table`, exit 1; a library's own `: a bad export table` |
| under `LD_BIND_DIGEST`, a core copy differing from its template other than at its fixups | `ld.so: <lib>: core copy differs`, exit 1 (libc's core is skipped: the binder runs in it) |
| a block table with another row count than the bitmap's | `ld.so: <lib>: <prog> needs relinking`, exit 1 |
| a signal during a load | the exit hook ABORTs the row; waiters retry |
| a signal while waiting in ACQUIRE | `ld.so: <lib>: interrupted`, exit 1 |

## 6. Kernel pieces

Each goes where measured room allows: the core if it fits, else the far or
tty bank or a new overlay, with only the call in the core.

1. **`SYS_LDCTL`** on syscall 8: `_Syscall_Table`'s slot, a core thunk and
   a tty-bank body that refuses selectors past 4 and jumps through
   `LD_TRAMP` ($00:031A), a JML `Tty_BankInit` points at `_Ld_Absent`
   (ENOSYS, hooks no-ops) and `ld.mod` re-points.  Recorded by
   `tools/gen_syscall_table.py` in `docs/userland-abi.md`.
2. **`KSVC_BANKGRANT`, `KSVC_BANKFREE`**: appended to the module ABI
   (`include/modules.s`, append-only), dispatched in `jumptable.s`'s chain.
   A granted bank is in no TCB; only `ld.mod` frees it.
3. **Hooks**, each a core call site into a tty-bank body that enters
   `LD_TRAMP` with a hook selector ($80-$84), a no-op until `ld.mod` loads:
   - **exit**, in `_Exit_Core` beside the process's other releases (fds,
     cwd vnode; 4.3BSD-Reno `kern_exit.c:139`'s order) and before
     `_Task_FreeBanks`, so the row's granted banks and the process's own are
     never confused; it releases the process's rows and ABORTs a row it
     owns in LOADING; signal deaths reach it too (`signal.s:1396`);
   - **fork** and **vfork**: the child becomes a user of its parent's rows,
     at the point where the child is made runnable -- after the last
     failure path (the snapshot's, `process.s:1057-1068`) -- so a rollback
     never has a use to undo; `Task_Alloc`'s zeroing (section 4) covers
     every other path;
   - **exec**, after the new image commits: the old image's rows are
     released, as execve drops the borrowed libc reference
     (`process.s:3100-3116`).
4. **Reclaim**: `Bank_Alloc`'s pool-dry path calls `_LibcSh_Reclaim`
   (`bank.s:143-156`); when the pile registry frees nothing, it asks
   `ld.mod` to free one unpinned, zero-user row holding banks, READY or
   FREE (an aborted row's banks too), never LOADING, and never one a READY
   row imports from.  `Bank_Alloc` retries
   its bitmap after each freed row before it asks the MM, so a bank the MM
   granted to a row and the row later freed can cost every cached row
   before the MM is tried.
5. **The loader refuses a library file** (header flags bit 1) with ENOEXEC;
   bit 2 loads as today (`src/kernel/far/loader.s` reads no flags now).
6. **`ld.mod`** joins `/etc/rc.in`'s `modload` line and `modload.conf`
   (held equal by `tools/check_modload_lists.py`); `/sbin/ldload` runs
   after it.
7. **Unchanged**: the pile registry, `TCB_LibcBank`, the TCB layout, and
   SP1's `HEAP_LIM` and fork range (the arena lies inside it).

## 7. Boot, `ld.so.conf`, `ldd`

- `/etc/ld.so.conf`: one library per line (`libtermlib 1`), `#` comments;
  missing or empty is fine.  ldload makes libc resident, then each listed
  library in file order, pinned.  An order listing a library above one it
  needs is refused, naming both.
- ldload prints one line per library (name, version, banks, core base, and
  its load time or `(resident)`), then how many it loaded and how many were
  resident; a library a listed one needs and that is not listed loads
  first, unpinned.  `/etc/rc` runs it in the foreground after `modload`,
  as SunOS's rc.local runs ldconfig.
- `ldd <prog>` runs it with `LD_TRACE_LOADED_OBJECTS=1` and prints the
  binder's lines.

## 8. Performance and scalability

- **Per exec**, as estimated: the copy of libc's core dominates -- 2,389
  bytes at `MVN`'s 7 cycles a byte is ~16.7 k cycles, ~6 ms at 2.8 MHz,
  two-thirds of a 9 ms budget (10% of the umbrella's 90 ms `exec(true)`),
  and it is per-process data, so nothing moves it to boot.  Sites are well
  under 1 ms for a small tool (~50 sites at ~40 cycles in asm); one
  `SYS_LDCTL` per needed library is sub-ms.
- **Per exec, as measured** (step 3; PC samples every 1.009 ms of emulated
  time over 200 execs of `dyntrue`): the core copy is ~2.3 ms.  Before two
  fixes, the binder's own code dominated: `ld_bind`'s frame was over 255
  bytes and fcc reached every scalar through `_fcc_fp` (fixed in fcc: its
  scalars now sit below its arrays), and `_lib_init` walked libc's 37 block
  rows to find nothing to copy for a program that reaches none (fixed at
  link time, 5.1; measured 92-93 ms -> 87 ms per exec).  What remains of the
  binder is `ld_bind`, `ld_rd16` and `lb_row`.  89% of the core template is
  zeros, but the destination is the previous process's core, not zeros (a
  read before the copy found 98-614 nonzero bytes), so only a fill faster
  than `MVN` would cut it.
- **First use**: a library's read, relocs and core sites once per boot
  (curses: 44 KB and 1,712 core sites, ~30 ms of patching in asm plus the
  read).
- **The pool**: each resident library holds its banks; zero-user rows are
  reclaimed under pressure; pinned rows never.
- **The data bank**: a process loses the cores lying between its needed
  cores; `ldd` shows it; `ld.so.conf`'s order (small cores first) keeps it
  small.
- **Registry**: ~40 bytes a row in `ld.mod`; twenty libraries fit.

## 9. Testing and measurement

Host (`make test-archives`): fgx_dyn's table placement and locator
(including a full segment 0), the binder's frames in stack sizing, and
`fgx_bind --digest`, which fgx_bind gains.

Machine (headless MAME, testbin, fresh runs, not the gate):

1. **`dynso`**, dynamic: its checks, and libc's banks equal in a forked
   child and in a second, unrelated run.
2. **`cursso`**, first use: the trace says loaded, a second run says
   resident; `ldd cursso` prints the libraries, bases and holes.
3. **Race**: `cursso & cursso & wait` on a fresh boot: both pass, one load.
4. **Killed mid-load**: step 1's direct probe ACQUIREs a row, GRANTs a
   bank and `pause()`s; a sibling kills it and ACQUIREs the same row, which
   it takes over with the same bank.  In step 4 the same with `cursso`
   killed while it reads (a 44 KB read); the row ends READY and the
   free-bank count is unchanged.  No test-only service is needed.
5. **Reclaim**: after `cursso` exits, claim banks until the pool runs dry:
   curses's row is freed, libc's is not, and `cursso` then reloads at the
   same base.
6. **Errors**: a fit fixture just over its limit; a program linked against
   a test library whose `.so` is not staged (`fgx_libso.LIBS` gains a
   test-only entry).
7. **Parity**: `LD_BIND_DIGEST` on dynso and cursso equals `fgx_bind
   --digest` with the same bases.  As built, the digest covers the
   program's patched sites only, every bank byte normalised to (library
   index, code segment): a 16-bit rotate-xor over each site's word and
   `16*L+S`, printed with the site count, `LDB sites xxxx n=N`.  fgx_bind
   writes load-time segment numbers and the machine writes runtime banks,
   so raw bytes never match.  The core copies are not in the host parity:
   their bank bytes are the libraries' own relocs, which the binder does not
   know and step 2's `lddig` already checked in the templates.  Instead the
   binder, under `LD_BIND_DIGEST`, checks each core it copied equals its
   template but at its fixups.
8. **Negative cases**, each from step 1's direct probe where it can be: a
   fork that fails (pool dry) leaves every count unchanged; an exec of a
   missing file keeps the old image's rows; a non-owner's GRANT, COMMIT or
   ABORT gets EPERM; a GRANT past the file's segment count is refused; a
   waiter killed asleep in ACQUIRE dies and the count is unchanged; a second
   major of one library gets its own row.

Controls that must fail: the exit hook disabled (the reclaim probe fails);
arbitration off, every absent library loaded by whoever asks (the race
shows two loads); `Task_Alloc`'s zeroing off (the failed-fork probe's
counts change).

Measured and gating: `exec(true)` in ms for small tools, dynamic against
today's static `true` through the pile path, under one MAME primary, 20 or
more repetitions (MAME's frame is 16.7 ms) -- dynamic within 10%.  SP3's
bound image is reported beside it (it pays the same core copy).  The
report names libc's core bytes as the term that decides it.  Two traps,
found measuring it: the meter (`exectime`, `gettimeofday`) is the system
clock, which lost ticks under fork/exec load until apple/fgx#502 was fixed,
so check it against MAME's emulated time when a number moves; and at 20
repetitions the first exec's cold read of the binary is a large share of
the mean, so the budget is read at 200.
Reported: the first-use load of curses, ldload's boot time, per-process
data and hole bytes, the stack surcharge, the pool's banks.

SP3's MAME probes `dynsomis` and `dynsonodata` (26 s of `ninja all` when
libc changes) retired in step 4, SP4's by-name path being proven on the
machine; fgx_bind and its host tests stay, and `dynso`'s and `cursso`'s
bound images stay as controls.

As built (step 4): items 2-6 run a new binary, `curssodyn` (cursso bound on
the machine), and each multi-step probe is a script under `/testdata`, the
console taking at most 255 typed characters (`TTYHOG`).  The race and the
kill stop the first user inside its load (`ldctl waitload <lib> <pid>`
sends it SIGSTOP once its row is LOADING with banks granted) so the second
user always finds the row LOADING: the race then continues it, the kill
SIGKILLs it.  "The free-bank count unchanged" is the row's bank list,
equal before and after the takeover -- nothing reports the pool's free
count.  "Not found" renames the staged termlib aside for the run.  The
machine's fit check is reached by moving a base (`ldctl pad 100`, then
termlib loaded): fgx_dyn refuses at link time a program that does not fit
the assembled bases.

## 10. Order of work

Each step lands on its own; the gate stays green.

1. **Kernel and `ld.mod`**: `SYS_LDCTL`, the KSVCs, the hooks, the reclaim
   step, the loader's refusal, `Task_Alloc`'s zeroing; `ld.mod`'s registry
   and services; a probe that drives the services directly (acquire,
   grant, commit, abort, the race, a dead owner, a signalled waiter, the
   negative cases of 9.8) with no library involved.
2. **Loading**: `ld_load.c`, the copier stub in `crt0_lib.s` (and `_lib_init`
   on it; the static probes prove it),
   `/sbin/ldload`, `ld.so.conf`, libc resident at boot; boot time measured.
3. **Binding**: fgx_dyn's tables and locator, `crt0_dyn.s` (the copier
   stub, libc's core copied first), `ld_bind.c` with its asm site loop,
   `LD_TRACE_LOADED_OBJECTS`, `ldd`,
   `LD_BIND_DIGEST` parity; `dynso` dynamic in MAME; the exec budget.
4. **First use and reclaim**: `cursso`, the race, the kill, reclaim, the
   error probes; the measurements; `dynsomis`/`dynsonodata` retire.

## 11. Divergences, stated

| FGX | Source | Why |
|---|---|---|
| a library stays at one base for the boot, relocated once at its first load | SunOS maps a library per process and relocates text when it must (`rtld.c:436-447`) | one shared copy, no MMU |
| zero-user libraries stay cached until the bank pool needs them | Linux/Solaris unmap a library when its last user exits; the page cache keeps its pages | the same effect with whole banks: today's pile registry behaves so (`bank.s:193-230`) |
| a program's lost bytes depend on which libraries loaded before its own | per-process mappings never overlap | a core's base is fixed for the boot; `ldd` shows the cost |
| any user can make an installed library resident (bounded by the file's banks) | SunOS has no resident set to exhaust | FGX's posture favours function; stated in BUGS |
| a library with a changed block table refuses old programs | SunOS has no per-member blocks | the bitmap's rows carry no names |
| a first user of a library that another process is loading waits for it, and waits for as long as that process is stopped (^Z) | SunOS maps a library per process; nobody waits on another's load | one shared copy; the wait is interruptible (EINTR), so the waiter can be killed; stated in BUGS |
| a library a program loaded before ldload ran, and that ld.so.conf lists, stays unpinned | SunOS has no resident set | COMMIT sets the pin, and the library was committed before; stated in ldload(8)'s BUGS |

## 12. Open items

- Step 1 landed 2026-09-30 (plan `2026-09-30-shared-libc-sp4-step1-plan.md`).
  As built:
  - **`LD_TRAMP`** ($00:031A) is the one entry: services 0-4 (from
    `SYS_LDCTL`, whose tty-bank body refuses any other selector) and hooks
    $80-$84 (EXIT, FORK, EXEC, TALLOC, RECLAIM).  Tty_BankInit plants a
    JML to `_Ld_Absent` (ENOSYS / no-op) at every boot; ld.mod re-points it.
  - **Homes, measured**: the core holds only call sites -- `SYS_LDCTL`'s
    thunk, five hook sites, the two KSVC services -- 73 bytes including two
    bytes per core-to-tty site in the generated patch table, leaving 13 of
    86; the far bank holds the loader's refusal (17 bytes); the tty bank the
    bodies (slots 49-54, `ld_hooks.s`); ld.mod is 2,346 bytes in the shared
    module bank, after fpsim.  The core's room is the next constraint: the
    next kernel piece goes to the tty bank or an overlay.
  - **`ld.mod`**: 16 rows of 52 bytes (the 48-byte block plus the loader's
    pid and the arena-slot flag), a word of row bits per process slot, the
    arena's bottom.  GRANT is capped at 8 banks a row: ld.mod cannot know a
    file's segment count.  There is no dead-owner takeover: every death
    reaches `_Exit_Core`, whose hook aborts a dying owner's row and wakes its
    waiters.  Reclaim takes READY or FREE rows (an aborted row's banks too),
    never LOADING or pinned.  `Task_Alloc`'s hook clears a fresh slot's bits
    but has no discriminating test: a fork rolled back by `Task_Free` never
    ran the fork hook, so no stale bit can arise.
  - **Proven in MAME** (`ldctl`, testbin): selector, basic, libexec
    (ENOEXEC for a library), fork, exec (and a failed exec), race (the
    second first-user waits, then takes the row over with its banks), intr
    (EINTR), kill (a SIGKILLed waiter), eperm, reclaim (the pool drained
    through ld.mod's grants; `malloc` never calls `Bank_Alloc`), reuse; and
    `modimage` with ld.mod loaded.  Controls: the exit hook off fails fork
    and reclaim; arbitration off fails race; reclaim limited to READY rows
    fails reclaim.  `KSVC_SLEEP` from the module arm works as pty.mod's does.
  - **Found**: Merlin32 evaluates expressions left to right, so a table of
    `base+n*size` assembled as `(base+n)*size` (the row table now carries
    literal offsets); a new `PUT` file is tracked by ninja only after
    `tools/ninja/gen.py` regenerates `build.ninja`; ACQUIRE's sleep did
    not save the kernel's DP pointer scratch `_libcTmp2` (the apple/fgx#100
    class, caught by `check_dp_sleep_safety`), so the wait is its own
    routine, `ld_sleep`, saving it as two overlapping words.

- Step 2 landed 2026-10-01 (plan `2026-09-30-shared-libc-sp4-step2-plan.md`).
  As built:
  - **`ld.mod`**: the block is 50 bytes (the imports mask), the row still
    52; GRANT assigns the core base; reclaim keeps an import while a READY
    importer names it.  ld.mod is 2,427 bytes.
  - **`_lib_copy`** in `crt0_lib.s`, an `MVN` copier that `_lib_init` gets
    from `_crt0_inits`; the staged tree byte-identical for it.
  - **`ld_load.c`** in libc (about 18 KB of code, which made libc.so four
    code banks), **`/sbin/ldload`** (static), **`/etc/ld.so.conf`**
    (shipped empty), and `/etc/rc` running ldload after modload: libc is
    resident from boot.  In MAME, libc loads in 3.3 s and the boot reaches
    its prompt by 54 s (the smallest `FGX_MAME_BOOT_S` a boot probe passes
    at), where it did by 50; the harness types at 60.
  - **Proven in MAME**: `ldload` (libc from boot, termlib and curses from a
    conf, a second run all resident), `ldorder` (no conf; an order fault,
    a missing file and a line with no major named; the rest loaded),
    `lddelta` (100 bytes of arena held after libc, a conf of curses alone:
    termlib loads through the absent-library path, and curses's data
    imports bind at a delta of -100), `ldctl_deps`; `lddig` checks every
    runtime bank byte and a digest per bank against `fgx_lddigest`, the
    host's layout built on fgx_bind.  Controls: core sites skipped (fails
    `lddelta`; `ldload`'s bases equal the link bases, so its sites move by
    0), the templates' offset dropped from relocs, the data delta dropped
    (fails `lddelta` only), the import rule off (fails `ldctl_deps`), the
    copier a byte short (fails `libcso`).
  - **Found**: reclaim could free an import under a READY importer, and
    the core base came at COMMIT, after the loader needs it (step 1, fixed
    in ld.mod); `fgx_libso` packed a library's code with no room for the
    core and templates on its last bank (libc's reached 65,935 bytes with
    ld_load); `tools/stage_piles.py` pruned every `libc.so.*` in `/lib`,
    libc.so.1.0 with them; ldctl's deps mode sized its libraries for a pool
    without libc's four banks.

- Step 3 landed 2026-10-01 (plan `2026-10-01-shared-libc-sp4-step3-plan.md`).
  As built:
  - **libc's side**: `XIDX` after FIXS in ld_load, `_ld_patch` in
    `ld_bind_asm.s` for both binders, `ld_bind.c`, and `_ld_bind` in
    `ld_bind_entry.s` (libc.so's bank 0 only).  libc.so.1.0 is 223,837
    bytes in four code banks.
  - **The program's side**: fgx_dyn's tables at segment 0's tail, the
    `_dyn_loc` locator, `ENTR`, `crt0_dyn.s`; `_crt0_inits` without a
    `_lib_init` call for a library with nothing to copy.
  - **`LD_TRACE_LOADED_OBJECTS`**, **`LD_BIND_DIGEST`** (equal to
    `fgx_bind --digest`: `dynsodyn` and `dynsomisdyn` both `LDB sites 51fc
    n=85`, prebound and by name writing the same bytes), and **`ldd(1)`**,
    ported from SunOS 4.1.3's, at `/bin/ldd`.
  - **The exec budget**, 200 execs, MAME: `/bin/true` 87 ms, the dynamic
    `true(1)` 87 ms -- within 10%, at 0%.  SP3's bound image, which reads
    libc's four banks every exec, 2.76 s.
  - **Proven in MAME**: `dynsodyn` (21 checks, the environment, libc
    shared with a forked child, an exec of `dyntrue`, `users=0` after),
    `dynsomisdyn` (by name against a rebuilt libc), `lddigest`, `ldd`, and
    the step 1-2 probes again: 23 of 23 dynamic and registry probes.
    Controls: crt0_dyn without libc's core copy (`dynsodyn` fails); no data
    patch, by-name values off by one, and library/segment swapped in the
    digest (each fails `lddigest` or `dynsomisdyn`); the site loop broken
    (fails `ldload`'s termlib and curses digests).
  - **Found**: fcc gave locals frame slots in declaration order, so an array
    declared first pushed every scalar past the 8-bit `n,S` reach (fixed in
    fcc); a fork or vfork child resumed in user mode with IRQs masked, so
    its execve ran with the heartbeat off and the system clock lost about
    half its ticks under fork/exec load (apple/fgx#502, fixed); the static
    programs' ninja edges did not depend on libc's hand-written bank-0
    files, so an asm-only change left `/sbin/ldload` stale and a control
    first passed; `_ld_bind` in libc's bank 0 would have put the binder in
    every static program; `_lib_init` spent ~6 ms per exec finding nothing
    to copy.
  - **Found outside the gate**: a run of every manifest found eight that
    pass on main and failed on the branch.  Two causes, both fixed: both
    signal trampolines took a handler at `bank:$0000` for `SIG_DFL` (K&R
    A.6.6), and tcsh's `pchild` landed there once fcc's layout change
    repacked its banks, so SIGCHLD was dropped and tcsh hung (`tcstatic`,
    `stkover`, `stkdefer`, `fgxuser`, `sugidguard`, `telnetiac`); and a
    keystroke interrupt clobbered fcc's static scratch under a task's tty C,
    so `ttbgread` called the foreground shell background and tcsh logged out
    on EIO (apple/fgx#503; `dirperm`, made visible by #502's fix).  And
    `frotzacheton` crashed the machine once libc was resident at boot
    (bisected to step 2's ab903ac, apple/fgx#504): frotz's undo buffer size
    wrapped in 16-bit arithmetic, its copy overran the data bank, and with
    libc's four banks taken the next bank was frotz's own code -- fixed in
    frotz.  `manyproc` and `wuptime` fail on main too.

- Step 4 landed 2026-10-02 (plan `2026-10-02-shared-libc-sp4-step4-plan.md`).
  As built:
  - **Probes** (MAME, fresh): `curssodyn` (first use loads termlib and
    curses, a second run finds them resident, `ldd` lists the three),
    `lddigest` (now also curssodyn's digest, taken through the first-use
    load: equal to fgx_bind's), `curssoload` and `curssorace` (one load
    between two first users, both run), `curssokill` (the waiter takes the
    killed loader's row over with the same banks), `curssoreclaim` (curses
    reclaimed, libc not, curses reloaded at the same base), `ldfit` (`not
    found`, and `no room for its data (ends $f4aa, LIM $f478)` for fitso
    linked 50 bytes under its limit after termlib landed 100 lower; linked
    150 under, it runs).  `ldctl` gains `row`, `waitload` and `drain`.
  - **Controls**, each red and restored: the first-use path absent fails
    `curssodyn`; arbitration off fails `curssoload` (the second user takes
    the row and the first is refused); the exit hook off fails `curssokill`
    and `curssoreclaim`; apple/fgx#505's fix reverted fails `curssokill`;
    the run-time fit check off fails `ldfit`.
  - **Measured**, 200/20 execs, MAME: `/bin/true` 87 ms, the dynamic
    `true(1)` 88 ms (the exec budget holds); curssodyn's first exec, loading
    termlib and curses, 3,955 ms and 772 ms resident -- about 3.2 s of first
    use; cursso bound on the host 4,056 ms.  curses's core sits at `$E712`,
    termlib's at `$F4E2`, with no hole between them on a boot that loads
    them in order.  The stack surcharge (6 -> 11 pages) and ldload's boot
    time (libc, 3.3 s) are step 2-3's, unchanged.
  - **Found and fixed**: the binder's first-use path had never worked on the
    machine -- `ld_find` passed listdir(2) its whole buffer (~50 KB) and the
    kernel's size is an int, so every library was `not found`; SIGKILL did
    not end a stopped process (apple/fgx#505, per 2.11BSD `psignal()`);
    wait(2) never answered ECHILD after a reaped child, so sh's `wait` hung
    (apple/fgx#508, the #401 class); 2.11BSD sh called `signal(i, 1)`
    without libc's signature, installing a catcher at `<garbage>:$0001`, and
    fcc stored a function-pointer member from an integer with a stale bank
    (apple/fgx#507, #506) -- the two that made `killprobe` and `haltcmd`
    crash once the trampolines called a handler at offset 0 or 1 with a
    bank.
  - **Found, open**: apple/fgx#509 -- the binder's load buffer is the room
    between the break and libc's core, and the link-time fit reserves only
    its 294-byte scratch, so a program within ~8 KB of the cores cannot
    load a library on first use; apple/fgx#510 (cmp(1)'s message).
  - The full manifest run: 228 of 236 pass; `manyproc` and `wuptime` fail
    as on main, and six probes compiled out by `cfg/system.cfg` are skipped.

## 13. Sources read

- SunOS 4.1.3: `lib/csu/m68k/crt0.s:30-32, 53-61, 186-201` (crt0 maps
  `ld.so` and calls it with `__DYNAMIC`), `lang/rtld/rtld.c:52-55, 436-447,
  612-615, 800-850, 839`, `cache_rtld.c:145-183`, `bin/ldd.c`.
- 4.3BSD-Reno `kern/kern_exit.c:139`.
- FGX: `src/kernel/far/loader.s` (1030-1290, 1224, 1370-1447),
  `src/kernel/process.s` (34, 603-658, 1007-1076, 1348-1360, 3100-3123,
  3530-3610), `src/kernel/task.s:270-375`, `src/kernel/bank.s:81-230`,
  `src/kernel/syscall.s:1000-1145`, `src/kernel/jumptable.s:300-560`,
  `src/kernel/signal.s:1396`, `include/modules.s`, `include/memmap.s`
  (440-448, 1890-2000), `include/kernel.s` (653, 688, 695, 983-992),
  `include/loader.s`, `disk_src/etc/rc.in`, `toolchain/lib/libc_c/libc_init.c`,
  `toolchain/lib/fcc_runtime_data.s`, `toolchain/src/cc/emit.c:5200-5235`,
  `toolchain/src/ld/{fgx_bind,fgx_dyn,fgx_imports,fgx_ld}.py`.
- Adversarial review by Fable, 2026-09-30, of sections 3 and 5: the asm
  copies and site loop, the tables' placement, the binder's self-relocating
  prologue, iteration over the needed list, the arena's ordering rule,
  the ordinal-first lookup; its recommendation to drop first-use loading was
  answered by moving arbitration into the kernel.
- Second adversarial review by Fable, 2026-09-30, of the written spec,
  sixteen findings adopted: the copier in crt0 (MVN's banks are
  immediates), names passed with their bank, `Task_Alloc` zeroing a slot's
  uses and the fork hook after its last failure path, EINTR from an
  interrupted ACQUIRE, the stopped owner stated, `readv` into granted
  banks, the digest normalised, `ld.mod`'s reentrancy rules, STALL removed,
  the exec budget's baseline and its dominant term, crt0's interface, the
  bank table as `FGX2_LONG_PTR` cells, the `/lib` name match, the
  umbrella sections superseded, the exit hook's reason, the negative
  probes.
- Also read for it: `src/kernel/task.s:100-135`, `src/kernel/sched.s:588-620`,
  `src/kernel/chardev.s:38-42, 783-845`, `src/kernel/syscall.s:73-160,
  3893-3910, 4510-4535`, `include/kernel.s:1448`, `include/loader.s:841`.
