# libc time zones -- design

- **Status:** implemented on feat/libc-time-zones (2026-09-26); designed and
  accepted 2026-09-25 with the maintainer.  Where the build departs from this design --
  adjkerntz exits after the boot adjustment and runs after the remount, date(1)
  follows patch #454 without mktime -- the plan's "As built" section says so.
  Sub-project 2 of 3
  of the time work that NTP and Kerberos 5 need; sub-project 1, the kernel UTC
  clock, is `2026-09-19-kernel-clock-design.md` (merged, !393).
- **Goal:** `localtime(3)` applies real zone rules, so `date`, `ls -l`, `w`
  and syslog print local time with the zone's name, and `mktime(3)` exists for
  `adjkerntz(8)` and Kerberos.  The kernel's battery-clock offset is set from
  the same zone at boot.
- **Sub-project 3 shrinks** to cron and the `adjkerntz -a` crontab entry that
  follows a daylight-saving change; `adjkerntz(8)` itself moves into this one
  (section 5).

## 1. What the code does today

Read 2026-09-25 on `main` at `d5b0cb0d8`.

- **libc has no zones.**  `toolchain/lib/libc_c/ctime.c` is FGX's own:
  `localtime` IS `gmtime` and `tm_isdst` is always 0.  There is no `tzset`,
  `mktime`, `tzname` or `/etc/localtime`.
- **The kernel keeps UTC** (sub-project 1) and converts the battery clock with
  `tz_minuteswest` and `machdep.adjkerntz`, both 0 by default.  So today the
  kernel's "UTC" is the battery clock's local time, and a `localtime` that is
  `gmtime` prints it correctly.  **The moment `localtime` applies a real zone,
  the kernel offset must be set too**, or times read off by the zone's offset.
  That is why `adjkerntz(8)` is in this sub-project.
- **`date(1)`** (`src/userland/date/date.c`, 2.11BSD H1 port) sets the time
  through `settimeofday`, converting its argument with `gtime` as if it were
  UTC.
- **Eight userland programs call a time function** (`date fsck ls stat syslogd
  tar w who`), grep of `src/userland` for `localtime|ctime|asctime|gmtime|
  strftime`.

## 2. Sources

- **Code: 4.3BSD-Reno `lib/libc/gen/ctime.c` 5.23 (6/22/90)**, whole, with
  Reno's `include/tzfile.h`.  One upstream file carries `tzload`, `tzparse`
  (POSIX `TZ` strings), `localtime`, `gmtime`, `mktime`/`time2`, `tzset`,
  `tzname` and the leap-second tables.  Its `tzset` (ctime.c:872-916) reads
  `TZ`, then `/etc/localtime`, then falls back to GMT.
  - **Rejected: 2.11BSD `ctime.c` 1.1 (3/25/87) at patch #454.**  389 lines and
    16-bit-int native, but it has no `mktime`, and no 2.11BSD patch (1-484,
    `examples/2.11BSD-Patches/`) adds one.  Grafting Reno's `time2` into it
    would mix two upstreams in one file.  #454's lookup order -- `TZ`, then
    `/etc/localtime`, then GMT, never the kernel's `struct timezone` -- is
    Reno's already.
- **Data: IANA tzdata 2026d**, vendored as released, to
  `vendor/tzdata-2026d/`.
  - **Rejected: 2.11BSD's own zoneinfo source.**  The distribution's is 1987;
    patch #469 (2020) updated only `northamerica`.
  - **Rejected: the build host's compiled `/usr/share/zoneinfo`.**  No source,
    full history (up to 242 transitions and 18 types a zone), and it changes
    with the host OS.
- **Compiler: IANA tzcode 2026d `zic`**, vendored to `vendor/tzcode-2026d/`,
  built with the host cc.  2.11BSD's and Reno's `zic` cannot parse modern
  tzdata source.  Rejected: the host's `/usr/sbin/zic` (macOS ships 2022g), so
  that the output depends on the tree and not on the build machine.
- **`adjkerntz(8)`: FreeBSD 2.2.8 `sbin/adjkerntz/adjkerntz.c`**, already
  vendored with sub-project 1, with its man page vendored alongside.

## 3. The zone files

- **Compiled on the host at build time:**
  `zic -b fat -r @0/@2147483647 -d <stage>/usr/share/zoneinfo <tzdata files>`.
  - `-b fat` keeps the version-1 data block populated.  A TZif file's first 44
    bytes are laid out so that the old reader's header (`tzh_reserved[32]`,
    then `timecnt`, `typecnt`, `charcnt`) lands on the right fields, so Reno's
    `tzload` reads the v1 block unchanged and ignores the v2 data after it.
  - `-r @0/@2147483647` keeps 1970 to 2038, the range a signed 32-bit
    `time_t` holds.
- **Measured** (tzdata 2026d, compiled that way): 597 zone files, 544,710
  bytes; at most 139 transitions (America/Yakutat), 12 local-time types and 30
  abbreviation characters in one zone.
- **All zones are installed**, as 2.11BSD installs them, under
  `/usr/share/zoneinfo`.
- **`/etc/localtime` is a regular-file copy** of one zone, as 2.11BSD patch
  #469 advises so that it works before `/usr` is available.  The image ships
  UTC.  A build variable `FGX_TZ=<zone>` stages another zone; on the machine,
  `cp /usr/share/zoneinfo/<zone> /etc/localtime` changes it.
- **A host-side check** fails the build if any compiled zone exceeds
  `TZ_MAX_TIMES`, `TZ_MAX_TYPES` or `TZ_MAX_CHARS`, so a future tzdata update
  cannot overflow the reader silently.

## 4. libc

- **Reno's `ctime.c` replaces FGX's member**, whole, with these FGX deltas,
  each recorded in its PROVENANCE row:
  - **No large stack locals.**  FGX user stacks are budgeted in the hundreds
    of bytes (`docs/userland-abi.md` section 1.3, apple/fgx#367).  `tzload`'s
    `char buf[sizeof *sp]` and its `fullname[MAXPATHLEN]` become static.
  - **Limits sized to the data** (section 3): `TZ_MAX_TIMES` 150 (Reno 370),
    `TZ_MAX_TYPES` 12 (Reno 10), `TZ_MAX_CHARS` 50 (Reno's).  The `struct
    state` is then about 1 KB per program that calls a time function, against
    about 2 KB at Reno's limits.
  - **A 16-bit `int` audit.**  Reno assumes a 32-bit `int` in places; fcc's is
    16 bits.  First finding: `getsecs` (ctime.c:453) computes
    `*secsp = num * SECSPERHOUR` in `int`, and `SECSPERHOUR` is not cast to
    long where `SECSPERDAY` is (tzfile.h:98-99), so a POSIX `TZ` offset of 10
    hours or more overflows.  Every such site is fixed with a `(long)` cast.
  - **`time.h`** follows Reno's (`include/time.h`): `struct tm` gains
    `tm_gmtoff` and `tm_zone` at its end, and `mktime`, `tzset` and `tzname`
    are declared.  `timezone`/`daylight` are not: Reno defines them only
    under `USG_COMPAT` (ctime.c:196-199).  The "localtime == gmtime" comments
    go.  Every program is rebuilt with the new `struct tm`, and `strftime`'s
    zone name comes from `tm_zone`.
- **Size is measured, not assumed.**  libc selection is per file
  (apple/fgx#457), so a program that calls `ctime` links the whole file.  The
  plan measures every program in section 1's list, before and after.  If a
  segment overflows, the first answer is splitting the file into members the
  way apple/fgx#456 did for `su`; if that is not enough, how libc is linked is
  reassessed then (the maintainer, 2026-09-25), not pre-emptively.

## 5. adjkerntz(8) and the boot

- **`adjkerntz -i &` runs early in `/etc/rc`**, before the root is remounted
  read-write and before the first daemon, so few files are stamped with the
  unadjusted time.
  - It reads the zone through `localtime` and `mktime`, sets
    `machdep.adjkerntz` to the zone's current offset, and steps the kernel
    clock to true UTC with `settimeofday`, holding `machdep.disable_rtc_set`
    so the battery clock is not rewritten.  All three leaves exist since
    sub-project 1.
  - It then waits in `sigsuspend`; at SIGTERM (shutdown) it repeats the
    adjustment, as `-a` does.
  - It is backgrounded with `&` because FGX's `daemon(3)` cannot fork
    (apple/fgx#494), as `update`, `inetd` and `syslogd` are.
- **`machdep.adjkerntz` becomes a `long`**, found while planning:
  `src/kernel/tty/kern_time.c` declares it `int`, 16 bits under fcc, so
  it cannot hold a zone more than 9 h 06 m from UTC (Honolulu, Sydney,
  Auckland).  FreeBSD 2.2.8's is an `int` on a 32-bit `int` (`clock.c:100`,
  `machdep.c:710-721`).  The leaf exchanges 4 bytes, and the `adjkerntz`
  port's `kern_offset` is a `long` to match.  Fixed first, in its own commit.
- **`/etc/wall_cmos_clock` ships**: the IIgs battery clock keeps local time.
  Without it `adjkerntz` exits at once, as FreeBSD's does for a UTC clock.
- **With the default UTC `/etc/localtime`**, the offset is 0 and nothing
  moves: exactly today's behaviour.
- **Between daylight-saving changes and the next boot**, without cron, the
  kernel's offset keeps its boot value: the battery clock is written back an
  hour off, and the next boot's `inittodr` is off until `adjkerntz -i` runs.
  That is FreeBSD without cron; sub-project 3's crontab entry closes it.
  `localtime`'s display is right throughout, since it applies the rules itself.

## 6. date(1)

- **Display:** unchanged apart from the zone name, which now comes from
  `tm_zone` rather than a fixed string.
- **Setting:** `date yymmddhhmm` is local time, converted with `mktime` and set
  with `settimeofday`; the kernel writes the battery clock back in local time
  with the offset of section 5.  Checked against 2.11BSD's `date.c` at patch
  #454, which also removes `-d`/`-t` (FGX's port never had them).

## 7. Testing

One new MAME test, `tztest`, and extensions to existing ones.  Every assertion
is mutation-checked to go red.

- **Zones:** `TZ=America/New_York` gives EST in January and EDT in July, with
  the right offsets and abbreviations.  A POSIX string (`TZ=EST5EDT`) parses,
  and an offset of 10 hours or more comes out right (red on the 16-bit
  overflow).  A missing zone file falls back to GMT.
- **`mktime`:** round-trips `localtime`, including a time that does not exist
  on the spring-forward day.
- **adjkerntz:** with a non-UTC `/etc/localtime` staged, the boot's
  `adjkerntz -i` sets `machdep.adjkerntz`, and `gettimeofday` agrees with the
  battery clock plus that offset.  `timetest` stays green under the default
  UTC zone.
- **date(1):** setting 12:00 in a UTC-5 zone stores 17:00 UTC.
- **Host:** the zone-limits check of section 3, with a positive control (a
  zone compiled without `-r` must fail it).

## 8. Order of work

Each step is gated.

1. Vendor tzcode and tzdata 2026d; build `zic` on the host.
2. Compile the zone files, stage them and `/etc/localtime`; the limits check.
3. Reno's `ctime.c` into libc; the size measurement.
4. `date(1)`.
5. `adjkerntz(8)`, `/etc/rc`, `/etc/wall_cmos_clock`.
6. Man pages, PROVENANCE, ROADMAP.

## 9. Not in this sub-project

- `zic` and `zdump` on the IIgs itself.
- Leap-second zones (`right/`).
- cron and the daylight-saving crontab entry (sub-project 3).
- A forking `daemon(3)` (apple/fgx#494).
