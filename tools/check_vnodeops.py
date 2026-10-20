#!/usr/bin/env python3
"""check_vnodeops -- every `struct vnodeops' vector fills every slot, with no
null entry.

WHY THIS EXISTS.  fcc is a K&R compiler, so there are no designated
initialisers: every op vector in this tree is POSITIONAL.  A vector that is
short, or whose order has drifted from the header, is not a compile error -- it
is a null slot or a call that lands on the wrong operation.  Nothing checked it,
and the only guards were comments: dead_vnops.c and spec_vnops.c each say "a
slot inserted in the header without one added here shifts every entry below it"
and neither could enforce it.

WHAT A NULL SLOT WOULD COST, which is why this is worth a build edge rather than
a convention: fcc calls a function pointer by pushing bank and offset-minus-one
and returning to it, so a NULL pointer becomes $FFFF + 1 = $00/0000 rather than
an address that faults.  Bank 0 is zeros, $00 is BRK, and nothing installs the
native BRK vector at $00:FFE6 -- so the runaway BRK paves bank 0 with its own
stack frames and erases the relocation anchor the harness reads.  A missing slot
would not present as a missing slot; it would present as a machine with no
screen.  (Measured on apple/fgx#463, whose own cause was elsewhere -- a wild
store from net.mod -- but which reached $00/0000 by exactly this route.)

THE SLOT COUNT IS DERIVED, NEVER COPIED.  It is read from `struct vnodeops' in
src/kernel/vfs/vnode.h at check time, so adding a slot there makes every vector
that did not follow a BUILD failure.

RUNTIME-BUILT VECTORS ARE NOT COVERED and must start from a whole-struct copy.
prodos_write.c's pd_wvops is the one in the tree: it is an empty static, and
pd_setwriteops (prodos_node.c:355) fills it with `*v = prodos_vnodeops;' BEFORE
overriding the write half, so every slot it does not name is inherited rather
than null.  A runtime vector assembled field by field would defeat this checker,
which is why that copy is load-bearing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HDR = os.path.join(ROOT, "src", "kernel", "vfs", "vnode.h")

SLOT_RE = re.compile(r"int\s*\(\*\s*(vn_\w+)\s*\)\s*\(\s*\)\s*;")
VEC_RE = re.compile(r"struct\s+vnodeops\s+(\w+)\s*=\s*\{(.*?)\n\};", re.S)

# A FLOOR, BECAUSE "FOUND NOTHING" IS THIS CHECKER'S FAILURE MODE.  Everything
# here keys off VEC_RE matching; if a vector is ever written in a shape it does
# not match -- closed on the last entry's line rather than on its own, say --
# that vector silently stops being checked, and if the pattern broke entirely
# the run would report "clean (0 vectors)" and pass.  A count that DROPS is
# therefore evidence about this file, not about the tree, and it fails here.
# Raise it when a vector is added; if you are lowering it, one was deleted and
# the commit should say which.
MIN_VECTORS = 5


def header_slots(text):
    """Ordered slot names of `struct vnodeops', from the header's text."""
    m = re.search(r"struct\s+vnodeops\s*\{(.*?)\n\};", text, re.S)
    if not m:
        raise SystemExit("check_vnodeops: no `struct vnodeops' in %s" % HDR)
    slots = SLOT_RE.findall(m.group(1))
    if not slots:
        raise SystemExit("check_vnodeops: `struct vnodeops' declares no slots -- "
                         "the member pattern changed, fix this parser rather "
                         "than guessing a count")
    return slots


def entries(body):
    """The initialiser's entries, comments stripped.

    DEPTH-AWARE, because a plain `split(",")' miscounts the moment an entry is
    a macro call or a cast with arguments of its own -- and miscounting is
    indistinguishable here from the defect being looked for.
    """
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
    out, cur, depth = [], [], 0
    for ch in body:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail:
        out.append(tail)
    return out


def is_null(ent):
    """Is this entry a null pointer, however it is spelled?

    Casts are stripped first: `(int (*)())0' is as null as `0', and a checker
    that only knew the bare spellings would pass the one a reader is most
    likely to write.
    """
    e = re.sub(r"\s+", "", ent)
    while True:
        stripped = re.sub(r"^\((?:[^()]|\([^()]*\))*\)", "", e, count=1)
        if stripped == e:
            break
        e = stripped
    return e in ("0", "0L", "0l", "NULL")


def vectors(text):
    """(name, entries) for each `struct vnodeops X = {...};' in one file."""
    return [(m.group(1), entries(m.group(2))) for m in VEC_RE.finditer(text)]


def sources():
    out = []
    for sub in ("src/kernel", "src/modules"):
        for dirpath, _dirs, files in os.walk(os.path.join(ROOT, sub)):
            for f in files:
                if f.endswith(".c"):
                    out.append(os.path.join(dirpath, f))
    return sorted(out)


def check(slots, files):
    """Complaint strings, plus the number of vectors actually inspected."""
    fails = []
    seen = 0
    for path in files:
        with open(path, errors="replace") as fh:
            text = fh.read()
        rel = os.path.relpath(path, ROOT)
        for name, ents in vectors(text):
            seen += 1
            if len(ents) != len(slots):
                fails.append(
                    "%s: %s has %d entries, `struct vnodeops' declares %d -- a "
                    "positional vector that is short or long calls the WRONG "
                    "operation, or none" % (rel, name, len(ents), len(slots)))
                continue
            for slot, ent in zip(slots, ents):
                if is_null(ent):
                    fails.append(
                        "%s: %s leaves %s NULL -- fcc's pile-call turns a null "
                        "op into $00/0000, which is a BRK runaway and not a "
                        "fault" % (rel, name, slot))
    return fails, seen


def self_test():
    hdr = ("struct vnodeops {\n"
           "    int (*vn_lookup)();   /* ndp */\n"
           "    int (*vn_read)();     /* vp */\n"
           "    int (*vn_strategy)(); /* bp */\n"
           "};\n")
    slots = header_slots(hdr)
    bad = []

    def want(label, text, expect_fail):
        got, seen = check(slots, [_tmp(text)])
        if seen != 1:
            bad.append("%s: inspected %d vectors, wanted 1" % (label, seen))
        elif bool(got) != expect_fail:
            bad.append("%s: %s" % (label, "missed it" if expect_fail
                                   else "false positive: %s" % got[0]))

    if len(slots) != 3 or slots[2] != "vn_strategy":
        bad.append("header parse: got %r" % (slots,))
    want("complete vector accepted",
         "struct vnodeops ok_vnodeops = {\n a, /* lookup */\n b, /* read */\n"
         " c  /* strategy */\n};\n", False)
    want("short vector rejected",
         "struct vnodeops short_vnodeops = {\n a, /* lookup */\n b /* read */\n"
         "};\n", True)
    want("long vector rejected",
         "struct vnodeops long_vnodeops = {\n a,\n b,\n c,\n d\n};\n", True)
    want("bare null slot rejected",
         "struct vnodeops null_vnodeops = {\n a,\n b,\n 0 /* strategy */\n};\n",
         True)
    # THE SPELLING A READER ACTUALLY WRITES.  A bare 0 in a function-pointer
    # slot draws a compiler warning in most dialects, so the null that reaches
    # a vector in practice wears a cast.
    want("cast null slot rejected",
         "struct vnodeops cast_vnodeops = {\n a,\n b,\n"
         " (int (*)())0 /* strategy */\n};\n", True)
    # A COMMA INSIDE AN ENTRY IS NOT A SEPARATOR, in a comment or in a macro's
    # argument list.  Counting them as entries reports a good vector as long.
    want("commas inside comments are not entries",
         "struct vnodeops cm_vnodeops = {\n a, /* lookup, first */\n"
         " b, /* read */\n c  /* strategy */\n};\n", False)
    want("commas inside a macro argument are not entries",
         "struct vnodeops mac_vnodeops = {\n a,\n b,\n"
         " VOPFN(strategy, 3)\n};\n", False)

    # The floor itself must be able to fail, or it is the vacuous check it
    # exists to prevent.
    got, seen = check(slots, [_tmp("/* no vectors here */\n")])
    if seen != 0 or got:
        bad.append("empty file: seen=%d fails=%r" % (seen, got))

    if bad:
        for b in bad:
            print("check_vnodeops SELF-TEST FAILED: %s" % b, file=sys.stderr)
        return 1
    print("check_vnodeops self-test: OK (accepts a complete vector, rejects "
          "short, long, bare-null and CAST-null ones, and does not count commas "
          "inside comments or macro arguments)")
    return 0


def _tmp(text):
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".c", delete=False) as fh:
        fh.write(text)
        return fh.name


def main(argv):
    if "--self-test" in argv:
        return self_test()
    with open(HDR) as fh:
        slots = header_slots(fh.read())
    files = sources()
    fails, seen = check(slots, files)
    if seen < MIN_VECTORS:
        print("check_vnodeops: found %d vector(s), expected at least %d -- the "
              "initialiser pattern stopped matching, so this run proves nothing "
              "about the tree. Fix VEC_RE, or lower MIN_VECTORS and say which "
              "vector was deleted." % (seen, MIN_VECTORS), file=sys.stderr)
        return 1
    if fails:
        for f in fails:
            print("check_vnodeops: %s" % f, file=sys.stderr)
        return 1
    print("    check_vnodeops: clean (%d vector(s), each %d slots, no null op)"
          % (seen, len(slots)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
