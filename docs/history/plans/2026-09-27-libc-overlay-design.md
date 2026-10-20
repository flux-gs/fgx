# libc overlay segment -- 2.11BSD `ld -Z` for the libc pile

Status: design, 2026-09-27.  Branch `feat/libc-overlay`.  The maintainer chose the
private overlay and a declared member list (2026-09-27).

## 1. Why

A tool's libc is ONE 64 KB bank, seg2 (`tools/fgx2/seg2.link.s.in`).  After
function-level GC (#457) cron's selection is about 78 KB and crontab's about
73 KB, measured by the fit seg2 = 3.3 KB + 1.31 B per selection line (date,
30,689 lines -> 43,378 B; su, 45,357 -> 62,533 B).  Nothing in the selection is
dead: the largest parts are Reno's time zone code behind localtime (~15 KB),
printf, and the scanf family, whose `_innum` reaches atof and ldexp for every
sscanf.  cron is the first port whose libc does not fit; it will not be the
last.

The port is not trimmed to fit (scope reduction is not ours to make), and a
tool does not carry its own copy of a libc function (toolchain-first).

## 2. How 2.11BSD does it

Read, not remembered: `examples/2.11BSD/usr/man/cat1/ld.0`,
`examples/2.11BSD/usr/ucb/ex/Makefile`, `usr.sbin/cron/Makefile`.

- cron links with `LDFLAGS = -i` only: separate I&D gives text and data a 64 KB
  address space each, and on a PDP-11 all of cron and its libc fits the text.
- A program whose text does not fit is linked as automatic overlays.  `ld(1)`:
  "`-Z` Indicate the creation of an automatic-overlay format ... Repeated
  instances of -Z bracket the modules that will be loaded into a given overlay.
  Modules before the first -Z or after the concluding -Y will be loaded into
  the non-overlaid text (base) area ... The loader creates a small entry
  interface in the base segment for each subroutine in an overlay.  This
  interface ("thunk") arranges for the correct overlay to be present before the
  actual routine is entered."  ex, csh, tcsh, uucp, f77, pcc, lint, jove, rn and
  hack are built this way.
- The UNIT is the module -- an object file -- and the program's Makefile names
  them.  libc itself stays in the base: ex's link line ends `-Y ex_data.o ...
  printf.o strings.o -lc`.

FGX already has the program half: a tool's own translation units spread over
seg0/seg3/seg4 (`seg3_tus`, `seg4_tus`) and reach each other through
`FGX2_FARCALL`, all resident.  What 2.11BSD never needed is the libc half,
because a PDP-11 libc fit its base.  This design gives the libc pile the `-Z`
mechanism: named modules move to another text segment, and the linker
generates the entry interface.

## 3. What exists (read 2026-09-27, main 30f869cc9)

- **Pile calls.**  A call between libc members is
  `PHK / PEA ret-1 / PHK / PEA target-1 / RTL`: a JSL-shaped frame whose target
  bank is the CALLER'S (PHK).  Callees return with RTL.
- **Near references** from pile code are `JSR _fcc_*` (fcc's runtime helpers),
  `JMP _fcc_stkoflow`, one `JMP _libc_strerr` (toolchain/lib/libc.s), and
  `JSL SYS_TRAMP` (a bank-0 absolute).  Every code bank already carries its own
  `fcc_runtime.s` for the first kind (seg0, seg2, seg3).
- **libc.s holds no writable state** -- `DS 0` and inline DFB constants only --
  so a second copy of it changes nothing a process can observe.
- **Exports.**  A pile function carries an `FGX2_EXPORT` row; libc.s's entries
  carry `LIBC_EXPORT`.  `FGX2_FARCALL` from TU code resolves a name against
  every segment's exports (fgx_ld), and fgx_ld dies on a duplicated export.
- **Function pointers.**  `&function` is a hidden `FGX2_LONG_PTR` in the DATA
  segment (fcc `emit_fpr_addr_func`), resolved and relocated per process.
- **Sharing.**  seg2 is a LIBC segment: content-keyed {size, checksum}, one
  loaded copy per key, and it must carry zero relocations (fgx_ld's LIBC gate).
  `TCB_LibcBank` holds its one bank.
- **The GC.**  `toolchain/src/ld/fgx_gc.py` reads the link files, treats each
  `FGX_SECT`...`FGX_ENDS` unit as a node that defines its column-1 labels and
  references every identifier in its rows, and keeps what the roots reach.
- **The private library segment.**  `tools/fgx2/seg3libs.link.s.in` is an
  ordinary CODE segment for per-tool library piles (resolv, termlib, curses):
  its own fcc_runtime.s copy, data in seg1 through seg1_layout.s, relocations
  allowed.
- **Members.**  The libc archive's unit is the member (`toolchain/lib/
  libc.fgxa/index.json`, `id` == source stem: `ctime`, `syslog`, ...).  fgx_ar
  concatenates the selected members into `libc.sel.s` with no boundary marker.

## 4. Design

### 4.1 The declaration

A tool names the libc members to overlay in the manifest:

    { "name": "cron", ..., "libc_overlay": ["ctime", "syslog"] }

A member is the unit, as a module is for `-Z`: its static functions and data go
with it, so the only names crossing the boundary are exported ones.  A tool
without the key links exactly as today, byte for byte.

### 4.2 The partition (fgx_gc)

fgx_gc already knows every section, what it defines and what it references.
With a member map for the selection (section -> member id; fgx_ar writes it
beside libc.sel.s), it computes:

- **O**, the overlay: the declared members, plus every selected member that
  only they reach.  A member reached both from O and from outside O stays in
  seg2.
- **S2**, seg2: everything else the tool reaches.

and REFUSES the link unless O is upward-closed: no section in S2 references a
label defined in O.  The refusal names the S2 member, the O symbol it
references, and the member to add to the list.  That is the property that lets
seg2 stay shared and reloc-free: nothing in it ever needs to find the overlay.

fgx_gc writes `libc.sel.gc.s` (S2's sections, as now) and `libcovl.gc.s`
(O's).  Data sections are unaffected: they stay in seg1, kept by reachability
from both.

### 4.3 The overlay segment

A new per-tool CODE segment, from a template modelled on seg3libs.link.s.in
(`tools/fgx2/segovl.link.s.in`):

    macros.s, seg1_layout.s
    libc.s                   near-referenced (_libc_strerr); no state
    fcc_libc_shims.s         as seg2 carries it; stateless
    libcovl.gc.s             O's sections, unchanged pile code
    libcovl_thunks.s         generated: the entry interface (4.4)
    fcc_runtime.s            the JSR _fcc_* helpers, as every code bank

Nothing is recompiled: the same pile code runs from another bank.

### 4.4 The thunks

For every exported symbol defined in S2 or libfgx that O's sections reference,
fgx_gc writes one line into `libcovl_thunks.s`:

    strlen          FGX2_FARJUMP strlen

`FGX2_FARJUMP` is `JML $000000`, resolved exactly as `FGX2_FARCALL` resolves a
JSL: offset patched by fgx_ld, bank byte relocated at load.  The relocation
patches the OVERLAY, which is private, so the LIBC gate is untouched.

An O call site is unchanged -- `PEA strlen-1` finds the thunk, which is in its
own bank -- and the frame it built is the JSL-shaped frame seg2's strlen
returns through: the thunk jumps without pushing, and strlen's RTL comes back
to the caller in the overlay.  Four bytes a symbol.

A symbol the overlay's own copies define -- libc.s's vfork, getpid, setjmp;
the shims; the runtime -- gets no thunk: the overlay calls its own copy, which
is correct because those files hold no state.

Calls INTO the overlay come only from TU code, which reaches every libc
function through FGX2_FARCALL already; O's FGX2_EXPORT rows move with its
sections, so those calls resolve to the overlay.  Function pointers to O are
data-segment pointers and resolve the same way.

### 4.5 fgx_ld

- `FGX2_FARJUMP`: recognised, patched and relocated as `FGX2_FARCALL` is.
- `LIBC_EXPORT` is an export only in a LIBC-kind segment.  The overlay's copy of
  libc.s must not re-export seg2's names; its entries are reached near, from
  inside the overlay, or not at all.
- The overlay is kind CODE.  The existing rules (at most 9 segments, the LIBC
  one last when there are 9) are unchanged.

### 4.6 The build (tools/ninja/gen.py)

- `materialize_links`: when `libc_overlay` is set, instantiate the overlay
  template as the next free segment and add it to the manifest.
- The fgx_gc edge passes the list (`--overlay ctime,syslog`) and gains the two
  outputs; the overlay's merlin edge depends on them and on seg1_layout.s.
- fgx_ar's select edge writes the member map.

### 4.7 Kernel and loader

None.  The overlay is an ordinary CODE segment: it takes a TCB_BankList slot
and costs the process one bank, unshared.  cron, a daemon, holds it for its
uptime.

### 4.8 What goes wrong, and what is said

| Case | Answer |
|---|---|
| a listed member the tool does not select | refused: "`x` is in libc_overlay but not in this tool's libc" |
| O not upward-closed | refused, naming the S2 member, the symbol and the member to add |
| seg2 still over 64 KB | Merlin's refusal, preceded by fgx_gc's estimate of both banks' sizes and the heaviest members that could be listed |
| the overlay over 64 KB | Merlin's refusal on the overlay's link file |
| a duplicated export | fgx_ld's existing refusal |

## 5. Testing

Tests are the tail, and the gate's seconds budget has no room.

- **fgx_gc --self-test** gains the partition cases: a closed list is split;
  a list that S2 calls into is refused with the right names; a member reached
  from both sides stays in seg2; the thunk list is exactly the S2 exports O
  references; an unselected member is refused.
- **Byte identity**: every `bin/*.bin` of a tool without `libc_overlay` is
  unchanged (shasum before and after).
- **The integration is cron itself**: cron and crontab link, `crontab -l` and
  `-e` work, and a crontab entry runs -- on FGX, headless.  One smoke manifest,
  not in the gate.

## 6. Not in this design

- Sharing the overlay between processes: a ROADMAP follow-up for a later
  memory-efficiency pass (Toolchain / self-host, "libc overlay banks are
  private").
- Choosing the members automatically.
- Overlays for the optional libraries (termlib, curses, resolv) or for TU code,
  which already has seg3/seg4.
- A thunk in the other direction (seg2 into the overlay).  Upward closure is
  the rule that makes it unnecessary.
