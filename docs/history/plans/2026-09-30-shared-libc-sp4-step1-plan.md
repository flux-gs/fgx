# Shared libc SP4 step 1: the kernel pieces and ld.mod -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The kernel and a new module, `ld.mod`, arbitrate shared-library
residency: `SYS_LDCTL` (syscall 8) with ACQUIRE / GRANT / COMMIT / ABORT /
LOOKUP, banks granted to registry rows, per-process use counts kept by
exit, fork, exec and slot-allocation hooks, reclaim of zero-user rows when
the bank pool runs dry, and the loader refusing a library file -- proven in
headless MAME by a probe that drives `SYS_LDCTL` directly, with no library
involved.

**Architecture:** One bank-0 cell, `LD_TRAMP` ($00:031A, 4 bytes), holds a
`JML`.  The tty bank plants its default at boot (a routine answering
ENOSYS to services and doing nothing for hooks), and `ld.mod`'s `mod_init`
re-points it at its dispatcher -- the `FPSIM_TRAMP` pattern
(`src/kernel/far/far.s:557-571`, `src/modules/fpsim/fpsim.s:80-100`).  The
syscall handler and every hook call `LD_TRAMP` with a selector in A: the
core holds only short call sites into tty-bank slots (`KTTY_LD_*`), which
do the work.  `ld.mod` keeps the registry, the per-process use table and
the arena in its own zero-initialised statics.

**Tech Stack:** Merlin32 / 65816 (kernel core, tty bank, module), fcc C
(the probe), Python (gen.py, gen_modplace.py), headless MAME
(`tools/mame_test/run.py`).

**Spec:** `docs/history/plans/2026-09-30-shared-libc-sp4-design.md`,
sections 4 (ld.mod), 6 (kernel pieces), 9 (testing), 10 step 1.  Revised
the same day for an adversarial review (Fable), fourteen findings adopted.
Settled here from reading the code (file:line at b7f8c20e3):

- **Rooms.** `tools/check_kernel_ceiling.py`: core 86 bytes free, far 195,
  tty 2,343.  The core gets only call sites; bodies go in the tty bank
  through `KTTY_SLOT0+4n` export slots (`include/ktty.s:72-100`, slots up
  to 48 used of 56), called as `_ktpNNN JSL KTTY_x` (the pattern of
  `_thunk_Gtod`, `syscall.s:6360-6364`).  The loader's check is in the far
  bank (`_LoadFGX2`).
- **The cell.** `$031A-$031F` is unallocated (memmap.s:1970-1974: the DUM
  at $0300 ends after `KFGX_CUR_KDP` at $0318; the next starts at
  $000320), outside the firmware's stomp zones ($03C8-$03CC, $03CE).  A
  kernel-planted default at boot means a warm reboot cannot leave a stale
  `ld.mod` address there.  Boot order (`main.s`): `Bank_Init` :259,
  `Far_Init` :303, `Tty_Init` :362 (patches every `_ktp` site, then
  `KTTY_INIT` plants `LD_TRAMP`), first `Task_Alloc` :574 -- so every hook
  site's tty slot is live before any hook can fire.
- **Selectors** (A on every `LD_TRAMP` call): services 0-4 (ACQUIRE,
  GRANT, COMMIT, ABORT, LOOKUP), from `SYS_LDCTL` only; hooks $80-$84
  (EXIT, FORK, EXEC, TALLOC, RECLAIM), from the kernel only.  The syscall
  refuses A >= $80 so user code cannot call a hook.
- **Contexts.**  A syscall handler runs with MX %00, DBR = kernel bank, D =
  the task's kernel page, on the task's kernel stack, and may sleep
  (`syscall.s:68-470`).  `SYS_KCALL` saves the caller's DBR, does not touch
  D, returns C=1 + results or C=0 + A = errno (`jumptable.s:302-338`).
  `KSVC_SLEEP` returns A = 1 when a signal is pending, without blocking
  (`jumptable.s:636-652`).  `Bank_Alloc` returns C=1 + A = bank or C=0 + A
  = ENOMEM and preserves X/Y; `Bank_Free` takes A = bank, preserves X/Y
  (`bank.s:80-277`); `Bank_Alloc`'s pool-dry path calls `_LibcSh_Reclaim`
  and retries while it frees (`bank.s:139-154`).
- **Hook sites.**  Exit: after `_kfp966 JSL KFAR_VFS_CDIREXIT` / `PLA` and
  before `Task_Lookup` (`process.s` `_Exit_Core`, ~3570): the dying pid is
  `_curTask`, the status not yet ZOMBIE.  Fork: at `@vf_ready`, past the
  last failure path (`process.s` ~1146): `_vf_childPid`, parent
  `_curTask`.  Exec: after `@evf_noBorrowRef`'s `REP` (`process.s` ~3116),
  past the commit point.  Slot allocation: `Task_Alloc`'s tail, where
  `_taskAllocCur` = the new pid (`task.s` ~226-265).  Reclaim:
  `_LibcSh_Reclaim`'s final `CLC` / `RTS` (`bank.s` ~226).
- **Pids.**  pid = slot + 1, 1..NPROC (`NPROC` = `CFG_KERNEL_NPROC` = 32,
  `include/config.s:18`).
- **Modules.**  `mod_init` runs with MX %00, DBR = kernel bank, returns RTL
  C=1 (`modload.s:522-595`).  A module's mutable state must be zero in its
  file (`tools/mame_test/modimage_check.py` allows only zero-in-file bytes
  to differ).  Shared module bank (ordinal 0, absent from `OWN_BANK`),
  `ORDER` appended (`tools/gen_modplace.py:65-68`), `MODULES` in
  `tools/ninja/gen.py:2034-2037`, `rc.in:133` and `modload.conf` held equal
  by `tools/check_modload_lists.py`.  `ld.mod` bakes no kernel address
  (bank-0 cells only), so it is not build-locked (header +34 = $0000) and
  not in `KEXPORTS`.
- **Probe.**  fcc's `__syscall(num, a, x, y)`, `__syscall_c()`,
  `__syscall_y()` (`fcc_runtime_data.s:111-118`, `libc_c/fchown.c`).  A
  parameter block must be a static (the kernel cannot read the bank-0
  stack, `utimes.c`).  Fork/kill/wait shape from
  `src/userland/sigexec/sigexec.c`; manifest shape from
  `tools/mame_test/tests/sigreuse.json`.
- **Wait channel**: `WCHAN_LD` $FF0A, the next free fixed channel
  (`include/kernel.s:775-821`; `tools/check_wchans.py` refuses duplicates).

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- Nothing shipped changes behaviour until `ld.mod` loads; with `ld.mod`
  loaded and no `SYS_LDCTL` caller, nothing changes either (every hook is a
  no-op on an empty registry).  The gate proves it.
- `KSVC_*` numbers are append-only (`include/modules.s:98-103`).
- Headless MAME only (`run.py`); announce every rebuild and MAME run; the
  probe is testbin, not a gate test.
- Branch `feat/shared-libc`, not pushed.

## Review Focus

1. A hook running while `ld.mod` is not loaded -- every one a no-op, and
   `SYS_LDCTL` ENOSYS (Task 1's `absent` mode; the gate, which boots
   without and then with `ld.mod`, covers the rest).
2. An interrupt between `ld.mod` patching its param-copy `MVN` and running
   it -- the patch and the move are under `SEI` (Task 3; Task 4's `race`
   mode runs two callers at once).
3. A user calling `SYS_LDCTL` with a hook selector ($80-$84) -- ENOSYS, not
   a hook (Task 1's `absent` mode, and Task 4's `basic` with `ld.mod`).
4. A process exiting while asleep in ACQUIRE -- its use bits clear, the
   row's count unchanged, the owner's row still LOADING (Task 4's `intr`).
5. `Bank_Alloc` reached from inside `ld.mod`'s GRANT finding the pool dry
   -- reclaim re-enters `ld.mod`, which must not pick the LOADING row being
   granted (Task 4's `reclaim` drains the pool through GRANTs, so this
   happens for real).

---

### Task 1: `LD_TRAMP`, its default, and `SYS_LDCTL`

**Files:**
- Modify: `include/memmap.s` (reserve `$031A` as `_LD_TRAMP_RSV DS 4`,
  `ERR` against `LD_TRAMP`), `include/kernel.s` (`LD_TRAMP EQU $00031A`,
  selector EQUs, `WCHAN_LD EQU $FF0A`), `include/ktty.s` (slots
  `KTTY_LD_CTL` .. `KTTY_LD_RECLAIM`, 49-54), the tty bank's slot table
  (`ttybank.s:337-363`: six `JMP _Ld_x` / `DFB 0` entries, and the padding
  `LUP KTTY_SLOT_COUNT-49` at :363 becomes `-55`, or the `ERR` at :374
  fires) and `Tty_BankInit` (plant the default), a new `src/kernel/tty/ld_hooks.s`
  (the slot bodies and `_Ld_Absent`), `src/kernel/syscall.s` (slot 8 ->
  `_thunk_LdCtl`), `include/loader.s` (`SYS_LDCTL EQU 8`),
  `docs/userland-abi.md` (regenerated), `tools/check_wchans.py` if it
  lists channels.
- Create: `src/userland/ldctl/ldctl.c`, `tools/mame_test/tests/ldctl_absent.json`;
  `tools/ninja/manifest.json` (`{"name": "ldctl"}` tool, staging to
  `disk_src/testbin/ldctl`).

**Interfaces:**
- Produces: `LD_TRAMP` ($00:031A): `JSL LD_TRAMP` with A = selector, X/Y
  per selector; returns per selector.  Selectors: `LDS_ACQUIRE 0`,
  `LDS_GRANT 1`, `LDS_COMMIT 2`, `LDS_ABORT 3`, `LDS_LOOKUP 4`, `LDH_EXIT
  $80`, `LDH_FORK $81`, `LDH_EXEC $82`, `LDH_TALLOC $83`, `LDH_RECLAIM
  $84`.  Default: services -> C=0, A = ENOSYS; hooks -> C=0, A/X/Y
  preserved.  `SYS_LDCTL` (8): A = service, X = parameter block offset, Y =
  its bank; C=1 + A = status, or C=0 + A = errno; A >= $80 is ENOSYS.

- [ ] **Step 1: The probe, `absent` mode first.**  `src/userland/ldctl/ldctl.c`:

```c
/*
 * ldctl -- drives SYS_LDCTL (shared libc SP4) directly, with no library:
 * the registry's services and the kernel's hooks.  One mode per argument;
 * prints `LDC <mode> ok' or `LDC FAIL <mode> <what>'.
 * Spec: docs/history/plans/2026-09-30-shared-libc-sp4-design.md, section 9.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <signal.h>

#define SYS_LDCTL 8
#define LDS_ACQUIRE 0
#define LDS_GRANT 1
#define LDS_COMMIT 2
#define LDS_ABORT 3
#define LDS_LOOKUP 4

/* The parameter block (section 4): a static, so the kernel can read it. */
struct ldblk {
    char name[16];
    unsigned char major, minor;
    unsigned char crc[4];
    unsigned char row, nbanks;
    unsigned char banks[8];
    unsigned core_base, core_size, tmpl_off, expt_off, rows;
    unsigned char binder[3];
    unsigned char state, users, pinned;
};
static struct ldblk blk;
static int fails;

static int
ldctl(svc)
int svc;
{
    int r;

    r = (int)__syscall(SYS_LDCTL, svc, (unsigned)(unsigned long)(char *)&blk,
                       (unsigned)((unsigned long)(char *)&blk >> 16));
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    return r;
}

static void
say(mode, ok, what)
char *mode, *what;
int ok;
{
    if (ok)
        printf("LDC %s ok\n", mode);
    else {
        printf("LDC FAIL %s %s\n", mode, what);
        fails++;
    }
}

static void
name(s, major)
char *s;
int major;
{
    memset((char *)&blk, 0, sizeof blk);
    strcpy(blk.name, s);
    blk.major = major;
}

static int
absent()
{
    name("libx", 1);
    say("absent", ldctl(LDS_ACQUIRE) == -1 && errno == ENOSYS, "acquire");
    say("absent", ldctl(0x80) == -1 && errno == ENOSYS, "hook selector");
    return 0;
}

int
main(argc, argv)
int argc;
char **argv;
{
    if (argc < 2)
        return 2;
    if (strcmp(argv[1], "absent") == 0)
        absent();
    else
        return 2;
    return fails != 0;
}
```

  `tools/mame_test/tests/ldctl_absent.json`: command `/testbin/ldctl
  absent`, `screen_contains` `["LDC absent ok"]`, `screen_lacks` `["LDC
  FAIL", "PANIC", "BRK"]`.  (Until `ld.mod` exists every boot is "absent";
  Task 3 adds `ld.mod` to `rc.in`, after which this mode runs with
  `ld.mod` unloaded only if the manifest boots without it -- Task 3 Step 6
  rewrites the mode to ask for the hook selector only, which stays ENOSYS
  with `ld.mod` loaded.)

- [ ] **Step 2: Run it before the kernel change.**  Announce `ninja all` and
  one headless run.

Run: `ninja all >/dev/null && tools/mame_test/run.py ldctl_absent --fresh 2>&1 | tail -3`
Expected: PASS already -- slot 8 is `_Sys_Stub`, ENOSYS.  This mode is the
"nothing loaded" baseline, not a red test; the red is Step 4's.

- [ ] **Step 3: The kernel side.**

  `include/kernel.s`, beside `FPSIM_TRAMP`:

```
; LD_TRAMP - a JML into ld.mod's dispatcher (shared libc SP4).  Bank 0, so a
; module can name it.  The tty bank plants a JML to _Ld_Absent at boot;
; ld.mod's mod_init re-points it.  JSL LD_TRAMP with A = a selector: 0-4
; SYS_LDCTL's services (from the syscall only), $80-$84 the kernel's hooks.
LD_TRAMP        EQU     $00031A
LDS_ACQUIRE     EQU     0
LDS_GRANT       EQU     1
LDS_COMMIT      EQU     2
LDS_ABORT       EQU     3
LDS_LOOKUP      EQU     4
LDS_COUNT       EQU     5
LDH_EXIT        EQU     $80     ; Y = the dying pid
LDH_FORK        EQU     $81     ; Y = the child's pid; the parent is running
LDH_EXEC        EQU     $82     ; Y = the pid whose image was replaced
LDH_TALLOC      EQU     $83     ; Y = the pid a slot was just given to
LDH_RECLAIM     EQU     $84     ; -> C=1 a bank went back to the pool
WCHAN_LD        EQU     $FF0A   ; ld.mod: a registry row changed state
```

  `include/memmap.s`, in the $0300 DUM after `KFGX_CUR_KDP`:

```
_LD_TRAMP_RSV   DS      4                       ; $031A LD_TRAMP, see kernel.s
                ERR     _LD_TRAMP_RSV-LD_TRAMP
```

  `src/kernel/tty/ld_hooks.s` (PUT by the tty bank's source list beside
  `kern_time`'s; slots 49-54 in `include/ktty.s` and the tty slot table):

```
;==============================================================================
; ld_hooks.s - the kernel's side of shared-library residency (shared libc
; SP4 spec, sections 4 and 6).  The core calls these through tty-bank export
; slots; each calls LD_TRAMP, the bank-0 JML ld.mod points at its
; dispatcher.  Until ld.mod loads, LD_TRAMP holds _Ld_Absent's address.
;==============================================================================
; _Ld_Absent - LD_TRAMP's target while no ld.mod is loaded: a service is
; ENOSYS, a hook does nothing (RECLAIM: nothing freed).  A/X/Y preserved for
; a hook.
_Ld_Absent      MX      %00
                CMP     #LDH_EXIT
                BCS     @la_hook
                LDA     #ENOSYS
@la_hook        CLC
                RTL

; KTTY_LD_CTL - SYS_LDCTL's body.  In: A = service, X/Y = block offset/bank.
_Ld_Ctl         MX      %00
                CMP     #LDS_COUNT
                BCC     @lc_go
                LDA     #ENOSYS                 ; a hook selector, or junk
                CLC
                RTL
@lc_go          JSL     LD_TRAMP
                RTL

; KTTY_LD_EXIT / FORK / EXEC / TALLOC - A = the pid (its high byte is not
; always clear at the call sites, so it is masked here, not in the core);
; X/Y preserved.
_Ld_Exit        MX      %00
                PHY
                LDY     #LDH_EXIT
                BRA     _Ld_Hook
_Ld_Fork        MX      %00
                PHY
                LDY     #LDH_FORK
                BRA     _Ld_Hook
_Ld_Exec        MX      %00
                PHY
                LDY     #LDH_EXEC
                BRA     _Ld_Hook
_Ld_Talloc      MX      %00
                PHY
                LDY     #LDH_TALLOC
_Ld_Hook        PHX
                AND     #$00FF
                PHA
                TYA                             ; A = the selector
                PLY                             ; Y = the pid
                JSL     LD_TRAMP
                PLX
                PLY
                RTL

; KTTY_LD_RECLAIM - C=1 when ld.mod freed a bank.  _LibcSh_Reclaim's
; contract (clobbers A/X, preserves Y) holds through it.
_Ld_Reclaim     MX      %00
                PHY
                LDA     #LDH_RECLAIM
                JSL     LD_TRAMP
                PLY                             ; PLY leaves the carry alone
                RTL
```

  `Tty_BankInit` gains `LD_TRAMP`'s default, as `Far_BankInit` plants
  `FPSIM_TRAMP`'s (`far.s:557-571`):

```
                ; --- LD_TRAMP's default: JML _Ld_Absent, until ld.mod's
                ;     mod_init replaces it.
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    LD_TRAMP+0
                LDA     #<_Ld_Absent
                STAL    LD_TRAMP+1
                LDA     #>_Ld_Absent
                STAL    LD_TRAMP+2
                PHK
                PLA
                STAL    LD_TRAMP+3
                REP     #$30
                MX      %00
```

  `src/kernel/syscall.s`: slot 8 becomes `DA _thunk_LdCtl ; 8: SYS_LDCTL`,
  and beside `_thunk_Gtod`:

```
; SYS_LDCTL (8): ld.mod's registry (shared libc SP4).  The body is in the
; tty bank; ld.mod answers through LD_TRAMP, ENOSYS until it loads.
_thunk_LdCtl    MX      %00
_ktpNNN         JSL     KTTY_LD_CTL
                RTS
```

  (`_ktpNNN`: the next free `_ktp` label, whose bank byte the tty-bank
  init patches as for `_ktp100`.)  `include/loader.s`: `SYS_LDCTL EQU 8 ;
  ldctl(service, block): shared-library registry (ld.mod)`.  Run
  `python3 tools/gen_syscall_table.py` to regenerate `docs/userland-abi.md`.

- [ ] **Step 4: The red case.**  Temporarily make `_Ld_Ctl` skip its `CMP
  #LDS_COUNT` check (always `JSL LD_TRAMP`): the probe's hook-selector call
  then reaches `_Ld_Absent`'s hook arm, which answers C=0 with A = $80, not
  ENOSYS.

Run: `ninja all >/dev/null && tools/mame_test/run.py ldctl_absent --fresh 2>&1 | tail -3`
Expected: FAIL (`LDC FAIL absent hook selector`).  Restore the check.

- [ ] **Step 5: Green, and the ceilings.**

Run: `ninja all 2>&1 | tail -2 && python3 tools/check_kernel_ceiling.py && python3 tools/gen_syscall_table.py --check && tools/mame_test/run.py ldctl_absent --fresh 2>&1 | tail -1`
Expected: build clean; the core's free bytes drop by `_thunk_LdCtl`'s 5;
the abi doc current; `1 passed`.

- [ ] **Step 6: Commit** (`feat(kernel): LD_TRAMP and SYS_LDCTL, ENOSYS until ld.mod loads`,
  body: the cell, its default, the selectors, the tty slots, the syscall;
  the core's bytes; trailers).

---

### Task 2: the hooks, the bank services, and the loader's refusal

**Files:**
- Modify: `src/kernel/process.s` (exit, fork, exec call sites),
  `src/kernel/task.s` (`Task_Alloc` tail), `src/kernel/bank.s`
  (`_LibcSh_Reclaim` tail), `src/kernel/jumptable.s` (two services),
  `include/modules.s` (`KSVC_BANKGRANT 56`, `KSVC_BANKFREE 57`,
  `KSVC_COUNT 58`), `src/kernel/far/loader.s` (`_LoadFGX2` refuses flags
  bit 1), `include/loader.s` (`FGX2_FLAG_LIB EQU $02`).
- Modify: `tools/ninja/manifest.json` (stage `toolchain/lib/libtermlib.so.1.0`,
  the smallest library at 4.8 KB, to `disk_src/testbin/libtermlib.so`, as
  a file the probe tries to exec), `src/userland/ldctl/ldctl.c` (mode
  `libexec`).
- Create: `tools/mame_test/tests/ldlibexec.json`.

**Interfaces:**
- Consumes: Task 1's slots and selectors.
- Produces: `KSVC_BANKGRANT` (56): -> C=1 + A = a bank in no TCB, or C=0 +
  A = ENOMEM.  `KSVC_BANKFREE` (57): A = bank -> C=1.  The hooks fire at
  the sites in the plan's header with Y = the pid.

- [ ] **Step 1: The refusal's failing test.**  Not through the shell:
  2.11BSD's sh runs a file that fails with ENOEXEC as a shell script
  (`vendor/2.11BSD/usr/bin/sh/service.c:144-163`), so `sh` would feed the
  library's bytes to itself.  The probe execs it directly:

```c
static int
libexec()
{
    int pid, st;

    pid = vfork();
    if (pid == 0) {
        execl("/testbin/libtermlib.so", "libtermlib.so", (char *)0);
        _exit(errno == ENOEXEC ? 0 : 1);
    }
    wait(&st);
    say("libexec", pid > 0 && st == 0, "exec of a library is ENOEXEC");
    return 0;
}
```

  (`main` gains `libexec`; `execl`, `vfork`, `wait` declared as
  `sigexec.c` declares them.)  `ldlibexec.json`: command `/testbin/ldctl
  libexec`, `"timeout_s": 60`, `screen_contains` `["LDC libexec ok"]`,
  `screen_lacks` `["LDC FAIL", "PANIC", "BRK"]`.

Run: `ninja all >/dev/null && tools/mame_test/run.py ldlibexec --fresh 2>&1 | tail -3`
Expected: FAIL today.  The file is a valid FGX3 (three segments, data
segment 1, entry 0, ABI stamp current), so the loader accepts it and the
child enters at offset 0 of the DATA segment's bank: a hang, a BRK or a
nonzero exit -- red by every route, a hang by the timeout.

- [ ] **Step 2: The loader.**  In `_LoadFGX2`, after the n_segments check
  (`@lf2_nsegOK_M8`, `loader.s` ~917):

```
                ; A library (fgx_ld's header flags bit 1, shared libc SP3) is
                ; not a program: it has no entry, and its imports are unbound.
                SEP     #$20
                MX      %10
                LDA    |_ldHeader+FGX2_OFF_FLAGS
                AND     #FGX2_FLAG_LIB
                REP     #$20
                MX      %00
                BEQ     @lf2_notLib
                LDA     #ENOEXEC
                JMP     @lf2_errClose
@lf2_notLib
```

- [ ] **Step 3: The bank services.**  `include/modules.s`, after `KSVC_TIME`:

```
KSVC_BANKGRANT          EQU     56  ; -> C=1 + A = a pool bank in no TCB
                                    ;   (Bank_Alloc), which only its holder
                                    ;   frees; C=0 + A = ENOMEM.  ld.mod's
                                    ;   library banks (shared libc SP4).
KSVC_BANKFREE           EQU     57  ; A = a bank KSVC_BANKGRANT gave -> C=1
KSVC_COUNT              EQU     58
```

  `jumptable.s`, before `@kc_s55`'s fallthrough (renumber the label as the
  chain does):

```
                CPX     #KSVC_BANKGRANT
                BNE     @kc_s56
                BRL     @kc_bankgrant
@kc_s56         ANOP
                CPX     #KSVC_BANKFREE
                BNE     @kc_s57
                BRL     @kc_bankfree
@kc_s57         ANOP
```

  and the arms, beside `@kc_time`:

```
                ; --- KSVC_BANKGRANT / KSVC_BANKFREE (DBR = kernel here) ---
@kc_bankgrant   JSR     Bank_Alloc              ; C=1 + A = bank, or ENOMEM
                PLB
                RTL
@kc_bankfree    JSR     Bank_Free               ; A = bank; preserves X/Y
                PLB
                SEC
                RTL
```

- [ ] **Step 4: The hook sites.**  Each loads the pid into A and calls its
  tty slot (`_ktpNNN`, the next free labels):

  `_Exit_Core`, after `_kfp966 JSL KFAR_VFS_CDIREXIT` / `PLA`:

```
                ; ld.mod: release this process's library uses, and abort a
                ; library load it owns (shared libc SP4) -- beside the other
                ; references it took, before its banks go back.
                LDA     _curTask
_ktpNNN         JSL     KTTY_LD_EXIT
```

  `_vf_common`, at `@vf_ready` before `LDA #TASK_READY`:

```
                ; ld.mod: the child uses what its parent uses (shared libc
                ; SP4).  Past every failure path, so nothing to undo.
                LDA     _vf_childPid
_ktpNNN         JSL     KTTY_LD_FORK
                LDX     _vf_childTCB
```

  (re-load X as the original `@vf_ready` does if the next instruction
  needs it.)  execve, after `@evf_noBorrowRef`'s `REP #$20` / `MX %00`:

```
                ; ld.mod: the old image's library uses go (shared libc SP4);
                ; the new image's binder acquires its own.
                LDA     _curTask
_ktpNNN         JSL     KTTY_LD_EXEC
```

  `Task_Alloc`, before its final `PLX` / `PLP` / `SEC` / `RTS`:

```
                ; ld.mod: a fresh slot uses no library (shared libc SP4) --
                ; a child freed by Task_Free on a rollback never exits.
                LDA     _taskAllocCur           ; == pid
_ktpNNN         JSL     KTTY_LD_TALLOC
```

  `_LibcSh_Reclaim`, its final `CLC` / `RTS` becomes:

```
                ; No pile class to give back: ask ld.mod for a library's
                ; (shared libc SP4).  C=1 a bank went back.
_ktpNNN         JSL     KTTY_LD_RECLAIM
                RTS
```

  `_LibcSh_Reclaim` "clobbers A/X; preserves Y" (`bank.s:197`): `_Ld_Reclaim`
  saves Y around `ld.mod`, whose reclaim uses it.  The pid's high byte is
  masked in the tty bodies (`_curTask` is not masked before `Task_Lookup`,
  `process.s:3590`), where there is room, not in the core.

- [ ] **Step 5: Green, the ceilings, and the gate.**  Announce `ninja all`,
  two headless runs, then the gate (kernel changed).

Run: `ninja all 2>&1 | tail -2 && python3 tools/check_kernel_ceiling.py && tools/mame_test/run.py ldlibexec ldctl_absent --fresh 2>&1 | tail -1`
Expected: core within its ceiling (about 60 bytes of the 86 used in all,
measured and reported); `2 passed`.

Run: `tools/gate.sh 2>&1 | tail -2`
Expected: `GATE GREEN` -- every hook is `_Ld_Absent`'s no-op.

- [ ] **Step 6: Commit** (`feat(kernel): library-residency hooks, bank grants, and no exec of a library`,
  body: each hook's site and why there, the two services, the loader's
  refusal; the bytes; trailers).

---

### Task 3: `ld.mod`

**Files:**
- Create: `src/modules/ld/ld.s`, `src/modules/ld/ld.link.s`.
- Modify: `tools/gen_modplace.py` (`ORDER` += `'ld'`), `tools/ninja/gen.py`
  (`MODULES` += `"ld"`), `disk_src/etc/rc.in:133` and
  `disk_src/etc/modload.conf` (`ld` after `fpsim`, before `ufsprobe`, which
  stays last).

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces: the registry and services of spec section 4; the block layout
  of Task 1's `struct ldblk` (48 bytes): +0 name[16], +16 major, +17 minor,
  +18 crc[4], +22 row, +23 nbanks, +24 banks[8], +32 core_base, +34
  core_size, +36 tmpl_off, +38 expt_off, +40 rows, +42 binder[3], +45
  state, +46 users, +47 pinned.  ACQUIRE -> A = 0 READY (block filled) or 1
  LOAD (block's `row` set, you own it).  GRANT(row, nbanks = how many more)
  -> the block's `banks`/`nbanks` (EPERM unless owner; EINVAL past 8).
  COMMIT(row, core_size, tmpl_off, expt_off, rows, binder, pinned, crc,
  minor) -> `core_base` assigned (the row's arena slot, kept for the boot).
  ABORT(row).  LOOKUP(name, major) -> the block, or ENOENT.

- [ ] **Step 1: The failing test.**  Add `basic` to `ldctl.c`:

```c
static int
basic()
{
    int r, row, yrow, b0;

    name("libx", 1);
    r = ldctl(LDS_ACQUIRE);
    say("basic", r == 1, "first acquire says load");
    row = blk.row;
    blk.nbanks = 2;
    r = ldctl(LDS_GRANT);
    say("basic", r >= 0 && blk.nbanks == 2 && blk.banks[0] && blk.banks[1] &&
        blk.banks[0] != blk.banks[1], "grant two banks");
    b0 = blk.banks[0];
    blk.core_size = 100;
    blk.pinned = 0;
    say("basic", ldctl(LDS_COMMIT) >= 0 && blk.core_base == 0xFFF8 - 100,
        "commit: first core under HEAP_LIM");
    name("libx", 1);
    say("basic", ldctl(LDS_ACQUIRE) == 0 && blk.users == 1 &&
        blk.banks[0] == b0 && blk.row == row, "acquire again: no double count");
    name("liby", 1);
    ldctl(LDS_ACQUIRE);
    yrow = blk.row;
    blk.nbanks = 1;
    ldctl(LDS_GRANT);
    blk.core_size = 50;
    say("basic", ldctl(LDS_COMMIT) >= 0 && blk.core_base == 0xFFF8 - 150,
        "second core stacks below");
    name("liby", 2);
    say("basic", ldctl(LDS_ACQUIRE) == 1 && blk.row != yrow,
        "another major is another row");
    ldctl(LDS_ABORT);                   /* liby 2 holds no banks */
    name("libnone", 1);
    say("basic", ldctl(LDS_LOOKUP) == -1 && errno == ENOENT, "lookup absent");
    say("basic", ldctl(0x80) == -1 && errno == ENOSYS, "hook selector refused");
    name("libz", 1);
    ldctl(LDS_ACQUIRE);
    blk.nbanks = 9;
    say("basic", ldctl(LDS_GRANT) == -1 && errno == EINVAL, "grant past 8");
    ldctl(LDS_ABORT);
    return 0;
}
```

  and `ldctl_basic.json` (`/testbin/ldctl basic`, contains `LDC basic ok`,
  lacks `LDC FAIL`, `PANIC`, `BRK`).

Run: `tools/mame_test/run.py ldctl_basic --fresh 2>&1 | tail -3`
Expected: FAIL (ENOSYS: no `ld.mod`).

- [ ] **Step 2: `ld.mod`.**  `src/modules/ld/ld.s`, header as fpsim's
  (`fpsim.s:44-76`, name `'ld'`, build id $0000), then:

```
;==============================================================================
; ld.mod - the shared-library registry (shared libc SP4 spec, section 4).
; One row per resident library: its banks (granted to the row, in no TCB),
; its core's base in the per-boot arena below HEAP_LIM, and who uses it.
; Reached only through LD_TRAMP ($00:031A): SYS_LDCTL's services 0-4 from
; the syscall, the kernel's hooks $80-$84.  Rules (section 4): no scratch
; in these statics lives across a KSVC_SLEEP or a Bank_Alloc; RECLAIM never
; picks a LOADING row and never sleeps.  Every static here is zero in the
; file (modimage checks a module's image against it).
;==============================================================================
LD_ROWS         EQU     16
LD_ROWSZ        EQU     52              ; the 48-byte block + owner, flags
LR_OWNER        EQU     48              ; pid loading it (LOADING)
LR_SLOT         EQU     49              ; 1 once core_base is assigned
ST_EMPTY        EQU     0               ; never used
ST_FREE         EQU     1               ; aborted or reclaimed; slot kept
ST_LOADING      EQU     2
ST_READY        EQU     3
LD_MAXBANKS     EQU     8

mod_init        MX      %00
                PHP
                SEP     #$20
                MX      %10
                LDA     #$5C                    ; JML
                STAL    LD_TRAMP+0
                LDA     #<ld_entry
                STAL    LD_TRAMP+1
                LDA     #>ld_entry
                STAL    LD_TRAMP+2
                PHK
                PLA
                STAL    LD_TRAMP+3
                PLP
                SEC
                RTL

; ld_entry - A = selector; services: X/Y = block offset/bank; hooks: Y = pid.
ld_entry        MX      %00
                PHB
                PHK
                PLB                             ; DBR = this module's bank
                CMP     #LDH_EXIT
                BCS     @le_hook
                ASL
                TAX                             ; (the block ptr is on stack)
                ...                             ; dispatch to svc_acquire etc.
```

  The services and hooks, each in this module's bank with DBR = it:

  - `copy_in` / `copy_out`: the 48-byte block between the caller's
    (offset, bank) and `ld_blk`, by an `MVN` whose operand bytes are
    patched in place and run under `PHP`/`SEI`/`PLP` (another caller could
    otherwise repatch it between the patch and the move); the bank bytes
    are zero in the file, as modimage requires (`modimage_check.py`, its
    zero-in-file clause).  `MVN` leaves DBR = its destination: after
    `copy_out` DBR is the caller's bank, so `copy_out` ends `PHK`/`PLB`.
    The caller's offset and bank arrive as the user's X/Y (the syscall
    dispatcher hands the handler `_Sys_SavedA/X/Y`, `syscall.s:361-366`)
    and stay on the stack, never in a static, so a woken ACQUIRE copies
    again.
  - `find_row` (name, major) -> row index or none; `new_row`.
  - `svc_acquire`: `KSVC_CURPID` -> pid.  READY: set the pid's bit, count
    it if new, copy the row out, A = 0.  EMPTY/absent: claim an empty row,
    LOADING, owner = pid, A = 1.  FREE: LOADING, owner = pid, banks kept,
    A = 1.  LOADING by another: `KSVC_SLEEP` on `WCHAN_LD`; A = 1 back
    (interrupted) -> C=0, A = EINTR; else find again.
  - `svc_grant`: owner check (EPERM); `nbanks + n <= 8` (EINVAL); n times
    `KSVC_BANKGRANT` into the row's banks; on ENOMEM keep what was granted,
    copy out, then C=0 + A = ENOMEM, so the caller sees how many it holds.
    The cap is 8 (a library is at most 8 segments); the spec's "the file's
    segment count" cannot be known to `ld.mod` -- recorded in Task 5.
  - `svc_commit`: owner check; copy the block's fields in; if `LR_SLOT` is
    0, `core_base = arena - core_size`, `arena = core_base`, `LR_SLOT = 1`;
    READY, users = 1, the owner's bit set; `KSVC_WAKEUP WCHAN_LD`; copy
    out.
  - `svc_abort`: owner check; FREE, owner 0; wake.
  - `svc_lookup`: copy the row out, or ENOENT.
  - `hook_exit(pid)`: for each row with the pid's bit: clear, users-1; a
    LOADING row the pid owns: FREE, owner 0, wake.
  - `hook_fork(child)`: the running process's bits become the child's,
    each row's users + 1.
  - `hook_exec(pid)`: as exit's release, without the LOADING abort (an
    exec'ing process is not loading).
  - `hook_talloc(pid)`: the pid's bits cleared, no count changed.
  - `hook_reclaim`: the first row that is READY **or FREE**, with users 0,
    not pinned, and banks held: `KSVC_BANKFREE` each, nbanks 0, FREE (slot
    kept); C=1.  None: C=0.  No sleep, never a LOADING row.  FREE counts
    because ABORT keeps a row's banks for its next loader (spec section 4),
    and a library that never reloads must not hold them for the boot.
  - No dead-owner takeover: the spec's "LOADING by a dead owner
    (`KSVC_TASKLOOKUP`): take it over" cannot arise, because every death
    reaches `_Exit_Core` (signal deaths too, `signal.s:1396`), whose hook
    ABORTs the dying owner's row and wakes its waiters.  Recorded in Task
    5's spec update.
  - Statics (zero in the file): `ld_rows` (16 x 52), `ld_use` (NPROC x 2:
    one bit per row), `ld_arena` (0 means `$FFF8`), `ld_blk` (48).

  The file is the executor's to write in full in this module's style
  (fpsim.s, klog.s), with each routine's register contract in its header.

- [ ] **Step 3: Build, stage, load.**  `gen_modplace.py` `ORDER` += `'ld'`
  (appended; nothing before it moves); `gen.py` `MODULES` += `"ld"`;
  `rc.in`/`modload.conf` gain `ld` before `ufsprobe`.

Run: `python3 tools/check_modload_lists.py && ninja all 2>&1 | tail -2`
Expected: clean; `disk_src/lib/modules/ld` built.

- [ ] **Step 4: Green.**

Run: `tools/mame_test/run.py ldctl_basic modimage --fresh 2>&1 | tail -3`
Expected: `2 passed` (`modimage` still clean with `ld.mod` loaded).

- [ ] **Step 5: `absent`'s new meaning.**  With `ld.mod` in `rc.in`, the
  `absent` mode's ACQUIRE would now succeed: drop that check from
  `absent()` (it keeps the hook-selector check, which `_Ld_Ctl` still
  refuses).  Rename the manifest `ldctl_selector`.

- [ ] **Step 6: Commit** (`feat(ld.mod): the shared-library registry and its services`).

---

### Task 4: the hooks and arbitration, proven

**Files:**
- Modify: `src/userland/ldctl/ldctl.c` (modes `fork`, `exec`, `race`,
  `intr`, `kill`, `eperm`, `reclaim`, `reuse`, and `look NAME`).
- Create: `tools/mame_test/tests/ldctl_{fork,exec,race,intr,kill,eperm,reclaim,reuse}.json`.

- [ ] **Step 1: The modes** (each prints `LDC <mode> ok` or a FAIL line):

  - `fork`: ACQUIRE+GRANT 1+COMMIT `libf`; `fork()`; the child LOOKUPs
    `libf` and `_exit(users == 2 ? 0 : 1)`; the parent waits, checks the
    status, then LOOKUP: users == 1.
  - `exec`: ACQUIRE+COMMIT `libe`; `vfork()`; the child `execl("/testbin/ldctl",
    "ldctl", "look", "libe", 0)`; `look` prints `LDC look users=%d`; expect
    `users=1` (the fork made the child a user, its exec released it).  A
    second `vfork()` whose child `execl("/nonexistent", ...)` fails, then
    LOOKUPs: users == 2 (a failed exec keeps its uses), `_exit(0)`.
  Every "A" child (the LOADING owner) ACQUIREs, GRANTs 1 and then loops
  `for (;;) pause();` until killed with SIGKILL: FGX's `pause()` is a ~1 s
  interruptible sleep that returns -1 (`syscall_misc.c:103-106`) and
  `sleep(1)` is 60 ticks (`:80-82`), so a single `pause()` would end, A
  would exit, its exit hook would free the row, and B would pass with
  arbitration off.

  - `race`: A as above on `librace`.  After `sleep(1)`, the parent LOOKUPs
    `librace` (LOADING) and keeps `banks[0]`.  Child B ACQUIREs `librace`
    -- it sleeps.  After another `sleep(1)` the parent `kill(A, SIGKILL)`;
    B wakes, gets 1 (LOAD), COMMITs, `_exit(0)`.  The parent reaps both,
    LOOKUPs: READY, users 0 (B exited), `banks[0]` equal to the value kept
    before the kill (the row kept A's bank for B).
  - `intr`: A as above on `libi`; B installs a `SIGUSR1` handler and
    ACQUIREs; the parent `kill(B, SIGUSR1)`; B's ACQUIRE returns -1, errno
    EINTR, `_exit(0)`; the parent kills A; LOOKUP: state FREE (A's exit
    aborted it), users 0.
  - `kill`: A as above on `libk`; B, with no handler, ACQUIREs; the parent
    `kill(B, SIGKILL)`; B's wait ends (`_sleep` returns C=1 with the signal
    pending, `sched.s:591-600`), `ld.mod` returns EINTR and the signal
    kills B on the way out; the parent reaps B by signal and LOOKUPs
    `libk`: still LOADING, users 0; then kills A.
  - `eperm`: A as above on `libp`; the parent GRANT/COMMIT/ABORT on A's row:
    each -1 with EPERM; kill A.
  - `reclaim`: a child ACQUIRE+GRANT 3+COMMIT `librc` and exits (users 0);
    another the same for `libpin` with `pinned = 1`; a third ACQUIREs
    `libab`, GRANTs 2 and ABORTs (FREE, banks kept).  Then, until LOOKUP
    `librc` shows `nbanks == 0`: a child ACQUIREs `drain<n>`, GRANTs 8,
    COMMITs and exits.  Fourteen spare rows of 8 banks exceed the 56-bank
    pool (`memmap.s:1230-1231`), so a drain row's GRANT finds the pool dry
    and `Bank_Alloc`'s reclaim re-enters `ld.mod` from inside that GRANT
    (Review Focus 5) and frees `librc`'s banks.  Then LOOKUP `librc`: FREE,
    `core_base` unchanged; `libab`: `nbanks == 0` (an aborted row's banks
    are reclaimed too); `libpin`: `nbanks == 3`.  (`malloc` cannot
    drain the pool: small blocks come from `sbrk` in the data bank and big
    ones from a kind-4 Memory Manager row, `malloc.c:110-111`,
    `syscall.s:7928-7940` -- neither calls `Bank_Alloc`.)
  - `reuse`: ACQUIRE+COMMIT `libr`; 40 times `fork()` a child that
    `_exit(0)`s at once; LOOKUP: users == 1.  It proves fork and exit
    counting across 40 slot recycles.  It does not test `Task_Alloc`'s
    zeroing, and no probe can: every death reaches the exit hook, and a
    fork rolled back by `Task_Free` (`process.s:1057-1068`) never ran the
    fork hook (`@vf_ready` is past it), so no stale bit can exist.  The
    TALLOC hook stays (the spec asks for it) as belt and braces, claimed
    as untested.

- [ ] **Step 2: Run each, fresh.**  Announce one `ninja all` and the runs.

Run: `tools/mame_test/run.py ldctl_fork ldctl_exec ldctl_race ldctl_intr ldctl_kill ldctl_eperm ldctl_reclaim ldctl_reuse --fresh 2>&1 | tail -3`
Expected: `8 passed`.  A failure: the mode's FAIL line names the check;
debug with superpowers:systematic-debugging.

- [ ] **Step 3: Controls -- each must go red, then restore.**
  - Exit hook off (`_Ld_Exit` returns at once): `ldctl_fork` fails (users
    stays 2) and `ldctl_reclaim` fails (`librc` never reaches 0 users).
  - Arbitration off (`svc_acquire` treats LOADING-by-another as absent):
    `ldctl_race` fails (B gets a LOAD while A lives, or another row).
  - Reclaim restricted to READY rows: `ldctl_reclaim` fails (`libab`, an
    aborted row holding banks, keeps them).
  (No control for `hook_talloc`: see `reuse`.)

- [ ] **Step 4: Commit** (`test(ld.mod): the registry's hooks and arbitration in MAME`).

---

### Task 5: record and gate

- [ ] **Step 1: The spec.**  Section 4: the selectors, the block layout,
  the row size and capacity as built; GRANT capped at 8 banks a row (ld.mod
  cannot know a file's segment count); no dead-owner takeover (the exit
  hook aborts a dying owner's row); reclaim takes READY or FREE rows;
  `Task_Alloc`'s zeroing kept but untestable (no stale bit can arise); section 6: each kernel piece's home
  and its bytes (core, far, tty), measured; section 12: the open items this
  step closed (`KSVC_SLEEP` from the module arm; `ld.mod`'s size).

- [ ] **Step 2: The gate** (kernel and module changed).  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 3: Commit and the project notes** (`group_id="fgx"`): step 1 landed;
  `LD_TRAMP`'s selectors; where the kernel pieces live; the probe.
