#!/usr/bin/env python3
"""check_canaries -- every kernel canary byte is WRITTEN and is READ.  apple/fgx#464.

A `KMem_*_canary DS 1' byte guards the region before it: the kernel stamps it
$A5 at boot, and an overrun of the region changes it.  Two ways it can be a
guard in the source and nothing in the machine:

  - NO WRITER.  Eight of twenty-five were never stamped, so they read $00 in a
    healthy machine and in a crashing one alike -- found when #463 sampled them
    for an overflow they could not have reported.
  - NO READER.  Nothing compared them at all; they were read only when someone
    thought to write a throwaway manifest.

So: every canary declared in include/memmap.s (the core bank) or
src/kernel/far/far.s (the far bank) must be the target of an `STA' in one of
those two files' stampers, and must be a memory region of the smoke test with
an expectation that it reads a5.  smoke is in the gate, so an overrun of any
guarded region turns the gate red.

Exit 0 = every canary is written and read, 1 = not.
Run `--self-test' to check this checker against synthetic inputs.
"""
import json
import pathlib
import re
import sys

DECLS = {"core": pathlib.Path("include/memmap.s"),
         "far":  pathlib.Path("src/kernel/far/far.s")}
WRITERS = [pathlib.Path("src/kernel/main.s"), pathlib.Path("src/kernel/far/far.s")]
SMOKE = pathlib.Path("tools/mame_test/tests/smoke.json")

DECL_RE = re.compile(r"^(KMem_\w+_canary)\s+DS\s+1\b", re.M)
STA_RE = re.compile(r"^\s+STA\s+\|?(KMem_\w+_canary)\b", re.M)


def declared(texts):
    """{name: bank} for every canary declared in the given {bank: text}."""
    out = {}
    for bank, text in texts.items():
        for name in DECL_RE.findall(text):
            out[name] = bank
    return out


def written(texts):
    """Every canary name some writer file stores to."""
    out = set()
    for text in texts:
        out.update(STA_RE.findall(text))
    return out


def read_by_smoke(manifest):
    """{name: bank} for canary regions smoke dumps AND expects to read a5."""
    regions = {}
    for r in manifest.get("memory_regions", []):
        sym = r.get("symbol", "")
        if sym.endswith("_canary"):
            regions[r["name"]] = (sym, "far" if r.get("farbank") else "core")
    out = {}
    for chk in manifest.get("expect", {}).get("memory", []):
        if chk.get("name") in regions and \
                chk.get("hex_starts_with", "").lower() == "a5":
            sym, bank = regions[chk["name"]]
            out[sym] = bank
    return out


def check(decl, wrote, read):
    """Complaint strings; empty means every canary is written and read."""
    out = []
    if not decl:
        out.append("no canaries declared -- the declaration pattern has gone "
                   "stale, and an empty set passes anything")
    for name in sorted(decl):
        if name not in wrote:
            out.append("%s is declared but nothing stamps it $A5" % name)
        if name not in read:
            out.append("%s is declared but smoke does not read it" % name)
        elif read[name] != decl[name]:
            out.append("%s lives in the %s bank but smoke reads it from the %s "
                       "bank" % (name, decl[name], read[name]))
    for name in sorted(set(read) - set(decl)):
        out.append("smoke reads %s, which is not a declared canary" % name)
    return out


def self_test():
    decl = declared({"core": "KMem_a_canary DS 1\nKMem_b_canary   DS      1\n",
                     "far": "KMem_f_canary  DS  1\n"})
    good_w = written(["  STA |KMem_a_canary\n  STA KMem_b_canary\n",
                      "                STA     |KMem_f_canary\n"])
    good_r = {"KMem_a_canary": "core", "KMem_b_canary": "core",
              "KMem_f_canary": "far"}
    smoke = {"memory_regions": [{"name": "c", "symbol": "KMem_f_canary",
                                 "farbank": True, "len": 1}],
             "expect": {"memory": [{"name": "c", "hex_starts_with": "A5"}]}}
    cases = [
        ("all written and read", decl, good_w, good_r, True),
        ("one never stamped", decl, good_w - {"KMem_b_canary"}, good_r, False),
        ("one never read", decl, good_w,
         {k: v for k, v in good_r.items() if k != "KMem_a_canary"}, False),
        ("read from the wrong bank", decl, good_w,
         dict(good_r, KMem_f_canary="core"), False),
        ("nothing declared", {}, good_w, good_r, False),
    ]
    bad = 0
    for name, d, w, r, want_ok in cases:
        ok = not check(d, w, r)
        print("  %s %-26s" % ("ok  " if ok == want_ok else "WRONG", name))
        bad += ok != want_ok
    got = read_by_smoke(smoke)
    if got != {"KMem_f_canary": "far"}:
        print("  WRONG smoke parse: %r" % got)
        bad += 1
    else:
        print("  ok   a farbank region with an a5 expectation is a far reader")
    print("check_canaries: %s" % ("SELF-TEST FAILED (%d)" % bad if bad
                                  else "self-test clean"))
    return 1 if bad else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    decl = declared({b: p.read_text() for b, p in DECLS.items()})
    wrote = written(p.read_text() for p in WRITERS)
    read = read_by_smoke(json.loads(SMOKE.read_text()))
    problems = check(decl, wrote, read)
    if problems:
        print("CANARY CHECK FAILED:")
        for p in problems:
            print("  - " + p)
        return 1
    print("check_canaries: %d canaries, each stamped and read by smoke"
          % len(decl))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
