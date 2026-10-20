# Bank $00 (and TN#27 four-region) memory audit — 2026-06-13

Context: preparing **task #3** of the boot.conf/MM-claim rework — making the
loader's `NewHandle` calls compliant with **ProDOS 8 Technical Note #27
("Hybrid Applications", Matt Deatherage, 1990)**. FGX boots directly under
ProDOS 8, so `OS_BOOT` (`$E100BD`) is `$00`, meaning *nothing* is MM-allocated
at boot and FGX must reserve the memory GS/OS would normally protect — the
**canonical four handles**:

| Region | Size | TN#27 role |
|---|---|---|
| `$00/0800` | `$B800` | main bank-0 working RAM ($0800–$BFFF) |
| `$01/0800` | `$B800` | aux bank-1 RAM ($0800–$BFFF) |
| `$E0/2000` | `$4000` | bank $E0 ($2000–$5FFF) |
| `$E1/2000` | `$8000` | bank $E1 ($2000–$9FFF) |

Then `GetNewID` of type `$1000` (application) and `MMStartUp` **last**. The
loader already does `GetNewID $1000` and `MTStartUp`-last; it does **not** read
`OS_BOOT` and does **not** make the four protective claims. That gap is task #3.

This audit answers: *what does FGX put in these regions, and does the canonical
claim collide with anything?* — especially the open question of FGX usage
**below `$0800`**.

---

## Complete bank $00 map

| Range | Owner (EQU) | Alloc | `<$0800`? | In `$00/0800 $B800`? |
|---|---|---|---|---|
| `$0000–$00FF` | `FGX_DP_KERNEL` — boot DP/ZP (goes stale after kernel DP is MM-allocated; firmware/MM scratch freely) | special | yes | no |
| `$0100–$01FF` | `FGX_STK_KERNEL` — boot/kernel stack (must be page-1 for emul firmware) | special | yes | no |
| `$0200–$02FF` | `FGX_SYSVARS` — unused live | special | yes | no |
| `$0300–$07FF` | `FGX_INTVEC` — gateway: `_mlEntryJSL`($0300), ID/COP/SYS tramps($0320), `KFGX_ANCHOR`($032C), `MOD_JT_GATEWAY`($032E–$03B3), `_simTramp`($03B4), `_cd/_fst/_netTrampJSL`($03B8–$03C6), dead hole($03C7–$03CB), `KFGX_REST_ANCHOR`($03CC) | special | yes | no |
| `$0800–$0FFF` | `FGX_BOOTAREA` — boot-block load area (transient; free after boot) | fixed | no | yes |
| `$1000–$1FFF` | `FGX_STK_KTASKS` — per-task **kernel** stacks (PID k = `$1000+(k<<8)`). Loader transiently uses as CONF_BUF/PATH_BUF | fixed | no | yes |
| `$2000–$2FFF` | `BLK_STAGE` — 512-B SmartPort block staging | fixed | no | yes |
| `$3000–$3FFF` | `FGX_STK_TASKS` — user task stacks (PID k = `$3000+(k<<8)`). Loader transiently uses as KERNEL_BUFFER | fixed | no | yes |
| `$4000–~$BExx` | `FGX_SYSBUF` — system buffers + free | fixed/free | no | yes |
| `$BF00` (≈) | **kernel DP page** — MM-`NewHandle`'d, page-aligned, locked | **dynamic** | no | yes |
| (scattered, high) | **per-task DP pages** — MM-`NewHandle`'d, page-aligned, locked (`task.s:361`, same recipe as `Toolbox_AllocKernelDP`) | **dynamic** | no | yes |
| `$C000–$FFFF` | I/O soft switches + ROM | — | no | no (not RAM-managed) |

---

## Finding 1 — below `$0800` is fully resolved: nothing to claim, nothing at risk

Everything FGX puts below `$0800` (ZP, boot stack, sysvars, and the entire
`$0300–$07FF` gateway) lives in the Memory Manager's **special-memory zone**,
which the MM *never* hands out. This is proven empirically: a
`region 00 0300 0100` claim **halts the loader** (`NewHandle` returns C=0 →
`@kh_halt`), because the MM refuses fixed handles below `$0800`; whereas
`$1000`/`$2000`/`$3000` claim fine. TN#27 starts its `$00` claim at `$0800` for
exactly this reason.

**Conclusion:** the gateway page and all sub-`$0800` state are implicitly
protected. The canonical `$00/0800 $B800` claim correctly does not (and cannot)
cover them, and does not need to. The maintainer's "do we use anything below `$0800`"
concern is answered: **yes (the gateway, heavily), but it requires no claim.**

## Finding 2 — the four TN#27 regions each guard real FGX memory

- **`$00/0800 $B800` ($0800–$BFFF):** FGX's bank-0 working RAM — kernel+task
  stacks, BLK_STAGE, sysbuf, and the DP pages. **Subsumes** the current
  piecemeal `region 00 1000/2000/3000` boot.conf claims into one handle.
- **`$01/0800 $B800` ($01:0800–$BFFF):** covers `CON_SHR_BASE = $01:2000` — FGX
  writes SHR pixels here, hardware-**shadowed** to `$E1:2000`. Not unused aux
  RAM; it is FGX's framebuffer-write window.
- **`$E0/2000 $4000` ($E0:2000–$5FFF):** the `$E0` shadow region — protection
  (FGX renders via the `$E1`/`$01` path; `$E0` is mostly I/O at `$E0:C0xx`).
- **`$E1/2000 $8000` ($E1:2000–$9FFF):** FGX's actual SHR display —
  `SHR_SCREEN $E1:2000`, `SHR_SCB $E1:9D00`, `SHR_PALETTES $E1:9E00`. Must be
  reserved or a CDEV/tool could be handed the live console buffer.

(`$E1:0000–$1FFF` sound RAM and `$E0:C0xx` I/O are outside the claims —
hardware, not MM-managed. Correct.)

## Finding 3 — THE work item: DP-page allocation collides with a full `$00/0800` claim

The kernel DP (`Toolbox_AllocKernelDP`/`LoaderAllocKernelDP`, lands ≈`$BF00`)
and every per-task DP page are **dynamic MM `NewHandle`s** of page-aligned
bank-0 pages — and they land **inside** `$0800–$BFFF`. If the loader claims the
whole `$00/0800 $B800` block first, the MM has **no free bank-0 page left** to
satisfy those `NewHandle`s → they fail → `@kh_halt`.

So adopting canonical TN#27 **requires changing how bank-0 DP pages are
allocated.** Options:

1. **Fixed PID-indexed DP region (recommended)** — carve a fixed DP-page array
   inside the claimed block, mirroring the stack layout (`FGX_DP_TASKS +
   (pid<<8)`), plus one fixed kernel-DP page. Matches FGX's existing
   fixed-region precedent (kernel stacks were moved off `NewHandle`'d pages for
   the same class of reason — `task.s:787`). Simplest; no runtime allocator.
2. **FGX-internal bank-0 sub-allocator** — FGX carves DP pages from its own
   `$00/0800` handle at runtime. More flexible, more code, more risk.

Either way, the fixed regions (`$1000`/`$2000`/`$3000`/`$4000`) need no change —
they're already used by absolute address; the single claim just tells the MM
"hands off."

## Finding 4 — `OS_BOOT` gating

`OS_BOOT` (`$E100BD`): `$00` ⇒ direct ProDOS 8 boot (do the four claims);
non-zero ⇒ launched by GS/OS (low 128K already reserved — skip the claims, use
the GS/OS user ID, manage handles individually). FGX's normal path is `$00`;
the check is defensive future-proofing for a GS/OS-launched FGX.

---

## Implications for the boot.conf / claim rework

- The canonical four-handle claim **replaces** boot.conf's `region 00 1000/...`
  bank-0 lines and is the correct MM-citizen handshake for CDEV coexistence.
- It does **not** subsume the `$02`/`$03–$1F`/kernel/rest claims — those are
  separate (task #2 sizing + task #1 rest-handle migration).
- **Prerequisite for #3:** resolve Finding 3 (DP-page allocation) before adding
  the `$00/0800` claim, or the loader halts.

---

## Bank-0 scaling roadmap (decided 2026-06-13)

Bank-0 budget: usable working RAM is `$0800-$BFFF` = **47 KB** (hard ceiling).
Per-task structural cost (all bank-0-mandatory): kernel stack 256 B + DP 256 B +
user stack 256 B–4 KB ⇒ **768 B min / 4.6 KB max** per task. Process ceiling
≈ **8 at max stack size**, ~130 at min; NPROC=8 fits even at max, just. Stacks and
DP are bank-0-mandatory (65816 `S` and `D` are bank-0-only) — they **cannot** be
relocated. So reclaiming buffers buys headroom; only the swap model is structural.

Tiered plan:

1. **Recover ~8 KB (low effort, do now).** `FGX_SYSBUF` (`$4000`, 4 KB) is **dead**
   (zero consumers — only the EQU). `FGX_BOOTAREA` (`$0800-$0FFF`, 2 KB) is
   transient (boot-block load area). kstack/DP reserve a full 4 KB / 16 slots but
   NPROC=8 uses 2 KB. Reclaim → frees the middle of bank 0 for the arena.

2. **Bounded bank-0 stack arena + page allocator (do now — unblocks the TN#27
   claim).** A fixed ~24–33 KB arena (plan: `$4000-$AFFF` = 28 KB / 112 pages,
   inside the `$00/0800` claim, between BLK_STAGE `$2000` and DP `$B000`; `$8000`
   is touched only by the transient boot-time RAM probe, safe by task-spawn time).
   A page bitmap tracks free/used; `Task_AllocStack` carves N contiguous free pages
   (1–16), `Task_FreeStack` frees on exit. No MM handle, no copying. init keeps its
   static `$3100` (arena-bounds guard in free). This is the fix that lets the
   canonical TN#27 `$00/0800 $B800` claim land without starving child stacks.

3. **(future) Extended-SmartPort migration.** block.s/dev.s bounce disk I/O through
   the bank-0 buffer `BLK_STAGE` (`$2000`, 4 KB) then MVN to the destination bank.
   Switching to the extended SmartPort call (4-byte buffer pointer → any bank) reads
   straight into the destination bank — frees 4 KB **and** removes the per-block MVN
   (potentially a big I/O win). Delicate: kernel-private device tables.

4. **(future) Stack-swap model — the structural scaler.** Keep each task's user-stack
   image in the rest-of-OS handle; reserve one fixed bank-0 stack *window*; copy the
   used portion in on switch-in and out on switch-out. Decouples process count and
   stack size from bank-0 size. Cost: a memcpy per context switch (proportional to
   used depth — cheap for cooperative MT with shallow stacks). Needed when NPROC
   grows well past ~8 with large concurrent stacks. `Task_AllocStack` then becomes
   "register a home + map the window."
