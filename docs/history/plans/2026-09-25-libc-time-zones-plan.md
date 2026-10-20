# libc time zones -- implementation plan

> For agentic workers: execute task by task, in order; each task ends green,
> gated and committed.  Checkboxes track progress.  REQUIRED SUB-SKILL:
> superpowers:executing-plans (or subagent-driven-development for the C and
> host-tool tasks).

**Goal:** `localtime(3)` applies IANA zone rules, `mktime(3)` exists, the zone
files ship on the root, `date(1)` sets local time, and `adjkerntz(8)` sets the
kernel's battery-clock offset from the zone at boot.

**Architecture:**
- The build host compiles IANA tzdata 2026d with the vendored tzcode 2026d
  `zic` into `disk_src/usr/share/zoneinfo`, 1970-2038 only, "fat" so the
  version-1 block is populated.
- libc's `ctime.c` member becomes 4.3BSD-Reno's `ctime.c` 5.23, whose
  `tzload` reads that v1 block unchanged.
- FreeBSD 2.2.8's `adjkerntz -i` runs from `/etc/rc`.

**Tech stack:** host cc and Python (tools/ninja), fcc K&R C (libc pile,
userland), the MAME harness (`tools/mame_test`).

**Spec:** `docs/history/plans/2026-09-25-libc-time-zones-design.md`.

## As built (2026-09-26)

Every task landed; where the build departs from the steps below:

- **Library GC came first.**  Reno's ctime.c overflowed seg2 in six tools; the
  function-level GC (!394) was done before Task 3, after which it fits (su's
  seg2: 23,617 B free before, 7,132 after).
- **C2's oracle is -1.**  Reno's mktime, built on the host with 32-bit long
  and time_t (and -fwrapv), returns -1 for 02:30 on 2026-03-08 in New York;
  tztest checks 01:30, 02:30 and 03:30 against it.
- **date(1) does not call mktime.**  Patch #454's date.c subtracts the
  tm_gmtoff localtime reports for the entered value, and -u is
  `setenv("TZ", "GMT", 1)`; setenv(3) came into libc from 2.11BSD for it.
- **fcc and its harness were fixed on the way:** brace elision and
  multi-dimensional static locals (Reno's tables); a --sigs entry that
  conflicts with the TU's own definition is dropped (su's own setenv); the
  runtime oracle compiles a fixture with its .sigs.
- **Task 5 Step 0** widened the sysctl argument block to eight words; the
  machdep ids moved to <machine/cpu.h> (they are FreeBSD's, not 2.11BSD's),
  and <paths.h> came from 2.11BSD for adjkerntz's pathnames.h.
- **adjkerntz runs after the remount**, where FreeBSD 2.2.8's etc/rc runs it
  (line 96), not before it, and without an rc echo.
- **adjkerntz -i exits after the boot adjustment** (the maintainer, 2026-09-26): a
  resident one held a process slot and three banks for a twice-yearly DST
  change.  A DST change the machine is up across waits for cron's
  `adjkerntz -a` (sub-project 3).
- **difftime(3)** came into libc from Reno, its page documenting it.
- **The man pages** are ctime(3) and its seven names, tzfile(5), getenv(3) with
  setenv and unsetenv, adjkerntz(8), and updates to date(1) and sysctl(3),
  whose text predated the machdep leaves.

## Global constraints

- ASCII only in every FGX file (vendored files stay byte-identical to upstream).
- Every port gets a `docs/PROVENANCE.md` row naming its upstream file in
  `vendor/`; `tools/check_provenance.py` must stay clean.
- Read the upstream before changing behaviour; name file and line in commits.
- Source comments describe the current state only.
- fcc `int` is 16 bits; `long` is 32.  `time_t` is `long`.
- User stacks are ~256 bytes (`docs/userland-abi.md` 1.3): no local over ~64 B
  in libc.
- Address-of a local is a bank-0 pointer; buffers passed to syscalls live in
  static storage.
- Commit bodies are changelog: informational, no names, no process lines.
- MAME runs headless via `tools/mame_test/run.py` only.
- Rebuild with `sh <scratch>` (or `python3
  tools/ninja/gen.py && ninja`); gate with `tools/gate.sh`.  Announce every
  rebuild and checkout.
- Branch: `feat/libc-time-zones` (from main `d5b0cb0d8`).  Never push without
  asking; never merge.

## Facts measured while planning (2026-09-25)

- tzcode 2026d's `zic.c` builds with the host cc given two generated headers:
  `version.h` (`PKGVERSION`, `TZVERSION`, `REPORT_BUGS_TO`) and `tzdir.h`
  (`TZDEFAULT`, `TZDIR`).  Its output differs from macOS's zic 2022g in one
  zone (Asia/Tbilisi) -- the reason the host's zic is not used.
- `zic -b fat -r @0/@2147483647` over `africa antarctica asia australasia
  europe northamerica southamerica etcetera backward`: 597 files, 544,710 B;
  maxima 139 transitions (America/Yakutat), 12 types, 30 chars.
- Reno `include/tzfile.h`'s `struct tzhead` is `tzh_reserved[24]`,
  `tzh_ttisstdcnt`, `tzh_leapcnt`, `tzh_timecnt`, `tzh_typecnt`,
  `tzh_charcnt` -- the same 44-byte offsets as a modern TZif v1 header (the
  modern `isutcnt` falls inside `reserved`).
- Reno `ctime.c`: `#define const` under `!__STDC__` (line 55), static
  `struct state` unless `ALL_STATE`; `tzset` (872-900) is `TZ`, else
  `tzsetwall` (`/etc/localtime`), else `gmtload`.  `getsecs` line 453:
  `*secsp = num * SECSPERHOUR;` -- `int * int`.
- libc members are the `#include`s in `toolchain/lib/libc_c/libc_c.c` (order
  load-bearing); `ctime.c` is included at line 195, `strftime.c` at 196.
- Callers of a time function: `date fsck ls stat syslogd tar w who`.
  Baseline `tools/bank_pressure.py`: date 54,852 B used / 3 banks; fsck
  147,754 / 4; ls 86,218 / 3; stat 50,647 / 3; syslogd 124,120 / 4; tar
  78,495 / 3; w 57,516 / 3; who 56,738 / 3.
- Test epochs: 2026-01-15 12:00:00 UTC = 1768478400 (07:00 EST);
  2026-07-15 12:00:00 UTC = 1784116800 (08:00 EDT).  12:00 EST on
  2026-01-15 = 1768496400.

---

### Task 1: vendor tzcode and tzdata; build zic on the host

**Files:**
- Create: `vendor/tzcode-2026d/` (the release tarball's contents, verbatim)
- Create: `vendor/tzdata-2026d/` (the release tarball's contents, verbatim)
- Create: `tools/ninja/tz.sh`
- Modify: `tools/ninja/gen.py` (a `hostzic` rule and edge next to host yacc)
- Modify: `.gitignore` (`build/tz_host/`)
- Modify: `docs/PROVENANCE.md` (two third-party rows)

**Interfaces:**
- Produces: `build/tz_host/zic`, a host binary; `tools/ninja/tz.sh host`.

- [x] **Step 1: Fetch and vendor.**

```bash
cd ~/projects/Retro/Apple/fgx
S=$(mktemp -d)
curl -sSfL -o $S/code.tgz https://data.iana.org/time-zones/releases/tzcode2026d.tar.gz
curl -sSfL -o $S/data.tgz https://data.iana.org/time-zones/releases/tzdata2026d.tar.gz
mkdir -p vendor/tzcode-2026d vendor/tzdata-2026d
tar xzf $S/code.tgz -C vendor/tzcode-2026d
tar xzf $S/data.tgz -C vendor/tzdata-2026d
cat vendor/tzdata-2026d/version     # expect: 2026d
shasum -a 256 $S/*.tgz               # record both in the commit body
```

- [x] **Step 2: Write `tools/ninja/tz.sh`** (the host half, `host` verb only
  for now; Task 2 adds `zones`):

```bash
#!/usr/bin/env bash
#==============================================================================
# tz.sh -- the HOST-side steps of the time zone files.
#
#   tz.sh host                   build build/tz_host/zic from vendor/tzcode-2026d
#
# zic.c needs two headers its Makefile generates; they are written here with
# the values that Makefile would use for an FGX root.
#==============================================================================
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
CODE=vendor/tzcode-2026d
OUT=build/tz_host

case "${1:-}" in
host)
    mkdir -p "$OUT"
    printf '#define PKGVERSION "(tzcode) "\n#define TZVERSION "%s"\n#define REPORT_BUGS_TO "tz@iana.org"\n' \
        "$(cat $CODE/version)" > "$OUT/version.h"
    printf '#define TZDEFAULT "/etc/localtime"\n#define TZDIR "/usr/share/zoneinfo"\n' \
        > "$OUT/tzdir.h"
    ${CC:-cc} -O2 -I"$OUT" -I"$CODE" -o "$OUT/zic" "$CODE/zic.c"
    ;;
*)
    echo "usage: tz.sh host" >&2; exit 2 ;;
esac
```

- [x] **Step 3: Run it and check the version.**

Run: `bash tools/ninja/tz.sh host && build/tz_host/zic --version`
Expected: `zic (tzcode) 2026d`.  If `-I"$OUT"` loses to the vendored
directory's own `version.h`/`tzdir.h` (it has none in a release tarball;
check with `ls vendor/tzcode-2026d/*.h`), keep `-I"$OUT"` first.

- [x] **Step 4: Add the ninja rule and edge** in `gen.py`, beside the host-yacc
  block (around line 1984), unconditionally:

```python
    # ---- host zic ----------------------------------------------------------
    lines.append("\n# ---- host zic " + "-" * 55)
    lines.append("build build/tz_host/zic: hostzic | vendor/tzcode-2026d/zic.c "
                 "vendor/tzcode-2026d/version tools/ninja/tz.sh")
```

and the rule next to `rule hostyacc`:

```
rule hostzic
  command = bash tools/ninja/tz.sh host
  description = host zic
```

- [x] **Step 5: Build through ninja.**  `python3 tools/ninja/gen.py && ninja
  build/tz_host/zic` -- expect one `host zic` line, then `ninja -n
  build/tz_host/zic` says no work.

- [x] **Step 6: PROVENANCE rows** (third-party section, beside the FreeBSD
  2.2.8 rows): `vendor/tzcode-2026d/` and `vendor/tzdata-2026d/`, IANA tz
  release 2026d, public domain (their `LICENSE` file says so -- quote its
  first line), "vendored verbatim; zic is built for the host only".
  Run: `python3 tools/check_provenance.py` -- expect clean.

- [x] **Step 7: Commit** (no gate: nothing on the image changes yet).

```bash
git add vendor/tzcode-2026d vendor/tzdata-2026d tools/ninja/tz.sh tools/ninja/gen.py .gitignore docs/PROVENANCE.md
git commit   # "build: vendor IANA tz 2026d and build zic for the host"
```

---

### Task 2: compile and stage the zone files; `/etc/localtime`; the limits check

**Files:**
- Modify: `tools/ninja/tz.sh` (`zones` verb)
- Create: `tools/check_tzlimits.py`
- Modify: `tools/ninja/gen.py` (zones edge, `FGX_TZ`, tree walk exclusion,
  `disk/fgxufs.po` input)
- Modify: `.gitignore` (`disk_src/usr/share/zoneinfo/`, `disk_src/etc/localtime`)
- Modify: `tools/gate.sh` (run `check_tzlimits.py --self-test` with the other
  checker self-tests)

**Interfaces:**
- Consumes: `build/tz_host/zic` (Task 1).
- Produces: `build/.zoneinfo_staged` stamp; `disk_src/usr/share/zoneinfo/**`;
  `disk_src/etc/localtime`; `TZ_MAX_TIMES 150`, `TZ_MAX_TYPES 12`,
  `TZ_MAX_CHARS 50` as the limits Task 3's `tzfile.h` must carry (the checker
  reads them FROM `toolchain/include/tzfile.h` once Task 3 creates it; until
  then from constants in the checker, which Task 3 deletes).

- [x] **Step 1: Write the checker test first.**  `tools/check_tzlimits.py`:

```python
#!/usr/bin/env python3
"""check_tzlimits -- every staged zone file fits libc's tzfile.h limits.

libc's tzload (toolchain/lib/libc_c/ctime.c, 4.3BSD-Reno) refuses a file
whose version-1 block has more transitions, types or abbreviation characters
than TZ_MAX_TIMES, TZ_MAX_TYPES or TZ_MAX_CHARS, and falls back to GMT --
silently, on the machine.  This makes that a build failure instead.

    check_tzlimits.py <zoneinfo dir>     check every file under it
    check_tzlimits.py --self-test        a zone compiled WITHOUT -r must fail
"""
import os, re, struct, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def limits():
    h = os.path.join(ROOT, "toolchain/include/tzfile.h")
    out = {"TZ_MAX_TIMES": 150, "TZ_MAX_TYPES": 12, "TZ_MAX_CHARS": 50}
    if os.path.exists(h):
        for k in out:
            m = re.search(r"#define\s+%s\s+(\d+)" % k, open(h).read())
            if m:
                out[k] = int(m.group(1))
    return out

def check(zdir):
    lim, bad, n = limits(), [], 0
    for dp, _, fs in os.walk(zdir):
        for f in fs:
            p = os.path.join(dp, f)
            d = open(p, "rb").read()
            if d[:4] != b"TZif":
                continue
            n += 1
            _, _, leap, times, types, chars = struct.unpack(">6l", d[20:44])
            if times > lim["TZ_MAX_TIMES"] or types > lim["TZ_MAX_TYPES"] \
                    or chars > lim["TZ_MAX_CHARS"] or leap != 0:
                bad.append("%s: times=%d types=%d chars=%d leaps=%d"
                           % (os.path.relpath(p, zdir), times, types, chars, leap))
    return n, bad

def main():
    if sys.argv[1:] == ["--self-test"]:
        zic = os.path.join(ROOT, "build/tz_host/zic")
        src = os.path.join(ROOT, "vendor/tzdata-2026d/northamerica")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([zic, "-b", "fat", "-d", t, src], check=True)
            n, bad = check(t)
        if not bad:
            print("check_tzlimits: SELF-TEST FAILED: full-history zones passed")
            return 1
        print("check_tzlimits: self-test ok (%d of %d full-history zones refused)"
              % (len(bad), n))
        return 0
    n, bad = check(sys.argv[1])
    if n == 0:
        print("check_tzlimits: no zone files under %s" % sys.argv[1]); return 1
    if bad:
        print("check_tzlimits: %d zone(s) exceed tzfile.h:" % len(bad))
        for b in bad[:20]:
            print("  " + b)
        return 1
    print("check_tzlimits: clean (%d zones within %s)" % (n, limits()))
    return 0

sys.exit(main())
```

- [x] **Step 2: Run the self-test.**  `python3 tools/check_tzlimits.py
  --self-test` -- expect `self-test ok (N of M ...)` with N > 0 (America/*
  has > 150 transitions over its full history).  Then
  `python3 tools/check_tzlimits.py /nonexistent` -- expect exit 1 ("no zone
  files").

- [x] **Step 3: Add the `zones` verb** to `tz.sh`:

```bash
zones)
    # tz.sh zones <zone for /etc/localtime>
    Z="${2:-UTC}"
    DST=disk_src/usr/share/zoneinfo
    rm -rf "$DST"           # the wipe is the prune: a zone tzdata drops goes
    mkdir -p "$DST"
    D=vendor/tzdata-2026d
    "$OUT/zic" -b fat -r @0/@2147483647 -d "$DST" \
        $D/africa $D/antarctica $D/asia $D/australasia $D/europe \
        $D/northamerica $D/southamerica $D/etcetera $D/backward
    [ -f "$DST/$Z" ] || { echo "tz.sh: FGX_TZ=$Z is not a zone" >&2; exit 2; }
    cp "$DST/$Z" disk_src/etc/localtime     # a copy, not a link (2.11BSD #469)
    python3 tools/check_tzlimits.py "$DST"
    touch build/.zoneinfo_staged
    ;;
```

(update the usage line and header comment to list both verbs).

- [x] **Step 4: Wire it into `gen.py`.**
  - Read the zone once, near the other environment knobs:
    `FGX_TZ = os.environ.get("FGX_TZ", "UTC")` -- changing it needs
    `gen.py` re-run, which `kbuild.sh` does; say so in the comment.
  - Rule: `rule tzzones` / `command = bash tools/ninja/tz.sh zones $zone` /
    `description = zoneinfo ($zone)`.
  - Edge: `build build/.zoneinfo_staged disk_src/etc/localtime: tzzones |
    build/tz_host/zic tools/ninja/tz.sh tools/check_tzlimits.py
    vendor/tzdata-2026d/version toolchain/include/tzfile.h` with
    `zone = <FGX_TZ>` -- but `toolchain/include/tzfile.h` only once Task 3
    creates it (add it there).
  - The `tree_inputs` walk (around line 2311): add `"zoneinfo"` to the
    excluded directory names, and skip `disk_src/etc/localtime` (a build
    product), so generated files are never hard inputs.
  - `disk/fgxufs.po`'s input list: add `build/.zoneinfo_staged
    disk_src/etc/localtime`.

- [x] **Step 5: Build the image and look at it.**

Run: `sh <scratch>` (announce: rebuilding the tree on
feat/libc-time-zones).  Expect the `zoneinfo (UTC)` step and
`check_tzlimits: clean (597 zones ...)`.  Then:
`python3 tools/fgxfs.py ls disk/fgxufs.po /usr/share/zoneinfo/America | head`
(or the listing verb `tools/fgxfs.py --help` names) -- expect `New_York`.
If the image build reports the volume full, stop and report the free-space
numbers: that is a design question, not a workaround.

- [x] **Step 6: Negative check.**  `FGX_TZ=Nowhere/Such python3
  tools/ninja/gen.py && ninja build/.zoneinfo_staged` -- expect
  `FGX_TZ=Nowhere/Such is not a zone` and a failed edge.  Restore with
  `python3 tools/ninja/gen.py`.

- [x] **Step 7: Gate and commit.**  Add `python3 tools/check_tzlimits.py
  --self-test` to `tools/gate.sh`'s checker self-tests.  Run the gate
  (the image changed: the boot tests must stay green).

```bash
git add tools/ninja/tz.sh tools/ninja/gen.py tools/check_tzlimits.py tools/gate.sh .gitignore
git commit   # "build: the zone files ship in /usr/share/zoneinfo, /etc/localtime UTC"
```

---

### Task 3: 4.3BSD-Reno `ctime.c` into libc

**Files:**
- Create: `vendor/4.3BSD-Reno/lib/libc/gen/ctime.c`,
  `vendor/4.3BSD-Reno/include/tzfile.h`, `vendor/4.3BSD-Reno/include/time.h`
  (copied from `examples/4.3BSD-Reno/`, verbatim)
- Replace: `toolchain/lib/libc_c/ctime.c`
- Create: `toolchain/include/tzfile.h`
- Modify: `toolchain/include/time.h`, `toolchain/lib/libc_c/strftime.c` (`%Z`)
- Create: `src/userland/tztest/tztest.c`,
  `tools/mame_test/tests/tztest.json`
- Modify: `tools/ninja/manifest.json` (tool `tztest`, staging
  `bin/tztest.bin` -> `disk_src/testbin/tztest`), `tools/ninja/gen.py` (zones
  edge input `toolchain/include/tzfile.h`), `tools/check_tzlimits.py` (drop
  the fallback constants)
- Modify: `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: the staged zone files (Task 2).
- Produces (libc): `void tzset()`, `void tzsetwall()`, `struct tm
  *localtime(long *)`, `struct tm *gmtime(long *)`, `long mktime(struct tm
  *)`, `char *ctime(long *)`, `char *asctime(struct tm *)`, `char
  *tzname[2]`; `struct tm` gains `long tm_gmtoff; char *tm_zone;` at the end.

- [x] **Step 1: Write `tztest.c` first** (it must fail on today's libc).

```c
/* tztest -- libc time zones (toolchain/lib/libc_c/ctime.c, 4.3BSD-Reno 5.23).
 *
 *   TZ A1 ...ok   TZ=America/New_York, 2026-01-15 12:00 UTC is 07:00 EST,
 *                 gmtoff -18000, isdst 0
 *   TZ A2 ...ok   ...and 2026-07-15 12:00 UTC is 08:00 EDT, -14400, isdst 1
 *   TZ B1 ...ok   a POSIX string with a ten-hour offset, TEN-10: 22:00,
 *                 gmtoff 36000 (red while getsecs multiplies in int)
 *   TZ B2 ...ok   TZ=No/Such_Zone falls back to GMT: 12:00, "GMT"
 *   TZ C1 ...ok   mktime inverts localtime at both A instants
 *   TZ C2 ...ok   mktime of 2026-03-08 02:30 New York (a time the spring-
 *                 forward day skips) matches the host oracle's answer
 *   TZ D1 ...ok   (as root) date 2601151200 under America/New_York sets
 *                 1768496400 (12:00 EST = 17:00 UTC), within 3 s; the clock
 *                 is put back after
 *   TZ VERDICT PASS
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

extern char **environ;
static char *env_ny[] = { "TZ=America/New_York", 0 };
static char *env_ten[] = { "TZ=TEN-10", 0 };
static char *env_none[] = { "TZ=No/Such_Zone", 0 };
static int fail;

static void
zone(e)
    char **e;
{
    environ = e;
    tzset();
}

/* One line per case: what localtime made of t, and whether it is what the
 * case expects. */
static void
at(id, t, hh, mm, off, dst, abbr)
    char *id, *abbr;
    long t, off;
    int hh, mm, dst;
{
    struct tm *tm;
    int ok;

    tm = localtime(&t);
    ok = tm->tm_hour == hh && tm->tm_min == mm && tm->tm_gmtoff == off &&
         tm->tm_isdst == dst && strcmp(tm->tm_zone, abbr) == 0;
    printf("TZ %s %02d:%02d %ld %d %s %s\n", id, tm->tm_hour, tm->tm_min,
           tm->tm_gmtoff, tm->tm_isdst, tm->tm_zone, ok ? "ok" : "FAIL");
    if (!ok)
        fail = 1;
}

static void
inverse(id, t)
    char *id;
    long t;
{
    struct tm tm;
    long r;

    tm = *localtime(&t);
    r = mktime(&tm);
    printf("TZ %s %ld %s\n", id, r - t, r == t ? "ok" : "FAIL");
    if (r != t)
        fail = 1;
}

main()
{
    zone(env_ny);
    at("A1", 1768478400L, 7, 0, -18000L, 0, "EST");
    at("A2", 1784116800L, 8, 0, -14400L, 1, "EDT");
    zone(env_ten);
    at("B1", 1768478400L, 22, 0, 36000L, 0, "TEN");
    zone(env_none);
    at("B2", 1768478400L, 12, 0, 0L, 0, "GMT");
    zone(env_ny);
    inverse("C1", 1768478400L);
    inverse("C1", 1784116800L);
    /* C2: Step 2 below.  D1: Task 4. */
    printf("TZ VERDICT %s\n", fail ? "FAIL" : "PASS");
    exit(fail);
}
```

`tools/mame_test/tests/tztest.json` (description: one paragraph naming each
case as the header comment does):

```json
{
 "name": "tztest",
 "description": "libc time zones (4.3BSD-Reno ctime.c): A1/A2 America/New_York EST and EDT from the zone files; B1 a POSIX TZ string with a ten-hour offset (the 16-bit int overflow in getsecs); B2 an unknown TZ falls back to GMT; C1 mktime inverts localtime; C2 mktime of the skipped spring-forward hour matches the host oracle; D1 date(1) sets local time.",
 "command": "/testbin/tztest",
 "timeout_s": 60,
 "expect": {
  "screen_contains": ["TZ A1 07:00 -18000 0 EST ok", "TZ A2 08:00 -14400 1 EDT ok",
                      "TZ B1 22:00 36000 0 TEN ok", "TZ B2 12:00 0 0 GMT ok",
                      "TZ C1 0 ok", "TZ VERDICT PASS"],
  "screen_lacks": ["TZ VERDICT FAIL", "FAIL", "PANIC", "BRK"]
 }
}
```

Register `{"name": "tztest"}` in `manifest.json`'s tools and the staging row.

- [x] **Step 2: Establish C2's expected value with a host oracle.**  Compile
  the vendored Reno `ctime.c` on the host against the Task 2 zone files
  (`-DTZDIR=\"$PWD/disk_src/usr/share/zoneinfo\"`, `-Dtime_t=int` so its
  `time_t` is 32-bit like FGX's `long`, `-I vendor/4.3BSD-Reno/include` ahead
  of system headers only for `tzfile.h`), with a 10-line `main` that sets
  `TZ=America/New_York`, fills a `struct tm` for 2026-03-08 02:30:00
  `tm_isdst = -1`, and prints `mktime`'s return and the normalised fields.
  Record the printed value in the plan's C2 line and in `tztest.c` as:

```c
    {
        struct tm tm;
        long r;

        zone(env_ny);
        tm.tm_year = 126; tm.tm_mon = 2; tm.tm_mday = 8;
        tm.tm_hour = 2; tm.tm_min = 30; tm.tm_sec = 0; tm.tm_isdst = -1;
        r = mktime(&tm);
        printf("TZ C2 %ld %s\n", r, r == ORACLE_C2 ? "ok" : "FAIL");
        if (r != ORACLE_C2)
            fail = 1;
    }
```

  with `#define ORACLE_C2 <value>L` above `main`, and add `"TZ C2 <value> ok"`
  to the JSON.  If the oracle does not build on the host in 30 minutes, drop
  C2 to a property check (`r == -1 || localtime(&r)->tm_hour == 3`) and say
  so in the commit.

- [x] **Step 3: Build and watch it fail.**  Rebuild (announce).  Today's
  `time.h` has no `tm_gmtoff`/`tm_zone`/`tzset`/`mktime`, so the expected
  failure is at COMPILE time: `ninja bin/tztest.bin` fails naming
  `tm_gmtoff`.  That is the red.

- [x] **Step 4: Vendor Reno's three files** from `examples/4.3BSD-Reno/`
  (`lib/libc/gen/ctime.c`, `include/tzfile.h`, `include/time.h`) into
  `vendor/4.3BSD-Reno/` at the same paths, byte-identical (`cmp` each).

- [x] **Step 5: Port.**  `toolchain/lib/libc_c/ctime.c` becomes Reno's file
  with, and only with, these deltas (each commented at its site, current
  state only):
  - The FGX header block: SPDX/UCB notice as other members carry it,
    `FGX-Provenance: 4.3BSD-Reno lib/libc/gen/ctime.c 5.23 (6/22/90)`.
  - Includes: `<tzfile.h>`, `<time.h>`, `<string.h>`, `<fcntl.h>` as FGX
    names them; drop `<stdio.h>` if nothing needs it.  The member is a pile
    member: no file-scope `#define` that another member needs -- anything
    shared goes in `libc_c.c`'s prologue (see its header).
  - `tzload`: `char fullname[MAXPATHLEN]` and `char buf[sizeof *sp]` become
    file-scope statics (`static char __lc_tzpath[MAXPATHLEN];`,
    `static char __lc_tzbuf[sizeof (struct state)];`).
  - The 16-bit audit.  Read every multiplication, shift and constant in the
    file with `int` = 16 bits; fix each overflow with a `(long)` cast at the
    first operand.  Known: line 453 `*secsp = num * SECSPERHOUR;` ->
    `*secsp = (long) num * SECSPERHOUR;`.  Also read: `getsecs` 459,
    `getrule` 550, `transtime` 583-636, `tzparse` 703-754, `timesub`
    1069-1092, `time2` 1225-1260 (`bits` search over a 32-bit `time_t`), and
    any `int` holding seconds.  List every site found in the commit body.
  - Keep everything else, including leap-second support (`leapcnt` is 0 for
    these files) and `tzsetwall`.
  `toolchain/include/tzfile.h` is Reno's with `TZ_MAX_TIMES 150`,
  `TZ_MAX_TYPES 12`, `TZ_MAX_CHARS 50`, a comment saying why (the 1970-2038
  data of Task 2, `tools/check_tzlimits.py` enforces it), `TZDIR
  "/usr/share/zoneinfo"`, `TZDEFAULT "/etc/localtime"`.
  `toolchain/include/time.h`: `struct tm` as Reno's (append `tm_gmtoff`,
  `tm_zone`); declare `tzset`, `tzsetwall`, `mktime`, `tzname`; delete the
  "localtime == gmtime" comments; keep FGX's existing declarations
  (`strftime`'s note, etc.).  `strftime.c`: `%Z` prints `t->tm_zone` (read
  Reno's `lib/libc/ansi/strftime.c` in `examples/` first and match it).

- [x] **Step 6: Build libc and the eight callers; measure.**  Rebuild
  (announce).  Then `python3 tools/bank_pressure.py | grep -E
  '^(date|fsck|ls|stat|syslogd|tar|w|who) '` and `python3
  tools/check_data_budget.py` -- record before (the baseline above) and
  after in the commit body.  If a link fails for space, split `ctime.c` per
  `project_fgx_libc_member_split` (move `mktime`/`time1`/`time2`/`tmcomp`/
  `normalize` into `mktime.c`, and `tzparse`/`getzname`/`getnum`/`getsecs`/
  `getoffset`/`getrule`/`transtime` into `tzparse.c`, each `#include`d right
  after `ctime.c` in `libc_c.c`) and measure again.  If that is not enough,
  stop and report (the maintainer: reassess libc linking then).

- [x] **Step 7: Run tztest and timetest.**

Run: `python3 tools/mame_test/run.py --fresh tztest timetest`
Expected: `2 passed, 0 failed`; tztest's lines as the JSON lists; no
"(1 cached)".

- [x] **Step 8: Mutations.**  Each must turn tztest red, then be reverted:
  (a) remove the `(long)` at line 453's port -> B1 FAIL; (b) in `tz.sh` drop
  `-b fat` (slim files, empty v1 block) -> A1/A2 FAIL; (c) set
  `TZ_MAX_TIMES 100` -> check_tzlimits fails the build (the Task 2 check,
  not tztest).  Record each result.

- [x] **Step 9: PROVENANCE row** for `toolchain/lib/libc_c/ctime.c`
  (replacing FGX's own row if one exists) and `toolchain/include/tzfile.h`,
  naming `vendor/4.3BSD-Reno/lib/libc/gen/ctime.c` and every delta.
  `python3 tools/check_provenance.py` clean.

- [x] **Step 10: Gate and commit.**

```bash
git add vendor/4.3BSD-Reno toolchain/lib/libc_c toolchain/include src/userland/tztest tools docs/PROVENANCE.md
git commit   # "feat(libc): time zones -- 4.3BSD-Reno's ctime.c, with mktime"
```

---

### Task 4: `date(1)` sets local time

**Files:**
- Modify: `src/userland/date/date.c`
- Modify: `src/userland/tztest/tztest.c`, `tools/mame_test/tests/tztest.json`
  (case D1)

**Interfaces:**
- Consumes: `mktime`, `localtime`, `tm_zone` (Task 3).

- [x] **Step 1: Read upstream first.**  2.11BSD `date.c` at patch #454
  (`examples/2.11BSD-Patches/454`, applied to
  `examples/2.11BSD/usr/src/bin/date.c`): how `gtime` builds the time and
  what it hands `settimeofday`.  Note every difference from FGX's
  `date.c` (header comment lists FGX's deltas).

- [x] **Step 2: Write D1** in `tztest.c` (root only; the harness runs as root):

```c
    {
        struct timeval save, now;
        long t0, back;
        int pid, st;

        gettimeofday(&save, (struct timezone *)0);
        t0 = ticks();
        zone(env_ny);                   /* date inherits environ */
        if ((pid = vfork()) == 0) {
            execl("/bin/date", "date", "2601151200", (char *)0);
            _exit(127);
        }
        while (wait(&st) != pid)
            ;
        gettimeofday(&now, (struct timezone *)0);
        back = now.tv_sec - 1768496400L;
        printf("TZ D1 %ld %s\n", back, back >= 0 && back <= 3 ? "ok" : "FAIL");
        if (back < 0 || back > 3)
            fail = 1;
        save.tv_sec += (ticks() - t0) / 60;         /* put the clock back */
        settimeofday(&save, (struct timezone *)0);
    }
```

  (`long ticks();` declared at the top as timetest does.)  Add
  `"TZ D1 "` to the JSON's `screen_contains`.

- [x] **Step 3: Run; expect D1 FAIL** (today's `gtime` treats the digits as
  UTC, so `back` is about -18000).

- [x] **Step 4: Change `gtime`** to fill a `struct tm` (`tm_isdst = -1`) and
  return `mktime`'s answer, as upstream #454's `date.c` does; the display
  path prints `tm_zone` where it printed a fixed zone.  Remove what FGX's
  header says was dropped for lack of zones, if it now exists.

  **As built:** patch #454's `date.c` does not call `mktime` (2.11BSD has
  none): it keeps gtime's arithmetic and subtracts `localtime()->tm_gmtoff`
  for the entered value, and `-u` is `setenv("TZ", "GMT", 1)`.  The port
  follows #454, which needed setenv(3) in libc (2.11BSD `gen/setenv.c`).
  dateset gains `date -u`, asserting GMT where the harness zone prints UTC.

- [x] **Step 5: Run tztest; expect `TZ D1 0 ok`..`3 ok` and PASS.**
  Mutation: revert Step 4's `mktime` to the old arithmetic -> D1 FAIL.

- [x] **Step 6: Update `date.c`'s PROVENANCE row** (the H1 row) with the new
  delta list.  Gate.  Commit: `"feat(date): the time to set is local time"`.

---

### Task 5: `adjkerntz(8)` at boot

**Files:**
- Modify: `src/kernel/tty/kern_time.c` (`adjkerntz` becomes `long`; the
  machdep leaf exchanges 4 bytes for it), `src/userland/timetest/timetest.c`
  (D1/D2 read it as a long)
- Create: `src/userland/adjkerntz/adjkerntz.c` (from
  `vendor/FreeBSD-2.2.8/sbin/adjkerntz/adjkerntz.c`)
- Modify: `tools/ninja/manifest.json` (tool + staging to
  `disk_src/sbin/adjkerntz`)
- Modify: `disk_src/etc/rc.in`
- Create: `disk_src/etc/wall_cmos_clock` (empty, tracked)
- Modify: `tools/check_modload_lists.py` only if it objects to the rc change
  (it should not)
- Modify: `src/userland/tztest/tztest.c`, `tools/mame_test/tests/tztest.json`
  (cases E1-E2)
- Modify: `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: `sysctl` `CTL_MACHDEP` leaves `CPU_ADJKERNTZ` 2, `CPU_DISRTCSET`
  3, `CPU_WALLCLOCK` 5 (`toolchain/include/sys/sysctl.h`), `localtime`,
  `mktime`, `daemon`, `syslog`, `sigsuspend`/`sigprocmask`.

- [x] **Step 0: Fix first, own commit: `adjkerntz` is 16 bits.**
  `src/kernel/tty/kern_time.c:49` declares `int adjkerntz`, and fcc's `int`
  is 16 bits, so the offset holds +-32,767 s: every zone more than 9 h 06 m
  from UTC overflows it (Pacific/Honolulu +36000, Australia/Sydney -36000 and
  -39600, Pacific/Auckland -46800).  FreeBSD 2.2.8 declares it `int`
  (`clock.c:100`) on a 32-bit `int` and serves it with `sysctl_handle_int`
  (`machdep.c:710-721`); the width upstream intends is 32 bits.  File a work
  item with that evidence, then:
  - `long adjkerntz = 0;` and every use (`tod_localoff` already casts it);
  - `tod_sysctl`'s `CPU_ADJKERNTZ` case copies a `long` in and out (4 bytes;
    `oldlenp` reports 4), the other three leaves stay `int`;
  - `timetest.c` gets a `mdlong(id, v)` helper beside `machdep()` for this
    leaf; D1/D2 use it;
  - a timetest case D5: write `machdep.adjkerntz = -46800` (New Zealand) and
    read it back equal -- red on the `int` build.
  Rebuild (announce), run `timetest` (D5 red before, green after), gate,
  commit `"fix(kernel): machdep.adjkerntz holds a zone more than nine hours
  from UTC"`, naming FreeBSD's lines.

- [x] **Step 1: Read `adjkerntz.c` whole** (377 lines) and FreeBSD 2.2.8's
  `/etc/rc` call site if vendored (else note that it is `adjkerntz -i` at the
  top of rc, per the man page).  List what FGX lacks: `_PATH_CLOCK` (define
  `"/etc/wall_cmos_clock"` as FreeBSD's `<paths.h>` does -- add it to FGX's
  `paths.h`), `LOG_PERROR`, `sigsuspend`.  Anything missing is a libc/toolchain
  fix in its own commit (CLAUDE.md "Toolchain-first"), not a local shim.
  `int kern_offset` (and the `len = sizeof(kern_offset)` it pairs with) must
  be `long`, matching Step 0's leaf: a port delta for the 16-bit `int`, named
  in the PROVENANCE row.

- [x] **Step 2: Write E1/E2** in `tztest.c`.  They are driven from the
  harness command, so the zone the KERNEL is adjusted to comes from
  `/etc/localtime`, as at boot.  The JSON `command` becomes:

```
/testbin/tztest; cp /usr/share/zoneinfo/America/New_York /etc/localtime; /sbin/adjkerntz -a; /testbin/tztest -k; cp /usr/share/zoneinfo/UTC /etc/localtime; /sbin/adjkerntz -a; /testbin/tztest -z
```

  `main(argc, argv)`: no argument runs A-D as before; `-k` runs only E1,
  `-z` only E2; each run prints its own `TZ VERDICT`.  Copy `rtcnow()`,
  `machdep()`/`NOVAL` and Step 0's `mdlong()` from `timetest.c` (file-local:
  the test must not trust the code it checks), and add:

```c
/* E1: machdep.adjkerntz is minus New York's current gmtoff, and the kernel
 * clock is the battery clock plus that offset (adjkerntz stepped it).
 * E2: back under UTC, the offset is 0 and the kernel clock is the battery
 * clock again. */
static void
kcheck(id, want_ny)
    char *id;
    int want_ny;
{
    struct timeval now;
    long off, want, diff;

    gettimeofday(&now, (struct timezone *)0);
    off = mdlong(CPU_ADJKERNTZ, NOVAL);
    zone(env_ny);
    want = want_ny ? -localtime(&now.tv_sec)->tm_gmtoff : 0L;
    diff = now.tv_sec - rtcnow() - off;
    printf("TZ %s off=%ld diff=%ld %s\n", id, off, diff,
           off == want && diff >= -2 && diff <= 2 ? "ok" : "FAIL");
    if (off != want || diff < -2 || diff > 2)
        fail = 1;
}
```

  JSON `screen_contains` gains `"TZ E1 off="` and `"TZ E2 off=0 "`.

- [x] **Step 3: Run; expect E1 FAIL** (`/sbin/adjkerntz: not found`).

- [x] **Step 4: Port `adjkerntz.c`** verbatim but for the FGX header block and
  what Step 1 found.  `daemon(0, 1)` stays (FGX's does not fork, #494; rc
  backgrounds it).  Man page: format FreeBSD's `adjkerntz.8` to a cat page
  (`mandoc -T ascii`, emphasis as overstrike -- `tools/check_man_overstrike.py`
  must pass) into `src/userland/man/pages/cat8/adjkerntz.0`, vendoring the
  roff source to `vendor/FreeBSD-2.2.8/sbin/adjkerntz/adjkerntz.8`.

- [x] **Step 5: `/etc/rc`.**  In `disk_src/etc/rc.in`, before the root is
  remounted read-write and before any daemon, with a comment citing FreeBSD
  2.2.8's rc placement and #494 for the `&`:

```sh
echo 'adjusting the kernel clock to the time zone' >/dev/console 2>&1
/sbin/adjkerntz -i &
```

  and track `disk_src/etc/wall_cmos_clock` (empty).

- [x] **Step 6: Run tztest and timetest; expect both PASS**, E1 `off=18000`
  in January or `14400` in July (the date the MAME clock reads).
  Mutation: delete `/etc/wall_cmos_clock` from the image -> E1 FAIL
  (`adjkerntz` exits without adjusting).  Restore.

- [x] **Step 7: Boot smoke.**  The gate's boot tests reach the prompt with
  rc's new line (no hang); `FGX_TZ=America/New_York` built once by hand and
  booted headless: `timetest` A3 now compares battery clock and kernel with
  the offset -- expect it to FAIL there (it assumes offset 0) and record
  that as the evidence that `-i` ran at boot; do not ship that build.
  Rebuild with `FGX_TZ` unset (announce both rebuilds).

- [x] **Step 8: PROVENANCE row, gate, commit.**
  `"feat(sbin): adjkerntz(8) sets the kernel's zone offset at boot"`.

---

### Task 6: documentation

**Files:**
- Create: `src/userland/man/pages/cat3/ctime.0` (from 2.11BSD's or Reno's
  formatted page; Reno's `ctime.3` documents `mktime`/`tzset`), 
  `src/userland/man/pages/cat5/tzfile.0`
- Modify: `src/userland/man/pages/cat1/date.0` if FGX ships one (zone now
  honoured)
- Modify: `docs/PROVENANCE.md`, `docs/ROADMAP.md` (pointer paragraph),
  `docs/history/plans/2026-09-25-libc-time-zones-design.md` (status),
  this plan (boxes)

- [x] **Step 1:** Vendor the upstream roff for each page under
  `vendor/4.3BSD-Reno/...`; format to cat pages as Task 5 Step 4 does; FGX
  deltas (the 1970-2038 range, `TZ_MAX_*`, no leap-second zones, `zic` not on
  the machine) in BUGS.  `check_man_overstrike.py` clean.
- [x] **Step 2:** PROVENANCE rows for the pages; `check_provenance.py` clean.
- [x] **Step 3:** ROADMAP: replace the kernel-clock pointer's "Open:
  sub-projects 2 ..." with this sub-project's pointer; design status
  "implemented"; plan boxes ticked with any departures written in.
- [x] **Step 4:** the project notes episode (group `fgx`): what landed, the 16-bit
  sites found, the measured sizes, the oracle's C2 value.
- [x] **Step 5:** Commit; report to the maintainer; ask before pushing
  `feat/libc-time-zones` (`ALLOW_FEAT_PUSH=1`, plus `FGX_NO_GATE=1` when the
  head is already gated) and opening the MR (no Claude line or URL in the MR
  description).
