#!/usr/bin/env python3
"""check_tzlimits -- every staged zone file fits libc's tzfile.h limits.

libc's tzload (toolchain/lib/libc_c/ctime.c, 4.3BSD-Reno) refuses a file
whose version-1 block has more transitions, types or abbreviation characters
than TZ_MAX_TIMES, TZ_MAX_TYPES or TZ_MAX_CHARS, and falls back to GMT --
silently, on the machine.  This makes that a build failure instead.  A file
with leap seconds fails too: none of the zones FGX ships has any, so one that
does came from somewhere else.

The GMT file is held to one more rule.  gmtime's gmtsub names its zone with
the file's FIRST abbreviation (ctime.c, as 4.3BSD-Reno's), so that must be
"GMT".  zic -r writes a "-00" placeholder type ahead of the zone's own for
the times outside its range (zic(8), -r), so the Etc zones are compiled
without it (tools/ninja/tz.sh) -- they have no transitions to trim.

    check_tzlimits.py <zoneinfo dir>     check every file under it
    check_tzlimits.py --self-test        a zone compiled WITHOUT -r must
                                         fail, and a GMT compiled WITH it
"""
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def limits():
    """The limits, read from toolchain/include/tzfile.h, the header libc's
    tzload is compiled with."""
    text = open(os.path.join(ROOT, "toolchain/include/tzfile.h")).read()
    # tzfile.h defines NOSOLAR, so its `#ifndef NOSOLAR' arm (TZ_MAX_TYPES
    # 256) is not the one compiled: drop it, as the preprocessor does.
    if re.search(r"^#define\s+NOSOLAR\b", text, re.M):
        text = re.sub(r"#ifndef NOSOLAR.*?#else", "", text, flags=re.S)
    out = {}
    for k in ("TZ_MAX_TIMES", "TZ_MAX_TYPES", "TZ_MAX_CHARS"):
        m = re.search(r"#define\s+%s\s+(\d+)" % k, text)
        if not m:
            sys.exit("check_tzlimits: %s not in toolchain/include/tzfile.h" % k)
        out[k] = int(m.group(1))
    return out


def first_abbr(d):
    """The first abbreviation in a TZif file's version-1 block."""
    times, types, chars = struct.unpack(">3l", d[32:44])
    o = 44 + times * 5 + types * 6
    return d[o:o + chars].split(b"\0")[0].decode("ascii", "replace")


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
            if (times > lim["TZ_MAX_TIMES"] or types > lim["TZ_MAX_TYPES"]
                    or chars > lim["TZ_MAX_CHARS"] or leap != 0):
                bad.append("%s: times=%d types=%d chars=%d leaps=%d"
                           % (os.path.relpath(p, zdir), times, types, chars,
                              leap))
    g = os.path.join(zdir, "GMT")
    if n and (not os.path.exists(g) or first_abbr(open(g, "rb").read()) != "GMT"):
        bad.append("GMT: first abbreviation %r, which gmtime would name its "
                   "zone (compile etcetera without -r)"
                   % (first_abbr(open(g, "rb").read()) if os.path.exists(g)
                      else None))
    return n, bad


def main():
    if sys.argv[1:] == ["--self-test"]:
        zic = os.path.join(ROOT, "build/tz_host/zic")
        if not os.path.exists(zic):     # the gate self-tests before it builds
            subprocess.run(["bash", os.path.join(ROOT, "tools/ninja/tz.sh"),
                            "host"], check=True)
        src = os.path.join(ROOT, "vendor/tzdata-2026d/northamerica")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([zic, "-b", "fat", "-d", t, src], check=True)
            n, bad = check(t)
        if not bad:
            print("check_tzlimits: SELF-TEST FAILED: full-history zones passed")
            return 1
        etc = os.path.join(ROOT, "vendor/tzdata-2026d/etcetera")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([zic, "-b", "fat", "-r", "@0/@2147483647", "-d", t,
                            etc], check=True)
            _, gbad = check(t)
        if not any(b.startswith("GMT:") for b in gbad):
            print("check_tzlimits: SELF-TEST FAILED: a -r GMT file passed")
            return 1
        print("check_tzlimits: self-test ok (%d of %d full-history zones "
              "refused)" % (len(bad), n))
        return 0
    if len(sys.argv) != 2:
        print(__doc__.strip())
        return 2
    n, bad = check(sys.argv[1])
    if n == 0:
        print("check_tzlimits: no zone files under %s" % sys.argv[1])
        return 1
    if bad:
        print("check_tzlimits: %d zone file(s) libc cannot use as built:"
              % len(bad))
        for b in bad[:20]:
            print("  " + b)
        return 1
    print("check_tzlimits: clean (%d zones within %s)" % (n, limits()))
    return 0


sys.exit(main())
