#!/usr/bin/env python3
"""check_kernelc_calls.py - no FGX2 linker/loader macro may reach the far bank.

TWO MACROS, ONE FAILURE SHAPE.  Both are placeholders that fcc emits for tools
the far kernel bank never runs, and both assemble to zero bytes with no
diagnostic if they get there:

  FGX2_FARCALL   a call.  `JSL $000000`, operand patched by fgx_ld.  Reaches
                 $00:0000.  Guarded by --pile.
  FGX2_LONG_PTR  a &function or string-pointer data cell.  Offset resolved by
                 fgx_ld, bank byte written by the FGX2 loader.  Four zero
                 bytes, so a vector of them dispatches to $00:FFFF.  The
                 &function case is what --kernel-bank replaces.
  LIBC_DATA_PTR  an &global data cell.  The offset DOES resolve at assembly,
                 which makes this the nastiest of the three: only the bank
                 byte is missing, and unlike a function pointer a data
                 pointer's bank byte IS read on every deref.  So the cell
                 reads as bank 0 -- a plausible address in the wrong bank
                 rather than an obvious jump to nowhere.

All three found by apple/fgx#88, which no fixture could have caught: the fcc
fixtures ARE FGX2 binaries, where every one of these macros is correct.  The
context that breaks them is the one with no linker and no loader.


fcc's default output targets FGX2 userland, where a call to another user
function is `FGX2_FARCALL fn` -- a `JSL $000000` whose operand and bank byte
fgx_ld patches when it links the segments together.

The kernel far bank has no linker.  far.s PUTs the generated .s and Merlin32
assembles it, so an FGX2_FARCALL keeps its three zero bytes and the call
transfers to $00:0000.  Nothing complains: the macro assembles, the image
builds, the kernel boots, and the first C-to-C call jumps into bank 0.  That is
the same silent shape as a missing _kfp patch site, and it is why the kernelc
rule passes --pile (see tools/ninja/gen.py).

This check is the guard on that flag.  It runs on every kernel C compile, so
dropping --pile fails the BUILD rather than the machine.

The far bank's own RTL contract is checked separately by
tools/check_far_rtl_calls.py; this one is about reaching the target at all.
"""
import os
import re
import sys

# The macros as fcc emits them (emit_mac_farcall / emit_mac_longptr in
# toolchain/src/cc/emit.c).
FARCALL_RE = re.compile(r"^\s*FGX2_FARCALL\s+(\S+)", re.M)
LONGPTR_RE = re.compile(r"^\s*(?:\S+\s+)?FGX2_LONG_PTR\s+(\S+)", re.M)
DATAPTR_RE = re.compile(r"^\s*(?:\S+\s+)?LIBC_DATA_PTR\s+(\S+)", re.M)

_FIX_FARCALL = (
    "Compile kernel C with --pile so user calls use the relocation-safe "
    "PHK/PEA/PHK/PEA/RTL idiom instead.")

# fcc's tag is the first field of the operand (_Fa=&function, _Sa/_Sg=string
# pool, _Ga/_Spg=&global), and it decides which advice is the RIGHT advice.
# Telling someone to turn on a flag that is already on sends them after the
# wrong thing -- which is worse than saying nothing.
_FIX_FA = (
    "Compile kernel C with --kernel-bank so a &function cell becomes "
    "KFAR_FN_PTR, whose offset Merlin resolves in this image and whose bank "
    "the indirect call takes from PHK.")
_FIX_DATA = (
    "This is an initialised pointer-to-DATA global, which kernel C cannot "
    "have yet -- and --kernel-bank does not help, because a data pointer's "
    "bank byte is read on every deref and cannot come from PHK.  Fixing it "
    "needs a boot-time patch table for far-bank data cells (the far bank "
    "already has two, for core->far and far->core call operands).  Until "
    "then: initialise the pointer at RUNTIME, where the address is formed "
    "from the live DBR.  A string literal used directly in an EXPRESSION "
    "(kc_panic(\"...\")) is fine and needs no cell at all.")


def _fix_for(macro, tag):
    if macro == "FGX2_FARCALL":
        return _FIX_FARCALL
    if tag.startswith("_Fa"):
        return _FIX_FA
    return _FIX_DATA


_BANNED = (
    (FARCALL_RE, "FGX2_FARCALL",
     "these assemble as JSL $00:0000 and call into bank 0"),
    (LONGPTR_RE, "FGX2_LONG_PTR",
     "these assemble as four ZERO bytes, so a function-pointer table "
     "dispatches to $00:FFFF (apple/fgx#88)"),
    (DATAPTR_RE, "LIBC_DATA_PTR",
     "the offset resolves but the BANK BYTE does not, and a data pointer's "
     "bank byte is read on every deref -- so it reads as bank 0"),
)


def _scan(path, text, rx, macro, why):
    hits = [(text[:m.start()].count("\n") + 1, m.group(1))
            for m in rx.finditer(text)]
    if not hits:
        return 0
    print(f"check_kernelc_calls: {path}: {len(hits)} {macro} site(s) in "
          f"kernel C -- {why}.", file=sys.stderr)
    for line, tgt in hits[:20]:
        print(f"  {path}:{line}: {macro} {tgt}", file=sys.stderr)
    if len(hits) > 20:
        print(f"  ... and {len(hits) - 20} more", file=sys.stderr)
    # One line of advice per DISTINCT kind present, not per site.
    for fix in dict.fromkeys(_fix_for(macro, t) for _, t in hits):
        print(fix, file=sys.stderr)
    return 1


def check(path):
    """Check `path`, AND its data segment if one sits beside it.

    The data segment is where FGX2_LONG_PTR lands, and the ninja rule names
    only the code output -- fcc derives the data file's name from -o and
    writes it alongside.  Checking only what was named is how this class of
    defect stayed invisible: the code segment was clean the whole time."""
    rc = 0
    paths = [path]
    if path.endswith(".s") and not path.endswith(".data.s"):
        data = path[:-2] + ".data.s"
        if os.path.exists(data):
            paths.append(data)
    for p in paths:
        try:
            with open(p) as f:
                text = f.read()
        except OSError as e:
            print(f"check_kernelc_calls: cannot read {p}: {e}", file=sys.stderr)
            return 1
        for rx, macro, why in _BANNED:
            rc |= _scan(p, text, rx, macro, why)
    return rc


def selftest():
    """RED on either banned macro, GREEN on the idiom that replaces it.

    Both directions for both macros, because a checker that cannot fail reads
    as a clean bill of health -- the trap this project has hit more than once.
    """
    import tempfile
    bad = ("                PHK\n"
           "                FGX2_FARCALL getblk\n")
    good = ("                PHK\n"
            "                PEA     _L0-1\n"
            "                PHK\n"
            "                PEA     getblk-1\n"
            "                RTL             ; PILECALL\n")
    bad_ptr = ("spec_vnodeops   FGX2_LONG_PTR _Fa;spec_lookup;0\n"
               "                FGX2_LONG_PTR _Fa;spec_open;0\n")
    good_ptr = ("spec_vnodeops   KFAR_FN_PTR _Fa;spec_lookup\n"
                "                KFAR_FN_PTR _Fa;spec_open\n")
    bad_data = "pg              LIBC_DATA_PTR _Spg;g\n"
    bad_str = "msg             FGX2_LONG_PTR _Sg;_kb_S0;0\n"
    rc = 0
    for name, body, want in (("bad", bad, 1), ("good", good, 0),
                             ("bad_ptr", bad_ptr, 1),
                             ("good_ptr", good_ptr, 0),
                             ("bad_data", bad_data, 1),
                             ("bad_str", bad_str, 1)):
        with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
            f.write(body)
            p = f.name
        got = check(p)
        os.unlink(p)
        if got != want:
            print(f"SELFTEST FAIL: {name} returned {got}, wanted {want}",
                  file=sys.stderr)
            rc = 1
    if rc == 0:
        print("check_kernelc_calls selftest: OK (red on FGX2_FARCALL, "
              "FGX2_LONG_PTR and LIBC_DATA_PTR; green on PILECALL and "
              "KFAR_FN_PTR)")
    return rc


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--selftest":
        sys.exit(selftest())
    if len(sys.argv) < 2:
        print("usage: check_kernelc_calls.py <file.s>... | --selftest",
              file=sys.stderr)
        sys.exit(2)
    sys.exit(max(check(p) for p in sys.argv[1:]))
