#!/usr/bin/env python3
"""ufsboot_check -- did stage 2 assemble the kernel out of a 2.11BSD filesystem?

UFS campaign 2.3.  The boot chain reads its files off a UFS volume now, and
the question a blank screen cannot answer is whether the bytes it assembled
are the bytes on the host.  So this compares two windows of the LIVE kernel
bank against bin/fgx.bin:

  kearly  a string ~1 KB into the image, inside the inode's FIRST direct
          block.  It passes even when nothing but the direct blocks work.
  kdeep   a string ~52 KB in.  Four direct blocks cover 4 KB, so every byte
          past that is reached through the single indirect block, the
          half-swapped daddr_t in it, and the multipass MVN on top.

BOTH ARMS ARE HERE BECAUSE THE FIRST ONE ALONE PASSED A BROKEN READER.  The
indirect address was fetched at di_addr[(12+4)*4] rather than di_addr[12+4*4]
-- Merlin32 evaluates strictly left to right -- which read past the dinode,
found zero, and took the legal HOLE path.  The kernel loaded four direct
blocks, zero-filled its other fifty-four, and reset into ROM.  `kearly'
matched throughout.

AND THE HALT IS AN ASSERTION, not a disappointment.  The ROOT filesystem is
still ProDOS until campaign 2.4, so a kernel booted from a UFS volume comes up
with no root it can mount and stops in _Halt.  Reaching _Halt is therefore the
statement that everything BEFORE the root mount ran: six path walks, four file
loads, the module pre-stage and the handoff.  Reaching ROM instead is what a
broken load looks like, and reaching a shell would mean 2.4 had landed and
this test needs rewriting.

Run standalone:  python3 ufsboot_check.py <dump.json>
Self-test:       python3 ufsboot_check.py --self-test
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
KERNEL_BIN = os.path.join(REPO, "bin", "fgx.bin")
LISTING = os.path.join(REPO, "build", "fgx_S01_KernelMain_Output.txt")
FAR_LISTING = os.path.join(REPO, "build", "fgxfar_Output.txt")

# Where stage 2 puts the kernel image inside its bank: FGX_CODE's offset,
# read from include/kernel.s rather than copied (stage2.s KERNEL_DEST_LO is
# its lockstep copy); a region's reported address minus this is its offset in
# bin/fgx.bin.
def _kernel_dest_lo():
    with open(os.path.join(REPO, "include", "kernel.s")) as f:
        m = re.search(r"^\s*FGX_CODE\s+EQU\s+\$([0-9A-Fa-f]+)", f.read(), re.M)
    if not m:
        raise SystemExit("ufsboot_check: no FGX_CODE EQU in include/kernel.s")
    return int(m.group(1), 16) & 0xFFFF


KERNEL_DEST_LO = _kernel_dest_lo()

ARMS = ("kearly", "kdeep")


def label_addr(name, listing):
    """A label's 16-bit address, from the listing rather than baked."""
    pat = re.compile(r"\|\s*[0-9A-F]{2}/([0-9A-F]{4})\s*(?::[^|]*)?\|\s*"
                     + re.escape(name) + r"\b")
    try:
        with open(listing) as f:
            for line in f:
                m = pat.search(line)
                if m:
                    return int(m.group(1), 16)
    except IOError:
        return None
    return None


def check(dump):
    bad = []
    notes = []
    mem = dump.get("memory") or {}
    try:
        kern = open(KERNEL_BIN, "rb").read()
    except IOError as e:
        return ["cannot read %s: %s" % (KERNEL_BIN, e)], []

    for name in ARMS:
        r = mem.get(name)
        if not r:
            bad.append("%s: region missing from the dump" % name)
            continue
        got = bytes.fromhex(r["hex"])
        off = (r["addr"] & 0xFFFF) - KERNEL_DEST_LO
        want = kern[off:off + len(got)]
        if got == want:
            notes.append("%s ok at +%d (%r)" % (name, off, want[:12]))
        else:
            bad.append("%s: kernel byte %d is %s on the machine and %s in "
                       "bin/fgx.bin" % (name, off, got.hex(), want.hex()))

    ps = mem.get("prestaged")
    if ps is None:
        bad.append("prestaged: region missing from the dump")
    elif not any(bytes.fromhex(ps["hex"])):
        bad.append("_PreStaged_Banks is all zeros -- stage 2 pre-staged NOTHING, "
                   "so /fgxunix was not found, or its segment table named no "
                   "module segments.  On a UFS volume a not-found is the "
                   "lowercase path set failing; a bad table says so on the "
                   "boot console instead of getting this far.")
    else:
        notes.append("pre-staged banks %s, so the lowercase /etc and /lib paths "
                     "resolved" % bytes.fromhex(ps["hex"]).hex())

    rs = mem.get("rootstatus")
    if rs is None:
        bad.append("rootstatus: region missing from the dump")
    else:
        v = int.from_bytes(bytes.fromhex(rs["hex"]), "little", signed=True)
        if v == 1:
            notes.append("root_status 1: root_mount() mounted the boot volume "
                         "as the root, which is what /fgxunix carrying "
                         "vfs/ufs/ufsdir as segments bought")
        elif v == 0:
            bad.append(
                "root_status is 0, which is NEVER RAN -- the value the far "
                "bank's image carries, since that bank is not zeroed at load.  "
                "root_mount() did not execute at all: the usual cause is a "
                "pre-staged module missing, so check the `mod: <name> loaded' "
                "lines before blaming the mount.")
        else:
            bad.append(
                "root_status is %d: root_mount() RAN and refused (-1, -2 and "
                "-3 are its failures; -2 is `this is not a UFS volume').  The "
                "boot volume stopped being mountable as the root." % v)

    # THE CONSOLE CAME UP, and this arm is the whole point of the change that
    # retired the font panic.  A kernel that cannot load glyphs renders NOTHING
    # -- the panic goes to the firmware text console and SHR stays as the boot
    # ROM left it -- so a framebuffer with real content is the statement that
    # stage 2 staged /lib/fonts/default.fnt into KFAR_BOOT_FONT off a 2.11BSD
    # volume and Con_Init accepted the header.  Nothing else in this dump can
    # say that: CharBuf holds codepoints whether or not a glyph exists for them.
    shr = mem.get("shr_full")
    if shr is None or not shr.get("hex"):
        bad.append("shr_full: region missing from the dump, so the arm that "
                   "says the console RENDERED did not run")
    else:
        px = bytes.fromhex(shr["hex"])
        lit = sum(1 for b in px if b)
        if len(px) < 32000:
            bad.append("shr_full is %d bytes, want the whole 32,000-byte "
                       "framebuffer" % len(px))
        elif lit < 512:
            bad.append(
                "the SHR framebuffer has only %d non-zero bytes -- the console "
                "painted nothing.  That is what a font failure looks like: "
                "Con_Init panics to the firmware text console and never renders "
                "a glyph.  Check that stage 2 still stages /lib/fonts/"
                "default.fnt into KFAR_BOOT_FONT." % lit)
        else:
            notes.append("the SHR framebuffer carries %d non-zero bytes, so the "
                         "boot program's staged font rendered" % lit)

    # THE HALT ARMS ARE GONE, AND THAT IS THE MILESTONE -- UFS campaign 2.4.
    #
    # Two arms stood here: _conStrPtr had to name _K_haltMsg, and the CPU had to
    # be inside _Kern_Halt's WAI/BRA loop.  Both said "this machine mounted its
    # root and then stopped, because it could not read /etc/init through it".
    # It can now: Load_Binary reads a root descriptor in the far bank, the
    # volume boots to a shell, and this test's own description said the day
    # that happened the assertion had to be rewritten.  This is that rewrite.
    #
    # NEITHER ARM CAN SIMPLY BE INVERTED, and the reason is the same for both:
    # they read DIRECT PAGE cells at a baked bank-0 address.  That was sound
    # while the machine was halted -- the DP at the halt is $0900, so _conStrPtr
    # ($E0) is bank-0 $0009E0 -- and it stops being sound the moment the machine
    # is RUNNING, because the direct page then belongs to whichever task the
    # sample frame caught.  An arm that reads a different task's page would go
    # red on scheduling, which is noise and not evidence.
    #
    # SO THE CLAIM MOVED TO THE SCREEN, where it is stronger than it was in
    # memory.  The manifest asserts "Starting network...", which /etc/rc prints
    # -- so init was loaded off the UFS root, execve'd, and ran its script --
    # and it asserts the ABSENCE of "init load failed" and "system halted",
    # which are the two ways this boot used to end.  The absence arms are
    # allowed to count because the presence arm is there with them: run.py
    # refuses screen_lacks on an empty capture, and a boot that never started
    # cannot print /etc/rc's line.
    #
    # WHAT STILL LIVES IN MEMORY, because the screen cannot say it: the two
    # kernel-image windows (the deep one is the indirect-block reader's only
    # witness), _PreStaged_Banks, root_status, and the SHR framebuffer -- which
    # remains the only thing that can state the staged font was delivered AND
    # accepted, since CharBuf holds codepoints whether a glyph exists or not.
    return bad, notes


def main(argv):
    if argv[:1] == ["--self-test"]:
        return self_test()
    if not argv:
        print("ufsboot: no dump path given")
        return 2
    try:
        dump = json.load(open(argv[0]))
    except (IOError, ValueError) as e:
        print("ufsboot: cannot read dump: %s" % e)
        return 2
    bad, notes = check(dump)
    if bad:
        print("ufsboot: FAIL -- " + "; ".join(bad))
        return 1
    print("ufsboot: PASS -- " + "; ".join(notes))
    return 0


def self_test():
    """THE POSITIVE CONTROL.  A checker that cannot call a bad dump bad reads
    exactly like one that passes everything, so each arm is mutated here and
    must be caught."""
    kern_ok = os.path.exists(KERNEL_BIN)
    if not kern_ok:
        print("  FAIL  %s missing; build the kernel first" % KERNEL_BIN)
        return 1
    kern = open(KERNEL_BIN, "rb").read()

    def dump_with(early_ok=True, deep_ok=True,
                  staged=True, rooted=True, painted=True,
                  shr_len=32000, rootval=None):
        def win(off, ok):
            b = kern[off:off + 16]
            return (b if ok else bytes(16)).hex()
        # A framebuffer with SOME ink in it, or a blank one -- the two states
        # the console-came-up arm has to tell apart.
        px = bytearray(shr_len)
        if painted:
            for i in range(0, min(shr_len, 4000), 2):
                px[i] = 0x55
        return {
            "kernel_bank": 0x7C,
            "memory": {
                "kearly": {"addr": (0x7C << 16) | (KERNEL_DEST_LO + 0x455),
                           "hex": win(0x455, early_ok)},
                "kdeep": {"addr": (0x7C << 16) | (KERNEL_DEST_LO + 0xD138),
                          "hex": win(0xD138, deep_ok)},
                "prestaged": {"addr": (0x7C << 16) | 0xFF08,
                              "hex": ("05000000" if staged else "00000000")},
                "rootstatus": {"addr": (0x7D << 16) | 0x45D9,
                               "hex": (rootval.to_bytes(2, "little").hex()
                                       if rootval is not None
                                       else ("0100" if rooted else "0000"))},
                "shr_full": {"addr": 0x012000, "hex": bytes(px).hex()},
            },
        }

    cases = [
        ("a correct dump passes", dump_with(), True),
        ("a zeroed DEEP window is caught -- the real defect's signature",
         dump_with(deep_ok=False), False),
        ("a zeroed EARLY window is caught", dump_with(early_ok=False), False),
        ("an empty _PreStaged_Banks is caught -- the lowercase-path control",
         dump_with(staged=False), False),
        ("root_status back to 0 is caught -- root_mount never ran, which is "
         "what a missing pre-staged module looks like from here",
         dump_with(rooted=False), False),
        ("root_status as a REFUSAL (-2) is caught, and told apart from 0",
         dump_with(rootval=0xFFFE), False),
        ("a BLANK framebuffer is caught -- what a font failure looks like",
         dump_with(painted=False), False),
        ("a short framebuffer dump is caught rather than counted",
         dump_with(shr_len=1000), False),
        ("a dump with no regions is caught", {"memory": {}}, False),
    ]
    ok = True
    for label, dump, want_pass in cases:
        bad, _ = check(dump)
        passed = not bad
        if passed != want_pass:
            print("  FAIL  %s (got %s)" % (label, "pass" if passed else "fail"))
            ok = False
        else:
            print("  ok    %s" % label)
    print("ufsboot_check self-test: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
