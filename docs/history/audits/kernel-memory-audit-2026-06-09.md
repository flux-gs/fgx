# FGX Kernel Memory Audit — 2026-06-09

**Why this exists:** the kernel keeps hitting its bank-$02 size ceiling (most recently
adding `pipe.s` pushed it 767 B over). This is a full audit of *everything* that consumes
kernel memory — static buffers, code by subsystem, the direct page, the heap, and the
module system — so we pick durable reclaim levers instead of repeatedly patching at the wall.

Snapshot: kernel = **51711 B**, ceiling = **50944 B** (`lib/build_common.sh:162`), **767 B over**.

---

## 1. The binding constraint (why we keep hitting the wall)

Bank $02 has two allocation fronts growing **toward each other**:

```
$02:0000  vectors / reserved tables ........ (mostly DEAD, see §4)
$02:2000  FGX_CODE  ── kernel code grows UP ──►   ... collides here ...
$02:E700  FGX_DATA  ◄── static data grows DOWN-from-top ── $02:FB9D (KMem_end)
$02:FE00  MOD_JT_BASE  (module jump table — hard data ceiling)
$02:FF00  BlkTramp / loader handoff
$02:FFFF  end of bank
$03:0000  FGX_HEAP / console framebuffers (out of bank $02)
```

- **Code:** `$022000 .. $02E6D2` ≈ 50,898 B span (43,933 B emitted; gaps make the linked
  size 51,711). Just overflowed `FGX_DATA`.
- **Static data:** `$02E700 .. $02FB9D` = **5277 B**, with 611 B slack to the `$FE00` ceiling.
- Everything else (heap, console framebuffers, modules) is in **other banks** — so moving
  code *or* data out of bank $02 genuinely relieves the collision.

---

## 2. Static data inventory (bank-$02 `$E700–$FB9D`, 5277 B)

The big items dominate: **7×512-B buffers + 2×256-B console tables ≈ 4096 B = 78%.**

| Item | Size | Owner | Access | Migration |
|---|--:|---|---|---|
| `CON_EXPAND` | 512 | console render | ABS, hot render path | MEDIUM |
| `_fsDirBuf` | 512 | fs | ABS `LDAL` + KAD (prodos.mod) | HARD |
| `_fsDataBuf` | 512 | fs | ABS + KAD, hot I/O | HARD |
| `_fsIndexBuf` | 512 | fs | ABS + KAD | HARD |
| `_fsMasterBuf` | 512 | fs tree-file | ABS + KAD | HARD |
| `CON_VT_STATE` | 256 | console VT parser | ABS, single owner | MEDIUM |
| `CON_FONT_HDR_BUF` | 256 | font loader | ABS; **only 48 B used** | **EASY (shrink in place)** |
| `_sccRxBuf` / `_sccTxBuf` | 256 ea | serial IRQ rings | ABS (+KAD tx) | MEDIUM (IRQ) |
| `_fsPathScratch` | 288 | fs path resolver | ABS + KAD, label-relative sub-bufs | MEDIUM/HARD |
| ~120 scalar state cells | ≈600 total | various | ABS (many KAD) | low yield each |

**Critical fact:** *every* large buffer is reached by **bank-$02 absolute/long addressing**
(`LDAL name,X`, `LDA #name`). None use a DP long-pointer today. So heap-migrating any of
them requires rewriting every accessor to `[dp],Y` form — the surgery already done for the
log ring, modReg/chardev/sigHnd/cwd tables. The auto-generated `KAD_*` exports
(`gen_kernel_exports.py`) fix address *drift* but **not** the DBR-pinning: a module still
does `LDAL $02xxxx`, which only works if the buffer is physically in bank $02.

---

## 3. Code inventory (43,933 B emitted, 48 files)

Top of the list (full table in the audit run; key rows):

| File | Bytes | % | Hot? | Subsystem |
|---|--:|--:|:--:|---|
| `syscall.s` | 4774 | 10.9 | HOT | dispatch + read/write/open/spawn cores |
| **`uthernet.s`** | **4326** | **9.9** | **COLD** | W5100 driver + net handlers |
| `fs.s` | 3796 | 8.6 | HOT | filesystem core |
| `main.s` | 3074 | 7.0 | COLD | boot/init |
| `console_vthandler.s` | 1878 | 4.3 | HOT | VT/ANSI |
| `loader.s` | 1643 | 3.7 | warm | program loader |
| `process.s` | 1576 | 3.6 | HOT | spawn/fork/wait/exit |
| `modload.s` | 1296 | 2.9 | COLD | module loader (the enabler) |
| `printf.s` | 1229 | 2.8 | warm | kernel printf |
| `task.s` | 1211 | 2.8 | HOT | context switch |
| **`socket.s`** | **1153** | **2.6** | **COLD** | BSD socket layer |
| `pipe.s` | 1073 | 2.4 | warm | NEW pipe object |
| **`ifconfig_sys.s`** | **824** | **1.9** | **COLD** | iface table / SYS_IFCONFIG |

Top-10 files = 56.5% of code; top-3 = 29.4%. **The single biggest COLD lump is
networking** (`uthernet.s` + `socket.s` + `ifconfig_sys.s` ≈ **6,300 B**), which is only
reached on socket I/O. Already-modularized subsystems (NOT in the kernel): **prodos,
serial, bpf, hello** — bpf.mod is the proven "driver → module + 78-B boot residue" template.

---

## 4. The high-value structural finding — dead reserved tables below `$2000`

`main.s` ORGs at `FGX_CODE = $022000`. Below it sit reserved tables, **most now dead**:

| Region | Addr | Size | Status |
|---|---|--:|---|
| `FGX_VECTORS` | $0000 | 256 | **LIVE** (boot entry) — keep |
| `FGX_SYSCALL_TBL` | $0100 | 256 | **DEAD** (no live reader; dispatch is via COP trampoline) |
| `FGX_INTR_TBL` | $0200 | 256 | **DEAD** |
| `FGX_GLOBALS` | $0400 | 1024 | **DEAD** — only `ipc.s`/`memory.s` read it, and **neither is compiled** |
| `FGX_TASK_TBL` | $0800 | 512 (NPROC=8) | **LIVE** — keep; `$0A00–$0FFF` is slack |
| `FGX_READY_Q` | $1000 | 4096 | **DEAD** (round-robin scheduler uses the heap sched table) |

`ipc.s` and `memory.s` are orphaned v3-scheduler scaffold — not in the PUT list, so their
`FGX_GLOBALS`/`FGX_SYSCALL_TBL` consumers don't exist in the running kernel. Live current-task
is `_curTask` (DP $9E); live bank bitmap is `BankBitmap DS 3` in FGX_DATA — not the
`$020400` globals.

**Consequence: `FGX_CODE` can drop from `$022000` to `$021000`, reclaiming ~4 KB of code
room with no data surgery, no DP pressure, no FS/console hot-path risk.** `FGX_VECTORS`
($0000) and `FGX_TASK_TBL` ($0800–$09FF) stay where they are (below $1000). Note bank-$02
`$1000` ≠ bank-$00 `FGX_STK_KTASKS` `$001000` (kernel stacks are in bank $00 — no collision).

---

## 5. Direct page & heap (constraints on the *other* levers)

- **DP is FULL.** `include/dpmap.s` packs `$00–$FF` edge-to-edge (`ERR KDp_end-1/$100`).
  No free word; only scattered 1-byte alignment pads. **Every heap-migrated static needs a
  3-byte DP long-pointer to reach it** (heap is outside DBR=$02 → `[dp],Y`-only). This is the
  real gate on the "migrate a buffer to heap" lever — not heap space.
- **Heap is plentiful and outside bank $02.** Kmalloc arenas in banks `$07–$09` (~192 KB
  resident at boot, growable to ~1 MB via `Bank_Alloc`, `KMEM_MAX_ARENAS=16`). 9-B per-chunk
  overhead + 16-B click rounding. Migrating a bank-$02 static into it genuinely frees bank-$02.
- **Modules cost a whole bank each** ($05–$06 reserved; extras draw user-pool banks).
  Per-module registry cost ~6 B heap; core→module calls go through the fixed 20-slot
  `$02FE00` jump table (tail-appendable, finite). 4 modules live now (prodos/serial/bpf/hello).

---

## 6. Reclaim roadmap (ranked by yield ÷ risk)

| # | Lever | Yield | Risk | Notes |
|---|---|--:|---|---|
| **1** | **Lower `FGX_CODE` `$2000`→`$1000`** | **+4096 B** | **LOW** | Dead reserved tables. Edit `kernel.s` FGX_CODE, `main.s` ORG, `stage2.s` `KERNEL_DEST`/`_LO`, ceiling `50944`→`55040`. Verify: **cold-boot smoke (--no-state)** + suite. **Unblocks pipes now** with durable headroom. |
| 2 | **Net → `net.mod`** (uthernet+socket+ifconfig) | **+6300 B** | MED | The big durable structural fix. bpf.mod template: boot probe/iface residue + module-owned W5100 ISR arm + `read/write→_Net_Xport_*` jump-table seam. Watch the `_ArmUthernet2` shared-side-effect lesson. Do as a dedicated effort. |
| 3 | Shrink `CON_FONT_HDR_BUF` 256→64 | +192 B | ~0 | 48 B used; pure in-place `DS` cut. Freebie. |
| 4 | `FGX_TASK_TBL` `$0A00–$0FFF` slack | (absorbed) | 0 | Auto-reclaimed when #1 lowers FGX_CODE. |
| 5 | Migrate FS buffers (`_fs*Buf`, 2 KB) to heap | +2048 B | HIGH | Module-shared + absolute access + **needs a free DP slot** (DP full). FS hot path. Defer behind #1–2. |
| 6 | Migrate `CON_VT_STATE`/`CON_EXPAND` to heap | +768 B | MED | Single-owner but render hot path + DP-full gate. Last resort. |

**Recommendation:** do **#1 now** (low-risk, +4 KB — by itself takes pipes from 767-over to
~3.3 KB-under and covers SIGPIPE + several more features). Then schedule **#2 (net.mod)** as
the strategic durable win (#1 + #2 ≈ 10 KB headroom — ends the recurring wall for the
foreseeable future). #3 is a freebie to fold in. #5–6 (buffer migration) are **deprioritized**:
the audit shows they're gated by the full DP page and touch hot paths, so they're *higher*
risk/effort than the code-side levers for similar yield.

**Constraints to respect:** DP full (every heap-migrate needs a DP slot); `$02FE00` data
ceiling + `$02FF00` loader handoff; one bank per module; `KMEM_HEAP_FIRST_BANK`/`KMEM_MAX_ARENAS`
move in lockstep if module/heap bank reservations grow.
