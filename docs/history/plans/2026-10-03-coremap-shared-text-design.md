# Coremap and shared text -- design

Date: 2026-10-03.  Status: phase A merged (!406); B1-B3 merged (!409, 6.5); B4-B5 not built (6.6).
Scope decided with the maintainer: text and kernel memory now; each process keeps a
64 KB data bank; no swapping.

## 1. Goal

Cut what a process and a kernel consumer cost in memory by moving toward
2.11BSD's model: memory placed by size from one resource map (the coremap),
and program text shared by every instance of a program.  Success is measured
in banks: banks held per process, and banks held by an idle system, counted
the way section 2 counts them.

## 2. Where memory goes today (measured 2026-10-02/03, MAME, 8 MB)

The machine has 130 banks of 64 KB.  With 21 background sleeps:

| Use | Banks |
|---|---|
| processes' code + data (each process: one code bank, one data bank) | 64 (21 sleeps = 42) |
| ramdisk (2048 x 512-byte blocks, made at boot) | 16 |
| libc piles, one per distinct program | 9 |
| libc.so (feat/shared-libc, before the SP5 cut-over) | 4 |
| kernel (images, heap, console, screens, modules, home, swap, ...) | ~23 |
| system banks $00/$01/$E0/$E1 | 4 |

A process needs two whole free banks; with 21 sleeps there were two, so the
22nd ran and the 23rd got ENOMEM.

The kernel's banks at an idle prompt, used against held:

| Banks | What | Used |
|---|---|---|
| 3 | core / far / tty images | full |
| 4 | console + 3 virtual-console screens | ~40 KB each (4 x 8000-byte planes padded to 8 KB, 4 x 2000-byte alt copies) |
| 1 | fonts | ~64 KB |
| 2-3 | heap arenas | 53 KB; 37.9 KB (VFS pool: vnodes 10.5 KB, specinfo 0.9 KB, nameidata 26.5 KB = 32 pids x 2 x 414 B); one arena 0 B |
| 7 | modules | shared bank 53.9 KB; vfs 65.3 KB; ufs 47.8 KB; ufsdir 53.5 KB; ufsprobe 6 KB; prodos 37.3 KB; prodosw 34.5 KB |
| 1 | home bank (parked kernel images, 2 KB per pid) | 22 KB at idle |
| 1+ | user-image swap banks (2 KB units) | partial |
| 2 | docvu.cda (Memory Manager blocks) | 68 KB |

### 2.1 Quick wins already taken (branch feat/mem-quick-wins)

| Commit | Change | Recovered |
|---|---|---|
| f0248a505 | rest-of-OS claim: module window 4 -> 3, boot heap 3 -> 2 banks | 2 banks |
| 984f2251e | open-file table carved after Kmem_Init (it had leaked a pool bank) | 1 bank |
| 3f39c606e | prodos/prodosw loaded by mount_prodos on demand | 2 banks |
| 35337c5c9 | ufsprobe built and shipped only with a probe gate on | 1 bank |
| 1f7f742c4 | kernel and rest-of-OS handles claimed exactly (no slack bank) | 2 banks |
| 5de3baedd | no desk accessory installed at boot; loadcda when wanted | ~64 KB |

Baseline for this spec, after them: idle pool use 46 of 56 banks; Memory
Manager FREE 2,847 KB at idle.

After phase A (feat/shared-text, measured 2026-10-03 with `vmstat -b` and a
BankBitmap dump):

| | Before phase A | After |
|---|---|---|
| 21 sleeps' images | 42 banks (21 code + 21 data) | 22 (21 data + 1 shared code bank, count 21) |
| idle pool use | 46 of 56 | 53 of 56, of which 14 are text banks; 5 of those belong to no running program and are reclaimed when the pool runs dry |
| Memory Manager FREE at idle | 2,847 KB | 2,847 KB (the pool is claimed at boot either way) |

Idle use rises because a text stays cached after its program exits, as
2.11BSD's does; what a dry pool can take back is the measure that matters.

## 3. Constraints the code sets

These were read from the source, and they bound the design.

1. **No MMU.**  A segment is loaded at $0000 of a fresh bank
   (`src/kernel/far/loader.s` `_LoadOneSegment`), code is assembled at org 0,
   and data is reached through the data bank register with absolute 16-bit
   operands (`toolchain/lib/crt0_far.s:117-121`: the loader presets DBR and
   crt0 never changes it).
2. **Data cannot move after a program starts.**  fcc pointers are 4 bytes,
   offset + bank + pad (`toolchain/src/cc/emit.c:517`, "offset @ +0,
   bank+pad @ +2"), and they live in the
   heap, globals and frames.  2.11BSD grows a process by copying it
   (`sys/vm_proc.c` `expand()`), which needs an MMU; here a region is placed
   with its room up front and grows only in place.
3. **Shared-library cores sit at one offset in every process**, assigned
   once per boot from the arena at a library's first GRANT with a core size
   (`src/modules/ld/ld.s` `svc_grant`; libc measured at $F6A3), because shared
   library code addresses its core absolutely.  Two processes cannot share a data bank
   while each needs its own core at that offset.  Hence data stays one bank
   per process in this spec (section 7).
4. **Code is already free of data-bank references.**  Across all 112 shipped
   programs, measured: CODE->CODE 8,643 relocs, CODE->LIBC/LIBCREF 6,776,
   DATA->CODE/DATA/libc 6,317, and **CODE->DATA 0**.  fcc takes the live data
   bank with PHB; `FGX2_LONG_PTR` is emitted to the data output only
   (`emit.c:131`), and no program's CODE listing holds an `FGX2_CALLEE_ENTER`
   or `FGX2_LONG_PTR` (the immediate-data-bank prologue,
   `toolchain/lib/macros.s:574`).  Own-bank function pointers take their bank
   with PHK at the dereference (`emit.c:1191-1197`).  Nothing writes a code
   bank at load but the bank-byte relocs (`loader.s:1366-1392`); the heap
   descriptor goes to the data bank.  Code binds only to its own code segments
   and to its libc pile.
5. **The assembler gives no relocation information.**  Segments are assembled
   absolute (`ORG $0B0000`), and the Merlin32 listing's `Reloc` column is empty
   on every row -- `JMP _crt0_start` at $0000 included.

## 4. The BSD model this follows (2.11BSD, read 2026-10-03)

- The unit is a 64-byte click (`pdp/machparam.h`: "Core clicks (64 bytes)").
- A process is text, data and stack, each sized from its a.out header
  (`sys/kern_exec.c` `getxfile()`: `ts = btoc(ep->a_text)`, `ds =
  btoc(lsize)`, `ss = SSIZE + btoc(nargc)`), each allocated with
  `malloc(coremap, n)`.
- The coremap is a dense array of `{m_size, m_addr}` segments in address
  order, first-fit, coalescing on return (`sys/subr_rmap.c`, `h/map.h`).
- Text is shared: `xalloc()` finds a program's text by inode and bumps
  `x_count` and `x_ccount` (`sys/vm_text.c`); `xfree()` drops the count and
  keeps the text cached ("all text under 2.10 is sticky in an LRU cache");
  `xuncore()` frees unused cached texts when core is short.
- Writing a running program is refused: `access()` tries `xuntext()` once,
  then answers ETXTBSY (`sys/ufs_fio.c:58-67`); unlink and chmod flush an
  unused text (`sys/ufs_syscalls.c:366`, `:598`); exec of a file open for
  writing answers ETXTBSY (`sys/kern_exec.c:472-481`).
- Swapping (`sys/vm_sched.c` `sched()`) is BSD's answer to over-commit; it is
  out of scope here.

## 5. Phase A -- shared text

### 5.1 What is shared

A program's CODE and RODATA segments, as one unit: its text.  This is safe by
constraint 4.  DATA->CODE relocs (function pointers in data) stay per process
and point into the shared banks.

### 5.2 The text table

Modelled on `struct text` (`h/text.h:18-29`, about 20 bytes there), on the
kernel heap, `NTEXT` = 16 entries to start (as `LIBCSH_SLOTS` is 16), about 16
bytes each in FGX's layout:

- the executable's identity (its vnode);
- its code and RODATA bank list;
- the libc pile it was relocated against, held as a reference: a pile
  reclaimed and reloaded into another bank would leave the code's JSL bank
  bytes stale;
- `x_count` (processes using it) and flags (loaded, being written).

The text holds a **vnode reference** (a `v_usecount` taken through the VFS's
`vref`/`vrele` pair in `vfs_subr.c`) and records `v_id`
(`src/kernel/vfs/vnode.h:289-294`) as its stale-pointer check, as BSD's text
holds `x_iptr` and drops it with `irele()` in `xuntext()` (`vm_text.c:351-358`).
The loader today opens by path and closes the descriptor after loading
(`loader.s:552`, `:1443-1445`), so nothing held the vnode before.

Each process records its text in a per-pid byte array (32 bytes; TCB and SE
are full, so it is a parallel array of the `_kAlarm*` shape).  Shared banks
never enter `TCB_BankList`, which exit frees bank by bank; they ride the text,
as the libc pile rides `TCB_LibcBank` (`include/loader.s:125`).

### 5.3 Lifecycle

**Exec and spawn order change.**  Today both allocate a bank BEFORE the loader
opens the file and pass it as the override bank: spawn stores it in
`TCB_CodeBank`, `TCB_DataBank` and `TCB_BankList+0` (`process.s:111-119`),
exec the same (`process.s:2926`), and the loader requires it, loads segment 0
(always CODE) into it and makes it the entry bank (`loader.s:1411-1418`,
`:1536-1540`).  Shared text needs:

- open and look up the text first, before any bank is allocated;
- the pre-allocated override bank becomes the DATA bank, and
  `TCB_BankList+0` holds the data bank, not the code bank -- every rollback
  that reads it as `_ps_childBank` (`process.s:181`, `:478`) follows;
- the entry bank comes from the text entry, not the override.

**Text references are per TCB, independent of image-group ownership.**  The
fork image group shares the code bank today (`process.s:759-761`) and hands
`TCB_BankList[0..7]` to an heir in `Img_HandOff` (`process.s:2148-2200`); a
snapshot child "owns nothing" and frees nothing at exit (`:2157-2159`).  Once
code banks ride the text, every member holds its own text reference: fork
takes one, and every member's exit or exec drops one, owner or not.
`Img_HandOff` hands the data, stack, soft-frame and big-block banks only.

- **exec** (`xalloc`): look up the vnode.  On a hit (entry present, banks
  resident): `x_count++`, map its banks, and load only the data segment and
  the soft-frame bank, applying only the relocs whose source is DATA.  On a
  miss: load as today, then register.
- **fork:** the child takes the parent's text; `x_count++`.
- **exit / exec-away** (`xfree`): `x_count--`.  At zero the text stays cached,
  except that it is freed at once when the file's link count is zero
  (`vm_text.c:107`).  A cached text is never written under: write access
  flushes it first (below).
- **reclaim** (`xuncore`): when the pool runs dry, `Bank_Alloc` frees a
  zero-reference cached text before asking for a Memory Manager grant, beside
  `_LibcSh_Reclaim`.
- **writing a running program**, the three rules of section 4.  The hook is
  already in the tree: `vn_writechk` answers ETXTBSY on `VTEXT`
  (`src/kernel/vfs/vfs_vnops.c:162-173`), and nothing sets `VTEXT` yet
  (`:39-41`).  So A2 sets and clears `VTEXT` with the text, adds the "flush
  once, then ETXTBSY" retry at `:172`, and flushes an unused text on unlink
  and chmod in ufs_vnops.  Exec of a file open for writing is ETXTBSY.  This
  is new to FGX: today every exec loads a fresh copy, so writing a running
  binary is harmless.

**Every path that frees or keeps a code bank** is covered, since each frees
`TCB_BankList` today:

| Path | Today | With shared text |
|---|---|---|
| spawn failure (`process.s:142,187,266,303,321,452,484`, `_Task_FreeBanks`) | frees the list | frees the data bank; drops the text reference if one was taken |
| exec commit (`process.s:2915-2922`, `:3128-3165`) | frees the old list after `Img_HandOff` | drops the OLD text reference; frees the old data banks |
| exec failure | restores the old list | drops the NEW text reference; keeps the old |
| loader extras (`_FreeExtras`, `loader.s:1709`) | frees extra segment banks | frees only banks the load allocated, never a hit's text banks |
| exit (`_Task_FreeBanks`, `task.s:283`) | frees the list | `xfree`, then the data banks |
| snapshot / vfork child exit | frees nothing | drops its own text reference |

**Where the code lives.**  Every hook above is core-bank code (`process.s`,
`task.s`, `bank.s`, `libc/alloc.s` are PUT into the core bank), and the core
has about 130 bytes free on main and 4 on feat/shared-libc.  The text table's
code -- lookup, register, reference, flush, reclaim -- lives in the far bank
behind `_FarSh_*` seams, as the libc pile registry does
(`far/loader.s:1069-1290`); the core keeps only the calls.  The plan budgets
each seam against the core's free bytes.

### 5.5 Phase A as built (feat/shared-text, 2026-10-03)

The plan (`2026-10-03-shared-text-phase-a-plan.md`) made six rulings against
5.2 and 5.3; this is what was built.

- **The pre-allocated bank is the DATA bank; exec and spawn keep their order.**
  No lookup moves ahead of the allocation: the bank spawn, exec and init's boot
  load allocate becomes the data segment's, so every rollback that frees
  `_ps_childBank` is unchanged.  Segment 0 (CODE in every shipped binary; it
  holds the entry) gets a bank of its own and becomes `TCB_CodeBank`.
  `_ldExtraBanks` is indexed by segment and lists only the banks the process
  owns; the core copies it whole into `TCB_BankList` through one helper,
  `_Ld_Bind`.
- **The key is fstat's `(st_dev, st_ino, st_ctime)` and no vnode is held.**  A
  held vnode would take one of 64 per cached text, make unmount answer EBUSY
  and keep an unlinked file's blocks; ctime moves on every write, truncate,
  chmod and link change.  `st_dev`/`st_ino` are FGX's 16-bit stat fields.  The
  loader asks `root_fstat` (the far bank's own fstat), which needed no new code:
  an fcc helper measured 430 bytes against 187 free.  ctime is in whole
  seconds, so the table declines a text whose change time is in [now - 1,
  now]: a later rewrite, stamped at or after now, can then never carry a
  cached key.  A change time after now (another clock's) is cached.
- **No ETXTBSY: step A2 is not done; writing a running program stays
  allowed** (confirmed by the maintainer).  2.11BSD refuses the write because its text
  is read from the inode and the swap area on demand; FGX's text is a complete
  in-memory copy made at load, so a write cannot change a running program, and
  the key's ctime keeps the cache from serving the old copy.  `vn_writechk`'s
  `VTEXT` test stays unreachable.
- **The table and its code live in the tty bank** (`src/kernel/tty/text.s`),
  behind KTTY slots 56-61 (FIND, REG, RECLAIM, UNREF, FORK, SET): the far bank
  had 187 bytes, the tty bank 2,329.  The per-pid array `_kTextOf` lives there
  too, so the core names a pid and never an address in that bank.  An entry is
  20 bytes (key 8, a bank per segment 8, pile 1, count 1, use stamp 2);
  `NTEXT` 16.
- **Only CODE segments are shared** (5.1 said CODE and RODATA; no tool emits
  RODATA today, and such a segment would get a private bank).
- **A program read through a legacy descriptor is never cached**, and neither
  is one that calls a libc pile it loaded privately (that pile would go when
  its process exits).
- **The merge into feat/shared-libc is a later step**: the core hooks cost 21
  bytes here (134 -> 113 free) and that branch has 4.

Beyond the rulings: a full table gives up its least recently used unused text
before registering, as `xalloc` takes `xhead` and `xuntext`s it; where
`xalloc` answers a table of running texts with `tablefull` and SIGKILL, the
program here simply loads into banks of its own.  The fork reference is taken
past every fork rollback, so a failed fork never holds one.

### 5.4 The dynamic-program binder (feat/shared-libc)

`ld_bind.c` patches import sites in the program's code.  Library banks are
system-wide, so the bytes are the same on every exec, but the binder should
patch only when the text is first loaded and skip on a hit.  This is a small
change made on feat/shared-libc once A1 reaches it.

## 6. Phase B -- the coremap

### 6.1 The map

`subr_rmap.c`'s shape over FGX memory: a dense array of `{m_size, m_addr}`
segments, address order, first-fit `malloc(map, size)`, coalescing
`mfree(map, size, addr)`.

- **Unit:** a 256-byte page.  A page number is `bank << 8 | page`, 16 bits,
  as BSD's `memaddr` is.
- **Rule BSD does not have:** no allocation crosses a bank boundary, since a
  65816 code or data segment cannot span banks.
- **Coverage:** the 56 pool banks, plus banks the Memory Manager grants on
  demand.  A grant enters the map as 256 free pages and goes back
  (DisposeHandle, through the existing block-table row) once all of it is
  free again.
- **Placement:** a whole-bank request (a data bank) takes a wholly free bank;
  a sub-bank request goes first-fit into banks already partly used, so whole
  banks stay free for data.  Short of space: free cached texts and piles
  (`xuncore`), then grant.
- **When no partly used bank has room,** a sub-bank request opens a fresh
  bank; that bank becomes whole again only when its last allocation is
  freed.  The map therefore counts allocations per bank, and the reclaim step
  (`xuncore`) prefers texts whose bank it would empty.
- `Bank_Alloc`/`Bank_Free` become whole-bank requests on the map, so their
  callers keep working.  These consumers of the bitmap itself are B2 work
  items: `Bank_MarkUsed` (`bank.s:288`, used by `modload.s:877` for a bank the
  boot loader filled); `Bank_Free`'s grant routing by block-table lookup
  (`bank.s:233`); `BANK_USER_COUNT` tied to `BankBitmap DS 7`
  (`include/loader.s:1125`); `tools/bank_pressure.py`, which parses that
  literal (`:29-31`); and the canary at `main.s:1512`.

### 6.2 Text placed by size

A text's segments are each placed at a page offset instead of $0000.

- **Toolchain (lands first):** `fgx_ld` emits a second relocation kind, a
  16-bit offset patch: "add segment T's load offset to the word at
  src:offset".  It covers every absolute reference to a code address --
  JSR/JMP/JML operands, `LDA #label`, `PEA label-1`, `DA` tables, and
  DATA->CODE function pointers.
- **The two-origin link generates them** (constraint 5: the assembler gives
  none).  `fgx_ld` links the program twice, moving ONE segment's origin from
  $0000 to $0100 each time; every byte pair that differs is classified, and
  the build fails on any difference that is not exactly +$01 in the high byte
  of a 16-bit word.  That refuses `label/2` or `label*2` tables and `#>label`
  in hand-written assembly; fcc emits no `#>`/`#^` immediates (none in
  `emit.c`), so the residual risk is hand-written `.s`.  Moving one segment at
  a time proves operands into other segments do not move.
- **Format:** a header flag says offset relocs are present.  A program without
  it loads at $0000 of its own bank, as today.
- **Loader:** allocate pages per segment, patch bank bytes as now, then add
  the bases.  On a text hit, apply only DATA's relocs against the text's
  recorded bases.

### 6.3 Kernel consumers moved onto the map

- **Screens:** each takes ~40 KB of pages (to $9800).  Four screens fit in
  about two and a half banks plus fill, instead of four banks.  The cost is
  real: the console addresses its buffers as absolute operands with only the
  BANK byte patched (`include/memmap.s:1844` `CON_CHARBUF`; sites such as
  `console_char.s:371` `STAL CON_CHARBUF,X`, patched through the hand-kept
  `console_bankpatch.s`), and virtual consoles switch bank per screen at
  identical offsets (`ttyv.s:1718`, `:1893`).  A screen at a page offset needs
  a per-screen 16-bit base at every one of those sites.  This is the last B4
  item and may be cut if its cost outweighs about one and a half banks.
- **Home bank:** a 2 KB unit per process, taken when the process first needs
  one, instead of one 64 KB bank held for 32.
- **Image swap:** 2 KB units straight from the map, instead of up to four
  whole swap banks.
- **Kernel heap growth:** 16 KB arenas instead of whole banks; the arena code
  takes a base and a size instead of assuming `bank:$0000`.  `_Sys_Free`
  tells a big block from a heap chunk by its offset -- "big blocks are the
  ONLY allocations at bank:0000" (`alloc.s:1145-1148`) -- so that test changes
  with the arenas.
- The home bank's stride is fixed by an `ERR FGX_KHOME_STRIDE-2048`
  (`task.s:1805`), and the image-swap math is already in 2 KB units within a
  bank (`task.s:2862-2864`); both take a unit base from the map instead.

### 6.4 Kernel heap, outside the map

The per-pid nameidata pool (26.5 KB, 32 pids x 2 slots x 414 B) is replaced by
nameidata allocated per lookup and freed on return.  That is Reno's per-call
lifetime (its nameidata is a stack local in each syscall), held on the heap
because FGX's kernel stacks cannot hold 414 bytes.

### 6.5 B1-B3 as built (feat/coremap, 2026-10-10)

The plan (`2026-10-10-coremap-phase-b-code-packing-plan.md`) made nine
rulings against 6.1 and 6.2, and execution found three more facts; this is
what was built.

- **The move is \$0101, and it is one extra assembly per code segment.**
  A move of \$0100 cannot refuse a lone high-byte operand (`#>label`): its
  byte reads one more and the opcode before it is unchanged, exactly like an
  address word.  With an odd move an address word reads exactly \$0101 more
  and a lone byte \$0001 more, so `fgx_offrel` (with `fgx_sites.diff_sites`)
  refuses it.  It found three: ensoniqplay and ntpplay stored their sound
  vector a byte at a time, now one 16-bit store.  Cross-segment addresses
  are not found by moving: `fgx_ld` writes every one itself
  (`FGX2_IMPORT_JSL`, `FGX2_FARCALL`, `FGX2_FARJUMP`, `FGX2_LONG_PTR`,
  `FGX2_ABS_OFFSET`) and records an offset relocation as it writes it, so
  the one-segment-at-a-time proof 6.2 wanted holds by construction.
- **The flag is per segment** (segment-table byte 5 bit 0,
  `FGX2_SEGF_PLACE`), set for every code segment up to \$FEFF bytes; a
  bigger one loads at \$0000 of its own bank.  An offset relocation is the
  4-byte entry with bit 7 of the target byte set (`FGX2_RELOC_ADDOFF`); a
  kernel without it refuses the image by the apple/fgx#522 check, so no
  ABI bump.  Over the volume: 248 of 275 code segments flagged, 30,868
  offset relocations, 121 more blocks.
- **The map lives in the core bank** (`src/kernel/bank.s`), because
  `Bank_Init` and the first `Bank_Alloc` run before the tty bank is bound.
  It has NPROC slots, 2.11BSD's own sizing (`param.c`: `CMAPSIZ NPROC`);
  pieces coalesce freely and the bank rule is enforced in placement.
  `tools/coremap_model.py` is its behaviour in Python.  The map cost 434
  core bytes, and its `Core_Alloc`/`Core_Free` seams 92 more.
- **Memory Manager grants stay outside the map**; a segment the map has no
  room for takes a whole bank.
- **Only a newly claimed text's segments are placed.**  The text entry is
  claimed before the load (`KTTY_TEXT_CLAIM`) and filled after
  (`KTTY_TEXT_FILL`), so pages always belong to an entry, never to a
  process; an entry whose load failed is freed when its reference goes.
  An entry records each segment's bank, page and page count (36 bytes).
- **Libraries are not placed** (libfgx's 3.7 KB keeps a bank).
- **Reclaim frees one unused text per retry until the allocation
  succeeds**, where `xuncore(size)` stops at the first text at least
  `size` big: with packed banks a whole-bank request needs a whole bank
  empty, and the retry is the test.  No per-bank counts.
- **Two loader facts placement exposed:** every relocation's patch
  address adds its source segment's page (a placed segment's relocations
  otherwise landed at its bank's first page), and fgx_bind's host-bound
  startup ends in a `JMP` into segment 0, which needs an offset
  relocation of its own.

Measured (MAME, 8 MB): at an idle prompt 28.2 of the 56 pool banks are
in use, from 46; after churn 29.3.  Exec time: `/bin/echo` 154 ms, a
dynamic `true` 92, a host-bound `true` 283 (149, 91, 280 before).  Bank
bytes free, main to feat/coremap: core 1,394 to 868, far 800 to 570, tty
1,052 to 721.  B4 (screens, home units, swap units, heap arenas) and B5
(nameidata per lookup) are the next plan.

### 6.6 B4 and B5 not built (measured, 2026-10-11)

Measured on main d10b9a48c (B1-B3 merged) at an idle prompt, before
planning: the B4 holders take five pool banks -- the screens of virtual
consoles 1-3 (console 0 uses a boot bank), the home bank (about 22 KB of
its 64 used) and one image swap bank -- and the kernel heap arenas are
boot-claimed banks below the pool, as is B5's nameidata pool.  B4 and B5
together would recover about two of the 56 pool banks; the screens step
about one, under the 1.5-bank bar 6.3 set for it.  B3 already leaves 28
banks free, and the process table (NPROC 32) runs out before the pool.
Closed at B3 (the maintainer, 2026-10-11).  Should the pool become the limit
again -- more processes, a bigger machine model -- 6.3 and 6.4 are the
design to pick up, with these numbers as the baseline.

## 7. Not in this spec

- **Packing data** (several processes in one data bank).  Blocked by
  constraint 3; a later spec, after the shared-libc cut-over settles how
  library cores are reached.
- **Swapping.**
- **Soft-frame stacks** stay a whole bank: the header gives no size, and a
  small stack without a bound would overflow silently.
- **libc piles** stay a whole bank each until the cut-over retires them.
- **Modules** keep their build-time placement (the shared module bank already
  packs ten).
- **Desk accessories** keep their Memory Manager blocks: the Desk Manager's
  `InstallCDA` takes a handle.
- **The ramdisk** (1 MB, made at boot) is unchanged here; whether it should
  be made on first use is a separate question.

## 8. Testing

Tests are the tail: one discriminating probe per mechanism, a mechanical check
wherever one can exist, and few new gate tests (the gate's seconds budget
means adding one retires one).

- **Build time, no gate seconds:**
  - the two-origin link (6.2), which fails on any difference it cannot
    classify as a 16-bit address;
  - `fgx_ld` refuses a CODE->DATA reloc in a program (zero today; this keeps
    it zero).
- **MAME probes, each shown to go red first:**
  - `texshare`: two SPAWNED instances of one program report the same code
    bank (task-table dump) -- a fork child shares its parent's bank already,
    so it proves nothing -- with a positive control that a different program
    gets a different bank, and a disabled lookup must fail it;
  - `textbusy`: writing a running binary answers ETXTBSY; after it exits, a
    rewrite runs the new code, not the cached copy;
  - `codepack`: two different small programs report the same code bank at
    different page offsets;
  - manyproc gains a bank-count needle: 21 sleeps hold about 22 banks for
    processes, not 42;
  - an ownership scan: every used page in the map has an owner (process,
    text, pile, kernel consumer), and spawn/exit churn leaves the free total
    where it started.
- **Measurements** against section 2.1's baseline, recorded in each step's
  commit.

## 9. Rollout

One branch per step, off main, each gated and merged before the next; main is
merged into feat/shared-libc after each.

| Step | What | Runtime change |
|---|---|---|
| A1 | the data segment in the pre-allocated bank, text table in the tty bank, per-TCB references, every free path of 5.3 (as built: 5.5) | shared text |
| A2 | not done: writing a running program stays allowed (5.5) | none |
| B1 | fgx_ld offset relocs generated by the two-origin link, header flag | none |
| B2 | the coremap behind Bank_Alloc/Bank_Free, whole banks only | behaviour-neutral |
| B3 | loader places flagged texts by size | code packing |
| B4 | screens, home units, swap units, heap arenas onto the map (one commit each) | kernel savings |
| B5 | nameidata per lookup | heap saving |

## 10. Questions for planning

These are decided by measurement during planning, not by taste:

- whether the Merlin32 listing's `Reloc` column marks every absolute operand
  (the two-origin check answers it either way);
- the kernel heap arena size (16 KB proposed), against Kmalloc's largest
  requests;
- `NTEXT`, against the number of distinct programs resident at a busy prompt;
- the byte cost of each core-bank seam (5.3), against the core's free bytes.
