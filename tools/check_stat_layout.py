#!/usr/bin/env python3
"""check_stat_layout.py - the kernel's STX_ block and userland's struct stat
must describe the same 32 bytes.

WHY THIS EXISTS, and it is not hypothetical.  include/fs.s carries the BSD
stat layout as a DUM block (STX_dev, STX_ino, ...) and
toolchain/include/sys/stat.h carries the same thing as a C struct that userland
reads DIRECTLY -- SYS_STAT fills the kernel side and libc casts.  The header
states outright that it "MIRRORS the kernel's include/fs.s BSD layout (STX_*
fields)", and on 2026-09-01 it did not: the asm block was missing st_rdev, so
the two disagreed by two bytes and every member from st_size onward would have
landed short the moment anything filled the layout.  Nothing did yet, which is
the only reason it was latent rather than a bug -- and the root swap's new
Fs_Stat is the first writer.

A two-byte shift in a struct userland reads directly does not fail loudly.  It
reports wrong file sizes and wrong timestamps, a long way from the edit that
caused it, which is exactly the shape gen_vfs_equ.py's header warns about when
it says "there is no second place to remember".  There are two places here and
they cannot be collapsed -- one is Merlin32 assembly and one is C read by the
port -- so the agreement is CHECKED instead.

WHAT IS COMPARED: field ORDER, field WIDTH and the total size.  Names are
matched with the STX_/st_ prefixes stripped, because the two spellings are
fixed by their own conventions and neither is free to change to suit the other.
"""
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM  = os.path.join(ROOT, "include/fs.s")
HDR  = os.path.join(ROOT, "toolchain/include/sys/stat.h")
KC   = os.path.join(ROOT, "src/kernel/vfs/statlayout.h")

# C type -> width in bytes, on fcc's model: int and short are 16 bits, long is
# 32.  ASKED OF THE COMPILER rather than assumed -- sizeof int/short/long/char
# emits 2, 2, 4, 1 -- and it is why 2.11BSD is the port source at all.
CWIDTH = {
    "short": 2, "unsigned short": 2, "u_short": 2,
    "int": 2, "unsigned int": 2, "unsigned": 2,
    "long": 4, "unsigned long": 4,
    "char": 1, "unsigned char": 1,
}


def asm_fields(text):
    """The STX_ DUM block, in order: [(name, width)]."""
    out = []
    started = False
    for line in text.split("\n"):
        m = re.match(r"^STX_(\w+)\s+DS\s+(\d+)", line)
        if m:
            started = True
            out.append((m.group(1), int(m.group(2))))
            continue
        if started and re.match(r"^STAT_SIZE\s+EQU", line):
            break
    return out


def hdr_fields(text):
    """struct stat's members, in order: [(name, width)]."""
    m = re.search(r"struct\s+stat\s*\{(.*?)\}\s*;", text, re.S)
    if not m:
        return []
    out = []
    for line in m.group(1).split("\n"):
        line = re.sub(r"/\*.*?\*/", "", line).strip()
        if not line or line.startswith("/*") or line.startswith("*"):
            continue
        # AN ARRAY MEMBER COUNTS AS ITS WHOLE EXTENT.  st_spare4[3] is one
        # field of six bytes, not a field of two -- and before this was
        # handled the member was skipped entirely, so the header looked one
        # field SHORT rather than wrong.  A parser that silently drops what it
        # cannot read is the failure this whole checker exists to prevent.
        d = re.match(r"^((?:unsigned\s+|u_)?\w+)\s+st_(\w+)"
                     r"(?:\s*\[\s*(\d+)\s*\])?\s*;", line)
        if not d:
            continue
        ctype = re.sub(r"\s+", " ", d.group(1)).strip()
        n = int(d.group(3)) if d.group(3) else 1
        if ctype not in CWIDTH:
            out.append((d.group(2), None))     # unknown -> reported, not guessed
        else:
            out.append((d.group(2), CWIDTH[ctype] * n))
    return out


def kc_offsets(text):
    """The kernel C offsets: `#define STX_<name> <n>' plus STAT_SIZE.

    THE THIRD COPY, added with the cutover (2026-09-05).  root_stat fills the
    buffer from far-bank kernel C, which cannot use the userland struct, so it
    names the offsets itself -- and a third place is a third thing to rot.
    """
    out = {}
    for m in re.finditer(r"^#define\s+(STX_(\w+)|STAT_SIZE)\s+(\d+)",
                         text, re.M):
        out[m.group(2) or "SIZE"] = int(m.group(3))
    return out


def compare_kc(a, kc):
    """The C offsets must be the running sum of the asm widths."""
    bad = []
    if not kc:
        return ["no STX_ #defines found in src/kernel/vfs/statlayout.h"]
    off = 0
    for name, w in a:
        if name not in kc:
            bad.append(f"statlayout.h has no STX_{name}, which include/fs.s "
                       f"declares")
        elif kc[name] != off:
            bad.append(f"STX_{name}: include/fs.s puts it at {off}, "
                       f"statlayout.h says {kc[name]}")
        off += w
    total = sum(w for _, w in a)
    if kc.get("SIZE") != total:
        bad.append(f"STAT_SIZE: include/fs.s sums to {total}, "
                   f"statlayout.h says {kc.get('SIZE')}")
    extra = set(kc) - {n for n, _ in a} - {"SIZE"}
    if extra:
        bad.append("statlayout.h names field(s) include/fs.s does not: "
                   + ", ".join(sorted(extra)))
    return bad


def compare(a, h):
    bad = []
    if not a:
        bad.append("no STX_ block found in include/fs.s")
    if not h:
        bad.append("no struct stat found in sys/stat.h")
    if bad:
        return bad
    for i, (name, w) in enumerate(h):
        if w is None:
            bad.append(f"struct stat: st_{name} has a type this checker does "
                       f"not know a width for")
    if len(a) != len(h):
        bad.append(f"field COUNT differs: include/fs.s has {len(a)} "
                   f"({', '.join(n for n, _ in a)}); sys/stat.h has {len(h)} "
                   f"({', '.join(n for n, _ in h)})")
        return bad
    for i, ((an, aw), (hn, hw)) in enumerate(zip(a, h)):
        if an != hn:
            bad.append(f"field {i}: include/fs.s says STX_{an}, "
                       f"sys/stat.h says st_{hn} -- ORDER must match")
        elif aw != hw:
            bad.append(f"field {i} ({an}): include/fs.s says {aw} byte(s), "
                       f"sys/stat.h says {hw}")
    if not bad:
        tot_a = sum(w for _, w in a)
        tot_h = sum(w for _, w in h)
        if tot_a != tot_h:
            bad.append(f"total size differs: {tot_a} vs {tot_h}")
    return bad


def main():
    a = asm_fields(open(ASM).read())
    h = hdr_fields(open(HDR).read())
    kc = kc_offsets(open(KC).read())
    bad = compare(a, h) + compare_kc(a, kc)
    if bad:
        print("check_stat_layout: FAIL")
        for b in bad:
            print("  " + b)
        return 1
    print(f"check_stat_layout: clean ({len(a)} fields, {sum(w for _, w in a)} "
          f"bytes; include/fs.s, sys/stat.h and statlayout.h agree)")
    return 0


def self_test():
    """THE POSITIVE CONTROL.  A checker that cannot call a bad pair bad reads
    exactly like one that passes everything -- and this checker exists BECAUSE
    a real disagreement went unnoticed, so its own blindness is the risk."""
    good_asm = ("                DUM     0\n"
                "STX_dev         DS      2\n"
                "STX_ino         DS      2\n"
                "STX_size        DS      4\n"
                "STAT_SIZE       EQU     *\n")
    good_hdr = ("struct stat {\n"
                "    short  st_dev;\n"
                "    unsigned short st_ino;\n"
                "    long   st_size;\n"
                "};\n")
    cases = [
        ("an agreeing pair passes", good_asm, good_hdr, True),
        ("A MISSING ASM FIELD IS CAUGHT -- the real 2026-09-01 defect, where "
         "st_rdev was in the header and not the block",
         good_asm.replace("STX_ino         DS      2\n", ""), good_hdr, False),
        ("a missing HEADER field is caught",
         good_asm, good_hdr.replace("    unsigned short st_ino;\n", ""), False),
        ("a REORDER is caught even at the same total size",
         "                DUM     0\n"
         "STX_ino         DS      2\n"
         "STX_dev         DS      2\n"
         "STX_size        DS      4\n"
         "STAT_SIZE       EQU     *\n", good_hdr, False),
        ("a WIDTH change is caught",
         good_asm.replace("STX_size        DS      4", "STX_size        DS      2"),
         good_hdr, False),
        ("a header type widening is caught",
         good_asm, good_hdr.replace("    short  st_dev;", "    long   st_dev;"),
         False),
        ("an unparseable header is caught rather than passing empty",
         good_asm, "struct notstat { short x; };\n", False),
        ("AN ARRAY MEMBER COUNTS AS ITS WHOLE EXTENT -- st_spare4[3] is six "
         "bytes, and before this was handled the member was skipped and the "
         "header merely looked one field short",
         good_asm.replace("STX_size        DS      4",
                          "STX_size        DS      6"),
         good_hdr.replace("    long   st_size;", "    short  st_size[3];"),
         True),
        ("...and an array whose COUNT is wrong is still caught",
         good_asm, good_hdr.replace("    long   st_size;",
                                    "    short  st_size[3];"), False),
        ("an unparseable asm block is caught rather than passing empty",
         "; nothing here\n", good_hdr, False),
    ]
    ok = True
    for label, asm, hdr, want_pass in cases:
        bad = compare(asm_fields(asm), hdr_fields(hdr))
        passed = not bad
        if passed != want_pass:
            print(f"  FAIL  {label} (got {'pass' if passed else 'fail'})")
            ok = False
        else:
            print(f"  ok    {label}")

    # THE THIRD COPY'S OWN ARMS.  compare_kc was added with the cutover and an
    # unmutated checker arm is not coverage -- the whole reason this file has a
    # self-test at all.
    good_kc = ("#define STX_dev   0\n"
               "#define STX_ino   2\n"
               "#define STX_size  4\n"
               "#define STAT_SIZE 8\n")
    kc_cases = [
        ("the C offsets agreeing with the asm widths passes", good_kc, True),
        ("A WRONG OFFSET IS CAUGHT -- the shape the whole file guards: a "
         "field that starts two bytes early reads every later one short",
         good_kc.replace("#define STX_size  4", "#define STX_size  2"), False),
        ("a MISSING C offset is caught",
         good_kc.replace("#define STX_ino   2\n", ""), False),
        ("a wrong STAT_SIZE is caught",
         good_kc.replace("#define STAT_SIZE 8", "#define STAT_SIZE 12"), False),
        ("a C offset for a field the asm does not declare is caught",
         good_kc + "#define STX_nosuch 8\n", False),
        ("an unparseable C header is caught rather than passing empty",
         "/* nothing */\n", False),
    ]
    for label, kc, want_pass in kc_cases:
        bad = compare_kc(asm_fields(good_asm), kc_offsets(kc))
        passed = not bad
        if passed != want_pass:
            print(f"  FAIL  {label} (got {'pass' if passed else 'fail'})")
            ok = False
        else:
            print(f"  ok    {label}")

    print("check_stat_layout self-test: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main())
