#!/usr/bin/env python3
"""derive.py -- mint a DELIBERATELY-BROKEN test fixture.

It is a good binary with one byte changed, and exists to prove the kernel
REJECTS something.  It is built by editing bytes rather than by a linker
option on purpose: a linker able to emit a stale ABI stamp could mint the very
thing the gate is meant to catch, so the badness has to be introduced outside
the toolchain.

    fgx3bad    <- fgx3probe.bin   ABI stamp rolled back to v1.  The loader must
                  ENOEXEC it.  If the stamp gate regresses, the binary RUNS and
                  prints the PASS marker that tests/fgx3reject.json asserts is
                  absent -- so a silent no-op here is a test that cannot fail.

The transform ASSERTS the byte it is about to change already holds the
expected value.  Without that, an upstream format change would leave it
silently patching the wrong offset, producing a fixture that is "bad" in no
particular way and a green test that proves nothing.

Usage:  derive.py fgx3bad <src> <dst>
        derive.py --self-test
"""
import sys


def fgx3bad(data):
    """Roll the ABI stamp back to v1 so the loader must refuse the binary."""
    d = bytearray(data)
    if bytes(d[:4]) != b"FGX3" or d[13] != 2:
        raise SystemExit(
            f"derive: source is {bytes(d[:4])!r} abi={d[13]}, expected FGX3 "
            f"abi=2 -- fgx_ld format plumbing changed")
    d[13] = 1
    return bytes(d)


TRANSFORMS = {"fgx3bad": fgx3bad}


def _selftest():
    """Prove the transform CHANGES the byte it claims, and REFUSES a source
    that no longer has the expected shape.  A transform that silently did
    nothing would still produce a file, and the test built on it would pass
    for the wrong reason."""
    fails = 0

    good3 = bytearray(b"FGX3" + bytes(9) + b"\x02" + bytes(50))
    out3 = fgx3bad(bytes(good3))
    if out3[13] != 1:
        print(f"  SELFTEST FAIL: fgx3bad left abi={out3[13]}, expected 1")
        fails += 1
    if out3[:4] != b"FGX3":
        print("  SELFTEST FAIL: fgx3bad corrupted the magic")
        fails += 1

    # The guard must actually fire -- it is the only thing standing between
    # "fixture is deliberately broken" and "fixture is accidentally fine".
    for fn, bad, what in ((fgx3bad, bytearray(b"FGX2" + bytes(60)),
                           "wrong magic"),):
        try:
            fn(bytes(bad))
        except SystemExit:
            pass
        else:
            print(f"  SELFTEST FAIL: {fn.__name__} accepted a source with {what}")
            fails += 1

    if fails:
        print(f"derive self-test: {fails} FAILURE(S)")
        return 1
    print("derive self-test: OK (the transform edits the right byte and "
          "rejects a source whose format moved)")
    return 0


def main(argv):
    if "--self-test" in argv or "--selftest" in argv:
        return _selftest()
    if len(argv) != 3 or argv[0] not in TRANSFORMS:
        print(__doc__.rstrip(), file=sys.stderr)
        return 2
    what, src, dst = argv
    with open(src, "rb") as f:
        data = f.read()
    with open(dst, "wb") as f:
        f.write(TRANSFORMS[what](data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
