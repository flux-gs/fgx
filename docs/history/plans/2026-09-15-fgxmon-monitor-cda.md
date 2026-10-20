# `fgxmon`: a kernel monitor that runs as a desk accessory

Status: designed, not implemented.  ROADMAP item: Kernel / memory, "A monitor
desk accessory".  Depends on the desk accessory support in
`2026-09-15-classic-desk-accessories.md`, which landed 2026-09-15.

## 1. What it is for

The Ctrl-OA-Esc menu is served in the firmware's interrupt path, and FGX never
sets the firmware busy flag, so the menu opens FROM ANYWHERE: mid-syscall,
mid-driver, with every task stopped, with the shell wedged, with the console
invisible.  A desk accessory is therefore the one program on this system that
runs when nothing else can.

That buys three things no existing tool gives:

- **It works on real hardware.**  Every runtime measurement FGX has ever made
  came from a MAME Lua probe.  A IIgs with a real drive has no such thing.
- **It works when the machine is wedged**, which is when the harness can only
  dump memory blindly and guess what the addresses meant.
- **It is interactive and needs no rebuild.**  Adding a kernel probe today
  means editing source, rebuilding, and re-running a scripted boot of minutes.
  Reconstructing the interrupt vectors, os_kind, the Super Hi-Res settings and
  the console render state during the C3 work took about ten such runs; one
  panel would have shown all of it at once.

It does not replace the gate or the harness, which stay the automated,
scriptable thing that can fail a build.  This is the instrument for one wedged
machine in front of a person.

## 2. Two audiences, one format

**The maintainer, 2026-09-15: the tool is for people AND for machines, and the values it
prints must be comprehensible to a person.**  Both follow from one decision:

- There is ONE rendering.  What a panel shows on screen is what the report
  contains, byte for byte, minus the cursor.  A second, "machine" format is a
  format that rots -- the two diverge the first time a field is added to one of
  them, and the parser then reads a fiction.
- The rendering is COLUMNAR AND STABLE: a `#` comment line carries the schema
  version, the kernel build id and the sample tick; each section opens with
  `# section <name>`; each table opens with a header row naming its fields;
  every row has fixed field positions.  `awk '{print $2}'` works, and so does
  reading it.
- **A value is printed the way a person understands it, with the raw value
  beside it when the raw value is what you would type into a debugger.**  The
  rules in section 4 are binding on every panel.

## 3. The interface

Eighty columns by twenty-four lines of text -- the menu has already switched
the machine to text, and the desk accessory has the screen to itself.

    +----------------------------------------------------------------------------+
    | fgxmon 1  kernel 9F03  up 00:04:11  ticks 15062  heartbeat running   [?]help |  title
    +----------------------------------------------------------------------------+
    |                                                                            |
    |  the panel: one screen of rows, scrolled with the arrow keys                |  body
    |                                                                            |
    +----------------------------------------------------------------------------+
    | 3 tasks sleeping, 1 stopped -- pid 7 stopped with no stopper                |  findings
    | [t]asks [w]ait [l]og [c]onsole [v]ectors [b]anks [d]evices [m]emory [s]ave  |  keys
    +----------------------------------------------------------------------------+

- **One key per panel**, always visible on the key line.  `Esc` leaves, which
  is what every other CDA does and what DocVue's documentation tells people.
- **Arrow keys and space** scroll; `<` and `>` page a table sideways when it
  has more fields than fit.
- **`r`** re-samples (the panels are snapshots; a live panel that changes under
  you while you read it is worse than one you refresh deliberately).
- **The findings line** is the point of the tool.  Each panel names, in a
  sentence, what looks wrong in what it just sampled -- a flag set with nothing
  to consume it, a task stopped with no stopper, a vector pointing somewhere
  unexpected, a heartbeat that did not advance between two samples.  A person
  reads the sentence; the report carries the same sentence as a `# finding`
  line, so a parser can collect them without knowing every rule.
- **`s`** writes the whole report -- every panel, not just the visible one --
  into the buffer section 6 describes.

## 4. How values are printed

Binding on every panel.  The aim is that nothing on screen needs a lookup
table in the reader's head.

| Kind | Printed as | Not |
|------|-----------|-----|
| task state | `S sleeping`, `T stopped`, `R running`, `Z zombie` -- ps(1)'s letters, and the word.  ps prints `R` for both READY and RUNNING; the monitor says `R runnable` and `R running`, which is more precise without contradicting it | `2` |
| wait channel | `WCHAN_KBD (console keyboard)` | `$FF01` |
| a wait channel that is an ADDRESS | the object it is: a channel in $0800-$0BFF is a TCB, so `TCB of pid 4 (sh)` | `$0840` |
| a flag | its name, and `set`/`clear`; a word of flags as the names that are set | `$0041` |
| a pid | the pid and its command name, as ps(1) prints it | a bare number |
| a device | `19 /dev/cda` | `19` |
| a bank | `$7C kernel`, `$08 far`, `$12 DOCVu (desk accessory)` | `$7C` |
| an address | `$7C:EDB2` -- bank, colon, offset -- and the symbol when the anchor names it | `8121778` |
| ticks | the count, and the time: `15062 (4m 11s)` | ticks alone |
| an age | `3.2 s ago` | a tick stamp |
| bytes | `45,801 bytes (44.7 KB)` over 1 KB | a bare byte count |
| something it cannot decode | the raw value and the word `unknown` | a guess |

Two further rules, both learned the hard way in this repo:

- **Never invent a name for a value the tool does not recognise.**  A wrong
  name reads as a finding; `unknown` reads as what it is.
- **A count that should be moving is sampled twice** and reported as moving or
  stopped, rather than as a number the reader has to remember and compare.

## 5. What it must not do

- **It must not call into FGX.**  No syscalls, no kernel services, no module
  entry points: the kernel may be frozen half-way through the very structures
  the monitor is reading.  It reads memory, uses the ROM's Text Tools to write
  and the keyboard hardware to read, which the C2 test accessory already
  proved works.
- **It must not allocate while frozen.**  Its buffers are reserved when it is
  LOADED, the way loadcda already reserves a block, so a wedged machine's
  allocator is never asked for anything.
- **It is read-only.**  Any future poke mode is a separate increment, behind an
  explicit mode, and prints what it will write and where before it writes.
- **It must never read I/O space at large.**  Reading $C000-$CFFF has side
  effects: walking $C080-$C08F remaps the language card, $C050-$C05F changes
  the video mode.  This cost a whole misdiagnosis on 2026-09-15, when a Lua
  dump that had just walked those switches read the monitor ROM as zeros and
  made the language card look guilty for garbled text that was a compiler
  defect.  The memory panel REFUSES the I/O window and the W5100's window by
  address, and the status panels read only the specific status switches they
  name, one at a time.
- **It must know which kernel it is looking at.**  See the anchor below.

## 6. Getting the report off a frozen machine

A frozen machine cannot write a file: there is no VFS to call.  So `s` copies
the report into a buffer that `loadcda` registered when the accessory was
loaded, and a userland command prints that buffer once there is a shell again.
A wedge then leaves a readable report behind instead of a screen someone
photographs.

The same buffer is what makes the tool usable from the harness: a test can read
the buffer through the device rather than scraping the screen.

## 7. What is reachable without help, and the anchor for the rest

**More is relocation-invariant than I assumed, and D1 should exploit it.**
Three handles hold across every build:

- **`$00:032C`**, the live kernel bank byte the loader writes, with its magic
  at `$032D`.  The far bank is that byte plus one and the tty bank plus two, so
  the console state is reachable from it.
- **`$00:032E`**, the module jump table, whose header carries the ABI version
  and **the running kernel's build id** (`MOD_JT_CORE_BUILD`).  The monitor can
  therefore check which kernel it is looking at with no kernel change at all.
- **The kernel direct page**, `$0900 + (pid << 8)`, so pid 0's copy is at
  `$00:09A4` for `_schedTblPtr`.  The scheduler table, the log buffer
  (`_kLogBufPtr`, DP $B0) and the chardev table (`_cdTablePtr`, DP $30) are all
  reached through DP pointers, which do not move.

So the task, log and device panels need no generated map: they need the DP
pointers and the published layouts.  What DOES need one is every kernel-bank
STATIC -- the deferred-work flags, the log cursor, `_kVcActive`,
`_chardev_count`, `_screenOwner` -- because those are listing-scraped offsets
that move whenever the kernel is edited, and a module gets them today only
through `tools/gen_kernel_exports.py`.  The module name of a bank needs one
too: `_modBankTab` is a byte per ordinal, and the ordinal-to-name map exists
only at build time in `tools/gen_modplace.py`.

So the kernel exports a small DEBUG MAP at a fixed address in bank 0, beside
the anchors modules already use:

- a magic word and a schema version;
- the kernel build id (`KERN_BUILD_ID`, which cda.mod is already locked to);
- the kernel, far and tty bank bytes;
- for each table the monitor reads: its address and its entry size.

It is GENERATED, by the script family that already writes each module's
`kernel_exports.s`, and the build fails if an entry does not resolve.  A map
maintained by hand is the drift this project has been bitten by before.

`fgxmon` refuses to decode anything when the magic, schema or build id does not
match, and says so in words: what it found, what it expected.  The build id to
compare against is the one the jump table already publishes, so the refusal
works before the map exists.  It still offers the panels that need no kernel
knowledge -- the memory viewer and the vector panel -- because those are true
of the machine rather than of the build.

## 8. The panels

Ordered by what has cost this project time.

1. **Tasks.**  One row per task: pid, ppid, state, wait channel, the kernel and
   user stack pointers, direct page, bank, and command name.  The findings line
   calls out a task stopped with nothing to continue it, which is the shape of
   apple/fgx#253.
2. **Wait and deferred work.**  Every flag an interrupt sets for someone else
   to consume, with the count of sleepers on each wait channel beside it.  A
   flag set with no sleeper, or a sleeper on a channel nothing wakes, is a hang
   with a name.
3. **Log.**  The kernel log ring (`KMEM_LOGBUF_SIZE`, 4 KB), oldest to newest,
   paged.  When the console is dead or the shell is gone, this is the last
   thing the kernel said, and `dmesg(1)` cannot run to show it.
4. **Console.**  Active virtual console, render state, the task that owns the
   screen, the SCB and palette values, the video soft switches.  The C3
   invisible-console bug was exactly this panel's contents.
5. **Vectors.**  IRQ.VBL, IRQ.SOUND, the GS/OS entry, os_kind, the state
   register, shadowing -- with a note when one does not point where FGX put it.
6. **Banks and modules.**  Which module is in which bank, the kernel, far and
   tty banks, the desk accessory blocks, and free space.
7. **Devices.**  The chardev registry: index, name, the module that owns it.
8. **Memory.**  A bank:offset hex and ASCII viewer, with the refusals above.

## 9. How it is built

FGX's toolchain emits FGX2 executables; a desk accessory must be OMF.  So the
first cut is assembly wrapped by a small OMF packer -- the throwaway Python one
written for the C2 test accessories does exactly this -- and a toolchain OMF
output is the thing to do IF the tool earns it.  This is the one piece of the
design with no precedent in the tree, and it is deliberately the smallest part
of the first increment.

## 10. Increments

- **D1: it runs.**  The OMF packer, the screen frame, the key handling, the
  memory viewer and the vector panel, plus the build-id refusal against the
  jump table.  Needs no kernel change.  Check: it loads from `/usr/fgx/cda`,
  opens from the menu, reads a known address, and Quit returns to a repainted
  console.
- **D2: tasks, through the direct-page pointers.**  The task panel and the wait
  channels, reached through `_schedTblPtr` and the TCB table -- still no kernel
  change.  Check: a task asleep on the keyboard shows as sleeping on
  `WCHAN_KBD` with its command name, on a machine where `ps` agrees.
- **D3: the debug map, and what only it can give.**  The deferred-work flags,
  the log cursor, the console statics, module names by bank.  Check: the log
  panel's last line matches `dmesg(1)`'s last line.
- **D4: the report buffer and its userland reader.**  Check: a report saved
  from the accessory prints after Quit and parses field-for-field.
- **Later, separately:** a poke mode; a watch list; a mini disassembler.

## 11. Open

- The byte budget for the accessory and for the report buffer (the maintainer's call).
- Whether the harness should press the chord, which it cannot do today -- every
  desk accessory measurement so far has been an ad-hoc Lua script.
- Whether a panic recorder is worth it: once FGX is in the Monitor the menu
  cannot open, so a crash is exactly the case this tool cannot reach.

## Appendix: the state that exists today, and how it is spelled

Read from the tree on 2026-09-15.  A symbol that moves is the debug map's
problem, not the monitor's.

**Tasks.**  TCBs are a kernel-bank array at offset $0800 (`FGX_TASK_TBL
$020800`, `include/kernel.s:129`), `NPROC` = 12 slots (`include/config.s:18`)
of `TCB_SIZE` = 64 (`kernel.s:786`); there is no slot for pid 0, so pid =
slot + 1.  `TCB_Status` is at +2, `TCB_ParentID`, `TCB_DirectPage`,
`TCB_DataBank` and `TCB_SavedS` follow in the block at `:734-786`.  The
scheduler entries are a heap table found through `_schedTblPtr` (DP $A4,
`include/dpmap.s:285`), `SE_SIZE` = 32, slot = pid - 1, with `SE_KernSP` +0,
`SE_WaitChan` +12, `SE_PGroup` +14, `SE_Flags` +16, `SE_UserSP` +18,
`SE_UserDP` +20, `SE_WakeTime` +24 and `SE_SoftBank` +31 (`kernel.s:983-1037`).
The controlling tty is `SE_Flags` bits 8-10, as index + 1.

**Names.**  A separate heap table, `_procNameTblPtr` (`include/memmap.s:1506`),
16 bytes per pid, slot = pid << 4 (`src/kernel/task.s:353-364`).  The working
directory is parallel, through `_fsCwdPtr` (DP $6C), 128 bytes per pid.

**States** (`include/kernel.s:850-856`): `TASK_UNUSED` $0000, `TASK_READY`
$0001, `TASK_RUNNING` $0002, `TASK_BLOCKED` $0003, `TASK_ZOMBIE` $0004,
`TASK_STOPPED` $0005.  ps(1) maps 1 and 2 to `R`, 3 to `S`, 4 to `Z`, 5 to `T`
and anything else to `?` (`src/userland/ps/ps.c:28-34`).

**Wait channels** (`include/kernel.s:874-930`): `WCHAN_KBD` $FF01,
`WCHAN_SOCK` $FF02, `WCHAN_TIMER` $FF03, `WCHAN_PIPE` $FF04, `WCHAN_SELECT`
$FF05, `WCHAN_VFORK` $FF06, `WCHAN_PTY` $FF07, `WCHAN_PAUSE` $FF08,
`WCHAN_LBOLT` $FF09.  **Any other channel is an object address**, and a value
in $0800-$0BFF is a TCB -- which is what lets the monitor say "waiting on the
TCB of pid 4" instead of printing a number.  `tools/check_wchans.py` guards
the set.

**The log ring.**  The buffer is heap, reached through `_kLogBufPtr` (DP $B0,
`include/dpmap.s:304`), `KMEM_LOGBUF_SIZE` = $1000 (`include/memmap.s:621`),
with `_kernLogHead` (next write) and `_kernLogWrap` (`memmap.s:637-639`).
Oldest-to-newest is head-to-end when wrapped, then 0-to-head -- the order
`_Sys_Dmesg` uses (`src/kernel/syscall.s:7981-8033`).  dmesg(1)'s man page
still says the ring holds 2 KB.

**Devices.**  The chardev table is reached through `_cdTablePtr` (DP $30),
`CHARDEV_MAX` = 24 entries of 24 bytes: `CD_NameLen` +0, `CD_Name` +1 (15
bytes, NOT NUL-terminated), `CD_OpsLo` +16, `CD_OpsBank` +18 (the owning
module's bank), `CD_Minor` +19, `CD_OpenCount` +20, `CD_TtyOff` +21,
`CD_Flags` +23 (`include/chardev.s:28-172`).  **The index IS the device
number**, and a descriptor carries it with `CDIDX_NDELAY` $80 in bit 7.
`_chardev_count` is a kernel-bank byte (`memmap.s:1176`).

**Modules.**  `_modBankTab` is one byte per ordinal (`src/kernel/modload.s:119`),
the value being the allocated bank and 0 meaning not loaded; ordinal 0 is the
shared bank.  There is no runtime name table -- the names live in
`tools/gen_modplace.py:92`, which is why the map must carry them.

**Console.**  `CON_VT_STATE` is the first far-bank static
(`src/kernel/far/far.s:579-583`); the far bank is the live kernel bank + 1 and
the tty bank + 2 (`include/memmap.s:566-582`).  `VT_RENDER_STATE` is at +$5A
with 0 immediate, 1 batch, 2 deferred, 3 suspended (`include/console.s:191`);
the per-VC block below it holds the cursor, colours and viewport.  `_kVcActive`
and `_kVcBank` are core-bank (`memmap.s:412-413`), and `_screenOwner` at
`:1488` is the pid holding SYS_SCREEN_CTL.

**Deferred work.**  `_kKbdRingCount` (`memmap.s:125`), `_kVcSwitchReq` (`:550`),
`_kConRestoreReq` (`:559`), `_kAlarmFiredAny` (`:889`), `_kSockWakePending`
(`:1476`), `_kYieldReq` (`src/kernel/toolbox.s:906`), `_kLboltDue` (`:918`),
`_nTimerSleepers` (`src/kernel/sched.s:1119`).  `_kTtySigPend` still exists but
its writer was removed (`src/kernel/signal.s:352-359`), so the panel must not
list it as live state.

**Anchors and the build lock.**  `$00:032C` with its magic $4B at `$032D`
(`memmap.s:1905-1906`); the jump table at `$032E`, whose header carries
`MOD_JT_ABI_VER` and `MOD_JT_CORE_BUILD` (`include/modules.s:37-48`).
`KERN_BUILD_ID` is derived from sampled kernel addresses, published there by
`_JT_Init`, and `Mod_Load` already refuses a module whose header disagrees --
the same lock, and the same refusal, the monitor needs.

**Units.**  `_kSystemTicks` is 32 bits at 60 Hz (`memmap.s:105-111`),
`QUANTUM_TICKS` 4 and `LBOLT_TICKS` 60 (`kernel.s:1677-1684`).  uptime(1)
derives its figure from the same counter; vmstat(1) prints no time at all.
