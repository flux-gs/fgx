# kprobe — non-perturbing kernel probing for FGX under MAME

## The problem it solves

Some FGX bugs are **layout/size-sensitive Heisenbugs**: adding *any* instrumentation
— a `putc` marker in a userland binary, a `klog` line in the kernel — shifts the
code/data layout and the bug changes or disappears. Editing source IS the
perturbation, so you can't `printf`-debug them.

The canonical example is the sed(1) "read returns 0" bug
(`docs/RESUME-2026-06-23-sed-read-heisenbug.md`): a large FGX2 program's first
`read()` spuriously returns EOF, and any kernel code-size change makes it work.

`kprobe` observes the **unmodified** disk image through MAME's hardware debugger,
so the Heisenbug reproduces exactly. Two front-ends:

| tool | use | output |
|---|---|---|
| `kdebug.sh` | **interactive** — you drive MAME's debugger live | debugger window |
| `kprobe.py` | **headless/scripted** — set wp/bp, capture to JSON | parsed event table |

Both leave the binary untouched. `kdebug.sh` works today; `kprobe.py`'s headless
*capture* channel is still being finished (see § Status).

---

## If you must add guest code: rare branch, not hot path

Everything above exists so you do not have to. But sometimes the question needs
a value no watchpoint can reach, and you add a latch to the kernel. Then the
only question is *where*, and apple/fgx#377 measured the answer over eleven
passes.

**The axis is how often the probe's code runs. It is not which bank it lives
in.**

| probe site | how often it runs | fault |
|---|---|---|
| `watch_addrs`, `capture_writes` | no guest code at all | intact |
| `_FarSh_Gsignal` | once in the entire run | intact |
| `@disp_stop` | once per actual stop | intact |
| `_Kill_Apply` | once per signal | intact |
| `_Con_Close` | once per close | intact |
| `_FarSh_CurPgrp` | twice per gate evaluation | **moved** |
| `kc_gsignal` counters | once per gate firing, in the gate's own file | **cured** |
| the `ttbgread` body | every read | **cured** |

**A plausible rule that was wrong.** This first read as "core-kernel probes
survive, tty-bank probes perturb", and it had a 4-for-4 against 3-for-3 split
behind it, which is exactly enough evidence to feel settled. Then
`_FarSh_CurPgrp` perturbed, and it is core-side. It is called twice per gate
evaluation on a gate that runs on every read, so it is hot. The bank was a
coincidence of where the hot code happened to sit. Frequency explains every
case, including the ones the bank rule got right by luck.

**So, before adding a latch, count.** How many times will these instructions
execute in the whole run? Single digits is affordable and has never moved a
fault here. Once per read is not, and no amount of keeping the probe small
rescues it.

**Two corollaries worth having in advance.**

A probe *inside the expression under test* does not merely change timing, it
changes the shape of the code being evaluated. In #377 that made a three-term
`&&` chain stop misbehaving, which for several passes read as evidence about the
predicate rather than about the instrumentation.

A probe that makes the fault vanish is a measurement, not a wasted run. It
bounds the window. Record it as a result and pick a rarer site, rather than
shrinking the same probe and trying again.

---

## Kernel relocation (read this first)

The kernel **assembles at ORG $02** but the loader **relocates it to a runtime
bank** (commonly **$7D** on the 8 MB build). So a kernel symbol listed at
`02/F3AE` lives at `$7D:F3AE` at runtime.

The live bank is published by the loader at the bank-0 anchor **`$00:032C`**
(with magic `$4B` at `$00:032D`) — the same anchor the `fgxdebug` plugin reads.
In the debugger: `print b@32C`. `kprobe.py` resolves it automatically (phase 1).

### Handy address map (kernel bank = `$7D` shown; confirm with `print b@32C`)

| symbol | assembly | runtime ($7D) | notes |
|---|---|---|---|
| `_fsFileState` | `$02F3AE` | `$7DF3AE` | FST_* singleton (64 B) |
| &nbsp;&nbsp;FST_InUse | +0 | `$7DF3AE` | 1 B |
| &nbsp;&nbsp;FST_StorageType | +1 | `$7DF3AF` | $10 seed/$20 sap/$30 tree |
| &nbsp;&nbsp;**FST_Eof** | +2 | **`$7DF3B0`** | 3 B, 24-bit EOF |
| &nbsp;&nbsp;**FST_Pos** | +5 | **`$7DF3B3`** | 3 B, 24-bit position |
| `_fsCurOwnerFcb` | `$02F598` | `$7DF598` | 3 B long-ptr to owning FCB |
| FCB (heap) | — | (deref above) | FCB_Eof@+7, FCB_Pos@+10 (3 B each) |

Resolve any other kernel symbol from the Merlin listings:
`grep ' _Symbol' build/fgx_S01_KernelMain_Output.txt` → the `BB/AAAA` column is
`assembly_bank/offset` (EQU/ENT rows have no address column — use the offset of a
nearby labelled global).

---

## Interactive debugger — `kdebug.sh`

```
./tools/mame_test/kdebug.sh                          # boot to shell; type cmd yourself
./tools/mame_test/kdebug.sh "sed s/ProDOS/RiffyDOS/ /docs/shell.txt"   # autoboot it
```

Opens the IIgs screen + the MAME debugger console. The disk is used unmodified.

### Recipe: "what corrupts the file position for sed?"

Arm the watchpoint **after boot** so boot-time file I/O doesn't flood it:

1. Launch with **no** autoboot: `./tools/mame_test/kdebug.sh`
2. In the debugger console, let it boot: `go` (wait for the `fgx:/root/#` prompt
   in the IIgs window).
3. Confirm the live bank, then watch the position (3 bytes, on write):
   ```
   print b@32C            ; -> e.g. 7D  (the live kernel bank)
   wpset 7DF3B3,3,w       ; break whenever FST_Pos is written  (use <bank>F3B3)
   go
   ```
4. In the **IIgs window**, type: `sed s/ProDOS/RiffyDOS/ /docs/shell.txt`
5. On each break the debugger stops at the writing instruction. Inspect:
   ```
   print curpc            ; who wrote it (full PB:PC)
   dw 7DF3B0              ; current Eof   (expect the file size, e.g. 09FA)
   dw 7DF3B3              ; new Pos
   ```
   The bug is the write that leaves `Pos >= Eof` *before* the first `read()`.
   Note `_fsCurOwnerFcb` (`dw 7DF598`) and whether `_Fs_SwitchToFCB` ran.

Other useful breaks: `bpset <Fs_ReadN runtime addr>` to stop at the bulk read and
inspect the singleton; `wpset 7DF598,3,w` to watch the FS-owner pointer change.

### MAME debugger quick reference (65816)
`go`/`g` resume · `s` step · `bpset addr[,cond]` · `wpset addr,len,r|w|rw[,cond]` ·
`bplist`/`wplist` · `bpclear`/`wpclear` · `print <expr>` · `dw/db addr` dump ·
memory access in exprs: `b@addr` byte, `w@addr` word, `d@addr` dword (program
space) · registers: `curpc`, `pb`, `db`, `a`, `x`, `y`, `s`, `d`.

---

## Headless harness — `kprobe.py`

```
python3 tools/mame_test/kprobe.py probes/<name>.json
python3 tools/mame_test/kprobe.py <name>            # -> probes/<name>.json
python3 tools/mame_test/kprobe.py probes/<name>.json --window
```

### What it does
1. **Phase 1**: boots once with the `fgxdebug` plugin to read the live kernel
   bank (cached by disk mtime).
2. Resolves each probe's kernel symbol → concrete runtime address.
3. Generates a MAME `-debugscript` that sets the watchpoints/breakpoints and, on
   each hit, appends the captured `fields` to a **circular scratch ring** in RAM.
4. **Phase 2**: boots with the debugscript + plugin (autoboots the `command`);
   the plugin dumps the ring; kprobe parses + prints the events.

### Probe config schema (`probes/*.json`)
```jsonc
{
  "name": "sed_pos",
  "command": "sed s/ProDOS/RiffyDOS/ /docs/shell.txt",  // autobooted
  "timeout_s": 25,
  "max_events": 48,            // circular ring capacity (keeps the LAST N)
  "scratch": "0x008000",       // optional scratch RAM base for the ring
  "watch": [                   // hardware watchpoints
    { "sym": "_fsFileState",   // OR  "off": "F3B3" (+ optional "bank")
      "off": "F3B3",           // kernel-bank offset (EQUs don't resolve by sym)
      "len": 3, "type": "w",   // r | w | rw
      "labels": ["whoPC", "byteVal", "curEofLo"],
      "fields": ["{PC}", "{VAL}", "{kbb:0xF3B0}"] }
  ],
  "brk": [                     // hardware breakpoints (same field syntax)
    { "sym": "Fs_ReadN", "fields": ["{PC}", "{kb:0xF3B3}", "{kb:0xF3B0}"] }
  ]
}
```

### Field shorthands (captured per hit; each stored as a 32-bit dword)
`{PC}` full PB:PC · `{VAL}` value written (watchpoints) · `{A}{X}{Y}{S}{D}`
registers · `{kb:X}` / `{kbw:X}` / `{kbb:X}` dword/word/byte read of kernel-bank
symbol-or-`0x`offset X at the live bank. Anything else is a raw MAME debugger
expression.

### Extending
Add a new `probes/<name>.json` — nothing is sed-specific. New symbols resolve
from the kernel listings by name, or give an explicit `off` for EQU/ENT symbols.
Each watch/brk can capture up to a handful of fields.

---

## sed read-heisenbug: the complete `_fsFS_Pos` writer map (2026-06-23)

The bug is: at `Fs_ReadN`'s EOF check (`Pos >= Eof`), the singleton **Pos == Eof
== $0009FA** (= /docs/shell.txt size) *before* sed's first `read()` returns any
bytes. So **something writes Pos := Eof in the open→read window.** Every
instruction in the build that stores `_fsFS_Pos` ($7D:F3B3) was enumerated from
the listings (object-code grep `8D B3 F3` over both `fgx_S01_KernelMain_Output.txt`
and `module_prodos_Output.txt`). It is *exhaustive*:

### Kernel — bank `$7D` (confirm `print b@32C`)
| `curpc` | routine | writes | can cause Pos:=Eof pre-read? |
|---|---|---|---|
| `7D/5317` | `_Fs_LoadStateFromFCB` | `Pos := FCB_Pos` (owner-switch load) | **YES** — if loaded FCB has Pos=Eof |
| `7D/56B6` | `Fs_ReadN` advance | `Pos += chunk` | no — runs only after a real read |
| `7D/7042` | `_Sys_Open` `@op_postOpen` | `Pos := Eof` if `O_APPEND` | **YES** — but flags measured 0 |
| `7D/8AD1` | spawn `@afa_doOpen` | `Pos := Eof` if `O_APPEND` | **YES** — spawn fd-action redirect (untested) |

### Prodos module — runtime bank = `curpc`'s bank when ≠ `$7D` (reloc is bank-granular, so the offset below = low 16 bits of `curpc`)
| offset | handler | writes |
|---|---|---|
| `/0343` `/03C8` `/0456` | `_fop_open` (seed/sap/tree) | `Pos := 0` (open setup — benign) |
| `/05AF` | `_fop_bmap` | runs only *after* the EOF check passes |
| `/070F` | `_fop_lseek` | `Pos := seek target` (arbitrary) |
| `/0ADF` | `_fop_write` | write-path advance |
| `/1007` | late handler | (write/truncate path) |

A hardware watchpoint on the physical address `$7D:F3B3` catches **all** of them
(the module reaches the singleton via DBR=$7D), so `curpc` at the break uniquely
names the writer.

### Field / pointer addresses
`Eof` = `7D/F3B0` (3 B) · `Pos` = `7D/F3B3` (3 B) · `_fsCurOwnerFcb` = `7D/F598`
(3 B long-ptr) · `_fcbPtr` = DP `$94` (3 B long-ptr to current FCB) · within an
FCB: `FCB_Flags`+0, `FCB_Eof`+7 (3 B), `FCB_Pos`+10 (3 B), `FCB_RefCount`+32.

### THE decisive experiment (interactive, one break)
Arm **after boot** (so boot I/O doesn't flood it). The condition fires precisely
on the bug signature "Pos is being set to the current Eof":
```
print b@32C                          ; confirm = 7D
wpset 7df3b3,1,w,wpdata==(b@7df3b0)  ; break when PosLo := EofLo  (= "Pos:=Eof")
go
; -- type in the IIgs window:  sed s/ProDOS/RiffyDOS/ /docs/shell.txt
; on break:
print curpc                          ; -> map against the tables above
dw 7df3b0                            ; Eof  (expect 09FA = shell.txt size)
dw 7df3b3                            ; Pos  (now == Eof)
```
Fallback if the condition syntax misbehaves: `wpset 7df3b3,1,w` (every PosLo
write) and record the (curpc, Pos, Eof) sequence; the write that lands Pos=$09FA
with Eof=$09FA is the culprit.

### Decision tree on `curpc`
- **`7D/5317`** (`_Fs_LoadStateFromFCB`) → owner-churn loaded a stale FCB whose
  saved Pos=Eof. At the break, `dw 7df3b0` already holds the loaded FCB's Eof; if
  it's `09FA` and Pos becomes `09FA`, a fully-read /docs/shell.txt FCB was loaded.
  To see the source FCB directly: `print d` (DP base), then the 3-byte ptr at
  `D+$94` is the FCB; `FCB+7`=Eof, `FCB+10`=Pos.  **Prime suspect** (see below).
- **`7D/7042`** (`_Sys_Open` O_APPEND) → O_APPEND was taken despite the earlier
  flags=0 measurement ⇒ layout-dependent flag corruption between read of
  `_Sys_OpenFlags` and the `AND #O_APPEND`.
- **`7D/8AD1`** (spawn fd-action O_APPEND) → a spawn-time redirect opened the file
  O_APPEND. This site was **never** covered by the earlier "O_APPEND ruled out" test.
- **module `/070F`** (`_fop_lseek`) → an lseek-to-EOF on the file before the read.
- **`7D/56B6`** (advance) → a real read progressed ⇒ bug not reproduced this run.
- **No break, yet read still returns 0** → Pos was ALREADY $09FA before the read.
  The "Pos=0 at SYS_OPEN return" snapshot was from a *non-manifesting* instrumented
  build; on the unmodified image the corruption is at/before open. Re-arm
  `wpset 7df3b3,1,w` from boot and watch the whole open sequence for sed's file.

### Prime suspect by elimination
Between `SYS_OPEN` return (Pos=0, measured) and `Fs_ReadN`'s EOF check, a plain
`read()` with no lseek/spawn reaches exactly **one** Pos writer:
`_Fs_LoadStateFromFCB` (`7D/5317`), entered only when `_Fs_SwitchToFCB` takes its
`@sw_change` branch — i.e. `_fcbPtr` (from sed's fd) ≠ `_fsCurOwnerFcb`. So the
mechanism is most likely: **the owner changed away from sed's file FCB, and the
FCB loaded back in has saved Pos=Eof** (a recycled/fully-read /docs/shell.txt
FCB). The watchpoint + the `D+$94` FCB dump confirms or refutes this in one break.

---

## Status / limitation (being finished)
The wp/bp **fire** correctly, but capturing their data **headlessly** is the open
problem: under `-debugger none`, debugger-action `printf` is not captured,
in-action memory writes don't land, and a stopping wp freezes (no headless
resume). MAME's **Lua** debug API (`cpu.debug:wpset`, `manager.machine.debugger.
execution_state`) IS available and `emu.print_info` IS captured, and `frame_done`
fires while running — so the intended final mechanism is a Lua poll/resume in the
plugin. Until that lands, use **`kdebug.sh`** (interactive) for live capture; it
needs no capture channel.
