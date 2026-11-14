#!/usr/bin/env python3
"""check_sock_argblk.py - libc packs the socket arg block and the kernel unpacks
it; the two must agree on where every field sits.

WHY THIS EXISTS.  `_sock_argblk' (toolchain/lib/libc_c/socket.c) is a flat scalar
block that libc fills and the network modules read, through `blk[i]' in
src/kernel/bsdnet/machine/bn_sys.c.  There is no shared declaration, so the
layout lives twice and nothing else makes the two copies agree.

That is not hypothetical.  apple/fgx#440: `sendto' and `recvfrom' took a `flags'
argument, named it in the signature, and packed no word for it -- so MSG_OOB
and MSG_DONTWAIT were discarded in libc, before the kernel could honour or
refuse them.  Both halves were self-consistent and both were wrong, which is
precisely the failure a single-sided review does not catch.  apple/fgx#480 was
the buffer's bank: a stack buffer read through the data bank.

A DISAGREEMENT HERE IS SILENT: the kernel reads whatever word sits where it
believes the field is.  So the agreement is CHECKED rather than tested.

WHAT IS COMPARED, for the four calls that carry the block: the subscript libc
assigns `flags' and the buffer's bank `(int)(lp >> 16)' against the subscript
bn_sys.c reads them from (`.flags = blk[i]', `.buf = far(blk[i], ...)'); for
sendto, the sockaddr's offset, bank and length (`far(blk[b], blk[o])', `blk[n]'
as its length); and that the block's size covers every word libc writes.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# BOTH socket members: the wrappers are split across two files because the libc
# pile dead-strips at FILE granularity (socket_srv.c's header says why).
CSRC = [os.path.join(ROOT, "toolchain/lib/libc_c/socket.c"),
        os.path.join(ROOT, "toolchain/lib/libc_c/socket_srv.c")]
KSRC = os.path.join(ROOT, "src/kernel/bsdnet/machine/bn_sys.c")
DATA = os.path.join(ROOT, "toolchain/lib/libc_c/socket.c")

# libc call -> the argument block bn_sys.c fills for it
PAIRS = {"send": "a_sendto", "sendto": "a_sendto",
         "recv": "a_recvfrom", "recvfrom": "a_recvfrom"}

C_FUNC = re.compile(r"^int\s+(\w+)\s*\(")
C_SLOT = re.compile(r"_sock_argblk\[(\d+)\]\s*=\s*(.+?);")
C_BANK = re.compile(r"^\(int\)\s*\(\s*lp\s*>>\s*16\s*\)$")
C_TO_OFF = re.compile(r"^\(int\)\s*tp$")
C_TO_BANK = re.compile(r"^\(int\)\s*\(\s*tp\s*>>\s*16\s*\)$")
C_FROM_OFF = re.compile(r"^\(int\)\s*fp$")
C_FROM_BANK = re.compile(r"^\(int\)\s*\(\s*fp\s*>>\s*16\s*\)$")
DS_SIZE = re.compile(r"^int\s+_sock_argblk\s*\[\s*(\d+)\s*\]\s*;", re.M)


def c_slots(text):
    """{function: {field: subscript}} and {function: widest subscript}."""
    out, widest, cur = {}, {}, None
    for line in text.splitlines():
        m = C_FUNC.match(line)
        if m:
            cur = m.group(1)
            out.setdefault(cur, {})
        if cur is None:
            continue
        for idx, rhs in C_SLOT.findall(line):
            idx, rhs = int(idx), rhs.strip()
            widest[cur] = max(widest.get(cur, -1), idx)
            if rhs == "flags":
                out[cur]["flags"] = idx
            elif C_BANK.match(rhs):
                out[cur]["bank"] = idx
            elif C_TO_OFF.match(rhs):
                out[cur]["tooff"] = idx
            elif C_TO_BANK.match(rhs):
                out[cur]["tobank"] = idx
            elif rhs == "tolen":
                out[cur]["tolen"] = idx
            elif C_FROM_OFF.match(rhs):
                out[cur]["fromoff"] = idx
            elif C_FROM_BANK.match(rhs):
                out[cur]["frombank"] = idx
            elif "*fromlen" in rhs:
                out[cur]["fromlen"] = idx
    return out, widest


def k_reads(text):
    """{block: {field: subscript}} from bn_sys.c."""
    out = {}
    for blk in ("a_sendto", "a_recvfrom"):
        d = {}
        m = re.search(blk + r"\.flags\s*=\s*blk\[(\d+)\]", text)
        if m:
            d["flags"] = int(m.group(1))
        m = re.search(blk + r"\.buf\s*=\s*far\(blk\[(\d+)\],\s*blk\[\d+\]\)", text)
        if m:
            d["bank"] = int(m.group(1))
        out[blk] = d
    m = re.search(r"a_sendto\.to\s*=\s*far\(blk\[(\d+)\],\s*blk\[(\d+)\]\)", text)
    if m:
        out["a_sendto"]["tobank"] = int(m.group(1))
        out["a_sendto"]["tooff"] = int(m.group(2))
    m = re.search(r"a_sendto\.tolen\s*=\s*blk\[(\d+)\]", text)
    if m:
        out["a_sendto"]["tolen"] = int(m.group(1))
    m = re.search(r"a_recvfrom\.from\s*=\s*far\(blk\[(\d+)\],\s*blk\[(\d+)\]\)", text)
    if m:
        out["a_recvfrom"]["frombank"] = int(m.group(1))
        out["a_recvfrom"]["fromoff"] = int(m.group(2))
    # the length word is read in and written back: both must name one word
    rd = re.search(r"bn_len\s*=\s*blk\[(\d+)\];", text)
    wr = re.search(r"blk\[(\d+)\]\s*=\s*bn_len;", text)
    if rd and wr and rd.group(1) == wr.group(1):
        out["a_recvfrom"]["fromlen"] = int(rd.group(1))
    return out


def check(csrc, ksrc, data):
    cs, widest = c_slots(csrc)
    ks = k_reads(ksrc)
    errs, checked = [], 0
    for cname, kblk in sorted(PAIRS.items()):
        c, k = cs.get(cname, {}), ks.get(kblk, {})
        fields = ["flags", "bank"] + (
            ["tooff", "tobank", "tolen"] if cname == "sendto" else
            ["fromoff", "frombank", "fromlen"] if cname == "recvfrom" else [])
        for f in fields:
            if f not in c:
                errs.append("libc %s() packs no %s word" % (cname, f))
            elif f not in k:
                errs.append("bn_sys.c reads no %s for %s, but libc %s() packs "
                            "it at word %d" % (f, kblk, cname, c[f]))
            elif c[f] != k[f]:
                errs.append("bn_sys.c reads %s's %s from word %d; libc %s() "
                            "writes word %d" % (kblk, f, k[f], cname, c[f]))
        checked += 1
    m = DS_SIZE.search(data)
    if not m:
        errs.append("no `int _sock_argblk[n];' in socket.c")
    elif widest and int(m.group(1)) < max(widest.values()) + 1:
        errs.append("_sock_argblk holds %s words; libc writes %d"
                    % (m.group(1), max(widest.values()) + 1))
    return errs, checked


def self_test():
    good_c = (
        "int send(int s, char *buf, int len, int flags)\n{\n"
        "    _sock_argblk[2] = flags;\n"
        "    _sock_argblk[3] = (int)(lp >> 16);\n}\n")
    good_k = ("a_sendto.buf = far(blk[3], blk[0]);\n"
              "a_sendto.flags = blk[2] & ~MSG_DONTWAIT;\n")
    data = "int _sock_argblk[13];\n"
    saved = dict(PAIRS)
    try:
        PAIRS.clear()
        PAIRS["send"] = "a_sendto"
        errs, n = check(good_c, good_k, data)
        assert not errs and n == 1, ("agreeing pair must pass", errs)
        errs, _ = check(good_c, good_k.replace("blk[2]", "blk[4]"), data)
        assert any("flags from word 4" in e for e in errs), errs
        errs, _ = check(good_c.replace("    _sock_argblk[2] = flags;\n", ""),
                        good_k, data)
        assert any("packs no flags" in e for e in errs), errs
        errs, _ = check(good_c, good_k.replace("far(blk[3]", "far(blk[5]"), data)
        assert any("bank from word 5" in e for e in errs), errs
        errs, _ = check(good_c, good_k, "int _sock_argblk[2];\n")
        assert any("holds 2 words" in e for e in errs), errs
        PAIRS.clear()
        PAIRS["recvfrom"] = "a_recvfrom"
        rc = ("int recvfrom(int s, char *buf, int maxlen, int flags)\n{\n"
              "    _sock_argblk[2] = flags;\n"
              "    _sock_argblk[3] = (int)(lp >> 16);\n"
              "    _sock_argblk[4] = (int)fp;\n"
              "    _sock_argblk[5] = (int)(fp >> 16);\n"
              "    _sock_argblk[6] = from ? *fromlen : 0;\n}\n")
        rk = ("a_recvfrom.buf = far(blk[3], blk[0]);\n"
              "a_recvfrom.flags = blk[2] & ~MSG_DONTWAIT;\n"
              "bn_len = blk[6];\na_recvfrom.from = far(blk[5], blk[4]);\n"
              "blk[6] = bn_len;\n")
        errs, n = check(rc, rk, data)
        assert not errs and n == 1, ("agreeing recvfrom must pass", errs)
        errs, _ = check(rc, rk.replace("far(blk[5], blk[4])", "far(blk[4], blk[5])"), data)
        assert any("frombank from word 4" in e for e in errs), errs
        errs, _ = check(rc, rk.replace("blk[6] = bn_len;", "blk[7] = bn_len;"), data)
        assert any("reads no fromlen" in e for e in errs), errs
    finally:
        PAIRS.clear()
        PAIRS.update(saved)
    print("check_sock_argblk self-test: OK")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    csrc = "".join(open(p).read() + "\n" for p in CSRC)
    errs, n = check(csrc, open(KSRC).read(), open(DATA).read())
    for e in errs:
        print("check_sock_argblk: " + e)
    if errs:
        sys.exit(1)
    print("check_sock_argblk: OK (%d calls, libc and bn_sys.c agree)" % n)


if __name__ == "__main__":
    main()
