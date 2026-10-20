#!/usr/bin/env python3
"""modimage_check -- every loaded module's image still matches the file it came
from (apple/fgx#110).

A module is read from disk into a bank and then nothing ever looks at that bank
again.  apple/fgx#29 was two stray 16-bit stores landing inside a freshly loaded
image, turning four bytes of `_fop_rename` into BRKs; it presented as "rename(2)
is broken", which is a symptom nobody traces back to module loading, and it cost
a long investigation past two wrong diagnoses.  What settled it in ten minutes
was a byte-for-byte compare of the in-RAM image against the built file.  This is
that compare, run on every gate.

NOTHING HERE IS BAKED.  The manifest dumps two whole banks by ORDINAL, and every
offset, length and expected byte comes from the module files themselves:

  * which bank an ordinal is in   -> _modBankTab, read by the plugin at runtime
  * where a module sits in it     -> its own FGXM load address (header +4)
  * how many bytes are its image  -> its own FGXM text size (header +10)
  * which modules should be there -> /etc/modload.conf and the modules the
                                     test boot's rc.local loads, plus any module
                                     found staged by the loader (see PRE-LOADED
                                     below)

That matters more than it looks.  Module offsets move whenever a module grows
(gen_modplace reassigns them), so a manifest carrying `"addr_hex": "005100"`
would go stale silently and compare the wrong bytes -- and comparing the wrong
bytes is worse than not comparing, because it still says PASS.

THE THREE LEGITIMATE DIFFERENCES, each measured rather than assumed.  On a clean
boot the five loaded modules differ from their files in 16 to 534 bytes, and
every one of those falls into exactly one of these:

1. THE 40-BYTE FGXM HEADER, for conf-loaded modules.  Mod_Load copies text to
   load_addr + FGXM_HEADER_SZ and never writes the header area, so it reads as
   whatever was there.  A module the LOADER staged (prodos today) is copied
   whole and DOES carry its header -- so the header's presence is detected per
   module, not assumed either way.

2. A ZERO BYTE IN THE FILE.  Zero is padding or a zero-initialised static, and
   statics are exactly what legitimately changes at runtime.  vfs accounts for
   534 of these on its own -- pool pointers and cached banks written during
   mod_init.

   THIS IS THE REAL LIMIT OF THE TEST, and it is stated rather than buried: a
   stray write that lands on a byte the file has as zero is NOT caught.  Closing
   it needs a text/data split in the FGXM header, which does not exist; with one,
   this clause becomes "outside the data section" and the check becomes exact.
   What IS covered is every non-zero byte -- all code, all constant tables --
   which is the class #29 belonged to.

3. A BANK RELOCATION PATCH: the file byte equals the module's own assembled bank
   (its FGXM load-address high byte) and the RAM byte equals the live bank it was
   loaded into.  Both sides are derived, so this cannot be used to excuse an
   arbitrary byte -- only the exact substitution the loader performs.

4. THE ONE HAND-PLACED ALLOWANCE, and it is a real finding rather than a
   convenience: serial.mod PATCHES ITS OWN TEXT.  `_serCfgRead` decodes the
   control-panel baud/data/parity/stop settings and writes the display
   characters straight into `banner_{A,B}_tmpl` (`banB_d` = banner_B_tmpl+21 and
   friends), so a machine configured for 8N1 still shows three bytes changed --
   `8N1` rewritten as high ASCII.  This test found that on its first real run.

   It is by design and documented in that module, so it is allowed -- but only
   INSIDE the two banner templates, which are located by searching the file for
   their own text rather than by baking an offset.  Nothing else in serial, and
   nothing at all in any other module, may differ.

   It is allowed rather than fixed because it is a driver's deliberate behaviour
   and not this test's business to change.  Two things would remove the
   allowance: an FGXM text/data split, which would also close the zero-byte gap
   above, or serial composing its banner in a scratch buffer instead of in its
   own image.  Both are worth doing; neither is worth doing blind.

Measured on a clean boot: these explain 100% of the differences across prodos,
ramdisk, pty, net, serial and vfs, with nothing left over.  A fifth kind of
difference appearing is the finding, which is the point.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
MODDIR = REPO / "disk_src" / "lib" / "modules"
CONF = REPO / "disk_src" / "etc" / "modload.conf"
# The test boot's /etc/rc.local (run.py stages it), which turns on the modules
# modload.conf leaves to rc.local: they are loaded, so they are compared too.
TEST_RC_LOCAL = REPO / "tools" / "mame_test" / "rc.local"
SYSCFG = REPO / "cfg" / "system.cfg"
HDR = 40                                  # FGXM_HEADER_SZ (include/fgxm.s)
ORG_BANK = 0x05                           # FGX_MOD_ORG_BANK; ordinal = hi - this

# A comparison that inspects almost nothing would pass in silence, which is the
# failure mode this whole test exists to avoid.  On the current tree the five
# loaded modules present ~54,000 non-zero bytes between them; require a floor
# far below that but far above "the dump was empty".
MIN_BYTES_COMPARED = 20000

# Clause 4: serial.mod patches the control-panel baud/data/parity/stop display
# characters into these templates in place (_serCfgRead).  Located by CONTENT so
# no offset is baked; only bytes inside a located template are allowed to differ.
#
# THE ANCHOR IS THE HEAD OF THE TEMPLATE AND NOT ITS tty NAME, because the name
# has already moved once.  These read `tty00 SCC ch.A ' until 2026-09-06, when
# the boot-log cleanup rewrote serial's banner and put the line name at the END
# -- `SCC ch.A 9600  8N1 (IRQ RX/TX) (attaching tty00)'.  Neither literal was
# found after that, so the allowance never applied and the three legitimate
# high-ASCII bytes of `8N1' were reported as a violation.
#
# THE CHECKER SAID SO, TWICE, and was right both times: it reports a missing
# anchor as its own finding rather than silently widening or narrowing what it
# will accept.  What hid it is that the harness surfaces only the LAST finding
# line, so the two that explained the third were off screen.  Run this script
# directly against dump.json to see all of them.
SELF_PATCHED = {"serial": (b"SCC ch.A ", b"SCC ch.B ")}


def gated_off(text=None):
    """Modules cfg/system.cfg builds OUT, as `kernel.<name> = 0`.

    modload.conf is the roster of what a FULL kernel loads; system.cfg decides
    which of those the kernel was actually built with.  A module gated off is
    absent BY DESIGN, so requiring it is asking the shipping configuration to
    fail -- apple/fgx#290, where `kernel.ufsprobe = 0` (with a note saying it
    "must stay 0") made this checker red on every default build.

    Only an explicit 0 excuses a module.  A name with no gate at all is still
    required, because that is the case where a genuinely missing module would
    otherwise be waved through -- which is the failure this checker exists for.
    """
    if text is None:
        if not SYSCFG.exists():
            return set()
        text = SYSCFG.read_text()
    off = set()
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line.startswith("kernel."):
            continue
        name, _, val = line.partition("=")
        name = name.strip()[len("kernel."):].strip().lower()
        if name and val.strip() == "0":
            off.add(name)
    return off


def conf_modules():
    if not CONF.exists():
        return None
    off = gated_off()
    out = []
    for line in CONF.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line and line.lower() not in off:
            out.append(line.lower())
    if TEST_RC_LOCAL.exists():
        for line in TEST_RC_LOCAL.read_text().splitlines():
            words = line.split("#", 1)[0].split()
            if words[:1] in (["modload"], ["/sbin/modload"]):
                for w in words[1:]:
                    if w[:1] in "<>" or w[:1].isdigit():
                        break
                    if w.lower() not in off and w.lower() not in out:
                        out.append(w.lower())
    return out


def parse(path):
    b = path.read_bytes()
    if b[:4] != b"FGXM":
        return None
    return {
        "name": b[16:32].split(b"\0")[0].decode("ascii", "replace").lower(),
        "off": b[4] | b[5] << 8,
        "asmbank": b[6],
        "ordinal": b[6] - ORG_BANK,
        "text": b[10] | b[11] << 8,
        "bytes": b,
        "file": path.name,
    }


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    mem = d.get("memory", {})

    want = conf_modules()
    if want is None:
        print("modimage: FAIL -- /etc/modload.conf not found; cannot tell which "
              "modules should be loaded, and skipping them all would pass")
        return 2

    mods = [m for m in (parse(p) for p in sorted(MODDIR.iterdir())) if m]

    # EVERY ORDINAL A MODULE ACTUALLY USES, not a hardcoded pair.  There are
    # seven (0 serial+bpf+net+ramdisk+pty, 1 vfs, 2 ufs, 3 ufsprobe, 4 ufsdir,
    # 5 prodos, 6 prodosw) and this asked for two, so a module in 2..4 was skipped in
    # silence and then reported "not found loaded" -- a harness gap wearing a
    # kernel defect's message (apple/fgx#290, plan increment D1).
    banks, unwitnessable = {}, []
    for ordn in sorted({m["ordinal"] for m in mods}):
        r = mem.get(f"modbank{ordn}")
        if r is None:
            print(f"modimage: FAIL -- dump has no modbank{ordn} region, so a "
                  f"module in that bank cannot be witnessed either way; add it "
                  f"to memory_regions in the manifest")
            return 2
        if not r.get("hex"):
            # No bank in _modBankTab: nothing was loaded into this ordinal.
            # That is ONLY a failure if something required lives here, and the
            # roster check below is what decides it.
            unwitnessable.append(ordn)
            continue
        banks[ordn] = (binascii.unhexlify(r["hex"]), r["addr"] >> 16)
    checked, compared, findings, roster = [], 0, [], []

    for m in mods:
        if m["ordinal"] not in banks:
            continue
        ram, live = banks[m["ordinal"]]
        img = m["bytes"][: HDR + m["text"]]
        seg = ram[m["off"]: m["off"] + len(img)]
        if len(seg) < len(img):
            findings.append(f"{m['name']}: image runs past the end of its bank")
            continue

        hdr_present = seg[:4] == b"FGXM"
        loaded = hdr_present or m["name"] in want
        if not loaded:
            roster.append(f"{m['name']}(not loaded)")
            continue
        roster.append(m["name"] + ("(pre-staged)" if hdr_present else ""))

        allow = []
        for lit in SELF_PATCHED.get(m["name"], ()):
            at = img.find(lit)
            if at < 0:
                findings.append(f"{m['name']}: self-patch template {lit!r} not "
                                f"found in {m['file']}; the allowance below is "
                                f"stale and would hide real differences")
            else:
                allow.append((at, at + 40))     # template + its patched fields

        bad = []
        for i in range(len(img)):
            f, g = img[i], seg[i]
            if i < HDR and not hdr_present:
                continue                       # header area never written
            if f == 0:
                continue                       # padding / zero-init static
            compared += 1
            if f == g:
                continue
            if f == m["asmbank"] and g == live:
                continue                       # bank relocation patch
            if any(lo <= i < hi for lo, hi in allow):
                continue                       # serial's own banner patch
            bad.append((i, f, g))

        checked.append(m["name"])
        if bad:
            where = ", ".join(f"+${i:04X} file=${f:02X} ram=${g:02X}"
                              for i, f, g in bad[:8])
            findings.append(
                f"{m['name']}: {len(bad)} byte(s) in the loaded image do not "
                f"match {m['file']} and are not relocation -- {where}"
                + (" ..." if len(bad) > 8 else ""))

    # A REQUIRED MODULE THIS RUN COULD NOT SEE IS A DIFFERENT SENTENCE from one
    # that failed to load, and saying the second when the first is true sends a
    # reader at the kernel for a manifest's fault.
    empty_ord = {m["name"]: m["ordinal"] for m in mods
                 if m["ordinal"] in unwitnessable}
    missing = [w for w in want if w not in checked]
    blind = [w for w in missing if w in empty_ord]
    real = [w for w in missing if w not in empty_ord]
    if real:
        findings.append("listed in modload.conf but not found loaded: "
                        + ", ".join(real))
    if blind:
        findings.append(
            "listed in modload.conf and NOT WITNESSABLE -- their ordinal has no "
            "bank in _modBankTab, so this run cannot say whether they loaded: "
            + ", ".join(f"{n} (ordinal {empty_ord[n]})" for n in blind))

    if compared < MIN_BYTES_COMPARED:
        print(f"modimage: FAIL -- only {compared} bytes compared "
              f"(floor {MIN_BYTES_COMPARED}); the dump or the roster is wrong, "
              f"and a comparison this thin would pass whatever happened")
        return 1

    if findings:
        print("modimage: FAIL")
        for f in findings:
            print("  " + f)
        return 1

    print(f"modimage: PASS -- {compared} non-zero bytes across "
          f"{len(checked)} modules match their files "
          f"({', '.join(roster)})")
    return 0


def self_test():
    """Both directions, because only one of them can go wrong quietly.

    A gate this checker ignored would fail the shipping build (apple/fgx#290).
    A gate it honoured too eagerly would EXCUSE a module that is genuinely
    missing, which is the failure it exists to catch -- and that one is silent,
    so the second case matters more than the first.
    """
    cfg = ("kernel.nproc = 12\n"
           "kernel.ufsprobe = 0      # gated OFF: must not be required\n"
           "kernel.kcprobe = 1       # gated ON: still required\n"
           "kernel.spext = 1\n"
           "# kernel.commented = 0   <- a comment is not a gate\n")
    off = gated_off(cfg)
    fails = []
    if "ufsprobe" not in off:
        fails.append("a `= 0' gate was not seen, so the shipping build stays red")
    if "kcprobe" in off:
        fails.append("a `= 1' gate was treated as OFF, which would excuse a "
                     "module that failed to load")
    if "commented" in off:
        fails.append("a commented-out gate was honoured")
    if "nproc" in off or "spext" in off:
        fails.append("a non-zero setting was treated as a gate")
    if "serial" in off:
        fails.append("a module with no gate at all was excused")

    for f in fails:
        print("modimage_check --self-test: FAIL -- " + f)
    if fails:
        return 1
    print("modimage_check --self-test: OK (%d gate case(s))" % 5)
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dump.json"))
