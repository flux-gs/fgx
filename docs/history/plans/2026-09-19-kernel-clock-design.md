# A kernel UTC clock -- design

- **Status:** designed 2026-09-19 with the maintainer; implemented 2026-09-25 on
  feat/kernel-clock (plan Tasks 3-8).  Sub-project 1 of 3 of the time
  work that NTP and Kerberos 5 need.
- **Goal:** the kernel keeps the time of day in UTC, as BSD does.
  `gettimeofday(2)` reads it and `settimeofday(2)` sets it.  The IIgs battery
  clock stays on local time.
- **Why now:** a KDC refuses a client more than 300 s off, NTP works in UTC,
  and 2.11BSD's `ntp -s` sets the clock through `settimeofday`.  See
  `reports/Kerberos 5 port survey for FGX.md` (untracked, repo root) for the
  wider plan.
- **The other two sub-projects** get their own designs:
  2. libc time zones: 2.11BSD's Olson `ctime.c` (`tzset`, `localtime`), `zic`,
     and current IANA zoneinfo data.
  3. `adjkerntz(8)` and cron: daylight-saving tracking for a battery clock kept
     on local time.

## 1. What the code does today

Read 2026-09-19 on `main` at `1f5f5e54f`.

- **Userland reads the ROM on every call.**
  - `gettimeofday` (`toolchain/lib/libc_c/gettimeofday.c`) calls SYS_RTCREAD
    (#31), which runs ReadTimeHex in the far bank (`src/kernel/far/clock.s`).
    It then converts the local frame to an epoch with no offset:
    `tv_sec = __lc_epoch(...) + sec`, `tv_usec = 0`.
  - The zone it returns is always zeroed.
  - `kern_time.c` measured that ROM excursion at 3.6 ms, with interrupts off.
- **`settimeofday` writes the battery clock directly**, through SYS_RTCWRITE
  (#32) and WriteTimeHex.  Since apple/fgx#446 it is root-only.
- **Kernel C has its own derived clock** (`src/kernel/vfs/kern_time.c`,
  apple/fgx#182).
  - It reads the ROM once, adds `_kSystemTicks / 60`, and re-syncs from the ROM
    every 60 s.
  - It clamps so that time never runs backwards.
  - ufs.mod and prodos.mod each link their own copy.
  - It treats the RTC's local time as the epoch.
- **The tick.** `_HBTickTask` (`src/kernel/toolbox.s:313-331`) is the
  firmware heartbeat.  It fires every VBL and increments `_kSystemTicks`.  No
  time of day is maintained from it.
- **Boot.** `_kBootTime` (`far/clock.s:333`) holds a boot-time ReadTimeHex
  snapshot, used for uptime.
- **What FGX lacks:** kernel time zone state, `adjtime(2)`, and a `machdep`
  sysctl node.  `root_sysctl.c` serves `kern.securelevel` only.
- **Space.** `check_kernel_ceiling.py` on the current build: core bank 114 B
  free, far bank 3,894 B, tty bank 10,608 B.
- **Measured under MAME** (main and fix/446): as root, `date 1234; date`
  reports no error, yet the time read back does not move.  Whether MAME
  ignores WriteTimeHex or the write path is broken is not yet known.

## 2. The sources

Each was read for this design.

- **2.11BSD `usr/sys/sys/kern_clock.c:129-140`, `hardclock`.**
  `if (++lbolt >= hz) { lbolt -= hz; ++time.tv_sec; }`, with `adjdelta`
  adding or dropping a tick while `adjtime` slews.
- **2.11BSD `usr/sys/sys/kern_time.c`.**
  - `gettimeofday` (line 22): copies out `time`, with
    `tv_usec = lbolt * mshz`, and the kernel's `tz`.
  - `settimeofday` (49): sets `tz` only `if (uap->tzp && suser())` (67).
  - `setthetime` (75): `if (!suser()) return;` (80), then sets `time`.
    `resettodr()` sits under `#ifdef notyet`.
  - `adjtime` (113): `suser()`, then `adjdelta`.
- **2.11BSD `usr/sys/sys/init_main.c:197-200`.**
  `time.tv_sec = fs->fs_time; if (toytime = toyclk()) time.tv_sec = toytime;
  boottime = time;`
- **2.11BSD `usr/sys/conf/param.c:40`.**
  `struct timezone tz = { %TIMEZONE%, %DST% };`
- **FreeBSD 2.2.8 `sys/i386/isa/clock.c`.**
  - `int adjkerntz; /* local offset from GMT in seconds */` (100)
  - `int disable_rtc_set; /* disable resettodr() if != 0 */` (101)
  - `int wall_cmos_clock; /* wall CMOS clock assumed if != 0 */` (119)
  - `inittodr` reads the CMOS clock as local seconds, then
    `sec += tz.tz_minuteswest * 60 + (wall_cmos_clock ? adjkerntz : 0);` (755).
  - `resettodr` returns early `if (disable_rtc_set)`, otherwise
    `tm -= tz.tz_minuteswest * 60 + (wall_cmos_clock ? adjkerntz : 0);` (788)
    and writes local time.
- **4.3BSD-Reno `kern/kern_time.c:94-131` and `kern/kern_clock.c:223-234`.**
  The clock does `BUMPTIME(&time, tick)` each tick.  While `timedelta`
  (microseconds) is non-zero, it adds `tick +/- tickdelta` and moves
  `timedelta` toward 0.  `adjtime` sets `tickdelta = tickadj`, or
  `10 * tickadj` above `bigadj` (1 s), and returns the unapplied `timedelta`
  as `olddelta`.
- **MAME `src/mame/apple/apple2gs.cpp:99,3795`.**  `A2GS_1M` is 1,021,800 Hz
  and a frame is 65 x 262 = 17,030 cycles, so the emulated VBL is exactly
  60.000 Hz.  Real hardware stretches cycles and is not 60 Hz; its rate is
  measured, not assumed.
- **MAME `src/mame/apple/macrtc.cpp:274-291`.**  A write to the clock's
  seconds registers is honoured (`m_seconds[i & 3] = m_data_byte;
  m_time_was_set = true;`) unless write-protect is set, and write-protect
  resets to 0.  So the failure of root's `date 1234` under MAME is FGX's,
  not the emulator's.
- **FreeBSD 2.2.8 `sbin/adjkerntz/adjkerntz.c`** (377 lines).  It drives
  those variables through the `machdep` sysctls.  Its man page: "The
  adjkerntz utility maintains synchronization between the kernel clock
  (always UTC) and the real-time clock (RTC), which may be set to local time."

## 3. Design

### 3.1 State

- **Core data** (`memmap.s`, 12 of 94 free bytes), because the heartbeat must
  reach it:
  - `_kTodSec` and `_kTodFrac`: the time of day as 32.32 fixed-point seconds
    since the epoch, which is NTP's own format.
  - `_kTickFrac`: one VBL in units of 2^-32 s.
- **Far-bank data** for everything else:
- `time`'s derived views: `boottime`, as in 2.11BSD.
- `tz` (`struct timezone`): 2.11BSD, default `{0, 0}`.
- `adjkerntz`, `wall_cmos_clock` (default **1**, because the IIgs clock holds
  local time) and `disable_rtc_set`: FreeBSD.
- `tick`: microseconds per VBL; it sets `_kTickFrac`.
- `timedelta` and `tickdelta`: Reno's pending `adjtime` correction, plus the
  tick count at which it started.

### 3.2 The tick advances `time`

- `_HBTickTask` adds `_kTickFrac` to `_kTodFrac` after its `_kSystemTicks`
  increment, and a carry bumps `_kTodSec`.  That is Reno's
  `BUMPTIME(&time, tick)` in a binary fraction of a second, and it costs about
  29 bytes of core code.
- `tv_usec` is derived only when someone reads the clock:
  `(frac >> 16) * 15625 >> 10`, which gives a 15 us step.
- **Reno's `adjtime` slew is applied at read time**, in far-bank C: the
  reported time is the raw clock plus `min(|timedelta|, tickdelta x ticks since
  the adjtime)`, with the sign of `timedelta`.  The result is folded into the
  raw clock once it is complete.  Readers see what Reno's `hardclock` would
  have produced, and the interrupt pays nothing for it.
- This is Reno's `tick`-per-interrupt form, not 2.11BSD's integer `hz`.
  - The IIgs VBL is not 60 Hz, and `kern_time.c` records the 0.1% error of
    assuming it is: about 86 s a day, past a KDC's 300 s in 3.5 days.
  - `tick` is therefore **measured**.  MAME's is exactly 16,667 us (60.000 Hz,
    from its source).  Real hardware's is measured on the machine (NTSC; PAL
    differs).  It stays settable as `machdep.tick` (an FGX-local sysctl), the
    job xntp's `tickadj(8)` does through `/dev/kmem` on other BSDs.
- The heartbeat body lives in the core bank.  With 114 B free there, the add
  stays as small as the 65816 allows, and everything else stays in the far
  bank.

### 3.3 Boot: `inittodr`

- 2.11BSD's order: `time.tv_sec` starts at the root superblock's `fs_time`,
  and the battery clock overrides it when it reads a valid time.
- The battery clock's local seconds become UTC by FreeBSD's formula:
  `+ tz.tz_minuteswest * 60 + (wall_cmos_clock ? adjkerntz : 0)`.
- `boottime = time`.  The boot ReadTimeHex this needs is the one `_kBootTime`
  already takes.

### 3.4 System calls

- **Numbering.**  The syscall table is dense and costs 2 core bytes per
  entry, fillers included.  So the three calls take 120-122 with no gaps:
  - **120 `gettimeofday`.**  2.11BSD's number, 116, is FGX's SYS_REBOOT.
  - **121 `adjtime`**, FGX-local.  2.11BSD's 140 would cost 36 bytes of
    fillers.
  - **122 `settimeofday`**, which is 2.11BSD's own number.

  The syscall review already settled that FGX's numbers are not an axis.
- **`gettimeofday`** copies out `time` and `tz`: 2.11BSD `kern_time.c:22`.
  libc's wrapper stops reading the ROM.
- **`settimeofday`**:
  - `tz` is set only by the super user (kern_time.c:67);
  - `setthetime` is root-only (kern_time.c:80, already enforced by #446 at the
    old entry) and sets `time`;
  - then FreeBSD's `resettodr` writes the battery clock back.
- **`adjtime`**: 2.11BSD `kern_time.c:113` for the super-user check, and
  Reno `kern_time.c:100` for the slew (`timedelta`, `tickdelta`, `tickadj`,
  `bigadj`).  It is what `ntpd` uses.
- **SYS_RTCWRITE (#32) is retired**: its table entry becomes `_Sys_Stub` and
  its thunk goes, which returns the core bytes #446 spent there.
  **SYS_RTCREAD (#31) stays**, because libc's hand-assembled `today_init`
  (cal) still reads the raw frame.
- `tools/check_bsd_enforcement.py`: kern_time.c:67 and :123 move from n/a to
  carried.

### 3.5 Writing the battery clock: `resettodr`

- FreeBSD's rule: local = `time - (tz.tz_minuteswest * 60 + (wall_cmos_clock ?
  adjkerntz : 0))`, written through WriteTimeHex unless `disable_rtc_set`.
- Called by `settimeofday` and by `reboot`, as FreeBSD's `boot()` does, so a
  clock that NTP has corrected is saved across a restart.

### 3.6 sysctl

FreeBSD's `machdep` leaves, as `int`s through the existing `sysctl_int` path in
`root_sysctl.c`:

- `machdep.adjkerntz`
- `machdep.wall_cmos_clock`
- `machdep.disable_rtc_set`
- `machdep.tick`: FGX-local.  It is the calibration knob of section 3.2.

The first three names and ids are FreeBSD 2.2.8's (CTL_MACHDEP), and writes
are super-user only.

### 3.7 Kernel C

- `kern_time()` reads the kernel's time through a new KSVC, `KSVC_TIME` (54):
  Y=0 gives UTC, Y=1 local time.  It replaces the ROM.  KSVC_RTCFRAME's arm
  is retired, because this was its only caller.
  #182's ROM re-sync goes in both copies.  The never-backward clamp stays: an
  `adjtime` never steps, but a `settimeofday` can.
- **UFS stamps UTC**, as 2.11BSD does.
- **ProDOS stamps local time**, because GS/OS reads its dates as local.
  prodos.mod subtracts the same offset `resettodr` does.  This is the case the
  `adjkerntz(8)` man page names: keeping "proper timestamps for local
  filesystems like MS-DOS".

### 3.8 What changes for a user after this sub-project alone

- With `adjkerntz` at 0, kernel time equals the battery clock's local time, as
  every clock read gives today.  Nothing moves on screen.
- Time becomes UTC when sub-project 3's `adjkerntz -i` sets the offset at boot.
- Until sub-project 2, `localtime` is still `gmtime`.
- Reads get cheaper: `time()` no longer disables interrupts for 3.6 ms.

## 4. Open items inside this sub-project

- **Why a root WriteTimeHex does not take under MAME.**  MAME honours the
  write (see section 2), so this is an FGX defect in `_Sys_RtcWrite` or the
  path to it.  The spike finds it before `resettodr` is built on the same
  path.
- **The real VBL rate on the machine**, which fixes the hardware `tick`.
  MAME's is known.

## 5. Tests

Kept to the blast radius:

- One small C program, run by one manifest:
  - `time` advances by about a second per second;
  - a root `settimeofday` is visible in the next `gettimeofday`;
  - `adjtime` reports and slews.
- `permtest` already holds the non-root refusal.
- The existing boot, fork and shell gate covers everything that stamps a file.
- No deep probes.

## 6. Alternatives rejected

- **Keep #182's derived clock and add an offset.**  Its 60 s re-sync from the
  battery clock would undo every `settimeofday` and every NTP correction, and
  `adjtime` could not slew a 1 s-granular clock.
- **2.11BSD's integer `hz` = 60.**  It is faithful, and 0.1% slow on this
  machine.
- **Move the battery clock to UTC.**  The maintainer ruled it stays on local time, so
  that GS/OS and the Control Panel stay right.

## 7. Provenance

- 2.11BSD `kern_time.c` and `hardclock` are UCB, registered as ports.
- FreeBSD 2.2.8 `clock.c`'s `inittodr`/`resettodr` rules, and later
  `adjkerntz.c`, are third-party BSD-licensed sources.  They get registry rows
  in `docs/PROVENANCE.md` under the third-party section.
