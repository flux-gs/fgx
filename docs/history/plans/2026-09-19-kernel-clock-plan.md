# A kernel UTC clock -- implementation plan

> For agentic workers: execute task by task, in order; each task ends green
> and committed.  Checkboxes track progress.  65816 assembly stays with the
> main session, not a subagent.

**Goal:** the kernel keeps the time of day in UTC, advanced by the VBL.
`gettimeofday`, `settimeofday` and `adjtime` serve it.  The IIgs battery clock
stays on local time: it is read at boot and written back by FreeBSD's rule.

**Architecture:**
- Core data holds the time as 32.32 fixed-point seconds, and the heartbeat adds
  one VBL to it.
- Everything else is far-bank C (`src/kernel/far/kern_time.c`) behind thin
  core thunks:
  - 2.11BSD's `gettimeofday`, `settimeofday` and `setthetime`;
  - Reno's `adjtime` slew, applied at read time;
  - FreeBSD's `inittodr`/`resettodr`, with `adjkerntz`, `wall_cmos_clock` and
    `disable_rtc_set`.
- Modules read the same clock through `KSVC_TIME`.

**Tech stack:** 65816 assembly under Merlin32 (core and far kernel banks);
kernel C and libc C through fcc; the MAME harness (`tools/mame_test`).

**Spec:** `docs/history/plans/2026-09-19-kernel-clock-design.md`.

## Amended 2026-09-25, before Task 3

Main moved between this plan and its Task 3, and the plan's reservations were
re-measured on `main` at fa30ad225.  Where the tasks below still say the old
thing, this section wins.

- **The C lives in the TTY bank, not the far bank** (the maintainer, 2026-09-25).  The
  far bank has 1,012 B free (3,894 when this plan was written); Task 3's C
  alone measures about 1.3 KB (fcc output at `root_sysctl.c`'s 1.42 B per
  line).  The tty bank has 10,771 B free and is live from boot.  So:
  `src/kernel/far/kern_time.c` is `src/kernel/tty/kern_time.c`; the accessors
  go in `src/kernel/tty/kc_sys.s` with `_ctpNNN` markers (from 060); the
  exports are the `tty` manifest; the entries are tty slots with stubs in
  `ttybank.s`, the `_KTty_Carrier` shape; core calls are `_ktpNNN JSL KTTY_*`.
- **Numbers:** syscalls 120-123 are now sigprocmask, setitimer, readv and
  writev, so `gettimeofday` is **124**, `adjtime` **125**, `settimeofday`
  **126**.  Far slots 74-77 are gone and not needed; the tty slots are 43 on
  (`KTTY_TOD_INIT` 43, `KTTY_TOD_GTOD` 44, `KTTY_TOD_ADJ` 45, `KTTY_TOD_STOD`
  46, `KTTY_TOD_NOW` 47, growing `KTTY_SLOT_COUNT` when more are needed).
  `KSVC_TIME` is **55** (54 is `KSVC_UNPNAME`).
- **Boot:** the far bank never calls the tty bank, so `inittodr` is a tty slot
  the CORE calls right after the root mount (`main.s`, after
  `KFAR_VFS_ROOTMOUNT`) -- 2.11BSD `init_main.c:197`'s place.  It takes its
  base from `_kRootFsTime`, a core cell `root_mount.c` fills with the root
  superblock's `fs_time`, and reads the battery clock itself with ReadTimeHex,
  as FreeBSD's `inittodr` reads the RTC, rather than borrowing the far bank's
  `_kBootTime`.
- **Core space:** 2,094 B free, not 114.
- **FreeBSD 2.2.8** `sys/i386/isa/clock.c`, `sys/i386/include/cpu.h` and
  `sbin/adjkerntz/adjkerntz.c` are vendored under `vendor/FreeBSD-2.2.8/` (they
  were read for the spec but not kept).

## Global constraints

- **Space.**
  - Core bank: 114 B code free and 94 B data free (`tools/check_kernel_ceiling.py`,
    measured 2026-09-19).  This plan spends about 63 B of core code and 12 B of
    core data, and returns about 20 B from the retired SYS_RTCWRITE thunk.
  - Far bank: 3,894 B free.
- **Files and history.**
  - ASCII only.
  - Source comments describe the current state; history goes in commit bodies.
  - Commit bodies are the changelog: informational, no names, no process.
- **Conformance.**  A syscall change names its BSD counterpart (file and
  function) in the commit.  The sources are listed in the spec's section 2.
- **Generated files.**
  - Never `git checkout` a generated file.
  - After a libc change: `cd toolchain && make piles archives`, and commit what
    moves.
  - After a change to the pile's hash: `python3 tools/ninja/gen.py`, then
    `ninja all`.
- **Tests and gate.**
  - Tests stay in the blast radius.  MAME runs headless
    (`SDL_VIDEODRIVER=dummy`).
  - `tools/gate.sh` gates each task; it is red on `stkfloor` only when it runs
    the full oracle (apple/fgx#450, pre-existing).
- **Your tree.**  Every rebuild of it is announced to the maintainer, with the branch
  and head.

## Shared names

| name | where | meaning |
|---|---|---|
| `_kTodSec`, `_kTodFrac` | core data, `memmap.s` | UTC seconds and the 2^-32 fraction |
| `_kTickFrac` | core data, `memmap.s` | one VBL in 2^-32 s |
| `SYS_GETTIMEOFDAY` / `SYS_ADJTIME` / `SYS_SETTIMEOFDAY` | `include/loader.s` | 120 / 121 / 122 |
| `KFAR_TOD_GTOD` / `KFAR_TOD_ADJ` / `KFAR_TOD_STOD` / `KFAR_TOD_NOW` | `include/kfar.s` | far slots 74-77 |
| `KSVC_TIME` | `include/modules.s` | 54; Y=0 UTC, Y=1 local; returns a long in A:X |
| `tod_snap[6]` | far C global | sec lo, sec hi, frac lo, frac hi, ticks lo, ticks hi |
| `_tod_argblk` | libc data, `libc_data.s` | 18 B marshalling block (flags + two timevals) |
| `CTL_MACHDEP` 7: `CPU_ADJKERNTZ` 2, `CPU_DISRTCSET` 3, `CPU_WALLCLOCK` 5 | FreeBSD 2.2.8 `sysctl.h:181`, `cpu.h:128-131` | FGX-local `CPU_TICK` 6 |

---

### Task 1: a root WriteTimeHex takes under MAME (spike, then fix)

MAME honours clock writes (`macrtc.cpp:274-291`), so root's
`date 1234; date` leaving the time unchanged is FGX's defect.

**Files:** `src/kernel/far/clock.s` (`_Sys_RtcWrite` 240-277, `_RtcFwWrite`
284-313); `toolchain/lib/libc_c/gettimeofday.c`; `src/userland/date/date.c`.

- [x] **Reproduce.**  A throwaway manifest runs `date 1234; date`, and the
  second line is not 12:34.
- [x] **Find the layer.**
  - Does libc's `settimeofday` pass the frame `gtime` built?  Print
    `__lc_rtc` from a scratch copy of date.
  - Does the far bank copy the caller's 6 bytes correctly?  Read `_rtcFrame`
    with a `memory_regions` entry (`symbol:` from the far listing) after the
    call.
  - Does WriteTimeHex receive the frame?  Stack words at the `JSL $E10000` in
    `_RtcFwWrite`: the ROM wants three words pushed in ReadTimeHex's layout
    (Toolbox Ref vol.1 p.627).
- [x] **Fix the layer that is wrong**, as its own commit.  If the fault is a
  separate defect, file it as a GitLab issue with the evidence and fix it on
  this branch.
- [x] **Verify:** `date 1234; date` shows `12:34:`.  Delete the throwaway
  manifest.

### Task 2: measure the VBL rate (`clkrate`)

**Files:** `src/userland/clkrate/clkrate.c` (new, FGX-original, with
`FGX-Provenance: none`); `tools/ninja/manifest.json` (tools list and
`/testbin` staging).

- [x] `clkrate [seconds]`, default 300:
  - wait for a battery-clock second edge by reading the clock directly
    (SYS_RTCREAD, #31), not through `gettimeofday`: once Task 3 lands, the
    kernel clock is itself driven by the VBL;
  - count SYS_TICKS (#52) until N more edges have passed;
  - print `CR ticks=%lu secs=%d tick_us=%ld` with tick_us = N * 1000000 /
    ticks.
- [x] **MAME:** expect `tick_us=16666` or `16667`.  MAME's VBL is exactly
  60.000 Hz: `A2GS_1M` / (65 x 262).  Measured 2026-09-19:
  `CR ticks=1800 secs=30 tick_us=16666`.
- [ ] **Hand the maintainer the command for the machine:** `/testbin/clkrate 600`.  His
  number becomes the documented hardware value in the man page.
- [x] **Commit.**

### Task 3: the time of day ticks, and `gettimeofday` (120) reads it

**Files:**
- `src/kernel/memmap.s`; `src/kernel/toolbox.s` (the heartbeat, after the
  `_kSystemTicks` increment at 328-330);
- `tools/gen_kernel_exports.py` (the `'far'` manifest);
- `src/kernel/far/kc_sys.s`; `src/kernel/far/kern_time.c` (new);
  `src/kernel/far/clock.s`;
- `include/kfar.s`; `src/kernel/far/far.s` (slots and PUT lines);
  `tools/ninja/gen.py` (the `_kc` tuple);
- `include/loader.s`; `src/kernel/syscall.s`;
- `toolchain/lib/libc_c/gettimeofday.c`; `toolchain/lib/libc_data.s`;
  `toolchain/include/time.h` (the comment on line 3);
- `docs/userland-abi.md` (`python3 tools/gen_syscall_table.py`);
- `src/userland/timetest/timetest.c` (new); `tools/mame_test/tests/timetest.json`
  (new).

- [x] **Core data**, in `memmap.s`'s DUM:
  `_kTodSec DS 4`, `_kTodFrac DS 4`, `_kTickFrac DS 4`.
- [x] **The heartbeat**, right after `@hb_noHi`.  This is Reno
  `kern_clock.c:223`'s `BUMPTIME(&time, tick)` in 32.32:

```
                LDA     _kTodFrac               ; the time of day, 32.32: Reno
                CLC                             ;   kern_clock.c:223 BUMPTIME
                ADC     _kTickFrac
                STA     _kTodFrac
                LDA     _kTodFrac+2
                ADC     _kTickFrac+2
                STA     _kTodFrac+2
                BCC     @hb_tod
                INC     _kTodSec
                BNE     @hb_tod
                INC     _kTodSec+2
@hb_tod
```

- [x] **Export the three words to the far bank**:
  `('_kTodSec','_kTodSec',0,'abs24')` and likewise `_kTodFrac`, `_kTickFrac`
  and `_kSystemTicks`.
- [x] **Far accessors** in `far/kc_sys.s`.  They run under `PHP/SEI`, so the
  heartbeat cannot tear a copy.  `kc_todsnap` copies sec, frac and the ticks
  into `tod_snap[6]`:

```
kc_todsnap      MX      %00
                PHP
                SEI
_cfp130         LDAL    _kTodSec
                STA     tod_snap
_cfp131         LDAL    _kTodSec+2
                STA     tod_snap+2
_cfp132         LDAL    _kTodFrac
                STA     tod_snap+4
_cfp133         LDAL    _kTodFrac+2
                STA     tod_snap+6
_cfp134         LDAL    _kSystemTicks
                STA     tod_snap+8
_cfp135         LDAL    _kSystemTicks+2
                STA     tod_snap+10
                PLP
                RTL
```

  - `kc_todstore` writes `tod_new[4]` (sec lo/hi, frac lo/hi) into core with
    `STAL` in the same shape.
  - `kc_tickset` writes `tod_tick[2]` into `_kTickFrac`.
  - Pick `_cfp` numbers unused in the far bank; `gen_far_bankpatch.py ... far
    --check` regenerates `far/core_patchsites.s`.
- [x] **`far/kern_time.c`**, with a header per `root_sysctl.c:1-7`.  Its
  `FGX-Provenance` names 2.11BSD `kern_time.c` with
  `Copyright (c) 1986 Regents of the University of California.` verbatim from
  `vendor/2.11BSD/usr/sys/sys/kern_time.c:2`.  First part:

```c
unsigned tod_snap[6];                   /* kc_todsnap: sec, frac, ticks */
unsigned tod_new[4];                    /* kc_todstore: sec, frac */
unsigned tod_tick[2];                   /* kc_tickset: _kTickFrac */
int      tod_valid;                     /* the clock has been set */
int      tick = 16667;                  /* us per VBL; machdep.tick */
int      tz_minuteswest, tz_dsttime;    /* 2.11BSD conf/param.c:40 */
int      adjkerntz;                     /* FreeBSD clock.c:100 */
int      disable_rtc_set;               /* FreeBSD clock.c:101 */
int      wall_cmos_clock = 1;           /* FreeBSD clock.c:119; IIgs = local */

/* frac (2^-32 s) <-> usec.  1e6 / 65536 = 15625 / 1024. */
static long tod_usec(hi) unsigned hi;
{ return ((long)hi * 15625L) >> 10; }
static unsigned tod_frachi(usec) long usec;
{ return (unsigned)((usec << 10) / 15625L); }

/* One VBL in 2^-32 s: tick * 2^32 / 1e6 = (tick << 16) / 15625 << 10. */
static void tod_settick(us) int us;
{
    long a = (long)us << 16;
    long hi = a / 15625L, rem = a % 15625L;
    long v = (hi << 10) + ((rem << 10) / 15625L);
    tod_tick[0] = (unsigned)v; tod_tick[1] = (unsigned)(v >> 16);
    kc_tickset();
}

/* The clock as a timeval (Task 5 adds the adjtime slew here). */
static void tod_read(sec, usec) long *sec; long *usec;
{
    kc_todsnap();
    *sec  = (long)tod_snap[0] | ((long)tod_snap[1] << 16);
    *usec = tod_usec(tod_snap[3]);
}

static void tod_write(sec, usec) long sec; long usec;
{
    tod_new[0] = (unsigned)sec; tod_new[1] = (unsigned)(sec >> 16);
    tod_new[2] = 0;             tod_new[3] = tod_frachi(usec);
    kc_todstore();
    tod_valid = 1;
}

/* the offset FreeBSD adds to a wall clock: clock.c:755 and :788 */
static long tod_localoff()
{ return (long)tz_minuteswest * 60L + (wall_cmos_clock ? (long)adjkerntz : 0L); }

/* 2.11BSD kern_time.c:22 gettimeofday.  blk: [0..3] tv_sec, [4..7] tv_usec,
 * [8..9] tz_minuteswest, [10..11] tz_dsttime -- written whole; libc copies
 * out only what the caller asked for. */
int tod_gettimeofday(blk) long *blk;
{
    long s, u;
    tod_read(&s, &u);
    blk[0] = s; blk[1] = u;
    ((int *)blk)[4] = tz_minuteswest; ((int *)blk)[5] = tz_dsttime;
    return 0;
}
```

- [x] **`inittodr`**: FreeBSD `clock.c:709` with 2.11BSD `init_main.c:197`'s
  order.
  - `tod_init()` runs at the end of `_KCaptureBootTime` (`far/clock.s:352`, a
    JSL to a pile-call entry in the vfs_seam_entry shape).
  - It sets the tick with `tod_settick(tick)`.
  - It converts `_kBootTime`'s local frame with `kern_epoch`, by
    `#include "../vfs/kern_epoch.c"`.  If that gives a non-zero epoch, it calls
    `tod_write(epoch + tod_localoff(), 0)`.
  - `root_mount.c`, after line 187 succeeds:
    `if (!tod_valid) tod_write(root_ump.um_sb.sb_time, 0L);`.
- [x] **The syscall.**
  - `SYS_GETTIMEOFDAY EQU 120` with continuation-comment doc lines.
    `SYS_NUM_MAX` names it; Task 4 moves it to 122.
  - Table entry `DA _thunk_Gtod`.
  - The thunk in `_thunk_RtcRead`'s shape:
    `LDX _Sys_CallerBank / _kfpNNN JSL KFAR_TOD_GTOD / RTS`.
  - Far slot 74 is a `JMP _Tod_Gtod`.  `_Tod_Gtod` is `_Vfs_Sysctl`'s entry
    shape with one far pointer, bank from X, offset from A.  It pile-calls
    `tod_gettimeofday`, and then does `TAY / BNE err / SEC / RTL`, or on error
    `err: TYA / CLC / RTL`.
- [x] **libc**: `gettimeofday` marshals through `_tod_argblk`
  (`libc_data.s`: `_tod_argblk DS 18`), then:

```c
int gettimeofday(struct timeval *tv, struct timezone *tz)
{
    int r = (int)__syscall(120, (unsigned)(unsigned long)&_tod_argblk[0], 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    if (tv) { tv->tv_sec = *(long *)&_tod_argblk[0];
              tv->tv_usec = *(long *)&_tod_argblk[4]; }
    if (tz) { tz->tz_minuteswest = *(int *)&_tod_argblk[8];
              tz->tz_dsttime = *(int *)&_tod_argblk[10]; }
    return 0;
}
```

  `__lc_epoch` stays for `settimeofday` until Task 4.
- [x] **timetest (A)** prints one line per check and a verdict:
  - `TT A1 adv=%ld`: two `gettimeofday` calls around `sleep(3)`; pass if 2..4.
  - `TT A2 usec=%d`: 20 reads 1 tick apart (SYS_TICKS spin); pass if
    `tv_usec` takes more than one value.
  - The manifest asserts `TT A1 ok`, `TT A2 ok` and `TT VERDICT PASS`.
- [x] **Build, gate, commit:**
  `feat(kernel): the kernel keeps the time of day, and gettimeofday reads it`,
  citing 2.11BSD `kern_time.c` `gettimeofday` (22), Reno `kern_clock.c:223`
  and FreeBSD `clock.c` `inittodr` (709).

### Task 4: `settimeofday` (122) sets it and writes the battery clock back

**Done 2026-09-25, with three departures, each from reading the source:**
- **No write-back at shutdown.**  FreeBSD 2.2.8's `boot()` syncs and unmounts
  and never calls `resettodr` (`kern_shutdown.c:174-235`, vendored); its only
  callers are `settimeofday` (`kern_time.c:144`) and a `machdep.adjkerntz`
  write (`machdep.c:716`).  The reboot bullet below is not carried.
- **`boottime` is not moved.**  Both BSDs move it by the step; FGX's uptime
  is SYS_UPTIME's battery-clock snapshot against the battery clock, which
  nothing kernel-side would feed.
- **The manual reboot run is `timetest` B2 instead:** after a root
  `settimeofday`, the battery clock read directly agrees with the kernel
  within 2 s, which is the write-back itself.  With `kc_rtcwrite` disabled it
  reads 999 s off.
- Also carried: FreeBSD's `EINVAL` for a `tv_usec` outside 0..999999
  (`kern_time.c:111`), checked before anything changes.

**Files:**
- `include/loader.s`; `src/kernel/syscall.s`; `include/kfar.s`;
  `src/kernel/far/far.s`;
- `src/kernel/far/kern_time.c`; `src/kernel/far/kc_sys.s`;
  `src/kernel/far/clock.s`;
- `src/kernel/vfs/vfs_syscalls.c` (`vfs_syncclean`);
- `toolchain/lib/libc_c/gettimeofday.c`; `toolchain/include/sys/time.h`;
- `tools/check_bsd_enforcement.py`; `tools/mame_test/tests/permtest.json`
  (unchanged; must stay green); timetest.

- [x] `SYS_SETTIMEOFDAY EQU 122`, with `SYS_NUM_MAX` naming it.  Table slot 121
  is `DA _Sys_Stub` until Task 5.
- [x] **The thunk** keeps #446's `_Suser` check.  It is the old
  `_thunk_RtcWrite` renamed `_thunk_Stod`, with its JSL aimed at
  `KFAR_TOD_STOD` (slot 76).
  - Slot 32 in the table becomes `DA _Sys_Stub`.
  - `_Sys_RtcWrite` and far slot 7 are deleted; the slot becomes
    `JMP _Far_StubHalt`.
- [x] **`tod_settimeofday(blk)`**:
  - blk `[0]` flags: bit 0 = tv given, bit 1 = tz given; `[1..4]` tv;
    `[5..6]` tz.
  - tv: `tod_write(sec, usec)`, clear the adjtime state (Task 5), then
    `resettodr()`.  That is 2.11BSD `setthetime` (75) plus FreeBSD
    `settimeofday`'s `resettodr`.
  - tz: `tz_minuteswest`/`tz_dsttime`, which is 2.11BSD `kern_time.c:67`.  The
    core thunk has already asked `_Suser` for the whole call.
- [x] **`resettodr()`**, FreeBSD `clock.c:771`:

```c
void resettodr()
{
    long t, s, u;
    if (disable_rtc_set)
        return;
    tod_read(&s, &u);
    t = s - tod_localoff();             /* FreeBSD clock.c:788 */
    tod_frame(t, tod_rtcframe);         /* sec min hour year-1900 day0 mon0 */
    kc_rtcwrite();                      /* far asm: JSR _RtcFwWrite */
}
```

  - `tod_frame` is the inverse of `kern_epoch`: walk years from 1970 with
    `(year & 3)` leap years, then months, as `pd_date` does
    (`prodos_write.c:267-307`).
  - `kc_rtcwrite` copies `tod_rtcframe` into `_rtcFrame` and calls the
    existing `_RtcFwWrite`.
- [x] **At shutdown**, FreeBSD `boot()`'s `resettodr`: `vfs_syncclean()` calls
  `resettodr()` before `vfs_sync()`.  That is far C already on the reboot path
  (`main.s:1210`), so it costs no core bytes.
- [x] **libc**: `settimeofday` fills flags plus tv and tz into `_tod_argblk`,
  then `__syscall(122, ...)` with the errno idiom.  `__lc_epoch` goes, and
  `sys/time.h` gains `int settimeofday();`.
- [x] **Checker**: `tools/check_bsd_enforcement.py` moves `kern_time.c:67` and
  `:80` to `carried` at `src/kernel/syscall.s::_thunk_Stod`.  `--self-test` and
  a mutation (drop the `JSR _Suser`, checker red, restore) prove it.
- [x] **timetest (B)**, as root:
  - `TT B1`: settimeofday(now + 1000); gettimeofday reads now + 1000 within
    1 s; restore.
  - `TT B2`: settimeofday with only tz; gettimeofday returns that tz; restore
    `{0,0}`.
- [x] **One manual MAME run for write-back** (recorded in the commit, not a
  manifest):
  - `settimeofday` to a known time, then `reboot`;
  - the next boot's `date` shows that time, which proves `resettodr` wrote the
    battery clock and `inittodr` read it.
- [x] **permtest** stays green: uid 77 still gets `PT st=-1 e=1`, now through
  122.
- [x] **Build, gate, commit:**
  `feat(kernel): settimeofday sets the kernel clock and writes the battery clock back`,
  citing 2.11BSD `setthetime` (75) and FreeBSD `resettodr` (771).

### Task 5: `adjtime` (121) slews it, Reno's way

**Done 2026-09-25.  The slew is FreeBSD 2.2.8's, not Reno's.**  Reading Reno's
`adjtime` (`kern_time.c:100`) found it rounding the correction to a multiple
of `tickadj` while slewing at `10 * tickadj` above `bigadj`, so a large
correction need not be a whole number of steps and overshoots; it also picks
the rate only when no slew is running.  NetBSD 0.9 is identical.  FreeBSD
2.2.8 (`vendor/FreeBSD-2.2.8/sys/kern/kern_time.c`) rounds to the rate itself,
"lest the correction overshoot", picks it every call and the same way either
side of zero, and carries a signed `tickdelta`.  `tickadj` is Reno's
`conf/param.c:63` (vendored), 66 us at 60 Hz.  The slew is applied at read
time and folded into the core clock before `settimeofday` or `adjtime`
replaces anything.

**Files:** `include/loader.s`; `src/kernel/syscall.s`; `include/kfar.s`;
`src/kernel/far/far.s`; `src/kernel/far/kern_time.c`;
`toolchain/lib/libc_c/gettimeofday.c`; `toolchain/include/sys/time.h`;
`tools/check_bsd_enforcement.py`; `src/userland/permtest/permtest.c`;
`tools/mame_test/tests/permtest.json`; timetest.

- [x] `SYS_ADJTIME EQU 121`.  The thunk is `_Suser` then
  `JSL KFAR_TOD_ADJ` (slot 75), the same shape as `_thunk_Stod`.
- [x] **Reno's state and rule**, following `kern_time.c:94-131`:

```c
long adj_delta;         /* Reno timedelta: the correction still owed, us */
long adj_tickdelta;     /* Reno tickdelta: us per tick while slewing */
unsigned adj_t0[2];     /* ticks when the slew began */
#define TICKADJ  (240000 / (60 * 60))   /* Reno conf/param.c's tickadj at 60 Hz */
#define BIGADJ   1000000L               /* Reno kern_time.c:97 */
```

  - **Before writing the macros**, open `examples/4.3BSD-Reno` for `tickadj`'s
    definition and copy it; do not trust the value above.
  - **Applied so far**: `min(|adj_delta|, adj_tickdelta * ticks_since(adj_t0))`
    with `adj_delta`'s sign.  `tod_read` adds it to the raw time.
  - **`tod_adjtime(blk)`**:
    - fold the applied part into the raw clock with `tod_write`;
    - compute the new `ndelta = sec * 1000000 + usec`;
    - pick `tickdelta` (10x above `BIGADJ`) and round `ndelta` as Reno does;
    - return the old remaining value in blk's olddelta;
    - set `adj_delta = ndelta` and `adj_t0` = now.
- [x] **libc**: `adjtime(delta, olddelta)` marshals flags plus two timevals
  into `_tod_argblk` and calls `__syscall(121, ...)`.  Add a prototype in
  `sys/time.h`.
- [x] **Checker**: `kern_time.c:123` becomes `carried` at
  `syscall.s::_thunk_Adj`.
- [x] **permtest**: as uid 77, `adjtime({1,0}, 0)` must fail with EPERM.  Print
  `PT adj=%d e=%d` and assert `PT adj=-1 e=1`.  Before the thunk has its check,
  run it once to see it fail.
- [x] **timetest (C)**:
  - `adjtime({2,0}, 0)`, then `adjtime({0,0}, &old)` shows `old` just under 2 s
    (Reno returns the unapplied part);
  - a later read shows it smaller;
  - finally `adjtime({0,0}, 0)`.
- [x] **Build, gate, commit:** `feat(kernel): adjtime slews the clock`, citing
  2.11BSD `adjtime` (113) for the check and Reno `kern_time.c:100` and
  `kern_clock.c:223` for the slew.

### Task 6: the `machdep` sysctls

**Done 2026-09-25, in the tty bank rather than `root_sysctl.c`.**  The core's
`_Sys_Sysctl` switches on `name[0]` as 2.11BSD's `__sysctl` does
(`kern_sysctl.c:112-135`): `CTL_MACHDEP` goes to `tod_sysctl` (tty slot 47),
everything else to the far bank as before.  2.11BSD's own `cpu_sysctl`
(`pdp/kern_pdp.c:212`) serves only the PDP's leaves, though its `h/sysctl.h`
defines these three ids; the leaves are FreeBSD's (`machdep.c:709-728`),
including `resettodr` on an `adjkerntz` write (`:716`).  `CPU_TICK` is 6, the
id 2.11BSD's `CPU_MAXID` leaves free.

**Files:** `src/kernel/far/root_sysctl.c`; `src/kernel/far/kern_time.c`;
`src/userland/sysctltest/sysctltest.c`, or timetest if smaller;
`tools/check_bsd_enforcement.py`, if the registry covers kern_sysctl leaves.

- [x] **Add `CTL_MACHDEP` (7)** with `CPU_ADJKERNTZ` (2), `CPU_DISRTCSET` (3)
  and `CPU_WALLCLOCK` (5) through the existing `sysctl_int` path.  Add the
  FGX-local `CPU_TICK` (6), whose write calls `tod_settick`.
  - Writes need uid 0, which the existing path already asks.
  - The ids come from FreeBSD 2.2.8 `sys/sysctl.h:181` and
    `i386/include/cpu.h:127-132`, cited in the source comment.
- [x] **timetest (D)** round-trips each leaf and restores it.  It also shows
  that `machdep.tick` changes the rate: over 3 s with tick doubled, `adv` is
  about 6.
- [x] **Build, gate, commit.**

### Task 7: modules read the kernel clock (`KSVC_TIME`)

**Done 2026-09-25.**  `KSVC_TIME` is 55 and reaches tty slot 48.  Two
departures: the never-backward clamp goes too, because 2.11BSD's `ITIMES`
stamps with `time` as it stands and the clamp's reason (#182's ROM re-sync
stepping back) went with the ROM; and `kern_epoch` leaves ufs.mod and
prodosw.mod, which no longer convert a frame (prodos.mod's reader keeps it).
timetest E covers UFS; ProDOS's local stamp has no volume in the suite to
land on and is covered by reading.

**Files:**
- `include/modules.s`; `src/kernel/jumptable.s`;
  `src/modules/common/kc_sys.s`;
- `src/kernel/vfs/kern_time.c`; `src/kernel/vfs/prodos_write.c` (401, 559,
  852);
- `src/kernel/far/kern_time.c`; `include/kfar.s`; `src/kernel/far/far.s`;
- timetest.

- [x] **`KSVC_TIME EQU 54`**, and `KSVC_COUNT` becomes 55.
  - The arm is `_kfpNNN JSL KFAR_TOD_NOW / PLB / SEC / RTL`, returning A=lo
    and X=hi, with Y as the shim set it.
  - Chain it after `@kc_s52` (`jumptable.s:536-548`).
  - **Retire `@kc_rtcframe`**, whose only caller goes below, and its chain
    step.  KSVC_RTCFRAME's number stays reserved (append only).
- [x] **Far slot 77**: `JMP _Tod_Now`.
  - It takes Y (0 = UTC, 1 = local) and pile-calls `long tod_now(local)`,
    which is `tod_read` minus `tod_localoff()` when local.
  - It returns A:X.  There are two shims, so that C passes no argument:
    `kc_time: LDY #0 / LDX #KSVC_TIME / JSL SYS_KCALL / RTL`, and `kc_ltime`
    with `LDY #1`.
- [x] **`src/kernel/vfs/kern_time.c` shrinks** to
  `long kern_time() { return kt_mono(kc_time()); }` plus
  `long kern_ltime() { return kc_ltime(); }`.  #182's ROM re-sync, `kt_rtc`
  and `KT_RESYNC_TICKS` go; the never-backward clamp stays.
- [x] **ProDOS stamps local time**: prodos_write.c's three calls become
  `kern_ltime()`.  UFS keeps `kern_time()`, which is UTC.
- [x] **timetest (E)**:
  - create `/tmp/tt.e`, `stat` it, and compare `st_mtime` with
    `gettimeofday`: equal within 2 s (`TT E1`);
  - with `machdep.adjkerntz` = 3600, a UFS mtime still matches UTC (`TT E2`);
    restore.
- [x] **Build, gate, commit:**
  `feat(kernel): modules read the kernel clock; ProDOS stamps local time`.

### Task 8: documentation and provenance

- [x] **Man pages**, cat-formatted like `sysctl.0`: `gettimeofday(2)`
  (settimeofday on the same page) and `adjtime(2)`.
  - BUGS: `tv_usec` has a 15 us step; `machdep.tick` is FGX-local; the local
    offset comes from `adjkerntz` (sub-project 3).
  - Landed as 2.11BSD's own cat pages, vendored, with FGX's differences
    written in; the BUGS section names the `machdep` leaves that exist now
    rather than sub-project 3.
- [x] **`docs/PROVENANCE.md`** rows:
  - `src/kernel/far/kern_time.c`: 2.11BSD `kern_time.c` (`gettimeofday` :22,
    `settimeofday` :49, `setthetime` :75, `adjtime` :113) with Reno
    `kern_time.c` `adjtime` (:100);
  - a third-party row: FreeBSD 2.2.8 `sys/i386/isa/clock.c` (`inittodr`,
    `resettodr`), BSD licence, with the SPDX id in the file.
  - Landed with Task 3 as ONE row for `src/kernel/tty/kern_time.c` naming
    every upstream it draws from; the vendored FreeBSD 2.2.8 files carry
    their own.  The man pages have a row of their own.
- [x] **ROADMAP**: a pointer paragraph.  Spec status: implemented, with the
  merge ref.
- [x] **the project notes**: one episode for the landed design; update the kernel-clock
  facts.
- [ ] **Commit; push after asking; MR for the maintainer.**
